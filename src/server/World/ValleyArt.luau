-- The valley round the farms (docs/ArtDirection.md §5, §11 step 4):
--   * the hills: Terrain grass in two rings of mounds past the valley's
--     edge, higher toward the north, where a rock cliff holds the tunnel;
--   * the tunnel's mouth: the stone arch (a mesh, TunnelArch) in the cliff
--     where the highway goes in, dark inside (the trucks drive into it and
--     out of sight), a lamp either side, a THE CITY road sign before it;
--   * woods in the gaps between the farms: clumps of oaks and firs with
--     bushes down the middle of each gap, at least 12 studs clear of the
--     hedges (the way round to the back trail goes along them) and of the
--     highway;
--   * the back trail: hay bales and bushes every 52 studs or so (cover for
--     sneaking up to a back fence), mostly on its outer verge, and lamp
--     posts along it for the night;
--   * the ring road: a dashed centre line, kerbs along both edges and a
--     zebra crossing where each farm's path crosses it.
-- Terrain only exists in Roblox: in the tests (Lune) the hills are skipped.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
local Parts = require(script.Parent.Parts)
local Meshes = require(script.Parent.Meshes)
local PlazaArt = require(script.Parent.PlazaArt)

local ValleyArt = {}

local COLORS = Parts.COLORS
local part, prop = Parts.part, Parts.prop
local HIGHWAY = PlotLayout.HIGHWAY
local polar, direction = PlotLayout.polar, PlotLayout.direction

