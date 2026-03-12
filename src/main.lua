--[[
main.lua

Run the simulator
]]

local config = require("config")
local Simulator = require("simulator")
local StateMachine = require("state_machine")

local function print_snapshot(label, tick, state_name, s)
    print(label .. " - Tick " .. tick)
    print(("  system_state:     %s"):format(state_name))
    print(("  tank_level_pct:   %.1f"):format(s.tank_level_pct))
    print(("  suction_kpa:      %.1f"):format(s.suction_kpa))
    print(("  discharge_kpa:    %.1f"):format(s.discharge_kpa))
    print(("  flow_lpm:         %.1f"):format(s.flow_lpm))
    print(("  supply_voltage_v: %.1f"):format(s.supply_voltage_v))
    print(("  pump_command:     %s"):format(tostring(s.pump_command)))
    print(("  pump_feedback:    %s"):format(tostring(s.pump_feedback)))
    print(("  valve_command:    %s"):format(tostring(s.valve_command)))
    print(("  valve_feedback:   %s"):format(tostring(s.valve_feedback)))
    print(("  network_online:   %s"):format(tostring(s.network_online)))
    print("")
end

local function run_scenario(label, pump_on, valve_open, ticks)
    local sim = Simulator.new(config)
    local sm = StateMachine.new(config)

    sim:set_pump_command(pump_on)
    sim:set_valve_command(valve_open)

    for tick = 1, ticks do
        sim:update()
        local snapshot = sim:get_snapshot()
        sm:update(snapshot)

        print_snapshot(label, tick, sm:get_state(), snapshot)
    end
end

run_scenario("Scenario A: Pump OFF, Valve CLOSED", false, false, 3)
run_scenario("Scenario B: Pump ON, Valve OPEN", true, true, 5)
run_scenario("Scenario C: Pump ON, Valve CLOSED", true, false, 5)