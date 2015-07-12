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
      self.push( ConditionsNode.new(anded_conditions, transition) )
    else
      # Search through the array to see if the new conditions are
      # already contained in array graph as a condition node.
      self.each_with_index do |obj, index|
        if !obj.startnode
          self.insert(index, ConditionsNode.new( anded_conditions, transition ) )
          break
        elsif anded_conditions == obj.conditions
          # the two are the same.  Therefore, simply add transition to the set
          # of transitions on this node.
          self[index].addTransition( transitions )
          break
        elsif anded_conditions < obj.conditions
          self[ index ] = ConditionsNode.new( obj.getConditions & anded_conditions, transition, false )
          self[ index ].edges = [ self.length ]
          self.push( @obj.conditions( obj.conditions - anded_conditions ) )
          break
        end
      end
    end
  end

  def ===(graph2)
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
              edge_list2 = Array.new cond_node2.edges

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
        Array.new( self[i].edges.length ) { |e| nodemap[ self[i].edges[e] ] },
        self[i].start_node )
    end
    
    new_graph
  end
end
