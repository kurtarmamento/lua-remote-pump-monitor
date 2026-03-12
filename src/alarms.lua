-- alarms.lua
-- Handles alarms given the current state

local AlarmEngine = {}
AlarmEngine.__index = AlarmEngine

function AlarmEngine.new(config)
    local self = setmetatable({}, AlarmEngine)

    self.config = config
    self.events = {
        raised = {},
        cleared = {},
    }

    self.definitions = {
        {
            id = "LOW_TANK_LEVEL",
            severity = "WARNING",
            debounce_ticks = config.alarms.debounce_ticks.low_tank,
            trigger = function(snapshot, state_name, c)
                return snapshot.tank_level_pct <= c.tank.min_level_pct
            end,
            clear = function(snapshot, state_name, c)
                return snapshot.tank_level_pct > (c.tank.min_level_pct + c.tank.clear_margin_pct)
            end,
        },
        {
            id = "NO_FLOW_WHILE_RUNNING",
            severity = "CRITICAL",
            debounce_ticks = config.alarms.debounce_ticks.no_flow,
            trigger = function(snapshot, state_name, c)
                return snapshot.pump_feedback
                    and snapshot.flow_lpm < c.flow.running_threshold_lpm
                    and snapshot.discharge_kpa < c.state_machine.fault_discharge_kpa
            end,
            clear = function(snapshot, state_name, c)
                return (not snapshot.pump_feedback)
                    or snapshot.flow_lpm >= c.flow.running_threshold_lpm
            end,
        },
        {
            id = "OVERPRESSURE",
            severity = "CRITICAL",
            debounce_ticks = config.alarms.debounce_ticks.overpressure,
            trigger = function(snapshot, state_name, c)
                return snapshot.discharge_kpa >= c.state_machine.fault_discharge_kpa
            end,
            clear = function(snapshot, state_name, c)
                return snapshot.discharge_kpa < (c.state_machine.fault_discharge_kpa - c.pressure.clear_margin_kpa)
            end,
        },
        {
            id = "LOW_VOLTAGE",
            severity = "WARNING",
            debounce_ticks = config.alarms.debounce_ticks.low_voltage,
            trigger = function(snapshot, state_name, c)
                return snapshot.supply_voltage_v <= c.voltage.low_v
            end,
            clear = function(snapshot, state_name, c)
                return snapshot.supply_voltage_v > (c.voltage.low_v + c.voltage.clear_margin_v)
            end,
        },
        {
            id = "COMMS_LOST",
            severity = "WARNING",
            debounce_ticks = config.alarms.debounce_ticks.comms_lost,
            trigger = function(snapshot, state_name, c)
                return snapshot.network_online == false
            end,
            clear = function(snapshot, state_name, c)
                return snapshot.network_online == true
            end,
        },
    }

    self.runtime = {}
    for _, def in ipairs(self.definitions) do
        self.runtime[def.id] = {
            active = false,
            debounce_count = 0,
        }
    end

    return self
end

function AlarmEngine:update(snapshot, state_name)
    self.events = {
        raised = {},
        cleared = {},
    }

    for _, def in ipairs(self.definitions) do
        local rt = self.runtime[def.id]
        local triggered = def.trigger(snapshot, state_name, self.config)

        if rt.active then
            if def.clear(snapshot, state_name, self.config) then
                rt.active = false
                rt.debounce_count = 0
                table.insert(self.events.cleared, {
                    id = def.id,
                    severity = def.severity,
                })
            end
        else
            if triggered then
                rt.debounce_count = rt.debounce_count + 1

                if rt.debounce_count >= def.debounce_ticks then
                    rt.active = true
                    rt.debounce_count = 0
                    table.insert(self.events.raised, {
                        id = def.id,
                        severity = def.severity,
                    })
                end
            else
                rt.debounce_count = 0
            end
        end
    end
end

function AlarmEngine:get_active_alarms()
    local active = {}

    for _, def in ipairs(self.definitions) do
        local rt = self.runtime[def.id]
        if rt.active then
            table.insert(active, {
                id = def.id,
                severity = def.severity,
            })
        end
    end

    return active
end

function AlarmEngine:get_recent_events()
    return self.events
end

return AlarmEngine