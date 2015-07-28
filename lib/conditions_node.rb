# @author Peter Bell
# Licensed under MIT2.

##
# Uses to represent a condition node within a directed graph of conditions.
# The directed graph shows the RETE decision tree.
class ConditionsNode
  ##
  # Constructor for a condition node.
  #
  # @param conditions [Set] defines the set of conditions all of which must be true for the condition node to be true
  # @param transitions [Set<Fixnum>] defines the set of transitions to be raised if the conditions are true
  # @param edges [Set<Fixnum>] defines the set of follow conditions within the graph
  # @param start_node [Set<Fixnum.] defines whether this node is a starting node
  # @return [ConditionsNode]
  def initialize( conditions, transitions, edges = [], start_node = true )
    @start_node = start_node
    @conditions = Set.new( conditions ) # make a copy
    @transitions = Set.new( transitions ) # make a copy
    @edges = Set.new( edges ) # make a copy
  end

  def clone
    ConditionsNode.new( self.conditions, self.transitions, self.edges, self.start_node )
  end

  ##
  # This is checking whether the two nodes are close enough to then do a closer examination
  # examination.
  def similar( cond_node2 )
    self.conditions == cond_node2.conditions &&
      self.transitions == cond_node2.transitions &&
      self.start_node == cond_node2.start_node &&
      self.edges.length == cond_node2.edges.length
  end

  ##
  # Make sure that any conditions added to the ConditionsNode is a set.
  def conditions=( conds )
    @conditions = ( conds.is_a? Set ) ? conds : Set.new( conds )
  end

  attr_reader :conditions
  attr_accessor :start_node
  attr_accessor :transitions
  attr_accessor :edges
end
