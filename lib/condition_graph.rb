# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'conditions_node'

class ConditionGraph < Array

  alias :nr_nodes :length

  ##
  # A chain is a hash of one element containing a set of conditions, and
  # a transition description.  So a chain might be:
  #
  #   { [:c1, :c2, :c3, :c4] => :fsm1_transition }
  #
  # This describes that if conditions :c1 to :c4 are fulfilled, then the
  # :fsm1_transition should be performed.
  #
  # This static methods job is to merge two chains in the above description into
  # a single representation. So if one chain is a sub-set of the other, this
  # method would do the following mapping:
  #
  # { [:c1, :c2, :c3, :c4] => :fsm1_transition }
  # { [:c1, :c2] => :fsm2_transition }
  #
  # becomes
  #
  # { [:c1, :c2] => :fsm2_transition, [:c3, :c4] => :fsm1_transition }
  #
  # The other interesting case is if the two condition sets share some common
  # elements, but also have some differences:
  #
  # { [:c1, :c2, :c3, :c4] => :fsm1_transition }
  # { [:c1, :c2, :c5, :c6] => :fsm2_transition }
  def add_conditions( anded_conditions, transition )
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
              self[ index ] = ConditionsNode.new( obj.conditions & anded_conditions, [transition], [ self.length ], false )
              obj.conditions = obj.conditions - anded_conditions
              self.push( obj )
              break
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
    string = "start:"
    self.each_with_index { |obj, ind| string << " #{ind.to_s}" if obj.start_node }
    string << "\n"
    
    # Print each line
    self.each_with_index do |obj,ind|
      string << "#{ind}: {#{obj.conditions.to_a.join(", ")}} "\
        "[#{obj.transitions.to_a.join(", ")}] "\
        "-> #{ obj.edges.empty? ? "end" : obj.edges.to_a.join(", ")}\n"
    end
    string
  end
  
  def ==(graph2)
    # Check that they are the same length.
    return false if self.nr_nodes != graph2.nr_nodes

    self.each_with_index do |cond_node1, index|
      catch :do_match do
        # Now for this condition_node, see if we can find the same node in second
        # graph
        graph2.each_with_index do |cond_node2, index|
          catch :dont_match do           
            if cond_node1.similar( cond_node2 )
              # make a copy of the edge list for cond_node2
              # byebug unless cond_node2.edges.is_a? Set
              
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
