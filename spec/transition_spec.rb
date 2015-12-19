# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.
require 'rspec'

require 'cfsm'

module CfsmClasses
  describe Transition do
    before(:each) do
      CFSM.reset

      class TestFSM_A < CFSM
        state :a do
          on :event1, :transition => :b
        end
      end

      class TestFSM_B < CFSM
        state :b do
          on :event1, :transition => :b
        end
      end
    end

    describe '#instantiate' do
      # Note the use of let! - needed as lazy evaluation would otherwise mean that the FSM has not been registered
      # when the expect is executed.
      let!( :test_a ){ TestFSM_A.new }
      let!( :test_b ){ TestFSM_A.new }
      let!( :test_c ){ TestFSM_B.new }

      subject( :transition ){ Transition.new( TestFSM_A, :a, nil ) }

      it 'should instantiate transitions for all state machines' do
        # Note, that test_c is missing from the array since its FSM is not referenced in the transition.
        fsms = [test_a, test_b]

        transition.instantiate( :all ).each { |transition| expect(fsms.delete(transition.fsm)).to equal(transition.fsm) }
        expect( fsms ).to be_empty
      end

      it 'should instantiate transitions for a subset of state machines' do
        # Note, that test_b is missing since it is not in the list of FSMs to instantiate.
        # test_c is missing from the array since its FSM is not referenced in the transition.
        expect( transition.instantiate( [test_a, test_c] )[0].fsm ).to equal( test_a )
      end
    end
  end
end