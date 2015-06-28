# Part of the parslet family.  Transforms the condition tree into a linear array of ComparisonNode's and BranchNodes
# Each ComparisonNode will evaluate a condition.  BranchNodes are used to evaluate OR conditions.  So the 
require 'parslet'

class ConditionTransform < Parslet::Transform
  # rule( :comparison => { :left => sequence(:left), :comparator => single(:comparator), :right => sequence(:right) } ) do
  #  [ comparator, left, right ]
  # end
  
  # rule( :comparator => simple(:op) ) { op.to_sym }
  rule( :string => simple(:s) ) { String.new(s) }
  rule( :number => simple(:n) ) { n.to_f }
end
