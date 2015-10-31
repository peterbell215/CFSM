# @author Peter Bell
# @copyright 2015
# Licensed under MIT.  See License file in top level directory.
require 'rspec'
require 'rspec/expectations'

require 'cfsm'

# Test class used to exercise the SortedArray.  Store insert sequence in an instance variable.
class Entry
  include Comparable

  def Entry.init_counter
    @@inserted = Enumerator.new { |yielder| 0.step { |num| yielder.yield num } }
  end

  def initialize(p)
    @insert_sequence = @@inserted.next
    @prio = p
  end

  attr_reader :insert_sequence
  attr_reader :prio

  def to_s
    "< prio=#{prio}, insert_sequence=#{insert_sequence} >"
  end
end

module CfsmClasses
  describe SortedArray do
    subject { SortedArray.new { |e1, e2| e1.prio <=>e2.prio } }

    before(:each) { Entry.init_counter }

    it 'should correctly add an element to an empty array' do
      subject.push( Entry.new( 1 ) )
      expect( subject.shift ).to have_attributes(:insert_sequence => 0, :prio => 1)
    end

    it 'should correctly prepend an element to a single member array' do
      subject.push( Entry.new( 2 ) )
      subject.push( Entry.new( 1 ) )

      expect( subject.shift ).to have_attributes(:insert_sequence => 1, :prio => 1)
      expect( subject.shift ).to have_attributes(:insert_sequence => 0, :prio => 2)
    end

    it 'should correct append an element to a single member array' do
      subject.push( Entry.new( 1 ) )
      subject.push( Entry.new( 1 ) )

      expect( subject.shift ).to have_attributes(:insert_sequence => 0, :prio => 1)
      expect( subject.shift ).to have_attributes(:insert_sequence => 1, :prio => 1)
    end

    it 'should correctly insert an element of the same priority into the array after others of that priority' do
      [0, 1, 2].each { |i| subject.push( Entry.new( i ) ) }  # create the priority array

      subject.push( Entry.new( 1 ) )

      # prio, insert_sequence
      [ { :prio => 0, :insert_sequence => 0 },
        { :prio => 1, :insert_sequence => 1 },
        { :prio => 1, :insert_sequence => 3 },
        { :prio => 2, :insert_sequence => 2 } ].each do |expected|
        expect( subject.shift ).to have_attributes( expected )
      end
    end

    it "should correctly insert a sequence of elements" do
      (0..8).to_a.permutation.each do |seq|
        result = SortedArray.new { |e1, e2| e1.prio <=> e2.prio }
        expected_result = []

        seq.each do |i|
          entry = Entry.new( i/2 )
          result.push entry
          expected_result.push entry
        end
        expected_result.sort! { |e1, e2| e1.prio <=> e2.prio }
        expect( result ).to match( expected_result )
      end
    end

  end
end




