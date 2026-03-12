--[[
config.lua

Holds adjustable parameters simulating a real pump system
]]

local config = {
    tick_seconds = 1,

    tank = {
        min_level_pct = 20,
        max_level_pct = 100,
        drain_per_tick_pct = 0.8,
    },

    pressure = {
        suction_idle_kpa = 5,
        suction_running_kpa = 45,
        discharge_idle_kpa = 10,
        discharge_running_kpa = 220,
        blocked_line_extra_kpa = 30,
    },

    flow = {
        idle_lpm = 0,
        running_lpm = 180,
        running_threshold_lpm = 50,
    },

    voltage = {
        nominal_v = 12.5,
        running_v = 12.2,
        low_v = 11.5,
    },

    state_machine = {
        startup_ticks_required = 2,
        fault_discharge_kpa = 240,
    }

}

return config