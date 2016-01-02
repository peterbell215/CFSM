# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.

module ConditionOptimisation
  # Uses to represent a condition node within a directed graph of conditions.
  # The directed graph shows the RETE decision tree.
  class ConditionsNode
    # Constructor for a condition node.
    #
    # @param conditions [Set<EventCondition>] defines the set of conditions all of which must be true for the condition node to be true
    # @param transitions [Set<Fixnum>] defines the set of transitions to be raised if the conditions are true
    # @param edges [Set<Fixnum>] defines the set of follow conditions within the graph
    # @return [ConditionsNode]
    def initialize( conditions, transitions, edges = [] )
      @conditions_set = ConditionsSet.new( conditions, transitions )
      @edges = Set.new( edges ) # make a copy
    end

    def clone
      ConditionsNode.new( self.conditions, self.transitions, self.edges )
    end

    # This is checking whether the two nodes are close enough to then do a closer examination
    # examination.
    # @param [ConditionsNode] cond_node2 node being compared to for similarity
    # @return [Boolean]
    def similar( cond_node2 )
      self.conditions_set.similar( cond_node2 ) && self.edges.length == cond_node2.edges.length
    end

    # Generate a string description of the object.
    # @return [String]
    def inspect
      "#{self.conditions_set.inspect} -> #{ self.edges.empty? ? 'end' : self.edges.to_a.map{|e| e.inspect}.join(', ')}"
    end

    # Accessor function to retrieve the set of conditions.
    #
    # @return [Set<EventCondition>] the set of event conditions to be evaluated by this node.
    def conditions
      @conditions_set.conditions
    end

    # Accessor function to retrieve the set of transitions.
    #
    # @return [Set<Fixnum>]
    def transitions
      @conditions_set.transitions
    end

    # Make sure that any conditions added to the ConditionsNode is a set.
    #
    # @param [Set<EventCondition>] conds the new set of conditions for this condition node.
    # @return [Set<EventCondition>] the condition set passed to it.
    def conditions=( conds )
     @conditions_set.conditions = conds
    end

    attr_reader :conditions_set
    attr_accessor :edges
  end
end