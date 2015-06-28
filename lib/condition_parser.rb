# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'parslet'
require './lib/condition_transform'

require 'byebug'

class ConditionParser < Parslet::Parser
  root( :or_expression )

  # Simple types
  rule(:digit)          { match["0-9"] }
  rule(:space)          { match["\t "] }
  rule(:space?)         { space.repeat }
  rule(:string)         { str('"') >> ((str('\"').absent? >> str('"')).absent? >> any).repeat.as(:string) >> str('"') }
  rule(:varname)        { match("[A-Za-z]").repeat(1) >> ( str(".") >> match("[A-Za-z0-9_]").repeat(1) ).maybe }
  rule(:comparator)     { str("==") | str("!=") | str("<") | str("<=") | str(">") | str(">=") }

  # Simple classes
  rule(:number) {
    ( str('-').maybe >>
    (str('0') | (match('[1-9]') >> digit.repeat)) >>
    (str('.') >> digit.repeat(1)).maybe >>
    (
      (str('e') | str('E')) >>
      (str('+') | str('-')).maybe >>
      digit.repeat(1)
    ).maybe ).as(:number) }
  rule(:boolean)        { str("true") | str("false") }
  rule(:state_var)      { (str("@") >> varname).as( :state_var ) }
  rule(:state_name)     { (str(":") >> varname).as( :state ) }
  rule(:event)          { varname }

  # Grammar parts
  rule(:or_expression)  { ( and_expression >> ( space >> str("or") >> space >> or_expression).repeat(1) ).as(:or) | and_expression }
  rule(:and_expression) { ( evaluation >> ( space >> str("and") >> space >> evaluation).repeat(1) ).as(:and) | evaluation }
  rule(:evaluation)     { comparison.as(:comparison) | boolean_test | brackets.as(:brackets) }
  rule(:brackets)       { str("(") >> or_expression >> str(")") }
  rule(:comparison)     { lhs.as(:left) >> space? >> comparator.as(:comparator) >> space? >> rhs.as(:right) }
  rule(:lhs)            { state_var | event }
  rule(:rhs)            { lhs | number| string | boolean }

  rule(:boolean_test)   { str("!").maybe >> (state_name | event) }

  # Compare two arrays within the parse tree and identify the elements that
  # are common and those that are different.
  # [ a, b ], [ c, d ] => nil
  # [ a, b], [a, b ] => true
  # [ a, b, c ], [ a, b, d ] => { :common => [a, b], only_1 => [:c], only_2 => [:d] }
  # [ a, b, b ], [ a, b ] => { :common => [a, b], only_1 => nil, only_2 => nil }
  # [ a, b ] != [ a, b, b] => { :common => [a, b], only_1 => nil, only_2 => nil }
  def self.compare_parse_arrays(array1, array2)
    common = []
    only_1 = Array.new( array1 )
    only_2 = Array.new( array2 )

    only_1.delete_if do | elem1 |
      # check if we have already moved elem1 to common array
      if common.find_index { |elem2| compare_parse_trees( elem1, elem2) }
        true
      # check if elem1 is present in only_2 and remove it if necessary
      elsif only_2.reject! { |elem2| compare_parse_trees( elem1, elem2 ) }
        # we have already removed elem1 from only_2.  Now need to add to
        # common and to remove from only_1
        common << elem1
        true
      end
    end
    
    # sort out what we return
    if common.empty?
      nil
    elsif only_1.empty? && only_2.empty?
      true
    else
      { :common => common, :only_1 => only_1, :only_2 => only_2 }
    end
  end

  # compare to elements.
  def self.compare_parse_elements(elem1, elem2)
    e1 = elem1.instance_of?( Parslet::Slice ) && elem1.str || elem1
    e2 = elem2.instance_of?( Parslet::Slice ) && elem2.str || elem2

    e1 == e2
  end

  def self.compare_parse_trees(expected, actual)
     if actual.instance_of?( Array ) && expected.instance_of?( Array )
      return compare_parse_arrays(expected, actual) == true
    elsif actual.instance_of?( Hash  ) && expected.instance_of?( Hash )
      actual.each_pair do |key, value|
        return false if !compare_parse_trees(expected[key], value)
      end
      # if we got here, then every parse element in the array2 is also in the
      # array1.  Therefore, so long as they are the same length, they are equal.
      return actual.length == expected.length
    else
      return compare_parse_elements(expected, actual)
    end
  end
end

p = ConditionParser.new
t = ConditionTransform.new
tree = p.parse('a==1 and b==2 or a<4 and b<2 and c>"peter"')
puts tree.inspect
puts t.apply( tree ).inspect 