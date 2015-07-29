# @author Peter Bell

require 'condition_optimisation/conditions_node'

module ConditionOptimisation
  describe ConditionsNode do
    before(:each) do
      @conditions_node = Array.new(2) { ConditionsNode.new( [1, 2, 3, 4], [:fsm1], [1, 2], false ) }
    end

    describe '#=' do
      it 'should convert an array of conditions into a set of conditions' do
        conditions_node = ConditionsNode.new [], []
        conditions_node.conditions = [1, 2, 3, 4]

        expect( conditions_node.conditions ).to be_a( Set )
      end
    end

    describe '#similar' do
      it 'match two similar condition nodes' do
        expect( @conditions_node[ 0 ].similar( @conditions_node[ 1 ]))
      end

      it 'does not match nodes where the condition sets differ' do
        @conditions_node[1].conditions = [1, 2, 3 ]
        expect( @conditions_node[ 0 ].similar( @conditions_node[ 1 ] ) ).to be false
      end

      it 'does not match nodes where the transition sets differ' do
        @conditions_node[1].transitions = [ 1 ]
        expect( @conditions_node[ 0 ].similar( @conditions_node[ 1 ] ) ).to be false
      end

      it 'does not match nodes where the start condition differs' do
        @conditions_node[1].start_node = true
        expect( @conditions_node[ 0 ].similar( @conditions_node[ 1 ] ) ).to be false
      end
    end
  end
end
