# Part of the parslet family.  Transforms the condition tree into a linear array of ComparisonNode's and BranchNodes
# Each ComparisonNode will evaluate a condition.  BranchNodes are used to evaluate OR conditions.  So the 
require 'parslet'

class ConditionTransform < Parslet::Transform
  rule( :left => sequence(:left), :comparator => simple(:comparator), :right => sequence(:right) ) do
    [ comparator.str.to_sym, left, right ]
  end
  
  rule( :string => simple(:s) ) { String.new( s.str ) }
  rule( :number => simple(:n) ) { n.to_f }
  rule( :symbol => simple(:s) ) { s.to_s[1..-1].to_sym }
end
