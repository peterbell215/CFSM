# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

require 'condition_parser/parser'
require 'condition_parser/condition_transform'
require 'rspec/expectations'

module ConditionParser
  describe ConditionTransform do
    let( :condition_parser ) { Parser.new }
    let( :condition_transform ) { ConditionTransform.new }

    it 'should produce an evaluation of a comparison' do
      # TODO: this needs a better test.
      expect( condition_transform.apply( condition_parser.parse('a == "Peter"') ) ).not_to be_nil
    end
  end
end
