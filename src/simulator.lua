--[[
    simulator.lua

  Simulate a real pump
]]

local Simulator = {}
Simulator.__index = Simulator

function Simulator.new(config)
    local self = setmetatable({}, Simulator)

    self.config = config

    self.state = {
        tank_level_pct = 100.0,
        suction_kpa = config.pressure.suction_idle_kpa,
        discharge_kpa = config.pressure.discharge_idle_kpa,
        flow_lpm = config.flow.idle_lpm,
        supply_voltage_v = config.voltage.nominal_v,

        pump_command = false,
        valve_command = false,

        pump_feedback = false,
        valve_feedback = false,

        pressure_target = config.pressure.discharge_running_kpa,
        network_online = true,
    }

    return self
end

function Simulator:update()
    local s = self.state
    local c = self.config

    s.pump_feedback = s.pump_command
    s.valve_feedback = s.valve_command

    if s.pump_feedback and s.valve_feedback then
        -- Normal pumping
        s.flow_lpm = c.flow.running_lpm
        s.suction_kpa = c.pressure.suction_running_kpa
        s.discharge_kpa = s.pressure_target

        s.tank_level_pct = math.max(
            0,
            s.tank_level_pct - c.tank.drain_per_tick_pct
        )

    elseif s.pump_feedback and not s.valve_feedback then
        -- Pump running against a closed valve / blocked line type behavior
        s.flow_lpm = 0
        s.suction_kpa = c.pressure.suction_running_kpa
        s.discharge_kpa = s.pressure_target + c.pressure.blocked_line_extra_kpa

    else
        -- Pump off
        s.flow_lpm = c.flow.idle_lpm
        s.suction_kpa = c.pressure.suction_idle_kpa
        s.discharge_kpa = c.pressure.discharge_idle_kpa
    end

    if s.pump_feedback then
        s.supply_voltage_v = c.voltage.running_v
    else
        s.supply_voltage_v = c.voltage.nominal_v
    end
end

function Simulator:set_pump_command(value)
    self.state.pump_command = value
end

function Simulator:set_valve_command(value)
    self.state.valve_command = value
end

function Simulator:set_pressure_target(value)
    self.state.pressure_target = value
end

function Simulator:set_network_online(value)
    self.state.network_online = value
end

function Simulator:get_snapshot()
    return self.state
end

return Simulator