# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.

module CfsmClasses
  # Creates an array that is maintained in a sorted fashion.  Note, that if two elements are the same
  # then the second element is inserted after the first.  This ensures that for two elements with the
  # same priority we maintain first-in-first-out as required for a prioritised queue.
  class SortedArray < Array
    # Constructor.  Given a block.  This is used to evaluate the relative importance of the two elements.
    #
    # Example:
    # SortedArray.new { |e1, e2| e1.prio <=> e2.prio }
    def initialize( &comp_proc )
      @cmp_proc = comp_proc
    end

    # @param [Object] element - element to be inserted
    # @return [SortedArray] - self
    def push(element)
      if self.empty? || @cmp_proc.call(element, self.last) >=0
        super element
      elsif @cmp_proc.call(element, self.first) < 0
        self.unshift element
      elsif self.length < 6
        # Faster to do linear scan for less than 10 elements.
        0.step do |i|
          if @cmp_proc.call(self[i], element)<=0 && @cmp_proc.call(element, self[i + 1]) < 0
            self.insert(i+1, element)
            break
          end
        end
      else
        # Binary search
        index = step = self.length / 2
        until @cmp_proc.call(self[index], element)<=0 && @cmp_proc.call(element, self[index+1])<0
          step /= 2 if step > 1
          index += @cmp_proc.call(self[index], element)<=0 ? step : -step
        end
        self.insert(index+1, element)
      end
      self
    end
  end
end