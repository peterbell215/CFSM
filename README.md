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

Once, all the state machines have been instantiated, then the system is started with the ```CFSM.run``` instruction.  Normally, the state machine system executes asynchronously in its own thread.  This allows other threads to run that create the external events.

## Events

### General
For a FSM to work, it needs to react to events.  Events are of the ```CfsmEvent``` class or a derived class.  Example:

```ruby
event = CfsmEvent.new( :incoming_call )
CFSM.post( event )
```

This creates an event of type ```:incoming_call```.  The instruction ```CFSM.post``` then makes the CFSM system aware of the event. The system will automatically work out to which FSMs the event needs to be sent to effect a state transition.  All state machines that can react to the event will react to it.  If no state machine can react to the event, then the event gets queued until at least one FSM can act on the event.  This was a conscious design decision to avoid race conditions causing events to get lost.  This does mean that if an event can be generated that the system should ignore, this needs to be explicitly captured as a valid transition using something like:

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

Note that each of the items in ```CfsmEvent``` data hash is accessible via a suitable method.

### Priority

Events can be prioritised to ensure that more important events are acted on more quickly:

```ruby
call = CfsmEvent.new :incoming_call, :prio => 3
```

The lowest and default priority is zero.  Priorities can be positive Fixnums.  Within a priority events are processed on a first-in, first-out basis.

### Delayed Events

Sometimes, we want an event to first be triggered after a certain time.  Using the delay attributes allows the user to define in how many seconds an event will happen.  For example;

```ruby
call_back = CfsmEvent.new :call_back, :delay => 30, :data => { :callback_number => '01225 700000' }
CFSM.post( call_back )
```
## Conditions

Sometimes we want a FSM only to react if certain conditions are met.  For example, we might block a call from abroad:

```ruby
class Telephone < CFSM
    state :nothing_happening do
        on :incoming_call, :transition => :ringing, :if => 'orig==:uk'
    end

    # ...
end

my_phone = Telephone.new

CFSM.start
CFSM.post( CfsmEvent.new(:call, :data => { :orig => :de } )

my_phone.state
# => :nothing_happening

CFSM.post( CfsmEvent.new(:call, :data => { :orig => :uk } )

my_phone.state
# => :incoming_call
```

The parser that interprets the _if_ clause supports a verity of condition tests:

```ruby
on :event, :transition => :new_state, :if => 'cost<5 || cost<10 && important'
```

Tests that the method call ```event.cost``` returns less than 5, or that ```event.cost``` to be less than 10 and ```event.important``` to be truthy.  Event method calls can be concatenated. So ```event.name.length``` is also valid.

The parser supports parentheses, booleans and comparisons with numbers, strings or symbol.  The following are all valid clauses:

```ruby
on :event, :transition => :new_state, :if => 'cost<5 && (org=:cam || org=:lon)'
on :event, :transition => :new_state, :if => 'name="Peter"'
```

We may have some information internal to the state machine other than the state itself which we want to take into account in the condition.  The following supports this:

```ruby
on :event, :transition => :new_state, :if => '@subscription_status==:enabled'
```

Although we use the @ symbol to represent a state check, this is actually executed as a method call.  Now that method can be a instance variable accessor.  However, it may be a more complex calculation as well.

## Actions

Clearly, just performing transitions on there own is not particularly useful.  The FSM needs to perform actions based on those transitions.  Two forms of actions can be specified using the FSM:

```ruby
class Telephone < CFSM
    state :nothing_happening do
        # Form 1: Do block
        on :incoming_call, :transition => :ringing do |event|
            Audio.play 'ring.wav'
            true
        end

        # Form 2: Execute a method call
        on :off_hook, :transition => :connection, :exec => open_voip_connection
    end

    state :ringing
        # Form 2: Execute a method call
        on :ringing, :transition => :off_hook, :exec => open_voip_connection
    end

    def open_voip_connection(event, next_state)
        Audio.stop
        Voip.connect   # Note, returns nil if it fails
    end
end
```
In both forms, we allow for the action to fail leading to the transition not happening.  So if the block or method returns a falsey value, then the transition does not happen.  Clearly the block may have already made some other changes that it will need to undo for itself before returning.

## Namespacess

Groups of related FSMs can be grouped into a namespace by including them in the same modules.  Events are not specific to a namespace, so an event posted will be evaluated in all namespaces that have FSMs that have declared an interest in the event.  Namespaces are still

