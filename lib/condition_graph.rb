# CFSM Project.
# Author: peter.bell215@gmail.com
# Licensed under MIT2.

require 'conditions_node'

class ConditionGraph < Array

  alias :nr_nodes :length

  ##
  # We need clone to be deep.
  def clone
    ConditionGraph.new( self.length ) { |index| self[index].clone }
  end

  ##
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
  #
  def add_conditions( anded_conditions, transition )
    # This is here primarily to make the Rspec's slightly easier to read by not requiring
    # anded_conditions to be a Set.  Internally, it does need to be a set, though.
    anded_conditions = Set.new( anded_conditions) if anded_conditions.is_a? Array

    if self.empty?
      # First condition to be added to the graph.
      self.push( ConditionsNode.new( anded_conditions, [transition] ) )
    else
      # Search through the array to see if the new conditions are
      # already contained in array graph as a condition node.
      catch :added_conditions do
        self.each_with_index do |obj, index|
          if obj.start_node
            if anded_conditions == obj.conditions
              # the two are the same.  Therefore, simply add transition to the set
              # of transitions on this node.
              self[index].transitions.add( transition )
              throw :added_conditions
            elsif anded_conditions < obj.conditions
              # the new conditions are a subset of the existing conditions.  Therefore,
              # split the existing conditions into those shared with the new conditions
              # and those that come later.
              self[ index ] = ConditionsNode.new( obj.conditions & anded_conditions, [transition], [ self.length ], true )
              obj.conditions = obj.conditions - anded_conditions
              obj.start_node = false
              self.push( obj )
              throw :added_conditions
            elsif obj.conditions < anded_conditions
              # New conditions super-set of existing conditions.  Therefore, we simply add the missing conditions on
              # as a new branch.
              obj.edges << self.length
              self.push( ConditionsNode.new( anded_conditions - obj.conditions, [transition], [], false ) )
              throw :added_conditions
            elsif obj.conditions.intersect?( anded_conditions )
              # The two sets of conditions have conditions in common, but both have unique conditions.
              intersect = obj.conditions.intersection anded_conditions
              self.push( ConditionsNode.new( obj.conditions - intersect, obj.transitions, [], false ))
              self.push( ConditionsNode.new( anded_conditions - intersect, [transition], [], false ))
              self[ index ] = ConditionsNode.new( intersect, [], [ self.length-2, self.length-1 ], true )
              throw :added_conditions
            end
          end
        end
        # if we reach here, we have not been able to add the new conditions
        # to an existing chain. Therefore, we simply add them as a new node
        # in their own right.
        self.push( ConditionsNode.new( anded_conditions, [transition] ) )
      end
    end
    self
  end

  ##
  # We measure the complexity of the graph by the number of conditions it has to evaluate
  def count_complexity
    self.inject( 0 ) { |nr_conditions, conditions_node| nr_conditions + conditions_node.conditions.length }
  end

  ##
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
    string = 'start: ' << (0..self.length-1).to_a.reject { |i| !self[i].start_node }.join(', ') << "\n"

    # Print each line
    self.each_with_index do |obj,ind|
      string << "#{ind}: {#{obj.conditions.to_a.join(", ")}} "\
        "[#{obj.transitions.to_a.join(", ")}] "\
        "-> #{ obj.edges.empty? ? "end" : obj.edges.to_a.join(", ")}\n"
    end

    string
  end

  @@start_matcher = /^start: (\d+(?:, \d+)*)/
  @@line_matcher = /^(\d+): \{(.*)\} ?\[(.*)\] -> (.*)$/

  ##
  # Class method to turn a string as generated by inspect into a graph.  This lacks
  # any sophisticated error handling and is only intended to help with testing.
  def self.from_string( input_string )
    graph = ConditionGraph.new
    start_array = nil

    input_string.split(/[\n;]/).each do |line|
      if starts = @@start_matcher.match(line)
        start_array = starts[1].split(', ').map! { |s| s.to_i }
      elsif elements = @@line_matcher.match(line)
        conditions = Set.new elements[2].split(", ").map! { |n| n.to_i }
        transitions = Set.new elements[3].split(", ").map! { |s| s.to_sym }
        edges = elements[4] == 'end' ? nil : Set.new( elements[4].split(", ").map! { |n| n.to_i } )

        graph[ elements[1].to_i ] = ConditionsNode.new( conditions, transitions, edges, false )
      end
    end

    start_array.each { |s| graph[s].start_node = true }

    graph
  end

  ##
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

    self.each do |cond_node1|
      catch :do_match do
        # Now for this condition_node, see if we can find the same node in second
        # graph
        graph2.each do |cond_node2|
          catch :dont_match do
            if cond_node1.similar( cond_node2 )
              # make a copy of the edge list for cond_node2
              edge_list2 = Set.new cond_node2.edges

              # Now check that the edges are the same for both nodes.
              cond_node1.edges.each do | edge1 |
                throw :dont_match if !edge_list2.reject! { |edge2| self[ edge1 ].similar( graph2[ edge2 ] ) }
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
        # we break out hee.
        return nil
      end
      # if we get here, then its because we executed the :do_match.
    end
    return true
  end
  
  # This is a little helper function that can mix up a tree.  Used for testing
  # purposes.
  def shuffle
    nodemap = (0..self.length-1).to_a.shuffle
    new_graph = ConditionGraph.new( self.length )
    
    (0..self.length-1).each do |i|
      new_graph[ nodemap[i] ] = ConditionsNode.new( self[i].conditions,
        self[i].transitions,
        Set.new( self[i].edges ) { |e| nodemap[ e ] },
        self[i].start_node )
    end
    
    new_graph
  end
end
