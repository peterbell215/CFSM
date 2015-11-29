# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

module ConditionParser
  # It is easier for the optimiser to manipulate integers representing the individual
  # conditions, rather than the conditions themselves.  To aid this, this class builds
  # an array that maps an integer value to a condition.
  # Note, it makes more sense to use an Array than a Hash since during normal execution the key
  # mapping is from number to ConditionNode.
  class ConditionCache < Array
    # Add an entry to the cache, or if already cached just return the lookup value.
    # @param event_condition [ConditionNode] the event condition being cached.
    # @return [ConditionNode] the cached value - either the event condition, or a previously stored copy of the same
    def add(event_condition)
      # TODO: we need to re-arrange the in-equality if it contains both an event attribute and a state attribute.

      # check if the member exists: if not add.
      index_existing_entry = self.index( event_condition )
      if index_existing_entry.nil?
        self.push( event_condition )
        event_condition
      else
        self[index_existing_entry]
      end
    end
  end
end
