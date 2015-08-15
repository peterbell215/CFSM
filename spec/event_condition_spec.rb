# @author Peter Bell
# Licensed under MIT.

require 'rspec'

require 'cfsm'
require 'cfsm_event'
require 'condition_parser/event_condition'

class TestFSM1 < CFSM
  state :a do
    on :test_event, :transition => :b, :initial => true
  end

  def initialize( test_var )
    @test_var = test_var
  end
  attr_reader :test_var
end

class TestFSM2 < CFSM
  state :c do
    on :test_event, :transition => :d
  end
end

module ConditionParser
  describe EventCondition do
    let( :test_fsm1_1 ) { TestFSM1.new( 5 ) }
    let( :fsm_condition1 ) { EventCondition::fsm_state_checker(TestFSM1, :a) }
    let( :fsm_condition2 ) { EventCondition.new(:==, FsmStateVariable(:test_var), 5) }
    let( :test_event ) { CfsmEvent.new( :test_event, :test_var => 5 ) }

    describe '#fsm_state_checker' do
      it 'should generate a state checker correctly do' do
        expect( condition1 ).to eq EventCondition.new(:==, FsmStateVariable.new(TestFSM1, :state), :a)
      end
    end

    describe '#evaluate' do
      context 'event evaluation' do

      end

      context 'state evaluation' do
        it 'should match the correct FSM.' do
          expect( fsm_condition1.evaluate( nil, test_event ) ).to match_array test_fsm1
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
