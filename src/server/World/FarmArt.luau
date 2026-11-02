-- How a farm's field looks (docs/ArtDirection.md §7): the tiles, the
-- edging round each 2×2 block, overgrown land with its 4 obstacles (a
-- stump, a rock, weeds, a bush: what you clear with a Land Permit), and
-- the crops at each growth stage. WorldBuilder lays an empty field;
-- FieldService and LandService call the rest as the owner's farm changes.
--
-- Each tile part carries what the client needs as attributes (so the field
-- never needs a state sync): Tile, Block, Open, Fresh, and while planted
-- Crop, Stage ("Seed" · "Sprout" · "Growing" · "Ripe"), Yield (how many it
-- gives), RipeAt (server time), Watered, Leave. The Field folder carries
-- FieldLevel: its soil, beds and drip lines (§4.1c).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crops = require(ReplicatedStorage.Shared.Config.Crops)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local GrowthRules = require(ReplicatedStorage.Shared.GrowthRules)
local LandRules = require(ReplicatedStorage.Shared.LandRules)
local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
local Parts = require(script.Parent.Parts)

local COLORS = Parts.COLORS
local part, prop, cylinder, ball = Parts.part, Parts.prop, Parts.cylinder, Parts.ball

local FarmArt = {}

FarmArt.OBSTACLES = { "Stump", "Rock", "Weeds", "Bush" } -- (Config/Land.OBSTACLES of them, cleared in this order)

local FIELD = PlotLayout.PLOT.field
local TILE_TOP = 0.5 -- a tile's top above the yard

------------------------------------------------------------------------
-- Crops: a patch's plants stand in rows on the tile's three ridges, and a
-- ripe patch shows every carrot, cob or pumpkin it gives (tile.yield): what
-- you see is what you harvest (docs/ArtDirection.md §7). About 20 parts a
-- patch at most, for phones (a full field is 64 of them, §10).

-- Each crop's produce colour: its fruit in the field, on crates and shelves.
local FRUIT = {
	Carrot = Color3.fromRGB(242, 140, 40),
	Wheat = Color3.fromRGB(232, 198, 98),
	Potato = Color3.fromRGB(176, 128, 80),
	Lettuce = Color3.fromRGB(150, 210, 96),
	Corn = Color3.fromRGB(245, 211, 61),
	Onion = Color3.fromRGB(206, 150, 84),
	Strawberry = Color3.fromRGB(226, 52, 62),
	Tomato = Color3.fromRGB(222, 62, 46),
	BellPepper = Color3.fromRGB(242, 200, 44),
	Pumpkin = Color3.fromRGB(240, 127, 30),
	Watermelon = Color3.fromRGB(58, 142, 64),
	Blueberry = Color3.fromRGB(72, 92, 204),
	Pineapple = Color3.fromRGB(232, 182, 52),
	CocoaPod = Color3.fromRGB(196, 110, 46),
	Dragonfruit = Color3.fromRGB(232, 62, 142),
	GrapeVine = Color3.fromRGB(124, 62, 164),
	Moonmelon = Color3.fromRGB(206, 224, 255),
	Starfruit = Color3.fromRGB(252, 222, 84),
	GoldenApple = Color3.fromRGB(236, 172, 22),
	CrystalRose = Color3.fromRGB(150, 222, 255),
	PhoenixPepper = Color3.fromRGB(255, 96, 32),
	DragonsEyePumpkin = Color3.fromRGB(156, 42, 124),
}
local ORANGE = FRUIT.Carrot
local WOOD = Color3.fromRGB(150, 112, 70)
local BARK = Color3.fromRGB(112, 82, 54)
local CANOPY = Color3.fromRGB(64, 138, 56)
local RIPE_LEAF = Color3.fromRGB(150, 156, 70) -- (potato and onion tops yellow when they're ready)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

-- The colour a crop's produce shows in (crates, shelves).
function FarmArt.cropColor(cropId: string): Color3
	return FRUIT[cropId] or ORANGE
end

-- The stage a tile shows.
function FarmArt.stage(tile): string
	if GrowthRules.isRipe(tile) then
		return "Ripe"
	elseif tile.regrowing or tile.progress >= 0.5 then
		return "Growing" -- (a regrowing plant stays a full plant between harvests)
	elseif tile.progress >= 0.15 then
		return "Sprout"
	end
	return "Seed"
end

local function extra(p: BasePart, props)
	for key, value in props or {} do
		p[key] = value
	end
	return p
end

local function block(model, name: string, cframe: CFrame, size: Vector3, color: Color3, props)
	return extra(prop({ Name = name, Size = size, CFrame = cframe, Color = color, CastShadow = false }, model), props)
end

-- An ellipsoid (a block drawn as a sphere stretched to its size).
local function egg(model, name: string, cframe: CFrame, size: Vector3, color: Color3, props)
	local p = block(model, name, cframe, size, color, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function orb(model, name: string, cframe: CFrame, diameter: number, color: Color3, props)
	return extra(ball(name, cframe, diameter, { Color = color, CastShadow = false }, model), props)
end

-- A cylinder standing along `cframe`'s Y axis.
local function rod(model, name: string, cframe: CFrame, diameter: number, length: number, color: Color3, props)
	return extra(cylinder(name, cframe, diameter, length, { Color = color, CastShadow = false }, model), props)
end

-- A flat leaf rising from `base`: turned `yaw` degrees, leaning `tilt`.
local function leaf(model, base: CFrame, yaw: number, tilt: number, size: Vector3, color: Color3?)
	local cf = base * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(tilt), 0, 0) * CFrame.new(0, size.Y / 2, 0)
	return block(model, "Leaf", cf, size, color or COLORS.leaf)
end

-- A tuft of grass or weeds: `count` blades round `base`.
local function tuft(model, base: CFrame, count: number, height: number, width: number)
	for i = 1, count do
		leaf(model, base, i * 360 / count, 22, Vector3.new(0.25, height, width), if i % 2 == 0 then COLORS.leafDark else COLORS.leaf)
	end
end

local RIDGES = { -3.2, 0, 3.2 } -- across the tile (FarmArt.setTileOpen): the ridges run along its Z
local ON_RIDGE = 0.42 -- a ridge's top, above the tile's
local ROW = 9.4 -- studs along a ridge that plants spread over

-- n spread over the ridges as evenly as possible (k = 3: all three; 2: the
-- outer two; 1: the middle), extra ones to the middle first. Returns the
-- count on ridges 1, 2, 3.
local function split(n: number, k: number): { number }
	local use = if k == 1 then { 2 } elseif k == 2 then { 1, 3 } else { 1, 2, 3 }
	local order = if k == 1 then { 2 } elseif k == 2 then { 1, 3 } else { 2, 1, 3 }
	local counts = { 0, 0, 0 }
	for _, r in use do
		counts[r] = n // #use
	end
	for i = 1, n % #use do
		counts[order[i]] += 1
	end
	return counts
end

-- Where n plants stand: spread along the ridges' tops, a little uneven.
local function spots(base: CFrame, n: number, k: number?): { CFrame }
	local out = {}
	for r, count in split(n, k or 3) do
		for i = 1, count do
			local z = -ROW / 2 + (i - 0.5) * ROW / count
			local jitter = ((r * 7 + i * 13) % 5 - 2) * 0.1
			table.insert(out, base * CFrame.new(RIDGES[r] + jitter, ON_RIDGE, z - jitter) * CFrame.Angles(0, math.rad(r * 67 + i * 41), 0))
		end
	end
	return out
end

-- A point on the surface of an egg `size` big centred on `centre`, at
-- `angle` round it and `up` (−1 to 1) of the way up, pushed `out` studs
-- further (negative: sunk in).
local function onEgg(centre: CFrame, size: Vector3, angle: number, up: number, out: number): CFrame
	local ring = math.sqrt(math.max(0, 1 - up * up))
	local radius = (size.X / 2) * ring + out
	return centre * CFrame.new(math.cos(angle) * radius, up * size.Y / 2, math.sin(angle) * radius)
end

-- A ribbed pumpkin `width` across on `base` (four long eggs turned 45°
-- apart, so the ribs dip where they cross), a curled stem. Returns its middle.
local function pumpkin(model, base: CFrame, width: number, height: number, body: Color3, shade: Color3, stem: Color3): CFrame
	local centre = base * CFrame.new(0, height / 2, 0)
	for i = 0, 3 do
		egg(model, "Fruit", centre * CFrame.Angles(0, math.rad(i * 45), 0), Vector3.new(width, height, width * 0.58), if i % 2 == 0 then body else shade,
			{ CastShadow = true })
	end
	rod(model, "Stem", centre * CFrame.new(0.05, height / 2 + 0.25, 0) * CFrame.Angles(0, 0, math.rad(-16)), width * 0.12, 0.8, stem)
	return centre
end

-- A long melon lying on `base` along Z (round across: size.X = size.Y), its
-- stripes running end to end. Returns its middle.
local function melon(model, base: CFrame, size: Vector3, body: Color3, stripe: Color3, props, stripeProps)
	local centre = base * CFrame.new(0, size.Y / 2 - 0.1, 0)
	egg(model, "Fruit", centre, size, body, props)
	for i = 0, 3 do
		-- (thin eggs as long as the melon, turned round its length: each shows as two stripes)
		egg(model, "Stripe", centre * CFrame.Angles(0, 0, math.rad(i * 45)), Vector3.new(size.X * 0.14, size.Y + 0.08, size.Z + 0.06), stripe, stripeProps)
	end
	return centre
end

-- A leafy clump `size` big round `centre`: a big egg and `n − 1` smaller
-- ones bulging out of its top in two greens, so it reads as leaves, not a
-- ball.
local function foliage(model, centre: CFrame, size: Vector3, n: number, dark: Color3?, light: Color3?)
	dark, light = dark or COLORS.leafDark, light or COLORS.leaf
	egg(model, "Leaves", centre * CFrame.new(0, -size.Y * 0.1, 0), size * 0.8, dark, { CastShadow = true })
	for k = 1, n - 1 do
		local a = k / (n - 1) * math.pi * 2 + 0.7
		local at = centre * CFrame.new(math.cos(a) * size.X * 0.24, size.Y * (0.1 + (k % 2) * 0.1), math.sin(a) * size.Z * 0.24)
		egg(model, "Leaves", at, size * 0.56, if k % 2 == 0 then dark else light)
	end
end

-- Big vine leaves round a patch's middle, and two curling runners.
local function vineLeaves(model, base: CFrame, s: number, count: number, color: Color3?)
	for i = 1, count do
		local at = base * CFrame.Angles(0, math.rad(i * 360 / count + 20), 0) * CFrame.new(0, 0.3, 3.3 * s)
		egg(model, "Leaf", at * CFrame.Angles(math.rad(-10), 0, 0), Vector3.new(2.5 * s, 0.32, 2.1 * s), color or (if i % 2 == 0 then COLORS.leafDark else COLORS.leaf))
	end
	for _, a in { 50, 230 } do
		local runner = base * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 0.25, 2.2 * s) * CFrame.Angles(math.rad(90), 0, 0)
		rod(model, "Runner", runner, 0.22, 2.6 * s, Color3.fromRGB(86, 140, 60))
	end
