# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

require 'cfsm'
require 'set'
require 'condition_optimisation/condition_graph'
require 'logger'

module ConditionOptimisation
  describe ConditionGraph do
    let(:log) { Logger.new( 'condition_graph.txt' ).tap { |l| l.level = Logger::DEBUG } }

    describe 'graph to/and from strings' do
      subject(:graph) do
        ConditionGraph.new([
                               ConditionOptimisation::ConditionsNode.new([1, 2], [], [1, 2]), # 0
                               ConditionOptimisation::ConditionsNode.new([7, 8], [:fsm_c, :fsm_b], []), # 1
                               ConditionOptimisation::ConditionsNode.new([3, 4, 5, 6], [:fsm_a], [] ) ], # 2
                           [0] )
      end

      let(:graph_as_string_with_newline) do
        "start: 0\n"\
          "0: {1, 2} [] -> 1, 2\n"\
          "1: {7, 8} [fsm_c, fsm_b] -> end\n"\
          "2: {3, 4, 5, 6} [fsm_a] -> end\n"
      end
      let(:graph_as_string_with_semicolon) { graph_as_string_with_newline.tr("\n", ';') }

      it 'should produce nice output' do
        expect( graph.inspect ).to eq( graph_as_string_with_newline )
      end

      it 'should generate a graph from a valid string using newlines as separators' do
        new_graph = ConditionGraph::from_string graph_as_string_with_newline

        expect( new_graph ).to eq( graph )
      end

      it 'should generate a graph from a valid string using semicolons as separators' do
        new_graph = ConditionGraph::from_string graph_as_string_with_semicolon

        expect( new_graph ).to eq( graph )
      end
    end

    describe '#clone' do
      it 'should make a deep copy including of the sets.' do
        graph = ConditionGraph.new( [
                                     ConditionsNode.new( [1, 2], [], [1, 2] ),         # 0
                                     ConditionsNode.new( [7, 8], [:fsm_c], [] ),       # 1
                                     ConditionsNode.new( [3, 4, 5, 6], [:fsm_a], [] )  # 2
                                 ], [0] )

        copy = graph.clone

        expect( graph.length ).to eq( copy.length )
        expect( graph.start_array ).to match_array( copy.start_array )

        (0..graph.length-1).each do |index|
          expect( graph[index].conditions ).to match( copy[index].conditions )
          expect( graph[index].conditions ).not_to be( copy[index].conditions )
          expect( graph[index].transitions ).to match( copy[index].transitions )
          expect( graph[index].transitions ).not_to be( copy[index].transitions.object_id )
          expect( graph[index].edges ).to match( copy[index].edges )
          expect( graph[index].edges ).not_to be( copy[index].edges )
        end
      end
    end

    describe '#==' do
      before(:each) do
        # Create the same graph twice/
        @graphs = Array.new(2) do
          ConditionGraph.new([
                                 ConditionsNode.new([1, 2, 3, 4], [:fsm_a], [5, 7]), # 0
                                 ConditionsNode.new([4, 5, 6, 7], [:fsm_b], [3]), # 1
                                 ConditionsNode.new([8, 9, 10, 11], [:fsm_c], [3]), # 2
                                 ConditionsNode.new([13, 14, 15], [:fsm_e], [4]), # 3
                                 ConditionsNode.new([16], [:fsm_f], []), # 4
                                 ConditionsNode.new([17, 18, 19], [:fsm_g], [6]), # 5
                                 ConditionsNode.new([20], [:fsm_h], []), # 6
                                 ConditionsNode.new([21, 22, 23], [:fsm_i], []) # 7
                             ], [0, 1, 2])
        end
      end

      it 'should match two identical graphs' do
        expect( @graphs[0] ).to eq( @graphs[1] )
      end

      it 'should match two graphs that are identical, but with nodes in different sequence' do
        expect( @graphs[0] ).to eq( @graphs[0].shuffle )
      end

      it 'should not match two similar graphs' do
        @graphs[1][3].conditions.delete(14)

        expect( @graphs[0] ).to_not eq( @graphs[1] )
      end
    end

    describe '#add_conditions' do
      it 'should accept a single condition chain' do
        graph = ConditionGraph.new.add_conditions( [1, 2, 3, 4], :fsm1 )

        expect( graph[ 0 ].conditions.to_a ).to contain_exactly 1, 2, 3, 4
        expect( graph[ 0 ].transitions.to_a ).to contain_exactly :fsm1
      end

      it 'should create two condition chains in sequence if the 2nd is full subset of the 1st' do
        graph = ConditionGraph::from_string 'start: 0;0: {1, 2} [fsm_1] -> 1;1: {3, 4} [fsm_2] -> end;'

        expect( graph.add_conditions( [1, 2, 5, 6 ], :fsm_3 ) ).to eq(
          ConditionGraph::from_string 'start: 0;0: {1, 2} [fsm_1] -> 1, 2;1: {3, 4} [fsm_2] -> end;2: {5, 6} [fsm_3] -> end;' )
      end

      it 'should create two condition chains in sequence if the 1st is full subset of the 2nd' do
        graph = ConditionGraph::from_string 'start: 0;0: {1, 2, 3, 4} [fsm_1] -> 1;1: {5, 6} [fsm_2] -> end;'

        expect( graph.add_conditions( [1, 2], :fsm_3 ) ).to eq( ConditionGraph::from_string(
          'start: 0;0: {1, 2} [fsm_3] -> 1;1: {3, 4} [fsm_1] -> 2;2: {5, 6} [fsm_2] -> end;' ) )
      end

      it 'should split an existing condition if it they share some conditions' do
        graph = ConditionGraph::from_string "start: 0\n0: {1, 2, 3} [] -> 1, 2\n1: {4} [fsm_1] -> end\n2: {5} [fsm_2] -> end\n"

        expect( graph.add_conditions( [2, 6], :fsm_3 ) ).to eq(ConditionGraph::from_string(
               'start: 0;0: {2} [] -> 3, 4;1: {4} [fsm_1] -> end;2: {5} [fsm_2] -> end;3: {1, 3} [] -> 1, 2;4: {6} [fsm_3] -> end;'))
      end

      it "should create two separate condition chains if they don't share any conditions" do
        graph = ConditionGraph::from_string "start: 0\n0: {1, 2} [fsm_1] -> 1\n1: {3, 4} [fsm_2] -> end\n"

        expect( graph.add_conditions( [5, 6], :fsm_3 ) ).to eq(
          ConditionGraph::from_string "start: 0, 2\n0: {1, 2} [fsm_1] -> 1\n1: {3, 4} [fsm_2] -> end\n2: {5, 6} [fsm_3] -> end\n" )
      end

      it 'should create merge three chains correctly' do
        graph = ConditionGraph.new

        condition_sets = {
            Set.new( [1, 2, 7, 8] ) => :fsm_c,
            Set.new( [1, 2, 3, 4, 5, 6] ) => :fsm_b,
            Set.new( [3, 4, 5, 6] ) => :fsm_a
        }

        condition_sets.each_pair { |conds, state| graph.add_conditions( conds, state ) }

        expect( graph ).to eq(
          ConditionGraph::from_string 'start: 0, 3;0: {1, 2} [] -> 1, 2;1: {7, 8} [fsm_c] -> end;2: {3, 4, 5, 6} [fsm_b] -> end;'\
          '3: {3, 4, 5, 6} [fsm_a] -> end;' )
      end
    end

    context 'dealing with condition sets' do
      # We use a simplified representation for testing: conditions are represented as Fixnums
      # and transitions as symbols.  In other to ensure that EventProcessor still works correctly
      # we have to monkey patch both classes to behave similar enough to ConditionNode and Transition.
      class ::Fixnum
        include RSpec::Matchers

        # We use a slight of hand here.  The correct evaluate is passed the event for evaluation.
        # Instead, we pass the set of conditions that have not yet been evaluated in the event field.
        # This way we can keep track of what conditons have been evaluated without needing to interfere
        # in any way with EventProcessor::execute.  A rather extreme example of duck typing.
        def evaluate( fsms, conditions_not_tested_yet )
          expect( conditions_not_tested_yet.delete? self ).to be_truthy
          fsms
        end
      end

      class ::Symbol
        def instantiate( included_fsms )
          [ self ]
        end
      end

      let!( :set_a ){ Set.new( [1, 2, 7, 8]) }
      let!( :set_b ){ Set.new( [1, 2, 3, 4, 5, 6] ) }
      let!( :set_c ){ Set.new( [3, 4, 5, 6] ) }
      let!( :conditions ) { { set_a => :fsm_a, set_b => :fsm_b, set_c => :fsm_c } }

      subject( :graph ) { ConditionGraph.new.add_condition_sets conditions }
      subject( :simple_graph ) { ConditionGraph.new.add_conditions( set_a, :fsm_a ) }

      describe '#execute' do
        it 'should evaluate each condition only once and return the correct transition' do
          # We use a simplified representation for testing: conditions are represented as Fixnums
          # and transitions as symbols.  In other to ensure that EventProcessor still works correctly
          # we have to monkey patch both classes to behave similar enough to ConditionNode and Transition.
          class ::Fixnum
            include RSpec::Matchers

            # We use a slight of hand here.  The correct evaluate is passed the event for evaluation.
            # Instead, we pass the set of conditions that have not yet been evaluated in the event field.
            # This way we can keep track of what conditons have been evaluated without needing to interfere
            # in any way with EventProcessor::execute.  A rather extreme example of duck typing.
            def evaluate( fsms, conditions_not_tested_yet )
              expect( conditions_not_tested_yet.delete? self ).to be_truthy
              fsms
            end
          end

          expect( simple_graph.execute( set_a ) ).to contain_exactly :fsm_a
          expect( set_a ).to be_empty
        end

        context 'some conditions are true' do
          # See comment above about need to monkey patch Fixnum to support testing.
          class ::Fixnum
            def evaluate(fsms, set_of_conds_pass)
              set_of_conds_pass.member? self ? fsms : nil
            end
          end

          it 'should only return :fsm_a if conditons 3 to 6 are false ' do
            expect( graph.execute( set_a ) ).to contain_exactly( :fsm_a )
          end

          it 'should only return :fsm_b and :fsm_c for conditons 1 to 6' do
            expect( graph.execute( set_b ) ).to contain_exactly( :fsm_b, :fsm_c )
          end
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

    context 'should handle a complex set of conditions' do
      subject( :graph ) { ConditionGraph.new }
      let( :complex_conditions_set ) do
        {
          [2, 6, 7, 9] => :fsm_1,
          [5, 8, 9] => :fsm_2,
          [1, 4, 8, 10] => :fsm_3,
          [4, 5, 8, 10] => :fsm_4,
          [5, 9, 10] => :fsm_5,
          [2, 8] => :fsm_6,
          [2, 4, 5, 9, 10] => :fsm_7,
          [3, 7, 9, 10] => :fsm_8,
          [2, 5, 6, 8, 9] => :fsm_9,
          [2, 5, 9] => :fsm_10
        }
      end

      describe '#add_conditions' do
        it 'should add one condition set at a time correctly' do
          fail

          # noinspection RubyResolve
          conditions_sets_as_array = complex_conditions_set.keys

          conditions_sets_as_array.each_with_index do |conds, index|
            log.debug "iteration #{index}: adding #{conds.inspect} => #{complex_conditions_set[conds]}"

            # add the next condition set with transition into the graph.
            graph.add_conditions( conds, complex_conditions_set[conds] )

            log.debug "resulting graph: #{graph.inspect}"

            # now test if we have broken anything by lopping through each condition set
            # we have added to far, and making sure that they each execute correctly.
            (0..index).each do |i|
              condition_set_under_test = conditions_sets_as_array[i]
              expected_transition = complex_conditions_set[ condition_set_under_test ]
              log.debug "Testing #{i}: #{condition_set_under_test.inspect} => #{expected_transition}"
#              expect( graph.execute { |c| condition_set_under_test.member? c } ).to include( expected_transition )
            end
          end
        end
      end


      describe '#add_condition_sets' do
        it 'should build a graph correctly.' do
          graph = ConditionGraph.new.add_condition_sets complex_conditions_set

          log.debug graph.inspect

          # Now test that for every condition set we get the correct
          complex_conditions_set.each_pair do |condition_set, transition|
            log.debug "#{condition_set.inspect} => #{transition}"
            expect( graph.execute { |c| condition_set.member? c } ).to include( transition )
          end
        end
      end
    end
  end
end
