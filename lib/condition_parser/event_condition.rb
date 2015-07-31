# @author Peter Bell
# Licensed under MIT2

module ConditionParser
  ##
  # Holds an event condition that needs to be evaluated.
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
    end

    # @param [EventCondition] object2
    # @return [True,False]
    def ==(object2)
      self.comparator == object2.comparator && self.attribute == object2.attribute && self.value == object2.value
    end
  end
end