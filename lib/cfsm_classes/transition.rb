# @author Peter Bell
# Licensed under MIT

module CfsmClasses
  ##
  # Used to describe a state transition.
  class Transition
    # @param fsm [Class] the class of FSMs to which this transition applies
    # @param new_state [Symbol] the new state in which the FSM will be
    def initialize( fsm, new_state )
      @fsm = fsm
      @new_state = new_state
    end

    attr_reader :fsm
    attr_reader :new_state
  end
end
