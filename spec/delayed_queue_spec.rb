# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.
require 'rspec'
require 'rspec/expectations'

require 'cfsm'

module CfsmClasses
  describe DelayedQueue do
    describe '#post' do
      let!(:seq) { Enumerator.new { |yielder| 0.step { |num| yielder.yield num } } }
      let!(:delay_seq) { Enumerator.new { |yielder| i=0; loop { yielder.yield( i += rand + 1 ) } } }
      let!(:expected_events) { Array.new(10) { CfsmEvent.new( :tst_event, :delay => delay_seq.next, :data => { :seq => seq.next } ) } }
      let!(:expected_events_seq) { expected_events.each }
      let!(:start_time) { Time.now }
      let!(:wait_for_retrieves) { ConditionVariable.new }

      it 'should raise exception if an event does not have a delay or expiry set' do
        delayed_queue = DelayedQueue.new { |event| }
        expect { delayed_queue.post CfsmEvent.new( :tst_event ) }.to raise_exception CfsmEvent::EventDoesNotHaveExpiry
        delayed_queue.kill
      end

      it 'should retrieve events at the correct time if pushed in order' do
        event_retrieved = false
        delayed_queue = DelayedQueue.new do |event|
          expected_event = expected_events_seq.next
          expect(Time.now - expected_event.expiry < 0.01 )
          expect(event.seq ).to eq( expected_event.seq )
        end

        expected_events.each { |event| delayed_queue.post event }

        until delayed_queue.empty?
          sleep 1
        end

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
          delta = Time.now - expected_event.expiry
          expect( Time.now - expected_event.expiry < 0.01 )
          expect(event.seq ).to eq( expected_event.seq )
        end

        events.each { |event| delayed_queue.post event }

        until delayed_queue.empty?
          sleep 1
        end

        delayed_queue.kill
      end

      it 'should receive an event that is sooner than the current top event' do
        # We add an element that is ahead of the current queue.
        first_event = CfsmEvent.new( :tst_event, :delay => 1, :data => { :seq => seq } )
        events = expected_events.shuffle.push first_event      # This ensures the last element has a 1s delay.
        expected_events.unshift first_event

        delayed_queue = DelayedQueue.new do |event|
          expected_event = expected_events_seq.next
          delta = Time.now - expected_event.expiry
          expect( Time.now - expected_event.expiry < 0.01 )
          expect(event.seq ).to eq( expected_event.seq )
        end

        events.each { |event| delayed_queue.post event }

        until delayed_queue.empty?
          sleep 1
        end

        delayed_queue.kill
      end
    end
  end
end
