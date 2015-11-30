# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

require 'rspec'

require 'cfsm'

# TODO add missing tests

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
    let!( :test_event ) { CfsmEvent.new( :test_event, :data => { :test_var => 5 } ) }
    let!( :fsm_state_variable ){ FsmStateVariable.new(TestFSM1,:test_var) }
    let!( :event_attribute ){ EventAttribute.new(:test_var) }

    describe '#fsm_state_checker' do
      it 'should generate a state checker correctly do' do
        expect( fsm_condition1 ).to eq EventCondition.new(:==, FsmStateVariable.new(TestFSM1, :state), :a)
      end
    end

    describe '#evaluate' do
      let!( :fsm_state_variable ){ FsmStateVariable.new(TestFSM1,:test_var) }
      let!( :event_attribute ){ EventAttribute.new(:test_var) }

      context 'event evaluation' do
        it 'should evaluate an event attribute against a constant' do
          expect( EventCondition.new(:==, fsm_state_variable, 5).evaluate(test_event, :all) ).to contain_exactly( test_fsm1_1 )
          expect( EventCondition.new(:!=, fsm_state_variable, 5).evaluate(test_event, :all) ).to be_empty
        end
      end

      context 'state evaluation' do
        it 'should match the correct FSM.' do
          expect( fsm_condition1.evaluate( test_event, :all ) ).to match_array test_fsm1_1
        end
      end

      context 'combined event and state evaluation' do
        it 'should compare event attribute to a FSM attribute' do
          expect( EventCondition.new(:==, fsm_state_variable, event_attribute ).evaluate(test_event, :all) ).to contain_exactly( test_fsm1_1 )
          expect( EventCondition.new(:==, event_attribute, fsm_state_variable ).evaluate(test_event, :all) ).to contain_exactly( test_fsm1_1 )
          expect( EventCondition.new(:!=, fsm_state_variable, event_attribute ).evaluate(test_event, :all) ).to be_empty
          expect( EventCondition.new(:!=, event_attribute, fsm_state_variable ).evaluate(test_event, :all) ).to be_empty
        end
      end
    end

    describe '#hash' do
      it 'should generate the same hash for two identical EventConditions' do
        ech1 = EventCondition.new(:<, fsm_state_variable, event_attribute).hash
        ech2 = EventCondition.new(:>, event_attribute, fsm_state_variable).hash
        ech3 = EventCondition.new(:>=, event_attribute, fsm_state_variable).hash

        expect( ech1 ).to eql(ech2)
        expect( ech1 ).to_not eql(ech3)
      end
    end

    describe '#==' do
      it 'should compare two EventConditions correctly' do
        ec1 = EventCondition.new(:==, fsm_state_variable, 5)
        ec2 = EventCondition.new(:==, fsm_state_variable, 5)
        ec3 = EventCondition.new(:==, event_attribute, 5)
        ec4 = EventCondition.new(:==, event_attribute, 5)

        expect( ec1==ec2 ).to be true
        expect( ec3==ec4 ).to be true
        expect( ec1==ec3 ).to be false
        expect( ec2==ec4 ).to be false
      end

      it 'should compare two EventConditions that are inverse of each other correctly' do
        ec1 = EventCondition.new(:<, fsm_state_variable, event_attribute)
        ec2 = EventCondition.new(:>, event_attribute, fsm_state_variable)
        ec3 = EventCondition.new(:>=, event_attribute, fsm_state_variable)
        expect( ec1==ec2 ).to be true
        expect( ec1==ec3 ).to be false
      end
    end
  end
end
