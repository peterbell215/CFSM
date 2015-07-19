require 'rspec'
require 'condition_permutations'

describe ConditionPermutations do
  before(:each) do
    @condition_permutator = ConditionPermutations.new

    @condition_sets = {
        [1, 2, 7, 8] => :fsm_c,
        [1, 2, 3, 4, 5, 6] => :fsm_b,
        [3, 4, 5, 6] => :fsm_a
    }
    @condition_sets.keys.keep_if { |c| c.is_a? Array }.each { |c| @condition_sets[ Set.new( c )] = @condition_sets.delete( c ) }
  end

  describe '#apply_one_permutation' do
    it 'add a single ' do
      @condition_permutator.apply_one_permutation( @condition_sets, @condition_sets.keys)

      expect(@condition_permutator.set_of_graphs()[0].graph.inspect).to eq(
        "start: 0\n"\
        "0: {1, 2, 7, 8} [fsm_c] -> end\n")
      expect(@condition_permutator.set_of_graphs()[0].nxt_conditions[ Set.new([1, 2, 3, 4, 5, 6])]).to eq(1)

      expect(@condition_permutator.set_of_graphs()[1].graph.inspect).to eq(
        "start: 0\n"\
        "0: {1, 2} [] -> 1, 2\n"\
        "1: {7, 8} [fsm_c] -> end\n"\
        "2: {3, 4, 5, 6} [fsm_b] -> end\n")
      expect(@condition_permutator.set_of_graphs()[1].nxt_conditions[Set.new([3, 4, 5, 6])]).to eq(2)

      expect(@condition_permutator.set_of_graphs()[2].graph.inspect).to eq(
        "start: 0, 3\n"\
        "0: {1, 2} [] -> 1, 2\n"\
        "1: {7, 8} [fsm_c] -> end\n"\
        "2: {3, 4, 5, 6} [fsm_b] -> end\n"\
        "3: {3, 4, 5, 6} [fsm_a] -> end\n")
      expect(@condition_permutator.set_of_graphs()[2].nxt_conditions).to be_empty
    end

    it 'should not recalculate if the solution already exists.' do
      # TODO
      true
    end
  end

  describe "#permutate_graphs" do
    it "should permutate over all possiblities" do
      @condition_permutator.permutate_graphs( @condition_sets )
      @condition_permutator.set_of_graphs.inspect
    end
  end
end