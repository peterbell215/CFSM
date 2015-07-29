# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'condition_parser'
require 'rspec/expectations'

RSpec::Matchers.define :have_parse_tree do |expected|
  match { |actual| ConditionParser::compare_parse_trees(expected, actual) }
end

describe ConditionParser do
  subject( :condition_parser) { ConditionParser.new }

  describe "#compare_parse_arrays" do
    it "should return nil for two arrays with no common members" do
      expect( ConditionParser::compare_parse_arrays( [ :a, :b ], [:c, :d] ) ).to be_nil     
    end
 
    it "should match two equal arrays" do
      array = [ :a, :b ]
      expect( ConditionParser::compare_parse_arrays( array, array.clone ) ).to be true

      expect( ConditionParser::compare_parse_arrays( array, array.clone.insert(1, array.sample ) ) ).to be true

      expect( ConditionParser::compare_parse_arrays( array.clone.insert(1, array.sample ), array ) ).to be true
    end
   
    it "should not match two un-equal arrays" do
      result = ConditionParser::compare_parse_arrays( [ :a, :b ], [:b, :c, :d] )
      expect( result[:common] ).to match_array( [ :b ] )
      expect( result[:only_1] ).to match_array( [ :a ] )
      expect( result[:only_2] ).to match_array( [ :c, :d ] )
    end
  end  
  
  describe "#compare_parse_trees" do
    it "should correctly compare the same parse tree." do
      res1 = { :or => [
           { :comparison => { :left => 'a.b', :comparator => '==', :right => '1'} },
           { :comparison => { :left=>'a.c', :comparator => '<', :right=> '2'} } ] }
      res2 = { :or => [
          { :comparison => { :left => 'a.b', :comparator => '==', :right => '1'} },
          { :comparison => { :left=>'a.c', :comparator => '<', :right=> '2'} } ] }

      expect( ConditionParser::compare_parse_trees(res1, res2) ).to be true
    end
  end

  describe "#parse" do
    it "should parse a simple comparison with different white space configs" do
      result = { :comparison => {:left => {:event => 'a.b'}, :comparator => '==', :right => {:number => '1'} } }
      expect( condition_parser.parse( "a.b==1" ) ).to have_parse_tree( result )
      expect( condition_parser.parse( "a.b ==1" ) ).to have_parse_tree( result )
      expect( condition_parser.parse( "a.b== 1" ) ).to have_parse_tree( result )
      expect( condition_parser.parse( "a.b == 1" ) ).to have_parse_tree( result )
    end

    it "should parse two comparisons joined by an 'or' expression" do
      @result = { :or => [
         { :comparison => { :left=>"a.b", :comparator=>"==", :right=>"1"} },
         { :comparison => { :left=>"a.c", :comparator=>"<", :right=>"2" } } ] }

      expect( @condition_parser.parse( "a.b==1 or a.c<2" ) ).to have_parse_tree( @result )
    end

    it "should parse two comparisons joined by an 'and' expression" do
      @result = { :and => [
        { :comparison => {:left=>"a.b", :comparator=>"==", :right=>"1"} }, 
        { :comparison => {:left=>"a.c", :comparator=>"<", :right=>"2" } } ] }

      expect( @condition_parser.parse( "a.b==1 and a.c<2" ) ).to have_parse_tree( @result )   
    end

    it "should parse a bracketed sub-expression" do
      @result = { :and => [
        { :comparison => {:left=>"a.b", :comparator=>"==", :right=>"1" } },
        { :brackets => {
            :or => [
              { :comparison => {:left=>"a.c", :comparator=>">", :right=>"4" } },
              { :comparison => {:left=>"a.c", :comparator=>"<", :right=>"2" } } ]
          }
        } ] }

      expect( @condition_parser.parse( "a.b==1 and (a.c>4 or a.c<2)" ) ).to have_parse_tree( @result )
    end

    it "should evaluate an event field against a string" do
      expect( @condition_parser.parse( 'abba=="abba"') ).to have_parse_tree( :comparison =>
          { :left=>"abba", :comparator=>"==", :right=> { :string => "abba" } } )
    end

    it "should evaluate a single event field" do
      expect( @condition_parser.parse( "abba==1") ).to have_parse_tree( :comparison => { :left=>"abba", :comparator=>"==", :right=>"1" } )
    end

    it "should evaluate state definitions correctly" do
      expect( @condition_parser.parse( ":initial" ) ).to have_parse_tree( { :state => ":initial" } )
    end

    it "should flag an error if state variable has a dot" do
      expect( @condition_parser.parse( ":initial.this_should_not_be_here" ) ).to raise_error( Parslet::ParseFailed )
    end
  end
  
  
end

