# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.

require 'rspec'

require 'cfsm_event'
require 'cfsm_classes/prio_queue'

module CfsmClasses
  describe PrioQueue do
    subject( :queue ) { PrioQueue.new }

    context 'basic queue behaviour' do
      it 'should stack and unstack in the correct order for same priority' do
        (0..10).each { |i| queue.push( CfsmEvent.new :test_event, :data => { :element => i } ) }
        (0..10).each { |i| expect( queue.pop.element ).to eq( i ) }
      end

      it 'should stack and unstack in the correct order for different priorities' do
        prio_map = (0..10).to_a.shuffle
        (0..10).each { |i| queue.push( CfsmEvent.new :test_event, :prio => prio_map[i], :data => { :element =>  i } ) }
        10.times do
          event = queue.pop
          expect( prio_map[event.element] ).to eq( event.prio )
        end
      end
    end

    describe '#size' do
      it 'should return zero for an empty queue' do
        expect( queue.size ).to eq(0)
      end

      it 'should return the correct size for a queue with elements' do
        11.times { queue.push( CfsmEvent.new :test_event, :prio => rand(10), :data => { :element =>  rand(10) } ) }
        expect( queue.size ).to eq(11)
      end
    end

    describe '#remove' do
      it 'should remove elements in the queue' do
        data = (0..10).to_a.shuffle!
        events = Array.new(11) { CfsmEvent.new :test_event, :prio => rand(6), :data => { :element => data.pop } }

        events.each { |e| queue.push( e ) }

        events.each do |event|
          expect( queue.remove( event ) ).to eql( event )
        end

        expect( queue.size ).to eq( 0 )
      end

      it 'should return nil if attempting to remove an element not in the queue' do
        data = (0..10).to_a.shuffle!
        11.times { queue.push( CfsmEvent.new :test_event, :prio => rand(6), :data => { :element => data.pop } ) }

        expect( queue.remove( CfsmEvent.new :test_event, :prio => rand(6), :data => { :element => 15 } ) ).to be_nil
        expect( queue.size ).to eq( 11 )
      end

      it 'should return nil if attempting to remove from empty queue' do
        expect( queue.remove( CfsmEvent.new :test_event, :prio => rand(6), :data => { :element => 15 } ) ).to be_nil
      end
    end

    describe '#to_a' do
      it 'should generate an array' do
        data = (0..10).to_a.shuffle
        prio = (0..10).to_a.reverse!

        (0..10).each { |i| queue.push( CfsmEvent.new :test_event, :prio => prio[i], :data => { :element =>  data[i] } ) }

        queue.to_a.each_with_index do |item, index|
          expect(item.element).to eq(data[index])
          expect(item.prio).to eq(prio[index])
        end
      end
    end

    [ :pop_each, :peek_each ].each do |method|
      describe "##{method.to_s}" do
        it 'should yield the elements in the correct order' do
          data = (0..10).to_a.shuffle
          prio = (0..10).to_a.reverse!

          (0..10).each { |i| queue.push( CfsmEvent.new :test_event, :prio => prio[i], :data => { :element => data[i] } ) }

          index = 0

          queue.send( method ) do |item|
            expect(item.element).to eq(data[index])
            expect(item.prio).to eq(prio[index])
            index += 1
          end
        end
      end
    end

    describe '#inspect' do
      it 'should generate a string showing the queue.' do
        (0..2).each { |i| queue.push( CfsmEvent.new :test_event, :prio => i, :data => { :element => i } ) }

        result = queue.inspect.split("\n")[1..-1]

        (0..2).each do |i|
          expect( result[i] ).to eq( "{ test_event: prio = #{2-i}, status = nil, data = {:element=>#{2-i}} }")
        end
      end


    end

    context '#async behaviour' do
      it 'should make a thread wait until an element is available' do
        t = Thread.new do
          # try and read an element from the queue.
          (0..10).each { |i| expect( queue.pop.element ).to eq( i ) }
        end

        (0..10).each do |i|
          # keepting sleeping till the thread status is "sleep" i.e. waiting for input
          sleep 0.001 while t.status != 'sleep'
          queue.push(CfsmEvent.new :test_event, :data => {:element => i} )
        end
      end

      describe '#wait_for_new_element' do
        it 'should wait for a new element to arrive even it the queue has content' do
          6.times { queue.push( CfsmEvent.new :test_event, :prio => rand(10), :data => {:element => rand(10) } ) }

          expect( queue.size ).to eq( 6 )

          t = Thread.new do
            queue.wait_for_new_event
            expect( queue.size ).to eq( 7 )
          end

          sleep 0.001 while t.status != 'sleep'
          queue.push(CfsmEvent.new :test_event, :data => { :element => 8 } )
        end
      end
    end
  end
end