ValleyArt.WOODS_CLEAR = 12 -- studs from a hedge (or the highway's edge) to a tree's trunk
ValleyArt.TRAIL_COVER = 5 -- degrees between the back trail's hay bales and bushes
ValleyArt.TRAIL_LAMPS = 7.5 -- degrees between its lamps
ValleyArt.MARKINGS_TOP = 0.36 -- the road's paint, over the road (0.3)

local WHITE = Color3.fromRGB(240, 238, 228)
local KERB = Color3.fromRGB(196, 190, 178)

-- A steady "random" number in [0, 1) from two numbers (the same every start).
local function noise(a: number, b: number): number
	local x = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return x - math.floor(x)
end

-- A bush (the town's mesh, or a leafy ball until the props are imported).
local function bush(at: CFrame, scale: number, parent: Instance)
	if not Meshes.make("Bush", at, scale, parent) then
		Parts.ball("Bush", at * CFrame.new(0, 1.4 * scale, 0), 3.6 * scale, { Color = COLORS.leaf, CanCollide = false }, parent)
	end
end

------------------------------------------------------------------------
-- The hills and the cliff (Terrain)

-- Whether a mound whose foot is `reach` round `centre` would spill onto the
-- highway's last stretch before the tunnel.
local function onHighway(centre: Vector3, reach: number): boolean
	local x = math.max(0, math.abs(centre.X) - (HIGHWAY.width / 2 + 16))
	local z = math.max(0, (HIGHWAY.to - 120) - centre.Z, centre.Z - HIGHWAY.to)
	return centre.Z > 0 and math.sqrt(x * x + z * z) < reach
end

local function hills()
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		return
	end
	local ok, err = pcall(function()
		terrain:Clear()
		-- (the valley's own green, so the hills' feet meet its ground unseen;
		-- no Terrain under the ground itself: its grass blades grow through
		-- anything they're under)
		terrain:SetMaterialColor(Enum.Material.Grass, COLORS.meadow)
		terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(156, 146, 132))
		-- two rings of mounds, the nearer one starting at the valley's edge;
		-- higher toward the north; none over the highway's last stretch
		local edge = PlotLayout.VALLEY_RADIUS + 10
		for ringIndex, spec in { { count = 60, base = 70, spread = 22, north = 45, sink = 0.45, back = 0.9 }, { count = 48, base = 110, spread = 34, north = 60, sink = 0.35, back = 0.8 } } do
			for i = 0, spec.count - 1 do
				local angle = (i + noise(i, ringIndex) * 0.6) * 360 / spec.count
				local towardNorth = math.max(0, math.cos(math.rad(angle)))
				local r = spec.base + spec.spread * noise(ringIndex, i) + spec.north * towardNorth ^ 2
				local radius = edge + (ringIndex - 1) * 70 + spec.back * r
				local centre = polar(angle, radius, -spec.sink * r)
				if not onHighway(centre, math.sqrt(r * r - (spec.sink * r) ^ 2)) then
					terrain:FillBall(centre, r, Enum.Material.Grass)
				end
			end
		end
		-- the cliff the tunnel goes into: rock behind and round the arch, its
		-- shoulders rounded, grassy hill over it and either side
		local mouth = HIGHWAY.to
		terrain:FillBlock(CFrame.new(0, 22, mouth + 42), Vector3.new(66, 44, 80), Enum.Material.Rock)
		for _, ball in {
			{ 40, 12, 26, 32 }, { -40, 12, 26, 32 }, { 26, 36, 36, 26 }, { -26, 36, 36, 26 }, { 0, 44, 48, 28 },
		} do
			terrain:FillBall(Vector3.new(ball[1], ball[2], mouth + ball[3]), ball[4], Enum.Material.Rock)
		end
		for _, ball in { { 0, 60, 80, 46 }, { 62, 26, 46, 44 }, { -62, 26, 46, 44 }, { 100, 6, 40, 52 }, { -100, 6, 40, 52 } } do
			terrain:FillBall(Vector3.new(ball[1], ball[2], mouth + ball[3]), ball[4], Enum.Material.Grass)
		end
		-- the tunnel itself (the arch stands at its mouth), and nothing in front of the arch
		terrain:FillBlock(CFrame.new(0, 16, mouth + 34), Vector3.new(30, 32, 70), Enum.Material.Air)
		terrain:FillBlock(CFrame.new(0, 30, mouth - 15), Vector3.new(56, 60, 30), Enum.Material.Air)
	end)
	if not ok then
		warn(`[ValleyArt] the hills couldn't be built: {err}`)
	end
end

-- An invisible wall round the valley at the hills' crest: walk up the
-- slopes, but not over them and off the world (the old greybox hills were
-- solid blocks).
local function boundary(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Boundary"
	local R, segments = PlotLayout.HILLS_RADIUS, 72
	local length = 2 * math.pi * R / segments + 2
	for i = 0, segments - 1 do
		local angle = 360 * i / segments
		local p = polar(angle, R, 100)
		part({ Name = "Wall", Size = Vector3.new(2, 200, length), CFrame = CFrame.lookAt(p, p + direction(angle + 90)),
			Transparency = 1, CanQuery = false, CanTouch = false, CastShadow = false }, folder)
	end
	folder.Parent = parent
end

------------------------------------------------------------------------
-- The tunnel's mouth

local function roadSign(at: CFrame, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "CitySign"
	for _, x in { -2.6, 2.6 } do
		Parts.cylinder("SignPost", at * CFrame.new(x, 4.5, 0), 0.4, 9, { Color = Color3.fromRGB(150, 150, 150) }, model)
	end
	local board = part({ Name = "SignBoard", Size = Vector3.new(7.6, 3.6, 0.3), CFrame = at * CFrame.new(0, 7.4, -0.36), Color = Color3.fromRGB(36, 112, 64) }, model)
	prop({ Name = "SignEdge", Size = Vector3.new(7.9, 3.9, 0.22), CFrame = at * CFrame.new(0, 7.4, -0.15), Color = WHITE }, model)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- (toward the valley)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.5
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = WHITE
	text.Text = "↑ THE CITY\ntrucks only"
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0.1, 0), UDim.new(0.1, 0)
	padding.Parent = text
	text.Parent = gui
	gui.Parent = board
	model.Parent = parent
	return model
end

local function tunnel(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "TunnelMouth"
	local mouth = CFrame.new(0, 0, HIGHWAY.to) -- (the arch's front faces the valley, −Z)
	if not Meshes.make("TunnelArch", mouth, 1, model) then
		-- (until the props are imported: two piers and a lintel)
		for _, x in { -1, 1 } do
			part({ Name = "Pier", Size = Vector3.new(10, 30, 3), CFrame = mouth * CFrame.new(x * 20, 15, 1.5), Color = COLORS.stone or Color3.fromRGB(176, 168, 152) }, model)
		end
		part({ Name = "Lintel", Size = Vector3.new(50, 6, 3), CFrame = mouth * CFrame.new(0, 33, 1.5), Color = Color3.fromRGB(176, 168, 152) }, model)
	end
	-- (the dark inside: you see into it, not through it)
	part({ Name = "Tunnel", Size = Vector3.new(30, 30, 60), CFrame = mouth * CFrame.new(0, 15, 34), Color = Color3.fromRGB(20, 20, 22), CanCollide = false, CastShadow = false }, model)
	part({ Name = "TunnelRoad", Size = Vector3.new(HIGHWAY.width, 0.42, 40), CFrame = mouth * CFrame.new(0, 0.21, 20), Color = COLORS.road }, model)
	for _, x in { -1, 1 } do
		PlazaArt.lamp(mouth * CFrame.new(x * 21, 0, -6), model, false)
	end
	roadSign(CFrame.new(HIGHWAY.width / 2 + 6, 0, HIGHWAY.to - 40), model)
	model.Parent = parent
end

------------------------------------------------------------------------
-- The woods between the farms

-- Whether a tree's trunk here would stand clear of every hedge and the highway.
local function clearForTree(p: Vector3): boolean
	if p.Z > 0 and math.abs(p.X) < HIGHWAY.width / 2 + ValleyArt.WOODS_CLEAR then
		return false
	end
	for index = 1, PlotLayout.COUNT do
		local q = PlotLayout.frame(index):PointToObjectSpace(p)
		if q.Z > -ValleyArt.WOODS_CLEAR and q.Z < PlotLayout.DEPTH + ValleyArt.WOODS_CLEAR
			and math.abs(q.X) < PlotLayout.WIDTH / 2 + 3 + ValleyArt.WOODS_CLEAR then
			return false
		end
	end
	local r = Vector3.new(p.X, 0, p.Z).Magnitude
	return r > PlotLayout.SIDEWALK.radius + 20 and r < PlotLayout.BACK_TRAIL.radius - PlotLayout.BACK_TRAIL.width / 2 - 10
end
ValleyArt.clearForTree = clearForTree

local function woods(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Woods"
	for gap = 0, PlotLayout.COUNT - 1 do
		local bisector = gap * 45
		local across = direction(bisector + 90)
		for step = 0, 5 do
			local radius = 365 + step * 40
			local trees = 3 + math.floor(noise(gap, step) * 3)
			local placed = {}
			for t = 1, trees * 4 do
				if #placed >= trees then
					break
				end
				local offset = (noise(gap * 7 + t, step) * 2 - 1) * (0.383 * radius - 100)
				local p = polar(bisector, radius + (noise(step, gap * 3 + t) - 0.5) * 24) + across * offset
				local spaced = true
				for _, other in placed do
					if (other - p).Magnitude < 10 then
						spaced = false
					end
				end
				if spaced and clearForTree(p) then
					table.insert(placed, p)
					local kind = if noise(t, gap + step) < 0.45 then "PineTree" else "OakTree"
					PlazaArt.tree(kind, CFrame.new(p) * CFrame.Angles(0, noise(gap, t) * math.pi * 2, 0), 0.85 + noise(t, step) * 0.35, folder)
				end
			end
			-- bushes at the clump's feet
			for b = 1, 2 do
				local spot = placed[b]
				if spot then
					local p = spot + direction(noise(b, gap) * 360) * 5
					if clearForTree(p) then
						local model = Instance.new("Model")
						model.Name = "Bush"
						bush(CFrame.new(p) * CFrame.Angles(0, noise(gap, b) * 6.28, 0), 1.1 + noise(b, step) * 0.4, model)
						model.Parent = folder
					end
				end
			end
		end
	end
	folder.Parent = parent
end

------------------------------------------------------------------------
-- The back trail's cover and lamps

local function trail(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "TrailCover"
	local R, half = PlotLayout.BACK_TRAIL.radius, PlotLayout.BACK_TRAIL.width / 2
	local function offHighway(angle: number, margin: number): boolean
		local a = angle % 360
		return a > margin and a < 360 - margin
	end
	local k = 0
	for angle = ValleyArt.TRAIL_COVER / 2, 360, ValleyArt.TRAIL_COVER do
		k += 1
		if offHighway(angle, 4) then
			local inner = k % 4 == 0 -- (every fourth just behind the farms' back fences)
			local radius = if inner then R - half - 4 else R + half + 4
			local p = polar(angle, radius)
			local along = CFrame.lookAt(p, p + direction(angle)) -- (its X runs along the trail)
			local model = Instance.new("Model")
			model.Name = "Cover"
			if k % 3 ~= 1 then
				-- a pair of hay bales, one tipped against the other
				if Meshes.make("HayBale", along * CFrame.new(-1.6, 0, 0), 1.2, model) then
					Meshes.make("HayBale", along * CFrame.new(1.7, 0, 0.3) * CFrame.Angles(0, math.rad(12), 0), 1.2, model)
					if k % 3 == 0 then
						Meshes.make("HayBale", along * CFrame.new(0, 2.2, 0.1) * CFrame.Angles(0, math.rad(-6), 0), 1.2, model)
					end
				end
				-- (you can hide behind it: solid)
				part({ Name = "CoverBlock", Size = Vector3.new(7.4, 2.2, 2.4), CFrame = along * CFrame.new(0, 1.1, 0.1), Transparency = 1, CanQuery = false, CanTouch = false }, model)
			end
			if k % 3 ~= 2 then
				bush(along * CFrame.new(if k % 3 == 1 then 0 else 5.5, 0, 0) * CFrame.Angles(0, angle, 0), 1.6, model)
			end
			model.Parent = folder
		end
	end
	for angle = ValleyArt.TRAIL_LAMPS * 0.83, 360, ValleyArt.TRAIL_LAMPS do
		if offHighway(angle, 5) then
			local p = polar(angle, R + half + 3)
			PlazaArt.lamp(CFrame.lookAt(p, Vector3.new(0, 0, 0)), folder, false)
		end
	end
	folder.Parent = parent
end

------------------------------------------------------------------------
-- The ring road's paint and kerbs

-- Where each farm's path crosses the ring road (degrees from north).
local function crossings(): { number }
	local list = {}
	for index = 1, PlotLayout.COUNT do
		local gate = PlotLayout.visitWorld(index)
		local start = polar(PlotLayout.angle(index), PlotLayout.TOWN.walkRadius + 3.5)
		local t = (PlotLayout.RING_ROAD.radius - PlotLayout.TOWN.walkRadius - 3.5) / ((gate - start).Magnitude)
		local p = start:Lerp(gate, t)
		table.insert(list, math.deg(math.atan2(p.X, p.Z)) % 360)
	end
	return list
end
ValleyArt.crossings = crossings

local function nearCrossing(angle: number, list, margin: number): boolean
	for _, c in list do
		local d = math.abs((angle - c + 180) % 360 - 180)
		if d < margin then
			return true
		end
	end
	return false
end

local function road(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "RoadMarkings"
	local road = PlotLayout.RING_ROAD
	local list = crossings()
	local top = ValleyArt.MARKINGS_TOP
	-- the dashed line down the middle: 3 studs of paint every 8
	local stepAngle = math.deg(8 / road.radius)
	for angle = 0, 360 - stepAngle / 2, stepAngle do
		if not nearCrossing(angle, list, 2.4) then
			local p = polar(angle, road.radius, top - 0.03)
			prop({ Name = "Dash", Size = Vector3.new(0.5, 0.06, 3), CFrame = CFrame.lookAt(p, p + direction(angle + 90)), Color = WHITE }, folder)
		end
	end
	-- a zebra crossing at each farm's path
	for _, angle in list do
		for i = 0, 8 do
			local p = polar(angle, road.radius - road.width / 2 + 1.6 + i * 2, top - 0.03)
			prop({ Name = "Zebra", Size = Vector3.new(1.0, 0.06, 7), CFrame = CFrame.lookAt(p, p + direction(angle + 90)), Color = WHITE }, folder)
		end
	end
	-- kerbs along both edges (not across the crossings)
	local segments = 120
	for _, spec in { { radius = road.radius - road.width / 2 - 0.4, width = 0.8 }, { radius = road.radius + road.width / 2 + 0.5, width = 1.0, highway = true } } do
		local length = 2 * math.pi * spec.radius / segments + 0.4
		for i = 0, segments - 1 do
			local angle = 360 * i / segments
			local junction = spec.highway and math.abs((angle + 180) % 360 - 180) < 4 -- (where the highway leaves)
			if not nearCrossing(angle, list, 2.2) and not junction then
				local p = polar(angle, spec.radius, 0.25)
				prop({ Name = "Kerb", Size = Vector3.new(spec.width, 0.5, length), CFrame = CFrame.lookAt(p, p + direction(angle + 90)), Color = KERB }, folder)
			end
		end
	end
	folder.Parent = parent
end

function ValleyArt.build(world: Instance)
	hills()
	local valley = Instance.new("Folder")
	valley.Name = "Countryside"
	boundary(valley)
	tunnel(valley)
	woods(valley)
	trail(valley)
	road(valley)
	valley.Parent = world
end

return ValleyArt
