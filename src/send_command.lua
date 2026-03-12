--[[
send_command.lua

]]

local mqtt = require("mqtt")
local json = require("dkjson")
local config = require("config")

local command_name = arg[1]

if not command_name then
    print("Usage:")
    print("  lua send_command.lua START_PUMP")
    print("  lua send_command.lua STOP_PUMP")
    print("  lua send_command.lua OPEN_VALVE")
    print("  lua send_command.lua CLOSE_VALVE")
    print("  lua send_command.lua RESET_FAULT")
    print("  lua send_command.lua ACK_ALARM")
    print("  lua send_command.lua SET_PRESSURE_TARGET 210")
    os.exit(1)
end

local payload = nil

if command_name == "SET_PRESSURE_TARGET" then
    local value = tonumber(arg[2])
    if not value then
        print("SET_PRESSURE_TARGET requires a numeric value")
        os.exit(1)
    end
    payload = { value = value }
end

local body = {
    command = command_name
}

if payload then
    body.payload = payload
end

local encoded, err = json.encode(body)
if not encoded then
    print("Failed to encode command JSON: " .. tostring(err))
    os.exit(1)
end

local client = mqtt.client{
    uri = config.mqtt.uri,
    clean = true,
    id = "pump-command-sender"
}

client:on{
    connect = function(connack)
        if connack.rc ~= 0 then
            print("MQTT connection failed")
            os.exit(1)
        end

        print("Connected. Sending command: " .. command_name)

        assert(client:publish{
            topic = config.mqtt.topics.commands,
            payload = encoded,
            qos = 1,
            callback = function()
                print("Command published successfully")
                os.exit(0)
            end
        })
    end,

    error = function(e)
        print("MQTT error: " .. tostring(e))
        os.exit(1)
    end,

    close = function()
        print("MQTT connection closed")
    end
}

mqtt.run_ioloop(client)