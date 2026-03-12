-- state_machine.lua
-- Returns state for current simulation state

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new(config)
    local self = setmetatable({}, StateMachine)

    self.config = config
    self.current_state = "IDLE"
    self.starting_ticks = 0
    self.reset_requested = false
    self.fault_requires_reset = false

    return self
end

function StateMachine:get_state()
    return self.current_state
end

function StateMachine:request_reset()
    self.reset_requested = true
end

function StateMachine:update(snapshot)
    local c = self.config
    local state = self.current_state

    local pump_on = snapshot.pump_feedback
    local valve_open = snapshot.valve_feedback
    local flow_ok = snapshot.flow_lpm >= c.flow.running_threshold_lpm
    local high_pressure_fault = snapshot.discharge_kpa >= c.state_machine.fault_discharge_kpa

    if state == "IDLE" then
        if pump_on then
            self.current_state = "STARTING"
            self.starting_ticks = 1
        end

    elseif state == "STARTING" then
        if not pump_on then
            self.current_state = "IDLE"
            self.starting_ticks = 0

        elseif high_pressure_fault then
            self.current_state = "FAULT"
            self.fault_requires_reset = true

        else
            self.starting_ticks = self.starting_ticks + 1

            if flow_ok and valve_open and self.starting_ticks >= c.state_machine.startup_ticks_required then
                self.current_state = "RUNNING"
            end
        end

    elseif state == "RUNNING" then
        if not pump_on then
            self.current_state = "IDLE"

        elseif high_pressure_fault then
            self.current_state = "FAULT"
            self.fault_requires_reset = true

        elseif not flow_ok then
            self.current_state = "WARNING"
        end

    elseif state == "WARNING" then
        if not pump_on then
            self.current_state = "IDLE"

        elseif high_pressure_fault then
            self.current_state = "FAULT"
            self.fault_requires_reset = true

        elseif flow_ok and valve_open then
            self.current_state = "RUNNING"
        end

    elseif state == "FAULT" then
        if not pump_on then
            if self.fault_requires_reset then
                self.current_state = "LOCKOUT"
            else
                self.current_state = "IDLE"
            end
        end

    elseif state == "LOCKOUT" then
        if self.reset_requested and not pump_on then
            self.current_state = "IDLE"
            self.starting_ticks = 0
            self.fault_requires_reset = false
        end
    end

    self.reset_requested = false
end

return StateMachine