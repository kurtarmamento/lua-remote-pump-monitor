# DESIGN.md

## Purpose

This document explains how the Lua Remote Pump Monitor is intended to work.

The focus is not only on what the system does, but on why each subsystem exists and how the pieces fit together.



## 1. System being modeled

The project models a remote pump station with the following components:

- a tank or water source
- a pump
- an outlet valve
- suction-side and discharge-side conditions
- flow through the line
- a power supply condition
- an intermittent communications link

This is not a fluid-dynamics simulator. It is a practical control and telemetry model designed to support:

- operational state detection
- alarm logic
- command validation
- transport behavior
- operator visibility



## 2. Core system loop

The system follows this logical loop:

**plant -> sensors -> edge logic -> alarms -> transport -> operator -> commands -> actuation -> plant**

### Plant
The physical or simulated process:
- water source level
- pump on/off condition
- valve open/closed condition
- resulting flow and pressure values

### Sensors
Measured signals exposed to the control logic:
- tank level
- suction pressure
- discharge pressure
- flow
- supply voltage
- pump feedback
- valve feedback
- network status

### Edge logic
The logic running locally on the device:
- state machine
- alarm evaluation
- command validation
- message generation
- offline buffering

### Operator layer
The remote monitoring/control side:
- current state view
- active alarms
- recent events
- command submission
- command result visibility



## 3. Signals and variables

### Measured variables
These represent what the device reads from the plant.

- `tank_level_pct`
- `suction_kpa`
- `discharge_kpa`
- `flow_lpm`
- `supply_voltage_v`
- `pump_feedback`
- `valve_feedback`
- `network_online`

### Commanded variables
These represent what the system requests.

- `pump_command`
- `valve_command`
- `pressure_target`

### Derived conditions
These are computed from the measured and commanded values.

Examples:
- pump running normally
- dry-run risk
- no-flow fault
- blocked discharge
- low-voltage condition
- communications loss



## 4. Important modeling principle

A core rule of the design is:

**command is not the same as feedback**

Examples:
- `pump_command = true` means the system wants the pump on
- `pump_feedback = true` means the pump is actually running

These may differ in real systems because of:
- startup delay
- fault condition
- interlocks
- actuator failure
- remote output success but physical non-response

This distinction is central to meaningful control and diagnostics.



## 5. State machine design

The project uses an explicit finite-state machine.

### Planned states
- `IDLE`
- `STARTING`
- `RUNNING`
- `WARNING`
- `FAULT`
- `LOCKOUT`

### State meanings

#### `IDLE`
The system is not actively pumping.

Typical indicators:
- pump off
- flow near zero
- pressures near idle range

#### `STARTING`
A valid start has been issued and the system is transitioning toward stable operation.

Typical indicators:
- pump command active
- pressures changing
- flow may not yet be stable

#### `RUNNING`
The system is pumping normally.

Typical indicators:
- pump feedback true
- valve open
- flow present
- pressure within expected operating range

#### `WARNING`
The system is still operating but a noncritical abnormality exists.

Examples:
- pressure trend drifting
- comms issue
- noncritical sensor anomaly

#### `FAULT`
A critical abnormality has occurred.

Examples:
- no flow while running
- overpressure
- low voltage shutdown condition
- dry-run risk

#### `LOCKOUT`
The system has been forced into a protected state and must be reset explicitly.

This is useful to prevent unsafe automatic restart behavior after critical faults.



## 6. Alarm engine design

The alarm engine is separate from the state machine.

This separation is intentional.

### Why alarms are separate
The state machine describes the operating mode.  
The alarm engine describes abnormal conditions.

A system can be:
- `RUNNING` with no alarms
- `RUNNING` with a warning alarm
- `FAULT` because of a critical alarm
- `LOCKOUT` after a critical event and forced stop

### Planned alarm structure
Each alarm definition should include:
- `id`
- `name`
- `severity`
- `condition`
- `debounce_s`
- `clear_condition`
- `suppress_repeat_s`

### Initial alarms
- `LOW_TANK_LEVEL`
- `NO_FLOW_WHILE_RUNNING`
- `OVERPRESSURE`
- `LOW_VOLTAGE`
- `COMMS_LOST`

