--[[
mqtt_client.lua

Handle mqtt
]]

local mqtt = require("mqtt")
local json = require("dkjson")

local MqttClient = {}
MqttClient.__index = MqttClient

function MqttClient.new(config)
    local self = setmetatable({}, MqttClient)

    self.config = config
    self.connected = false
    self.pending_commands = {}

    self.client = mqtt.client{
        uri = config.mqtt.uri,
        clean = true,
        id = config.mqtt.client_id
    }

    self.client:on{
        connect = function(connack)
            if connack.rc ~= 0 then
                print("MQTT connection failed: " .. tostring(connack:reason_string()))
                return
            end

            self.connected = true
            print("MQTT connected")

            assert(self.client:subscribe{
                topic = self.config.mqtt.topics.commands,
                qos = 1,
                callback = function()
                    print("Subscribed to " .. self.config.mqtt.topics.commands)
                end
            })
        end,

        message = function(msg)
            assert(self.client:acknowledge(msg))

            local topic = msg.topic
            local payload = msg.payload

            if topic ~= self.config.mqtt.topics.commands then
                return
            end

            local decoded, _, err = json.decode(payload, 1, nil)
            if err then
                print("Invalid command JSON: " .. tostring(err))
                return
            end

            table.insert(self.pending_commands, decoded)
        end,

        error = function(err)
            print("MQTT client error: " .. tostring(err))
        end,

        close = function()
            self.connected = false
            print("MQTT connection closed")
        end
    }

    return self
end

function MqttClient:is_connected()
    return self.connected
end

function MqttClient:pop_pending_commands()
    local cmds = self.pending_commands
    self.pending_commands = {}
    return cmds
end

function MqttClient:_publish_table(topic, tbl, qos)
    if not self.connected then
        return false, "not connected"
    end

    local payload, err = json.encode(tbl)
    if not payload then
        return false, err or "json encode failed"
    end

    local ok = self.client:publish{
        topic = topic,
        payload = payload,
        qos = qos or 0
    }

    return ok
end

function MqttClient:publish_state(snapshot, state_name)
    return self:_publish_table(self.config.mqtt.topics.state, {
        asset_id = self.config.mqtt.asset_id,
        state = state_name,
        pump_feedback = snapshot.pump_feedback,
        valve_feedback = snapshot.valve_feedback,
        network_online = snapshot.network_online
    }, 0)
end

function MqttClient:publish_telemetry(snapshot, state_name, active_alarms)
    local alarm_ids = {}
    for _, alarm in ipairs(active_alarms) do
        table.insert(alarm_ids, alarm.id)
    end

    return self:_publish_table(self.config.mqtt.topics.telemetry, {
        asset_id = self.config.mqtt.asset_id,
        state = state_name,
        tank_level_pct = snapshot.tank_level_pct,
        suction_kpa = snapshot.suction_kpa,
        discharge_kpa = snapshot.discharge_kpa,
        flow_lpm = snapshot.flow_lpm,
        supply_voltage_v = snapshot.supply_voltage_v,
        pressure_target = snapshot.pressure_target,
        active_alarms = alarm_ids
    }, 0)
end

function MqttClient:publish_alarm_event(event, action)
    return self:_publish_table(self.config.mqtt.topics.alarms, {
        asset_id = self.config.mqtt.asset_id,
        alarm_id = event.id,
        severity = event.severity,
        action = action
    }, 0)
end

function MqttClient:publish_command_result(command_result, state_name)
    return self:_publish_table(self.config.mqtt.topics.command_result, {
        asset_id = self.config.mqtt.asset_id,
        command = command_result.command,
        accepted = command_result.accepted,
        reason = command_result.reason,
        state = state_name
    }, 0)
end

return MqttClient