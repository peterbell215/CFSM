# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

# Class to represent a message/event that is produced and then sent to the appropriate CFSMs.  Typically, this class
# will be used in one of two ways:
# - As a superclass from which a specific Event class is then derived.  This allows for more complex operations on the
#   the class to be abstracted into methods.
# - As the class directly.  In this case, the Event class is defined by a symbol.  The invoker can include additional
#   data in the data hash.
# @example Creating an event without a sub-class
#   Cfsm.Event.new( :car_arrived, :data> { :from => :N, :lane => 2}, :prio => 2, :delay => 10 )
class CfsmEvent
  class EventDoesNotHaveExpiry < Exception; end

  include Comparable

  # @param [Symbol,Class] event_class
  # @param [Hash] opts the options for this event.
  # @option opts [Hash] :data provides the data for the event.
  # @option opts [Fixnum] :prio the priority of the message with 0 the lowest priority.  Default is 0.
  # @option opts [Time] :expiry the time at which the event should become live and be posted
  # @option opts [Fixnum] :delay allows the posting of the event to be delayed.  Default is 0.
  # @option opts [true,false] :autopost allows the event to be immediately posted to the relevant CFSMs.
  # @return [CfsmEvent]
  def initialize( event_class, opts={} )
    @event_class = event_class

    # Retrieve the data held and store as instance variables with suitable accessors
    if opts[:data]
      @data = opts[:data]
      @data.each do |k,v|
        instance_variable_set("@#{k}", v)
        eigenclass = class<<self; self; end
        eigenclass.class_eval { attr_accessor k }
      end
    end

    @src = caller(1, 1)[0]
    @prio = opts[ :prio ] || 0
    # At the point a delayed event is created, this sets an expiry for that event.
    @expiry = opts[ :expiry ] || (opts[ :delay ] ? Time.now + opts[ :delay ] : nil )

    CFSM.post( self ) if opts[:autopost]

    self
  end

  # Once an event has left the delayed queue, CFSM needs to reset its expiry to nil before posting it to
  # the event processors' queues.
  def reset_expiry
    @expiry = nil
  end

  # Allows SortedArray to compare the events.  Behaviour different if the two events still need to expire versus
  # it they are both live.
  def <=>(event2)
    raise ComparingDelayedToLiveEvent if self.expiry.nil? != event2.expiry.nil?

    if self.expiry
      self.expiry <=> event2.expiry
    else
      event2.prio <=> self.prio
    end
  end

  # This returns the status of the event.
  #
  # Because an event may be posted to multiple queues at the same time, the event status is held
  # per CFSM namespace.  Once posted, the valid statuses are:
  # o 'nil' when the event has not yet been posted to this CFSM namespace or been cancelled in the namespace
  # o _delayed_ if the event has been posted to become active in the future
  # o _pending_ if the event can be processed, but some condition of the event is not yet valid.
  # o _processed_ once the event has been processed in the said namespace.
  #
  # @param [String] namespace the namespace in which we are querying the status.  IF not specified, then returned or the Global namespace
  # @return [Symobol,nil] the status. If the event has not yet been posted to the namespace, then `nil`
  def status( namespace = 'Global' )
    @status.is_a?(Hash) ? @status[namespace] : @status
  end

  # @!attribute [r] status
  #   @return [:created, :delayed, :pending, :processed] status of the event within its lifecycle
  attr_reader :src
  attr_reader :event_class
  attr_reader :prio
  attr_reader :data
  attr_reader :expiry

  def inspect
    "{ #{ self.event_class.to_s }: prio = #{self.prio.to_s}, status = #{@status ? @status.to_s : 'nil'}, expiry = #{self.expiry ? self.expiry.strftime("%-d-%b %H:%M.%3N") : 'nil'}, data = #{ self.data.inspect } }"
  end

  private

  # This is a private method to allow `event_processor` to set the status.  The same event can be in multiple
  # namespaces and can therefore have different statuses for each namespace.  Initially, when an event is created,
  # it is has an undefined status and nil is returned.  Once the event has been posted to a namespace, then the status
  # values are stored in a hash to allow efficient mapping of namespace to status.
  #
  # Namespaces can also be destroyed.  This should really only be used for testing.  In this case, the event
  # will be removed from the relevant queue, and the queue destroyed.  We therefore, also remove the namespace
  # from the hash.
  #
  # @api private
  # @param [Symbol] status is the current status of the event
  # @param [String] namespace is the namespace in which it applies.  If omitted, the default is 'Global'
  def set_status(status, namespace = 'Global' )
    if @status.is_a?(Hash)
      if status==:cancelled
        @status.delete(namespace)
        @status = nil if @status.empty?
      else
        @status[namespace] = status
      end
    else
      @status = { namespace => status } unless status == :cancelled
    end
    @status
  end
end
