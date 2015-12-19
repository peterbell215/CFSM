# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.

module ConditionParser
  class EventAttribute
    def initialize( a )
      @attribute = a
    end

    def hash
      @attribute.hash
    end

    def inspect
      "EventAttribute #{@attribute.to_s}"
    end

    def evaluate(event)
      event.send( @attribute )
    end

    def ==(object2)
      object2.is_a?( EventAttribute ) && attribute == object2.attribute
    end

    attr_reader :attribute
  end
end
