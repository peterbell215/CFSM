# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.

require 'rspec'

require 'cfsm'
require 'cfsm_event'
require 'condition_parser/event_attribute'

module ConditionParser
  describe EventAttribute do
    before(:all) do
      class TestEvent < CfsmEvent
        def initialize(a)
          @attr2 = a
        end
        def method1
          return 'method1'
        end

        attr_reader :attr2
      end

      class TestFSM < CFSM; end
    end

    let(:fsm) { CFSM.new }
    let(:eventmsg) { TestEvent.new( 5 ) }
    let(:eventattribute1) { EventAttribute.new( :method1 ) }
    let(:eventattribute2) { EventAttribute.new( :attr2 ) }

    describe '#hash' do
      it 'should generate the same hash for the same condition' do
        expect( eventattribute1.hash ).to eq( EventAttribute.new( :method1 ).hash )
        expect( eventattribute1.hash ).not_to eq( eventattribute2.hash )
      end
    end

    describe '#evaluate' do
      it 'should correctly evaluate the attribute' do
        expect( eventattribute1.evaluate( eventmsg ) ).to eq 'method1'
        expect( eventattribute2.evaluate( eventmsg ) ).to eq 5
      end
    end

    describe '#==' do
      it 'should correctly compare' do
        expect( eventattribute1 == EventAttribute.new( :method1 ) ).to be_truthy
        expect( eventattribute1 == eventattribute2 ).to be_falsey
      end
    end
  end
end