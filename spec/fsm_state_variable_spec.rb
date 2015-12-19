# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.
require 'rspec'
require 'rspec/wait'
require 'rspec/expectations'

require 'cfsm'

module ConditionParser
  describe FsmStateVariable do
    before(:each) do
      CFSM.reset

      class TestFSM_A < CFSM
        state(:a) { on :event1, :transition => :b }
      end
      class TestFSM_B < CFSM
        state(:a) { on :event2, :transition => :b }
      end
    end

    subject { FsmStateVariable.new( TestFSM_A, :a ) }

    describe '#==' do
      it 'should return true if the two state variable tests are the same' do
        expect( subject==FsmStateVariable.new( TestFSM_A, :a ) ).to be_truthy
      end

      it 'should return false if the two state variables disagree' do
        expect( subject==FsmStateVariable.new( TestFSM_A, :b ) ).to be_falsey
      end

      it 'should return false if the two state variables agree but the test refers to different state machines' do
        expect( subject==FsmStateVariable.new( TestFSM_B, :a) ).to be_falsey
      end

      it 'should return false if the state variable test is being compared to an event condition' do
        expect( subject==EventAttribute.new( :method1 ) ).to be_falsey
      end
    end

    describe '#hash' do
      it 'should return true if the two state variable tests are the same' do
        expect( subject.hash ).to eq FsmStateVariable.new( TestFSM_A, :a ).hash
      end

      it 'should return false if the two state variables disagree' do
        expect( subject.hash ).not_to eq FsmStateVariable.new( TestFSM_A, :b ).hash
      end
    end

  end
end