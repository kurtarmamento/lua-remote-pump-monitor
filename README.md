# Lua Remote Pump Monitor

A Lua-based remote pump telemetry and control simulator inspired by industrial remote-asset monitoring workflows.

This project models a remote pump station and demonstrates how an edge device can:

- read simulated pump and site signals
- determine operational state
- raise and clear alarms
- validate and apply remote commands
- queue telemetry during communications outages
- replay queued telemetry when connectivity returns

The aim is to learn how a remote pump monitoring system works from the inside out, starting with the plant model and progressing through state logic, alarms, commands, transport behavior, and operator visibility.

---

## Why this project exists

Many IoT demos stop at simple sensor logging. This project is intentionally different.

It focuses on the kinds of behaviors that matter in remote industrial systems:

- state interpretation instead of raw values only
- fault detection instead of simple threshold printing
- safe command handling instead of direct output toggling
- store-and-forward telemetry instead of assuming perfect connectivity
- operator-facing visibility instead of device-only output

---

## Project goals

By the end of the first version, the system should be able to:

- simulate a pump station with tank level, flow, suction pressure, discharge pressure, valve state, and power state
- model normal and abnormal operating conditions
- track the asset through explicit operating states
- raise alarms with debounce and clear conditions
- accept remote commands and reject unsafe ones
- produce heartbeats, alarm events, and command responses
- buffer messages locally while offline
- replay messages in order after reconnect

---

## Planned features

### Plant and telemetry model
- tank level
- suction pressure
- discharge pressure
- flow rate
- power / supply voltage
- pump state
- valve state
- network status

### State machine
- `IDLE`
- `STARTING`
- `RUNNING`
- `WARNING`
- `FAULT`
- `LOCKOUT`

### Alarm engine
- low tank level
- no flow while running
- overpressure
- low voltage
- communications lost
- additional derived faults later

### Remote commands
- `START_PUMP`
- `STOP_PUMP`
- `OPEN_VALVE`
- `CLOSE_VALVE`
- `SET_PRESSURE_TARGET`
- `ACK_ALARM`
- `RESET_FAULT`

### Transport behavior
- periodic heartbeat
- event-driven alarm messages
- command acknowledgement and result
- offline queueing
- ordered replay on reconnect

---

## Repository structure

```text
lua-remote-pump-monitor/
├─ README.md
├─ DESIGN.md
├─ ROADMAP.md
├─ RESULTS.md
├─ LICENSE
├─ docs/
│  ├─ architecture.md
│  ├─ alarm-matrix.md
│  ├─ command-protocol.md
│  └─ demo-scenarios.md
├─ src/
│  ├─ config.lua
│  ├─ simulator.lua
│  ├─ state_machine.lua
│  ├─ alarms.lua
│  ├─ commands.lua
│  ├─ transport.lua
│  ├─ storage.lua
│  └─ main.lua
├─ backend/
│  ├─ viewer.py
│  ├─ api.py
│  └─ data/
├─ examples/
│  ├─ telemetry_samples.json
│  ├─ command_samples.json
│  └─ alarm_samples.json
└─ tests/
   ├─ test_state_machine.lua
   ├─ test_alarm_logic.lua
   ├─ test_command_rules.lua
   └─ test_queue_replay.lua