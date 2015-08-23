# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.


# Class to represent a message/event that is produced and then sent to the appropriate CFSMs.
class CfsmEvent
  # @param [Symbol,Class] event_class
  # @param msg [Hash] addition data as a Hash
  # @param prio [Fixnum] the priority of the message with 0 the lowest priority
  # @return [CfsmEvent]
  def initialize(event_class, msg={}, prio=0 )
    @event_class = event_class
    @msg = msg
    # TODO: automatically determine source from stack.
    # @src = src
    @prio = prio
  end

  attr_reader :event_class
end
