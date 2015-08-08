# @author Peter Bell
# Licensed under MIT2.

require 'cfsm_classes/transition'
require 'condition_parser/parser'
require 'condition_parser/fsm_state_variable'
require 'condition_parser/transformer'
require 'condition_parser/condition_hash'
require 'condition_optimisation/condition_graph'
require 'condition_optimisation/condition_permutations'

module CfsmClasses
  class TooLateToRegisterEvent < Exception; end

  # this class hides the implementation complexities of the Communicating FSM system.  It is really only to be invoked from
  # methods within the CFSM class.
  class EventProcessor
    include ConditionOptimisation::ConditionPermutations

    # Constructor.  Creates an instance of EventProcessor.
    def initialize
      ##
      # This variable holds a list of all instantiated FSMs within the namespace. It holds the data as a hash of namespace to
      # an array of all instantiated FSMs.
      @cfsms = {}

      ##
      # This variable holds a list of initial states for all defined classes of CFSM.  It is a hash of
      # class to state.
      @cfsm_initial_state = {}

      # Hash that provides the collection of if_conditions that need to be evaluated for a given event type.
      #
      # While the CFSMs are being constructed, the hash will point to an array of EventTrees.  Each
      # event tree represents a condition tree and the transition that will produced.  Example:
      #
      #   @if_conditions[ :event_a ] =
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

      # In order to facilitate faster manipulation of the if_conditions during the optimisation we cache the
      # if_conditions in this Hash together with an integer.  The Caches are in turn hashed onto the EventConditions.
      @condition_cache = {}
    end

    ##
    # Class method to register that a FSM reacting to an event while in a defined state and transitioning to a new state.
    #
    # @api private
    #
    # @param name [Class,symbol] the event that we are reacting too.
    # @param current_state [Symbol] the state in which the FSM needs to be when receiving this event
    # @param next_state [Symbol] the state to which the FSM will transition on receiving the event and if the if_conditions are met
    # @param if_conditions [String] the if_conditions that the FSM must meet to
    # @param proc [Proc] a method to be executed as part of the state transition
    def register_event( name, fsm_class, current_state, next_state, if_conditions = {}, &proc)
      # Create an array to hold the condition trees and their respective transitions.
      @conditions[ name ] ||= Array.new

      # Make sure we have not yet passed the point of turning this into a ConditionGraph.
      raise TooLateToRegisterEvent if @conditions[ name ].is_a? ConditionOptimisation::ConditionGraph

      # Create a parse tree with at least a state check.
      fsm_check = ConditionParser::EventCondition::fsm_state_checker(fsm_class, current_state)
      if_tree = unless if_conditions[:if].nil?
                  { :and => [ fsm_check, @@transformer.apply( @@parser.parse( if_conditions[:if] ) ) ] }
                else
                  fsm_check
                end

      # Create the transition object
      transition = CfsmClasses::Transition.new( fsm_class, next_state )

      # TODO: deal with the Proc argument

      # Store the event.
      @conditions[name].push Struct::EventTree.new( if_tree, transition )
    end

    # Take all the condition trees associated with this EventProcessor and populate the @conditions_cache
    # hash.
    # @api private
    def cache_conditions
      @conditions.each_pair do |event, condition_trees|
        @condition_cache[event] ||= ConditionParser::ConditionHash.new
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

    def self.run
      # For each event class, we also have a queue of each event type.
      unless @event_queue
        @event_queue = Queue.new

        Thread.new do
          event = @event_queue.pop
          @conditions[ event ].condition_tree.execute( event )
        end
      end
    end

    # Method used to register with the event processor what the initial state is for a class of
    # communicating FSMs.
    #
    # @api private
    #
    # @param [Class] cfsm_class
    # @param [Symbol] initial_state
    # @return [Symbol] returns the initial state
    # @raises ConflictingInitialStates if the initial state is already set for this state machine
    def register_initial_state(cfsm_class, initial_state)
      # check if an initial state is indicated.
      raise ConflictingInitialStates if @cfsm_initial_state[ cfsm_class ]
      @cfsm_initial_state[ cfsm_class ] = initial_state
    end

    # Retrieves the initial state for this class of FSM.  If it is not defined, raises an error.
    #
    # @api private
    #
    # @param [Class] cfsm_class
    # @return [Symbol]
    def initial_state( cfsm_class )
      @cfsm_initial_state[ cfsm_class ] || raise( NoInitialState )
    end

    # Registers an instance of a CFSM with the event processor.  Used by the constructor of the CFSM.
    #
    # @api private
    #
    # @param [CFSM] cfsm
    # @return [Symbol] initial state for the FSM
    def register_cfsm( cfsm )
      ( @cfsms[ cfsm.class ] ||= Array.new ).push( self )
    end

    # Create single instances of the parser and the transformer.
    @@parser =  ConditionParser::Parser.new

    # Used to hold the condition tree and transition descriptions in the @@event_processors hash.
    Struct.new('EventTree', :condition_tree, :transition )
  end
end