### Alarm design rules
- alarms should not trigger instantly on transient noise
- alarms should have explicit clear conditions
- repeat notifications should be suppressed for a period
- alarm handling should be table-driven rather than scattered through `main.lua`



## 7. Command handling design

The project includes two-way command behavior.

### Planned commands
- `START_PUMP`
- `STOP_PUMP`
- `OPEN_VALVE`
- `CLOSE_VALVE`
- `SET_PRESSURE_TARGET`
- `ACK_ALARM`
- `RESET_FAULT`

### Command response model
Every command should produce a result that indicates:
- whether it was received
- whether it was accepted
- why it was rejected, if rejected
- what action was taken
- what state resulted afterward

### Safety rules
Command handling must not be implemented as unrestricted output toggling.

Examples of command rules:
- reject `START_PUMP` if tank level is below minimum
- reject `START_PUMP` in `LOCKOUT`
- reject certain actions while a critical fault is active
- force stop on severe alarm
- require fault reset before restart

This is a major distinction between a toy project and a control-oriented project.



## 8. Transport design

The transport layer is responsible for moving information between the edge system and the operator side.

### Planned message types
- heartbeat
- alarm event
- command response
- state snapshot

### Transport behavior rules
- send heartbeat periodically
- send alarm events immediately
- send command responses immediately
- queue messages while offline
- replay queued messages oldest-first on reconnect
- include timestamps and sequence numbers

### Why offline buffering matters
Remote systems must assume communications can be intermittent.

A robust edge device should:
- keep operating locally
- keep recording important events
- send them later when a path is available again



## 9. Plant behavior assumptions

The simulator uses simplified but meaningful relationships.

### Assumption examples
- if the pump is off, flow should be near zero
- if the valve is closed, flow should be low or zero
- if the pump is on and the valve is open, flow and discharge pressure should rise
- tank level decreases while pumping
- voltage may dip while the pump is active
- network availability is independent of pumping state

These rules are intentionally simple so the higher-level logic is easier to understand.



## 10. Initial scenarios

The design will support these scenarios:

### A. Normal run
- start pump
- open valve
- pressure rises
- flow stabilizes
- heartbeats continue

### B. Dry-run risk
- tank level falls too low
- pump must not continue
- alarm raised
- restart blocked until reset

### C. No-flow fault
- pump running
- valve or process condition prevents flow
- alarm raised
- system may transition to fault

### D. Overpressure
- discharge pressure exceeds acceptable threshold
- alarm raised
- stop action may be forced

### E. Communications outage
- link goes offline
- telemetry is queued
- reconnect occurs
- messages replay in order



## 11. Planned module responsibilities

### `config.lua`
Stores:
- thresholds
- timing constants
- default operating values
- alarm parameters

### `simulator.lua`
Models:
- tank level
- flow behavior
- pressure behavior
- pump and valve effects
- network state

### `state_machine.lua`
Determines:
- current operating state
- legal transitions
- transition rules

### `alarms.lua`
Evaluates:
- alarm conditions
- debounce timing
- clear conditions
- active alarm set

### `commands.lua`
Handles:
- command validation
- command execution
- rejection reasons
- reset logic

### `transport.lua`
Builds and sends:
- heartbeat messages
- alarm events
- command results
- state snapshots

### `storage.lua`
Stores:
- queued outbound messages
- event history
- sequence tracking if needed

### `main.lua`
Coordinates the modules and runs the main loop.



## 12. Non-goals for the first version

The first version is intentionally limited.

Not in scope initially:
- detailed hydraulic simulation
- real field hardware integration
- full production-grade communications stack
- advanced authentication/authorization model
- multi-asset fleet logic
- predictive maintenance modeling

Those can come later once the architecture is stable.


## 13. Definition of a good first version

A good first version should:

- behave consistently under a few key scenarios
- be modular enough to extend
- make the system logic easy to follow
- demonstrate sound engineering decisions
- be understandable by a reviewer reading the repo

Success is not “maximum features.”  
Success is “clear, correct, explainable behavior.”