end

-- A small tree: a trunk and a leafy canopy. Returns the canopy's middle and
-- size, for fruit on it.
local function tree(model, base: CFrame, s: number, height: number, canopy: Color3?): (CFrame, Vector3)
	rod(model, "Trunk", base * CFrame.new(0, height / 2, 0), 0.7 * s, height, BARK, { CastShadow = true })
	local size = Vector3.new(4.8, 3.4, 4.8) * s
	local centre = base * CFrame.new(0, height + size.Y * 0.3, 0)
	foliage(model, centre, size, 4, canopy or CANOPY, COLORS.leaf)
	return centre, size
end

-- Seeds just sown: a dark line down each ridge.
local function sown(model, base: CFrame)
	for _, x in RIDGES do
		block(model, "Seeds", base * CFrame.new(x, ON_RIDGE + 0.03, 0), Vector3.new(0.5, 0.08, ROW), COLORS.wetSoil)
	end
end

-- Seedlings: two leaves each, two to a ridge.
local function seedlings(model, base: CFrame, s: number)
	for _, at in spots(base, 6, 3) do
		leaf(model, at, 0, 30, Vector3.new(0.15, 1.1 * s, 0.5 * s))
		leaf(model, at, 180, 30, Vector3.new(0.15, 1.1 * s, 0.5 * s), COLORS.leafDark)
	end
end

local BUILDERS = {}

-- Carrots: their orange shoulders out of the ridge under bushy fronds.
function BUILDERS.Carrot(model, base, ripe, _s, n)
	for i, at in spots(base, n, 3) do
		if ripe then
			rod(model, "Root", at * CFrame.new(0, 0.14, 0), 0.82, 0.62, ORANGE)
		end
		local top = at * CFrame.new(0, if ripe then 0.4 else 0.05, 0)
		for k = 0, 2 do
			leaf(model, top, i * 50 + k * 120, 30, Vector3.new(0.05, if ripe then 1.6 else 1.2, 0.62), if k == 1 then COLORS.leafDark else Color3.fromRGB(96, 178, 70))
		end
	end
end

-- Wheat: green rows along the ridges while it grows; ripe, it stands in
-- golden sheaves, one for each sheaf it gives: a bundle of stalks tied with
-- twine, the ears splaying out of its top (like 🌾, and what a thief carries).
function BUILDERS.Wheat(model, base, ripe, _s, n)
	if not ripe then
		for _, x in RIDGES do
			egg(model, "Stalks", base * CFrame.new(x, ON_RIDGE + 0.55, 0), Vector3.new(1.0, 1.9, ROW - 0.4), COLORS.leaf)
		end
		return
	end
	for i, at in spots(base, n, 3) do
		-- (each stalk a straight line from one side of the foot to the other
		-- side of the top, so they cross at the tie: an hourglass)
		local waist = 1.4
		for k = 0, 4 do
			local a = math.rad(k * 72 + i * 25)
			local foot = Vector3.new(math.cos(a) * 0.7, 0, math.sin(a) * 0.7)
			local head = Vector3.new(-math.cos(a) * 0.78, 3.0, -math.sin(a) * 0.78)
			local mid = (foot + head) / 2
			rod(model, "Stalk", at * CFrame.lookAt(mid, head) * CFrame.Angles(math.rad(-90), 0, 0), 0.24, (head - foot).Magnitude, Color3.fromRGB(206, 168, 76))
			egg(model, "Ear", at * CFrame.lookAt(head, head + (head - foot)) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, 0.42, 0), Vector3.new(0.36, 1.0, 0.36),
				if k % 2 == 0 then Color3.fromRGB(236, 196, 92) else Color3.fromRGB(214, 168, 64))
		end
		rod(model, "Twine", at * CFrame.new(0, waist, 0), 0.62, 0.3, Color3.fromRGB(150, 104, 52))
	end
end

