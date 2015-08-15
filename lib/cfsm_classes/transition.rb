# @author Peter Bell
# Licensed under MIT

module CfsmClasses
  ##
  # Used to describe a state transition.
  class Transition
    # @param fsm [Class] the class of FSMs to which this transition applies
    # @param new_state [Symbol] the new state in which the FSM will be
    # @param [Proc] proc code to be executed if transition happens
    def initialize( fsm, new_state, &proc )
      @fsm = fsm
      @new_state = new_state
      @proc = proc
    end

    # The FSM can be overwritten by a specific FSM.
    attr_accessor :fsm
    attr_reader :new_state
  end
end
