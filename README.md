# Lua Remote Pump Monitor

A Lua-based pump station simulator that models pump operation, pump faults, MQTT telemetry, alarm notifications, and operator-issued remote commands.

This project simulates a remote pump monitoring and control system. It is designed to emulate the kind of workflow used in industrial remote asset monitoring:

- a pump and valve system runs locally in simulation
- plant variables such as flow, pressure, tank level, and voltage are updated over time
- system state is interpreted through a state machine
- faults are detected through an alarm engine
- telemetry, state, alarm events, and command results are published over MQTT
- operator commands are received over MQTT and applied through validated command logic

The goal of the project is to demonstrate a complete end-to-end remote monitoring and control loop in Lua.

---

## Features

### Plant simulation
- Simulated pump, valve, flow, pressure, tank level, and supply voltage
- Normal and abnormal operating behavior
- Pressure target support

### State machine
- `IDLE`
- `STARTING`
- `RUNNING`
- `WARNING`
- `FAULT`
- `LOCKOUT`

### Alarm engine
- `LOW_TANK_LEVEL`
- `NO_FLOW_WHILE_RUNNING`
- `OVERPRESSURE`
- `LOW_VOLTAGE`
- `COMMS_LOST`

### Remote commands
- `START_PUMP`
- `STOP_PUMP`
- `OPEN_VALVE`
- `CLOSE_VALVE`
- `SET_PRESSURE_TARGET`
- `ACK_ALARM`
- `RESET_FAULT`

### MQTT integration
- Publishes state
- Publishes telemetry
- Publishes alarm raise/clear events
- Publishes command results
- Subscribes for operator-issued commands

### Operator-side tools
- Terminal-based live operator monitor
- Simple command sender script

---

## Why this project exists

Many IoT demos stop at basic sensor logging or simple dashboards.

This project is intentionally more control-oriented. It focuses on the logic needed for a remotely monitored and remotely operated pump system:

- interpreting plant behavior into operating state
- distinguishing normal behavior from abnormal conditions
- validating operator commands before applying them
- publishing useful system information to an operator
- handling a full control loop through MQTT

---

## Architecture

The system follows this loop:

**pump simulation -> state machine -> alarm engine -> MQTT publish -> operator -> MQTT command -> command handler -> simulation**

### Main modules
- `simulator.lua`  
  Simulates the pump system and plant behavior

- `state_machine.lua`  
  Interprets raw plant values into operating states

- `alarms.lua`  
  Detects active abnormal conditions and emits raise/clear events

- `commands.lua`  
  Validates and applies operator-issued commands

- `mqtt_client.lua`  
  Handles MQTT publish/subscribe integration

- `operator_monitor.lua`  
  Displays live system status from MQTT topics

- `send_command.lua`  
  Sends one-shot operator commands over MQTT

---

## MQTT Topics

### Simulator publishes
- `pump/PUMP-001/state`
- `pump/PUMP-001/telemetry`
- `pump/PUMP-001/alarms`
- `pump/PUMP-001/command_result`

### Simulator subscribes
- `pump/PUMP-001/commands`

See `docs/mqtt-topics.md` for payload examples.

---

## Supported Commands

### `OPEN_VALVE`
Opens the valve if allowed.

### `CLOSE_VALVE`
Closes the valve.

### `START_PUMP`
Starts the pump if:
- system is not in `LOCKOUT`
- tank level is above start threshold
- no critical alarm blocks the start
- valve conditions satisfy your configured safety rules

### `STOP_PUMP`
Stops the pump.

### `SET_PRESSURE_TARGET`
Sets the discharge pressure target if within the allowed range.

### `ACK_ALARM`
Records alarm acknowledgement.

### `RESET_FAULT`
Requests reset from `LOCKOUT` if reset conditions are satisfied.

---

## Simulated Faults

The project currently supports detection of:

- low tank level
- low flow while running
- overpressure / blocked discharge behavior
- low voltage
- communications lost flag

However, not every fault has been implemented.

---

## Running the Project

### Requirements
- Lua
- LuaRocks
- Mosquitto broker
- Lua MQTT library
- JSON library for Lua

Example LuaRocks install:

```bash
luarocks install luasocket
luarocks install luamqtt
luarocks install dkjson
```

### Start the broker
On Fedora:

```bash
sudo systemctl start mosquitto
sudo systemctl status mosquitto --no-pager
```

### Run the simulator:

From `src/`:

```bash
lua main.lua
```

### Run the operator monitor

From `src/`:
```bash
lua operator_monitor.lua
```

### Send a command

From `src/`:
```bash
lua send_command.lua START_PUMP
```

>Note: You can also use an external MQTT Publisher with payload: **{"command":"START_PUMP"}**

---

## Repository Structure
```
lua-remote-pump-monitor/
- README.md
- DESIGN.md
- ROADMAP.md
- RESULTS.md
- docs/
   - images/
      - normal-startup.png
      - normal-stop.png
      - overpressure.png
      - lockout.png
- src/
   - alarms.lua
   - commands.lua
   - config.lua
   - main.lua
   - mqtt_client.lua
   - operator_monitor.lua
   - send_command.lua
   - simulator.lua
   - state_machine.lua
```

---

## Currently Status
### Features
- pump and valve simulation
- operating state interpretation
- alarm raise/clear logic
- safe remote command handling
- MQTT-based telemetry and command flow
- operator-side monitoring in Lua

### Currently in Progress

- Push notifications for faults (discord/node-red)
- Random fault occurence

### Future Features
- event persistence / logging
- multiple simulated pumps
- MQTT authentication and broker hardening