# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

module CfsmClasses
  # This class implements a thread safe priority queue designed around our requirements.
  class PrioQueue
    def initialize
      @queues = Array.new
      @mutex = Mutex.new
      @queue_wait = ConditionVariable.new
    end

    # Pushes an element onto the queue taking account of priority.
    # @param [Object] element - element to be pushed into queue.
    # @return [PrioQueue] - reference to self
    def push(element)
      @mutex.synchronize do
        (@queues[element.prio] ||= Array.new).push element
        @queue_wait.signal
      end
      self
    end

    # Removes the highest priority element that has longest been in the queue.
    # @return [Object] returns the highest priority element.
    def pop
      result = nil
      @mutex.synchronize do
        @queue_wait.wait( @mutex ) if size==0

        (@queues.size-1).downto(0).each do |queue_index|
          if @queues[queue_index] && @queues[queue_index].size > 0
            result = @queues[queue_index].shift
            break
          end
        end
      end
      result
    end

    # Allows the calling thread to wait for a new element to have been added.
    def wait_for_new_event
      @mutex.synchronize { @queue_wait.wait( @mutex ) }
    end

    # Returns an array copy of the queue with the correct ordering.
    # @return [Array] the array of elements in the queue.
    def to_a
      result = []
      @mutex.synchronize do
        (@queues.size-1).downto(0).each do |queue_index|
          result.concat @queues[queue_index] if @queues[queue_index] && @queues[queue_index].size > 0
        end
      end
      result
    end

    # Removes the referenced element from the queueu.

    def remove( element )
      @mutex.synchronize do
        if @queues[ element.prio ] && (index = @queues[ element.prio ].find_index( element ) )
          return @queues[ element.prio ].delete_at(index)
        end
      end
    end

    def pop_each
      while self.size>0
        event = pop
        yield event
      end
    end

    def peek_each
      self.to_a.each { |e| yield e }
    end

    def size
      @queues.inject(0) { |s, q| s += q ? q.size : 0 }
    end

    def inspect
      result = "queue:\n"
      self.peek_each do |obj|
        result << "#{obj.inspect}\n"
      end
      result
    end
  end
end
