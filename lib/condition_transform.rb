# Part of the parslet family.  Transforms the condition tree into a linear array of ComparisonNode's and BranchNodes
# Each ComparisonNode will evaluate a condition.  BranchNodes are used to evaluate OR conditions.  So the 

class ConditionTransform < Parslet::Transform
  rule( :comparison => { :left => sequence(:left), :comparator => single(:comparator), :right => sequence(:right) } ) do
    ComparisonNode.new( comparator.to_sym, left, right)
  end
  
  rule( :string => simple(:s) ) { String.new(s) }
  
end
