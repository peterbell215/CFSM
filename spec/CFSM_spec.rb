# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

require 'rspec'

require 'cfsm'
require 'cfsm_event'

describe CFSM do
  before(:each) do
    CFSM.reset

    class TestFSM_A < CFSM
      state(:a) { on :event1, :transition => :b }

      def test_method
        'Test method invoked'
      end
    end

    module TestModule
      class TestFSM_B < CFSM
        state(:d) { on :event1, :transition => :e }
      end
      class TestFSM_C < CFSM
        state(:a) { on :event1, :transition => :b }
      end
    end
  end

  describe '::reset' do
    it 'should allow the state machine system to be reset.' do
      test_fsm_a = TestFSM_A.new
      test_fsm_b1 = TestModule::TestFSM_B.new
      test_fsm_b2 = TestModule::TestFSM_B.new
      test_fsm_c = TestModule::TestFSM_C.new

      expect( test_fsm_a.state ).to eq( :a )

      event = CfsmEvent.new(:event1, :delay => 2 )

      CFSM.start :sync => false
      CFSM.post( event )

      # At this point the CFSM is running.  Now reset.
      CFSM.reset

      # Having killed the CFSMs, the queues should have been emptied.  Therefore,
      # *event* should always remain in the *delayed* status.
      sleep( 2 )
      # TODO need to fix status of events
      # expect( event.status ).to eq( :delayed )

      # Check that the various state machines have disappeared from the CFSM system
      expect { TestFSM_A.new }.to raise_error( NameError )
      expect { TestModule::TestFSM_B.new }.to raise_error( NameError )

      class TestFSM_A < CFSM
        state(:c) { on :event1, :transition => :d }

        def test_method
          'New test method invoked'
        end
      end

      test_fsm_new_a = TestFSM_A.new
      expect( test_fsm_new_a.test_method ).to eq( 'New test method invoked' )
    end
  end

  describe '::namespace' do
    it 'should return the correct namespaces' do
      expect( TestFSM_A.namespace ).to eql( 'Global' )
      expect( TestModule::TestFSM_B.namespace ).to eql( 'TestModule' )
      expect( TestModule::TestFSM_C.namespace ).to eql( 'TestModule' )
    end
  end

  describe '::state_machines' do
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

  describe '::start' do
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

      CFSM.start :sync => true

      CFSM.post( CfsmEvent.new(:event1) )

      expect( fsm.state ).to eq( :b )
    end

    it 'should advance only one state machine of a class if the second is in the wrong state' do
      class TestFSM < CFSM
        state :a do
          on :event1, :transition => :b
        end
      end
# todo

    end
  end

end