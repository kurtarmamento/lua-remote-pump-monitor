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
        clear_margin_pct = 5,
        start_permit_level_pct = 25,
    },

    pressure = {
        suction_idle_kpa = 5,
        suction_running_kpa = 45,
        discharge_idle_kpa = 10,
        discharge_running_kpa = 220,
        blocked_line_extra_kpa = 30,
        clear_margin_kpa = 10,
        min_target_kpa = 150,
        max_target_kpa = 260,
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
        clear_margin_v = 0.3,
    },

    state_machine = {
        startup_ticks_required = 2,
        fault_discharge_kpa = 240,
    },

    alarms = {
        debounce_ticks = {
            low_tank = 2,
            no_flow = 2,
            overpressure = 1,
            low_voltage = 2,
            comms_lost = 1,
        }
    },

    mqtt = {
    uri = "127.0.0.1",
    client_id = "pump-sim-001",
    asset_id = "PUMP-001",

    topics = {
        state = "pump/PUMP-001/state",
        telemetry = "pump/PUMP-001/telemetry",
        alarms = "pump/PUMP-001/alarms",
        command_result = "pump/PUMP-001/command_result",
        commands = "pump/PUMP-001/commands"
    }
    }
}

return config