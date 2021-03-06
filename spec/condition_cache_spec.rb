# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.
require 'rspec'

require 'CFSM'

module ConditionParser
  describe ConditionCache do
    before(:all) { class TestFSM < CFSM; end }

    # Note, these can be created using RSpec `subject`, as this is evaluated lazily.  This means that some of the
    # CFSM classes might be empty causing CFSM to complain about lack of instantiated FSMs for a specific class.
    let!( :event_condition1 ) { EventCondition.new(:==, EventAttribute.new('attribute'), 5.0) }
    let!( :event_condition2 ) { EventCondition.new(:==, EventAttribute.new('attribute'), 5.0 ) }
    let!( :event_condition3 ) { EventCondition.new(:<, EventAttribute.new('attribute'), 5.0) }
    let!( :fsm_condition1 ) { EventCondition::fsm_state_checker(TestFSM, :started) }
    let!( :fsm_condition2 ) { EventCondition::fsm_state_checker(TestFSM, :started) }
    let!( :fsm_condition3 ) { EventCondition::fsm_state_checker(TestFSM, :ended) }

    it 'should add new items to the hash' do
      expect( subject.add(event_condition1) ).to equal(event_condition1)
      expect( subject.add(event_condition3) ).to equal(event_condition3)
      expect( subject.add(fsm_condition1) ).to equal(fsm_condition1)
      expect( subject.add(fsm_condition3) ).to equal(fsm_condition3)
    end

    it 'should return the first entry if the condition is already in the hash' do
      subject.add event_condition1
      expect( subject.add(event_condition2) ).to equal(event_condition1)
      subject.add fsm_condition1
      expect( subject.add fsm_condition2 ).to equal(fsm_condition1)
    end
  end
end
