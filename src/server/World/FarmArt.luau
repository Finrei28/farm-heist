-- How a farm's field looks (docs/ArtDirection.md §7): the tiles, the
-- edging round each 2×2 block, overgrown land with its 4 obstacles (a
-- stump, a rock, weeds, a bush: what you clear with a Land Permit), and
-- the crops at each growth stage. WorldBuilder lays an empty field;
-- FieldService and LandService call the rest as the owner's farm changes.
--
-- Each tile part carries what the client needs as attributes (so the field
-- never needs a state sync): Tile, Block, Open, Fresh, and while planted
-- Crop, Stage ("Seed" · "Sprout" · "Growing" · "Ripe"), RipeAt (server time),
-- Watered, Leave.
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
-- Crops

-- Ripe fruit colours for the crops that use the plain bush model.
local FRUIT = {
	Wheat = Color3.fromRGB(232, 198, 98),
	Potato = Color3.fromRGB(176, 128, 80),
	Lettuce = Color3.fromRGB(150, 210, 96),
	Onion = Color3.fromRGB(222, 178, 126),
	Strawberry = Color3.fromRGB(226, 52, 62),
	Tomato = Color3.fromRGB(222, 62, 46),
	BellPepper = Color3.fromRGB(242, 200, 44),
	Watermelon = Color3.fromRGB(58, 142, 64),
	Blueberry = Color3.fromRGB(72, 92, 204),
	Pineapple = Color3.fromRGB(232, 182, 52),
	CocoaPod = Color3.fromRGB(150, 86, 44),
	Dragonfruit = Color3.fromRGB(232, 62, 142),
	GrapeVine = Color3.fromRGB(124, 62, 164),
	Moonmelon = Color3.fromRGB(206, 224, 255),
	Starfruit = Color3.fromRGB(252, 222, 84),
	GoldenApple = Color3.fromRGB(252, 202, 42),
	CrystalRose = Color3.fromRGB(150, 222, 255),
	PhoenixPepper = Color3.fromRGB(255, 96, 32),
	DragonsEyePumpkin = Color3.fromRGB(156, 42, 124),
}
local ORANGE = Color3.fromRGB(242, 140, 40)
local PUMPKIN = Color3.fromRGB(240, 127, 30)
local CORN = Color3.fromRGB(245, 211, 61)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- The colour a crop's produce shows in (crates, shelves).
function FarmArt.cropColor(cropId: string): Color3
	return if cropId == "Carrot" then ORANGE elseif cropId == "Pumpkin" then PUMPKIN elseif cropId == "Corn" then CORN else FRUIT[cropId] or ORANGE
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

local function leaf(model, base: CFrame, yaw: number, tilt: number, size: Vector3, color: Color3?)
	local cf = base * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(tilt), 0, 0) * CFrame.new(0, size.Y / 2, 0)
	return prop({ Name = "Leaf", Size = size, CFrame = cf, Color = color or COLORS.leaf, CastShadow = false }, model)
end

local function mound(model, base: CFrame, s: number)
	cylinder("Mound", base * CFrame.new(0, 0.25, 0), 3 * s, 0.5, { Color = COLORS.ridge }, model)
end

local function sprout(model, base: CFrame, s: number)
	mound(model, base, s)
	leaf(model, base * CFrame.new(0, 0.4, 0), 0, 30, Vector3.new(0.2, 1.3 * s, 0.6 * s))
	leaf(model, base * CFrame.new(0, 0.4, 0), 180, 30, Vector3.new(0.2, 1.3 * s, 0.6 * s), COLORS.leafDark)
end

local function tuft(model, base: CFrame, count: number, height: number, width: number)
	for i = 1, count do
		leaf(model, base, i * 360 / count, 22, Vector3.new(0.25, height, width), if i % 2 == 0 then COLORS.leafDark else COLORS.leaf)
	end
end

local BUILDERS = {}

function BUILDERS.Carrot(model, base, stage, _s)
	if stage == "Growing" then
		tuft(model, base, 3, 2.2, 0.8)
	else
		tuft(model, base * CFrame.new(0, 0.5, 0), 5, 3.2, 0.9)
		cylinder("Root", base * CFrame.new(0, 0.3, 0), 1.5, 1.1, { Color = ORANGE }, model)
	end
