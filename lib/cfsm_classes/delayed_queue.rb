# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.

require 'cfsm'

module CfsmClasses
  # This class implements a queue for delayed events.  The algorithm is as described on the
  # Wikipedia page.  Once a delayed event is posted, it is given an expiry time.  Alternatively, it may have an
  # expiry time set.
  class DelayedQueue < SortedArray
    def initialize( &expiry_handler )
      @queue_mutex = Mutex.new
      @expiry_handler = expiry_handler
      super { |e1, e2| e1.expiry <=> e2.expiry }
    end

    attr_reader :wait_thread

    # Posts the event to the global delayed event queue.  Note that this implies that the event
    # expiry needs to be set by the caller.
    #
    # @param [CfsmEvent] event the event being posted to the CFSMs.
    # @return [CfsmEvent] returns the posted event
    # @raise [CfsmEvent::EventDoesNotHaveExpiry] if the event does not have an expiry set.
    def post( event )
      raise CfsmEvent::EventDoesNotHaveExpiry.new(event) if event.expiry.nil?

      # Start the wait thread  once we have something to wait for.
      start_wait_thread if @wait_thread.nil?

      @queue_mutex.synchronize do
        self.push event
        event.instance_exec { set_status(:delayed) }
      end
      CFSM.logger.info "Pushed delayed event #{event.inspect}"
      @wait_thread.wakeup if self.length > 0 && self.first == event
    end

    # Removes the referenced element from the queue.
    def cancel( event )
      result = false

      @queue_mutex.synchronize do
        result = self.delete(event)
        event.instance_exec { set_status( :cancelled ) } if result
      end

      if result
        @wait_thread.wakeup if self.length > 0 && self.first == event
        CFSM.logger.info "Cancelled delayed event #{event.inspect}"
      end

      result
    end

    # Cancels all delayed events within the queue.
    def cancel_all
      self.each { |event| self.cancel(event) }
    end

    # Used if the delayed event queue is no longer needed.  Destroys the array and kills the waiting thread.
    # Reason for destroying is to make sure that nobody uses the array again.
    def kill
      @queue_mutex.synchronize do
        if @wait_thread
          @wait_thread.kill
          @wait_thread = nil
        end
        self.delete_if { |item| true }
      end
    end

    private

    # This private method is invoked by #post once we have the first event posted to the queue.
    # This ensures the system as a whole is operational (avoids some otherwise nasty race conditions in the CFSM class)
    # and also ensure we don't waste processor resource until we need it.
    def start_wait_thread
      @wait_thread = Thread.new do
        @wait_thread.abort_on_exception = true

        loop do
          if self.empty?
            CFSM.logger.debug 'Main loop of DelayedQueue: infinite sleep'
            sleep 5
          elsif self.first.expiry <= Time.now then
            event = nil
            @queue_mutex.synchronize { event = self.shift }
            CFSM.logger.info "Retrieved delayed event #{event.inspect}"
            # Note, for reasons I don't understand, we need to yield first, and then reset expiry.
            @expiry_handler.yield( event )
            CFSM.logger.debug 'Main loop of DelayedQueue: Back from yield'
            event.reset_expiry
          else
            delay = self.first.expiry - Time.now
            CFSM.logger.debug "Main loop of DelayedQueue: Sleep for #{self.first.expiry - Time.now}"
            sleep( self.first.expiry - Time.now ) if delay > 0
          end
        end
      end
    end
  end
end
