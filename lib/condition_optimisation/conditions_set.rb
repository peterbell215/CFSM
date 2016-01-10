# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.

module ConditionOptimisation
  # Represents a set of conditions that under AND can cause a number of transitions.
  class ConditionsSet
    # Constructor for a conditions set.  Note, it creates copies of its input parameters to ensure that the originals
    # are not affected by subsequent operations on the ConditionSet.
    #
    # @param conditions [Set<EventCondition>] defines the set of conditions all of which must be true for the transition to be executable
    # @param transitions [Set<Transitions>] defines the set of transitions to be raised if the conditions are true
    # @return [ConditionsNode]
    def initialize( conditions, transitions )
      @conditions = Set.new( conditions )   # make a copy
      @transitions = Set.new( transitions ) # make a copy
    end

    # This is checking whether the two nodes are close enough to then do a closer examination
    # examination.
    # @param [ConditionsSet] cond_node2
    # @return [Boolean]
    def similar( cond_node2 )
      self.conditions == cond_node2.conditions && self.transitions == cond_node2.transitions
    end

    # @return [String] a string description of the ConditionSet in the form `{cond1, cond2} [tran1, tran2]`
    def inspect
      "{#{self.conditions.to_a.map{|t|t.inspect}.join(', ')}} [#{self.transitions.to_a.map{|t| t.to_s}.join(', ')}]"
    end

    # Make sure that any conditions added to the ConditionsNode is a set.
    def conditions=( conds )
      @conditions = ( conds.is_a? Set ) ? conds : Set.new( conds )
    end

    attr_reader :conditions
    attr_reader :transitions
  end
end