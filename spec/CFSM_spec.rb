require 'rspec'

require 'cfsm'
require 'cfsm_event'

class TestFSM_A < CFSM
  state( :a, :initial => true ) { on :event1, :transition => :b }
end

module TestModule
  class TestFSM_B < CFSM
    state :d, :initial => true do
      on :event1, :transition => :e
    end
  end
  class TestFSM_C < CFSM
    state( :a, :initial => true ) { on :event1, :transition => :b }
  end
end

describe CFSM do
  describe '#state_machines' do

    it 'should test something' do
      pending

      fail

      fsm = TestFSM_A.new
    end
  end

  describe '#start' do
    context 'namespace option' do
      it 'should start a single CFSM system' do
        pending

        fail

        CFSM.start :namespace => Test1
      end

      it 'should start multiple CFSM systems' do
        pending

        fail

        CFSM.start :namespace => [Test1, Test2]
      end

      it 'should start all CFSM systems' do
        pending

        fail

        CFSM.start
      end

      it 'should raise an error if we try to start on a namespace' do
        pending

        fail

        expect { Test1.start }.to raise_error( OnlyStartOnCFSMClass )
      end
    end
    context 'async option' do
      it 'should create a separate thread when async' do
        pending

        fail
      end

      it 'should not create a separate thread when async false' do
        pending

        fail
      end
    end
  end


  context 'running the FSMs' do
    it 'should create a simple state machine' do
      class TestFSM < CFSM
        state :a do
          on :event1, :transition => :b
        end
      end
      fsm = TestFSM.new

      expect( fsm.state ).to eq( :a )

      CFSM.start :async => false

      CFSM.post( CfsmEvent.new(:event1) )

      expect( fsm.state ).to eq( :b )
    end

    it 'should advance only one state machine of a class if the second is in the wrong state' do
      class TestFSM < CFSM
        state :a do
          on :event1, :transition => :b
        end

      end
      pending

    end
  end

end