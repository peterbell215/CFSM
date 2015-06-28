# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

class EventProcessor
  @@parser = ConditionParser.new
  
  # Hash with one event processor for each event type in the system.
  @@event_processors = {}
  
  ##
  # name: event name - either a Class derived from CfsmEvent or a symbol
  # cfsm: reference to the FSM that is registering an interest in the even
  # current_state: symbol - the state in which the event has to be to accept the event
  # transition_state: symbol - the state to which the FSM will move if the event is processed successfully
  # condition: an expression (see ConditionParser for details) that has to be checked
  # proc: the 
  def self.register_event( name, fsm, current_state, next_state, condition = nil, &proc )
    if @@event_processors[ name ]
      @@event_processors[ name ].merge( fsm, current_state, next_state, 
        condition ? @@parser.parse( condition ) : nil, proc )
    else
      @@event_processors[ name ] = EventProcessor.new( fsm, current_state, next_state, 
        condition ? @@parser.parse( condition ) : nil, &proc )
    end
  end
  
  
  def self.process_event( event )
    raise "Still to come"
  end
  
  def initialize
    @prog = [] 
  end
  
  def build_initial_prog( fsm, current_state, next_state, condition, &proc )
    @prog << CheckFsmState.new( fsm, current_state )
    
    if condition
      
    end
  end
end
