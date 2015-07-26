# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

#TODO replace class instance variable with Rspec let statement.
#TODO tidy up this spec by moving to let {} and subject {}

require 'set'
require 'condition_graph'
require 'byebug'

describe ConditionGraph do
  describe "graph to/and from strings" do
    subject(:graph) do
      ConditionGraph.new(
          [
              ConditionsNode.new([1, 2], [], [1, 2], true), # 0
              ConditionsNode.new([7, 8], [:fsm_c, :fsm_b], [], false), # 1
              ConditionsNode.new([3, 4, 5, 6], [:fsm_a], [], false), # 2
          ])
    end

    let(:graph_as_string) do
      "start: 0\n"\
        "0: {1, 2} [] -> 1, 2\n"\
        "1: {7, 8} [fsm_c, fsm_b] -> end\n"\
        "2: {3, 4, 5, 6} [fsm_a] -> end\n"
    end

    it "should produce nice output" do
      expect( graph.inspect ).to eq( graph_as_string )
    end

    it "should generate a graph from a valid string" do
      new_graph = ConditionGraph.from_string graph_as_string

      expect( new_graph ).to eq( graph )
    end
  end

  describe "#clone" do
    it "should make a deep copy including of the sets." do
      graph = ConditionGraph.new ( [
                                   ConditionsNode.new( [1, 2], [], [1, 2], true ),           # 0
                                   ConditionsNode.new( [7, 8], [:fsm_c], [], false ),        # 1
                                   ConditionsNode.new( [3, 4, 5, 6], [:fsm_a], [], false ),  # 2
                               ] )

      copy = graph.clone

      expect( graph.length ).to eq( copy.length )
      (0..graph.length-1).each do |index|
        expect( graph[index].conditions ).to match( copy[index].conditions )
        expect( graph[index].conditions ).not_to be( copy[index].conditions )
        expect( graph[index].transitions ).to match( copy[index].transitions )
        expect( graph[index].transitions ).not_to be( copy[index].transitions.object_id )
        expect( graph[index].edges ).to match( copy[index].edges )
        expect( graph[index].edges ).not_to be( copy[index].edges )
        expect( graph[index].start_node ).to eq( copy[index].start_node )
      end
    end
  end

  describe "#==" do
    before(:each) do
      # Create the same graph twice/
      @graphs = Array.new(2) do
        ConditionGraph.new ( [
          ConditionsNode.new( [1, 2, 3, 4], [:fsm_a], [5, 7], true ),     # 0
          ConditionsNode.new( [4, 5, 6, 7], [:fsm_b], [3], true ),        # 1
          ConditionsNode.new( [8, 9, 10, 11], [:fsm_c], [3], true ),      # 2
          ConditionsNode.new( [13, 14, 15], [:fsm_e], [4], false ),       # 3
          ConditionsNode.new( [16], [:fsm_f], [], false ),                # 4
          ConditionsNode.new( [17, 18, 19], [:fsm_g], [6], false ),       # 5
          ConditionsNode.new( [20], [:fsm_h], [], false ),                # 6
          ConditionsNode.new( [21, 22, 23], [:fsm_i], [], false )         # 7
        ] )
      end      
    end
    
    it "should match two identical graphs" do
      expect( @graphs[0] ).to eq( @graphs[1] )
    end
    
    it "should match two graphs that are identical, but with nodes in different sequence" do
      expect( @graphs[0] ).to eq( @graphs[0].shuffle )
    end
    
    it "should not match two similar graphs" do
      @graphs[1][3].conditions.delete(14)
      
      expect( @graphs[0] ).to_not eq( @graphs[1] )
    end
  end
  
  describe '#add_conditions' do
    subject( :graph ) { ConditionGraph.new }
  
    it "should accept a single condition chain" do
      graph.add_conditions( [1, 2, 3, 4], :fsm1 )
      
      expect( graph[ 0 ].start_node ).to be true
      expect( graph[ 0 ].conditions.to_a ).to contain_exactly 1, 2, 3, 4
      expect( graph[ 0 ].transitions.to_a ).to contain_exactly :fsm1
    end

    it "should create two condition chains in sequence if the 2nd is full subset of the 1st" do
      #TODO: Replace the manually crafted condition graph with one built forom a string.
      graph.add_conditions(Set.new( [1, 2, 3, 4 ] ), :fsm_a )
      graph.add_conditions(Set.new( [1, 2, 3, 4, 5, 6] ), :fsm_b )
        
      @expected = ConditionGraph.new ( [
          ConditionsNode.new( [1, 2, 3, 4], [:fsm_a], [1], true ),  # 0
          ConditionsNode.new( [5, 6], [:fsm_b], [], false ),        # 1
      ] )
      
      expect( graph ).to eq( @expected )
    end
    
    it "should create two condition chains in sequence if the 1st is full subset of the 2nd" do
      graph.add_conditions( [1, 2, 3, 4, 5, 6], :fsm_b )
      graph.add_conditions( [1, 2, 3, 4 ], :fsm_a )
  
      @expected = ConditionGraph.new ( [
          ConditionsNode.new( [1, 2, 3, 4], [:fsm_a], [1], true ),  # 0
          ConditionsNode.new( [5, 6], [:fsm_b], [], false ),        # 1
      ] )
      
      expect( graph ).to eq( @expected )
    end
    
    it "should create two separate condition chains if they don't share any conditions" do
      graph.add_conditions( [1, 2, 7, 8], :fsm_c )
      graph.add_conditions( [1, 2, 3, 4, 5, 6], :fsm_a )
        
      @expected = ConditionGraph.new ( [
          ConditionsNode.new( [1, 2], [], [1, 2], true ),           # 0
          ConditionsNode.new( [7, 8], [:fsm_c], [], false ),        # 1
          ConditionsNode.new( [3, 4, 5, 6], [:fsm_a], [], false ),  # 2
      ] )
      
      expect( graph ).to eq( @expected )
    end

    it "should create merge three chains correctly" do
      @condition_sets = {
          Set.new( [1, 2, 7, 8] ) => :fsm_c,
          Set.new( [1, 2, 3, 4, 5, 6] ) => :fsm_b,
          Set.new( [3, 4, 5, 6] ) => :fsm_a
      }

      @condition_sets.each_pair { |conds, state| graph.add_conditions( conds, state ) }

      expect( graph.inspect ).to eq(
        "start: 0, 3\n"\
        "0: {1, 2} [] -> 1, 2\n"\
        "1: {7, 8} [fsm_c] -> end\n"\
        "2: {3, 4, 5, 6} [fsm_b] -> end\n"\
        "3: {3, 4, 5, 6} [fsm_a] -> end\n" )
    end
  end

  context 'dealing with condition sets' do
    let!( :set_a ){ Set.new( [1, 2, 7, 8]) }
    let!( :set_b ){ Set.new( [1, 2, 3, 4, 5, 6] ) }
    let!( :set_c ){ Set.new( [3, 4, 5, 6] ) }
    let!( :condition_sets ) { { set_a => :fsm_a, set_b => :fsm_b, set_c => :fsm_c } }

    subject( :graph ) { ConditionGraph.new.add_condition_sets condition_sets }
    subject( :simple_graph ) { ConditionGraph.new.add_conditions( set_a, :fsm_a ) }

    describe '#execute' do
      it 'should yield to evaluate a set of conditions' do
        conditions_not_tested_yet = set_a.clone

        simple_graph.execute do |c|
          expect( conditions_not_tested_yet.delete? c ).to be_truthy
          true
        end

        expect( conditions_not_tested_yet ).to be_empty
      end

      it 'should return return the correct transition' do
        expect( simple_graph.execute { |c| true } ).to contain_exactly :fsm_a
      end

      it 'should only return :fsm_a if conditons 3 to 6 are false ' do
        expect( graph.execute { |c| set_a.member? c } ).to contain_exactly( :fsm_a )
      end

      it 'should only return :fsm_b and :fsm_c for conditons 1 to 6' do
        expect( graph.execute { |c| set_b.member? c } ).to contain_exactly( :fsm_b, :fsm_c )
      end
    end

    describe '#count_complexity' do
      it 'should return nil if the graph is empty' do
        expect( ConditionGraph.new.count_complexity ).to eq(0)
      end

      it 'should return the number of conditions correctly' do
        expect( graph.count_complexity ).to eq(12)
      end
    end
  end
end

