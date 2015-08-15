# @author Peter Bell
# Licensed under MIT

require 'cfsm_classes/transition'
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
  # TODO Need to replace the current Queue class from the standard library with a prioritised thread safe queue.
  #
  # @api private
  class EventProcessor
    include ConditionOptimisation::ConditionPermutations

    # Constructor.  Creates an instance of EventProcessor.
    # @param [String] namespace
    def initialize( namespace )
      # keep a record of the namespace.
      @namespace = namespace

      # Used to store runtime options.  Key one at the moment is :async => False which prevents CFSM from creating
      # a separate thread to process events.
      @options = nil

      ##
      # This variable holds a list of all instantiated FSMs within the namespace. It holds the data as a hash of class to
      # an array of all instantiated FSMs.
      @cfsms = {}

      ##
      # This variable holds a list of initial states for all defined classes of CFSM.  It is a hash of
      # class to state.
      @cfsm_initial_state = {}

      # Hash that provides the collection of parameters that need to be evaluated for a given event type.
      #
      # While the CFSMs are being constructed, the hash will point to an array of EventTrees.  Each
      # event tree represents a condition tree and the transition that will produced.  Example:
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

    # TODO: add description plus rpsec tests
    def register_events( klass, state, other_params, &exec_block)
      @klass_being_defined = klass
      @state_being_defined = state

      # if an initial state has not been set, then set it. In practice, means the first state defintion
      # gets the initial state.
      @cfsm_initial_state[ klass ] = state unless @cfsm_initial_state[ klass ]

      # Evaluate the transition definitions
      self.instance_eval( &exec_block )

      @klass_being_defined = nil
      @state_being_defined = nil
    end

    ##
    # Class method to register that a FSM reacting to an event while in a defined state and transitioning to a new state.
    #
    # @api private
    #
    # @param event [Class,symbol] the event that we are reacting too.
    # @param parameters [String] the parameters that the FSM must meet to
    # @param proc [Proc] a method to be executed as part of the state transition
    def on( event, parameters = {}, &proc )
      # Create an array to hold the condition trees and their respective transitions.
      @conditions[ event ] ||= Array.new

      # Make sure we have not yet passed the point of turning this into a ConditionGraph.
      raise TooLateToRegisterEvent if @conditions[ event ].is_a? ConditionOptimisation::ConditionGraph

      # Create a parse tree with at least a state check.
      fsm_check = ConditionParser::EventCondition::fsm_state_checker(@klass_being_defined, @state_being_defined)
      if_tree = unless parameters[:if].nil?
                  { :and => [ fsm_check, @@transformer.apply( @@parser.parse( parameters[:if] ) ) ] }
                else
                  fsm_check
                end

      # Create the transition object
      transition = CfsmClasses::Transition.new( @klass_being_defined, parameters[:transition], &proc )

      # Store the event.
      @conditions[event].push Struct::EventTree.new( if_tree, transition )
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

    # Registers an instance of a CFSM with the event processor.  Used by the constructor of the CFSM.
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

    # Creates the queue for this event processor.  If the event processor is to operate in async mode, also
    # creates the processing thread and starts waiting for events to be queued.
    def run( options )
      @options = options

      # Do the heavy lifting on converting the condition trees to optimised condition graphs.
      cache_conditions
      convert_trees_to_sets
      convert_sets_to_graph

      # For each event CFSM namespace, we also have a queue to hold unprocessed events.
      @event_queue ||= Queue.new

      # If running in async mode, then create a thread with an infinite loop to process incoming events.
      @thread = Thread.new { loop { process_event } } if @options[:async].nil? || @options[:async]
    end

    # Receives an event for consideration by the event processor.  So long as we have a ConditionGraph
    # for that event we stick it into the queue for processing.  If we are not operating in async mode,
    # then we also process the event.
    def post( event )
      if @conditions[ event.event_class ]
        @event_queue.push event
        process_event unless @thread
      end
    end

    private

    # Take all the condition trees associated with this EventProcessor and populate the @conditions_cache
    # hash.
    # @api private
    def cache_conditions
      @conditions.each_pair do |event, condition_trees|
        @condition_cache[event] ||= ConditionParser::ConditionCache.new
        condition_trees.each do |tree|
          tree.condition_tree = ConditionParser::Transformer.cache_conditions(@condition_cache[event], tree.condition_tree)
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
    # event to determine if the transition should happen.
    def convert_sets_to_graph
      @conditions.each_pair do | event, condition_sets |
        @conditions[event] = self.permutate_graphs( condition_sets ).find_optimal
      end
      self
    end

    # Removes the next event from the queue and executes the condition graph to see if the event can be
    # processed.
    def process_event
      event = @event_queue.pop

      # we use fsms to keep track of which FSMs are in the right state to meet the requirements.
      transitions = @conditions[ event.event_class ].execute do |c, fsms|
        fsms = @condition_cache[ event.event_class ][ c ].evaluate( fsms, event )
      end

      transitions.each do |t|
        if !t.proc || t.proc && t.fsm.instance_exec( t.proc )
          t.fsm.state = t.next_state
        end
      end
    end

    # Create single instances of the parser and the transformer.
    @@parser =  ConditionParser::Parser.new

    # In order to save memory, we remove the parser, once we have parsed and converted all trees.
    def self.shutdown_parser
      self.remove_class_variable :@@parser
    end

    # Used to hold the condition tree and transition descriptions in the @@event_processors hash.
    Struct.new('EventTree', :condition_tree, :transition )
  end
end