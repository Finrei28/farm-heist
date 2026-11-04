-- The town's grounds (docs/ArtDirection.md §6, §11 step 6): the paved plaza
-- with a four-leaf clover set in it round the fountain, the clocktower
-- rising out of the fountain (the landmark you see from every farm; its
-- clocks show the sky's time, SkyController turns their hands), benches
-- and picnic tables (the Trade Plaza), the park round it (a lawn, walks to
-- each building, avenues out between them to the walk round the town,
-- trees, flowerbeds and lamps), a signpost at the start of each farm's
-- path (its number and owner: PlotService writes the name), the green out
-- to the ring road (trees in clumps, benches) and lamps along the ring
-- road. The fountain's basin, the trees and the flowerbeds are meshes
-- (World/Meshes; part-built until the props are imported), the rest parts.
--
-- World space: the town's middle at the origin, north +Z, angles clockwise
-- from north (PlotLayout.polar). The ground in layers (never two tops at
-- one height where they overlap): the meadow 0, the park's lawn 0.12, the
-- farm paths 0.2, walks 0.3, the plaza 0.4, its kerb, bands and clover 0.45.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
local Parts = require(script.Parent.Parts)
local Meshes = require(script.Parent.Meshes)

local PlazaArt = {}

local COLORS = Parts.COLORS
local TOWN = PlotLayout.TOWN
local LAWN = Color3.fromRGB(128, 192, 92)
local PAVING = COLORS.plaza
local KERB = Color3.fromRGB(198, 186, 160)
local WALK = Color3.fromRGB(216, 200, 166)
local CLOVER = Color3.fromRGB(78, 146, 82) -- (darker than the lawn: tiles, not grass)
local STONE = Color3.fromRGB(232, 220, 196)
local STONE_DARK = Color3.fromRGB(204, 190, 162)
local SLATE = Color3.fromRGB(98, 104, 116)
local GOLD = Color3.fromRGB(240, 186, 64)
local IRON = Color3.fromRGB(44, 68, 54) -- lamps and bench ends: dark green iron
local WOOD = Color3.fromRGB(160, 116, 72)
local WOOD_DARK = Color3.fromRGB(128, 90, 54)
local LAMP_GLASS = Color3.fromRGB(250, 236, 196)
local WATER = Color3.fromRGB(96, 176, 218)

PlazaArt.TOWER_TOP = 61 -- the clocktower's weathervane (the Exchange's elevator is taller)
PlazaArt.SPAWN_TOP = 0.55 -- the spawn's medallion (TownSpawn stands on it)

local PLAZA_TOP = 0.4
local WALK_TOP = 0.3
local LAWN_TOP = 0.12

-- Where the walks go: to each building from the plaza, and the avenues out
-- between them to the walk round the town.
local function buildingAngles(): { number }
	local list = {}
	for _, building in TOWN.buildings do
		table.insert(list, building.angle)
	end
	return list
end
local function avenueAngles(): { number }
	local list = {}
	local angles = buildingAngles()
	table.sort(angles)
	for i, a in angles do
		local b = angles[i % #angles + 1] + (if i == #angles then 360 else 0)
		table.insert(list, ((a + b) / 2) % 360)
	end
	return list
end
PlazaArt.avenueAngles = avenueAngles

------------------------------------------------------------------------
-- Helpers

local function part(props, parent: Instance): BasePart
	return Parts.part(props, parent)
end
local function prop(props, parent: Instance): BasePart
	return Parts.prop(props, parent)
end

-- A CFrame on the ground at `angle`, `radius`, facing the town's middle
-- (look vector inward), shifted `across` to its right.
local function facingIn(angle: number, radius: number, y: number, across: number?): CFrame
	local p = PlotLayout.polar(angle, radius, y)
	local inward = -PlotLayout.direction(angle)
	local cf = CFrame.lookAt(p, p + inward)
	return if across then cf * CFrame.new(across, 0, 0) else cf
end

-- A flat round slab from y0 to y1 (you can stand on it).
local function slab(name: string, x: number, z: number, radius: number, y0: number, y1: number, color: Color3, parent: Instance, solid: boolean?)
	return part({
		Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(y1 - y0, radius * 2, radius * 2),
		CFrame = CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.rad(90)), Color = color,
		CanCollide = solid ~= false, CastShadow = false,
	}, parent)
end

