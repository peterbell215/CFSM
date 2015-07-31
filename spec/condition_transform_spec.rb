# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'cfsm'
require 'cfsm_event'
require 'condition_parser/parser'
require 'condition_parser/condition_transform'
require 'condition_parser/fsm_state_variable'

require 'rspec/expectations'

module ConditionParser
  describe ConditionTransform do
    subject( :condition_parser ) { Parser.new }
    before(:all) do
      class TestFSM < CFSM; end
    end

    context 'single condition evaluations' do
      it 'should produce an EventCondition of a comparison with a String' do
        expected_result = ConditionParser::EventCondition.new( :==, EventAttribute.new('a'), 'Peter')
        expect( condition_parser.process_if( 'a == "Peter"', CfsmEvent, TestFSM ) ).to eq( expected_result )
      end

      it 'should produce an evaluation of a comparison with an Integer' do
        expected_result = ConditionParser::EventCondition.new( :==, EventAttribute.new('a'), 4)
        expect( condition_parser.process_if( 'a == 4', CfsmEvent, TestFSM ) ).to eq( expected_result )
      end

      it 'should produce an evaluation of a comparison with a FSM state variable' do
        expected_result = ConditionParser::EventCondition.new( :<, FsmStateVariable.new( TestFSM, 'distance_to_travel'), 5.0)
        expect( condition_parser.process_if( '@distance_to_travel < 5.0', CfsmEvent, TestFSM ) ).to eq( expected_result )
      end

      it 'should produce an evaluation of a comparison between an event variable and with a FSM state variable' do
        result = condition_parser.process_if( '@distance_to_travel < threshold_on_distance', CfsmEvent, TestFSM )
        expected_result = ConditionParser::EventCondition.new( :<, FsmStateVariable.new( TestFSM, 'distance_to_travel' ),
                                                               EventAttribute.new('threshold_on_distance') )
        expect( result ).to eq( expected_result )
      end
    end

    context 'Complex expression evaluations' do
      it 'should produce an evaluation of an AND set of conditions' do
        result = condition_parser.process_if( 'a == 4 and b == "Peter"', CfsmEvent, TestFSM )
        expect( result ).to be_a Hash
        expect( result[:and] ).to be_a Array
        expect( result[:or] ).to be_nil
        expect( result[:and][0] ).to eq( ConditionParser::EventCondition.new( :==, EventAttribute.new('a'), 4 ) )
        expect( result[:and][1] ).to eq( ConditionParser::EventCondition.new( :==, EventAttribute.new('b'), 'Peter' ) )
      end
    end

    it "should produce an evaluation of an OR set of conditions" do
      result = condition_parser.process_if('a == 4 or b == "Peter"', CfsmEvent, TestFSM  )
      expect( result ).to be_a Hash
      expect( result[:or] ).to be_an Array
      expect( result[:and] ).to be_nil
      expect( result[:or][0] ).to eq( ConditionParser::EventCondition.new( :==, EventAttribute.new('a'), 4 ) )
      expect( result[:or][1] ).to eq( ConditionParser::EventCondition.new( :==, EventAttribute.new('b'), 'Peter' ) )
    end

    it "should produce an evaluation of an expression including brackets" do
      result = condition_parser.process_if('a == 4 and (@b == "Peter" or c<5)', CfsmEvent, TestFSM  )
      expect( result ).to be_a Hash
      expect( result[:and] ).to be_an Array
      expect( result[:and][0] ).to eq ConditionParser::EventCondition.new( :==, EventAttribute.new( 'a' ), 4.0)
      expect( result[:and][1] ).to be_a Hash
      expect( result[:and][1][:or] ).to be_an Array
      expect( result[:and][1][:or][0] ).to eq( ConditionParser::EventCondition.new( :==, FsmStateVariable.new( TestFSM, 'b' ), 'Peter' ) )
      expect( result[:and][1][:or][1] ).to eq( ConditionParser::EventCondition.new( :<, EventAttribute.new('c'), 5.0 ) )
    end
  end
end
