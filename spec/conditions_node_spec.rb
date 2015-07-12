# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'conditions_node'

describe ConditionsNode do
  before(:each) do
    @conditions_node = Array.new(2) { ConditionsNode.new( [1, 2, 3, 4], [:fsm1], [1, 2], false ) }
  end

  describe "#similar" do
    it "match two similar condition nodes" do
      expect( @conditions_node[ 0 ].similar( @conditions_node[ 1 ]))
    end
    
    it "does not match nodes where the condition sets differ" do
      @conditions_node[1].conditions = [1, 2, 3 ]
      expect( @conditions_node[ 0 ].similar( @conditions_node[ 1 ] ) ).to be false
    end

    it "does not match nodes where the transition sets differ" do
      @conditions_node[1].transitions = [ 1 ]
      expect( @conditions_node[ 0 ].similar( @conditions_node[ 1 ] ) ).to be false
    end

    it "does not match nodes where the start condition differs" do
      @conditions_node[1].start_node = true
      expect( @conditions_node[ 0 ].similar( @conditions_node[ 1 ] ) ).to be false
    end    
  end
end

