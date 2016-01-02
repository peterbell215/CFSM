# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.
require 'cfsm'

module ConditionOptimisation
  describe ConditionsNode do
    before(:each) do
      @conditions_node =
          [ ConditionsNode.new( [1, 2, 3, 4], [:fsm1], [1, 2] ),
            ConditionsNode.new( [1, 2, 3, 4], [:fsm1], [1, 2] ),
            ConditionsNode.new( [1, 2, 3, 4], [:fsm1], [1] ) ]
    end

    describe '#=' do
      it 'should convert an array of conditions into a set of conditions' do
        conditions_node = ConditionsNode.new [], []
        conditions_node.conditions = [1, 2, 3, 4]

        expect( conditions_node.conditions ).to be_a( Set )
      end
    end

    describe '#similar' do
      it 'should find two nodes similar if they agree in every aspect' do
        expect( @conditions_node[ 0 ].similar( @conditions_node[ 1 ])).to be_truthy
      end

      it 'should find two nodes  not similar if they differ in the number of edges' do
        expect( @conditions_node[ 0 ].similar( @conditions_node[ 2 ])).to be_falsey
      end
    end

  end
end
