# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.
require 'CFSM'

module ConditionOptimisation
  describe ConditionsSet do
    describe '#clone' do

    end

    describe '#similar' do
      before(:each) do
        @conditions_node =
            [ ConditionsNode.new( [1, 2, 3, 4], [:fsm1] ),
              ConditionsNode.new( [1, 2, 3, 4], [:fsm1] ),
              ConditionsNode.new( [1, 2, 3], [:fsm1] ),
              ConditionsNode.new( [1, 2, 3, 4], [:fsm2] ) ]
      end

      it 'match two similar condition nodes' do
        expect( @conditions_node[ 0 ].similar( @conditions_node[ 1 ]))
      end

      it 'does not match nodes where the condition sets differ' do
        expect( @conditions_node[ 0 ].similar( @conditions_node[ 2 ] ) ).to be false
      end

      it 'does not match nodes where the transition sets differ' do
        expect( @conditions_node[ 0 ].similar( @conditions_node[ 3 ] ) ).to be false
      end
    end

    describe '#inspect' do

    end

    describe '#conditions' do

    end
  end
end