end

function BUILDERS.Corn(model, base, stage, _s)
	local stalks = if stage == "Growing" then { Vector3.zero } else { Vector3.new(1.2, 0, 0), Vector3.new(-0.6, 0, 1), Vector3.new(-0.6, 0, -1) }
	local height = if stage == "Growing" then 4 else 7
	for i, offset in stalks do
		local foot = base * CFrame.new(offset)
		prop({ Name = "Stalk", Size = Vector3.new(0.6, height, 0.6), CFrame = foot * CFrame.new(0, height / 2, 0), Color = COLORS.leaf }, model)
		leaf(model, foot * CFrame.new(0, height * 0.35, 0), i * 90, 40, Vector3.new(0.2, 2.6, 0.7), COLORS.leafDark)
		leaf(model, foot * CFrame.new(0, height * 0.6, 0), i * 90 + 180, 40, Vector3.new(0.2, 2.2, 0.6))
		if stage == "Ripe" and i <= 2 then
			local cob = foot * CFrame.new(0, height * 0.55, 0) * CFrame.Angles(0, math.rad(i * 150), math.rad(25)) * CFrame.new(0.7, 0, 0)
			prop({ Name = "Cob", Size = Vector3.new(0.9, 2.2, 0.9), CFrame = cob, Color = CORN }, model)
			prop({ Name = "Husk", Size = Vector3.new(0.3, 1.6, 0.9), CFrame = cob * CFrame.new(0.5, -0.4, 0), Color = COLORS.leaf, CastShadow = false }, model)
		end
	end
end

function BUILDERS.Pumpkin(model, base, stage, s)
	for i = 1, 3 do
		local at = base * CFrame.Angles(0, math.rad(i * 120), 0) * CFrame.new(0, 0.15, 2.2 * s)
		cylinder("Leaf", at, 2.6 * s, 0.25, { Color = if i % 2 == 0 then COLORS.leafDark else COLORS.leaf }, model)
	end
	if stage == "Growing" then
		ball("Fruit", base * CFrame.new(0, 0.6, 0), 1.2 * s, { Color = COLORS.leaf }, model)
		return
	end
	local d = 4.2 * s
	for _, offset in { Vector3.new(0.5, 0, 0), Vector3.new(-0.5, 0, 0.2), Vector3.new(0, 0, -0.5) } do
		ball("Fruit", base * CFrame.new(offset + Vector3.new(0, d * 0.42, 0)), d, { Color = PUMPKIN }, model)
	end
	prop({ Name = "Stem", Size = Vector3.new(0.5, 1.2, 0.5), CFrame = base * CFrame.new(0, d * 0.85 + 0.4, 0) * CFrame.Angles(0, 0, math.rad(12)),
		Color = COLORS.stump }, model)
end

-- Any other crop: a leafy bush, with fruit in its colour once ripe.
local function bush(model, base, stage, s, cropId: string)
	local crop = Crops.ById[cropId]
	local d = (if stage == "Growing" then 2.2 else 3) * s
	ball("Bush", base * CFrame.new(0, d * 0.45, 0), d, { Color = COLORS.leafDark }, model)
	if stage ~= "Ripe" then
		return
	end
	local glows = Rarities.ById[crop.rarity].order >= 5 -- Legendary and Mythic fruit glow (§4.2)
	for i = 1, 4 do
		local at = base * CFrame.new(0, d * 0.45, 0) * CFrame.Angles(0, math.rad(i * 90 + 20), math.rad(if i % 2 == 0 then 35 else -20))
			* CFrame.new(0, d * 0.5, 0)
		ball("Fruit", at, 1.1 * s, { Color = FRUIT[cropId] or ORANGE, Material = if glows then Enum.Material.Neon else Enum.Material.SmoothPlastic }, model)
	end
end