-- Potatoes: three leafy plants; ripe, their tops yellowing and the potatoes
-- dug up in the furrows beside them.
function BUILDERS.Potato(model, base, ripe, _s, n)
	for r, x in RIDGES do
		local at = base * CFrame.new(x, ON_RIDGE, ({ -2.4, 1.8, -0.8 })[r])
		foliage(model, at * CFrame.new(0, 1.0, 0), Vector3.new(2.7, 2.0, 2.7), 3, if ripe then Color3.fromRGB(116, 132, 58) else COLORS.leafDark, if ripe then RIPE_LEAF else COLORS.leaf)
	end
	if ripe then
		local tones = { Color3.fromRGB(176, 128, 80), Color3.fromRGB(160, 114, 70), Color3.fromRGB(188, 142, 92) }
		for i, at in spots(base, n, 3) do
			-- (in the furrow beside its ridge, half in the soil)
			local p = base:PointToObjectSpace(at.Position)
			local side = if i % 2 == 0 then 1.3 else -1.3
			egg(model, "Potato", base * CFrame.new(p.X + side, 0.14, p.Z) * CFrame.Angles(0, i * 0.9, 0.25), Vector3.new(0.9, 0.6, 0.7), tones[i % 3 + 1])
		end
	end
end

-- Lettuces: a pale heart cupped in four darker leaves.
function BUILDERS.Lettuce(model, base, ripe, _s, n)
	local d = if ripe then 2.9 else 1.6
	for i, at in spots(base, n, if n <= 4 then 2 else 3) do
		egg(model, "Heart", at * CFrame.new(0, d * 0.32, 0), Vector3.new(d * 0.66, d * 0.58, d * 0.66), Color3.fromRGB(184, 228, 124))
		for k = 0, 3 do
			local cf = at * CFrame.Angles(0, math.rad(i * 40 + k * 90), 0) * CFrame.new(0, d * 0.22, d * 0.26) * CFrame.Angles(math.rad(36), 0, 0)
			egg(model, "Leaf", cf, Vector3.new(d * 0.72, d * 0.55, d * 0.15), if k % 2 == 0 then Color3.fromRGB(104, 176, 68) else Color3.fromRGB(128, 196, 84))
		end
	end
end

-- Corn: a tall stalk on each ridge with its tassel; ripe, two cobs on each,
-- standing out of their green husks.
function BUILDERS.Corn(model, base, ripe, _s, n)
	local stalks = if ripe then math.max(1, math.ceil(n / 2)) else 3
	local height = if ripe then 7 else 4
	local left = n
	for i, at in spots(base, stalks, 3) do
		block(model, "Stalk", at * CFrame.new(0, height / 2, 0), Vector3.new(0.42, height, 0.42), Color3.fromRGB(96, 156, 64))
		leaf(model, at * CFrame.new(0, height * 0.3, 0), i * 90, 44, Vector3.new(0.1, 2.8, 0.6), COLORS.leafDark)
		leaf(model, at * CFrame.new(0, height * 0.55, 0), i * 90 + 180, 44, Vector3.new(0.1, 2.4, 0.55))
		if ripe then
			egg(model, "Tassel", at * CFrame.new(0, height + 0.4, 0), Vector3.new(0.3, 1.0, 0.3), Color3.fromRGB(206, 176, 104))
			local cobs = if i == stalks then left else math.min(2, left)
			left -= cobs
			for c = 1, cobs do
				local cob = at * CFrame.new(0, height * (0.34 + c * 0.14), 0) * CFrame.Angles(0, math.rad(i * 90 + c * 160), 0) * CFrame.new(0.45, 0, 0) * CFrame.Angles(0, 0, math.rad(-14))
				egg(model, "Cob", cob * CFrame.new(0, 0.2, 0), Vector3.new(0.62, 1.7, 0.62), Color3.fromRGB(240, 204, 60))
				egg(model, "Husk", cob * CFrame.new(0, -0.25, 0), Vector3.new(0.74, 1.35, 0.74), COLORS.leaf)
			end
		end
	end
end

-- Onions: bulbs half out of the ridge; ripe, their tops flopped over.
function BUILDERS.Onion(model, base, ripe, _s, n)
	for i, at in spots(base, n, 3) do
		if ripe then
			egg(model, "Bulb", at * CFrame.new(0, 0.22, 0), Vector3.new(1.0, 0.85, 1.0), FRUIT.Onion)
			rod(model, "Top", at * CFrame.new(0, 0.62, 0) * CFrame.Angles(math.rad(62), math.rad(i * 70), 0) * CFrame.new(0, 0.6, 0), 0.15, 1.3, RIPE_LEAF)
		else
			for k = -1, 1, 2 do
				rod(model, "Leaf", at * CFrame.Angles(0, 0, math.rad(k * 12)) * CFrame.new(0, 0.75, 0), 0.12, 1.5, COLORS.leaf)
			end
		end
	end
end

