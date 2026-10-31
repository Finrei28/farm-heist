-- Builds the greybox of Cloverdale from shared/PlotLayout (docs/GameDesign.md
-- §3): the valley and hills, the town square and its five buildings, the
-- ring road and its sidewalk, the highway and tunnel, the back trail, and the
-- 8 farms with their hedges, picket fences, gate arch, store, Packing Shed,
-- pickup, farmhouse and 8×8 field (the start corner tilled, the rest
-- overgrown: World/FarmArt; the selling side: World/YardArt; the store:
-- World/StoreArt). Plain blocks and
-- labels, in the art direction's palette (docs/ArtDirection.md): enough to
-- walk the distances and time a raid until the look pass replaces them.
--
-- Rebuilt from scratch at every server start (workspace.World). Each farm is
-- a Model named Plot<n> with a PlotIndex attribute and an invisible "Zone"
-- part matching PlotLayout.zone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
local Parts = require(script.Parent.Parts)
local FarmArt = require(script.Parent.FarmArt)
local YardArt = require(script.Parent.YardArt)
local StoreArt = require(script.Parent.StoreArt)

local WorldBuilder = {}

WorldBuilder.VERSION = 5

local COLORS = Parts.COLORS
local part, plotBox = Parts.part, Parts.plotBox

-- A flat disc (a cylinder standing up).
local function disc(name: string, radius: number, height: number, y: number, color: Color3, parent: Instance)
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
	}, parent)
end