-- A crop's model at a stage, standing on `base` (the top centre of its
-- tile). Ripe crops get a glow ring in their rarity colour and sparkles.
function FarmArt.cropModel(cropId: string, stage: string, base: CFrame): Model
	local crop = Crops.ById[cropId]
	local rarity = Rarities.ById[crop.rarity]
	local s = 1 + (rarity.order - 1) * 0.15 -- rarer crops grow bigger (§7: 3–8 studs ripe)
	local model = Instance.new("Model")
	model.Name = "Crop"
	if stage == "Seed" then
		mound(model, base, s)
	elseif stage == "Sprout" then
		sprout(model, base, s)
	else
		(BUILDERS[cropId] or function(m, b, st, sc)
			bush(m, b, st, sc, cropId)
		end)(model, base, stage, s)
	end
	if stage == "Ripe" then
		local glow = if rarity.order == 1 then Color3.fromRGB(255, 236, 180) else rarity.color
		local ring = cylinder("Glow", base * CFrame.new(0, 0.06, 0), 8, 0.1, {
			Color = glow, Material = Enum.Material.Neon, Transparency = 0.55, CastShadow = false,
		}, model)
		local attachment = Instance.new("Attachment")
		attachment.Position = Vector3.new(2, 0, 0) -- (the ring is a cylinder on its side: X is up)
		attachment.Parent = ring
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "Sparkle"
		sparkle.Texture = SPARKLE
		sparkle.Color = ColorSequence.new(glow)
		sparkle.LightEmission = 1
		sparkle.Rate = 2 + rarity.order
		sparkle.Lifetime = NumberRange.new(0.8, 1.4)
		sparkle.Speed = NumberRange.new(1, 2)
		sparkle.SpreadAngle = Vector2.new(40, 40)
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Parent = attachment
	end
	return model
end

------------------------------------------------------------------------
-- Tiles and land

local function tileBase(tilePart: BasePart, tile: number): CFrame
	return tilePart.CFrame * CFrame.new(0, tilePart.Size.Y / 2, 0) * CFrame.Angles(0, math.rad(tile * 47 % 360), 0)
end

-- Tilled (two soil ridges) or overgrown.
function FarmArt.setTileOpen(tilePart: BasePart, open: boolean, fresh: boolean?)
	tilePart:SetAttribute("Open", open)
	tilePart:SetAttribute("Fresh", fresh == true or nil)
	tilePart.Color = if open then COLORS.soil else COLORS.overgrown
	local ridges = tilePart:FindFirstChild("Ridges")
	if open and not ridges then
		ridges = Instance.new("Folder")
		ridges.Name = "Ridges"
		-- (cylinders lying along the row, half sunk: rounded mounds, not planks)
		for _, x in { -3.2, 0, 3.2 } do
			prop({
				Name = "Ridge", Shape = Enum.PartType.Cylinder, Size = Vector3.new(FIELD.tile - 1.8, 1.6, 1.6),
				CFrame = tilePart.CFrame * CFrame.new(x, tilePart.Size.Y / 2 - 0.35, 0) * CFrame.Angles(0, math.rad(90), 0),
				Color = COLORS.ridge, CastShadow = false,
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
	local old = tilePart:FindFirstChild("Crop")
	if old and (not tile or tilePart:GetAttribute("Crop") ~= tile.crop or tilePart:GetAttribute("Stage") ~= stage) then
		old:Destroy()
		old = nil
	end
	if tile and not old then
		FarmArt.cropModel(tile.crop, stage, tileBase(tilePart, number)).Parent = tilePart
	end
	tilePart:SetAttribute("Crop", tile and tile.crop)
	tilePart:SetAttribute("Stage", stage)
	tilePart:SetAttribute("RipeAt", tile and now + GrowthRules.secondsLeft(tile))
	tilePart:SetAttribute("Watered", tile and tile.watered or nil)
	tilePart:SetAttribute("Leave", tile and tile.leave or nil)
	if tilePart:GetAttribute("Open") then
		local wet = tile and tile.watered and stage ~= "Ripe"
		tilePart.Color = if wet then COLORS.wetSoil else COLORS.soil
		local ridges = tilePart:FindFirstChild("Ridges")
		for _, ridge in if ridges then ridges:GetChildren() else {} do
			ridge.Color = if wet then COLORS.wetRidge else COLORS.ridge
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
-- overgrown, and a block being cleared down to the obstacles it has left.
function FarmArt.applyLand(model: Instance, frame: CFrame, land)
	local field = model:FindFirstChild("Field")
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

return FarmArt
