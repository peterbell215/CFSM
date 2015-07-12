# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

##
# Uses to represent a condition node within a directed graph of conditions.
# The directed graph shows the RETE decision tree.
class ConditionsNode
  def initialize( conditions, transitions, edges = [], start_node = true )
    @start_node = start_node
    @conditions = Set.new( conditions ) # make a copy 
    @transitions = Set.new( transitions ) # make a copy
    @edges = Set.new( edges )
  end
  
  ##
  # This is checking whether the two nodes are close enough to then doing a closer
  # examination.
  def similar( cond_node2 )
    byebug if self.edges.nil? || cond_node2.edges.nil?
    
    self.conditions == cond_node2.conditions &&
      self.transitions == cond_node2.transitions &&
      self.start_node == cond_node2.start_node &&
      self.edges.length == cond_node2.edges.length
  end
  
  ##
  # Make sure that any conditions added to the ConditionsNode is a set.
  def conditions=( conds )
    @conditions = ( conds.is_a? Set ) ? conds : Set.new( conds )
  end
  attr_reader :conditions
    
  attr_accessor :start_node
  attr_accessor :transitions
  attr_accessor :edges
end
