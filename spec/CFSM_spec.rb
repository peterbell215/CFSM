require 'rspec'

require 'cfsm'
require 'cfsm_event'

class TestFSM_A < CFSM
  state(:a) { on :event1, :transition => :b }
end

module TestModule
  class TestFSM_B < CFSM
    state(:d) { on :event1, :transition => :e }
  end
  class TestFSM_C < CFSM
    state(:a) { on :event1, :transition => :b }
  end
end

describe CFSM do
  describe '#namespace' do
    it 'should return the correct namespaces' do
      expect( TestFSM_A.namespace ).to eql( 'Global' )
      expect( TestModule::TestFSM_B.namespace ).to eql( 'TestModule' )
      expect( TestModule::TestFSM_C.namespace ).to eql( 'TestModule' )
    end
  end

  describe '#state_machines' do
    it 'should return all instantiated state machines for that class' do
      test_fsm_a = TestFSM_A.new
      test_fsm_b1 = TestModule::TestFSM_B.new
      test_fsm_b2 = TestModule::TestFSM_B.new
      test_fsm_c = TestModule::TestFSM_C.new

      expect( CFSM.state_machines( TestFSM_A ) ).to match_array [ test_fsm_a ]
      expect( CFSM.state_machines( TestModule::TestFSM_B ) ).to match_array [ test_fsm_b1, test_fsm_b2 ]
      expect( CFSM.state_machines( TestModule::TestFSM_C ) ).to match_array [ test_fsm_c ]
    end
  end

  describe '#set_state' do
    it 'should not be possible to externally set the state of FSM' do
      test_fsm_a = TestFSM_A.new

      expect{ test_fsm_a.set_state() }.to raise_exception( NoMethodError )
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