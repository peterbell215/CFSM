# @author Peter Bell
# Licensed under MIT2

module ConditionParser
  ##
  # Holds an event condition that needs to be evaluated.
  class EventCondition
    attr_reader :comparator
    attr_reader :attribute
    attr_reader :value

    ##
    # Factory method to provide a convenient way of creating an EventCondition to
    # check the current state of the FSM.
    #
    # @param [Class] fsm
    # @param [Symbol] state
    # @return [EventCondition]
    def self.fsm_state_checker(fsm_class, state)
      EventCondition.new(:==, FsmStateVariable.new( fsm_class, "state" ), state)
    end

    ##
    # Constructor
    #
    # @param comparator [Symbol] the comparison to be undertaken
    # @param attribute [String] the attribute to tested
    # @param [Object] value the value it should be compared to
    def initialize( comparator, attribute, value )
      @comparator = comparator
      @attribute = attribute
      @value = value
    end

    # @param [EventCondition] object2
    # @return [True,False]
    def ==(object2)
      self.comparator == object2.comparator && self.attribute == object2.attribute && self.value == object2.value
    end
  end
end