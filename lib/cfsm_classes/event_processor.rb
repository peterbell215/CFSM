# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

require 'cfsm_classes/transition'
require 'cfsm_classes/prio_queue'
require 'condition_parser/parser'
require 'condition_parser/fsm_state_variable'
require 'condition_parser/transformer'
require 'condition_parser/condition_cache'
require 'condition_optimisation/condition_graph'
require 'condition_optimisation/condition_permutations'

module CfsmClasses
  class TooLateToRegisterEvent < Exception; end

  # This class hides the implementation complexities of the Communicating FSM system.  It is really only to be invoked from
  # methods within the CFSM class
  #
  # @api private
  class EventProcessor
    include ConditionOptimisation::ConditionPermutations

    # Constructor.  Creates an instance of EventProcessor.
    # @param [String] namespace
    def initialize( namespace )
      @status = :initialising

      # keep a record of the namespace.
      @namespace = namespace

      # Used to store runtime options.
      @options = nil

      ##
      # This variable holds a list of all instantiated FSMs within the namespace. It holds the data as a hash of class to
      # an array of all instantiated FSMs.
      @cfsms = {}

      ##
      # This variable holds a list of initial states for all defined classes of CFSM.  It is a hash of
      # class to state.
      @cfsm_initial_state = {}

      # Hash that provides the collection of parameters that need to be evaluated for a given event_class type.
      #
      # While the CFSMs are being constructed, the hash will point to an array of EventTrees.  Each
      # event_class tree represents a condition tree and the transition that will produced.  Example:
      #
      #   @parameters[ :event_a ] =
      #     EventTree[0] = <
      #       @condition_tree = { :and => [
      #         StateCheck( FsmA, :state_a ), ConditionNode( :==, 'a', 'Peter' ) },
      #         @transition = Transition( FsmA, :state_b ) }
      # If event_a is raised, and FsmA is in state_a, and the message contains a field 'a' that has value 'Peter', then
      # FsmA should transition to state_b.
      #
      # The array is then converted into a Hash of ANDed Conditions and the transition.  Details
      # in condition_permutations.rb.
      #
      # This is in turn turned into a ConditionGraph representing the tests that need to be carried out
      # together with the transitions.  Details in condition_graph.rb
      @conditions = {}

      # In order to facilitate faster manipulation of the parameters during the optimisation we cache the
      # parameters in this Hash together with an integer.  The Caches are in turn hashed onto the EventConditions.
      @condition_cache = {}
    end

    attr_reader :status
    attr_reader :namespace

    # This does the heavy lifting for when the programmer defines a state.
    #
    # @param [Class] klass is the class of FSMs for which this event_class is being defined
    # @param [Symbol] state
    # @param [Object] other_params
    # @param [Object] exec_block
    def register_events( klass, state, other_params, &exec_block)
      @klass_being_defined = klass
      @state_being_defined = state

      # if an initial state has not been set, then set it. In practice, means the first state defintion
      # gets the initial state.
      @cfsm_initial_state[ klass ] = state unless @cfsm_initial_state[ klass ]

      # Evaluate the transition definitions
      self.instance_eval( &exec_block ) if exec_block

      @klass_being_defined = nil
      @state_being_defined = nil
    end

    # Class method to register that a FSM reacting to an event_class while in a defined state and transitioning to a new state.
    #
    # @api private
    #
    # @param event_class [Class,symbol] the event_class that we are reacting too.
    # @param parameters [String] the parameters that the FSM must meet to
    # @param proc [Proc] a method to be executed as part of the state transition
    def on( event_class, parameters = {}, &proc )
      # Create an array to hold the condition trees and their respective transitions.
      @conditions[ event_class ] ||= Array.new

      # Make sure we have not yet passed the point of turning this into a ConditionGraph.
      raise TooLateToRegisterEvent if @conditions[ event_class ].is_a? ConditionOptimisation::ConditionGraph

      # Create a parse tree with at least a state check.
      fsm_check = ConditionParser::EventCondition::fsm_state_checker(@klass_being_defined, @state_being_defined)
      if_tree = unless parameters[:if].nil?
                  { :and => [ fsm_check, @@parser.process_if(parameters[:if], event_class, @klass_being_defined) ] }
                else
                  fsm_check
                end

      # Create the transition object
      transition = CfsmClasses::Transition.new( @klass_being_defined, parameters[:transition], proc )

      # Store the event_class.
      @conditions[event_class].push Struct::EventTree.new( if_tree, transition )
    end

    # Retrieves the initial state for this class of FSM.  If it is not defined, raises an error.
    #
    # @api private
    #
    # @param [Class] cfsm_class
    # @return [Symbol]
    def initial_state( cfsm_class )
      @cfsm_initial_state[ cfsm_class ]
    end

    # Registers an instance of a CFSM with the event_class processor.  Used by the constructor of the CFSM.
    #
    # @api private
    #
    # @param [CFSM] cfsm
    # @return [Symbol] initial state for the FSM
    def register_cfsm( cfsm )
      ( @cfsms[ cfsm.class ] ||= Array.new ).push( cfsm )
    end

    # Returns an array of instantiated FSMs for the specific class.
    #
    # @param [Class] cfsm
    # @return [Array<CFSM>] array of FSMs of correct type
    def []( cfsm )
      @cfsms[ cfsm ]
    end

    # Creates the queue for this event_class processor.  If the event_class processor is to operate in async mode, also
    # creates the processing thread and starts waiting for events to be queued.
    def run( options )
      @status = :running

      @options = options

      # Do the heavy lifting on converting the condition trees to optimised condition graphs.
      cache_conditions
      convert_trees_to_sets
      convert_sets_to_graph

      # For each CFSM namespace, we also have a queue to hold unprocessed events.
      @event_queue ||= PrioQueue.new

      # We also create a Hash to a mapping between delayed events and the thread that is used to
      # wait.
      @delayed_event_hash = {}

      # Ensure only one thread is actually in the process_event method.
      @process_mutex = Mutex.new

      # In order to avoid race conditions on the delayed_event_hash we also declare a mutex.
      @delayed_event_mutex = Mutex.new

      # If running in sync mode, we set @thread to true to indiciate the EventProcessor has been set to
      # run.  If we are running in async mode then create a thread with an infinite loop to process incoming events.
      @thread = @options[:sync] || Thread.new do
        loop do
          @status = :waiting_for_event
          @event_queue.wait_for_new_event
          process_event
        end
      end
    end

    # Used in the context of CFSM.reset to close down this event_class processor in a clean manner.  Should
    # only be used with RSpec when running a new set of state machine tests.
    def reset
      @delayed_event_hash.each_key { |event| self.cancel( event ) } if @delayed_event_hash
      @delayed_event_mutex = nil

      @thread.kill if @thread.is_a? Thread
      @thread = nil

      # This unloads any classes derived from CFSM.  It does this by looking at all currently loaded classes,
      # and checking if they are derived from CFSM.  IF they are, we split them into the module reference and
      # the class name as a symbol.  We then use remove_const to get rid of them.
      ObjectSpace.each_object( Class ).select do |klass|
        if klass < CFSM
          module_name = klass.to_s.split('::')[0..-2].join('::')
          module_ref = module_name.empty? ? Object : Object.const_get( module_name )
          class_sym = klass.to_s.split('::')[-1].to_sym
          if module_ref.constants.index class_sym
            module_ref.instance_exec( class_sym ) { |k| remove_const( k ) }
          end
        end
      end
    end

    # Receives an event_class for consideration by the event_class processor.  So long as the EventProcessor has
    # been started and we have a ConditionGraph
    # for that event_class we stick it into the queue for processing.  If we are not operating in async mode,
    # then we also process the event_class.
    # @param event [CfsmEvent] the event being posted.
    def post( event )
      if @thread && @conditions[ event.event_class ]
        if event.delay > 0
          # TODO rather than have one thread per delayed event_class, we should have a sorted queue with a single thread
          @delayed_event_hash[ event ] = Thread.new do
            set_event_status(event, :delayed )
            # wait for the delay to expire in the thread.
            sleep event.delay
            # Avoid race conditions by preventing any other threads updating the delayed_event_hash
            @delayed_event_mutex.synchronize do
              # If the event_class still exists in the delayed_event_hash, remove it and post it into the main queue.
              if @delayed_event_hash.delete(event)
                set_event_status(event, :pending )
                @event_queue.push event
              end
            end
          end
        else
          set_event_status(event, :pending )
          @event_queue.push event
        end
        process_event if @thread==true
      end
    end

    # Cancel a posted event_class.  Mainly used to cancel events due at point in the future.  However, can also
    # be used to cancel an event_class that is in the main queue, but has not yet been acted on.
    #
    # @param [CfsmEvent] event
    # @return [true,false] whether the event_class was still around to be cancelled.
    def cancel( event )
      case event.status
        when :delayed
          @delayed_event_mutex.synchronize do
            if ( thread = @delayed_event_hash.delete(event) )
              thread.kill
              set_event_status(event, :cancelled)
              return true
            end
          end
        when :pending
          set_event_status(event, :cancelled)
          return @event_queue.remove( event )
      end
    end

    # Normally, we shut the parser down once we have evaluated all state machine descriptions.  If we are running
    # RSpec then we may need to restart it.
    def self.restart_parser
      @@parser = ConditionParser::Parser.new
    end

    # Look at each event_class in priority order until it can find one to process. If it can, then it removes that
    # event_class from the queue and executes the transitions.  Returns the identified event_class.  If no events can be found
    # returns nil to allow the calling method to perform a wait_for_next_event.
    def process_event
      @process_mutex.synchronize do
        @status = :process_event
        @event_queue.peek_each do |event|
          # we use fsms to keep track of which FSMs are in the right state to meet the requirements.
          transitions =
              @conditions[event.event_class].execute(event,
                                                     ->(event, condition, fsms) do
                                                       # condition evaluation
                                                       @condition_cache[event.event_class][condition].evaluate(event, fsms)
                                                     end,
                                                     ->(transition, fsms) do
                                                       # transition instantiation
                                                       transition.instantiate( fsms )
                                                     end)

          unless transitions.empty?
            @event_queue.remove( event )

            # we have a number of transactions to process, so lets do the state transitions.
            transitions.each do |t|
              if t.transition_proc.nil? || t.transition_proc && t.fsm.instance_exec( t.transition_proc.call )
                t.fsm.instance_exec( t.new_state ) { |s| set_state(s) }
              end
            end

            set_event_status( event, :processed )

            # we have managed to process the event_class, so exit process event_class.
            return event
          end
        end
        # if we get to here, we have been through all events in the queue and cannot process any.  Need to
        # wait for something to change.
        return nil
      end
    end

    def inspect
