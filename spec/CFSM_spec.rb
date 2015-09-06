# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

require 'rspec'

require 'cfsm'
require 'cfsm_event'

describe CFSM do
  # Reset the CFSM system each time we start an RSpec so we can define an FSM specific to the test
  before(:each) do
    CFSM.reset
  end

  context 'helper functions' do
    before(:each) do
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

    let!( :test_fsm_a) { TestFSM_A.new }
    let!( :test_fsm_b1) { TestModule::TestFSM_B.new }
    let!( :test_fsm_b2) { TestModule::TestFSM_B.new }
    let!( :test_fsm_c) { TestModule::TestFSM_C.new }

    describe '::reset' do
      it 'should allow the state machine system to be reset.' do
        expect( test_fsm_a.state ).to eq( :a )

        event = CfsmEvent.new(:event1, :delay => 2 )

        CFSM.start :sync => false
        CFSM.post( event )

        # At this point the CFSM is running.  Now reset.
        CFSM.reset

        # Having killed the CFSMs, the queues should have been emptied.  Therefore,
        # *event* should always remain in the *delayed* status.
        sleep( 2 )
        expect( event.status ).to eq( :delayed )

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
        expect( CFSM.state_machines( TestFSM_A ) ).to match_array [ test_fsm_a ]
        expect( CFSM.state_machines( TestModule::TestFSM_B ) ).to match_array [ test_fsm_b1, test_fsm_b2 ]
        expect( CFSM.state_machines( TestModule::TestFSM_C ) ).to match_array [ test_fsm_c ]
      end
    end

    describe '#set_state' do
      it 'should not be possible to externally set the state of FSM' do
        expect{ test_fsm_a.set_state() }.to raise_exception( NoMethodError )
      end
    end

    describe '::start' do
      context 'namespace option' do
        it 'should start a single CFSM system' do
          # TODO handle both sync and async.
          expect( test_fsm_a.state ).to eql( :a )
          expect( test_fsm_b1.state ).to eql( :d )
          expect( test_fsm_c.state ).to eql( :a )

          CFSM.start :namespace => TestModule, :sync => true

          CFSM.post( CfsmEvent.new(:event1) )

          expect( test_fsm_a.state ).to eql( :a )
          expect( test_fsm_b1.state ).to eql( :e )
          expect( test_fsm_c.state ).to eql( :b )
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

        def initialize( initial_state )
          super()
          self.instance_exec( initial_state ) { |s| set_state(s) }
        end
      end

      fsm_0 = TestFSM.new( :a )
      fsm_1 = TestFSM.new( :c )

      CFSM.start :sync => true
      CFSM.post( CfsmEvent.new(:event1) )

      expect( fsm_0.state ).to eq( :b )
      expect( fsm_1.state ).to eq( :c )
    end

    context 'if processing' do
      before( :each ) do
        class TestFSM < CFSM
          state :a do
            on :event1, :transition => :b, :if => '@test==1'
          end

          def initialize
            super
            @test = 0
          end

          attr_accessor :test
        end
      end

      let!( :fsm ) { TestFSM.new }

      it 'should not advance if a state variable is not correctly set' do
        fsm.test = 1
        CFSM.start :sync => true

        expect( fsm.state ).to eq( :a )
        CFSM.post( CfsmEvent.new(:event1) )
        expect( fsm.state ).to eq( :b )
      end

      it "should advance once the FSM's member variable is correctly set" do
        CFSM.start :sync => true
        expect( fsm.state ).to eq( :a )
        event = CfsmEvent.new(:event1)
        CFSM.post( event )
        expect( fsm.state ).to eq( :a )
        fsm.test = 1
        CFSM.eval( fsm )
        expect( fsm.state ).to eq( :b )
      end
    end
  end
end