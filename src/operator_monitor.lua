--[[
operator_monitor.lua


]]

local mqtt = require("mqtt")
local json = require("dkjson")
local config = require("config")

local client = mqtt.client{
    uri = config.mqtt.uri,
    clean = true,
    id = "pump-operator-monitor"
}

local view = {
    current_state = "UNKNOWN",
    state = {
        asset_id = config.mqtt.asset_id,
        state = "UNKNOWN",
        pump_feedback = false,
        valve_feedback = false,
        network_online = true
    },
    telemetry = {
        state = "UNKNOWN",
        tank_level_pct = 0,
        suction_kpa = 0,
        discharge_kpa = 0,
        flow_lpm = 0,
        supply_voltage_v = 0,
        pressure_target = 0,
        active_alarms = {}
    },
    recent_alarm_events = {},
    last_command_result = nil
}

local function merge_into(dst, src)
    for k, v in pairs(src) do
        dst[k] = v
    end
end

local function push_alarm_event(event)
    table.insert(view.recent_alarm_events, 1, event)
    while #view.recent_alarm_events > 10 do
        table.remove(view.recent_alarm_events)
    end
end

local function clear_screen()
    io.write("\27[2J\27[H")
end

local function format_alarm_ids(ids)
    if not ids or #ids == 0 then
        return "none"
    end
    return table.concat(ids, ", ")
end

local function render()
    clear_screen()

    print("=== Pump Operator Monitor ===")
    print("Asset: " .. tostring(view.state.asset_id or config.mqtt.asset_id))
    print("Current State: " .. tostring(view.current_state))
    print("Pump Running: " .. tostring(view.state.pump_feedback))
    print("Valve Open: " .. tostring(view.state.valve_feedback))
    print("Network Online: " .. tostring(view.state.network_online))
    print("")

    print("=== Telemetry ===")
    print(string.format("Tank Level:      %.1f %%", view.telemetry.tank_level_pct or 0))
    print(string.format("Suction:         %.1f kPa", view.telemetry.suction_kpa or 0))
    print(string.format("Discharge:       %.1f kPa", view.telemetry.discharge_kpa or 0))
    print(string.format("Flow:            %.1f L/min", view.telemetry.flow_lpm or 0))
    print(string.format("Supply Voltage:  %.1f V", view.telemetry.supply_voltage_v or 0))
    print(string.format("Pressure Target: %.1f kPa", view.telemetry.pressure_target or 0))
    print("Active Alarms:   " .. format_alarm_ids(view.telemetry.active_alarms))
    print("")

    print("=== Last Command Result ===")
    if view.last_command_result then
        print("Command:  " .. tostring(view.last_command_result.command))
        print("Accepted: " .. tostring(view.last_command_result.accepted))
        print("Reason:   " .. tostring(view.last_command_result.reason))
        print("State at response time: " .. tostring(view.last_command_result.state))
    else
        print("none")
    end
    print("")

    print("=== Recent Alarm Events ===")
    if #view.recent_alarm_events == 0 then
        print("none")
    else
        for _, event in ipairs(view.recent_alarm_events) do
            print(string.format(
                "[%s] %s %s (%s)",
                tostring(event.local_time),
                tostring(event.action),
                tostring(event.alarm_id),
                tostring(event.severity)
            ))
        end
    end
    print("")
end

client:on{
    connect = function(connack)
        if connack.rc ~= 0 then
            print("MQTT connection failed")
            return
        end

        print("Operator monitor connected")

        assert(client:subscribe{
            topic = config.mqtt.topics.state,
            qos = 0
        })

        assert(client:subscribe{
            topic = config.mqtt.topics.telemetry,
            qos = 0
        })

        assert(client:subscribe{
            topic = config.mqtt.topics.alarms,
            qos = 0
        })

        assert(client:subscribe{
            topic = config.mqtt.topics.command_result,
            qos = 0
        })
    end,

    message = function(msg)
        assert(client:acknowledge(msg))

        local data, _, err = json.decode(msg.payload, 1, nil)
        if err then
            print("JSON decode error on topic " .. tostring(msg.topic) .. ": " .. tostring(err))
            return
        end

        if msg.topic == config.mqtt.topics.state then
            merge_into(view.state, data)
            if data.state then
                view.current_state = data.state
            end

        elseif msg.topic == config.mqtt.topics.telemetry then
            merge_into(view.telemetry, data)
            if data.state then
                view.current_state = data.state
            end

        elseif msg.topic == config.mqtt.topics.alarms then
            data.local_time = os.date("%H:%M:%S")
            push_alarm_event(data)

        elseif msg.topic == config.mqtt.topics.command_result then
            view.last_command_result = data
        end

        render()
    end,

    error = function(err)
        print("MQTT error: " .. tostring(err))
    end,

    close = function()
        print("MQTT connection closed")
    end
}

print("Starting operator monitor...")
mqtt.run_ioloop(client)