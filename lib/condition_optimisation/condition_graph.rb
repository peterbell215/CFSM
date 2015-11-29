# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

module ConditionOptimisation
  class ConditionGraph < Array
    def initialize( condition_array = [], start_array = [] )
      super( condition_array )
      @start_array = start_array
    end

    attr_reader :start_array
    alias :nr_nodes :length

    # We need clone to be deep.
    def clone
      new_graph = ConditionGraph.new( self.length ) { |index| self[index].clone }
      new_graph.instance_exec( @start_array ) { |start_array| @start_array = start_array.clone }
      new_graph
    end

    # A chain is a hash of one element containing a set of conditions, and
    # a transition description.  So a chain might be:
    #
    #   0: {:c1, :c2, :c3, :c4}[:fsm1_transition] -> 1
    #
    # This describes that the first entry in the graph says that if conditions
    # :c1 to :c4 are fulfilled, then the :fsm1_transition should be performed.
    # Furthermore, the graph executor should then consider moving to the 2nd
    # entry in the graph.
    #
    # This method's job is to merge a further chain into an existing graph.
    # The merge only ever evaluates start nodes in the graph.  It applies
    # one of the four rules:
    #
    # 0: {:c1, :c2, :c3, :c4}[:fsm1_transition] -> end
    # merged with
    # {:c1, :c2, :c3, :c4}[:fsm2_transition]
    # becomes
    # 0: {:c1, :c2, :c3, :c4}[:fsm1_transition, :fsm2_transition] -> end
    #
    # 0: {:c1, :c2, :c3, :c4}[:fsm1_transition] -> end
    # merged with
    # {:c1, :c2}[:fsm2_transition]
    # becomes
    # 0: {:c1, :c2}[:fsm2_transition] -> [1]
    # 1: {:c3, :c4}[:fsm1_transition] -> end
    #
    # 0: {:c1, :c2}[:fsm1_transition][:fsm1_transition] -> end
    # merged with
    # {:c1, :c2, :c3, :c4}[:fsm2_transition]
    # becomes
    # 0: {:c1, :c2}[:fsm1_transition] -> [1]
    # 1: {:c3, :c4}[:fsm2_transition] -> end
    #
    # 0: {:c1, :c2, :c3, :c4}[:fsm1_transition][:fsm1_transition] -> end
    # merged with
    # {:c1, :c2, :c5, :c6}[:fsm2_transition]
    # becomes
    # 0: {:c1, :c2}[] -> [1,2]
    # 1: {:c3, :c4}[:fsm1_transition] -> end
    # 2: {:c5, :c6}[:fsm2_transition] -> end
    def add_conditions( anded_conditions, transition )
      # This is here primarily to make the Rspec's slightly easier to read by not requiring
      # anded_conditions to be a Set.  Internally, it does need to be a set, though.
      anded_conditions = Set.new( anded_conditions) if anded_conditions.is_a? Array

      if self.empty?
        # First condition to be added to the graph.
        self.push( ConditionsNode.new( anded_conditions, [transition] ) )
        @start_array.push( 0 )
      else
        # Search through the array to see if the new conditions are
        # already contained in array graph as a condition node.
        catch :added_conditions do
          @start_array.each do |index|
            obj = self[index]

            if anded_conditions == obj.conditions
              # the two are the same.  Therefore, simply add transition to the set
              # of transitions on this node.
              self[index].transitions.add( transition )
              throw :added_conditions
            elsif anded_conditions < obj.conditions
              # the new conditions are a subset of the existing conditions.  Therefore,
              # split the existing conditions into those shared with the new conditions
              # and those that come later.
              self[ index ] = ConditionsNode.new( anded_conditions, [transition], [ self.length ] )
              obj.conditions = obj.conditions - anded_conditions
              self.push( obj )
              throw :added_conditions
            elsif obj.conditions < anded_conditions
              # New conditions super-set of existing conditions.  Therefore, we simply add the missing conditions on
              # as a new branch.
              obj.edges << self.length
              self.push( ConditionsNode.new( anded_conditions - obj.conditions, [transition], [] ) )
              throw :added_conditions
            elsif obj.conditions.intersect?( anded_conditions )
              # The two sets of conditions have conditions in common, but both have unique conditions.
              intersect = obj.conditions.intersection anded_conditions
              self.push( ConditionsNode.new( obj.conditions - intersect, obj.transitions, obj.edges ))
              self.push( ConditionsNode.new( anded_conditions - intersect, [transition], [] ))
              self[ index ] = ConditionsNode.new( intersect, [], [ self.length-2, self.length-1 ] )
              throw :added_conditions
            end
          end
          # if we reach here, we have not been able to add the new conditions
          # to an existing chain. Therefore, we simply add them as a new node
          # in their own right.
          @start_array.push( self.nr_nodes )
          self.push( ConditionsNode.new( anded_conditions, [transition] ) )
        end
      end
      self
    end

    # Executes the condition graph.  Starts at the appropriate start_node, progresses through the condition nodes
    # keeping track of all fsms in play.  Once all conditions have been evaluated, then the transitions associated
    # with that condition node are added to the list of transitions that need executing.
    #
    # @param [CfsmEvent] event
    def execute( event )
      transitions = Set.new      # list of transitions that can be executed.

      @start_array.each do |current|
        stack = [current, :all]           # stack used to keep track of different branches for evaluation.

        begin
          # Retrieve next condition set to evaluate, and the fsms to use.
          current, fsms_still_in_play = stack.pop(2)

          catch( :all_fsms_eliminated ) do
            # At this point self[current] points to a ConditionNode.  This has a set of conditions which we
            # need to evaluate in turn. *fsms* keeps a list of all finite state machines that are still in play.
            self[current].conditions.each do |condition_to_eval|
              fsms_still_in_play = condition_to_eval.evaluate( event, fsms_still_in_play )
              if fsms_still_in_play.nil?
                CFSM.logger.info("Condition evaluation failed for #{event.inspect} on #{condition_to_eval.inspect}")
                throw :all_fsms_eliminated
              end
            end

            # fsms is either :all or a list of FSMs that meet the criteria. We now have to apply the specified
            # transitions to those fsms in the list, or all if the list is still :all.
            self[current].transitions.each { |transition| transitions.merge transition.instantiate(fsms_still_in_play) }

            # Now push the follow ons onto the stack, with the list fof instantiated fsms still in play
            self[current].edges.each { |follow_on| stack += [ follow_on, fsms_still_in_play ] }
          end
        end until stack.empty? # If the stack is empty we are done.
      end
      transitions
    end

    # We measure the complexity of the graph by the number of conditions it has to evaluate
    def count_complexity
      self.inject( 0 ) { |nr_conditions, conditions_node| nr_conditions + conditions_node.conditions.length }
    end

    # Produces easily understandable output of the graph.  For example:
    #
    # start: 0, 2\n
    # 0: {1, 2}[] -> 1, 2
    # 1: {7, 8}[:fsm_c] -> end
    # 2: {3, 4, 5, 6}[:fsm_a] -> false
    #
    # The first line shows which nodes are start nodes.  Then each node
    # has its own line.  The first number is an index for easier reference.
    # This is followed by the set of ANDed conditions for the node.  In square
    # brackets follows the set of transitions that can be executed if we reach
    # this point in the graph.  The final element following the -> shows where
    # the graph executor next goes as indices.  If the node is a leaf node, then
    # this is marked by the word 'end'.
    def inspect
      # Print the list of starters
      string = 'start: ' << @start_array.join(', ') << "\n"

      # Print each line
      self.each_with_index do |obj,ind|
        string << "#{ind}: {#{obj.conditions.to_a.join(', ')}} "\
          "[#{obj.transitions.to_a.join(', ')}] "\
          "-> #{ obj.edges.empty? ? 'end' : obj.edges.to_a.join(', ')}\n"
      end

      string
    end

    @@start_matcher = /^start: (\d+(?:, \d+)*)/
    @@line_matcher = /^(\d+): \{(.*)\} ?\[(.*)\] -> (.*)$/

    # Class method to turn a string as generated by inspect into a graph.  This lacks
    # any sophisticated error handling and is only intended to help with testing.
    def self.from_string( input_string )
      graph = nil
      input_elements = input_string.split(/[\n;]/)
      input_elements.each do |line|
        if ( starts = @@start_matcher.match(line) )
          # start line is assumed to be the first line.  Therefore, create the graph object.
          graph = ConditionGraph.new( Array.new( input_elements.length-1 ), starts[1].split(', ').map! { |s| s.to_i })
        elsif elements = @@line_matcher.match(line)
          conditions = Set.new elements[2].split(', ').map! { |n| n.to_i }
          transitions = Set.new elements[3].split(', ').map! { |s| s.to_sym }
          edges = elements[4] == 'end' ? nil : Set.new( elements[4].split(', ').map! { |n| n.to_i } )
          graph[ elements[1].to_i ] = ConditionsNode.new( conditions, transitions, edges )
        end
      end

      graph
    end

    # Compares two graphs for equality.  Firstly, it checks that the two
    # graphs have the same number of nodes.  It then takes each node in the first
    # graph and looks for a node in the second graph that is similar.  The
    # definition of similar is that both nodes have the same conditions, the
    # same transitions, and the same number of edges leaving the node.
    #
    # If both nodes are similar, we then check that for each edge in the first
    # graph's node, there is a corresponding edge in the second graph's node
    # for which the nodes at the end of the edge are also similar.
    def ==(graph2)
      # Check that they are the same length.
      return false if self.nr_nodes != graph2.nr_nodes

      self.each_with_index do |cond_node1, index_1|
        catch :do_match do
          # Now for this condition_node, see if we can find the same node in second
          # graph
          graph2.each_with_index do |cond_node2, index_2|
            catch :dont_match do
              if self.start_array.member?(index_1) == graph2.start_array.member?(index_2) &&
                  cond_node1.similar( cond_node2 )
                # make a copy of the edge list for cond_node2
                edge_list2 = Set.new cond_node2.edges

                # Now check that the edges are the same for both nodes.
                cond_node1.edges.each do | edge1 |
                  throw :dont_match unless edge_list2.reject! { |edge2| self[edge1].similar(graph2[edge2]) }
                end

                # if we get here, we have managed to find a corresponding edge in
                # cond_node2 for each edge in cond_node1.  Therefore, we should exit
                # to the main self loop and test the next node for the existenance
                # of an equivalence.
                throw :do_match
              end
            end
          end
          # if we get to here, then we have failed to find for cond_node1 an
          # equivalent node in graph2.  Therefore the two graphs do not match.
          # we break out here.
          return nil
        end
        # if we get here, then its because we executed the :do_match.
      end
      true
    end

    # This is a little helper function that adds the conditions to the graph in the
    # sequence they are provided in *condition_sets*.  This is used for testing to
    # separate out the process of exploring all the permutations within ConditionPermutations
    # versus the actual process of building a graph.
    #
    # @param [Hash] condition_sets
    # @return [ConditionGraph]
    def add_condition_sets( condition_sets )
      condition_sets.each_pair { |conds, state| self.add_conditions( conds, state ) }
      self
    end

    # This is a little helper function that can mix up a ConditionGraph tree and return the new tree.  Used for testing
    # purposes.
    #
    # @return [ConditionGraph]
    def shuffle
      nodemap = (0..self.length-1).to_a.shuffle
      new_graph = ConditionGraph.new( self.length )

      (0..self.length-1).each do |i|
        new_graph[ nodemap[i] ] = ConditionsNode.new( self[i].conditions,
          self[i].transitions,
          Set.new( self[i].edges ) { |e| nodemap[ e ] } )
      end

      @start_array.each { |start_node| new_graph.start_array.push nodemap[start_node] }

      new_graph
    end
  end
end