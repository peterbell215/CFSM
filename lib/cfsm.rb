# @author Peter Bell
# Licensed under MIT

require 'cfsm_classes/event_processor'

class NoInitialState < Exception; end
class ConflictingInitialStates < Exception; end

class CFSM
  ##
  # This class variable holds a list of all instantiated FSMs. It holds the data as a hash of FSM Class to
  # an array of all instantiated FSMs.
  @@cfsms = {}

  ##
  # This class variable holds a list of initial states for all defined classes of CFSM.  It is a hash of
  # class to state.
  @@cfsm_initial_state = {}

  ##
  # Used to define the initial state of CFSM class.
  def self.set_cfsm_initial_state( fsm_class, initial_state )
    @@cfsm_initial_state[ fsm_class ] = initial_state
  end

  ##
  # Create the FSM.
  def initialize
    if @@cfsms[ self.class ]
      @@cfsms[ self.class ].push( self )
    else
      @@cfsms[ self.class ] = [ self ]
    end

    raise NoInitialState unless ( @state = @@cfsm_initial_state[ self.class ] )
  end

  attr_reader :state

  # the core function that does the heavy lifting.
  # @return [Object]
  def self.state(state, other_parameters, &exec_block)
    # Make sure the key mandatory parameters are defined in other_parameters
    raise OnMissing unless other_parameters[:on]
    raise TransitionMissing unless other_parameters[:transition]

    # check if an initial state is indicated.
    if other_parameters[:initial]
      unless @@cfsm_initial_state[ self ]
        @@cfsm_initial_state[ self ] = state
      else
        raise ConflictingInitialStates
      end
    end

    CfsmClasses::EventProcessor::register_event( other_parameters[:on], self, state, other_parameters[:transition] )
  end
end