-- Strawberries: low plants of three spreading leaves, berries hanging out
-- round their edges (a punnet's worth a plant); between pickings, white
-- flowers.
function BUILDERS.Strawberry(model, base, ripe, _s, n)
	for i, at in spots(base, n, 3) do
		for k = 0, 2 do
			local cf = at * CFrame.Angles(0, math.rad(i * 40 + k * 120), 0) * CFrame.new(0, 0.36, 0.6) * CFrame.Angles(math.rad(-16), 0, 0)
			egg(model, "Leaf", cf, Vector3.new(1.4, 0.36, 1.2), if k == 1 then COLORS.leaf else COLORS.leafDark)
		end
		for k = 1, if ripe then 3 else 2 do
			local a = math.rad(i * 40 + k * 120 + 60)
			if ripe then
				egg(model, "Berry", at * CFrame.new(math.cos(a) * 1.25, 0.26, math.sin(a) * 1.25) * CFrame.Angles(math.rad(10), 0, 0), Vector3.new(0.64, 0.76, 0.64), FRUIT.Strawberry)
			else
				orb(model, "Flower", at * CFrame.new(math.cos(a) * 0.6, 0.62, math.sin(a) * 0.6), 0.34, Color3.fromRGB(250, 250, 240))
			end
		end
	end
end

-- Tomatoes: tall leafy plants tied to stakes, tomatoes hanging on them.
function BUILDERS.Tomato(model, base, ripe, _s, n)
	local plants = if n > 6 then 3 else 2
	local left = n
	for p, at in spots(base, plants, if plants == 2 then 2 else 3) do
		block(model, "Stake", at * CFrame.new(0.15, 2.4, 0), Vector3.new(0.22, 4.8, 0.22), WOOD)
		local bush = at * CFrame.new(0, 2.0, 0)
		local size = Vector3.new(2.3, 3.6, 2.3)
		foliage(model, bush, size, 3)
		local count = if ripe then (if p == plants then left else math.ceil(left / (plants - p + 1))) else 2
		left -= if ripe then count else 0
		for k = 1, count do
			local where = onEgg(bush, size * 0.85, math.rad(p * 50 + k * 360 / count), 0.45 - (k % 3) * 0.4, 0.05)
			if ripe then
				orb(model, "Tomato", where, 0.8, FRUIT.Tomato)
			else
				orb(model, "Flower", where, 0.32, Color3.fromRGB(250, 214, 60))
			end
		end
	end
end

-- Bell peppers: low leafy bushes, big yellow peppers hanging off them.
function BUILDERS.BellPepper(model, base, ripe, s, n)
	local plants = if n > 4 then 3 else 2
	local left = n
	for p, at in spots(base, plants, if plants == 2 then 2 else 3) do
		local bush = at * CFrame.new(0, 1.35 * s, 0)
		local size = Vector3.new(2.8, 2.3, 2.8) * s
		foliage(model, bush, size, 3)
		if ripe then
			local count = if p == plants then left else math.ceil(left / (plants - p + 1))
			left -= count
			for k = 1, count do
				local where = onEgg(bush, size * 0.85, math.rad(p * 70 + k * 360 / count), -0.3, 0.12)
				egg(model, "Pepper", where, Vector3.new(0.95, 1.15, 0.95) * s, FRUIT.BellPepper)
				rod(model, "Stem", where * CFrame.new(0, 0.66 * s, 0), 0.16, 0.34, COLORS.leaf)
			end
		end
	end
end

-- A pumpkin patch: vines and big leaves, one big ribbed pumpkin (two on a
-- bumper patch).
function BUILDERS.Pumpkin(model, base, ripe, s, n)
	vineLeaves(model, base, s, 4)
	if not ripe then
		orb(model, "Fruit", base * CFrame.new(0, 0.9, 0), 1.6 * s, COLORS.leaf)
		return
	end
	local width = (if n == 1 then 3.0 else 2.4) * s
	for i = 1, n do
		local at = base * CFrame.new(0, 0, if n == 1 then 0 else (i - 1.5) * 5.2) * CFrame.Angles(0, math.rad(i * 50), 0)
		pumpkin(model, at, width, width * 0.68, FRUIT.Pumpkin, Color3.fromRGB(226, 112, 24), Color3.fromRGB(104, 112, 52))
	end
end

-- A watermelon patch: vines and leaves, one big striped melon (two on a
-- bumper patch).
function BUILDERS.Watermelon(model, base, ripe, s, n)
	vineLeaves(model, base, s, 4)
	local size = (if ripe then (if n == 1 then Vector3.new(2.3, 2.3, 3.6) else Vector3.new(1.9, 1.9, 3.0)) else Vector3.new(1.1, 1.1, 1.6)) * s
	for i = 1, if ripe then n else 1 do
		local at = base * CFrame.new(if n == 1 or not ripe then 0 else (i - 1.5) * 3.4, 0, 0) * CFrame.Angles(0, math.rad(i * 25 - 12), 0)
		melon(model, at, size, Color3.fromRGB(104, 168, 78), Color3.fromRGB(40, 104, 50), { CastShadow = true })
	end
end

-- A blueberry bush, clusters of berries all over it (a punnet's worth each).
function BUILDERS.Blueberry(model, base, ripe, s, n)
	local bush = base * CFrame.new(0, 1.8 * s, 0)
	local size = Vector3.new(4.4, 3.4, 4.4) * s
	foliage(model, bush, size, 5, COLORS.leafDark, CANOPY)
	if not ripe then
		return
	end
	local blues = { Color3.fromRGB(72, 92, 204), Color3.fromRGB(58, 72, 176), Color3.fromRGB(92, 110, 214) }
	for k = 1, n do
		local cluster = onEgg(bush, size * 0.88, math.rad(k * 360 / n + 15), 0.3 - (k % 2) * 0.5, 0.05)
		for j = 0, 2 do
			orb(model, "Berry", cluster * CFrame.new(math.cos(j * 2.1) * 0.3 * s, j * 0.14 - 0.12, math.sin(j * 2.1) * 0.3 * s), 0.5 * s, blues[j + 1])
		end
	end
end

-- Pineapples: a rosette of long spiky leaves, the fruit standing up in it
-- under its own crown.
function BUILDERS.Pineapple(model, base, ripe, s, n)
	local leafColor = Color3.fromRGB(92, 140, 84)
	for p, at in spots(base, if ripe then n else 2, 2) do
		for k = 0, 5 do
			leaf(model, at * CFrame.new(0, 0.1, 0), p * 30 + k * 60, 55, Vector3.new(0.12, 2.3 * s, 0.5 * s), if k % 2 == 0 then leafColor else COLORS.leafDark)
		end
		if ripe then
			local fruit = at * CFrame.new(0, 1.25 * s, 0)
			egg(model, "Fruit", fruit, Vector3.new(1.3, 1.85, 1.3) * s, Color3.fromRGB(214, 152, 46), { Material = Enum.Material.Cobblestone })
			for k = 0, 4 do
				leaf(model, fruit * CFrame.new(0, 0.8 * s, 0), k * 72, 20, Vector3.new(0.1, 1.4 * s, 0.42 * s), if k % 2 == 0 then leafColor else COLORS.leafDark)
			end
		end
	end
end

-- A cocoa tree: the pods grow on its trunk.
function BUILDERS.CocoaPod(model, base, ripe, s, n)
	local height = 3.6 * s
	tree(model, base, s * 0.8, height)
	if not ripe then
		return
	end
	for k = 1, n do
		local a = math.rad(k * 360 / n + 30)
		local at = base * CFrame.new(math.cos(a) * 0.6 * s, height * (0.3 + (k % 3) * 0.18), math.sin(a) * 0.6 * s) * CFrame.Angles(0, -a, math.rad(10))
		egg(model, "Pod", at, Vector3.new(0.8, 1.55, 0.8) * s, FRUIT.CocoaPod)
	end
end

-- A dragonfruit cactus: long ridged green stems climbing a post and hanging
-- over its top, pink fruit at their tips.
function BUILDERS.Dragonfruit(model, base, ripe, s, n)
	local height = 3.6 * s
	block(model, "Post", base * CFrame.new(0, height / 2, 0), Vector3.new(0.5, height, 0.5), WOOD, { CastShadow = true })
	block(model, "Stem", base * CFrame.new(0, height * 0.55, 0.3) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(0.45, height * 1.0, 0.45), Color3.fromRGB(78, 150, 72))
	local top = base * CFrame.new(0, height, 0)
	local stems = math.max(4, n)
	for k = 1, stems do
		local stem = top * CFrame.Angles(0, math.rad(k * 360 / stems), 0) * CFrame.Angles(math.rad(-115), 0, 0) * CFrame.new(0, 1.2 * s, 0)
		block(model, "Stem", stem * CFrame.Angles(0, math.rad(45), 0), Vector3.new(0.5 * s, 2.6 * s, 0.5 * s), if k % 2 == 0 then Color3.fromRGB(78, 150, 72) else Color3.fromRGB(96, 166, 84))
		if ripe and k <= n then
			local fruit = stem * CFrame.new(0, 1.6 * s, 0)
			egg(model, "Fruit", fruit, Vector3.new(1.0, 1.2, 1.0) * s, FRUIT.Dragonfruit)
			for j = -1, 1, 2 do
				egg(model, "Scale", fruit * CFrame.Angles(0, math.rad(j * 70), 0) * CFrame.new(0, 0.15 * s, -0.45 * s) * CFrame.Angles(math.rad(-30), 0, 0), Vector3.new(0.4, 0.42, 0.1) * s,
					Color3.fromRGB(150, 200, 80))
			end
		end
	end
end

-- A grape vine on a trellis: two posts, two wires, broad vine leaves along
-- the top, bunches hanging below it.
function BUILDERS.GrapeVine(model, base, ripe, s, n)
	for _, z in { -4.2, 4.2 } do
		block(model, "Post", base * CFrame.new(0, 2.1 * s, z), Vector3.new(0.35, 4.2 * s, 0.35), WOOD, { CastShadow = true })
	end
	for _, y in { 2.2, 3.7 } do
		rod(model, "Wire", base * CFrame.new(0, y * s, 0) * CFrame.Angles(math.rad(90), 0, 0), 0.06, 8.4, Color3.fromRGB(120, 120, 120))
	end
	for k = 1, 4 do
		local z = -ROW / 2 + (k - 0.5) * ROW / 4
		egg(model, "Leaf", base * CFrame.new(if k % 2 == 0 then 0.3 else -0.3, 3.85 * s, z) * CFrame.Angles(0, 0, math.rad(if k % 2 == 0 then 28 else -28)),
			Vector3.new(2.2, 0.3, 2.0) * s, if k % 2 == 0 then COLORS.leaf else COLORS.leafDark)
	end
	if not ripe then
		return
	end
	local purples = { Color3.fromRGB(124, 62, 164), Color3.fromRGB(106, 50, 146), Color3.fromRGB(140, 76, 180) }
	for k = 1, n do
		local z = -ROW / 2 + (k - 0.5) * ROW / n
		local top = base * CFrame.new(if k % 2 == 0 then 0.4 else -0.4, 3.35 * s, z)
		local j = 0
		for _, layer in { { 0, 0.32, 3 }, { -0.42, 0.2, 2 }, { -0.8, 0, 1 } } do
			for q = 1, layer[3] do
				j += 1
				local a = q / layer[3] * math.pi * 2 + k
				orb(model, "Grape", top * CFrame.new(math.cos(a) * layer[2] * s, layer[1] * s, math.sin(a) * layer[2] * s), 0.5 * s, purples[j % 3 + 1])
			end
		end
	end
end

-- The Moonmelon: a pale melon with glowing stripes among silvery leaves.
function BUILDERS.Moonmelon(model, base, ripe, s, n)
	vineLeaves(model, base, s, 4, Color3.fromRGB(150, 176, 160))
	local size = (if ripe then (if n == 1 then Vector3.new(2.5, 2.5, 3.2) else Vector3.new(2.0, 2.0, 2.6)) else Vector3.new(1.2, 1.2, 1.5)) * s
	for i = 1, if ripe then n else 1 do
		local at = base * CFrame.new(if n == 1 or not ripe then 0 else (i - 1.5) * 3.4, 0, 0)
		if ripe then
			melon(model, at, size, Color3.fromRGB(184, 206, 246), Color3.fromRGB(226, 238, 255), { CastShadow = true }, { Material = Enum.Material.Neon })
		else
			melon(model, at, size, COLORS.leaf, COLORS.leafDark)
		end
	end
end

-- A starfruit tree, golden star-shaped fruit hanging under its canopy.
function BUILDERS.Starfruit(model, base, ripe, s, n)
	local centre, size = tree(model, base, s * 0.75, 3.2 * s)
	if not ripe then
		return
	end
	for k = 1, n do
		local at = onEgg(centre, size * 0.8, math.rad(k * 360 / n + 40), -0.6, 0) * CFrame.new(0, -0.75 * s, 0)
		rod(model, "Stem", at * CFrame.new(0, 0.7 * s, 0), 0.1, 0.5 * s, BARK)
		for j = 0, 2 do
			egg(model, "Fin", at * CFrame.Angles(0, math.rad(j * 60), 0), Vector3.new(0.32, 1.45, 1.1) * s * 0.85, FRUIT.Starfruit, { Reflectance = 0.1 })
		end
	end
end

-- The Golden Apple Tree: big shiny golden apples all over its canopy.
function BUILDERS.GoldenApple(model, base, ripe, s, n)
	local centre, size = tree(model, base, s * 0.8, 3.0 * s)
	if not ripe then
		return
	end
	for k = 1, n do
		local at = onEgg(centre, size * 0.8, math.rad(k * 360 / n + 10), if k % 2 == 0 then 0.2 else -0.4, 0.15)
		orb(model, "Apple", at, 1.05 * s, FRUIT.GoldenApple, { Reflectance = 0.25 })
	end
end

-- The Crystal Rose: one great rose of glass petals round a glowing bud,
-- on a stem with two pairs of leaves.
function BUILDERS.CrystalRose(model, base, ripe, s, n)
	local crystal = FRUIT.CrystalRose
	for i, at in spots(base, if ripe then n else 1, 1) do
		local height = (if ripe then 2.6 else 1.6) * s
		rod(model, "Stem", at * CFrame.new(0, height / 2, 0), 0.26 * s, height, COLORS.leaf)
		for pair = 0, 1 do
			for _, side in { -1, 1 } do
				local leaf = at * CFrame.Angles(0, math.rad(pair * 90), 0) * CFrame.new(side * 0.5 * s, height * (0.22 + pair * 0.25), 0) * CFrame.Angles(0, 0, math.rad(-side * 30))
				egg(model, "Leaf", leaf, Vector3.new(1.1, 0.1, 0.55) * s, if pair == 0 then COLORS.leafDark else COLORS.leaf)
			end
		end
		local bloom = at * CFrame.new(0, height, 0)
		egg(model, "Bud", bloom, Vector3.new(0.8, 1.0, 0.8) * s, Color3.fromRGB(210, 244, 255), { Material = Enum.Material.Neon })
		if ripe then
			for ring, petals in { { 5, 0.38, 20, Vector3.new(0.75, 1.05, 0.16) }, { 6, 0.68, 50, Vector3.new(1.05, 1.15, 0.16) } } do
				for k = 0, petals[1] - 1 do
					local petal = bloom * CFrame.Angles(0, math.rad(k * 360 / petals[1] + ring * 30 + i * 20), 0) * CFrame.new(0, -0.1 * s, petals[2] * s) * CFrame.Angles(math.rad(petals[3]), 0, 0)
					egg(model, "Petal", petal, petals[4] * s, crystal, { Reflectance = 0.25 })
				end
			end
		end
	end
end

-- The Phoenix Pepper: a bush with one great flaming pepper hanging off it,
-- red at the stem to glowing yellow at the tip.
function BUILDERS.PhoenixPepper(model, base, ripe, s, n)
	local bush = base * CFrame.new(0, 1.3 * s, 0)
	local size = Vector3.new(2.8, 2.3, 2.8) * s
	foliage(model, bush, size, 3)
	if not ripe then
		return
	end
	local fire = { Color3.fromRGB(206, 30, 24), Color3.fromRGB(220, 44, 22), Color3.fromRGB(232, 72, 24), Color3.fromRGB(244, 112, 28),
		Color3.fromRGB(252, 156, 40), Color3.fromRGB(255, 206, 64) }
	local diameters = { 0.7, 0.66, 0.58, 0.48, 0.36, 0.22 }
	for k = 1, n do
		-- (from the bush's side, pointing out and a little down, the tip curling up)
		local a = math.rad(k * 180 + 30)
		local at = bush * CFrame.Angles(0, -a, 0) * CFrame.new(size.X * 0.42, 0.2 * s, 0) * CFrame.Angles(0, 0, math.rad(70))
		rod(model, "Calyx", at * CFrame.new(0, 0.05 * s, 0), 0.62 * s, 0.14 * s, COLORS.leafDark)
		local tip
		for j, colour in fire do
			tip = rod(model, "Pepper", at * CFrame.new(0, -0.24 * s, 0), diameters[j] * s, 0.5 * s, colour,
				{ Reflectance = 0.15, Material = if j == #fire then Enum.Material.Neon else Enum.Material.SmoothPlastic })
			at = at * CFrame.new(0, -0.44 * s, 0) * CFrame.Angles(0, 0, math.rad(if j > 3 then 16 else 4))
		end
		local flame = Instance.new("Attachment") -- (on the glowing tip)
		flame.Name = "Flame"
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = FIRE
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 80, 20))
		emitter.LightEmission = 0.8
		emitter.Rate = 12
		emitter.Lifetime = NumberRange.new(0.3, 0.55)
		emitter.Speed = NumberRange.new(1, 2)
		emitter.Acceleration = Vector3.new(0, 3, 0)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.1) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		emitter.Parent = flame
		flame.Parent = tip
	end
end

-- The Dragon's Eye Pumpkin: a great purple pumpkin with a glowing eye, on
-- dark vines.
function BUILDERS.DragonsEyePumpkin(model, base, ripe, s, n)
	vineLeaves(model, base, s, 4, Color3.fromRGB(70, 96, 60))
	if not ripe then
		orb(model, "Fruit", base * CFrame.new(0, 1.0, 0), 1.8 * s, Color3.fromRGB(92, 60, 96))
		return
	end
	local width = (if n == 1 then 3.0 else 2.4) * s
	for i = 1, n do
		local at = base * CFrame.new(0, 0, if n == 1 then 0 else (i - 1.5) * 5.4)
		local centre = pumpkin(model, at, width, width * 0.66, FRUIT.DragonsEyePumpkin, Color3.fromRGB(132, 32, 104), Color3.fromRGB(56, 40, 44))
		local eye = centre * CFrame.new(0, 0.05 * s, -width / 2 + 0.08) -- (on the front rib's face)
		egg(model, "Eye", eye, Vector3.new(0.36, 0.23, 0.12) * width, Color3.fromRGB(255, 214, 60), { Material = Enum.Material.Neon })
		egg(model, "Pupil", eye * CFrame.new(0, 0, -0.04 * width), Vector3.new(0.06, 0.2, 0.1) * width, COLORS.dark)
	end
end

-- A crop's model at a stage, standing on `base` (the top centre of its
-- tile), showing `count` of it ripe (default: the crop's perPatch). A ripe
-- patch sparkles all over in its rarity's colour.
function FarmArt.cropModel(cropId: string, stage: string, base: CFrame, count: number?): Model
	local crop = Crops.ById[cropId]
	local rarity = Rarities.ById[crop.rarity]
	local s = 1 + (rarity.order - 1) * 0.15 -- rarer crops grow bigger (§7)
	local model = Instance.new("Model")
	model.Name = "Crop"
	if stage == "Seed" then
		sown(model, base)
	elseif stage == "Sprout" then
		seedlings(model, base, s)
	else
		BUILDERS[cropId](model, base, stage == "Ripe", s, count or crop.perPatch)
	end
	if stage == "Ripe" then
		-- (sparkles rising from the whole patch: an invisible slab they come out of)
		local glow = if rarity.order == 1 then Color3.fromRGB(255, 236, 180) else rarity.color
		local shine = prop({ Name = "Shine", Size = Vector3.new(FIELD.tile - 2, 0.2, FIELD.tile - 2), CFrame = base * CFrame.new(0, 0.9, 0),
			Transparency = 1, CastShadow = false }, model)
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "Sparkle"
		sparkle.Texture = SPARKLE
		sparkle.Color = ColorSequence.new(glow)
		sparkle.LightEmission = 1
		sparkle.Rate = 4 + rarity.order * 2
		sparkle.Lifetime = NumberRange.new(0.8, 1.5)
		sparkle.Speed = NumberRange.new(1, 2.5)
		sparkle.SpreadAngle = Vector2.new(20, 20)
		sparkle.EmissionDirection = Enum.NormalId.Top
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Parent = shine
	end
	return model
end

------------------------------------------------------------------------
-- Tiles and land

-- Soil colours by Field Level: { soil, ridge, wet soil, wet ridge }. From
-- Level 2 the soil is composted: darker and richer (watered is darker still).
local SOIL = {
	{ COLORS.soil, COLORS.ridge, COLORS.wetSoil, COLORS.wetRidge },
	{ Color3.fromRGB(84, 56, 38), Color3.fromRGB(97, 65, 43), Color3.fromRGB(60, 40, 28), Color3.fromRGB(70, 46, 32) },
}

local function palette(tilePart: BasePart)
	local level = tilePart.Parent and tilePart.Parent:GetAttribute("FieldLevel") or 1
	return SOIL[math.min(level, #SOIL)]
end

-- Where a tile's crop stands: the top of the tile, turned half the time so
-- neighbouring patches aren't all the same (the rows stay on the ridges).
local function tileBase(tilePart: BasePart, tile: number): CFrame
	return tilePart.CFrame * CFrame.new(0, tilePart.Size.Y / 2, 0) * CFrame.Angles(0, if tile % 2 == 0 then math.pi else 0, 0)
end

-- Tilled (three soil ridges) or overgrown.
function FarmArt.setTileOpen(tilePart: BasePart, open: boolean, fresh: boolean?)
	tilePart:SetAttribute("Open", open)
	tilePart:SetAttribute("Fresh", fresh == true or nil)
	local colors = palette(tilePart)
	tilePart.Color = if open then colors[1] else COLORS.overgrown
	local ridges = tilePart:FindFirstChild("Ridges")
	if open and not ridges then
		ridges = Instance.new("Folder")
		ridges.Name = "Ridges"
		-- (cylinders lying along the row, half sunk: rounded mounds, not planks)
		for _, x in { -3.2, 0, 3.2 } do
			prop({
				Name = "Ridge", Shape = Enum.PartType.Cylinder, Size = Vector3.new(FIELD.tile - 1.8, 1.6, 1.6),
				CFrame = tilePart.CFrame * CFrame.new(x, tilePart.Size.Y / 2 - 0.35, 0) * CFrame.Angles(0, math.rad(90), 0),
				Color = colors[2], CastShadow = false,
			}, ridges)
		end
		ridges.Parent = tilePart
	elseif not open and ridges then
		ridges:Destroy()
	end
end

-- Shows a tile's crop (or none) and sets its attributes. `now`: server time.
function FarmArt.showTile(tilePart: BasePart, tile, now: number)
	local number = tilePart:GetAttribute("Tile")
	local stage = tile and FarmArt.stage(tile)
	local yield = tile and GrowthRules.yieldOf(tile)
	local old = tilePart:FindFirstChild("Crop")
	if old and (not tile or tilePart:GetAttribute("Crop") ~= tile.crop or tilePart:GetAttribute("Stage") ~= stage or tilePart:GetAttribute("Yield") ~= yield) then
		old:Destroy()
		old = nil
	end
	if tile and not old then
		FarmArt.cropModel(tile.crop, stage, tileBase(tilePart, number), yield).Parent = tilePart
	end
	tilePart:SetAttribute("Crop", tile and tile.crop)
	tilePart:SetAttribute("Stage", stage)
	tilePart:SetAttribute("Yield", yield)
	tilePart:SetAttribute("RipeAt", tile and now + GrowthRules.secondsLeft(tile))
	tilePart:SetAttribute("Watered", tile and tile.watered or nil)
	tilePart:SetAttribute("Leave", tile and tile.leave or nil)
	if tilePart:GetAttribute("Open") then
		local colors = palette(tilePart)
		local wet = tile and tile.watered and stage ~= "Ripe"
		tilePart.Color = if wet then colors[3] else colors[1]
		local ridges = tilePart:FindFirstChild("Ridges")
		for _, ridge in if ridges then ridges:GetChildren() else {} do
			ridge.Color = if wet then colors[4] else colors[2]
		end
	end
end

local function blockCentre(block: number): Vector3
	local tiles = LandRules.tilesOf(block)
	return (PlotLayout.tileLocal(tiles[1]) + PlotLayout.tileLocal(tiles[4])) / 2
end

local OBSTACLE_BUILDERS = {
	Stump = function(model, at: CFrame)
		cylinder("Stump", at * CFrame.new(0, 1, 0), 3, 2, { Color = COLORS.stump }, model)
		cylinder("Rings", at * CFrame.new(0, 2.02, 0), 2.6, 0.05, { Color = COLORS.stumpTop, CastShadow = false }, model)
	end,
	Rock = function(model, at: CFrame)
		prop({ Name = "Rock", Size = Vector3.new(3.6, 2.4, 3), CFrame = at * CFrame.new(0, 1.1, 0) * CFrame.Angles(0.15, 0.6, 0.1), Color = COLORS.rock }, model)
		prop({ Name = "Pebble", Size = Vector3.new(1.4, 1, 1.2), CFrame = at * CFrame.new(2, 0.45, 1) * CFrame.Angles(0.2, 1.1, 0), Color = COLORS.rock }, model)
	end,
	Weeds = function(model, at: CFrame)
		tuft(model, at, 5, 3.4, 1)
	end,
	Bush = function(model, at: CFrame)
		ball("Bush", at * CFrame.new(0, 1.8, 0), 3.8, { Color = COLORS.bush }, model)
		ball("Bush", at * CFrame.new(1.6, 1.2, 0.8), 2.6, { Color = COLORS.leafDark }, model)
	end,
}

-- An overgrown block: tufts of grass and its obstacles, one on each tile.
-- `left`: how many obstacles are still there (all of them unless it's being cleared).
local function buildOvergrowth(field: Instance, frame: CFrame, block: number, left: number)
	local model = Instance.new("Model")
	model.Name = `Overgrowth{block}`
	model:SetAttribute("Block", block)
	local centre = blockCentre(block)
	for i = 1, 3 do
		local at = frame * CFrame.new(centre + Vector3.new(math.cos(i * 2.1) * 7, TILE_TOP, math.sin(i * 2.1) * 7))
		tuft(model, at, 4, 2.4, 0.8)
	end
	local tiles = LandRules.tilesOf(block)
	local first = #FarmArt.OBSTACLES - left + 1
	for k = first, #FarmArt.OBSTACLES do
		local kind = FarmArt.OBSTACLES[k]
		local obstacle = Instance.new("Model")
		obstacle.Name = kind
		obstacle:SetAttribute("Obstacle", k)
		local at = frame * CFrame.new(PlotLayout.tileLocal(tiles[k]) + Vector3.new(0, TILE_TOP, 0)) * CFrame.Angles(0, block * 0.9 + k, 0)
		OBSTACLE_BUILDERS[kind](obstacle, at)
		obstacle.PrimaryPart = obstacle:FindFirstChildWhichIsA("BasePart")
		obstacle.Parent = model
	end
	model.Parent = field
	return model
end

-- Lays an empty field: 64 tiles (the start corner tilled), the block
-- edging, and overgrowth on the other 12 blocks.
function FarmArt.buildField(model: Instance, frame: CFrame): Folder
	local field = Instance.new("Folder")
	field.Name = "Field"
	field.Parent = model
	for tile = 1, FIELD.size * FIELD.size do
		local t = part({
			Name = `Tile{tile}`,
			Size = Vector3.new(FIELD.tile - 0.6, 0.4, FIELD.tile - 0.6),
			CFrame = frame * CFrame.new(PlotLayout.tileLocal(tile) + Vector3.new(0, 0.3, 0)),
		}, field)
		t:SetAttribute("Tile", tile)
		t:SetAttribute("Block", LandRules.blockOfTile(tile))
	end
	-- Edging: low boards along every block boundary.
	local edging = Instance.new("Folder")
	edging.Name = "Edging"
	edging.Parent = field
	local span = FIELD.tile * FIELD.size
	local step = FIELD.tile * 2
	for k = 0, FIELD.size / 2 do
		prop({ Name = "Board", Size = Vector3.new(span + 0.6, 0.7, 0.6),
			CFrame = frame * CFrame.new(FIELD.across + span / 2, 0.35, FIELD.depth + k * step), Color = COLORS.edging }, edging)
		prop({ Name = "Board", Size = Vector3.new(0.6, 0.7, span + 0.6),
			CFrame = frame * CFrame.new(FIELD.across + k * step, 0.35, FIELD.depth + span / 2), Color = COLORS.edging }, edging)
	end
	FarmArt.applyLand(model, frame, { cleared = {}, fresh = {} })
	return field
end

-- Matches the field to a save's land: open blocks tilled, the rest
-- overgrown, a block being cleared down to the obstacles it has left, and
-- the look of its Field Level.
function FarmArt.applyLand(model: Instance, frame: CFrame, land)
	local field = model:FindFirstChild("Field")
	field:SetAttribute("FieldLevel", land.fieldLevel or 1) -- (the soil's colours: palette)
	for block = 1, 16 do
		local open = LandRules.isOpen(land, block)
		for _, tile in LandRules.tilesOf(block) do
			FarmArt.setTileOpen(field[`Tile{tile}`], open, open and land.fresh and land.fresh[tostring(tile)])
		end
		local overgrowth = field:FindFirstChild(`Overgrowth{block}`)
		local clearing = land.clearing and land.clearing.block == block
		local left = if clearing then land.clearing.obstacles else #FarmArt.OBSTACLES
		if overgrowth and (open or overgrowth:GetAttribute("Left") ~= left) then
			overgrowth:Destroy()
			overgrowth = nil
		end
		if not open and not overgrowth then
			overgrowth = buildOvergrowth(field, frame, block, left)
			overgrowth:SetAttribute("Left", left)
		end
		if overgrowth then
			overgrowth:SetAttribute("Clearing", clearing or nil)
		end
	end
	FarmArt.applyFieldLevel(model, frame, land)
end

-- The obstacles still standing on a block (for LandService's prompts).
function FarmArt.obstacles(model: Instance, block: number): { Model }
	local overgrowth = model.Field:FindFirstChild(`Overgrowth{block}`)
	local list = {}
	for _, child in if overgrowth then overgrowth:GetChildren() else {} do
		if child:GetAttribute("Obstacle") then
			table.insert(list, child)
		end
	end
	return list
end

------------------------------------------------------------------------
-- Field Levels (§4.1c): what the soil and the field round it look like

local TIMBER = Color3.fromRGB(164, 116, 70)
local GOLD = Color3.fromRGB(232, 188, 66)
local PIPE = Color3.fromRGB(42, 42, 46)
local COMPOST = Color3.fromRGB(104, 74, 48)
local STRAW = Color3.fromRGB(214, 182, 106)
local COMPOST_SPOT = Vector3.new(-62, 0, 128) -- behind the farmhouse, by the field's front corner
local SIGN_SPOT = Vector3.new(14, 0, 131) -- beside the path to the field, facing the farmhouse

-- The edging between blocks: low boards at Levels 1–2; from Level 3 raised
-- timber beds (taller, a post where they cross), gold-capped at Level 5.
local function edging(field: Instance, frame: CFrame, level: number)
	local folder = field:FindFirstChild("Edging")
	local beds = level >= 3
	local height, width = if beds then 1.3 else 0.7, if beds then 0.8 else 0.6
	local span = FIELD.tile * FIELD.size
	for _, board in folder:GetChildren() do
		if board.Name == "Board" then
			local at = frame:PointToObjectSpace(board.CFrame.Position)
			local alongX = board.Size.X > board.Size.Z
			board.Size = if alongX then Vector3.new(span + width, height, width) else Vector3.new(width, height, span + width)
			board.CFrame = frame * CFrame.new(at.X, height / 2, at.Z)
			board.Color = if beds then TIMBER else COLORS.edging
		elseif board.Name == "Post" or board.Name == "Cap" then
			board:Destroy()
		end
	end
	if not beds then
		return
	end
	local step = FIELD.tile * 2
	for i = 0, FIELD.size / 2 do
		for j = 0, FIELD.size / 2 do
			local at = frame * CFrame.new(FIELD.across + i * step, 0, FIELD.depth + j * step)
			prop({ Name = "Post", Size = Vector3.new(1.1, 1.7, 1.1), CFrame = at * CFrame.new(0, 0.85, 0), Color = COLORS.post }, folder)
			if level >= 5 then
				ball("Cap", at * CFrame.new(0, 1.85, 0), 0.8, { Color = GOLD, Reflectance = 0.15 }, folder)
			end
		end
	end
	if level >= 5 then
		for k = 0, FIELD.size / 2 do -- (a gold strip along the top of every board)
			prop({ Name = "Cap", Size = Vector3.new(span + width, 0.14, width + 0.1), CFrame = frame * CFrame.new(FIELD.across + span / 2, height + 0.07, FIELD.depth + k * step),
				Color = GOLD, Reflectance = 0.15 }, folder)
			prop({ Name = "Cap", Size = Vector3.new(width + 0.1, 0.14, span + width), CFrame = frame * CFrame.new(FIELD.across + k * step, height + 0.07, FIELD.depth + span / 2),
				Color = GOLD, Reflectance = 0.15 }, folder)
		end
	end
end

-- Raised beds (Level 3) are filled with soil: a slab under each open
-- block's patches, so no grass shows between them (its edges run under the
-- bed walls, its top just under the patches').
local function bedSoil(field: Instance, frame: CFrame, land, level: number)
	local old = field:FindFirstChild("BedSoil")
	if old then
		old:Destroy()
	end
	if level < 3 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "BedSoil"
	for block = 1, 16 do
		if LandRules.isOpen(land, block) then
			local centre = blockCentre(block)
			prop({ Name = "Soil", Size = Vector3.new(FIELD.tile * 2, 0.3, FIELD.tile * 2), CFrame = frame * CFrame.new(centre.X, TILE_TOP - 0.21, centre.Z),
				Color = SOIL[2][1], CastShadow = false }, folder)
		end
	end
	folder.Parent = field
end

-- Drip lines (Level 4): a black pipe down each furrow of every open block,
-- fed from a pipe across its front with a blue tap.
local function dripLines(field: Instance, frame: CFrame, land, level: number)
	local old = field:FindFirstChild("Drip")
	if old then
		old:Destroy()
	end
	if level < 4 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Drip"
	for block = 1, 16 do
		if LandRules.isOpen(land, block) then
			local centre = blockCentre(block)
			local front = centre.Z - FIELD.tile + 1.1 -- (the block's edge by the farmhouse)
			for _, column in { -FIELD.tile / 2, FIELD.tile / 2 } do
				for _, furrow in { -1.6, 1.6 } do
					prop({ Name = "Pipe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(FIELD.tile * 2 - 2.6, 0.26, 0.26),
						CFrame = frame * CFrame.new(centre.X + column + furrow, TILE_TOP + 0.13, centre.Z + 0.2) * CFrame.Angles(0, math.rad(90), 0),
						Color = PIPE, CastShadow = false }, folder)
				end
			end
			prop({ Name = "Header", Shape = Enum.PartType.Cylinder, Size = Vector3.new(FIELD.tile * 2 - 3.4, 0.34, 0.34),
				CFrame = frame * CFrame.new(centre.X, TILE_TOP + 0.17, front), Color = PIPE, CastShadow = false }, folder)
			local tap = frame * CFrame.new(centre.X - FIELD.tile + 1.6, TILE_TOP, front)
			cylinder("Tap", tap * CFrame.new(0, 0.45, 0), 0.45, 0.9, { Color = Color3.fromRGB(64, 120, 200) }, folder)
			cylinder("Valve", tap * CFrame.new(0, 0.98, 0), 0.7, 0.16, { Color = Color3.fromRGB(208, 52, 44) }, folder)
		end
	end
	folder.Parent = field
end

-- The compost bin (Level 2): three slatted wooden sides round a dark heap,
-- open toward the farmhouse, a fork stuck in it.
local function compostBin(parent: Instance, at: CFrame)
	local model = Instance.new("Model")
	model.Name = "CompostBin"
	for _, side in { { -2.2, 0, 90 }, { 2.2, 0, 90 }, { 0, -2.2, 0 } } do
		local wall = at * CFrame.new(side[1], 0, side[2]) * CFrame.Angles(0, math.rad(side[3]), 0)
		for k = 0, 2 do
			prop({ Name = "Slat", Size = Vector3.new(4.6, 0.55, 0.3), CFrame = wall * CFrame.new(0, 0.45 + k * 0.8, 0), Color = TIMBER }, model)
		end
		for _, x in { -2.15, 2.15 } do
			prop({ Name = "Post", Size = Vector3.new(0.55, 2.5, 0.55), CFrame = wall * CFrame.new(x, 1.25, 0.25), Color = COLORS.post }, model)
		end
	end
	local heap = Instance.new("Part")
	heap.Name = "Heap"
	heap.Size = Vector3.new(4.0, 2.2, 4.0)
	heap.CFrame = at * CFrame.new(0, 0.7, 0.1)
	heap.Color = COMPOST
	heap.Anchored, heap.CanCollide, heap.CanTouch = true, false, false
	heap.Material = Enum.Material.Ground
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = heap
	heap.Parent = model
	for k = 1, 3 do -- (straw on top)
		local straw = Instance.new("Part")
		straw.Name = "Straw"
		straw.Size = Vector3.new(1.1, 0.3, 0.9)
		straw.CFrame = at * CFrame.new(math.cos(k * 2.1) * 0.8, 1.68, 0.1 + math.sin(k * 2.1) * 0.8) * CFrame.Angles(0, k, 0.2)
		straw.Color = STRAW
		straw.Anchored, straw.CanCollide, straw.CanTouch, straw.CastShadow = true, false, false, false
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = straw
		straw.Parent = model
	end
	local fork = at * CFrame.new(1.0, 1.9, 0.6) * CFrame.Angles(math.rad(-14), 0, math.rad(12))
	cylinder("Handle", fork * CFrame.new(0, 0.6, 0), 0.16, 2.6, { Color = WOOD }, model)
	for _, x in { -0.18, 0, 0.18 } do
		prop({ Name = "Tine", Size = Vector3.new(0.06, 0.8, 0.06), CFrame = fork * CFrame.new(x, -0.9, 0), Color = Color3.fromRGB(150, 150, 156) }, model)
	end
	model.Parent = parent
	return model
end

-- The prize sign (Level 5): a painted board on two posts, a blue rosette on it.
local function prizeSign(parent: Instance, at: CFrame)
	local model = Instance.new("Model")
	model.Name = "PrizeSign"
	for _, x in { -2.6, 2.6 } do
		prop({ Name = "Post", Size = Vector3.new(0.5, 5.2, 0.5), CFrame = at * CFrame.new(x, 2.6, 0.2), Color = COLORS.post }, model)
	end
	local board = prop({ Name = "Board", Size = Vector3.new(6.4, 2.6, 0.3), CFrame = at * CFrame.new(0, 3.6, 0), Color = Color3.fromRGB(240, 226, 192) }, model)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(320, 130)
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(0.66, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(70, 46, 30)
	text.Text = "PRIZE\nFIELD"
	text.Parent = gui
	gui.Parent = board
	-- the rosette, on the board's right as you read it (its -X): a ribbon
	-- frill, a gold middle, two tails
	local rosette = at * CFrame.new(-1.75, 3.7, -0.2)
	cylinder("Frill", rosette * CFrame.Angles(math.rad(90), 0, 0), 1.9, 0.12, { Color = Color3.fromRGB(44, 92, 196) }, model)
	cylinder("Middle", rosette * CFrame.new(0, 0, -0.1) * CFrame.Angles(math.rad(90), 0, 0), 1.0, 0.12, { Color = GOLD, Reflectance = 0.15 }, model)
	for _, side in { -1, 1 } do
		prop({ Name = "Tail", Size = Vector3.new(0.45, 1.5, 0.08), CFrame = rosette * CFrame.new(side * 0.3, -1.05, 0.02) * CFrame.Angles(0, 0, math.rad(side * 12)),
			Color = Color3.fromRGB(44, 92, 196) }, model)
	end
	model.Parent = parent
	return model
end

-- Dresses the field for its Field Level: the edging, drip lines on open
-- blocks, the compost bin and the prize sign (the soil's colour is
-- FarmArt.showTile's, from the FieldLevel attribute this sets).
function FarmArt.applyFieldLevel(model: Instance, frame: CFrame, land)
	local field = model:FindFirstChild("Field")
	local level = land.fieldLevel or 1
	field:SetAttribute("FieldLevel", level)
	edging(field, frame, level)
	bedSoil(field, frame, land, level)
	dripLines(field, frame, land, level)
	local look = field:FindFirstChild("Look")
	if look then
		look:Destroy()
	end
	if level >= 2 then
		look = Instance.new("Folder")
		look.Name = "Look"
		compostBin(look, frame * CFrame.new(COMPOST_SPOT) * CFrame.Angles(0, math.pi, 0))
		if level >= 5 then
			prizeSign(look, frame * CFrame.new(SIGN_SPOT))
		end
		look.Parent = field
	end
end

return FarmArt