-- A ring of flat segments (roads and trails).
local function ring(name: string, radius: number, width: number, segments: number, color: Color3, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	local length = 2 * math.pi * radius / segments + 1
	for i = 0, segments - 1 do
		local angle = 360 * i / segments
		local position = PlotLayout.polar(angle, radius, 0.15)
		local radians = math.rad(angle)
		local tangent = Vector3.new(math.cos(radians), 0, -math.sin(radians))
		part({
			Name = `{name}{i}`,
			Size = Vector3.new(width, 0.3, length),
			CFrame = CFrame.lookAt(position, position + tangent),
			Color = color,
		}, folder)
	end
end

-- A floating name over something (greybox only). Sized in studs (`studs` is
-- the text height) so it shrinks with distance like a real sign, and hidden
-- beyond `maxDistance`, so far-off farms' labels don't pile up on screen.
local function label(text: string, adornee: BasePart, height: number, studs: number, maxDistance: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(studs * 8, studs)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = maxDistance
	gui.Adornee = adornee
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0.3
	textLabel.Text = text
	textLabel.Parent = gui
	gui.Parent = adornee
	return gui
end

------------------------------------------------------------------------

local function buildValley(world: Instance)
	disc("Valley", PlotLayout.VALLEY_RADIUS, 2, -1, COLORS.meadow, world)
	-- Hills: a ring of tall blocks, open in the north for the highway tunnel.
	local hills = Instance.new("Folder")
	hills.Name = "Hills"
	hills.Parent = world
	local depth = PlotLayout.HILLS_RADIUS - PlotLayout.VALLEY_RADIUS
	for i = 0, 35 do
		local angle = i * 10 + 5
		local radius = PlotLayout.VALLEY_RADIUS + depth / 2
		local position = PlotLayout.polar(angle, radius, 20)
		part({
			Name = `Hill{i}`,
			Size = Vector3.new(depth, 40, 2 * math.pi * radius / 36 + 4),
			CFrame = CFrame.lookAt(position, Vector3.new(0, 20, 0)) * CFrame.Angles(0, math.rad(90), 0),
			Color = COLORS.hill,
		}, hills)
	end
	-- (Nothing flat may sit at the same height as something it overlaps: the
	-- two surfaces would fight over which one shows and flicker as the
	-- camera moves. So the ground goes in layers: valley 0, lawn and town
	-- paths 0.2, roads, trails and the sidewalk 0.3, farm paths 0.35, the
	-- highway 0.42, the plaza 0.4; in a farm, the warehouse site 0.3, the
	-- shed floor 0.5, the dock 0.8.)
	local highway = PlotLayout.HIGHWAY
	part({
		Name = "Highway",
		Size = Vector3.new(highway.width, 0.42, highway.to - highway.from),
		CFrame = CFrame.new(0, 0.21, (highway.from + highway.to) / 2),
		Color = COLORS.road,
	}, world)
	local tunnel = part({
		Name = "Tunnel",
		Size = Vector3.new(highway.width + 6, 18, 6),
		CFrame = CFrame.new(0, 9, highway.to),
		Color = COLORS.dark,
		CanCollide = false,
	}, world)
	label("To the City", tunnel, 14, 5, 400)
end

local function buildTown(world: Instance)
	local town = Instance.new("Folder")
	town.Name = "Town"
	town.Parent = world
	local square = PlotLayout.TOWN
	disc("Plaza", square.plazaRadius, 0.4, 0.2, COLORS.plaza, town)
	disc("Fountain", square.fountainRadius, 2, 1, COLORS.water, town)
	for _, building in square.buildings do
		local position = PlotLayout.polar(building.angle, building.radius, building.size.Y / 2)
		local block = part({
			Name = building.id,
			Size = building.size,
			CFrame = CFrame.lookAt(position, Vector3.new(0, position.Y, 0)),
			Color = if building.id == "Police" then COLORS.slate else COLORS.cream,
		}, town)
		label(building.name, block, building.size.Y / 2 + 4, 4, 260)
	end
	local porch = part({
		Name = "PolicePorch",
		Size = Vector3.new(14, 0.6, 8),
		CFrame = CFrame.lookAt(PlotLayout.policePorchWorld() + Vector3.new(0, 0.3, 0), Vector3.new(0, 0.3, 0)),
		Color = COLORS.slate,
	}, town)
	label("Police porch", porch, 4, 2, 80)

	-- Barley's counter, in front of the seed shop (SeedShopService puts the
	-- Seed Rack prompt on it), and Barley in his straw hat behind it.
	local counterAt = PlotLayout.frontOf("Seeds", 4) + Vector3.new(0, 1.75, 0)
	local facing = CFrame.lookAt(counterAt, Vector3.new(0, counterAt.Y, 0))
	part({ Name = "SeedCounter", Size = Vector3.new(12, 3.5, 3), CFrame = facing, Color = COLORS.kraft }, town)
	part({ Name = "CounterTop", Size = Vector3.new(12.6, 0.4, 3.6), CFrame = facing * CFrame.new(0, 1.95, 0), Color = COLORS.post }, town)
	local barley = Instance.new("Model")
	barley.Name = "Barley"
	local feet = facing * CFrame.new(0, -1.75, 2.8)
	part({ Name = "Body", Size = Vector3.new(2.4, 3.4, 1.4), CFrame = feet * CFrame.new(0, 1.7, 0), Color = COLORS.leaf }, barley)
	Parts.ball("Head", feet * CFrame.new(0, 4.3, 0), 2, { Color = Color3.fromRGB(240, 196, 150) }, barley)
	Parts.cylinder("HatBrim", feet * CFrame.new(0, 5, 0), 3.6, 0.25, { Color = COLORS.hay }, barley)
	Parts.cylinder("HatCrown", feet * CFrame.new(0, 5.5, 0), 2, 1, { Color = COLORS.hay }, barley)
	barley.Parent = town
	label("Barley", barley.Body, 4.6, 1.4, 90)

	-- The Exchange's desk (MarketService opens the Market window from it);
	-- the price board on the building's face is drawn by the clients.
	local deskAt = PlotLayout.frontOf("Exchange", 4) + Vector3.new(0, 1.75, 0)
	part({ Name = "ExchangeDesk", Size = Vector3.new(12, 3.5, 3), CFrame = CFrame.lookAt(deskAt, Vector3.new(0, deskAt.Y, 0)), Color = COLORS.slate }, town)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TownSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 1, 8)
	-- facing north, at the fountain and the Exchange (not the Police Station)
	local spawnAt = square.spawn + Vector3.new(0, 0.5, 0)
	spawn.CFrame = CFrame.lookAt(spawnAt, spawnAt + Vector3.new(0, 0, 1))
	spawn.Color = COLORS.hay
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = town

	ring("RingRoad", PlotLayout.RING_ROAD.radius, PlotLayout.RING_ROAD.width, 72, COLORS.road, world)
	ring("Sidewalk", PlotLayout.SIDEWALK.radius, PlotLayout.SIDEWALK.width, 120, COLORS.plaza, world) -- (shoppers walk it)
	ring("BackTrail", PlotLayout.BACK_TRAIL.radius, PlotLayout.BACK_TRAIL.width, 120, COLORS.trail, world)

	-- Paths from the square to each farm's gate.
	for index = 1, PlotLayout.COUNT do
		local from = PlotLayout.polar(PlotLayout.angle(index), square.plazaRadius, 0.1)
		local to = PlotLayout.visitWorld(index) + Vector3.new(0, 0.1, 0)
		part({
			Name = `Path{index}`,
			Size = Vector3.new(6, 0.2, (to - from).Magnitude),
			CFrame = CFrame.lookAt((from + to) / 2, to),
			Color = COLORS.trail,
		}, town)
	end
