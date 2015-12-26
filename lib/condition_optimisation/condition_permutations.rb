# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.

# TODO do we really need set here?
require 'set'

module ConditionOptimisation
  # This module forms part of the optimisation process.  It provides the methods used to try different
  # permutations of condition sets to generate the optimal RETE graph.
  #
  # @see https://github.com/peterbell215/CFSM/wiki/Permutator Description of algorithm in project Wiki.
  module ConditionPermutations
    # An array of GraphEntry items is used to hold a graph representing the use of permutations to define an
    # optimal RETE graph.
    class GraphEntry < Struct.new(:graph, :nxt_conditions )
      # @!attribute graph
      #   @return [ConditionGraph] the RETE condition graph that this entry represents.
      # @!attribute nxt_conditions
      #   @return [Hash<ConditionSet, Integer>]
      #     a hash that for a set of anded conditions gives the index of the graph in the `set_of_graphs` array.
    end

    # @return [Array<GraphEntry>] the directed graph of graph entries.
    attr_reader :set_of_graphs

    # Given a set of anded_conditions and associated transitions, for example:
    #
    #    [A, B, C, D ] => :fsm_c
    #    [1, 2, 3, 4, 5, 6 ] => :fsm_b
    #    [3, 4, 5, 6 ] => :fsm_a
    #
    # This function will try a reasonable number of permutations to combine the sets.  If we have less than 6 members
    # in the set, we try all permutations.
    #
    # @param [Hash<Set<ConditionSet>. Symbol>] condition_sets
    # @return [ConditionGraph]
    def permutate_graphs( condition_sets )
      @set_of_graphs = []

      # This is mainly here for testing purposes.  Allows us to not have to explicitly create a set when creating
      # the test data.
      condition_sets.keys.keep_if { |c| c.is_a? Array }.each { |c| condition_sets[::Set.new( c )] = condition_sets.delete( c ) }

      if condition_sets.size > 6
        (1..40).each do
           apply_one_permutation( condition_sets, condition_sets.keys.shuffle )
        end
      else
        condition_sets.keys.permutation.each { |sequence_of_insertions| apply_one_permutation( condition_sets, sequence_of_insertions ) }
      end

      self
    end

    # Given a specific sequence in which condition sets are added to the graph, build a graph that represents
    # the test of all the conditions.  This is added to the existing graph of possible ConditionGraphs held in
    # set_of_graphs.
    #
    # @param [Hash<Set<ConditionParser::EventCondition> => CfsmClasses::Transition>] condition_sets
    # @param [Array<ConditionParser::EventCondition>] seq_of_insertions
    # @return [Array<GraphEntry>]
    def apply_one_permutation( condition_sets, seq_of_insertions )
      previous_graph_index = nil
      seq_of_insertions.each do |conditions|
        # noinspection RubyResolve
        if previous_graph_index.nil?
          # First element in the permutation of conditions.  So we check if the graph already
          # exists.  If it does we set the previous graph to that instance.  If it does not
          # we create a new graph.
          previous_graph_index = find_or_add_graph( ConditionGraph.new.add_conditions( conditions, condition_sets[conditions] ) )
        elsif @set_of_graphs[previous_graph_index].nxt_conditions.key?( conditions )
          # The previous graph already has a valid transition from the previous graph
          # with the new condition.  Therefore, we simply follow that transition.
          previous_graph_index = @set_of_graphs[previous_graph_index].nxt_conditions[conditions]
        else
          # We don't have a valid transition yet from the previous graph with adding this condition.
          # Therefore, we clone the previous graph, and add the new set of conditions.
          new_graph = @set_of_graphs[ previous_graph_index ].graph.clone.add_conditions conditions, condition_sets[conditions]
          # Now we check if this new graph already exists. If not we add it.
          new_graph_index = find_or_add_graph( new_graph )
          @set_of_graphs[previous_graph_index].nxt_conditions[conditions] = new_graph_index
          previous_graph_index = new_graph_index
        end
      end
      @set_of_graphs
    end

    # Having calculated a new graph, we now need to see, if we have already arrived at the same graph by another method.
    # If it is a genuinely new graph, we add it to the set.  If not, we return an index to the existing entry.
    #
    # @param [ConditionGraph] graph
    def find_or_add_graph( graph )
      # scan existing set of graphs looking for comparison.
      @set_of_graphs.each_with_index { | graph_entry, index | return index if graph == graph_entry.graph }

      # if we reach here, it is because the graph is new
      # noinspection RubyResolve
      @set_of_graphs.push( Struct::GraphEntry.new( graph, {} ) )
      @set_of_graphs.length-1
    end

    # Having determined all possible ConditionGraphs this method will check which one is optimal, This method first removes
    # the intermediate graphs we generated to only leave complete graphs as defined by an empty nxt_conditions hash.
    # It then counts the number of conditions to be tested in each graph.  It returns the graph with the smallest number
    # of conditions to test.
    #
    # @return [ConditionGraph]
    def find_optimal
      # @type [ConditionGraph] g
      @set_of_graphs.keep_if { |g| g.nxt_conditions.empty? }
      @set_of_graphs.min { |a, b| a.graph.count_complexity <=> b.graph.count_complexity }.graph
    end
  end
end