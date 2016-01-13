# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.

require 'rspec'

require 'CFSM'
require 'cfsm_event'

describe CfsmEvent do
  describe '#initialize' do
    it 'should create an object with default priority and delay' do
      event = CfsmEvent.new :test_event

      expect( event.event_class ).to eq(:test_event)
      expect( event.prio ).to eq( 0 )
      expect( event.expiry ).to be_nil
      expect( event.status ).to be_nil
    end

    it 'should create an object with additional data items' do
      event = CfsmEvent.new :test_event, :data => { :data_string => 'String field', :data_fixnum => 5, :data_sym => :sym }

      expect( event.event_class ).to eq(:test_event)
      expect( event.data_string ).to eq( 'String field' )
      expect( event.data_fixnum ).to eq( 5 )
      expect( event.data_sym ).to eq( :sym )
      expect( event.status ).to be_nil
    end

    it 'should raise an Exception if an unknown option is provided in the initialisation hash' do
      expect { CfsmEvent.new( :test_event, :data => { :data_string => 'String field' }, :erroneous_field => true ) }.to raise_exception(CFSM::CfsmEventHasIllegalOption)
    end
  end

  describe '#inspect' do
    it 'should return a string describing the event' do
      expect( CfsmEvent.new( :test_event, :src => 'rspec', :prio => 1,
                             :data => { :data_string => 'String field', :data_fixnum => 5, :data_sym => :sym } ).inspect ).to \
      eq('{ test_event: src = rspec, prio = 1, status = nil, expiry = nil, data = {:data_string=>"String field", :data_fixnum=>5, :data_sym=>:sym} }')

      # TODO remove the absolute line reference in the string.
      expect( CfsmEvent.new( :test_event, :prio => 2, :expiry => Time.mktime(2015,12,1,14,30),
                             :data => { :data_string => 'String field', :data_fixnum => 5, :data_sym => :sym } ).inspect ).to \
      eq('{ test_event: src = _spec.rb:42:in `new\', prio = 2, status = nil, expiry = 1-Dec 14:30.000, data = {:data_string=>"String field", :data_fixnum=>5, :data_sym=>:sym} }')
    end
  end

  describe '#set_status' do
    subject(:event) { CfsmEvent.new :test_event }

    it 'should create a hash to store the namespaces if set.' do
      expect( event.status ).to be_nil
      event.instance_eval { set_status( :delayed ) }
      expect( event.status ).to eq( :delayed )
      expect( event.status( 'OtherNamespace' ) ).to eq( :delayed )
      event.instance_eval { set_status( :cancelled ) }
      expect( event.status ).to be_nil
    end

    it 'should raise an exception if already posted and then status is set to delayed' do
      event.instance_eval { set_status( :pending, 'NameSpace1' ) }
      expect { event.instance_eval { set_status( :delayed, 'NameSpace2' ) } }.to raise_exception(CFSM::AlreadySubmittedSetToDelayed)
    end

    it 'should remove namespaces correctly.' do
      event.instance_eval { set_status( :pending, 'NameSpace1' ) }
      event.instance_eval { set_status( :pending, 'NameSpace2' ) }
      expect( event.status('NameSpace1') ).to eq( :pending )
      expect( event.status('NameSpace2') ).to eq( :pending )

      event.instance_eval { set_status( :cancelled, 'NameSpace1' ) }
      expect( event.status('NameSpace1') ).to be_nil
      expect( event.status('NameSpace2') ).to eq( :pending )

      event.instance_eval { set_status( :cancelled, 'NameSpace2' ) }
      expect( event.status('NameSpace1') ).to be_nil
      expect( event.status('NameSpace2') ).to be_nil
    end
  end

  context '#delayed events' do
    before(:each) do
      CFSM.reset

      class TestFSM < CFSM
        state :a do
          on :delayed_event, :transition => :b
          on :event, :transition => :c
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

    it 'should allow a delayed event to be cancelled.' do
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
      test_fsm = TestFSM.new
      CFSM.start

      expect( test_fsm.state ).to eql( :a )

      test_event = CfsmEvent.new( :event )
      CFSM.post( test_event )

      sleep( 0.05 )
      expect( test_fsm.state ).to eql( :c )

      expect( CFSM.cancel( test_event ) ).to be_falsey
    end
  end
end