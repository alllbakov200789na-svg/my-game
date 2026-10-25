--!strict
-- Pure server-side envelope. Never derive allowances from replicated velocity/state.
local V = {}
local POSITION_SLACK = 6
local REPLICATION_SLACK = 0.35

export type State = {
	Y: number, At: number, StartAt: number, OriginY: number,
	Up: number, Down: number, Grounded: boolean,
	DescentY: number, DescentAt: number,
}

function V.new(y: number, now: number, jump: number, velocity: number?): State
	local speed = velocity or 0
	return { Y = y, At = now, StartAt = now, OriginY = y,
		Up = math.max(jump, speed), Down = math.max(0, -speed), Grounded = false,
		DescentY = y, DescentAt = now }
end

function V.check(s: State, y: number, now: number, grounded: boolean,
	jump: number, gravity: number, climbSpeed: number, horizontalDistance: number): (boolean, State?)
	local dt = math.max(0, now - s.At)
	local age = math.max(0, now - s.StartAt)
	local g = math.max(0, gravity)
	local up = math.max(jump, s.Up)
	local rise = up
	if grounded and s.Grounded then rise = math.max(rise, climbSpeed) end
	if y - s.Y > rise * (dt + REPLICATION_SLACK) + POSITION_SLACK then return false, nil end
	-- Falling speed grows with time in the air, including long falls and server stalls.
	local fall = s.Down + g * age
	if s.Y - y > fall * (dt + REPLICATION_SLACK) + POSITION_SLACK then return false, nil end
	local height = if g > 0 then up * up / (2 * g) else up * age
	if s.Grounded and grounded then
		-- Stairs/slopes need horizontal progress; a roof under a teleported player
		-- alone does not certify the vertical displacement that reached it.
		height = math.max(height, math.min(horizontalDistance * 2, climbSpeed * (dt + REPLICATION_SLACK)))
	end
	if y > s.OriginY + height + POSITION_SLACK then return false, nil end
	if grounded then
		local nextState = V.new(y, now, jump)
		nextState.Grounded = true
		return true, nextState
	end
	local nextState = table.clone(s)
	nextState.Y = y
	nextState.At = now
	nextState.Grounded = false
	-- Require downward progress after the jump/impulse apex. Unlike an exact
	-- ballistic curve this tolerates wall slides, collision and batched replication.
	if y <= s.DescentY - 3 then
		nextState.DescentY = y
		nextState.DescentAt = now
	elseif g > 0 and now - s.DescentAt > 2 + 2 * up / g then
		return false, nil
	end
	return true, nextState
end

return V
