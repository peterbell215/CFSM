# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.

module CfsmClasses
  # This class hides the implementation complexities of the Communicating FSM system.  It is really only to be invoked from
  # methods within the CFSM class.  Each event processor looks after one namespace and all FSMs withint that namespace.
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
      # parameters.  The ConditionCache holds an array of EventConditons with all tests stored only once in
      # the EventCondition.  This allows faster manipulation of the tree during optimisation since when comparing
      # conditions we can do this simply on object_id rather than on the whole EventCondition.
      #
      # Once optimisation is complete, this array can be discarded.
      @condition_cache = ConditionParser::ConditionCache.new
    end

    # @return [:initialising,:process_event,:running,:waiting_for_event] current activity for this event processor.
    attr_reader :status

    # @return [String,Symbol] name of event space for this event processor.
    attr_reader :namespace

    # This does the heavy lifting for when the programmer defines a state.  So when the user has written:
    #
    #   class MyFSM < CFSM
    #     state :a do
    #
    # This is converted by CFSM into a call to this method:
    #
    #   register_events(MyFSM, :a, &proc with on statements)
    #
    # @param [Class] klass is the class of FSMs for which this event_class is being defined
    # @param [Symbol] state
    # @param [Hash] other_params this is here for future expansion but is not used at the moment.
    # @param [Proc] exec_block this provides the code that actually defines the behaviours in terms of events and how
    #   to react to events
    # @return [void]
    def register_events(klass, state, other_params, &exec_block)
      @klass_being_defined = klass
      @state_being_defined = state

      # if an initial state has not been set, then set it. In practice, means the first state definition
      # gets the initial state.
      @cfsm_initial_state[ klass ] = state unless @cfsm_initial_state[ klass ]

      # Evaluate the transition definitions
      self.instance_eval( &exec_block ) if exec_block

      @klass_being_defined = nil
      @state_being_defined = nil
      @other_params = other_params
    end

    # Class method to register that a FSM can react to an event_class while in a defined state and that it can
    # transition to a new state.  The actual on statement would be found in the class derived from CFSM.
    #
    # @!scope Class
    # @param event_class [Class,symbol] the event_class that we are reacting too.
    # @param parameters [String] the parameters that the FSM must meet to
    # @param proc [Proc] a method to be executed as part of the state transition
    # @raise [BlockAndExecDefined] if both an action block and action method is defined.  The exception class
    #     description includes an example
    # @return [void]
    def on( event_class, parameters = {}, &proc )
      # Create an array to hold the condition trees and their respective transitions.
      @conditions[ event_class ] ||= Array.new

      # Make sure we have not yet passed the point of turning this into a ConditionGraph.
      raise TooLateToRegisterEvent if @conditions[ event_class ].is_a? ConditionOptimisation::ConditionGraph

      # Create a parse tree with at least a state check.
      fsm_check = ConditionParser::EventCondition::fsm_state_checker(@klass_being_defined, @state_being_defined)
      if_tree = if parameters[:if].nil?
                  fsm_check
                else
                  {:and => [fsm_check, @@parser.process_if(parameters[:if], event_class, @klass_being_defined)]}
                end

      # Create the transition object
      raise BlockAndExecDefined if proc && parameters[:exec]
      proc ||= parameters[:exec]
      transition = CfsmClasses::Transition.new( @klass_being_defined, parameters[:transition], proc )

      # Store the event_class.
      @conditions[event_class].push Struct::EventTree.new( if_tree, transition )
    end

    # Retrieves the initial state for this class of FSM.
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

    # Creates the queue for this event_class processor.  Converts the condition trees to condition graphs for fast
    # evaluation by the RETE algorithm.  If the event_class processor is to operate in async mode, also
    # creates the processing thread and starts waiting for events to be queued.
    #
    # @param [Hash] options the options for running the FSM.
    # @option options [true,false] :sync whether the FSM operators in sync mode.
    # @return [void]
    def run( options )
      # Check that for every defined class in the system, there is at least one instantiated FSM.  If not
      # raise an exception.
      @cfsm_initial_state.each_key do |cfsm|
        raise CFSM::EmptyCFSMClass, "#{namespace} has no instantiated FSMs" if @cfsms[cfsm].nil?
      end

      @status = :running

      @options = options

      # Do the heavy lifting on converting the condition trees to optimised condition graphs.
      cache_conditions
      convert_trees_to_sets
      convert_sets_to_graph

      if CFSM.logger.info?
        @conditions.each_pair do |event_class, condition_graph|
          CFSM.logger.info "Condition graph for #{event_class.to_s}"
          CFSM.logger.info condition_graph.inspect
        end
      end

      # For each CFSM namespace, we also have a queue to hold unprocessed events.
      @event_queue ||= PrioQueue.new

      # Ensure only one thread is actually in the process_event method.
      @process_mutex = Mutex.new

      # If running in sync mode, we set @thread to true to indicate the EventProcessor has been set to
      # run.  If we are running in async mode then create a thread with an infinite loop to process incoming events.
       start_thread
    end

    # Private method that starts the thread.  Separated out from run for readability.
    # @return [void]
    def start_thread
      @thread = @options[:sync] || Thread.new do
        begin
          loop do
            @status = :waiting_for_event
            process_event
            @event_queue.wait_for_new_event
          end
        rescue => e
          CFSM.logger.fatal "#{e.class}: #{$!}"
          Thread.main.raise e
        end
      end
    end

    # Used in the context of CFSM.reset to close down this event_class processor in a clean manner.  Should
    # only be used with RSpec when running a new set of state machine tests.
    # @return [void]
    def reset
      @thread.kill if @thread.is_a? Thread
      @thread = nil

      # Remove all pending events from the queue.
      @event_queue.pop_each { |event| self.cancel( event ) } if @event_queue
    end

    # Receives an event for consideration by the event_class processor.  So long as the EventProcessor has
    # been started and we have a ConditionGraph for that event's class we stick it into the queue for processing.  If
    # we are not operating in async mode, then we also process the event_class.
    # @param event [CfsmEvent] the event being posted.
    # @return [void]
    def post( event )
      if @thread && @conditions[ event.event_class ]
        set_event_status(event, :pending )
        @event_queue.push event
        CFSM.logger.info "Event #{event.inspect} posted to #{namespace}"
        process_event if @thread==true
      end
    end

    # Cancel a pending event_class.  Mainly used to cancel events due at point in the future.  However, can also
    # be used to cancel an event_class that is in the main queue, but has not yet been acted on.
    #
    # @param [CfsmEvent] event
    # @return [Boolean] whether the event_class was still :pending to be cancelled.
    def cancel( event )
      CFSM.logger.info( "#{namespace.to_s}: cancelling event #{event.inspect}" )

      if event.status( namespace ) == :pending && @event_queue.delete( event )
        set_event_status(event, :cancelled)
        true
      else
        false
      end
    end

    # Normally, we shut the parser down once we have evaluated all state machine descriptions.  If we are running
    # RSpec then we may need to restart it.
    # @return [void]
    def self.restart_parser
      @@parser = ConditionParser::Parser.new
    end

    # Look at each event_class in priority order until the event processor can find one to process. If it can, then it removes that
    # event from the queue and executes the transitions.  Returns the processed event.  If no events can be found
    # that result in a transition, it returns nil to allow the calling method to perform a wait_for_next_event.
    #
    # @return [nil, CfsmEvent] if one or more transitions were executed returns the event causing the transition, otherwise nil
    def process_event
      @process_mutex.synchronize do
        CFSM.logger.info( "#{namespace.to_s}: checking if events can be processed.  Queue holds #{@event_queue.size} event(s)" )
        @status = :process_event
        @event_queue.each do |event|
          CFSM.logger.debug( "#{namespace.to_s}: Examining event #{event.inspect}" )

          # we use fsms to keep track of which FSMs are in the right state to meet the requirements.
          transitions = @conditions[event.event_class].execute( event )
          CFSM.logger.debug( "Transitions still in play: #{transitions.inspect}")

          unless transitions.empty?
            return event if process_transitions(event, transitions)
          end
        end
        # if we get to here, we have been through all events in the queue and cannot process any.  Need to
        # wait for something to change.
        return nil
      end
    end

    # Generate a string description of the event processor.
    #
    # @return [String] a string description of the event processor.
    def inspect
