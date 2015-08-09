require 'rspec'
require 'cfsm'
require 'cfsm_event'

describe CFSM do
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
        state :a, :on => :event1, :transition => :b, :initial => true
      end
      fsm = TestFSM.new

      expect( fsm.state ).to eq( :a )

      CFSM.start :async => false

      CFSM.post( CfsmEvent.new(:event1, self) )

      expect( fsm.state ).to eq( :b )
    end
  end

end