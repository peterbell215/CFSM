
##
# Class to represent a message/event that is produced and then sent to the appropriate CFSMs.
class CfsmEvent
  # @param [Symbol,Class] event_class
  # @param src [Object] the source from which the message was transmitted.  Reference to an object.
  # @param prio [Fixnum] the priority of the message with 0 the lowest priority
  # @param msg [Hash] addition data as a Hash
  # @return [CfsmEvent]
  def initialize(event_class, src, prio=0, msg={})
    @event_class = event_class
    @src = src
    @prio = prio
    @msg = msg
  end
end
