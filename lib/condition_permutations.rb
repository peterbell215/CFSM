

require('condition_graph')

##
# We are exploring the permutations of all possible ways that we can combine the different anded
# conditions into a condition execution graph in order to find the most efficient one.  As this
# could potentially be a vary large number of permutations, we try and keep the amount of work
# down.  We construct a directed graph.  Each node in the graph represents a valid condition
# execution graph.  Each edge represents adding an anded condition set to a condition execution
# graph in order to get to a new execution graph.
#
# Lets explain with an example: we have four condition sets A, B, C, and D.  Now A and B share some conditions
# but also have some conditions independent of each other.  This means that whichever way we combine them, we get
# the same graph:
#
#   start 0:
#   0: { A intersection B}[] => 1, 2
#   1: { A minus B }[:fsm_a] => end
#   2: { B minus A }[:fsm_b] => end
#
# Now lets further assume that D is a complete subset of C.  So again the graph is the same which ever sequence
# we combine the graphs in.
#
# The @set_of_graphs will hold a directed graph.  Each graph node holds the condition execution graph, and a hash
# that marks by adding condition set A to this graph, we will arrive at a new graph whose index is y.  So if our
# initianal sequence of generating the graph is [ A, B, C, D ] we would end up with the graph held in the array as
# follows:
#
# 0: graph with A only : { B => 1 }
# 1: graph with A and B: { C => 2 }
# 2: graph with A and B plus C in parallel: { D => 3 }
# 3: graph with (A and B) plus (C and D) in parallel: {}
#
# If we now evaluate graphs in the sequence [ B, A, C, D ] then the graph becomes:
#
# 0: graph with A only : { B => 1 }
# 1: graph with A and B: { C => 2 }
# 2: graph with A and B plus C in parallel: { D => 3 }
# 3: graph with (A and B) plus (C and D) in parallel: {}
# 4: graph with B only : { A => 2 }
#
# From here on in, the permutator just goes through checking that it already has the appropriate
# transitions.  So in order to evaluate [ B, A, C, D ] we only have to do one further costly merge operation.
#
# Now if we look at the combination [ C, A, B, D ], again we actually end up only adding two new graphs to
# our set of graphs: C on its own, and C combined with A. By the time we get to C, A, B we already have an
# equivalent graph.
module ConditionPermutations
  # As per above explanation, *graph* is a ConditionGraph i.e. an executable graph to evaluate a set of
  # conditions. *nxt_conditions* is a hash that for a set of anded conditions gives the index of the graph
  # in the @set_of_graphs array.
  Struct.new('GraphEntry', :graph, :nxt_conditions )

  attr_reader :set_of_graphs

  ##
  # Given a set of anded_conditions and associated transitions, for example:
  #
  # a = [1, 2, 7, 8 ] => :fsm_c
  # b = [1, 2, 3, 4, 5, 6 ] => :fsm_b
  # c = [3, 4, 5, 6 ] => :fsm_a
  #
  # This function will try all permutations of combining the three anded_conditions
  # in order to determine the optimal graph.
  #
  # @return [ConditionGraph]
  # @param [Hash<Set => Symbol, CFSM>] condition_sets
  def permutate_graphs( condition_sets )
    # This is mainly here for testing purposes.  Allows us to not have to explicitely create a set when creating
    # the test data.
    @set_of_graphs = []
    condition_sets.keys.keep_if { |c| c.is_a? Array }.each { |c| condition_sets[ Set.new( c )] = condition_sets.delete( c ) }

    condition_sets.keys.permutation.each { |sequence_of_insertions| apply_one_permutation( condition_sets, sequence_of_insertions ) }
    self
  end

  ##
  # Given a specific sequence in which condition sets are added to the graph, build a graph that represents
  # the test of all the conditions.  This is added to the existing graph of possible ConditionGraphs held in
  # @set_of_graphs.
  #
  # @param [Hash<Set => Symbol,CFSM] condition_sets
  # @param [Array<Set<Conditions>>] seq_of_insertions
  # @return [Array<GraphEntry>]
  def apply_one_permutation( condition_sets, seq_of_insertions )
    previous_graph_index = nil
    seq_of_insertions.each do |conditions|
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

  ##
  # Having calculated a new graph, we now need to see, if we have already arrived at the same graph by another method.
  # If it is a genuinely new graph, we add it to the set.  If not, we return an index to the existing entry.
  #
  # @param [ConditionGraph] graph
  def find_or_add_graph( graph )
    # scan existing set of graphs looking for comparison.
    @set_of_graphs.each_with_index { | graph_entry, index | return index if graph == graph_entry.graph }

    # if we reach here, it is because the graph is new
    @set_of_graphs.push( Struct::GraphEntry.new( graph, {} ) )
    return @set_of_graphs.length-1
  end

  ##
  # Having determined all possible ConditionGraphs this method will check which one is optimal, This method first removes
  # the intermediate graphs we generated to only leave complete graphs as defined by an empty nxt_conditions hash.
  # It then counts the number of conditions to be tested in each graph.  It returns the graph with the smallest number
  # of conditions to test.
  #
  # @return [ConditionGraph]
  def find_optimal
    @set_of_graphs.keep_if { |g| g.nxt_conditions.empty? }
    @set_of_graphs.min { |a, b| a.graph.count_complexity <=> b.graph.count_complexity }.graph
  end
end
