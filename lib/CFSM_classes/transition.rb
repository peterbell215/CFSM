# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.

require 'pathname'

module CFSMClasses
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
      # note transitions returned from loop, so implicitly returned from method
    end

    # Turn the transition into a string description.
    def inspect
      result = "Transition: #{fsm.name} to #{new_state}"
      case self.transition_proc
        when Proc
          filename, line = self.transition_proc.source_location
          result << " on exec of #{Pathname.new(filename).basename}:#{line}"
        when Symbol
          result << " on exec of #{transition_proc.to_s}"
      end
      result
    end

    alias to_s inspect
  end
end
