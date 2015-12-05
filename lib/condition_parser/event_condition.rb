# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

module ConditionParser
  # Holds an event condition that needs to be evaluated.  Takes the form of:
  # - comparator (<. =, >, etc)
  # - attribute (either of an event or of a FSM)
  # - value either a constant or another expression.
  class EventCondition
    attr_reader :comparator
    attr_reader :left_term
    attr_reader :right_term

    INVERSE = { :== => :==, :!= => :!=, :>= => :<=, :> => :<, :<= => :>=, :< => :> }

    # Constructor
    #
    # @param comparator [Symbol] the comparison to be undertaken
    # @param left_term [Object] the left term of the comparator
    # @param right_term [Object]  the right term it should be compared to
    def initialize( comparator, left_term, right_term )
      if !left_term.is_a?(FsmStateVariable) && right_term.is_a?(FsmStateVariable)
        @comparator = INVERSE[comparator]
        @left_term = right_term
        @right_term = left_term
      else
        @comparator = comparator
        @left_term = left_term
        @right_term = right_term
      end
      self
    end

    # Factory method to provide a convenient way of creating an EventCondition to
    # check the current state of the FSM.
    #
    # @param [Class] fsm
    # @param [Symbol] state
    # @return [EventCondition]
    def self.fsm_state_checker(fsm_class, state)
      EventCondition.new(:==, FsmStateVariable.new( fsm_class, :state ), state)
    end

    def inspect
      "#{@left_term.inspect} #{@comparator.to_s} #{@right_term.inspect}"
    end

    # This will evaluate for whether the condition has been met.
    # @param [Array<CFSM>] cfsms is the array of FSMs to be evaluated.
    # @return [Array<CFSM>] is the array of FSMs that match the evaluated condition.
    def evaluate( event, cfsms )
      # if cfsms remains nil then this particular namespace has no FSMs instantiated,
      # therefore return []
      return [] if cfsms.nil? || cfsms.empty?

      CFSM.logger.debug "Evaluating #{self.inspect} "
      CFSM.logger.debug "    against event #{event.inspect}"

      if @left_term.is_a? FsmStateVariable
        cfsms = CFSM.state_machines( @left_term.fsm_class ).dup if cfsms == :all
        # TODO: this is destroying the set globally.
        cfsms.delete_if { |fsm| !comparison_evaluate(event, fsm) }
      else
        comparison_evaluate(event, nil) ? cfsms : []
      end
    end

    # Override the standard hash key so that different instances that are == generate the same hash
    # key
    # @return [Fixnum]
    def hash
      self.comparator.object_id ^ INVERSE[self.comparator].object_id ^ self.left_term.hash ^ self.right_term.hash
    end

    # Check if two EventConditions are equal.  Take account of the fact that left and right may be
    # reversed.
    #
    # @param [EventCondition] object2
    # @return [True,False]
    def ==(object2)
      return false unless object2.is_a?( EventCondition )

      if self.comparator == object2.comparator
        self.left_term == object2.left_term && self.right_term == object2.right_term
      elsif INVERSE[self.comparator] == object2.comparator
        self.left_term == object2.right_term && self.right_term == object2.left_term
      else
        false
      end
    end

    alias eql? :==

    private

    # Private method to evaluate for an event and a specific FSM whether the condition is med.
    def comparison_evaluate(event, fsm)
      left_arg = arg_evaluate( @left_term, event, fsm )
      right_arg = arg_evaluate( @right_term, event, fsm )
      # We need to coerce the two args to be the same class before we send to the comparator
      left_arg, right_arg = left_arg.coerce( right_arg ) if left_arg.respond_to?( :coerce )
      comparison_result = left_arg.send( @comparator, right_arg )

      if CFSM.logger.debug?
        CFSM.logger.debug "- against #{fsm.inspect}" unless fsm.nil?
        CFSM.logger.debug "    Result: #{left_arg.inspect} #{@comparator.to_s} #{right_arg.inspect} => #{comparison_result}"
      end
      comparison_result
    end

    # Private method to evaluate one side of the comparison operator.
    def arg_evaluate( argument, event, fsm )
      case argument
        when FsmStateVariable
          return fsm.send( argument.state_var )
        when EventAttribute
          return argument.evaluate( event )
        else
          return argument
      end
    end
  end
end