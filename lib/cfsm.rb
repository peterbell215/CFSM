# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

require 'cfsm_classes/event_processor'

class CFSM
  # Create the FSM.
  def initialize
    processor = @@eventprocessors[ self.class.namespace ]
    processor.register_cfsm( self )
    @state = processor.initial_state( self.class )
  end

  attr_reader :state

  # Related FSMs can be grouped into modules.  All FSMs that are part of the same module are deemed to be part of the
  # same name space.  This method takes the class name (e.g. CommsSystem::ModemInterface::Modem) and removes the last
  # part.  The rest (e.g. CommsSystem::ModemInterface) is considered to be the namespace.  If the CFSM's class is at
  # the top level (i.e. no proceeding modules), then the namespace is set to 'Global'.
  def self.namespace
    result = self.name.split('::').slice(0..-2).join('::')
    result.empty? ? 'Global' : result
  end

  # The core function that does the heavy lifting.  Delegates the real work to the EventProcessor object.
  #
  # @param state [Symbol] the state being defined
  # @param other_parameters [Hash] can be used to specify other parameters for the state machine.  For future expansion
  # @param specs [Proc] the body of the class definitions.  Contains the *on* calls.  Executed by the EventProcessor.
  # @return [CFSM] returns the CFSM object itself
  def self.state(state, other_parameters = {}, &specs)
    event_processor = ( @@eventprocessors[self.namespace] ||= CfsmClasses::EventProcessor.new(self.namespace) )
    event_processor.register_events( self, state, other_parameters, &specs )
    self
  end

  # The system is designed on the premise that a number of state machine classes are created, FSMS instantiated,
  # and that these FSMS then run until the system terminates.  The system does not expect new classes of FSMs to
  # be added once the CFSM.start method is invoked.  This is not the case, when we are unit testing using Rspec.
  # This method allows us to reset the CFSM system to allow new state machines to be defined.
  def self.reset
    @@eventprocessors.each_value { |processor| processor.reset }
    @@eventprocessors = {}

    # We have successfully started each processor.  Therefore we have no need for the parser.
    CfsmClasses::EventProcessor.restart_parser

    # Force a garbage collection.
    GC.start(:full_mark => :true)
  end

  # Starts the communicating finite state machine system.  The main action is to compile all the condition trees
  # into sets of RETE graphs for easier processing.  The standard approach to running the CFSM systems is async.
  # Here each CFSM system has a separate thread waiting on the input queue.  When an event is posted, control to
  # the posting process is returned immediately.  The CFSM system will then process the event asynchronously.  In
  # non-async mode, control is only returned to the posting process, once the event has been processed.
  #
  # @param [Hash] options defines various options for the start command
  # @option options [Array<Module>,Module] :namespace defines the namespace that should be started.  If missing all namespaces are started.
  # @option options [True,False] :sync defines whether the execution of the namespaces should be run synchronous,
  def self.start( options = {} )
    raise OnlyStartOnCFSMClass if self != CFSM

    namespaces = options.delete( :namespace )
    if namespaces
      processors = namespaces.is_a? Array ? namespaces : [ namespaces ]
    else
      processors = @@eventprocessors.keys
    end

    processors.each { |processor| @@eventprocessors[processor].run( options ) }

    # We have successfully started each processor.  Therefore we have no need for the parser.
    CfsmClasses::EventProcessor.shutdown_parser
  end

  # Used to post an event to all CFSM systems that need to know about it.
  #
  # @param [CfsmEvent] event
  def self.post( event )
    @@eventprocessors.each_value { |processor| processor.post( event ) }
  end

  # Use to inform the system of a change in either a FSM's internal state, or an event's internal variables.
  def self.eval( obj )
    if obj.is_a? CFSM
      @@eventprocessors.each_value do |processor|
        processor.process_event if processor[obj.class]
      end
    elsif obj.is_a? CfsmEvent
      @@eventprocessors[ obj ].process_event
    end
  end

  # Used to cancel an event posted into the system.
  #
  # @param [CfsmEvent] event cancel the event in the queue
  # @return [true,false] returns whether cancelling of the event was successful
  def self.cancel( event )
    result = true
    @@eventprocessors.each_value { |processor| result &&= processor.cancel( event ) }
    return result
  end

  # Given a class of FSMs, this returns an array of instantiated FSMs of that class.
  #
  # @param [Class] fsm_class
  # @return [Array<CFSM>]
  def self.state_machines( fsm_class )
    @@eventprocessors[ fsm_class.namespace ][ fsm_class ]
  end

  private

  # This holds for each namespace an EventProcessor that does the heavy lifting.  The user
  # can partition their system of communicating FSMs into independent sub-systems by placing
  # groups of FSMs into a module.  Each module has its own event_processor.  The following
  # hash maps from the module onto the individual event_processor.
  @@eventprocessors = {}

  # Set the state - used by EventProcessor.  Use fsm.instance_exec( state ) { |s| set_state(s) } for
  # the event processor to set the state.
  #
  # @api private
  # @param [Symbol] s new state
  def set_state( s )
    @state = s
  end
end
