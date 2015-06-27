# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'condition_parser'
require 'rspec/expectations'

RSpec::Matchers.define :have_parse_tree do |expected|
  match { |actual| compare_parse_trees(expected, actual) }
end

describe ConditionParser do
  before(:each) do
    @condition_parser = ConditionParser.new
  end

  describe "#parse" do
    it "should parse a simple comparison with different white space configs" do
      @result = { :comparison => { :left=>"a.b", :comparator=>"==", :right=>"1" } }
      expect( @condition_parser.parse( "a.b==1" ) ).to have_parse_tree( @result )
      expect( @condition_parser.parse( "a.b ==1" ) ).to have_parse_tree( @result )
      expect( @condition_parser.parse( "a.b== 1" ) ).to have_parse_tree( @result )
      expect( @condition_parser.parse( "a.b == 1" ) ).to have_parse_tree( @result )
    end

    it "should parse two comparisons joined by an 'or' expression" do
      @result = { :or => {
          :left => {
            :comparison =>
              {:left=>"a.b", :comparator=>"==", :right=>"1"}
          },
          :right => {
            :comparison =>
              { :left=>"a.c", :comparator=>"<", :right=>"2" }
          }
        } 
      }

      expect( @condition_parser.parse( "a.b==1 or a.c<2" ) ).to have_parse_tree( @result )
    end

    it "should parse two comparisons joined by an 'and' expression" do
      @result = { :and => {
          :left => {
            :comparison => 
              { :left=>"a.b", :comparator=>"==", :right=>"1"} 
          },
          :right => {
            :comparison => 
              {:left=>"a.c", :comparator=>"<", :right=>"2"}
          }
        }
      }
      expect( @condition_parser.parse( "a.b==1 and a.c<2" ) ).to have_parse_tree( @result )   
    end

    it "should parse a bracketed sub-expression" do
      @result = { :and => {
          :left => {
            :comparison =>
              { :left=>"a.b", :comparator=>"==", :right=>"1" }
          },
          :right => {
            :brackets => {
              :or => {
                :left => {
                  :comparison => {
                    :left=>"a.c", :comparator=>">", :right=>"4" }
                },
                :right => {
                  :comparison => {
                    :left=>"a.c", :comparator=>"<", :right=>"2"
                  }
                }
              }
            }
          }
        }
      }

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
  
  describe "#compare_parse_arrays" do
    it "should match two equal arrays" do
      expect( ConditionParser::compare_parse_arrays( [ :a, :b, :c], [:a, :b, :c] ) ).to be true
    end
    
    it "should not match two un-equal arrays" do
      expect( ConditionParser::compare_parse_arrays( [ :a, :b ], [:b, :c, :d] ) ).to be false
      expect( ConditionParser::compare_parse_arrays( [:b, :c, :d], [ :a, :b ] ) ).to be false
      expect( ConditionParser::compare_parse_arrays( [:b, :c, :d], [ :a, :b, :e ] ) ).to be false
    end
    
    it "should not match [ a, b, b ] and [ a, b ]" do
      expect( ConditionParser::compare_parse_arrays( [ :a, :b, :b ], [:a, :b ] ) ).to be false
    end
  end
end

