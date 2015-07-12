# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'set'
require 'condition_graph'
require 'byebug'

describe ConditionGraph do
  before(:each) do
    @graph = ConditionGraph.new
  end

  describe "#===" do
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
      expect( @graphs[0] === @graphs[1] ).to be_truthy
    end
    
    it "should match two graphs that are identical, but with nodes in different sequence" do
      expect( @graphs[0] === @graphs[1].shuffle ).to be_truthy
    end
    it "should not match two similar graphs" do
      @graphs[1][3].conditions.delete(14)
      
      expect( @graphs[0] === @graphs[1] ).to be_falsey
    end
  end
  
  describe "#optimize_graph" do
    it "should accept a single condition chain" do
      @graph.add_conditions([1, 2, 3, 4], [:fsm1] )
      
      expect( @graph[ 0 ].start_node ).to be true 
      expect( @graph[ 0 ].conditions ).to match_array( [1, 2, 3, 4] )
      expect( @graph[ 0 ].transitions ).to match_array( [:fsm1] )
    end
    
    it "should create two separate condition chains if they don't share any conditions" do
      
    end
    
  end  
end

