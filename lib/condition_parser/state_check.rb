# @author Peter Bell
# Licensed under MIT2

module ConditionParser
  ##
  # Holds a check of the state that needs to be considered.  In our implementation which state
  # a specific FSM is in is considered just another condition similar to the other tests.  The
  # reasoning is that you might have a number of state machines all testing the same conditions.
  # This way the RETE graph can check all of those conditions before finally checking state,
  # leading to an optimised state.
  class StateCheck
    ##
    # Constructor
    #
    # @param fsm [Class] class of the FSM
    # @param state [Object]
    def initialize(fsm, state)
      @fsm = fsm
      @state = state
    end

    attr_reader :fsm
    attr_reader :state
  end
end