# @author Peter Bell
# Licensed under MIT

require 'cfsm_classes/event_processor'

class NoInitialState < Exception; end
class ConflictingInitialStates < Exception; end

class CFSM
  # This holds for each namespace an EventProcessor that does the heavy lifting.  The user
  # can partition their system of communicating FSMs into independent sub-systems by placing
  # groups of FSMs into a module.  Each module has its own event_processor.  The following
  # hash maps from the module onto the individual event_processor.
  @@eventprocessors = {}

  def self.namespace
    result = self.name.split('::').slice(0..-2).join('::')
    result.empty? ? 'Global' : result
  end

  ##
  # Create the FSM.
  def initialize
    processor = @@eventprocessors[ self.class.namespace ]
    processor.register_cfsm( self )
    @state = processor.initial_state( self.class )
  end

  attr_reader :state

  # the core function that does the heavy lifting.
  # @return [Object]
  def self.state(state, other_parameters, &exec_block)
    # Make sure the key mandatory parameters are defined in other_parameters
    raise OnMissing unless other_parameters[:on]
    raise TransitionMissing unless other_parameters[:transition]

    event_processor = (@@eventprocessors[self.namespace] ||= CfsmClasses::EventProcessor.new)

    event_processor.register_initial_state( self, state ) if other_parameters[:initial]
    event_processor.register_event( other_parameters[:on], self, state, other_parameters[:transition] )
  end

  ##
  # Starts the communicating finite state machine system.  The main action is to compile all the condition trees
  # into sets of RETE graphs for easier processing.
  def self.start
    processor = @@eventprocessors[ self.namespace]
    processor.cache_conditions
    processor.convert_trees_to_sets
    processor.convert_sets_to_graph
    processor.run
  end

  # Used to post an event to all CFSM systems that need to know about it.
  def self.post( event )
    @@eventprocessors.each_value { |processor| processor.post( event )}
  end
end
