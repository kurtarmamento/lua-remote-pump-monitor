--[[
main.lua

Run the simulator
]]

local config = require("config")
local Simulator = require("simulator")
local StateMachine = require("state_machine")
local AlarmEngine = require("alarms")

local function format_alarm_list(active_alarms)
    if #active_alarms == 0 then
        return "none"
    end

    local parts = {}
    for _, alarm in ipairs(active_alarms) do
        table.insert(parts, alarm.id .. " (" .. alarm.severity .. ")")
    end

    return table.concat(parts, ", ")
end

local function format_event_list(events)
    local parts = {}

    for _, event in ipairs(events.raised) do
        table.insert(parts, "RAISED: " .. event.id)
    end

    for _, event in ipairs(events.cleared) do
        table.insert(parts, "CLEARED: " .. event.id)
    end

    if #parts == 0 then
        return "none"
    end

    return table.concat(parts, ", ")
end

local function print_snapshot(label, tick, state_name, active_alarms, events, s)
    print(label .. " - Tick " .. tick)
    print(("  system_state:     %s"):format(state_name))
    print(("  active_alarms:    %s"):format(format_alarm_list(active_alarms)))
    print(("  alarm_events:     %s"):format(format_event_list(events)))
    print(("  tank_level_pct:   %.1f"):format(s.tank_level_pct))
    print(("  suction_kpa:      %.1f"):format(s.suction_kpa))
    print(("  discharge_kpa:    %.1f"):format(s.discharge_kpa))
    print(("  flow_lpm:         %.1f"):format(s.flow_lpm))
    print(("  supply_voltage_v: %.1f"):format(s.supply_voltage_v))
    print(("  pump_feedback:    %s"):format(tostring(s.pump_feedback)))
    print(("  valve_feedback:   %s"):format(tostring(s.valve_feedback)))
    print(("  network_online:   %s"):format(tostring(s.network_online)))
    print("")
end

local function run_scenario(scenario)
    local sim = Simulator.new(config)
    local sm = StateMachine.new(config)
    local alarms = AlarmEngine.new(config)

    scenario.setup(sim)

    for tick = 1, scenario.ticks do
        sim:update()
        local snapshot = sim:get_snapshot()

        if scenario.inject then
            scenario.inject(tick, snapshot)
        end

        sm:update(snapshot)
        local state_name = sm:get_state()

        alarms:update(snapshot, state_name)
        local active_alarms = alarms:get_active_alarms()
        local events = alarms:get_recent_events()

        print_snapshot(scenario.label, tick, state_name, active_alarms, events, snapshot)
    end
end

local scenarios = {
    {
        label = "Scenario A: Normal Run",
        ticks = 5,
        setup = function(sim)
            sim:set_pump_command(true)
            sim:set_valve_command(true)
        end,
    },
    {
        label = "Scenario B: Low Tank Warning",
        ticks = 4,
        setup = function(sim)
            sim:set_pump_command(true)
            sim:set_valve_command(true)
        end,
        inject = function(tick, snapshot)
            snapshot.tank_level_pct = 18
        end,
    },
    {
        label = "Scenario C: Blocked Discharge Fault",
        ticks = 4,
        setup = function(sim)
            sim:set_pump_command(true)
            sim:set_valve_command(false)
        end,
    },
    {
        label = "Scenario D: Communications Lost",
        ticks = 3,
        setup = function(sim)
            sim:set_pump_command(false)
            sim:set_valve_command(false)
        end,
        inject = function(tick, snapshot)
            snapshot.network_online = false
        end,
    },
    {
        label = "Scenario E: Low Voltage",
        ticks = 4,
        setup = function(sim)
            sim:set_pump_command(true)
            sim:set_valve_command(true)
        end,
        inject = function(tick, snapshot)
            snapshot.supply_voltage_v = 11.2
        end,
    },
}

for _, scenario in ipairs(scenarios) do
    run_scenario(scenario)
end