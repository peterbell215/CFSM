# Part of the parslet family.  Transforms the condition tree into a linear array of ComparisonNode's and BranchNodes
# Each ComparisonNode will evaluate a condition.  BranchNodes are used to evaluate OR conditions.  So the 

require 'parslet'
require 'condition_parser/event_condition'
require 'condition_parser/event_attribute'

module ConditionParser
  class ConditionTransform < Parslet::Transform
    rule( :string => simple(:s) ) { String.new( s.str ) }
    rule( :number => simple(:n) ) { n.to_f }
    rule( :symbol => simple(:s) ) { s.to_s[1..-1].to_sym }
    rule( :event => simple(:e) )  { EventAttribute.new( e.to_s ) }
    rule( :state_var => simple(:s) ) { FsmStateVariable.new( s.str[1..-1] ) }

    rule( :comparison => { :left => subtree(:left), :comparator => simple(:comparator), :right => subtree(:right) } ) do
      EventCondition.new( comparator.str.to_sym, left, right )
    end


    ##
    #
    def generate_permutations
      # TODO: code here
    end

  end
end