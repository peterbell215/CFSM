# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.
require 'parslet'

class ConditionParser < Parslet::Parser
  root( :or_expression ) 
    
  # Simple types
  rule(:digit)          { match["0-9"] }
  rule(:space)          { match["\t "] }
  rule(:space?)         { space.repeat }
  rule(:string)         { str('"') >> ((str('\"').absent? >> str('"')).absent? >> any).repeat.as(:string) >> str('"') }
  rule(:varname)        { match("[A-Za-z0-9_]").repeat(1) >> ( str(".") >> match("[A-Za-z0-9_]").repeat(1) ).maybe }
  rule(:comparator)     { str("==") | str("!=") | str("<") | str("<=") | str(">") | str(">=") }
  
  # Simple classes
  rule(:number) {
    str('-').maybe >>
    (str('0') | (match('[1-9]') >> digit.repeat)) >>
    (str('.') >> digit.repeat(1)).maybe >>
    (
      (str('e') | str('E')) >>
      (str('+') | str('-')).maybe >>
      digit.repeat(1)
    ).maybe }
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
  
  # Compare two arrays within the parse tree. we need to test that for each
  # element in actual there is a corresponding element in array1.
  # We have a couple of edge cases to worry about:
  # [ a, b, b ] != [ a, b ]
  # [ a, b ] != [ a, b, b] 
  def self.compare_parse_arrays(array1, actual)
    array1 = Array.new( array1 )
    matches = 0

    actual.each do |a|
      array1.each_index do |e|
        if compare_parse_trees(a, array1[e] )
          array1.delete_at( e )
          matches += 1
          break;
        end 
      end
    end
    return matches == actual.length && array1.empty?    
  end
  
  def self.compare_parse_trees(expected, actual)
    if actual.instance_of?( Array ) && expected.instance_of?( Array )
      return compare_parse_arrays(expected, actual)
    elsif actual.instance_of?( Hash  ) && expected.instance_of?( Hash )
      actual.each_pair do |key, value|
        if value.instance_of? Parslet::Slice
          return false if value.str != expected[key]
        else
          return false if !compare_parse_trees(expected[key], value)
        end   
      end
      # if we got here, then every parse element in the actual is also in the
      # array1.  Therefore, so long as they are the same length, they are equal.
      return actual.length == expected.length
    else
      return actual == expected
    end
  end
end

p = ConditionParser.new
puts p.parse('a==1 and b==2 or a<4 and b<2 and c>4').inspect
