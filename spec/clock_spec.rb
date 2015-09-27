# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

require 'rspec'

require 'cfsm'
require 'cfsm_event'

describe CFSM do
  it 'should run a clock FSM correctly' do
    class Clock < CFSM
      state :tick do
        on :swing, :transition => :tock, :exec => :increment_clock
      end

      state :tock do

      end
    end
  end
end
