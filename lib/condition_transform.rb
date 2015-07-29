# Part of the parslet family.  Transforms the condition tree into a linear array of ComparisonNode's and BranchNodes
# Each ComparisonNode will evaluate a condition.  BranchNodes are used to evaluate OR conditions.  So the 

require 'parslet'
require 'event_condition'

class ConditionTransform < Parslet::Transform
  rule( :string => simple(:s) ) { String.new( s.str ) }
  rule( :number => simple(:n) ) { n.to_f }
  rule( :symbol => simple(:s) ) { s.to_s[1..-1].to_sym }

  rule( :comparison => { :left => { :event => simple(:e) }, :comparator => simple(:comparator), :right => subtree(:right) } ) do
    EventCondition.new( comparator.str.to_sym, e, right )
  end

  rule( :comparison => { :left => subtree(:left), :comparator => simple(:comparator), :right => subtree(:right) } ) do
    [ comparator.str.to_sym, left, right ]
  end
end
