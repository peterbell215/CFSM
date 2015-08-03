# Part of the parslet family.  Transforms the condition tree into a linear array of ComparisonNode's and BranchNodes
# Each ComparisonNode will evaluate a condition.  BranchNodes are used to evaluate OR conditions.  So the 

require 'parslet'
require 'condition_parser/event_condition'
require 'condition_parser/event_attribute'

module ConditionParser
  class Transformer < Parslet::Transform
    rule( :string => simple(:s) ) { String.new( s.str ) }
    rule( :number => simple(:n) ) { n.str.to_f }
    rule( :symbol => simple(:s) ) { s.str[1..-1].to_sym }
    rule( :event => simple(:e) )  { EventAttribute.new( e.to_s ) }
    rule( :state_var => simple(:s) ) { |context| FsmStateVariable.new(context[:cfsm_class], context[:s].str[1..-1]) }

    rule( :brackets => subtree(:b) ) { b }
    rule( :comparison => { :left => subtree(:left), :comparator => simple(:comparator), :right => subtree(:right) } ) do
      EventCondition.new( comparator.str.to_sym, left, right )
    end

    #
    # @param [EventCondition, Array<EventCondition>] a
    # @param [EventCondition, Array<EventCondition>] b
    # @return [Array<EventCondition>]
    def self.and(a , b)
      if a.is_a?( Array ) && a.empty?
        b.is_a?( Array ) ? b : [b]
      else
        (a.is_a?( Array ) ? a : [a] ).concat( b.is_a?( Array ) ? b : [b] )
      end
    end

    def self.make_a_of_a( x )
      if x.is_a? Array
        if x[0].is_a? Array
          return x
        else
          return [ x ]
        end
      else
        return [ [ x ] ]
      end
    end

    # @param [EventCondition, Array<EventCondition>] a
    # @param [EventCondition, Array<EventCondition>] b
    # @return [Array<EventCondition>]
    def self.or(a, b)
      result = []
      make_a_of_a( a ).each { |el_a| make_a_of_a( b ).each { |el_b| result.push( el_a + el_b ) } }
      result
    end
    ##
    #
    # @param [Hash,EventCondition] tree
    # @return [Array<Array<EventConditions>>]
    def self.generate_permutations(tree)
      if tree.is_a?(Hash)
        if (and_conditions = tree[:and])
          and_conditions.inject( nil ) do |result, subtree|
            if result
              self.and( result, subtree.is_a?( Hash ) ? generate_permutations(subtree) : subtree )
            else
              generate_permutations( subtree )
            end
          end
        else
          # must be :or tree
          tree[:or].inject( [] ) { |result, subtree| result.or( generate_permutations(subtree) ) }
        end
      end
    end
  end
end
