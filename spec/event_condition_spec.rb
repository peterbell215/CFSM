# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

require 'rspec'

require 'cfsm'
require 'cfsm_event'
require 'condition_parser/fsm_state_variable'
require 'condition_parser/event_condition'

module ConditionParser
  describe EventCondition do
    before(:each) do
      CFSM.reset

      class TestFSM1 < CFSM
        state :a do
          on :test_event, :transition => :b, :initial => true
        end

        def initialize( test_var )
          super()
          @test_var = test_var
        end
        attr_reader :test_var
      end

      class TestFSM2 < CFSM
        state :c do
          on :test_event, :transition => :d
        end
      end
    end

    let!( :test_fsm1_1 ) { TestFSM1.new( 5 ) }
    let!( :fsm_condition1 ) { EventCondition::fsm_state_checker(TestFSM1, :a) }
    let!( :test_event ) { CfsmEvent.new( :test_event, :test_var => 5 ) }

    describe '#fsm_state_checker' do
      it 'should generate a state checker correctly do' do
        expect( fsm_condition1 ).to eq EventCondition.new(:==, FsmStateVariable.new(TestFSM1, :state), :a)
      end
    end

    describe '#evaluate' do
      context 'event evaluation' do

      end

      context 'state evaluation' do
        it 'should match the correct FSM.' do
          expect( fsm_condition1.evaluate( :all, test_event ) ).to match_array test_fsm1_1
        end
      end

      context 'combined event and state evaluation' do

      end
    end

    describe '#hash' do

    end

    describe '#==' do

    end
  end
end