end

-- The gate arch (docs/ArtDirection.md §7): two posts and a beam over the
-- gate, a name plank hanging from it (PlotService writes the owner's name on
-- it), a flag in the farm's colour, and a mailbox by the road.
local function buildGateArch(model: Model, frame: CFrame, index: number, left: number, right: number)
	local arch = Instance.new("Model")
	arch.Name = "GateArch"
	local wood = COLORS.post
	local top = 13
	for _, x in { left - 0.7, right + 0.7 } do
		plotBox("ArchPost", frame, Vector3.new(x - 0.7, 0, -1.2), Vector3.new(x + 0.7, top, 0.2), { Color = wood }, arch)
		plotBox("ArchPostCap", frame, Vector3.new(x - 0.9, top, -1.4), Vector3.new(x + 0.9, top + 0.5, 0.4), { Color = COLORS.edging }, arch)
	end
	plotBox("ArchBeam", frame, Vector3.new(left - 1.6, top - 1.6, -1.0), Vector3.new(right + 1.6, top - 0.4, 0.0), { Color = COLORS.edging }, arch)
	local middle = (left + right) / 2
	for _, x in { middle - 4.5, middle + 4.5 } do
		Parts.prop({ Name = "Chain", Size = Vector3.new(0.15, 1.0, 0.15), CFrame = frame * CFrame.new(x, top - 2.1, -0.6), Color = COLORS.dark }, arch)
	end
	local plank = Parts.prop({ Name = "NamePlank", Size = Vector3.new(12, 2.6, 0.35), CFrame = frame * CFrame.new(middle, top - 3.9, -0.6),
		Color = Color3.fromRGB(226, 196, 146) }, arch)
	Parts.prop({ Name = "NamePlankEdge", Size = Vector3.new(12.4, 3.0, 0.25), CFrame = plank.CFrame * CFrame.new(0, 0, 0.12),
		Color = Parts.farmColor(index) }, arch)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "NamePlate"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 24
		gui.LightInfluence = 0.5
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(74, 50, 32)
		label.Text = `Farm {index}: for rent`
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0.12, 0)
		padding.PaddingBottom = UDim.new(0.12, 0)
		padding.PaddingLeft = UDim.new(0.05, 0)
		padding.PaddingRight = UDim.new(0.05, 0)
		padding.Parent = label
		label.Parent = gui
		gui.Parent = plank
	end
	-- the flag on the left post, in the farm's colour
	local poleX = left - 0.7
	Parts.prop({ Name = "FlagPole", Size = Vector3.new(0.25, 4.5, 0.25), CFrame = frame * CFrame.new(poleX, top + 2.7, -0.5), Color = COLORS.metal }, arch)
	Parts.prop({ Name = "Flag", Size = Vector3.new(3.2, 2.0, 0.1), CFrame = frame * CFrame.new(poleX + 1.75, top + 3.8, -0.5), Color = Parts.farmColor(index) }, arch)
	-- the mailbox, by the road outside the right post
	local mailX = right + 2.6
	Parts.part({ Name = "MailPost", Size = Vector3.new(0.4, 3.2, 0.4), CFrame = frame * CFrame.new(mailX, 1.6, -2.6), Color = wood }, arch)
	Parts.part({ Name = "Mailbox", Size = Vector3.new(1.3, 1.1, 2.0), CFrame = frame * CFrame.new(mailX, 3.7, -2.6), Color = Parts.farmColor(index) }, arch)
	Parts.prop({ Name = "MailFlag", Size = Vector3.new(0.12, 0.9, 0.35), CFrame = frame * CFrame.new(mailX + 0.71, 4.2, -2.3), Color = COLORS.barnRed }, arch)
	arch.Parent = model
