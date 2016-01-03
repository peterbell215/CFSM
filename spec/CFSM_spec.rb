# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.

require 'rspec'
require 'rspec/wait'

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

      module TestModuleB
        class TestFSM_B < CFSM
          state(:d) { on :event1, :transition => :e }
        end
      end
      module TestModuleC
        class TestFSM_C < CFSM
          state(:a) { on :event1, :transition => :b }
        end
      end
    end

    # TODO replace let! with subject
    let!( :test_fsm_a) { TestFSM_A.new }
    let!( :test_fsm_b1) { TestModuleB::TestFSM_B.new :test_fsm_b1 }
    let!( :test_fsm_b2) { TestModuleB::TestFSM_B.new :test_fsm_b2 }
    let!( :test_fsm_c) { TestModuleC::TestFSM_C.new 'test_fsm_c' }

    describe '#initialize' do
      it 'should create the state machines with the correct names' do
        expect( test_fsm_a.name ).to match( /CFSM_spec\.rb:\d+:in `new'/ )
        expect( test_fsm_b1.name ).to eq( :test_fsm_b1 )
        expect( test_fsm_b2.name ).to eq( :test_fsm_b2 )
        expect( test_fsm_c.name ).to eq( 'test_fsm_c' )
      end
    end

    describe '::reset' do
      it 'should allow the state machine system to be reset.' do
        CFSM.logger.level = Logger::DEBUG

        expect( test_fsm_a.state ).to eq( :a )
        expect( test_fsm_a.test_method ).to eq( 'Test method invoked' )

        event = CfsmEvent.new(:event1, :delay => 3600 )

        CFSM.start :sync => false
        CFSM.post( event )

        CFSM.logger.debug(' Rspec ')
        CFSM.logger.debug( CFSM.dump_to_string )

        # At this point the CFSM is running.  Now reset.
        CFSM.reset

        # Having killed the CFSMs, the queues should have been emptied.  Therefore,
        # *event* should always return to the *nil* status.
        sleep( 2 )
        expect( event.status ).to be_nil

        # Check that the various state machines have disappeared from the CFSM system
        expect { TestFSM_A.new }.to raise_error( NameError )
        expect { TestModuleB::TestFSM_B.new }.to raise_error( NameError )

        # redefine the class from above to check that it will be newly loaded.
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
        expect( TestModuleB::TestFSM_B.namespace ).to eql( 'TestModuleB' )
        expect( TestModuleC::TestFSM_C.namespace ).to eql( 'TestModuleC' )
      end
    end

    describe '::state_machines' do
      it 'should return all instantiated state machines for that class' do
        expect( CFSM.state_machines( TestFSM_A ) ).to match_array [ test_fsm_a ]
        expect( CFSM.state_machines( TestModuleB::TestFSM_B ) ).to match_array [ test_fsm_b1, test_fsm_b2 ]
        expect( CFSM.state_machines( TestModuleC::TestFSM_C ) ).to match_array [ test_fsm_c ]
      end
    end

    describe '#set_state' do
      it 'should not be possible to externally set the state of FSM' do
        expect{ test_fsm_a.set_state }.to raise_exception( NoMethodError )
      end
    end

    describe '#inspect' do
      it 'should convert to a string the internal state correctly' do
        expect( test_fsm_a.inspect ).to match( /<name = "CFSM_spec.rb:\d+:in `new'", state = a>/ )
        expect( test_fsm_b1.inspect ).to eq( '<name = :test_fsm_b1, state = d>' )
        expect( test_fsm_b2.inspect ).to eq( '<name = :test_fsm_b2, state = d>' )
        expect( test_fsm_c.inspect ).to eq( '<name = "test_fsm_c", state = a>' )
      end
    end

    describe '#dump_to_string' do
      it 'should return a description of the state of the system' do
        result = CFSM.dump_to_string.split(/\r?\n/)
        expected_result = <<HEREDOC
Namespace: Global
Thread status: not started
Condition graph: N/A
Current queue: uninitialised
Status of each FSM:
{TestFSM_A=>[<name = "CFSM_spec.rb:39:in `new'", state = a>]}
**************************
Namespace: TestModuleB
Thread status: not started
Condition graph: N/A
Current queue: uninitialised
Status of each FSM:
{TestModuleB::TestFSM_B=>[<name = :test_fsm_b1, state = d>, <name = :test_fsm_b2, state = d>]}
**************************
Namespace: TestModuleC
Thread status: not started
Condition graph: N/A
Current queue: uninitialised
Status of each FSM:
{TestModuleC::TestFSM_C=>[<name = "test_fsm_c", state = a>]}
**************************
HEREDOC
        expected_result = expected_result.split(/\r?\n/)
        0.upto( result.length-1 ).each do |i|
          # Line 2 is the condition graph.  Its rendered in a way that is difficult to check if correct.
          expect(result[i]).to eq(expected_result[i]) if i % 7 != 2
        end
      end
    end

    describe '::start' do
      context 'starting one, two or all namespaces in either sync or async mode' do
        { :all => 'all namespaces', :TestModuleB => 'one namespace', [:Global, :TestModuleB] => 'two namespaces' }.each_pair do |namespace, namespace_string|
          { false => 'async mode', true => 'sync mode' }.each_pair do |sync_mode, sync_string|
            it "should start #{namespace_string} in #{sync_string}" do
              CFSM.logger.debug "testing start #{namespace_string} in #{sync_string}"
              options = {}
              options[:namespace] = namespace unless namespace == :all
              options[:sync] = true if sync_mode

              expect(test_fsm_a.state).to eql(:a)
              expect(test_fsm_b1.state).to eql(:d)
              expect(test_fsm_c.state).to eql(:a)

              CFSM.start options
              CFSM.post(event = CfsmEvent.new(:event1))

              # If we are operating in async mode, then wait for the event to have been processed.
              unless options[:sync]
                CFSM.logger.debug( CFSM.dump_to_string )

                wait_for { event.status('TestModuleB') }.to eq( :processed )
              end

              expect(test_fsm_a.state).to eql(options[:namespace]==:TestModuleB ? :a : :b)    # only progresses if all namespaces executed
              expect(test_fsm_b1.state).to eql(:e)                                            # always progresses
              expect(test_fsm_c.state).to eql(options[:namespace].nil? ? :b : :a )           # doesn't progress if only TestModuleB run

              CFSM.reset
            end
          end
        end
      end

      it 'should raise an error if we try to start a namespace that has no FSMs' do
        class EmptyFSM < CFSM
          state :a do
            on :event, :transition => :b
          end
        end

        expect { CFSM.start }.to raise_error( CFSM::EmptyCFSMClass )
      end

      it 'should raise an error if we try to start on a namespace' do
        expect { TestFSM_A.start }.to raise_error( CFSM::OnlyStartOnCFSMClass )
      end

      context 'async option' do
        it 'should create a separate thread when async' do
          CFSM.start

          expect( TestFSM_A.thread_status ).to eq('run').or eq('sleep')
        end

        it 'should not create a separate thread when async false' do
          CFSM.start :sync => true

          expect( TestFSM_A.thread_status ).to eq('sync mode')
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
      # noinspection RubyArgCount
      fsm = TestFSM.new

      expect( fsm.state ).to eq( :a )

      CFSM.start :sync => true
      CFSM.post( CfsmEvent.new(:event1) )

      expect( fsm.state ).to eq( :b )
    end

    context 'event cancelling' do
      before(:each) do
        class TestFSM < CFSM
          state :a do
            on :event1, :transition => :b, :if => 'testcase==1'
          end
        end
      end

      it 'should be possible to cancel an event that is waiting' do
        test_fsm = TestFSM.new
        CFSM.start
        event1 = CfsmEvent.new(:event1, :delay => 3600, :data => { :testcase => 0 })
        CFSM.post event1
        expect( event1.status ).to eq( :delayed )
        expect( CFSM.cancel event1 ).to be_truthy
        expect( event1.status ).to be_nil
      end

      it 'should be possible to cancel an event that is waiting' do
        test_fsm = TestFSM.new
        CFSM.start
        event1 = CfsmEvent.new(:event1, :data => { :testcase => 0 })
        CFSM.post event1
        expect( event1.status ).to eq( :pending )
        expect( CFSM.cancel event1 ).to be_truthy
        expect( event1.status ).to be_nil
      end
    end

    it 'should advance only one state machine of a class if the second is in the wrong state' do
      class TestFSM < CFSM
        state :a do
          on :event1, :transition => :b
        end

        def set_initial_state( initial_state )
          self.instance_exec( initial_state ) { |s| set_state(s) }
        end
      end

      fsm_0 = TestFSM.new
      fsm_0.set_initial_state( :a )
      fsm_1 = TestFSM.new
      fsm_1.set_initial_state( :c )

      CFSM.start :sync => true
      CFSM.post( CfsmEvent.new(:event1) )

      expect( fsm_0.state ).to eq( :b )
      expect( fsm_1.state ).to eq( :c )
    end

    context 'if processing' do
      context 'state variable test' do
        before( :each ) do
          class TestFSM < CFSM
            state :a do
              on :event1, :transition => :b, :if => '@test==1'
            end

            def initialize
              # noinspection RubyArgCount
              super
              @test = 0
            end

            attr_accessor :test
          end
        end

        # TODO replace with subject
        # noinspection RubyArgCount
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

      context 'event variable test' do
        # TODO these need creating.
      end

      context 'event variable against state variable' do
        before( :each ) do
          class TestFSM < CFSM
            state :a do
              on :event1, :transition => :b, :if => 'src==@name'
            end
          end
        end

        let!( :fsm1 ){ TestFSM.new :fsm1 }
        let!( :fsm2 ){ TestFSM.new :fsm2 }

        it 'should correctly compare the event attribute to the state attribute' do
          CFSM.start :sync => true
          expect( fsm1.state ).to eq(:a)
          expect( fsm2.state ).to eq(:a)

          event = CfsmEvent.new :event1, :src => :fsm1, :autopost => true

          expect( fsm1.state ).to eq(:b)
          expect( fsm2.state ).to eq(:a)
        end
      end
    end
  end

  context 'options for ::on' do
    describe 'proc to test transition' do
      before(:each) do
        CFSM.reset

        class TestDo < CFSM
          state :a do
            on :event, :transition => :b do |event|
              # We can't use expectation matchers within this method.  They cause the system to timeout.  Better
              # store the results in a hash and check them later.
              @result = { :name => self.name, :event => event, :state => self.state }
              # Set the return based on what we are testing.
              @fail_proc
            end
          end

          state :c do
            on :event, :transition => :d, :exec => :test_transition
          end

          state :f do
            on :event, :transition => :g do |event|
              # This should cause the method to raise an error.
              self.state.non_existent_method
            end
          end

          def set_initial_state( initial_state )
            self.instance_exec( initial_state ) { |s| set_state(s) }
          end

          def test_transition(event, next_state)
            @result = { :name => self.name, :event => event, :state => self.state, :next_state => next_state }
            # Set the return based on what we are testing.
            @fail_proc
          end

          def initialize( fail_proc )
            super( :test_do )
            @result = {}
            @fail_proc = fail_proc
          end

          attr_reader :result
        end
      end

      let!(:event) { CfsmEvent.new( :event ) }

      ['block' , 'method'].each do |exec_style|
        [false, true].each do |test_case|
          # TODO this sometimes fails to run due to some form of race condition.
          it "should #{'not ' unless test_case}transition to new state if #{exec_style} returns #{test_case.to_s}" do
            fsm = TestDo.new( test_case )
            fsm.set_initial_state( :c ) if exec_style=='method'

            CFSM.start
            CFSM.post( event )

            wait_for { event.status }.to eq( :processed )

            expect( fsm.result[:name] ).to eq( :test_do )
            expect( fsm.result[:event] ).to equal( event )
            expect( fsm.result[:state] ).to eq( :a ) if exec_style=='block'
            expect( fsm.result[:state] ).to eq( :c ) if exec_style=='method'
            expect( fsm.result[:next_state] ).to eq( :d ) if exec_style=='method'

            expect( fsm.state ).to eq( :a ) if !test_case && exec_style=='block'
            expect( fsm.state ).to eq( :b ) if test_case && exec_style=='block'
            expect( fsm.state ).to eq( :c ) if !test_case && exec_style=='method'
            expect( fsm.state ).to eq( :d ) if test_case && exec_style=='method'
          end
        end
      end

      it 'should correctly handle an Exception in the block' do
        fsm = TestDo.new( 'block' )
        fsm.set_initial_state( :f )

        CFSM.start
        CFSM.post( event )
        expect { sleep 30 }.to raise_error NoMethodError
      end
    end
  end

end