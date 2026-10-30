-- Builds the greybox of Cloverdale from shared/PlotLayout (docs/GameDesign.md
-- §3): the valley and hills, the town square and its five buildings, the
-- ring road, the highway and tunnel, the back trail, and the 8 farms with
-- their hedges, fences, gate, shop, warehouse, farmhouse and 8×8 field (the
-- start corner tilled, the rest overgrown). Plain blocks and labels: enough
-- to walk the distances and time a raid before any art exists.
--
-- Rebuilt from scratch at every server start (workspace.World). Each farm is
-- a Model named Plot<n> with a PlotIndex attribute and an invisible "Zone"
-- part matching PlotLayout.zone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
local LandRules = require(ReplicatedStorage.Shared.LandRules)

local WorldBuilder = {}

WorldBuilder.VERSION = 1

local COLORS = {
	grass = Color3.fromRGB(150, 196, 104),
	yard = Color3.fromRGB(132, 184, 92),
	hill = Color3.fromRGB(104, 152, 72),
	plaza = Color3.fromRGB(226, 214, 186),
	road = Color3.fromRGB(150, 144, 134),
	trail = Color3.fromRGB(196, 164, 112),
	soil = Color3.fromRGB(120, 84, 56),
	overgrown = Color3.fromRGB(96, 140, 64),
	rock = Color3.fromRGB(128, 136, 146),
	hedge = Color3.fromRGB(47, 107, 42),
	fence = Color3.fromRGB(122, 82, 50),
	barnRed = Color3.fromRGB(184, 62, 40),
	cream = Color3.fromRGB(247, 237, 214),
	slate = Color3.fromRGB(127, 140, 153),
	hay = Color3.fromRGB(242, 179, 61),
	water = Color3.fromRGB(124, 195, 232),
	dark = Color3.fromRGB(28, 23, 18),
}

local function part(props, parent: Instance): BasePart
	local p: any = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		p[key] = value
	end
	p.Parent = parent
	return p
end

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

-- A floating name over something (greybox only).
local function label(text: string, adornee: BasePart, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 300
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

-- A box from plot-space corners (min.Y is the ground it stands on).
local function plotBox(name: string, frame: CFrame, min: Vector3, max: Vector3, props, parent: Instance): BasePart
	local size = Vector3.new(math.max(0.2, max.X - min.X), math.max(0.2, max.Y - min.Y), math.max(0.2, max.Z - min.Z))
	local centre = Vector3.new((min.X + max.X) / 2, min.Y + size.Y / 2, (min.Z + max.Z) / 2)
	local all = table.clone(props)
	all.Name = name
	all.Size = size
	all.CFrame = frame * CFrame.new(centre)
	return part(all, parent)
end

------------------------------------------------------------------------

local function buildValley(world: Instance)
	disc("Valley", PlotLayout.VALLEY_RADIUS, 2, -1, COLORS.grass, world).Material = Enum.Material.Grass
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
			Material = Enum.Material.Grass,
		}, hills)
	end
	local highway = PlotLayout.HIGHWAY
	part({
		Name = "Highway",
		Size = Vector3.new(highway.width, 0.3, highway.to - highway.from),
		CFrame = CFrame.new(0, 0.15, (highway.from + highway.to) / 2),
		Color = COLORS.road,
	}, world)
	local tunnel = part({
		Name = "Tunnel",
		Size = Vector3.new(highway.width + 6, 18, 6),
		CFrame = CFrame.new(0, 9, highway.to),
		Color = COLORS.dark,
		CanCollide = false,
	}, world)
	label("To the City", tunnel, 14)
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
		label(building.name, block, building.size.Y / 2 + 4)
	end
	local porch = part({
		Name = "PolicePorch",
		Size = Vector3.new(14, 0.6, 8),
		CFrame = CFrame.lookAt(PlotLayout.policePorchWorld() + Vector3.new(0, 0.3, 0), Vector3.new(0, 0.3, 0)),
		Color = COLORS.slate,
	}, town)
	label("Police porch", porch, 4)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TownSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(square.spawn + Vector3.new(0, 0.5, 0))
	spawn.Color = COLORS.hay
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = town

	ring("RingRoad", PlotLayout.RING_ROAD.radius, PlotLayout.RING_ROAD.width, 72, COLORS.road, world)
	ring("BackTrail", PlotLayout.BACK_TRAIL.radius, PlotLayout.BACK_TRAIL.width, 120, COLORS.trail, world)

	-- Paths from the square to each farm's gate.
	for index = 1, PlotLayout.COUNT do
		local from = PlotLayout.polar(PlotLayout.angle(index), square.plazaRadius, 0.12)
		local to = PlotLayout.visitWorld(index) + Vector3.new(0, 0.12, 0)
		part({
			Name = `Path{index}`,
			Size = Vector3.new(6, 0.24, (to - from).Magnitude),
			CFrame = CFrame.lookAt((from + to) / 2, to),
			Color = COLORS.trail,
		}, town)
	end
end

