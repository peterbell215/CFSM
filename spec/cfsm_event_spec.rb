# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

require 'rspec'

require 'cfsm'
require 'cfsm_event'

describe CfsmEvent do
  describe '#initialize' do
    it 'should create an object with default priority and delay' do
      event = CfsmEvent.new :test_event

      expect( event.event_class ).to eq(:test_event)
      expect( event.prio ).to eq( 0 )
      expect( event.delay ).to eq( 0 )
      expect( event.status ).to eq( :created )
    end

    it 'should create an object with additional data items' do
      event = CfsmEvent.new :test_event, :data => { :data_string => 'String field', :data_fixnum => 5, :data_sym => :sym }

      expect( event.event_class ).to eq(:test_event)
      expect( event.data_string ).to eq( 'String field' )
      expect( event.data_fixnum ).to eq( 5 )
      expect( event.data_sym ).to eq( :sym )
      expect( event.status ).to eq( :created )
    end
  end

  context '#delayed events' do
    before(:each) do
      CFSM.reset

      class TestFSM < CFSM
        state :a do
          on :delayed_event, :transition => :b
        end

        state :b
      end
    end

    it 'should allow a delayed event to become active after a certain time.' do
      test_fsm = TestFSM.new
      CFSM.start
      test_event = CfsmEvent.new( :delayed_event, :delay => 0.10 )
      CFSM.post( test_event )

      expect( test_fsm.state ).to eql( :a )
      sleep( 0.05 )
      expect( test_fsm.state ).to eql( :a )
      sleep( 0.10 )
      expect( test_fsm.state ).to eql( :b )
    end

    it 'should do allow a delayed event to be cancelled.' do
      test_fsm = TestFSM.new
      CFSM.start
      test_event = CfsmEvent.new( :delayed_event, :delay => 0.10 )
      CFSM.post( test_event )

      expect( test_fsm.state ).to eql( :a )
      sleep( 0.05 )
      expect( CFSM.cancel( test_event ) ).to be_truthy
      sleep( 0.06 )
      expect( test_fsm.state ).to eql( :a )
    end

    it 'should fail to cancel an already processed event' do

    end
  end



end