-- A ring of flat segments round the middle (one colour: where they overlap
-- they look the same, so they don't flicker).
local function ring(name: string, radius: number, width: number, y0: number, y1: number, segments: number, color: Color3, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = name
	local length = 2 * math.pi * radius / segments + 0.6
	for i = 0, segments - 1 do
		local angle = 360 * i / segments
		local p = PlotLayout.polar(angle, radius, (y0 + y1) / 2)
		local radians = math.rad(angle)
		local tangent = Vector3.new(math.cos(radians), 0, -math.sin(radians))
		part({ Name = name, Size = Vector3.new(width, y1 - y0, length), CFrame = CFrame.lookAt(p, p + tangent), Color = color, CastShadow = false }, folder)
	end
	folder.Parent = parent
	return folder
end

-- A straight strip out from the middle along `angle`, from radius `from` to `to`.
local function strip(name: string, angle: number, from: number, to: number, width: number, y0: number, y1: number, color: Color3, parent: Instance)
	local a, b = PlotLayout.polar(angle, from, (y0 + y1) / 2), PlotLayout.polar(angle, to, (y0 + y1) / 2)
	return part({ Name = name, Size = Vector3.new(width, y1 - y0, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = color, CastShadow = false }, parent)
end

-- Words on a part's face.
local function words(p: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?, name: string?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.5
	local label = Instance.new("TextLabel")
	label.Name = name or "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = label
	label.Parent = gui
	gui.Parent = p
	return label
end

------------------------------------------------------------------------
-- Furniture

-- A park bench (wooden slats on dark green iron ends) on `cf`, the middle
-- of where you'd sit, its sitter looking along cf's look vector.
local function bench(cf: CFrame, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Bench"
	for _, x in { -2.5, 2.5 } do
		prop({ Name = "BenchLeg", Size = Vector3.new(0.3, 1.6, 0.3), CFrame = cf * CFrame.new(x, 0.8, -0.75), Color = IRON }, model)
		prop({ Name = "BenchLeg", Size = Vector3.new(0.3, 3.3, 0.3), CFrame = cf * CFrame.new(x, 1.6, 0.75) * CFrame.Angles(math.rad(10), 0, 0), Color = IRON }, model)
		prop({ Name = "BenchArm", Size = Vector3.new(0.3, 0.25, 1.9), CFrame = cf * CFrame.new(x, 2.45, -0.05), Color = IRON }, model)
		prop({ Name = "BenchRail", Size = Vector3.new(0.3, 0.3, 1.8), CFrame = cf * CFrame.new(x, 1.45, 0), Color = IRON }, model)
	end
	for i, z in { -0.62, 0, 0.62 } do
		prop({ Name = "BenchSlat", Size = Vector3.new(5.6, 0.2, 0.48), CFrame = cf * CFrame.new(0, 1.7 + i * 0.012, z), Color = WOOD }, model)
	end
	for _, y in { 2.3, 2.95 } do
		-- (on the backs of the leaning legs, just behind them)
		prop({ Name = "BenchBack", Size = Vector3.new(5.6, 0.45, 0.18), CFrame = cf * CFrame.new(0, y, 1.13 + (y - 2.3) * 0.177) * CFrame.Angles(math.rad(10), 0, 0), Color = WOOD }, model)
	end
	part({ Name = "BenchBlock", Size = Vector3.new(5.6, 2.6, 2), CFrame = cf * CFrame.new(0, 1.3, 0.1), Transparency = 1, CanQuery = false, CanTouch = false }, model)
	model.Parent = parent
	return model
end

-- A picnic table with its two benches (the Trade Plaza), on `cf`, its
-- length along cf's X.
local function picnicTable(cf: CFrame, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "PicnicTable"
	for i, z in { -0.92, 0, 0.92 } do
		prop({ Name = "TableTop", Size = Vector3.new(6, 0.25, 0.86), CFrame = cf * CFrame.new(0, 2.7 + i * 0.01, z), Color = WOOD }, model)
	end
	for _, z in { -2.25, 2.25 } do
		prop({ Name = "TableSeat", Size = Vector3.new(6, 0.25, 0.9), CFrame = cf * CFrame.new(0, 1.55, z), Color = WOOD }, model)
	end
	for _, x in { -2.2, 2.2 } do
		prop({ Name = "TableBrace", Size = Vector3.new(0.32, 0.32, 5.4), CFrame = cf * CFrame.new(x, 1.27, 0), Color = WOOD_DARK }, model)
		prop({ Name = "TableBrace", Size = Vector3.new(0.3, 0.3, 2.4), CFrame = cf * CFrame.new(x + 0.02, 2.42, 0), Color = WOOD_DARK }, model)
		for _, side in { -1, 1 } do
			prop({ Name = "TableLeg", Size = Vector3.new(0.34, 2.9, 0.34), CFrame = cf * CFrame.new(x, 1.32, side * 0.95) * CFrame.Angles(side * math.rad(-24), 0, 0),
				Color = WOOD_DARK }, model)
		end
	end
	part({ Name = "TableBlock", Size = Vector3.new(6, 2.8, 5.4), CFrame = cf * CFrame.new(0, 1.4, 0), Transparency = 1, CanQuery = false, CanTouch = false }, model)
	model.Parent = parent
	return model
end

-- A town lamp post: a dark green iron post on a plinth, a lantern on top
-- (it glows at night, SkyController: "NightGlow"; `lit` gives it a real
-- light too: the plaza's).
local function lamp(at: CFrame, parent: Instance, lit: boolean?)
	local model = Instance.new("Model")
	model.Name = "Lamp"
	part({ Name = "LampBase", Size = Vector3.new(1.0, 1.0, 1.0), CFrame = at * CFrame.new(0, 0.5, 0), Color = IRON }, model)
	Parts.cylinder("LampPost", at * CFrame.new(0, 5.4, 0), 0.4, 8.8, { Color = IRON }, model)
	Parts.cylinder("LampCollar", at * CFrame.new(0, 9.75, 0), 0.75, 0.3, { Color = IRON }, model)
	local glass = prop({ Name = "LampGlass", Size = Vector3.new(0.9, 1.3, 0.9), CFrame = at * CFrame.new(0, 10.55, 0), Color = LAMP_GLASS }, model)
	glass:SetAttribute("NightColor", Color3.fromRGB(255, 214, 140))
	glass:AddTag("NightGlow")
	for _, corner in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		prop({ Name = "LampFrame", Size = Vector3.new(0.12, 1.42, 0.12), CFrame = at * CFrame.new(corner[1] * 0.47, 10.55, corner[2] * 0.47), Color = IRON }, model)
	end
	prop({ Name = "LampCap", Size = Vector3.new(1.3, 0.25, 1.3), CFrame = at * CFrame.new(0, 11.32, 0), Color = IRON }, model)
	Parts.ball("LampKnob", at * CFrame.new(0, 11.62, 0), 0.4, { Color = IRON }, model)
	if lit then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 206, 130)
		light.Range = 24
		light.Brightness = 1.1
		light.Enabled = false
		light.Parent = glass
		light:AddTag("NightLight")
	end
	model.Parent = parent
	return model
end

-- A street lamp on the ring road's town side: a tall post with an arm out
-- over the road (`at` looks toward the road).
local function streetLamp(at: CFrame, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "StreetLamp"
	part({ Name = "LampBase", Size = Vector3.new(1.1, 0.8, 1.1), CFrame = at * CFrame.new(0, 0.4, 0), Color = IRON }, model)
	Parts.cylinder("LampPost", at * CFrame.new(0, 7.2, 0), 0.45, 12.8, { Color = IRON }, model)
	prop({ Name = "LampArm", Size = Vector3.new(0.3, 0.3, 3.4), CFrame = at * CFrame.new(0, 13.3, -1.55), Color = IRON }, model)
	prop({ Name = "LampHood", Size = Vector3.new(1.0, 0.4, 1.6), CFrame = at * CFrame.new(0, 13.15, -3.4), Color = IRON }, model)
	local glass = prop({ Name = "LampGlass", Size = Vector3.new(0.8, 0.3, 1.3), CFrame = at * CFrame.new(0, 12.85, -3.4), Color = LAMP_GLASS }, model)
	glass:SetAttribute("NightColor", Color3.fromRGB(255, 214, 140))
	glass:AddTag("NightGlow")
	model.Parent = parent
	return model
end

-- A mesh standing on `at`, or the part-built stand-in when the props
-- aren't imported.
local function tree(kind: string, at: CFrame, scale: number, parent: Instance)
	local model = Instance.new("Model")
	model.Name = kind
	if not Meshes.make(kind, at, scale, model) then
		local tall = if kind == "PineTree" then 20 else 16
		Parts.cylinder("Trunk", at * CFrame.new(0, tall * 0.25 * scale, 0), 1.4 * scale, tall * 0.5 * scale, { Color = Color3.fromRGB(112, 82, 54) }, model)
		if kind == "PineTree" then
			for i = 0, 3 do
				local d = (9 - i * 2) * scale
				prop({ Name = "Crown", Size = Vector3.new(d, 3.2 * scale, d), CFrame = at * CFrame.new(0, (5 + i * 3.6) * scale, 0) * CFrame.Angles(0, math.rad(i * 20), 0),
					Color = Color3.fromRGB(52, 108, 60) }, model)
			end
		else
			Parts.ball("Crown", at * CFrame.new(0, 11 * scale, 0), 11 * scale, { Color = COLORS.leaf }, model)
		end
	end
	-- (you walk round its trunk)
	part({ Name = "TrunkBlock", Size = Vector3.new(1.6 * scale, 8, 1.6 * scale), CFrame = at * CFrame.new(0, 4, 0), Transparency = 1, CanQuery = false, CanTouch = false }, model)
	model.Parent = parent
	return model
end

PlazaArt.lamp, PlazaArt.streetLamp, PlazaArt.tree = lamp, streetLamp, tree -- (the valley's too: World/ValleyArt)

local function flowerBed(at: CFrame, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "FlowerBed"
	if not Meshes.make("FlowerBed", at, 1, model) then
		Parts.cylinder("BedEdge", at * CFrame.new(0, 0.3, 0), 7, 0.6, { Color = STONE_DARK }, model)
		Parts.cylinder("BedSoil", at * CFrame.new(0, 0.66, 0), 6, 0.2, { Color = Color3.fromRGB(98, 68, 46) }, model)
		for i = 0, 7 do
			local a = math.rad(i * 45)
			Parts.ball("Flower", at * CFrame.new(math.cos(a) * 2, 1.1, math.sin(a) * 2), 0.8,
				{ Color = if i % 2 == 0 then Color3.fromRGB(222, 52, 52) else Color3.fromRGB(250, 210, 56) }, model)
		end
	end
	part({ Name = "BedBlock", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 7, 7), CFrame = at * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Transparency = 1, CanQuery = false, CanTouch = false }, model)
	model.Parent = parent
	return model
end

------------------------------------------------------------------------
-- The clocktower in the fountain

-- A clock's face toward +Z of `cf` (its middle): a gold rim, a cream dial
-- (it glows at night), and the hour marks and hands drawn on it (tagged
-- "ClockFace": SkyController turns the hands, "Hour" and "Minute").
local function clockFace(cf: CFrame, diameter: number, parent: Instance)
	local axis = CFrame.Angles(0, math.rad(90), 0) -- (a cylinder lies along X: turn it to face +Z)
	Parts.prop({ Name = "ClockRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, diameter + 0.6, diameter + 0.6), CFrame = cf * CFrame.new(0, 0, 0.075) * axis,
		Color = GOLD }, parent)
	local dial = Parts.prop({ Name = "ClockDial", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.42, diameter, diameter), CFrame = cf * CFrame.new(0, 0, 0.21) * axis,
		Color = Color3.fromRGB(250, 244, 226) }, parent)
	dial:SetAttribute("NightColor", Color3.fromRGB(255, 238, 196))
	dial:AddTag("NightGlow")
	local face = Parts.prop({ Name = "ClockFace", Size = Vector3.new(diameter, diameter, 0.05), CFrame = cf * CFrame.new(0, 0, 0.47), Transparency = 1, CastShadow = false }, parent)
	face:AddTag("ClockFace")
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.MaxDistance = 2000
	local ink = Color3.fromRGB(40, 34, 30)
	for hour = 0, 11 do
		local angle = math.rad(hour * 30)
		local big = hour % 3 == 0
		local mark = Instance.new("Frame")
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(0.5 + math.sin(angle) * 0.4, 0.5 - math.cos(angle) * 0.4)
		mark.Size = UDim2.fromScale(if big then 0.06 else 0.035, if big then 0.13 else 0.08)
		mark.Rotation = hour * 30
		mark.BackgroundColor3 = ink
		mark.BorderSizePixel = 0
		mark.Parent = gui
	end
	for _, hand in { { "Hour", 0.045, 0.26 }, { "Minute", 0.03, 0.38 } } do
		-- (a square the size of the dial, turned about its middle; the hand
		-- in its top half)
		local turn = Instance.new("Frame")
		turn.Name = hand[1]
		turn.Size = UDim2.fromScale(1, 1)
		turn.BackgroundTransparency = 1
		turn.Parent = gui
		local stick = Instance.new("Frame")
		stick.AnchorPoint = Vector2.new(0.5, 1)
		stick.Position = UDim2.fromScale(0.5, 0.53)
		stick.Size = UDim2.fromScale(hand[2], hand[3])
		stick.BackgroundColor3 = ink
		stick.BorderSizePixel = 0
		stick.Parent = turn
	end
	local hub = Instance.new("Frame")
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromScale(0.09, 0.09)
	hub.BackgroundColor3 = GOLD
	hub.BorderSizePixel = 0
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = hub
	hub.Parent = gui
	gui.Parent = face
	return face
end

local function clocktower(town: Instance)
	local model = Instance.new("Model")
	model.Name = "Clocktower"
	local base = CFrame.new(0, PLAZA_TOP, 0)

	-- the fountain: the stone basin (a mesh; a ring of stone blocks until
	-- the props are imported), the water, spouts on the tower's plinth
	local fountain = Instance.new("Model")
	fountain.Name = "Fountain"
	local R = TOWN.fountainRadius
	if not Meshes.make("FountainBasin", base, 1, fountain) then
		ring("BasinWall", R - 0.7, 1.4, PLAZA_TOP, PLAZA_TOP + 2.4, 32, STONE_DARK, fountain)
		ring("BasinLip", R - 0.65, 1.7, PLAZA_TOP + 2.4, PLAZA_TOP + 2.75, 32, STONE, fountain)
	end
	local water = slab("Water", 0, 0, R - 1.25, PLAZA_TOP + 1.2, PLAZA_TOP + 1.9, WATER, fountain, false)
	water.Transparency = 0.12
	water.Reflectance = 0.2
	slab("PoolFloor", 0, 0, R - 1.6, PLAZA_TOP, PLAZA_TOP + 0.7, Color3.fromRGB(74, 146, 178), fountain).Transparency = 1
	for i = 0, 15 do -- (the rim: you step over it, not through it)
		local a = i * 22.5
		local p = PlotLayout.polar(a, R - 0.7, PLAZA_TOP + 1.25)
		part({ Name = "RimBlock", Size = Vector3.new(1.4, 2.5, 2 * math.pi * (R - 0.7) / 16 + 0.4), CFrame = CFrame.lookAt(p, p + Vector3.new(math.cos(math.rad(a)), 0, -math.sin(math.rad(a)))),
			Transparency = 1, CanQuery = false, CanTouch = false }, fountain)
	end
	fountain.Parent = model

	-- the tower, face by face (each turn of `side` puts one face at +Z)
	local function box(name, cf, size, color, parent, solid)
		return (if solid then part else prop)({ Name = name, Size = size, CFrame = cf, Color = color }, parent or model)
	end
	box("Plinth", base * CFrame.new(0, 2.3, 0), Vector3.new(8, 4.6, 8), STONE_DARK, model, true)
	box("PlinthCap", base * CFrame.new(0, 4.9, 0), Vector3.new(8.8, 0.6, 8.8), STONE)
	box("Shaft", base * CFrame.new(0, 17.4, 0), Vector3.new(6.4, 24.4, 6.4), STONE, model, true)
	for _, c in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		box("Quoin", base * CFrame.new(c[1] * 3.15, 17.4, c[2] * 3.15), Vector3.new(1.1, 24.4, 1.1), STONE_DARK)
	end
	box("Band", base * CFrame.new(0, 17.3, 0), Vector3.new(7.1, 0.6, 7.1), STONE_DARK)
	box("Cornice", base * CFrame.new(0, 29.9, 0), Vector3.new(7.9, 0.7, 7.9), STONE_DARK)
	box("ClockStage", base * CFrame.new(0, 34.4, 0), Vector3.new(7.6, 8.4, 7.6), STONE, model, true)
	box("Cornice", base * CFrame.new(0, 39.0, 0), Vector3.new(8.4, 0.8, 8.4), STONE_DARK)
	for i = 0, 3 do
		local side = base * CFrame.Angles(0, math.rad(90 * i), 0)
		-- a spout into the basin, its water arcing out (particles)
		box("Spout", side * CFrame.new(0, 3.3, 4.3), Vector3.new(1.2, 1.1, 0.8), STONE)
		Parts.prop({ Name = "SpoutPipe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 0.4, 0.4), CFrame = side * CFrame.new(0, 3.3, 5.1) * CFrame.Angles(0, math.rad(90), 0),
			Color = Color3.fromRGB(196, 150, 70) }, fountain)
		local nozzle = Parts.prop({ Name = "SpoutWater", Size = Vector3.new(0.3, 0.3, 0.3), CFrame = side * CFrame.new(0, 3.4, 5.55) * CFrame.Angles(math.rad(-25), math.rad(180), 0),
			Transparency = 1, CastShadow = false }, fountain)
		-- (thick enough to read as a stream from across the plaza; it lands
		-- 2.6 studs out, inside the rim, as the drops die)
		local jet = Instance.new("ParticleEmitter")
		jet.EmissionDirection = Enum.NormalId.Front
		jet.Rate = 120
		jet.Lifetime = NumberRange.new(0.38, 0.42)
		jet.Speed = NumberRange.new(7, 7.4)
		jet.SpreadAngle = Vector2.new(3, 3)
		jet.Acceleration = Vector3.new(0, -35, 0)
		jet.Size = NumberSequence.new(0.55, 0.4)
		jet.Color = ColorSequence.new(Color3.fromRGB(235, 248, 255))
		jet.Transparency = NumberSequence.new(0, 0.3)
		jet.LightEmission = 0.35
		jet.Parent = nozzle
		-- and a splash where it lands
		local splash = Parts.prop({ Name = "SpoutSplash", Size = Vector3.new(0.3, 0.3, 0.3), CFrame = side * CFrame.new(0, 1.95, 8.1),
			Transparency = 1, CastShadow = false }, fountain)
		local drops = Instance.new("ParticleEmitter")
		drops.EmissionDirection = Enum.NormalId.Top
		drops.Rate = 40
		drops.Lifetime = NumberRange.new(0.25, 0.35)
		drops.Speed = NumberRange.new(2, 3.5)
		drops.SpreadAngle = Vector2.new(35, 35)
		drops.Acceleration = Vector3.new(0, -25, 0)
		drops.Size = NumberSequence.new(0.35, 0.15)
		drops.Color = ColorSequence.new(Color3.fromRGB(235, 248, 255))
		drops.Transparency = NumberSequence.new(0.2, 0.7)
		drops.LightEmission = 0.35
		drops.Parent = splash
		-- two tall arched windows up the shaft
		for _, y in { 11.2, 22.4 } do
			box("Window", side * CFrame.new(0, y, 3.22), Vector3.new(1.3, 3.6, 0.1), Color3.fromRGB(52, 58, 70))
			Parts.prop({ Name = "WindowArch", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1.3, 1.3), CFrame = side * CFrame.new(0, y + 1.8, 3.22) * CFrame.Angles(0, math.rad(90), 0),
				Color = Color3.fromRGB(52, 58, 70) }, model)
			box("WindowSill", side * CFrame.new(0, y - 1.95, 3.32), Vector3.new(1.9, 0.3, 0.3), STONE_DARK)
		end
		-- the clock
		clockFace(side * CFrame.new(0, 34.4, 3.8), 5.6, model)
		-- the belfry: open arches between corner posts, a rail along the bottom
		box("BelfryLintel", side * CFrame.new(0, 44.8, 3.5), Vector3.new(7.7, 1.0, 0.7), STONE)
		box("BelfryRail", side * CFrame.new(0, 40.4, 3.5), Vector3.new(5.4, 0.35, 0.4), STONE_DARK)
		for _, x in { -1.35, 0, 1.35 } do
			box("Baluster", side * CFrame.new(x, 39.97, 3.45), Vector3.new(0.35, 0.55, 0.35), STONE)
		end
	end
	for _, c in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		box("BelfryPost", base * CFrame.new(c[1] * 3.25, 42.1, c[2] * 3.25), Vector3.new(1.3, 5.4, 1.3), STONE, model, true)
	end
	box("BelfryFloor", base * CFrame.new(0, 39.55, 0), Vector3.new(7.2, 0.3, 7.2), STONE_DARK)
	-- the bell, hung from a beam
	box("BellBeam", base * CFrame.new(0, 44.6, 0), Vector3.new(7.0, 0.5, 0.5), Color3.fromRGB(96, 66, 42))
	local bell = Meshes.make("AlarmBell", base * CFrame.new(0, 40.6, 0), 2.6, model)
	if not bell then
		Parts.ball("Bell", base * CFrame.new(0, 42.6, 0), 2.6, { Color = GOLD }, model)
	end
	-- the roof: a cornice, then the slate spire, a gold ball and a weathervane
	box("RoofCornice", base * CFrame.new(0, 45.7, 0), Vector3.new(8.8, 0.8, 8.8), STONE_DARK, model, true)
	local spire = Meshes.make("Pyramid", base * CFrame.new(0, 46.1, 0), Vector3.new(8.2, 12, 8.2), model)
	if spire then
		spire.Color = SLATE
		spire.Name = "Spire"
	else
		for i = 0, 5 do
			local w = 7.6 - i * 1.3
			box("Spire", base * CFrame.new(0, 47.1 + i * 2, 0), Vector3.new(w, 2, w), SLATE)
		end
	end
	Parts.ball("Finial", base * CFrame.new(0, 58.4, 0), 0.9, { Color = GOLD }, model)
	Parts.cylinder("VaneRod", base * CFrame.new(0, 59.6, 0), 0.18, 2.6, { Color = GOLD }, model)
	box("VaneArrow", base * CFrame.new(0, 60.3, 0.2), Vector3.new(0.12, 0.12, 2.8), GOLD)
	box("VaneTail", base * CFrame.new(0, 60.3, -1.3), Vector3.new(0.08, 0.8, 0.8), GOLD)
	Parts.prop({ Name = "VaneTip", Size = Vector3.new(0.1, 0.55, 0.55), CFrame = base * CFrame.new(0, 60.3, 1.7) * CFrame.Angles(math.rad(45), 0, 0), Color = GOLD }, model)

	model.Parent = town
	return model
end

------------------------------------------------------------------------
-- Signposts where the farm paths leave the town

-- A fingerpost pointing down farm `index`'s path: "FARM 3" and its owner's
-- name (PlotService writes it on the labels named "Owner").
local function signpost(index: number, town: Instance)
	local angle = PlotLayout.angle(index)
	local model = Instance.new("Model")
	model.Name = `Signpost{index}`
	model:SetAttribute("PlotIndex", index)
	-- (beside the path, just outside the walk; its board points out along
	-- it, +Z of `foot`)
	local foot = facingIn(angle, TOWN.walkRadius + 8, LAWN_TOP, -6)
	local color = Parts.farmColor(index)
	part({ Name = "SignPost", Size = Vector3.new(0.6, 9, 0.6), CFrame = foot * CFrame.new(0, 4.5, 0), Color = COLORS.post }, model)
	prop({ Name = "SignCap", Size = Vector3.new(0.85, 0.3, 0.85), CFrame = foot * CFrame.new(0, 9.15, 0), Color = color }, model)
	-- the board runs along the path (+Z of `foot` is outward) on the post's path side
	local board = prop({ Name = "SignBoard", Size = Vector3.new(0.3, 2.8, 7.4), CFrame = foot * CFrame.new(0.45, 7.2, 3.1), Color = COLORS.cream }, model)
	prop({ Name = "SignEdge", Size = Vector3.new(0.22, 3.2, 7.8), CFrame = board.CFrame * CFrame.new(0, 0, 0), Color = color }, model)
	-- the arrow's point, out toward the farm
	prop({ Name = "SignPoint", Size = Vector3.new(0.22, 2.0, 2.0), CFrame = board.CFrame * CFrame.new(0, 0, 3.7) * CFrame.Angles(math.rad(45), 0, 0), Color = color }, model)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local holder = Instance.new("Frame")
		holder.Size = UDim2.fromScale(1, 1)
		holder.BackgroundTransparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0.5
		local number = Instance.new("TextLabel")
		number.Name = "Number"
		number.Size = UDim2.fromScale(1, 0.55)
		number.BackgroundTransparency = 1
		number.Font = Enum.Font.FredokaOne
		number.TextScaled = true
		number.TextColor3 = Color3.fromRGB(74, 50, 32)
		number.Text = `FARM {index}`
		number.Parent = gui
		local owner = Instance.new("TextLabel")
		owner.Name = "Owner"
		owner.Position = UDim2.fromScale(0, 0.52)
		owner.Size = UDim2.fromScale(1, 0.4)
		owner.BackgroundTransparency = 1
		owner.Font = Enum.Font.FredokaOne
		owner.TextScaled = true
		owner.TextColor3 = Color3.fromRGB(120, 92, 64)
		owner.Text = "for rent"
		owner.Parent = gui
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0.08, 0)
		padding.PaddingRight = UDim.new(0.14, 0)
		padding.PaddingTop = UDim.new(0.08, 0)
		padding.PaddingBottom = UDim.new(0.06, 0)
		padding.Parent = gui
		gui.Parent = board
	end
	model.Parent = town
	return model
end

------------------------------------------------------------------------

function PlazaArt.build(town: Instance)
	local grounds = Instance.new("Folder")
	grounds.Name = "Grounds"
	grounds.Parent = town

	-- The ground: the park's lawn, the plaza, its kerb and a band, the
	-- clover round the fountain (each leaf two discs and the fountain the
	-- middle, so from above it reads as a four-leaf clover: Cloverdale).
	slab("TownLawn", 0, 0, TOWN.radius, 0, LAWN_TOP, LAWN, grounds)
	slab("Plaza", 0, 0, TOWN.plazaRadius, 0, PLAZA_TOP, PAVING, grounds)
	ring("PlazaKerb", TOWN.plazaRadius - 0.6, 1.2, 0, 0.45, 64, KERB, grounds)
	ring("PlazaBand", 32, 1.0, PLAZA_TOP, 0.45, 40, KERB, grounds)
	for i = 0, 3 do
		local a = 45 + 90 * i
		for _, side in { -1, 1 } do
			local p = PlotLayout.polar(a, 15.5) + PlotLayout.polar(a + 90, side * 4.6)
			slab("CloverLeaf", p.X, p.Z, 6.2, PLAZA_TOP, 0.45, CLOVER, grounds)
		end
	end

	-- Walks: to each building's front, the avenues out to the walk round
	-- the town, and the walk itself. (The farm paths go on from it:
	-- WorldBuilder.)
	for _, building in TOWN.buildings do
		strip("BuildingWalk", building.angle, TOWN.plazaRadius - 1.5, building.radius - building.size.Z / 2 + 1, 14, 0, WALK_TOP, WALK, grounds)
	end
	for _, angle in avenueAngles() do
		strip("Avenue", angle, TOWN.plazaRadius - 1.5, TOWN.walkRadius, 8, 0, WALK_TOP, WALK, grounds)
	end
	ring("TownWalk", TOWN.walkRadius, 8, 0, WALK_TOP, 72, WALK, grounds)

	-- The spawn: a medallion in the paving with the clover on it
	local spawnAt = TOWN.spawn
	local medal = slab("SpawnMedallion", spawnAt.X, spawnAt.Z, 4.4, PLAZA_TOP - 0.04, PlazaArt.SPAWN_TOP, STONE, grounds)
	slab("SpawnRing", spawnAt.X, spawnAt.Z, 4.9, PLAZA_TOP - 0.1, 0.49, CLOVER, grounds)
	local emblem = prop({ Name = "SpawnEmblem", Size = Vector3.new(6, 0.05, 6), CFrame = CFrame.new(spawnAt.X, PlazaArt.SPAWN_TOP + 0.03, spawnAt.Z), Transparency = 1, CastShadow = false }, grounds)
	words(emblem, Enum.NormalId.Top, "🍀", CLOVER)
	medal.CastShadow = false

	clocktower(town)

	-- The plaza's edge: lamps either side of each building's walk, benches
	-- facing the fountain between the openings, flowerbeds behind them on
	-- the lawn; picnic tables (the Trade Plaza) on the diagonals.
	local furniture = Instance.new("Folder")
	furniture.Name = "Furniture"
	furniture.Parent = town
	for _, angle in buildingAngles() do
		for _, d in { -11, 11 } do
			lamp(facingIn(angle + d, TOWN.plazaRadius - 4, PLAZA_TOP), furniture, true)
		end
	end
	for k = 0, 9 do
		local angle = 18 + 36 * k
		bench(facingIn(angle, TOWN.plazaRadius - 9, PLAZA_TOP), furniture)
		flowerBed(facingIn(angle, TOWN.plazaRadius + 7, LAWN_TOP), furniture)
	end
	for k = 0, 3 do
		local angle = 45 + 90 * k
		picnicTable(facingIn(angle, 36, PLAZA_TOP), furniture)
	end

	-- The park: flowerbeds along each building's walk, lamps along the
	-- avenues, trees in the gaps between the buildings.
	local park = Instance.new("Folder")
	park.Name = "Park"
	park.Parent = town
	for _, building in TOWN.buildings do
		local front = building.radius - building.size.Z / 2
		for _, across in { -12, 12 } do
			flowerBed(facingIn(building.angle, math.min(82, front - 8), LAWN_TOP, across), park)
		end
	end
	for i, angle in avenueAngles() do
		for j, r in { 92, 126 } do
			local across = if (i + j) % 2 == 0 then 5.5 else -5.5
			lamp(facingIn(angle, r, LAWN_TOP, across), park)
		end
		for j, spot in { { -12, 110 }, { 12, 114 }, { -8, 136 }, { 8, 132 } } do
			local kind = if (i + j) % 3 == 0 then "PineTree" else "OakTree"
			local turn = CFrame.Angles(0, math.rad((i * 71 + j * 113) % 360), 0)
			tree(kind, CFrame.new(PlotLayout.polar(angle + spot[1], spot[2], LAWN_TOP)) * turn, 0.9 + ((i + j) % 3) * 0.08, park)
		end
	end

	-- Where each farm's path leaves the walk: its signpost, a lamp across
	-- the path from it.
	for index = 1, PlotLayout.COUNT do
		signpost(index, town)
		lamp(facingIn(PlotLayout.angle(index), TOWN.walkRadius + 8, LAWN_TOP, 6), park)
	end

	-- The green, out to the ring road: trees in clumps between the farm
	-- paths (nothing taller: the farms' fronts show from the square), a
	-- bench here and there.
	local green = Instance.new("Folder")
	green.Name = "Green"
	green.Parent = town
	for k = 0, 7 do
		local angle = 45 * k
		for j, spot in { { 0, 208 }, { 5, 232 }, { -6, 246 } } do
			local kind = if (k + j) % 3 == 0 then "PineTree" else "OakTree"
			local turn = CFrame.Angles(0, math.rad((k * 53 + j * 97) % 360), 0)
			tree(kind, CFrame.new(PlotLayout.polar(angle + spot[1], spot[2], 0)) * turn, 0.95 + ((k + j) % 3) * 0.1, green)
		end
		if k % 2 == 1 then
			bench(facingIn(angle + 7, 196, 0) * CFrame.Angles(0, math.rad(180), 0), green)
		end
	end

	-- Street lamps along the ring road's town side (not on the farm paths).
	local road = Instance.new("Folder")
	road.Name = "StreetLamps"
	road.Parent = town
	local edge = PlotLayout.RING_ROAD.radius - PlotLayout.RING_ROAD.width / 2 - 2
	for k = 0, 31 do
		local angle = k * 11.25
		if (angle - 22.5) % 45 ~= 0 then
			streetLamp(facingIn(angle, edge, 0) * CFrame.Angles(0, math.rad(180), 0), road)
		end
	end
end

return PlazaArt