local function buildPlot(index: number, world: Instance)
	local frame = PlotLayout.frame(index)
	local P = PlotLayout.PLOT
	local W, D = PlotLayout.WIDTH, PlotLayout.DEPTH
	local model = Instance.new("Model")
	model.Name = `Plot{index}`
	model:SetAttribute("PlotIndex", index)
	model.Parent = world

	plotBox("Yard", frame, Vector3.new(-W / 2, 0, 0), Vector3.new(W / 2, 0.2, D), { Color = COLORS.yard, Material = Enum.Material.Grass }, model)

	-- Hedges can't be climbed; the back fence can (slowly); the front has the
	-- gate. Fences are low to look at, with an invisible wall above them that
	-- a jump can't clear (climbing comes with week 4: §4.10).
	local function fence(name: string, min: Vector3, max: Vector3)
		plotBox(name, frame, min, Vector3.new(max.X, PlotLayout.FENCE_HEIGHT, max.Z), { Color = COLORS.fence }, model)
		plotBox(`{name}Blocker`, frame, min, Vector3.new(max.X, PlotLayout.FENCE_BLOCK, max.Z),
			{ Transparency = 1, CanQuery = false, CanTouch = false }, model)
	end
	local H = PlotLayout.HEDGE_HEIGHT
	plotBox("HedgeLeft", frame, Vector3.new(-W / 2 - 3, 0, 0), Vector3.new(-W / 2, H, D), { Color = COLORS.hedge }, model)
	plotBox("HedgeRight", frame, Vector3.new(W / 2, 0, 0), Vector3.new(W / 2 + 3, H, D), { Color = COLORS.hedge }, model)
	fence("BackFence", Vector3.new(-W / 2, 0, D), Vector3.new(W / 2, 0, D + 1))
	local gateLeft = P.gate.across - P.gate.width / 2
	local gateRight = P.gate.across + P.gate.width / 2
	fence("FrontFenceShopSide", Vector3.new(-W / 2, 0, -1), Vector3.new(P.shop.min.X, 0, 0))
	fence("FrontFenceByGate", Vector3.new(P.shop.max.X, 0, -1), Vector3.new(gateLeft, 0, 0))
	fence("FrontFence", Vector3.new(gateRight, 0, -1), Vector3.new(W / 2, 0, 0)) -- (with the trucks-only gate across the driveway)
	local gatePost = plotBox("Gate", frame, Vector3.new(gateLeft, 0, -1.5), Vector3.new(gateRight, 0.4, 0.5), { Color = COLORS.hay }, model)
	label(`Farm {index}: for rent`, gatePost, 8)

	-- Buildings.
	label("Shop", plotBox("Shop", frame, P.shop.min, P.shop.max, { Color = COLORS.barnRed }, model), 10)
	plotBox("Gatehouse", frame, P.gatehouse.min, P.gatehouse.max, { Color = COLORS.cream }, model)
	plotBox("Driveway", frame, P.driveway.min, P.driveway.max, { Color = COLORS.road }, model)
	plotBox("Path", frame, P.path.min, P.path.max, { Color = COLORS.trail }, model)
	-- The warehouse: a roof on posts, so you can walk in to the stations.
	local wh = P.warehouse
	plotBox("WarehouseFloor", frame, wh.min, Vector3.new(wh.max.X, 0.4, wh.max.Z), { Color = COLORS.slate }, model)
	local roof = plotBox("WarehouseRoof", frame, Vector3.new(wh.min.X, wh.max.Y - 1, wh.min.Z), wh.max, { Color = COLORS.slate }, model)
	label("Warehouse", roof, 4)
	for _, corner in { { wh.min.X, wh.min.Z }, { wh.max.X - 2, wh.min.Z }, { wh.min.X, wh.max.Z - 2 }, { wh.max.X - 2, wh.max.Z - 2 } } do
		plotBox("Post", frame, Vector3.new(corner[1], 0, corner[2]), Vector3.new(corner[1] + 2, wh.max.Y - 1, corner[2] + 2), { Color = COLORS.slate }, model)
	end
	for _, station in P.stations do
		local pad = plotBox(station.id, frame, Vector3.new(P.stationAcross - 6, 0, station.z - 5), Vector3.new(P.stationAcross + 6, 3, station.z + 5), { Color = COLORS.cream }, model)
		label(station.id, pad, 4)
	end
	label("Farmhouse & barn", plotBox("Farmhouse", frame, P.farmhouse.min, P.farmhouse.max, { Color = COLORS.cream }, model), 12)
	local door = part({
		Name = "Door", Size = Vector3.new(4, 0.4, 4),
		CFrame = frame * CFrame.new(P.door + Vector3.new(0, 0.2, 0)), Color = COLORS.hay,
	}, model)
	door:SetAttribute("Deposit", true) -- the barn's deposit point and the owner's spawn

	-- The field: the start corner tilled, the rest overgrown (one rock per block).
	local field = Instance.new("Folder")
	field.Name = "Field"
	field.Parent = model
	for tile = 1, P.field.size * P.field.size do
		local block = LandRules.blockOfTile(tile)
		local centre = PlotLayout.tileLocal(tile)
		local open = LandRules.isStart(block)
		local t = part({
			Name = `Tile{tile}`,
			Size = Vector3.new(P.field.tile - 0.6, 0.4, P.field.tile - 0.6),
			CFrame = frame * CFrame.new(centre + Vector3.new(0, 0.3, 0)),
			Color = if open then COLORS.soil else COLORS.overgrown,
			Material = if open then Enum.Material.Ground else Enum.Material.Grass,
		}, field)
		t:SetAttribute("Tile", tile)
		t:SetAttribute("Block", block)
	end
	for block = 1, 16 do
		if not LandRules.isStart(block) then
			local tiles = LandRules.tilesOf(block)
			local corner = (PlotLayout.tileLocal(tiles[1]) + PlotLayout.tileLocal(tiles[4])) / 2
			part({
				Name = `Rock{block}`, Size = Vector3.new(4, 3, 3),
				CFrame = frame * CFrame.new(corner + Vector3.new(0, 1.5, 0)), Color = COLORS.rock,
				Material = Enum.Material.Slate,
			}, field)
		end
	end
	part({ Name = "Scarecrow", Size = Vector3.new(1, 8, 1), CFrame = frame * CFrame.new(P.scarecrow + Vector3.new(0, 4, 0)), Color = COLORS.fence }, model)
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
