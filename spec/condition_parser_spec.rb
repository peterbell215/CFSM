# @author Peter Bell
# Licensed under MIT2

require 'parslet'
require 'cfsm'
require 'cfsm_event'
require 'condition_parser/parser'
require 'condition_parser/transformer'
require 'condition_parser/fsm_state_variable'

require 'rspec/expectations'

module ConditionParser
  RSpec::Matchers.define :have_parse_tree do |expected|
    match { |actual| Parser::compare_parse_trees(expected, actual) }
  end

  describe Parser do
    subject( :condition_parser ) { Parser.new }

    describe '#compare_parse_arrays' do
      it 'should return nil for two arrays with no common members' do
        expect( Parser::compare_parse_arrays( [ :a, :b ], [:c, :d] ) ).to be_nil
      end

      it 'should match two equal arrays' do
        array = [ :a, :b ]
        expect( Parser::compare_parse_arrays( array, array.clone ) ).to be true
        expect( Parser::compare_parse_arrays( array, array.clone.insert(1, array.sample ) ) ).to be true
        expect( Parser::compare_parse_arrays( array.clone.insert(1, array.sample ), array ) ).to be true
      end

      it 'should not match two un-equal arrays' do
        result = Parser::compare_parse_arrays( [ :a, :b ], [:b, :c, :d] )
        expect( result[:common] ).to match_array( [ :b ] )
        expect( result[:only_1] ).to match_array( [ :a ] )
        expect( result[:only_2] ).to match_array( [ :c, :d ] )
      end
    end

    describe '#compare_parse_trees' do
      it 'should correctly compare the same parse tree.' do
        res1 = { :or => [
             { :comparison => { :left => 'a.b', :comparator => '==', :right => '1'} },
             { :comparison => { :left=>'a.c', :comparator => '<', :right=> '2'} } ] }
        res2 = { :or => [
            { :comparison => { :left => 'a.b', :comparator => '==', :right => '1'} },
            { :comparison => { :left=>'a.c', :comparator => '<', :right=> '2'} } ] }

        expect( Parser::compare_parse_trees(res1, res2) ).to be true
      end
    end

    describe '#parse' do
      it 'should parse a simple comparison with different white space configs' do
        result = { :comparison => {:left => {:event => 'a.b'}, :comparator => '==', :right => {:number => '1'} } }
        expect( condition_parser.parse('a.b==1') ).to have_parse_tree( result )
        expect( condition_parser.parse('a.b ==1') ).to have_parse_tree( result )
        expect( condition_parser.parse('a.b== 1') ).to have_parse_tree( result )
        expect( condition_parser.parse('a.b == 1') ).to have_parse_tree( result )
      end

      it "should parse two comparisons joined by an 'or' expression" do
        result = { :or => [
           { :comparison => { :left=>{:event => 'a.b'}, :comparator=> '==', :right=>{:number => '1'} } },
           { :comparison => { :left=>{:event => 'a.c'}, :comparator=> '<', :right=>{:number => '2'} } } ] }

        expect( condition_parser.parse('a.b==1 or a.c<2') ).to have_parse_tree( result )
      end

      it "should parse two comparisons joined by an 'and' expression" do
        result = { :and => [
          { :comparison => {:left=> {:event => 'a.b'}, :comparator=> '==', :right=> {:number => '1'} } },
          { :comparison => {:left=> {:event => 'a.c'}, :comparator=> '<', :right=> {:number => '2'} } } ] }

        expect( condition_parser.parse('a.b==1 and a.c<2') ).to have_parse_tree( result )
      end

      it 'should parse a bracketed sub-expression' do
        result = { :and => [
          { :comparison => {:left=> {:event=>'a.b'}, :comparator=> '==', :right=> {:number => '1'} } },
          { :brackets => {
              :or => [
                { :comparison => {:left=> {:event => 'a.c'}, :comparator=> '>', :right=> {:number => '4'} } },
                { :comparison => {:left=> {:event => 'a.c'}, :comparator=> '<', :right=> {:number => '2'} } } ]
          } } ] }

        expect( condition_parser.parse('a.b==1 and (a.c>4 or a.c<2)') ).to have_parse_tree( result )
      end

      it 'should evaluate an event field against a string' do
        expect( condition_parser.parse( 'abba=="abba"') ).to have_parse_tree(
          :comparison => { :left=> {:event => 'abba'}, :comparator=> '==', :right=> { :string => 'abba'} } )
      end

      it 'should evaluate a single event field' do
        expect( condition_parser.parse('abba==1') ).to have_parse_tree(
          :comparison => { :left=> {:event => 'abba'}, :comparator=>"==", :right=> { :number => '1'} } )
      end

      it 'should evaluate state definitions correctly' do
        expect( condition_parser.parse(':initial') ).to have_parse_tree( { :symbol => ':initial' } )
      end

      it 'should flag an error if state variable has a dot' do
        expect { condition_parser.parse(':initial.this_should_not_be_here') }.to raise_error( Parslet::ParseFailed )
      end
    end
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

  describe
end
