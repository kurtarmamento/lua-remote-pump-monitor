# ROADMAP.md

## Purpose

This roadmap tracks the planned evolution of the Lua Remote Pump Monitor project.

The intent is to keep the project focused, incremental, and understandable. Each milestone adds one major layer of system behavior.



## Guiding principle

Build the system in the same order that the real system operates:

1. plant model
2. state interpretation
3. alarm logic
4. remote commands
5. transport and offline behavior
6. operator view
7. documentation and polish

This keeps the learning process aligned with the architecture.



## Current phase

**Phase 1: single-asset simulated remote pump monitor**

Focus:
- one pump station
- one operator workflow
- clear state and alarm behavior
- offline telemetry queueing
- local simulation first



## Milestone 1 — Plant model and telemetry baseline

### Goal
Build a simple but believable simulated pump station.

### Deliverables
- `config.lua`
- `simulator.lua`
- `main.lua`
- initial `DESIGN.md`

### Features
- tank level
- suction pressure
- discharge pressure
- flow rate
- supply voltage
- pump command and feedback
- valve command and feedback
- network online/offline flag

### Success criteria
- the simulator updates once per tick
- values change consistently with pump and valve behavior
- printed snapshots make sense physically

### Learning focus
Understand the difference between:
- measured variables
- commanded variables
- derived conditions



## Milestone 2 — State machine

### Goal
Convert raw plant readings into explicit operating state.

### Deliverables
- `state_machine.lua`

### Features
- `IDLE`
- `STARTING`
- `RUNNING`
- `WARNING`
- `FAULT`
- `LOCKOUT`

### Success criteria
- state transitions are explicit
- state is printed or logged every cycle
- the system does not rely on scattered conditionals only

### Learning focus
Understand why operational state is a model, not just a collection of numbers.



## Milestone 3 — Alarm engine

### Goal
Detect abnormal conditions in a controlled and configurable way.

### Deliverables
- `alarms.lua`
- `docs/alarm-matrix.md`

### Initial alarms
- low tank level
- no flow while running
- overpressure
- low voltage
- comms lost

### Success criteria
- alarms use debounce
- alarms have clear conditions
- alarms can be raised and cleared cleanly
- repeat alerts are suppressed for a time window

### Learning focus
Understand the difference between monitoring and diagnostics.



## Milestone 4 — Remote commands and safety rules

### Goal
Allow the operator side to influence the asset safely.

### Deliverables
- `commands.lua`
- `docs/command-protocol.md`

### Commands
- `START_PUMP`
- `STOP_PUMP`
- `OPEN_VALVE`
- `CLOSE_VALVE`
- `SET_PRESSURE_TARGET`
- `ACK_ALARM`
- `RESET_FAULT`

### Safety rules
- reject unsafe starts
- reject actions in lockout
- force stop on severe faults
- require proper reset path where appropriate

### Success criteria
- every command produces a response
- commands can be accepted or rejected
- rejection reasons are clear
- state changes are visible after commands

### Learning focus
Understand that remote control is constrained by system state and safety logic.



## Milestone 5 — Transport behavior and offline queueing

### Goal
Simulate the communications realities of remote systems.

### Deliverables
- `transport.lua`
- `storage.lua`
- queue replay tests

### Features
- heartbeat messages
- alarm events
- command responses
- state snapshots
- offline queueing
- ordered replay on reconnect

### Success criteria
- no messages are lost during simulated outage
- queued messages replay oldest-first
- timestamps and sequence handling are clear

### Learning focus
Understand store-and-forward behavior and why the edge device must remain useful while offline.



## Milestone 6 — Operator/backend visibility

### Goal
Show how the device behavior becomes operational information.

### Deliverables
- backend viewer or simple dashboard
- `docs/demo-scenarios.md`

### Minimum display requirements
- current asset state
- active alarms
- recent events
- latest readings
- last contact time
- most recent command result

### Success criteria
- a reviewer can follow the device-to-operator loop
- a command can be issued and its result can be observed
- demo scenarios are repeatable

### Learning focus
Understand what operators need to see and why event logs matter.



## Milestone 7 — Testing, packaging, and documentation polish

### Goal
Turn the prototype into a portfolio-ready project.

### Deliverables
- polished `README.md`
- polished `DESIGN.md`
- `RESULTS.md`
- test files
- screenshots and demo evidence

### Minimum tests
- state transition test
- alarm trigger/clear test
- command validation test
- queue replay test

### Success criteria
- the repo is understandable without verbal explanation
- the major design choices are documented
- the demo cases are easy to run

### Learning focus
Understand how to communicate engineering decisions clearly.


## Version targets

## v0.1
Basic simulator with sensible plant behavior

## v0.2
State machine added

## v0.3
Alarm engine added

## v0.4
Command handling added

## v0.5
Transport and offline queueing added

## v0.6
Operator/backend view added

## v1.0
Documented, tested, demo-ready single-asset system


## Stretch goals

These are optional after v1.0:

- multi-asset simulation
- mobile pump trailer mode
- local maintenance/service mode
- config update simulation
- predictive maintenance score
- richer dashboard
- hardware-in-the-loop version
- low-voltage output demo on microcontroller



## Scope control rules

To keep the project strong, follow these rules:

- do not add hardware complexity before the core logic is stable
- do not add extra sensors unless they support a clear operational behavior
- do not add multiple assets too early
- do not build a complex dashboard before the transport model works
- do not let the roadmap become a vague wishlist

Each new feature should answer:
1. what subsystem it belongs to
2. what scenario it supports
3. what concept it teaches



## Definition of done for v1.0

Version 1.0 is done when the project can demonstrate:

- normal start and run behavior
- at least two meaningful fault cases
- safe remote command handling
- telemetry queueing through a comms outage
- replay after reconnect
- a clear operator-facing view
- readable documentation and tests

That is enough to make the project coherent, explainable, and portfolio-worthy.