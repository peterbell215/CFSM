# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

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
      object2.is_a?( EventAttribute ) && attribute == object2.attribute
    end

    attr_reader :attribute
  end
end
