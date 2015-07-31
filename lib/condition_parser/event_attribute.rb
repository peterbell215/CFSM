# @author Peter Bell
# Licensed under MIT2

module ConditionParser
  class EventAttribute
    def initialize( a )
      @attribute = a
    end

    def ==(object2)
      return self.attribute == object2.attribute
    end

    attr_reader :attribute
  end
end
