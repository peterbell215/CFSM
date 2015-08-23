# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

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
    # @param [class] fsm_class is the class of FSM that can be evaluated
    # @param [Object] state_var is the state variable of the FSM class.  This needs to actually be a method on the FSM class
    def initialize(fsm_class, state_var)
      @fsm_class = fsm_class
      @state_var = state_var
    end

    attr_reader :state_var
    attr_reader :fsm_class

    ##
    # Comparator
    #
    # @param [FsmStateVariable] object2
    # @return [True,False]
    def ==(object2)
      self.fsm_class==object2.fsm_class && self.state_var==object2.state_var
    end

    ##
    # Override the standard hash key so that different instances that are == generate the same hash
    # key.
    # @return [Fixnum]
    def hash
      fsm_class.to_s.hash ^ state_var.to_s.hash
    end

    alias eql? ==
  end
end