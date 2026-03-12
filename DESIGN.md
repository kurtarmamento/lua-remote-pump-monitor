# DESIGN.md

## Purpose

This document explains how the Lua Remote Pump Monitor is designed and how its major subsystems interact.

The project is not intended to be a full hydraulic simulation. It is a practical systems simulation built to demonstrate remote pump monitoring and control logic, fault detection, MQTT communication, and operator interaction.

---

## 1. System Overview

The project models a single remote pump station with:

- a pump
- a controllable valve
- a fluid source / tank level
- suction-side pressure
- discharge-side pressure
- flow rate
- supply voltage
- a communications status flag
- an operator communicating over MQTT

The project is designed around the following loop:

**plant simulation -> state machine -> alarm engine -> MQTT publish -> operator -> MQTT command -> command handler -> simulation**

---

## 2. Design Goals

The main design goals are:

- simulate believable pump system behavior
- distinguish plant state from alarm conditions
- support safe remote commands
- publish meaningful system information over MQTT
- provide a simple operator-side interface
- keep the system modular and easy to explain

---

## 3. Plant Model

The plant model is implemented in `simulator.lua`.

### Simulated variables
- `tank_level_pct`
- `suction_kpa`
- `discharge_kpa`
- `flow_lpm`
- `supply_voltage_v`
- `pump_command`
- `valve_command`
- `pump_feedback`
- `valve_feedback`
- `pressure_target`
- `network_online`

### Core plant assumptions
- If the pump is off, flow is near zero.
- If the valve is closed, flow is reduced or zero.
- If the pump is on and the valve is open, flow rises and discharge pressure follows the pressure target.
- If the pump runs, the tank level decreases over time.
- If the pump is running, supply voltage can dip relative to idle.
- If the pump runs against a closed valve, discharge pressure rises abnormally.

The simulator is intentionally simplified. The goal is deterministic operational behavior, not high-fidelity physical modeling.

---

## 4. Commanded vs Measured Variables

A key design principle is the distinction between:

### Commanded variables
Values requested by the control system:
- `pump_command`
- `valve_command`
- `pressure_target`

### Measured / feedback variables
Values representing what the plant is actually doing:
- `pump_feedback`
- `valve_feedback`
- flow, pressure, voltage, tank level

This distinction matters because remote control systems should not assume intent equals physical reality.

---

## 5. State Machine

The state machine is implemented in `state_machine.lua`.

Its responsibility is to interpret raw plant behavior into a meaningful operating state.

### States
- `IDLE`
- `STARTING`
- `RUNNING`
- `WARNING`
- `FAULT`
- `LOCKOUT`

### Meaning of each state

#### `IDLE`
Pump is not actively operating.

#### `STARTING`
Pump has been started but has not yet met the conditions for stable normal operation.

#### `RUNNING`
Pump is operating normally.

#### `WARNING`
The system is operating, but a noncritical abnormal condition is present.

#### `FAULT`
A critical abnormal condition has occurred.

#### `LOCKOUT`
A reset-requiring critical fault path has occurred, and restart is blocked until reset conditions are met.

### Important transition behavior
- `IDLE -> STARTING` when pump feedback becomes true
- `STARTING -> RUNNING` when flow, valve state, and startup time conditions are satisfied
- `RUNNING -> WARNING` when expected flow is lost without an immediate critical trip
- `RUNNING -> FAULT` when critical conditions such as overpressure occur
- `FAULT -> LOCKOUT` when the pump is stopped after a critical reset-requiring fault
- `LOCKOUT -> IDLE` only after valid reset logic is applied

### Reset-requiring fault concept
The state machine tracks whether a fault requires reset. This prevents normal operator stops from causing lockout while still allowing critical trips to force a reset path.

---

## 6. Alarm Engine

The alarm engine is implemented in `alarms.lua`.

Its responsibility is to answer:

**Which abnormal conditions are currently active?**

This is separate from the state machine, which answers:

**What operating mode is the system in?**

### Alarm behavior
Each alarm definition includes:
- alarm ID
- severity
- debounce requirement
- trigger condition
- clear condition

