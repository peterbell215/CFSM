# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

require 'condition_optimisation/condition_graph'
require 'condition_optimisation/condition_permutations'

module ConditionOptimisation
  ##
  # Factory class that performs necessary steps to create a ConditionGraph
  class ConditionGraphFactory
    include ConditionPermutations

    def initialize
      @set_of_graphs = []
    end

    ##
    # This is the wrapper for building the optimal graph.
    #
    # @param [Hash] condition_sets
    # @return [ConditionGraph]
    def build( condition_sets )
      @set_of_graphs.clear

      # Do the heavy lifting
      optimal_graph = self.permutate_graphs( condition_sets ).find_optimal

      # Recover the memory associated with creating the optimal graph
      @set_of_graphs.clear

      optimal_graph
    end

    ##
    # ConditionGraphPermutations expects a condition_set to be a hash mapping a Set of conditions
    # onto a transition.  In order to make things more readable in the Rspecs, we allow the set
    # to be defined as an array.  This little helper function goes through and changes any Arrays
    # to Sets.
    #
    # @param [Hash] condition_sets
    # @return [Hash]
    def self.condition_sets_from_array( condition_sets )
      condition_sets.keys.keep_if { |c| c.is_a? Array }.each { |c| sets[ Set.new( c )] = sets.delete( c ) }
    end
  end
end