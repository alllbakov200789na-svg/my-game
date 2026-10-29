--!strict
-- Applied only to the active clone. The prepared asset and its metadata stay intact.
local Lighting = game:GetService("Lighting")
local Trove = require(game:GetService("ReplicatedStorage").Packages.Trove)

local ShibuyaLighting = {}

function ShibuyaLighting.Apply(map: Model)
	local cleanup = Trove.new()
	-- Dynamic property access is confined to this snapshot/restore helper.
	local function setProperties(instance: Instance, values: {[string]: any})
		local target = instance :: any
		local previous: {[string]: any} = {}
		for key in pairs(values) do previous[key] = target[key] end
		cleanup:Add(function()
			for key, value in pairs(previous) do target[key] = value end
		end)
		for key, value in pairs(values) do target[key] = value end
	end

	local function effect(className: string, name: string, values: {[string]: any})
		local existing = Lighting:FindFirstChild(name)
		if existing and existing.ClassName == className then
			setProperties(existing, values)
		else
			local created = Instance.new(className) :: any
			created.Name = "ShibuyaNight_" .. name
			for key, value in pairs(values) do created[key] = value end
			cleanup:Add(created)
			created.Parent = Lighting
		end
	end

	setProperties(Lighting, {
		ClockTime = 22,
		Brightness = 1.6,
		ExposureCompensation = 0.05,
		Ambient = Color3.fromRGB(48, 55, 76),
		OutdoorAmbient = Color3.fromRGB(65, 77, 105),
		ColorShift_Top = Color3.fromRGB(8, 13, 28),
		ColorShift_Bottom = Color3.new(),
		EnvironmentDiffuseScale = 0.4,
		EnvironmentSpecularScale = 0.7,
	})
	effect("BloomEffect", "AnimeBloom", {
		Enabled = true, Intensity = 0.3, Size = 28, Threshold = 1.3,
	})
	effect("ColorCorrectionEffect", "AnimeGrade", {
		Enabled = true, Brightness = 0, Contrast = 0.12, Saturation = -0.05,
		TintColor = Color3.fromRGB(237, 244, 255),
	})
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local atmosphereValues = {
		Density = 0.22, Offset = 0.1, Haze = 1.1, Glare = 0,
		Color = Color3.fromRGB(173, 190, 224), Decay = Color3.fromRGB(35, 45, 72),
	}
	if atmosphere then
		setProperties(atmosphere, atmosphereValues)
	else
		effect("Atmosphere", "Atmosphere", atmosphereValues)
	end

	local city = map:FindFirstChild("ShibuyaIncident_NEW_V5")
	local preserved = city and city:FindFirstChild("V4_Preserved")
	local iconic = preserved and preserved:FindFirstChild("02_Iconic_Buildings")
	local qfront = iconic and iconic:FindFirstChild("QRONT_SHIBUYA_Test")
	if qfront then
		-- Only the existing screen and crown lettering; never the glass or cladding.
		for _, part in ipairs(qfront:GetChildren()) do
			if part:IsA("BasePart") and (string.find(part.Name, "integrated curved display", 1, true)
				or part.Name == "QRONT crown lettering") then
				setProperties(part, {Material = Enum.Material.Neon, Color = Color3.fromRGB(210, 231, 255)})
			end
		end
	end
	local magnet = iconic and iconic:FindFirstChild("MAGNET_Glass_Corner")
	if magnet then
		for _, name in ipairs({"Building_Banner", "Retail_Name_Sign"}) do
			local panel = magnet:FindFirstChild(name)
			local gui = panel and panel:FindFirstChild("ArchitecturalSign")
			if gui and gui:IsA("SurfaceGui") then
				setProperties(gui, {LightInfluence = 0, Brightness = 1.8})
			end
		end
	end
	-- SHIBUYA109's graphics are baked into the entire cylindrical shell.
	-- Keep that material intact rather than turning the whole building into neon.
	local street = preserved and preserved:FindFirstChild("04_Street_Details")
	local lamps = 0
	if street then
		for _, fixture in ipairs(street:GetChildren()) do
			if lamps >= 6 then break end
			local lens = fixture.Name == "Street_Lamp" and fixture:FindFirstChild("Warm_Street_Light")
			if lens and lens:IsA("BasePart") and Vector3.new(lens.Position.X, 0, lens.Position.Z).Magnitude <= 135 then
				local light = lens:FindFirstChildOfClass("PointLight")
				if light then
					setProperties(light, {
						Enabled = true, Brightness = 1.15, Range = 32,
						Color = Color3.fromRGB(255, 224, 192), Shadows = false,
					})
					lamps += 1
				end
			end
		end
	end
	return cleanup
end

return ShibuyaLighting
