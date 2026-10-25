--!strict
-- All player roles use the same unscaled R15 rig. Validate walking routes,
-- not routes that require a particular ability, jumping or breaking a door.
local Pathfinding = game:GetService("PathfindingService")
local Safety = {}
local BODY_SIZE = Vector3.new(4, 7, 4)
local OFFSETS = {Vector3.zero, Vector3.new(1.5, 0, 1.5), Vector3.new(-1.5, 0, 1.5),
	Vector3.new(1.5, 0, -1.5), Vector3.new(-1.5, 0, -1.5)}

export type Context = {
	Map: Model, Radius: number, Ray: RaycastParams, Overlap: OverlapParams,
	Anchor: CFrame, Reserved: {Vector3}, Goals: {Vector3},
}

function Safety.Ground(ctx: Context, requested: CFrame): CFrame?
	local pos = requested.Position
	if math.abs(pos.X) > ctx.Radius - 3 or math.abs(pos.Z) > ctx.Radius - 3 then return nil end
	local hit = workspace:Raycast(pos, Vector3.new(0, -12, 0), ctx.Ray)
	-- Do not snap onto a low awning/roof intersecting the intended character.
	if not hit or hit.Normal.Y < 0.8 or pos.Y - hit.Position.Y < 2 then return nil end
	local floorY = hit.Position.Y
	for _,offset in ipairs(OFFSETS) do
		local support = workspace:Raycast(Vector3.new(pos.X, floorY + 2, pos.Z) + offset,
			Vector3.new(0, -4, 0), ctx.Ray)
		if not support or support.Normal.Y < 0.8 or math.abs(support.Position.Y - floorY) > 0.5 then return nil end
	end
	-- Includes standing clearance and the short drop after placement (root at floor + 4).
	local box = CFrame.new(pos.X, floorY + 3.75, pos.Z)
	if #workspace:GetPartBoundsInBox(box, BODY_SIZE, ctx.Overlap) > 0 then return nil end
	return CFrame.new(pos.X, floorY + 4, pos.Z) * requested.Rotation
end

function Safety.CanReach(from: Vector3, to: Vector3): boolean
	local path = Pathfinding:CreatePath({AgentRadius = 2, AgentHeight = 6, AgentCanJump = false, AgentCanClimb = false})
	local ok = pcall(function() path:ComputeAsync(from, to) end)
	local reachable = false
	if ok and path.Status == Enum.PathStatus.Success then
		local points = path:GetWaypoints()
		local first, last = points[1], points[#points]
		-- Reject a pathfinder snapping its endpoints out of an enclosed room.
		if first and last then
			local startDelta, endDelta = first.Position - from, last.Position - to
			reachable = Vector3.new(startDelta.X, 0, startDelta.Z).Magnitude <= 3
				and Vector3.new(endDelta.X, 0, endDelta.Z).Magnitude <= 3
				and math.abs(startDelta.Y) <= 6 and math.abs(endDelta.Y) <= 6
		end
	end
	path:Destroy()
	return reachable
end

function Safety.new(map: Model, radius: number): Context
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = {map}
	ray.RespectCanCollide = true
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = {map}
	overlap.RespectCanCollide = true
	overlap.MaxParts = 1
	local ctx: Context = {Map = map, Radius = radius, Ray = ray, Overlap = overlap,
		Anchor = CFrame.new(), Reserved = {}, Goals = {}}
	local anchor = Safety.Ground(ctx, CFrame.new(0, 8, 0))
	assert(anchor, "Map has no safe central meeting point: " .. map.Name)
	ctx.Anchor = anchor
	return ctx
end

function Safety.CheckObjectives(ctx: Context, objectives: Instance)
	ctx.Goals = {}
	for _,goal in ipairs(objectives:GetChildren()) do
		if not goal:IsA("BasePart") then continue end
		local approach: Vector3? = nil
		for _,offset in ipairs({Vector3.new(4.5, 4, 0), Vector3.new(-4.5, 4, 0),
			Vector3.new(0, 4, 4.5), Vector3.new(0, 4, -4.5)}) do
			local cf = Safety.Ground(ctx, CFrame.new(goal.Position + offset))
			if cf and (cf.Position - goal.Position).Magnitude <= 10 then
				local hit = workspace:Raycast(cf.Position, goal.Position - cf.Position, ctx.Ray)
				if (not hit or hit.Instance == goal) and Safety.CanReach(ctx.Anchor.Position, cf.Position) then
					approach = cf.Position
					break
				end
			end
		end
		assert(approach, "No walkable, visible approach to objective: " .. goal:GetFullName())
		table.insert(ctx.Goals, approach)
	end
	assert(#ctx.Goals > 0, "Map has no objectives: " .. ctx.Map.Name)
end

function Safety.Find(ctx: Context, requested: CFrame): CFrame?
	local flat = Vector3.new(requested.Position.X, 0, requested.Position.Z)
	-- Bounded local alternatives towards the arena preserve the intended spawn sector.
	for _,inset in ipairs({0, 12, 24, 36, 48}) do
		local offset = if flat.Magnitude > 0 then -flat.Unit * math.min(inset, flat.Magnitude) else Vector3.zero
		local cf = Safety.Ground(ctx, requested + offset)
		if not cf then continue end
		local occupied = false
		for _,pos in ipairs(ctx.Reserved) do
			if (pos - cf.Position).Magnitude < 6 then occupied = true; break end
		end
		if not occupied and Safety.CanReach(cf.Position, ctx.Anchor.Position) then
			table.insert(ctx.Reserved, cf.Position)
			return cf
		end
	end
	return nil
end

return Safety
