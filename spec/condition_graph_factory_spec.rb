# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

require 'rspec'

require 'condition_optimisation/condition_graph_factory'
require 'condition_optimisation/condition_graph'
require 'logger'

module ConditionOptimisation
  describe 'evaluate multiple graphs' do
    let(:log) { Logger.new( 'condition_graph_factory.txt' ).tap { |l| l.level = Logger::DEBUG } }

    subject( :condition_graph_factory ) { ConditionGraphFactory.new }

    it 'should correctly optimise' do
      conditions_sets = {}

      (1..10).each do
        |fsm| conditions_sets[ (1..10).to_a.shuffle!.take( rand(2..6) ).sort! ] = "fsm_#{fsm.to_s}".to_sym
      end

      log.debug conditions_sets.inspect

      graph = condition_graph_factory.build( conditions_sets )

      # See what we have done.
      log.debug graph.inspect

      # Now test that for every condition set we get the correct
      conditions_sets.each_pair do |condition_set, transition|
        log.debug "#{condition_set.inspect} => #{transition}"
        expect( graph.execute(condition_set,
                             ->(condition, fsms) { condition_set.member?(self) ? fsms : nil },
                             ->(transition, included_fsms) { [transiton] } ) ).to include( transition )
      end

      # TODO: test the negative: i.e. sets of conditions that are not covered
    end
  end

end