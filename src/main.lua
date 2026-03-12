--[[
main.lua

Main loop
]]

local socket = require("socket")
local mqtt = require("mqtt")

local config = require("config")
local Simulator = require("simulator")
local StateMachine = require("state_machine")
local AlarmEngine = require("alarms")
local CommandHandler = require("commands")
local MqttClient = require("mqtt_client")

local sim = Simulator.new(config)
local sm = StateMachine.new(config)
local alarms = AlarmEngine.new(config)
local commands = CommandHandler.new(config)
local mqttc = MqttClient.new(config)

local tick_count = 0
local last_tick_at = socket.gettime()

local current_snapshot = sim:get_snapshot()
local current_state = sm:get_state()
local current_active_alarms = {}

local function recompute()
    current_snapshot = sim:get_snapshot()

    sm:update(current_snapshot)
    current_state = sm:get_state()

    alarms:update(current_snapshot, current_state)
    current_active_alarms = alarms:get_active_alarms()

    return alarms:get_recent_events()
end

local function publish_alarm_events(events)
    for _, event in ipairs(events.raised) do
        mqttc:publish_alarm_event(event, "RAISED")
    end

    for _, event in ipairs(events.cleared) do
        mqttc:publish_alarm_event(event, "CLEARED")
    end
end

local function process_incoming_commands()
    local queued = mqttc:pop_pending_commands()

    for _, cmd in ipairs(queued) do
        local command_name = cmd.command
        local payload = cmd.payload or {}

        if not command_name then
            print("Ignoring command without `command` field")
        else
            local result = commands:execute(
                command_name,
                payload,
                current_snapshot,
                current_state,
                current_active_alarms,
                sim,
                sm
            )

            -- Apply one plant update after command so result is reflected in state/telemetry
            sim:update()
            recompute()

            mqttc:publish_command_result(result, current_state)
            mqttc:publish_state(current_snapshot, current_state)
            mqttc:publish_telemetry(current_snapshot, current_state, current_active_alarms)

            print(string.format(
                "Command processed: %s accepted=%s reason=%s",
                result.command,
                tostring(result.accepted),
                tostring(result.reason)
            ))
        end
    end
end

local function inject_demo_faults(snapshot, tick)
    -- Optional demo hooks. Uncomment one at a time.

    -- Low tank after 15 ticks:
    -- if tick >= 15 then
    --     snapshot.tank_level_pct = 18
    -- end

    -- Low voltage after 25 ticks:
    -- if tick >= 25 then
    --     snapshot.supply_voltage_v = 11.2
    -- end

    -- Simulate blocked discharge after 35 ticks:
    -- if tick >= 35 then
    --     sim:set_valve_command(false)
    -- end
end

local function simulation_loop()
    -- Always process inbound MQTT commands as soon as they arrive
    process_incoming_commands()

    local now = socket.gettime()
    if (now - last_tick_at) < config.tick_seconds then
        return
    end

    last_tick_at = now
    tick_count = tick_count + 1

    sim:update()
    current_snapshot = sim:get_snapshot()

    inject_demo_faults(current_snapshot, tick_count)

    local events = recompute()

    mqttc:publish_state(current_snapshot, current_state)

    if tick_count % 3 == 0 then
        mqttc:publish_telemetry(current_snapshot, current_state, current_active_alarms)
    end

    publish_alarm_events(events)

    print(string.format(
        "Tick=%d state=%s flow=%.1f discharge=%.1f tank=%.1f alarms=%d",
        tick_count,
        current_state,
        current_snapshot.flow_lpm,
        current_snapshot.discharge_kpa,
        current_snapshot.tank_level_pct,
        #current_active_alarms
    ))
end

-- Seed initial view before the broker loop starts
recompute()

print("Starting MQTT + simulation loop")
-- luamqtt documents that run_ioloop can run MQTT clients and custom loop functions together.
mqtt.run_ioloop(mqttc.client, simulation_loop)