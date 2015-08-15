# @author Peter Bell

module ConditionParser
  ##
  # It is easier for the optimiser to manipulate integers representing the individual
  # conditions, rather than the conditions themselves.  To aid this, this class builds
  # a hash that maps each condition onto an integer.
  class ConditionCache < Array

    ##
    #
    def <<(event_condition)
      # TODO: we need to re-arrange the in-equality if it contains both an event attribute and a state attribute

      # check if the member exists: if so add
      self.index( event_condition ) || self.push( event_condition ).length - 1
    end
  end
end
