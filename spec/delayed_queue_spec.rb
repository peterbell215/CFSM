# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.
require 'rspec'
require 'rspec/wait'
require 'rspec/expectations'

require 'cfsm'

module CfsmClasses
  describe DelayedQueue do
    before(:each) { CFSM.reset }

    let!(:seq) { Enumerator.new { |yielder| 2.step { |num| yielder.yield num } } }
    let!(:expected_events) { Array.new(5) { d = seq.next; CfsmEvent.new( :tst_event, :delay => 2+d/2.0, :data => { :seq => d } ) } }
    let!(:expected_events_seq) { expected_events.each }

    describe '#post' do
      it 'should raise exception if an event does not have a delay or expiry set' do
        delayed_queue = DelayedQueue.new { |event| }
        expect { delayed_queue.post CfsmEvent.new( :tst_event ) }.to raise_exception CfsmEvent::EventDoesNotHaveExpiry
        delayed_queue.kill
      end

      # TODO: the following code is not very DRY.  Not sure what to do about it for now.
      it 'should retrieve events at the correct time if pushed in order' do
        delayed_queue = DelayedQueue.new do |event|
          expected_event = expected_events_seq.next
          expect(Time.now - expected_event.expiry).to be < 0.01
          expect(event.seq ).to eq( expected_event.seq )
        end

        expected_events.each { |event| delayed_queue.post event }

        wait_for( delayed_queue ).to be_empty

        delayed_queue.kill
      end

      it 'should retrieve events at the correct time if pushed in random order but no override of first element' do
        # If we add an element whose delay is ahead of the first element in the queue, this will require the Delayed
        # queue to cancel the first event and start again.  Here we avoid that edge case.  Deal with that in the next test.
        first_event = CfsmEvent.new( :tst_event, :delay => 1, :data => { :seq => seq.next } )
        events = expected_events.shuffle.unshift first_event  # This ensures the first element is a 1s delay.  The 2nd is at least 2s
        expected_events.unshift first_event

        delayed_queue = DelayedQueue.new do |event|
          expected_event = expected_events_seq.next
          expect(Time.now - expected_event.expiry).to be < 0.01
          expect(event.seq ).to eq( expected_event.seq )
        end

        events.each { |event| delayed_queue.post event }

        wait_for( delayed_queue ).to be_empty

        delayed_queue.kill
      end

      it 'should receive an event that is sooner than the current top event' do
        # We add an element that is ahead of the current queue.
        first_event = CfsmEvent.new( :tst_event, :delay => 1, :data => { :seq => seq } )
        events = expected_events.shuffle.push first_event      # This ensures the last element has a 1s delay.
        expected_events.unshift first_event

        delayed_queue = DelayedQueue.new do |event|
          expected_event = expected_events_seq.next
          expect(Time.now - expected_event.expiry).to be < 0.01
          expect(event.seq ).to eq( expected_event.seq )
        end

        events.each { |event| delayed_queue.post event }

        wait_for( delayed_queue ).to be_empty

        delayed_queue.kill
      end
    end

    describe '#cancel' do
      it 'should correctly remove an event other than the first one.' do
        $DEBUG = true

        delayed_queue = DelayedQueue.new do |event|
          CFSM.logger.info "length = #{delayed_queue.size}"
          expect( event.seq ).not_to eq(5)
          expected_event = expected_events_seq.next
          expect(Time.now - expected_event.expiry).to be < 0.01
          expect(event.seq ).to eq( expected_event.seq )
        end

        expected_events.each { |event| delayed_queue.post event }

        delayed_queue.cancel( expected_events.delete_at(3) )

        while !delayed_queue.empty?
          sleep 5
        end

        delayed_queue.kill
      end

      it 'should correctly remove the first one and spit out the next one at the correct time' do
        delayed_queue = DelayedQueue.new do |event|
          expect( event.seq ).not_to eq(2)
          expected_event = expected_events_seq.next
          expect(Time.now - expected_event.expiry).to be < 0.01
        end

        expected_events.each { |event| delayed_queue.post event }

        delayed_queue.cancel( expected_events.shift )

        wait_for( delayed_queue ).to be_empty

        delayed_queue.kill
      end
    end
  end
end
