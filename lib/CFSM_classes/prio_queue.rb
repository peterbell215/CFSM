# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.

module CfsmClasses
  # This class implements a thread safe priority queue designed around our requirements.
  class PrioQueue
    def initialize
      @queue = SortedArray.new { |e1, e2| e2.prio <=> e1.prio }
      @mutex = Mutex.new
      @queue_wait = ConditionVariable.new
      @waiting_threads = []
    end

    # Pushes an element onto the queue taking account of priority.
    # @param [Object] element - element to be pushed into queue.
    # @return [PrioQueue] - reference to self
    def push(element)
      @mutex.synchronize do
        @queue.push element
        @queue_wait.signal
      end
      self
    end

    # Removes the highest priority element that has longest been in the queue.  If the
    # queue is empty, block until a new element is added.
    #
    # @return [Object] returns the highest priority element.
    def pop
      @mutex.synchronize do
        if size==0
          @waiting_threads << Thread.current
          @queue_wait.wait(@mutex)
        end
        @waiting_threads.delete Thread.current
        @queue.shift
      end
    end

    # Allows the calling thread to wait for a new element to have been added.
    def wait_for_new_event
      @mutex.synchronize do
        @waiting_threads << Thread.current
        @queue_wait.wait(@mutex)
        @waiting_threads.delete Thread.current
      end
    end

    # Indicates whether the given thread is waiting on this priority queue.
    def thread_waiting?( t )
      @mutex.synchronize { !@waiting_threads.index( t ).nil? }
    end

    # Returns an array copy of the queue with the correct ordering.
    # @return [Array] the array of elements in the queue.
    def to_a
      @mutex.synchronize { Array.new( @queue ) }
    end

    # Removes the referenced element from the queue.
    def delete( element )
      @mutex.synchronize { @queue.delete( element ) }
    end

    def each
      @queue.each { |e| yield e }
    end

    def pop_each
      while self.size>0
        event = pop
        yield event
      end
    end

    def size
      @queue.size
    end

    def inspect
      result = "queue:\n"
      self.each do |obj|
        result << "#{obj.inspect}\n"
      end
      result
    end
  end
end
