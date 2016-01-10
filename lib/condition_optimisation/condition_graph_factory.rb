# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.

module ConditionOptimisation
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
  end
end