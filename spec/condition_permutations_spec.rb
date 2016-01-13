# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.
require 'rspec'

require 'CFSM'

module ConditionOptimisation
  describe ConditionPermutations do
    subject( :condition_permutator ) { ConditionGraphFactory.new }
    let!( :set_a ){ Set.new( [1, 2, 7, 8]) }
    let!( :set_b ){ Set.new( [1, 2, 3, 4, 5, 6] ) }
    let!( :set_c ){ Set.new( [3, 4, 5, 6] ) }
    let!( :conditions ) { { set_a => :fsm_a, set_b => :fsm_b, set_c => :fsm_c } }

    describe '#apply_one_permutation' do
      it 'add a single ' do
        condition_permutator.apply_one_permutation( conditions, conditions.keys)

        expect(condition_permutator.set_of_graphs[0].graph.inspect).to eq(
          "start: 0\n"\
          "0: {1, 2, 7, 8} [fsm_a] -> end\n")
        expect(condition_permutator.set_of_graphs[0].nxt_conditions[ Set.new([1, 2, 3, 4, 5, 6])]).to eq(1)

        expect(condition_permutator.set_of_graphs[1].graph.inspect).to eq(
          "start: 0\n"\
          "0: {1, 2} [] -> 1, 2\n"\
          "1: {7, 8} [fsm_a] -> end\n"\
          "2: {3, 4, 5, 6} [fsm_b] -> end\n")
        expect(condition_permutator.set_of_graphs[1].nxt_conditions[Set.new([3, 4, 5, 6])]).to eq(2)

        expect(condition_permutator.set_of_graphs[2].graph.inspect).to eq(
          "start: 0, 3\n"\
          "0: {1, 2} [] -> 1, 2\n"\
          "1: {7, 8} [fsm_a] -> end\n"\
          "2: {3, 4, 5, 6} [fsm_b] -> end\n"\
          "3: {3, 4, 5, 6} [fsm_c] -> end\n")
        expect(condition_permutator.set_of_graphs[2].nxt_conditions).to be_empty
      end

      it 'should not recalculate if the solution already exists.' do
        # TODO
        true
      end
    end

    describe '#permutate_graphs' do
      it 'should permutate over all possibilities' do
        condition_permutator.permutate_graphs( conditions )
        # TODO: check returns.
        condition_permutator.set_of_graphs.inspect
      end
    end

    describe '#find_optimal' do
      it 'should find the graph with the least number of conditions' do
        # 10 conditions is the best we can do.
        expect( condition_permutator.permutate_graphs( conditions ).find_optimal.inspect ).to eq(
          "start: 0, 2\n"\
          "0: {3, 4, 5, 6} [fsm_c] -> 1\n"\
          "1: {1, 2} [fsm_b] -> end\n"\
          "2: {1, 2, 7, 8} [fsm_a] -> end\n" )
      end
    end
  end
end