<<HEREDOC
Namespace: #{self.namespace}
Thread status: #{ thread_status }
Condition graph: #{ @conditions.inspect }
Current queue: #{ @event_queue ? ("\n" << @event_queue.inspect) : 'uninitialised' }
Status of each FSM:
#{cfsm_inspect}
**************************
HEREDOC
    end

    # This method returns the status of the event processor's thread as a string.
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

    private

    # Create single instances of the parser and the transformer.
    @@parser =  ConditionParser::Parser.new

    # Take all the condition trees associated with this EventProcessor and populate the @conditions_cache
    # hash.
    # @api private
    def cache_conditions
      @conditions.each_pair do |event, condition_trees|
        condition_trees.each do |tree|
          tree.condition_tree = ConditionParser::Transformer.cache_conditions(@condition_cache, tree.condition_tree)
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

    # In order to save memory, we remove the parser, once we have parsed and converted all trees.
    def self.shutdown_parser
      self.remove_class_variable :@@parser
    end

    # The status is something that should only be set by EventProcessor.  Therefore, it is a private method
    # on CfsmEvent.  This helper function allows us to set the status using `#instance_exec`.
    # @param [Event] event whose status needs setting
    # @param [Symbol] status the new status
    def set_event_status( event, status )
      event.instance_exec( namespace ) { |namespace| set_status(status, namespace) }
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

    # Once we have determined that one or more transitions need to happen, then the transitions
    # are processed in this method.
    #
    # @param event [CfsmEvent]  - the event causing the transitions
    # @param transitions[Array<Transition>] - the list of transitions to execute.
    def process_transitions(event, transitions)
      @event_queue.delete( event )

      CFSM.logger.info "#{event.inspect} being processed in #{namespace}"

      transitions.each do |t|
        do_transition =
            case t.transition_proc
              when Proc
                t.fsm.instance_exec(event, &t.transition_proc)
              when Symbol
                t.fsm.send(t.transition_proc, event, t.new_state)
              when nil
                true
              else
                raise CFSM::CfsmErrorTransitionUnknownType
            end
        t.fsm.instance_exec( t.new_state ) { |s| set_state(s) } if do_transition
      end

      set_event_status( event, :processed )

      # we have managed to process the event_class, so exit process event_class.
      return event
    end

    # Used to hold the condition tree and transition descriptions in the @@event_processors hash.
    Struct.new('EventTree', :condition_tree, :transition )
  end
end