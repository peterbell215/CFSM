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
  # TODO : introduce a status for an event: {created, delayed, pending, no_matches, processed}

  # @param [Symbol,Class] event_class
  # @param [Hash] opts the options for this event.
  # @option opts [Hash] :data provides the data for the event.
  # @option opts [Fixnum] :prio the priority of the message with 0 the lowest priority.  Default is 0.
  # @option opts [Fixnum] :delay allows the posting of the event to be delayed.  Default is 0.
  # @option opts [true,false] :autopost allows the event to be immediately posted to the relevant CFSMs.
  # @return [CfsmEvent]
  def initialize( event_class, opts={} )
    @event_class = event_class

    # Retrieve the data held and store as instance variables with suitable accessors
    if opts[:data]
      opts[:data].each do |k,v|
        instance_variable_set("@#{k}", v)
        eigenclass = class<<self; self; end
        eigenclass.class_eval { attr_accessor k }
      end
    end

    @src = caller(1, 1)[0]
    @prio = opts[ :prio ] || 0
    @delay = opts[ :delay ] || 0
    @status = :created

    CFSM.post( self ) if opts[:autopost]

    self
  end

  attr_reader :status
  attr_reader :src
  attr_reader :event_class
  attr_reader :prio
  attr_reader :delay

  private

  def status=(s)
    @status = s
  end
end
