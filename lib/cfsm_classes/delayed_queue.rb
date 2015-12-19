# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.

require 'cfsm'

module CfsmClasses
  # This class implements a queue for delayed events using a binary heap.  The algorithm is as described on the
  # Wikipedia page.  Once a delayed event is posted, it is given an expiry time.  Alternatively, it may have an
  # expiry time set.
  class DelayedQueue < SortedArray
    def initialize
      @queue_mutex = Mutex.new
      event = nil

      super { |e1, e2| e1.expiry <=> e2.expiry }

      @wait_thread = Thread.new do
        loop do
          if self.empty?
            CFSM.logger.debug 'Main loop of DelayedQueue: infinite sleep'
            sleep 5
          elsif self.first.expiry <= Time.now then
            event = nil
            @queue_mutex.synchronize { event = self.shift }
            CFSM.logger.info "Retrieved delayed event #{event.inspect}"
            # Note, for reasons I don't understand, we need to yield first, and then reset expiry.
            yield( event )
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

    attr_reader :wait_thread

    # Note that event expiry needs to be set by the caller.
    def post( event )
      raise CfsmEvent::EventDoesNotHaveExpiry if event.expiry.nil?
      @queue_mutex.synchronize { self.push event }
      CFSM.logger.info "Pushed delayed event #{event.inspect}"
      @wait_thread.wakeup if self.length > 0 && self.first == event
    end

    # Removes the referenced element from the queueu.
    def cancel( event )
      CFSM.logger.info "Cancelled delayed event #{event.inspect}"
      result = nil
      @queue_mutex.synchronize { result = self.delete( event ) }
      @wait_thread.wakeup if self.length > 0 && self.first == event
      result
    end

    # Used if the delayed event queue is no longer needed.  Destroys the array and kills the waiting thread.
    # Reason for destroying is to make sure that nobody uses the array again.
    def kill
      @queue_mutex.synchronize do
        @wait_thread.kill
        @wait_thread = nil
        self.delete_if { |item| true }
      end
    end
  end
end
