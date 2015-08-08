# @author Peter Bell
# Licensed under MIT

module ConditionParser
  class EventAttribute
    def initialize( a )
      @attribute = a
    end

    def hash
      @attribute.hash
    end

    def evaluate(event)
      event.send( @attribute )
    end

    def ==(object2)
      self.attribute == object2.attribute
    end

    attr_reader :attribute
  end
end
