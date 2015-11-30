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
    attr_reader :attribute
    attr_reader :value

    # Constructor
    #
    # @param comparator [Symbol] the comparison to be undertaken
    # @param attribute [String] the attribute to tested
    # @param [Object] value the value it should be compared to
    def initialize( comparator, attribute, value )
      @comparator = comparator
      @attribute = attribute
      @value = value
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
      "#{@attribute.inspect} #{@comparator.to_s} #{@value.inspect}"
    end

    # This will evaluate for whether the condition has been met.
    # @param [Array<CFSM>] cfsms is the array of FSMs to be evaluated.
    # @return [Array<CFSM>] is the array of FSMs that match the evaluated condition.
    def evaluate( event, cfsms )
      return [] if cfsms.nil? || cfsms.empty?

      CFSM.logger.debug "Evaluating #{self.inspect} "
      CFSM.logger.debug "    against event #{event.inspect}"

      # if cfsms remains nil then this particular namespace has no FSMs instantiated,
      # therefore return []
      cfsms = CFSM.state_machines( @attribute.fsm_class ).dup if cfsms == :all

      cfsms.delete_if do |fsm|
        CFSM.logger.debug "- against #{fsm.inspect}"
        if @attribute.is_a? FsmStateVariable
          left_arg = fsm.send( @attribute.state_var )
          # TODO: @value could be complex.  Need something to deal with that case.
          right_arg = @value
        else
          left_arg = self.attribute.evaluate( event )
          right_arg = fsm.send(self.value.state_var)
        end

        # We need to coerce the two args to be the same class before we send to the comparator
        left_arg, right_arg = left_arg.coerce( @value ) if left_arg.respond_to?( :coerce )

        comparison_result = left_arg.send( @comparator, right_arg )
        CFSM.logger.debug "    Condition: #{self.inspect}"
        CFSM.logger.debug "    Result:    #{left_arg.inspect} #{@comparator.to_s} #{right_arg.inspect} => #{comparison_result}"

        !comparison_result
      end
      cfsms
    end

    # Override the standard hash key so that different instances that are == generate the same hash
    # key
    # @return [Fixnum]
    def hash
      self.comparator.object_id ^ self.attribute.hash ^ self.value.hash
    end

    # Check if two EventConditions are equal.
    # @param [EventCondition] object2
    # @return [True,False]
    def ==(object2)
      object2.is_a?( EventCondition ) &&
        self.comparator == object2.comparator && self.attribute == object2.attribute && self.value == object2.value
    end

    alias eql? :==
  end
end