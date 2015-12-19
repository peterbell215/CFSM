# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.

require 'logger'

require 'cfsm_event'
require 'cfsm_classes/transition'
require 'cfsm_classes/prio_queue'
require 'cfsm_classes/sorted_array'
require 'cfsm_classes/delayed_queue'
require 'condition_parser/parser'
require 'condition_parser/event_condition'
require 'condition_parser/event_attribute'
require 'condition_parser/fsm_state_variable'
require 'condition_parser/transformer'
require 'condition_parser/condition_cache'
require 'condition_optimisation/condition_permutations'
require 'condition_optimisation/condition_graph_factory'
require 'condition_optimisation/condition_graph'
require 'condition_optimisation/conditions_node'
require 'cfsm_classes/event_processor'

# This is the core class for the system.  The user defines CFSMs by deriving a new class from this class.
# The class definition includes the state machine definition.  For example:
#
# @example
#   class Telephone < CFSM
#     state :nothing_happening do
#       on :incoming_call, :transition => :ringing
#     end
#
#     state :ringing do
#       on :receiver_lifted, :transition => :connection
#     end
#   end
class CFSM
  class OnlyStartOnCFSMClass < Exception; end
  class EmptyCFSMClass < Exception; end
  class BlockAndExecDefined < Exception; end
  class TooLateToRegisterEvent < Exception; end
  class ComparingDelayedToLiveEvent < Exception; end
  class NonEventBeingCompared < Exception; end

  # Create the FSM.
  #
  # @param [Symbol, String] name the name of the FSM.  If no name is given, then the filename and line from which the
  #   the constructor was called are used as the name.
  def initialize( name = nil )
    processor = @@event_processors[ self.class.namespace ]
    processor.register_cfsm( self )
    @name = name || caller(1, 1)[0].split('/')[-1]
    @state = processor.initial_state( self.class )
  end

  # Returns the name of the FSM as declared at instantiation.
  attr_reader :name

  # Returns the current state of the finite state machine.
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
    event_processor = ( @@event_processors[self.namespace] ||= CfsmClasses::EventProcessor.new(self.namespace) )
    event_processor.register_events( self, state, other_parameters, &specs )
    self
  end

  # The system is designed on the premise that a number of state machine classes are created, FSMS instantiated,
  # and that these FSMS then run until the system terminates.  The system does not expect new classes of FSMs to
  # be added once the CFSM.start method is invoked.  This is not the case, when we are unit testing using Rspec.
  # This method allows us to reset the CFSM system to allow new state machines to be defined.
  def self.reset
    @@event_processors.each_value { |processor| processor.reset }
    @@event_processors = {}

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

    namespaces =
        if ( ns = options[:namespace])
          ns.is_a?(Array) ? ns : [ns]
        else
          @@event_processors.keys
        end

    namespaces.each do |namespace|
      @@event_processors[namespace.to_s].run(options)
    end

    # We have successfully started each processor.  Therefore we have no need for the parser.
    CfsmClasses::EventProcessor.shutdown_parser
  end

  # Used to post an event to all CFSM systems that need to know about it.
  #
  # @param [CfsmEvent] event
  def self.post( event )
    if event.expiry
      @@delayed_queue.post( event )
    else
      @@event_processors.each_value { |processor| processor.post( event ) }
    end
  end

  # Use to inform the system of a change in either a FSM's internal state, or an event's internal variables.
  def self.eval( obj )
    if obj.is_a? CFSM
      @@event_processors.each_value do |processor|
        processor.process_event if processor[obj.class]
      end
    elsif obj.is_a? CfsmEvent
      @@event_processors[ obj ].process_event
    end
  end

  def self.status
    @@event_processors.values.inject( {} ) { |hash, processor| hash[processor.namespace] = processor.status; hash  }
  end

  # Used to cancel an event posted into the system.
  #
  # @param [CfsmEvent] event cancel the event in the queue
  # @return [Boolean] returns whether cancelling of the event was successful
  def self.cancel( event )
    if @@delayed_queue.cancel( event )
      result = true
    else
      result = true
      @@event_processors.each_value { |processor| result &&= processor.cancel( event ) }
    end

    result
  end

  # Given a class of FSMs, this returns an array of instantiated FSMs of that class.
  #
  # @param [Class] fsm_class
  # @return [Array<CFSM>]
  def self.state_machines( fsm_class )
    @@event_processors[ fsm_class.namespace ][ fsm_class ]
  end

  # Output a string showing the state of the state machines.  This is not called inspect, since CFMS.inspect
  # is called from below.
  #
  # @return [String]
  def self.dump_to_string
    result = ''
    @@event_processors.each_value { |processor| result << processor.inspect }
    result
  end

  # Outputs the CFSM's name and state.
  #
  # @return [String]
  def inspect
    "<name = #{ name_as_string }, state = #{state}>"
  end

  # We provide a logger to track how the system is performing.  This is really just a frontend for the Logger
  # class.
  def self.logger
    @@logger
  end

  # This function allows the thread status for a specific namespace to be retrieved.
  def self.thread_status
    @@event_processors[ self.namespace ].thread_status
  end

  private

  # This holds for each namespace an EventProcessor that does the heavy lifting.  The user
  # can partition their system of communicating FSMs into independent sub-systems by placing
  # groups of FSMs into a module.  Each module has its own event_processor.  The following
  # hash maps from the module onto the individual event_processor.
  @@event_processors = {}

  # Provide a logger to be used throughout the system.
  File.delete('cfsm.log')
  @@logger = Logger.new('cfsm.log', 0)

  # We have one delayed event queue.  Once the event has expired, then we push it to the processors.
  @@delayed_queue = CfsmClasses::DelayedQueue.new do |event|
    event.reset_expiry
    post( event )
  end

  # Set the state - used by EventProcessor.  Use fsm.instance_exec( state ) { |s| set_state(s) } for
  # the event processor to set the state.
  #
  # @api private
  # @param [Symbol] s new state
  def set_state( s )
    CFSM.logger.info "#{name_as_string} in #{self.class.namespace} transitioning to state #{s.to_s}"
    @state = s
  end

  def name_as_string
    case name
      when String
        '"' << name << '"'
      when Symbol
        ':'<< name.to_s
      else
        name.to_s
    end
  end
end

