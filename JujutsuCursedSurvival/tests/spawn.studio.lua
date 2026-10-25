-- Engine tests, not a CLI test. In an EDIT-mode test copy, paste into a temporary
-- ServerStorage.SpawnTests ModuleScript; call require(...)(mapId, mode) in Command Bar.
-- Removes its map, fixtures and isolated service copies even on failure.
return function(mapId: string, mode: string)
	assert(not game:GetService("RunService"):IsRunning(), "Run spawn geometry tests in Edit mode")
	assert(not workspace:FindFirstChild("ActiveMap"), "An ActiveMap already exists; use a clean test copy")
	local source = game:GetService("ServerScriptService").Services
	local sandbox = Instance.new("Folder")
	sandbox.Name = "SpawnTestServices"
	sandbox.Parent = game:GetService("ServerStorage")
	for _,name in ipairs({"MapService", "SpawnSafety", "AntiExploitService", "VerticalMotion"}) do
		source[name]:Clone().Parent = sandbox
	end
	local map = require(sandbox.MapService)
	local safety = require(sandbox.SpawnSafety)
	local guard = require(sandbox.AntiExploitService)
	local shared = game:GetService("ReplicatedStorage").Shared
	local chars = require(shared.CharacterDefinitions)
	local utility = require(shared.Utility)
	local checks, selections = 0, 0
	local function check(value, message)
		assert(value, message)
		checks += 1
	end
	local context = {Config = {ArenaRadius = 145}, DestructionService = {}, U = utility}
	map:Init(context)
	guard:Init(context)
	local ok, result = xpcall(function()
		map:Load(mapId, mode)
		local ctx = map.SpawnSafety
		check(#ctx.Goals == 3, "All three objectives need a reachable prompt approach")
		if mapId == "CursedDistrict" and mode ~= "Clash" then
			local original = map.Active.SpawnPoints.Spawn08.CFrame + Vector3.new(0, 4, 0)
			check(safety.Ground(ctx, original) ~= nil, "Regression fixture must have empty room space")
			check(not safety.CanReach(original.Position, ctx.Anchor.Position), "Original Spawn08 must reproduce NoPath")
			local fixed = map:Spawn(1, "Curses")
			check(fixed.Z > -97 and math.abs(fixed.X) < 1, "Sukuna should be outside the back wall in the same sector")
		end
		-- MapService uses team, not role. Both 15-slot sequences cover every normal
		-- Gojo/Sorcerer and Sukuna/Curse selection, plus both sides of Clash.
		for _,team in ipairs({"Sorcerers", "Curses"}) do
			ctx.Reserved = {}
			for index = 1, 15 do
				local cf = map:Spawn(index, team)
				check(safety.Ground(ctx, cf) ~= nil, team .. " slot " .. index .. " lacks clearance/support")
				check(#ctx.Reserved == index, "Every spawn must reserve a separate location")
				for previous = 1, index - 1 do
					check((cf.Position - ctx.Reserved[previous]).Magnitude >= 6, "Players overlap")
				end
				selections += 1
			end
		end
		-- Mixed roles exercise collisions caused by the original +8 team offset.
		ctx.Reserved = {}
		local roles = {"Sukuna", "Gojo", "Curse", "Sorcerer"}
		for index = 1, 15 do
			local role = roles[(index - 1) % #roles + 1]
			local cf = map:Spawn(index, chars[role].Team)
			check(safety.Ground(ctx, cf) ~= nil, role .. " lacks safe placement")
			for previous = 1, index - 1 do
				check((cf.Position - ctx.Reserved[previous]).Magnitude >= 6, "Mixed-role spawn collision")
			end
			selections += 1
		end
		-- Real Instances and the actual guard verify the placement/reset contract.
		for _,role in ipairs(roles) do
			ctx.Reserved = {}
			local cf = map:Spawn(1, chars[role].Team)
			local rig = Instance.new("Model")
			rig.Name = "SpawnBaselineTest"
			rig.Parent = map.Active
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"; root.Size = Vector3.new(2, 2, 1)
			root.Anchored = true; root.CanCollide = false; root.Parent = rig
			local h = Instance.new("Humanoid"); h.HipHeight = 2; h.Parent = rig
			rig.PrimaryPart = root
			rig:PivotTo(cf)
			local player = {UserId = 9001}
			local actor = {Model = rig, Player = player, Alive = true, Definition = chars[role]}
			guard:ResetMotion(actor, root.Position)
			guard:Step(actor, 0.25)
			check(guard.Motion[player].SafePos == root.Position and #guard.Audit == 0, role .. " guard rollback after spawn")
			guard:Remove(player)
			rig:Destroy()
			selections += 1
		end
		ctx.Reserved = {}
		local point = map:Spawn(1, "Sorcerers")
		local blocker = Instance.new("Part")
		blocker.Name = "SpawnTestBlocker"; blocker.Anchored = true; blocker.CanQuery = false
		blocker.Size = Vector3.new(5, 8, 5); blocker.CFrame = point; blocker.Parent = map.Active
		check(safety.Ground(ctx, point) == nil, "Collidable CanQuery=false blocker must be rejected")
		blocker.Size = Vector3.new(5, 1, 5); blocker.Position = point.Position + Vector3.new(0, 1, 0)
		check(safety.Ground(ctx, point) == nil, "Low roof must be rejected")
		blocker:Destroy()
		check(safety.Ground(ctx, CFrame.new(0, 100, 0)) == nil, "No nearby floor must be rejected")
		check(safety.Ground(ctx, CFrame.new(149, 5, 0)) == nil, "Out-of-arena spawn must be rejected")
		blocker = Instance.new("Part")
		blocker.Name = "SpawnTestBlockedGoal"; blocker.Anchored = true
		blocker.Size = Vector3.new(22, 12, 22)
		blocker.Position = map.Active.Objectives.Seal1.Position + Vector3.new(0, 3, 0)
		blocker.Parent = map.Active
		check(not pcall(safety.CheckObjectives, ctx, map.Active.Objectives), "Blocked objective must stop loading")
		blocker:Destroy()
		safety.CheckObjectives(ctx, map.Active.Objectives)
		blocker = Instance.new("Part")
		blocker.Name = "SpawnTestNoSafePoint"; blocker.Anchored = true
		blocker.Size = Vector3.new(290, 12, 290); blocker.Position = Vector3.new(0, 5, 0)
		blocker.Parent = map.Active
		check(not pcall(map.Spawn, map, 1, "Curses"), "Never return an unchecked fallback when all candidates fail")
		blocker:Destroy()
		return string.format("PASS %s/%s: %d spawn selections, %d assertions; all roles, objectives, clearance, reservations, guard baseline, fail-closed", mapId, mode, selections, checks)
	end, debug.traceback)
	map:Cleanup()
	sandbox:Destroy()
	if not ok then error(result) end
	return result
end
