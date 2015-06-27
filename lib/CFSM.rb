# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.
class CFSM
  
  # the core function that does the heavy lifting.
  def state(state, other_parameters, &exec_block)
    # The first clause of the evalgraph must be a check on the state the FSM
    # is currently in.
    evalgraph = EvalGraph.new( state )
    
    # If an if clause is defined, then build a graph to evaluate it.
    evalgraph.add_checks( other_parameters[:if] ) if other_parameters[:if]
    
    # Check that we don't have both an :exec ptr to a method, and an exec block
    raise ExecAndBlockDefined if other_parameters[:exec] && exec_block
    
    if exec_block
      evalgraph.add_transition( other_parameters[:transition], exec_block )
    elsif other_parameters[:exec]
      evalgraph.add_transition( other_parameters[:transition], other_parameters[:exec] )
    end
    
    # Finally register the evalGraph to the event
    other_parameters[:on].register( self, evaltree )    
  end
end
