# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

# @note
# Part of the parslet family.  Transforms the condition tree into a linear array of ComparisonNode's and BranchNodes
# Each ComparisonNode will evaluate a condition.  BranchNodes are used to evaluate OR conditions.

require 'parslet'

module ConditionParser
  class Transformer < Parslet::Transform
    rule( :string => simple(:s) ) { String.new( s.str ) }
    rule( :number => simple(:n) ) { n.str.to_f }
    rule( :symbol => simple(:s) ) { s.str[1..-1].to_sym }
    rule( :event => simple(:e) )  { EventAttribute.new( e.to_s ) }
    rule( :state_var => simple(:s) ) { |context| FsmStateVariable.new(context[:fsm_class], context[:s].str[1..-1]) }

    rule( :brackets => subtree(:b) ) { b }
    rule( :comparison => { :left => subtree(:left), :comparator => simple(:comparator), :right => subtree(:right) } ) do
      EventCondition.new( comparator.str.to_sym, left, right )
    end

    # Recurse down the tree, ensuring that each EventCondition object exists only once.  This allows equality of nodes
    # to be tested using object_id rather than comparing individual elements of the EventCondition.
    #
    # @param [ConditionCache] cache
    # @param [Hash,Array,EventCondition] tree
    # @return [Hash,Array,Fixnum]
    def self.cache_conditions( cache, tree )
      if tree.is_a? EventCondition
        ( cache.add(tree) )
      else
        # If its not an EventCondition (leaf node) then it must be a Hash.
        (tree[:or] || tree[:and]).map! { |sub_tree| sub_tree = cache_conditions( cache, sub_tree) }
        tree
      end
    end

    # Used by the methods below which require even individual items to be stored in an array of an array.
    #
    # @param [Object] x
    # @return [Array<Array<Object>>]
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

    # Combines two sets of conditions under AND.
    #
    # @param [EventCondition, Array<EventCondition>] a
    # @param [EventCondition, Array<EventCondition>] b
    # @return [Array<EventCondition>]
    def self.and(a , b)
       result = []
       a_as_array_of_array = make_a_of_a( a )
       b_as_array_of_array = make_a_of_a( b )
       a_as_array_of_array.each { |el_a| b_as_array_of_array.each { |el_b| result.push( el_a + el_b ) } }
       result
    end

    # Combines two sets of conditions under OR.
    #
    # @param [EventCondition, Array<EventCondition>] a
    # @param [EventCondition, Array<EventCondition>] b
    # @return [Array<EventCondition>]
    def self.or(a, b)
      if a.is_a?( Array ) && a.empty?
        make_a_of_a b
      elsif b.is_a?( Array ) && b.empty?
        make_a_of_a a
      else
        make_a_of_a( a ) + make_a_of_a( b )
      end
    end

    # Any boolean expression can ultimately be presented as ( set1 of AND conditions ) OR (set2 of AND conditions ) OR ...
    #
    # This function finds all paths through the tree that provide a set of AND conditions.  Each entry in the array
    # is one such sub-term of AND conditions.  It does this by recursing through all AND paths.
    #
    # @param [Hash,EventCondition] tree
    # @return [Array<Array<EventConditions>>]
    def self.generate_permutations(tree)
      if tree.is_a?(Hash)
        if tree[:and]
          tree[:and].inject( nil ) do |result, subtree|
            result ? self.and( result, generate_permutations(subtree) ) : generate_permutations( subtree )
          end
        else
          # must be :or tree
          tree[:or].inject( [] ) { |result, subtree| self.or( result, generate_permutations(subtree) ) }
        end
      else
        self.make_a_of_a( tree )
      end
    end
  end
end
