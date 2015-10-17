# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

module CfsmClasses
  # Creates an array that is maintained in a sorted fashion.  Note, that if two elements are the same
  # then the second element is inserted after the first.  This ensures that for two elements with the
  # same priority we maintain first-in-first-out as required for a prioritised queue.
  class SortedArray < Array
    # @param [Object] element - element to be inserted
    # @return [SortedArray] - self
    def push(element)
      if self.empty? || element >= self.last
        super element
      elsif element < self.first
        self.unshift element
      elsif self.length < 6
        # Faster to do linear scan for less than 10 elements.
        0.step do |i|
          if self[i] <= element && element < self[i + 1]
            self.insert(i+1, element)
            break
          end
        end
      else
        # Binary search
        index = step = self.length / 2
        until self[index]<=element && element < self[index+1]
          step /= 2 if step > 1
          index += self[index] <= element ? step : -step
        end
        self.insert(index+1, element)
      end
      self
    end
  end
end