# CFSM

## Introduction

When trying to build systems that deal with real world scenarios (particularly embedded and communications), then Communicating Finite State Machines is a powerful paradigm.  Too often, I have seen programmers to struggle trying to make what should be a simple change struggle, because they have in effect one very complex finite state machine.

This library was created out of a desire to provide an easy way within Ruby to construct systems of communicating finite state machines.  In our model, a class of CFSMs can be created by deriving a class from CFSM.

## Defining a State Machine

```ruby
class Telephone < CFSM
    state :nothing_happening do
        on :incoming_call, :transition => :ringing
    end
    
    state :ringing do
        on :receiver_lifted, :transition => :connection
    end
end

fsm = Telephone.new( :fsm_name)     # create an instance of the Telephone FSM
CFSM.run                            # Start the state machine system running

```
This clearly shows how to specify a simple state machine.  The first defined state is the initial state of the FSM. In our case the state ```:nothing_happening```.  States are always symbols.

State machines need to be created in the same way as any other object. This allows the same state machine to be used multiple times in a program.   For example, we can choose to create multiple phones.  When invoking the constructor, we can pass a name either as a symbol or a string.  If no name is passed, then the code reference is used as the name.

Once all the state machines have been instantiated, then the system is started with the ```CFSM.run``` instruction.  Normally, the state machine system executes asynchronously in its own thread.  This allows other threads to run that create the external events.

## Events

### General
For a FSM to work, it needs to react to events.  Events are of the ```CfsmEvent``` class or a derived class.  Example:

```ruby
event = CfsmEvent.new( :incoming_call )
CFSM.post( event )
```

This creates an event of type ```:incoming_call````.  The instruction ```CFSM.post``` then makes the CFSM system aware of the event. The system will automatically work out to which FSMs the event needs to be sent to effect a state transition.  All state machines that can react to the event will react to it.  If no state machine can react to the event, then the event gets queued.  This was a conscious design decision to avoid race conditions causing events to get lost.  This does mean that if an event can be generated that the system should ignore, this needs to be explicitly captured as a valid transition using something like:

```ruby
    state :a do
        on :a, :transition => :a
    end
```

### Data

We can attach data to the event by providing a hash of values.  Example:

```ruby
call = CfsmEvent.new :incoming_call, :data => { :call_number => '01225 700000', :exchange => 5 }
call.call_number
# ... returns '01225 700000
```

Each of the items in ```CfsmEvent``` data hash is accessible via a suitable method.

### Priority

Events can be prioritised to ensure that more important events are acted on more quickly:

```ruby
call = CfsmEvent.new :incoming_call, :prio => 3
```

The lowest and default priority is zero.  Priorities can be positive Fixnums.

## Actions





## Conditions

## Namespacess



