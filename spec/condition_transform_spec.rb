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
    subject( :condition_transform ) { ConditionTransform.new }
    let( :condition_parser ) { Parser.new }

    context 'single condition evaluations' do
      it 'should produce an EventCondition of a comparison with a String' do
        expected_result = ConditionParser::EventCondition.new( :==, EventAttribute.new('a'), 'Peter')
        expect( condition_transform.apply( condition_parser.parse('a == "Peter"' ) ) ).to eq( expected_result )
      end

      it 'should produce an evaluation of a comparison with an Integer' do
        expected_result = ConditionParser::EventCondition.new( :==, EventAttribute.new('a'), 4)
        expect( condition_transform.apply( condition_parser.parse('a == 4' ) ) ).to eq( expected_result )
      end

      it 'should produce an evaluation of a comparison with a FSM state variable' do
        expected_result = ConditionParser::EventCondition.new( :<, FsmStateVariable.new('distance_to_travel'), 5.0)
        expect( condition_transform.apply( condition_parser.parse( '@distance_to_travel < 5.0' ) ) ).to eq( expected_result )
      end
    end

    context 'Complex expression evaluations' do
      it 'should produce an evaluation of an AND set of conditions' do
        result = condition_transform.apply( condition_parser.parse('a == 4 and b == "Peter"' ) )
        expect( result ).to be_a Hash
        expect( result[:and] ).to be_a Array
        expect( result[:or] ).to be_nil
        expect( result[:and][0] ).to eq( ConditionParser::EventCondition.new( :==, EventAttribute.new('a'), 4 ) )
        expect( result[:and][1] ).to eq( ConditionParser::EventCondition.new( :==, EventAttribute.new('b'), 'Peter' ) )
      end
    end




    it "should produce an evaluation of an OR set of conditions" do
      result = condition_transform.apply( condition_parser.parse('a == 4 or b == "Peter"' ) )
      expect( result ).to be_a Hash
      expect( result[:or] ).to be_a Array
      expect( result[:o] ).to be_nil
      expect( result[:or][0] ).to eq( ConditionParser::EventCondition.new( :==, EventAttribute.new('a'), 4 ) )
      expect( result[:or][1] ).to eq( ConditionParser::EventCondition.new( :==, EventAttribute.new('b'), 'Peter' ) )
    end

    it "should produce an evaluation of an expression including brackets" do

    end
  end
end
