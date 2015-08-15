# @author Peter Bell
# Licensed under MIT2

module ConditionParser
  ##
  # Holds an event condition that needs to be evaluated.  Takes the form of:
  # - attribute (either of an event or of a FSM)
  # -
  class EventCondition
    attr_reader :comparator
    attr_reader :attribute
    attr_reader :value

    ##
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

    ##
    # Factory method to provide a convenient way of creating an EventCondition to
    # check the current state of the FSM.
    #
    # @param [Class] fsm
    # @param [Symbol] state
    # @return [EventCondition]
    def self.fsm_state_checker(fsm_class, state)
      EventCondition.new(:==, FsmStateVariable.new( fsm_class, :state ), state)
    end

    # This will evaluate for whether the condition has been met.
    # @param [Array<CFSM>] cfsms is the array of FSMs to be evaluated.
    # @return [Array<CFSM>] is the array of FSMs that match the evaluated condition.

    def evaluate( cfsms, event )
      if @attribute.is_a? FsmStateVariable
        # if cfsms remains nil then this particular namespace has not FSMs instantiated,
        # therefore return []
        cfsms = CFSM.state_machines( @attribute.fsm_class ) if cfsms == :all

        if cfsms && !cfsms.empty?
          cfsms.each do |fsm|
            # TODO: @value could be complex.  Need something to deal with that case.
            cfsms.delete(fsm) unless fsm.send( @attribute.state_var ).send( @comparator, @value )
          end

          cfsms
        end
      else
        # simply testing a condition.
        event.evaluate( self.attribute ).send( self.comparator, self.value )
      end
    end

    ##
    # Override the standard hash key so that different instances that are == generate the same hash
    # key
    # @return [Fixnum]
    def hash
      self.comparator.object_id ^ self.attribute.hash ^ self.value.hash
    end

    # @param [EventCondition] object2
    # @return [True,False]
    def ==(object2)
      object2.is_a?( EventCondition ) &&
        self.comparator == object2.comparator && self.attribute == object2.attribute && self.value == object2.value
    end

    alias eql? :==
  end
end