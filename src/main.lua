local config = require("config")
local Simulator = require("simulator")
local StateMachine = require("state_machine")
local AlarmEngine = require("alarms")
local CommandHandler = require("commands")

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

local function format_command_result(command_result)
    if not command_result then
        return "none"
    end

    return string.format(
        "%s -> accepted=%s, reason=%s",
        command_result.command,
        tostring(command_result.accepted),
        command_result.reason
    )
end

local function print_snapshot(label, tick, state_name, active_alarms, events, command_result, s)
    print(label .. " - Tick " .. tick)
    print(("  system_state:     %s"):format(state_name))
    print(("  active_alarms:    %s"):format(format_alarm_list(active_alarms)))
    print(("  alarm_events:     %s"):format(format_event_list(events)))
    print(("  command_result:   %s"):format(format_command_result(command_result)))
    print(("  tank_level_pct:   %.1f"):format(s.tank_level_pct))
    print(("  suction_kpa:      %.1f"):format(s.suction_kpa))
    print(("  discharge_kpa:    %.1f"):format(s.discharge_kpa))
    print(("  flow_lpm:         %.1f"):format(s.flow_lpm))
    print(("  supply_voltage_v: %.1f"):format(s.supply_voltage_v))
    print(("  pressure_target:  %.1f"):format(s.pressure_target))
    print(("  pump_feedback:    %s"):format(tostring(s.pump_feedback)))
    print(("  valve_feedback:   %s"):format(tostring(s.valve_feedback)))
    print(("  network_online:   %s"):format(tostring(s.network_online)))
    print("")
end

local function run_scenario(scenario)
    local sim = Simulator.new(config)
    local sm = StateMachine.new(config)
    local alarms = AlarmEngine.new(config)
    local commands = CommandHandler.new(config)

    scenario.setup(sim)

    for tick = 1, scenario.ticks do
        sim:update()
        local snapshot = sim:get_snapshot()

        if scenario.inject then
            scenario.inject(tick, snapshot, sim)
        end

        sm:update(snapshot)
        local state_name = sm:get_state()

        alarms:update(snapshot, state_name)
        local active_alarms = alarms:get_active_alarms()
        local events = alarms:get_recent_events()

        local command_result = nil
        if scenario.commands and scenario.commands[tick] then
            local cmd = scenario.commands[tick]
            command_result = commands:execute(
                cmd.name,
                cmd.payload,
                snapshot,
                state_name,
                active_alarms,
                sim,
                sm
            )

            sim:update()
            snapshot = sim:get_snapshot()

            sm:update(snapshot)
            state_name = sm:get_state()

            alarms:update(snapshot, state_name)
            active_alarms = alarms:get_active_alarms()
            events = alarms:get_recent_events()
        end

        print_snapshot(scenario.label, tick, state_name, active_alarms, events, command_result, snapshot)
    end
end

local scenarios = {
    {
        label = "Scenario A: Valid Start Command",
        ticks = 5,
        setup = function(sim)
            sim:set_pump_command(false)
            sim:set_valve_command(true)
        end,
        commands = {
            [1] = { name = "START_PUMP" },
        },
    },
    {
        label = "Scenario B: Start Rejected For Low Tank",
        ticks = 3,
        setup = function(sim)
            sim:set_pump_command(false)
            sim:set_valve_command(true)
        end,
        inject = function(tick, snapshot)
            snapshot.tank_level_pct = 18
        end,
        commands = {
            [1] = { name = "START_PUMP" },
        },
    },
    {
        label = "Scenario C: Pressure Target Updated",
        ticks = 4,
        setup = function(sim)
            sim:set_pump_command(true)
            sim:set_valve_command(true)
        end,
        commands = {
            [2] = { name = "SET_PRESSURE_TARGET", payload = { value = 210 } },
        },
    },
    {
        label = "Scenario D: Valve Open Rejected During Critical Fault",
        ticks = 4,
        setup = function(sim)
            sim:set_pump_command(true)
            sim:set_valve_command(false)
        end,
        commands = {
            [2] = { name = "OPEN_VALVE" },
        },
    },
    {
        label = "Scenario E: Reset After Fault Lockout",
        ticks = 6,
        setup = function(sim)
            sim:set_pump_command(true)
            sim:set_valve_command(false)
        end,
        commands = {
            [2] = { name = "STOP_PUMP" },
            [4] = { name = "RESET_FAULT" },
        },
    },
}

for _, scenario in ipairs(scenarios) do
    run_scenario(scenario)
end