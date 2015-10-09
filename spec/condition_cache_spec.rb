# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.
require 'rspec'

require 'cfsm'

module ConditionParser
  describe 'ConditionCache' do
    before(:all) { class TestFSM < CFSM; end }
    subject(:condition_hash) { ConditionCache.new }
    let!( :event_condition1 ) { EventCondition.new(:==, EventAttribute.new('attribute'), 5.0) }
    let!( :event_condition2 ) { EventCondition.new(:==, EventAttribute.new('attribute'), 5.0 ) }
    let!( :event_condition3 ) { EventCondition.new(:<, EventAttribute.new('attribute'), 5.0) }
    let!( :fsm_condition1 ) { EventCondition::fsm_state_checker(TestFSM, :started) }
    let!( :fsm_condition2 ) { EventCondition::fsm_state_checker(TestFSM, :started) }
    let!( :fsm_condition3 ) { EventCondition::fsm_state_checker(TestFSM, :ended) }

    it 'should add new items to the hash' do
      expect( condition_hash << event_condition1 ).to eq(0)
      expect( condition_hash << event_condition3 ).to eq(1)
      expect( condition_hash << fsm_condition1 ).to eq(2)
      expect( condition_hash << fsm_condition3 ).to eq(3)
    end

    it 'should return the first entry if the condition is already in the hash' do
      expect( condition_hash << event_condition1 ).to eq(0)
      expect( condition_hash << event_condition2 ).to eq(0)
      expect( condition_hash << fsm_condition1 ).to eq(1)
      expect( condition_hash << fsm_condition2 ).to eq(1)
    end
  end
end
