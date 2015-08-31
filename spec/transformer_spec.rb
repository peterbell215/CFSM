# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

require 'parslet'
require 'cfsm'
require 'cfsm_event'
require 'condition_parser/parser'
require 'condition_parser/condition_cache'
require 'condition_parser/transformer'
require 'condition_parser/fsm_state_variable'

require 'rspec/expectations'

module ConditionParser
  RSpec::Matchers.define :have_parse_tree do |expected|
    match { |actual| Parser::compare_parse_trees(expected, actual) }
  end

  describe Transformer do
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

      it 'should produce an evaluation of an OR set of conditions' do
        result = condition_parser.process_if('a == 4 or b == "Peter"', CfsmEvent, TestFSM  )
        expect( result ).to have_parse_tree(
          { :or =>
            [
                ConditionParser::EventCondition.new( :==, EventAttribute.new('a'), 4 ),
                ConditionParser::EventCondition.new( :==, EventAttribute.new('b'), 'Peter' )
            ]
          } )
      end

      it 'should produce an evaluation of an expression including brackets' do
        result = condition_parser.process_if('a == 4 and (@b == "Peter" or c<5)', CfsmEvent, TestFSM  )
        expect( result ).to have_parse_tree(
          { :and =>
            [
                ConditionParser::EventCondition.new( :==, EventAttribute.new( 'a' ), 4.0),
                { :or =>
                    [
                        ConditionParser::EventCondition.new( :==, FsmStateVariable.new( TestFSM, 'b' ), 'Peter' ),
                        ConditionParser::EventCondition.new( :<, EventAttribute.new('c'), 5 )
                    ]
                }
            ]
          } )
      end

      describe 'cache_conditions' do
        it 'should convert EventConditions to cached Fixnums' do
          result = condition_parser.process_if('a == 4 and (@b == "Peter" or c<5)', CfsmEvent, TestFSM  )
          cache = ConditionCache.new
          Transformer.cache_conditions( cache, result )

          expect( result ).to have_parse_tree( {:and=>[0, {:or=>[1, 2]}]} )

          expect( cache[0] ).to eq ConditionParser::EventCondition.new( :==, EventAttribute.new( 'a' ), 4.0)
          expect( cache[1] ).to eq ConditionParser::EventCondition.new( :==, FsmStateVariable.new( TestFSM, 'b' ), 'Peter' )
          expect( cache[2] ).to eq ConditionParser::EventCondition.new( :<, EventAttribute.new('c'), 5.0 )
        end
      end
    end

    describe 'self.generate_permutations(tree)' do
      describe 'self.and' do
        it 'should combine two arguments under AND' do
          expect( Transformer.and( 1, 2 ) ).to match_array [ [ 1, 2 ] ]
          expect( Transformer.and( 1, [2, 3] ) ).to match_array [ [ 1, 2, 3 ] ]
          expect( Transformer.and( [1, 2], 3 ) ).to match_array [ [ 1, 2, 3 ] ]
          expect( Transformer.and( [1, 2], [3, 4] ) ).to match_array [ [ 1, 2, 3, 4 ] ]
          expect( Transformer.and( [1, 2] , [[3, 4], [5, 6] ] ) ).to match_array [[1, 2, 3, 4], [1, 2, 5, 6]]
          expect( Transformer.and( [[1, 2], [3, 4]], [[5, 6], [7, 8]] ) ).to match_array [[1, 2, 5, 6], [1, 2, 7, 8], [3, 4, 5, 6], [3, 4, 7, 8]]
        end
      end

      describe 'self.or' do
        it 'should combine two arguments under AND' do
          expect( Transformer.or( 1, [] ) ).to match_array [ [ 1 ] ]
          expect( Transformer.or( [], 2 ) ).to match_array [ [ 2 ] ]
          expect( Transformer.or( 1, 2 ) ).to match_array [[ 1 ], [ 2 ]]
          expect( Transformer.or( 1, [2, 3] ) ).to match_array [[ 1 ], [ 2, 3 ]]
          expect( Transformer.or( [1, 2], 3 ) ).to match_array [[ 1, 2 ], [ 3 ]]
          expect( Transformer.or( [1, 2], [3, 4] ) ).to match_array [[ 1, 2], [ 3, 4 ]]
          expect( Transformer.or( [[1, 2], [3, 4]], [5, 6] ) ).to match_array [[ 1, 2], [3, 4], [5, 6 ]]
          expect( Transformer.or( [1, 2], [[3, 4], [5, 6]] ) ).to match_array [[1, 2], [3, 4], [5, 6]]

        end
      end

      it 'should turn a single condition into a single element array' do
        expect( Transformer.generate_permutations( 1 ) ).to match_array [ [1] ]
      end

      it 'should turn a set of ANDed conditions into an array' do
        expect( Transformer.generate_permutations( { :and => [ 1, 2 ] } ) ).to match_array [ [ 1, 2] ]
        expect( Transformer.generate_permutations( { :and => [ 1, 2, 3 ] } ) ).to match_array [ [ 1, 2, 3] ]
      end

      it "should turn a set of ORed conditions into an array" do
        expect( Transformer.generate_permutations( { :or => [ 1, 2 ] } ) ).to match_array [ [ 1 ], [ 2 ] ]
        expect( Transformer.generate_permutations( { :or => [ 1, 2, 3 ] } ) ).to match_array [ [ 1 ], [ 2 ], [ 3 ] ]
      end

      it 'should correctly combine (1 OR (2 AND 3) => [1], [2, 3]' do
        expect( Transformer.generate_permutations( { :or => [ 1, { :and => [ 2, 3 ] } ] } ) ).to match_array [ [ 1 ], [ 2, 3 ] ]
        expect( Transformer.generate_permutations( { :or => [ { :and => [ 1, 2 ] }, 3 ] } ) ).to match_array [ [ 1, 2 ], [ 3 ] ]
      end

      it 'should correctly combine (1 AND (2 OR 3) => [1, 2], [1, 3]' do
        expect( Transformer.generate_permutations( { :and => [ 1, { :or => [ 2, 3 ] } ] } ) ).to match_array [ [ 1, 2 ], [ 1, 3 ] ]
        # expect( Transformer.generate_permutations( { :or => [ { :and => [ 1, 2 ] }, 3 ] } ) ).to match_array [ [ 1, 2 ], [ 3 ] ]
      end
    end
  end
end
