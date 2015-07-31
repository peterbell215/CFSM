# @author Peter Bell
# Licensed under MIT2.

require 'cfsm_classes/transition'
require 'condition_parser/parser'
require 'condition_parser/fsm_state_variable'
require 'condition_parser/condition_transform'
require 'condition_optimisation/condition_graph'

module CfsmClasses
  class TooLateToRegisterEvent < Exception; end

  module EventProcessor
    ##
    # Class method to register that a FSM reacting to an event while in a defined state and transitioning to a new state.
    #
    # @param name [Class,symbol] the event that we are reacting too.
    # @param current_state [Symbol] the state in which the FSM needs to be when receiving this event
    # @param next_state [Symbol] the state to which the FSM will transition on receiving the event and if the conditions are met
    # @param conditions [String] the conditions that the FSM must meet to
    # @param proc [Proc] a method to be executed as part of the state transition
    def self.register_event( name, fsm_class, current_state, next_state, conditions = {}, &proc)
      # if we have not seen this one yet, then create an array to hold the various condition trees and transitions
      @@event_processors[ name ] = Array.new  if @@event_processors[ name ].nil?

      # Make sure we have not yet passed the point of turning this into a ConditionGraph.
      raise TooLateToRegisterEvent if @@event_processors[ name ].is_a? ConditionOptimisation::ConditionGraph

        # Create a parse tree
      fsm_check = ConditionParser::FsmStateVariable.new( fsm_class, current_state)
      if_tree = unless conditions[:if].nil?
                  { :and => [ fsm_check, @@transformer.apply( @@parser.parse( conditions[:if] ) ) ] }
                else
                  [ fsm_check ]
                end

      # Create the transition object
      transition = CfsmClasses::Transition.new( fsm_class, next_state )

      # TODO: deal with the Proc argument

      # Store the event.
      @@event_processors[name].push Struct::EventTree.new( if_tree, transition )
    end


    # @return [Object]
    def self.convert_condition_trees
      @@event_processors.each_pair do |event, condition_trees |
        condition_trees.each { |tree| ConditionTransform::generate_permutations( tree ) }
      end
    end

    private
    # Create single instances of the parser and the transformer.
    @@parser =  ConditionParser::Parser.new
    @@transformer = ConditionParser::ConditionTransform.new

    # Hash with one event processor for each event type of in the system.  While the CFSMs are
    # being constructed, the hash will point to an array of parse trees.
    # Once event processing has started, this is converted into a ConditionGraph.  The conversion
    # can be explicitely done (gives predictable timing behaviour); otherwise it is done, the first
    # time that event class is seen.
    #
    # Example:
    # @@event_processors[ :event_a ] =
    #   @condition_tree = { :and => [ StateCheck( FsmA, :state_a ), ConditionNode( :==, 'a', 'Peter' ) }, @transition = Transition( FsmA, :state_b ) }
    # If event_a is raised, and FsmA is in state_a, and the message contains a field 'a' that has value 'Peter', then
    # FsmA should transition to state_b.
    @@event_processors = {}

    # Used to hold the condition tree and transition descriptions in the @@event_processors hash.
    Struct.new('EventTree', :condition_tree, :transition )
  end
end