<<HEREDOC
Namespace: #{self.namespace}
Thread status: #{ thread_status }
Condition graph: N/A
Current queue: #{ @event_queue ? '\n' << @event_queue.inspect : 'uninitialised' }
Status of each FSM:
#{cfsm_inspect}
**************************
HEREDOC
    end

    private

    # Take all the condition trees associated with this EventProcessor and populate the @conditions_cache
    # hash.
    # @api private
    def cache_conditions
      @conditions.each_pair do |event, condition_trees|
        @condition_cache[event] ||= ConditionParser::ConditionCache.new
        condition_trees.each do |tree|
          tree.condition_tree = ConditionParser::Transformer.cache_conditions(@condition_cache[event],
                                                                              tree.condition_tree)
        end
      end
    end

    # On calling each entry in the @conditions hash is an array of EventTrees.  Each element consists of
    # a transformed parse tree and a transition for that parse tree.  Replaces the array of EventTrees with
    # a Hash of condition sets and transitions.  Each condition set holds a set of conditions that must
    # hold true for the transition to be performed.
    # @return [Object]
    def convert_trees_to_sets
      @conditions.each_pair do |event, condition_trees|
        condition_sets = {}
        condition_trees.each do |event_tree|
          ConditionParser::Transformer::generate_permutations( event_tree.condition_tree ).each do |permutation|
            condition_sets[permutation] = event_tree.transition
          end
        end
        @conditions[event] = condition_sets
      end
    end

    # On calling each entry in the @conditions hash is a Hash of a condition set to a Transition.  This then
    # uses the permutation optimiser to construct the optimal graph for each entry.  On leaving @conditions
    # is a Hash from Event onto ConditionGraph.  Each ConditionGraph can then be executed on receiving the
    # event_class to determine if the transition should happen.
    def convert_sets_to_graph
      @conditions.each_pair do | event, condition_sets |
        @conditions[event] = self.permutate_graphs( condition_sets ).find_optimal
      end
      self
    end

    # Create single instances of the parser and the transformer.
    @@parser =  ConditionParser::Parser.new

    # In order to save memory, we remove the parser, once we have parsed and converted all trees.
    def self.shutdown_parser
      self.remove_class_variable :@@parser
    end

    # The status is something that should only be set by EventProcessor.  Therefore, it is a private method
    # on CfsmEvent.  This helper function allows us to set the status.
    def set_event_status( event, status )
      event.instance_eval { @status = status }
    end

    # This private method returns the status of the event processor's thread as a string.
    #
    # @return [String] status of the thread
    def thread_status
      if @thread.nil?
        'not started'
      elsif @thread==true
        'sync mode'
      else
        @thread.status
      end
    end

    # Private method to assemble a string showing state of each CFSM within the namespace.
    #
    # @return [String]
    def cfsm_inspect
      result = ''
      @cfsms.each_pair do |klass, cfsms|
        result << "#{klass.to_s} : #{cfsms.join(', ')}\n"
      end
    end

    # Used to hold the condition tree and transition descriptions in the @@event_processors hash.
    Struct.new('EventTree', :condition_tree, :transition )
  end
end