require 'rspec'
require 'cfsm'
require 'cfsm_event'

describe CFSM do
  it 'should create a simple state machine' do
    class TestFSM < CFSM
      state :a, :on => :event1, :transition => :b, :initial => true
    end
    fsm = TestFSM.new

    expect( fsm.state ).to eq( :a )

    CfsmEvent.new(:event1, self)

    expect( fsm.state ).to eq( :b )
  end
end