### Implemented alarms
- `LOW_TANK_LEVEL`
- `NO_FLOW_WHILE_RUNNING`
- `OVERPRESSURE`
- `LOW_VOLTAGE`
- `COMMS_LOST`

### Alarm design rules
- alarms use debounce to avoid flickering on transient inputs
- alarms have explicit clear conditions
- alarms are tracked independently of state
- alarm raise/clear transitions produce events for MQTT publication

### Why state and alarms are separate
A system can be:
- `RUNNING` with no alarms
- `RUNNING` with a warning alarm
- `FAULT` because of a critical alarm
- `LOCKOUT` after a reset-requiring fault sequence

This separation makes the design clearer and more realistic.

---

## 7. Command Handling

Command handling is implemented in `commands.lua`.

Its responsibility is to validate and apply operator-issued commands safely.

### Implemented commands
- `START_PUMP`
- `STOP_PUMP`
- `OPEN_VALVE`
- `CLOSE_VALVE`
- `SET_PRESSURE_TARGET`
- `ACK_ALARM`
- `RESET_FAULT`

### Command result structure
Each command produces a result containing:
- command name
- accepted / rejected status
- reason

### Command validation inputs
Command decisions depend on:
- current plant snapshot
- current state machine state
- current active alarms

### Example validation rules
- `START_PUMP` is rejected in `LOCKOUT`
- `START_PUMP` is rejected if tank level is below the start threshold
- `START_PUMP` may be rejected if valve conditions are unsafe
- `SET_PRESSURE_TARGET` is rejected if the value is outside the allowed range
- `RESET_FAULT` is rejected unless the system is in `LOCKOUT`, the pump is stopped, and reset conditions are satisfied

### Design intent
Remote commands are treated as requests, not direct authority over outputs.

---

## 8. MQTT Communication Model

MQTT integration is implemented in `mqtt_client.lua`.

The MQTT layer is responsible for moving information between the simulated device and the operator.

### Published topics
- `pump/PUMP-001/state`
- `pump/PUMP-001/telemetry`
- `pump/PUMP-001/alarms`
- `pump/PUMP-001/command_result`

### Subscribed topic
- `pump/PUMP-001/commands`

### Publish behavior
- state is published regularly
- telemetry is published regularly
- alarm raise/clear events are published immediately
- command results are published immediately after command processing

### Command flow
1. operator publishes command JSON to `pump/PUMP-001/commands`
2. simulator receives and decodes the message
3. command is passed to `commands.lua`
4. command result is published
5. updated state and telemetry are visible to the operator

### Payload design
Payloads are intentionally simple, small, and explicit:
- asset identifier
- command or alarm identifier
- state
- key plant values
- active alarm list where useful

---

## 9. Operator Side

The operator side is implemented with:
- `operator_monitor.lua`
- `send_command.lua`

### `operator_monitor.lua`
Subscribes to simulator topics and displays:
- current state
- pump/valve feedback
- latest telemetry
- active alarms
- recent alarm events
- last command result

### `send_command.lua`
Publishes one-shot operator commands over MQTT.

This separation mirrors the difference between:
- passive monitoring
- active remote control

---

## 10. Testing Strategy

The project is best tested using two approaches:

### Command-driven tests
Used for:
- normal startup/shutdown
- pressure target updates
- blocked discharge / overpressure
- reset flow

### Controlled fault injection
Used for:
- low tank
- low voltage
- communications lost
- isolated no-flow cases

This allows each fault path to be tested cleanly without forcing all faults to be generated only by commands.

---

## 11. Limitations

Current limitations include:
- single simulated pump asset only
- simplified physical model
- no persistence or event storage
- no authentication or broker hardening
- no graphical dashboard
- no hardware integration

These are acceptable limitations for version 1 because the project’s purpose is to demonstrate control and monitoring logic clearly.

---

## 12. Summary

The Lua Remote Pump Monitor is structured as a modular simulation of a remote pump monitoring and control system.

Its key design decisions are:
- separate state interpretation from alarm detection
- separate command validation from the plant model
- use MQTT as the operator/device communication layer
- keep the system simple enough to understand while still demonstrating realistic operational behavior

The project is intended to be readable, demonstrable, and useful as a portfolio example of industrial-style remote monitoring logic in Lua.