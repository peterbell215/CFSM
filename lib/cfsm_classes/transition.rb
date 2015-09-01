# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

module CfsmClasses
  ##
  # Used to describe a state transition.
  class Transition
    # @param fsm [Class] the class of FSMs to which this transition applies
    # @param new_state [Symbol] the new state in which the FSM will be
    # @param [Proc] transition_proc code to be executed if transition happens
    def initialize( fsm, new_state, transition_proc )
      @fsm = fsm
      @new_state = new_state
      @transition_proc = transition_proc
    end

    # The FSM can be overwritten by a specific FSM.
    attr_accessor :fsm
    attr_reader :new_state
    attr_reader :transition_proc

    # The transition normally stores the class of FSM for which the transition applies,
    # This method takes that class and creates an array of transitions for specific
    # instances of FSMs.
    # @param [Array<CFSM>] included_fsms
    # @return [Array<Transition>] the array of instantiated transitions
    def instantiate( included_fsms )
      CFSM.state_machines( self.fsm ).inject([]) do |transitions, fsm|
        if included_fsms == :all || included_fsms.member?( fsm )
          transitions << Transition.new( fsm, self.new_state, self.transition_proc )
        end
        transitions
      end
      # note transitions returned from loop, so implicitely returned from method
    end
  end
end
