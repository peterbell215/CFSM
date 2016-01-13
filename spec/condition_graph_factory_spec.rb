# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.

require 'rspec'

require 'CFSM'
require 'cfsm_event'

module ConditionOptimisation
  describe 'evaluate multiple graphs' do
    subject( :condition_graph_factory ) { ConditionGraphFactory.new }

    before(:each) do
      # We monkey patch these two classes to allow us to test with a simplified representation.
      class ::Fixnum
        def evaluate( condition_set, fsms )
          condition_set.member?( self ) ? fsms : nil
        end
      end
      class ::Symbol
        def instantiate( fsms )
          return [ self ]
        end
      end
    end

    it 'should correctly optimise' do
      conditions_sets = {}

      (1..10).each do
        |fsm| conditions_sets[ (1..10).to_a.shuffle!.take( rand(2..6) ).sort! ] = "fsm_#{fsm.to_s}".to_sym
      end

      CFSM.logger.debug conditions_sets.inspect

      graph = condition_graph_factory.build( conditions_sets )

      # Now test that for every condition set we get the correct
      conditions_sets.each_pair do |condition_set, transition|
        expect( graph.execute(condition_set) ).to include( transition )
      end

      # TODO: test the negative: i.e. sets of conditions that are not covered
    end
  end

end