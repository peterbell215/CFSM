# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'condition_parser'
require 'condition_transform'
require 'rspec/expectations'

describe ConditionTransform do
  let( :condition_parser ) { ConditionParser.new }
  let( :condition_transform ) { ConditionTransform.new }

  it 'should produce an evaluation of a comparison' do
    expect( condition_transform.apply( condition_parser.parse('a == "Peter"') ) ).to be_nil
  end
end

