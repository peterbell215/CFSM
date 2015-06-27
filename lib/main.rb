# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

class NextStopDisplay < CFSM
  # If we are in state departing, and the system receives an exitStopBuffer event, then we execute the
  # handler set_next_stop before transitioning to the state :between_stops.
  state :departing, :on => :exitStopBuffer, :transition => :between_stops, :exec => set_next_stop
  
  # In this case, the action is unique to this transition and is included as a code block.  We can set
  # a new Event being generated.  The NSD driver will have subscribed to this event.  This state machine
  # does not need to know about it.  Alternative, we could drive the sign directly from the code block here.
  state :between_stops, :on => :stopButtonPush, :transition => :stopping_at_nxt_stop do |event, nxt_state|
    DisplayEvent.new :displayText => "Stopping:\n#{@nxtStop.name}"
  end
  
  state :stopping_at_nxt_stop, :on => :enterStop, :transition => :in_stop_zone do |event, nxt_state|
    DisplayEvent.new :displayText => "Stopping:\n#{@nxtStop.name}"    
  end
  
  # The block can also stop the transition happening.  It does this by returning a false.  In this case,
  # we need to explicitely state that the block will return a true.
  state :in_stop_zone, :on => :doorsOpen, :transition => :doors_open do |event, nxt_state|
    DisplayEvent.new :displayText => nil
    true
  end
  
  # We can define conditions for the event and the FSM to match for a state transition to happen.
  state :doors_open, :on => :doorsClose, :transition => :departing, :if => "!@nxtStop.lastStop" do |event, nxt_state|
    DisplayEvent.new :displayText => nil   
  end
  
  state :doors_open, :on => :doorsClose, :transition => :departing, :if => "@nxtStop.lastStop != true" do |event, nxt_state|
    DisplayEvent.new :displayText => nil     
  end
  
  state :in_stop_zone, :on => :exitStopBuffer, :transition => :between_stops, :exec => set_next_stop do |event, nxt_state|
    @nxtStop = event.nxtStop
    DisplayEvent.new :displayText => "Next Stop:\n#{@nxtStop.name}"
  end
  
  # If the same action is shared between transitions, then this can be captured with :exec
  def set_next_stop(event, nxt_state)
    @nxtStop = event.nxtStop
    DisplayEvent.new :displayText => "Next Stop:\n#{@nxtStop.name}"
  end
end


puts "Hello World"