end

local function buildPlot(index: number, world: Instance)
	local frame = PlotLayout.frame(index)
	local P = PlotLayout.PLOT
	local W, D = PlotLayout.WIDTH, PlotLayout.DEPTH
	local model = Instance.new("Model")
	model.Name = `Plot{index}`
	model:SetAttribute("PlotIndex", index)
	model.Parent = world

	-- The lawn, mown in stripes: strips side by side (never one on top of
	-- another, which flickers).
	local STRIPE = 20
	for x = -W / 2, W / 2 - STRIPE, STRIPE do
		local light = ((x + W / 2) / STRIPE) % 2 == 1
		plotBox("Yard", frame, Vector3.new(x, 0, 0), Vector3.new(x + STRIPE, 0.2, D), { Color = if light then COLORS.lawnStripe else COLORS.lawn }, model)
	end

	-- Hedges can't be climbed; the back fence can (slowly); the front has the
	-- gate. Fences are as tall as PlotLayout.FENCE_HEIGHT, so a jump hits the
	-- fence you see; an invisible wall up to FENCE_BLOCK is what really stops
	-- you: without it a character climbs rails like a ladder (play-test
	-- 2026-10-30). The front is a white picket fence; the back keeps its
	-- rails until the climb comes (week 5: slats with a "Climb" prompt). A
	-- fence runs across the plot (along X).
	local function fence(name: string, min: Vector3, max: Vector3)
		local rails = Instance.new("Model")
		rails.Name = name
		rails.Parent = model
		local height = PlotLayout.FENCE_HEIGHT
		for _, y in { 1, height / 2, height - 1 } do
			plotBox("Rail", frame, Vector3.new(min.X, y, min.Z), Vector3.new(max.X, y + 1, max.Z), { Color = COLORS.fence }, rails)
		end
		local gaps = math.max(1, math.round((max.X - min.X) / 12))
		for i = 0, gaps do
			local x = min.X + (max.X - min.X) * i / gaps
			-- (posts stand a little above the top rail: level tops would flicker)
			plotBox("Post", frame, Vector3.new(x - 0.5, 0, min.Z - 0.25), Vector3.new(x + 0.5, height + 0.6, max.Z + 0.25), { Color = COLORS.post }, rails)
		end
		plotBox(`{name}Blocker`, frame, min, Vector3.new(max.X, PlotLayout.FENCE_BLOCK, max.Z),
			{ Transparency = 1, CanQuery = false, CanTouch = false }, model)
	end
	local function pickets(name: string, fromX: number, toX: number)
		Parts.picketFence(frame, Vector3.new(fromX, 0, -1), Vector3.new(toX, 0, 0), model, name, PlotLayout.FENCE_HEIGHT, PlotLayout.FENCE_BLOCK)
	end
	-- Hedges: tall, with a rounded top and a few flowers.
	local H = PlotLayout.HEDGE_HEIGHT
	for _, side in { -1, 1 } do
		local x = side * (W / 2 + 1.5)
		plotBox(if side < 0 then "HedgeLeft" else "HedgeRight", frame, Vector3.new(x - 1.5, 0, 0), Vector3.new(x + 1.5, H, D), { Color = COLORS.hedge }, model)
		part({ Name = "HedgeTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(D, 3, 3),
			CFrame = frame * CFrame.new(x, H, D / 2) * CFrame.Angles(0, math.rad(90), 0), Color = COLORS.hedge }, model)
		for i = 0, 11 do
			local z = 8 + i * (D - 16) / 11
			local inward = -side * (if i % 2 == 0 then 1.55 else 1.5)
			Parts.ball("HedgeFlower", frame * CFrame.new(x + inward, 4 + (i * 37 % 7), z), 0.7,
				{ Color = if i % 3 == 0 then COLORS.cream else COLORS.hay }, model)
		end
	end
	fence("BackFence", Vector3.new(-W / 2, 0, D), Vector3.new(W / 2, 0, D + 1))
	-- The front: pickets from the store to the gate, the gate, then to the
	-- truck gate and on to the hedge. (The stretch from the hedge to the
	-- store is the store's: World/StoreArt. The store and the truck gate are
	-- part of the front too: neither is a way in.)
	local gateLeft = P.gate.across - P.gate.width / 2
	local gateRight = P.gate.across + P.gate.width / 2
	pickets("FrontFenceByGate", P.store.right + P.store.wall, gateLeft)
	pickets("FrontFence", gateRight, P.driveway.min.X)
	pickets("FrontFenceFar", P.driveway.max.X, W / 2)
	local gatePost = plotBox("Gate", frame, Vector3.new(gateLeft, 0, -1.5), Vector3.new(gateRight, 0.5, 0.5), { Color = COLORS.hay }, model)
	buildGateArch(model, frame, index, gateLeft, gateRight)

	-- Buildings.
	plotBox("Gatehouse", frame, P.gatehouse.min, P.gatehouse.max, { Color = COLORS.cream }, model)
	-- (on the lawn, not level with it)
	plotBox("Driveway", frame, P.driveway.min + Vector3.new(0, 0.2, 0), P.driveway.max + Vector3.new(0, 0.15, 0), { Color = COLORS.road }, model)
	plotBox("Path", frame, P.path.min + Vector3.new(0, 0.2, 0), P.path.max + Vector3.new(0, 0.15, 0), { Color = COLORS.trail }, model)
	-- Selling: the Packing Shed and dock, the pickup, the truck gate (the
	-- warehouse's stations come with Warehouse Level 5), and your store.
	YardArt.build(model, frame)
	StoreArt.build(model)
	label("Farmhouse & barn", plotBox("Farmhouse", frame, P.farmhouse.min, P.farmhouse.max, { Color = COLORS.cream }, model), 12, 3, 120)
	local door = part({
		Name = "Door", Size = Vector3.new(4, 0.4, 4),
		CFrame = frame * CFrame.new(P.door + Vector3.new(0, 0.2, 0)), Color = COLORS.hay,
	}, model)
	door:SetAttribute("Deposit", true) -- the barn's deposit point and the owner's spawn

	-- The field: the start corner tilled, the rest overgrown (World/FarmArt).
	FarmArt.buildField(model, frame)
	part({ Name = "Scarecrow", Size = Vector3.new(1, 8, 1), CFrame = frame * CFrame.new(P.scarecrow + Vector3.new(0, 4, 0)), Color = COLORS.post }, model)
	part({ Name = "Kennel", Size = Vector3.new(8, 6, 7), CFrame = frame * CFrame.new(P.kennel + Vector3.new(0, 3, 0)), Color = COLORS.barnRed }, model)

	-- The farm's zone, for checks you can see in Studio (the server uses PlotLayout.zone).
	local zone = PlotLayout.zone(index)
	part({
		Name = "Zone", Size = zone.size, CFrame = zone.cframe,
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
	}, model)
	model.PrimaryPart = gatePost
end

function WorldBuilder.Build()
	local old = workspace:FindFirstChild("World")
	if old then
		old:Destroy()
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	local world = Instance.new("Folder")
	world.Name = "World"
	world:SetAttribute("Version", WorldBuilder.VERSION)
	buildValley(world)
	buildTown(world)
	for index = 1, PlotLayout.COUNT do
		buildPlot(index, world)
	end
	world.Parent = workspace
	return world
end

return WorldBuilder
