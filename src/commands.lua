--[[
commands.lua

Handles commands made to alter pump behaviour
]]

local CommandHandler = {}
CommandHandler.__index = CommandHandler

local function has_active_critical_alarm(active_alarms)
    for _, alarm in ipairs(active_alarms) do
        if alarm.severity == "CRITICAL" then
            return true, alarm.id
        end
    end
    return false, nil
end

function CommandHandler.new(config)
    local self = setmetatable({}, CommandHandler)
    self.config = config
    return self
end

function CommandHandler:execute(command_name, payload, snapshot, state_name, active_alarms, sim, state_machine)
    payload = payload or {}

    local critical_active, critical_alarm_id = has_active_critical_alarm(active_alarms)

    local result = {
        command = command_name,
        accepted = false,
        reason = nil,
    }

    if command_name == "START_PUMP" then
        if state_name == "LOCKOUT" then
            result.reason = "system is in LOCKOUT"
            return result
        end

        if snapshot.tank_level_pct < self.config.tank.start_permit_level_pct then
            result.reason = "tank level below start permit threshold"
            return result
        end

        if critical_active then
            result.reason = "critical alarm active: " .. critical_alarm_id
            return result
        end

        sim:set_pump_command(true)
        result.accepted = true
        result.reason = "pump start command applied"
        return result

    elseif command_name == "STOP_PUMP" then
        sim:set_pump_command(false)
        result.accepted = true
        result.reason = "pump stop command applied"
        return result

    elseif command_name == "OPEN_VALVE" then
        if state_name == "LOCKOUT" then
            result.reason = "system is in LOCKOUT"
            return result
        end

        if critical_active then
            result.reason = "critical alarm active: " .. critical_alarm_id
            return result
        end

        sim:set_valve_command(true)
        result.accepted = true
        result.reason = "valve open command applied"
        return result

    elseif command_name == "CLOSE_VALVE" then
        sim:set_valve_command(false)
        result.accepted = true
        result.reason = "valve close command applied"
        return result

    elseif command_name == "SET_PRESSURE_TARGET" then
        local value = payload.value

        if type(value) ~= "number" then
            result.reason = "pressure target must be numeric"
            return result
        end

        if value < self.config.pressure.min_target_kpa or value > self.config.pressure.max_target_kpa then
            result.reason = "pressure target outside allowed range"
            return result
        end

        sim:set_pressure_target(value)
        result.accepted = true
        result.reason = "pressure target updated"
        return result

    elseif command_name == "ACK_ALARM" then
        result.accepted = true
        result.reason = "alarm acknowledgement recorded"
        return result

    elseif command_name == "RESET_FAULT" then
        if state_name ~= "LOCKOUT" then
            result.reason = "reset only allowed from LOCKOUT"
            return result
        end

        if snapshot.pump_feedback then
            result.reason = "pump must be stopped before reset"
            return result
        end

        if critical_active then
            result.reason = "critical alarm still active: " .. critical_alarm_id
            return result
        end

        state_machine:request_reset()
        result.accepted = true
        result.reason = "fault reset requested"
        return result
    end

    result.reason = "unknown command"
    return result
end

return CommandHandler