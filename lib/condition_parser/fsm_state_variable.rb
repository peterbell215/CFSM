# @author Peter Bell
# Licensed under MIT2

module ConditionParser
  ##
  # Holds a check of the state that needs to be considered.  In our implementation which state
  # a specific FSM is in is considered just another condition similar to the other tests.  The
  # reasoning is that you might have a number of state machines all testing the same conditions.
  # This way the RETE graph can check all of those conditions before finally checking state,
  # leading to an optimised state.
  class FsmStateVariable
    ##
    # Constructor
    #
    # @param fsm [Class] class of the FSM
    # @param state [Object]
    def initialize(fsm_class, state)
      @fsm_class = fsm_class
      @state = state.to_s
    end

    attr_reader :state
    attr_reader :fsm_class

    ##
    # Comparator
    #
    # @param [FsmStateVariable] object2
    # @return [True,False]
    def ==(object2)
      self.state==object2.state && self.state==object2.state
    end
  end
end