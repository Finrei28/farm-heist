-- The low-poly meshes (docs/ArtDirection.md §7, §9): drawn by
-- tools/crop_art (Python) and imported once in Studio (Home > Import 3D;
-- README): the crops and their produce from art/crops/FarmHeistCrops.glb
-- as ReplicatedStorage.CropModels, the props (wild land, the yard) from
-- art/props/FarmHeistProps.glb as ReplicatedStorage.PropModels. The
-- generator also writes where every piece goes (CropMeshData,
-- PropMeshData): each crop's patch growing and ripe with any number on
-- it, what a thief holds, a crop's piece on a shelf, an overgrown block's
-- obstacles and grass. It checked each of them by eye in its previews.
--
-- Until a file is imported, its ready() is false and the art modules
-- build their part-built stand-ins instead.
--
--   Meshes.ready() -> boolean            the crops are imported
--   Meshes.propsReady() -> boolean       the props are imported
--   Meshes.make(name, at, scale, parent) -> MeshPart?   one mesh standing
--       on `at` (the point it was drawn round), `scale` a number or Vector3
--   Meshes.patch(cropId, stage, count, base, model) -> boolean   a
--       "Growing" or "Ripe" patch of `count` on `base` (the tile's top middle)
--   Meshes.carried(cropId, count, base, model) -> { width, height, hold }?
--       what a thief holds, standing on `base` (its bottom middle)
--   Meshes.heap(cropId, regions, fraction, smallest) -> boolean   a crop's
--       pieces in display regions (see below)
--   Meshes.piece(cropId, at, longest, parent) -> boolean   one of them,
--       standing on `at`, `longest` studs at its longest
--   Meshes.obstacle(kind, at, model) -> boolean    an overgrown tile's obstacle
--   Meshes.grass(base, model) -> boolean           an overgrown block's grass
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CROPS = require(script.Parent.CropMeshData)
local PROPS = require(script.Parent.PropMeshData)

local Meshes = {}

Meshes.CROPS = "CropModels"
Meshes.PROPS = "PropModels"

local templates = {} -- [name] = MeshPart | false

local function template(name: string): MeshPart?
	local cached = templates[name]
	if cached ~= nil then
		return cached or nil
	end
	local models = ReplicatedStorage:FindFirstChild(if PROPS.meshes[name] then Meshes.PROPS else Meshes.CROPS)
	if not models then
		return nil -- (not cached: the import may turn up later in a Studio session)
	end
	local found = models:FindFirstChild(name, true)
	-- (the importer may wrap a mesh in a Model of the same name)
	if found and not found:IsA("MeshPart") then
		found = found:FindFirstChildWhichIsA("MeshPart", true)
	end
	templates[name] = found or false
	return found
end

function Meshes.ready(): boolean
	return template("Seedling") ~= nil
end

function Meshes.propsReady(): boolean
	return template("Stump") ~= nil
end

-- A copy of mesh `name` standing on `at`. Its size comes from the data, not
-- the import, so the importer's units don't matter; its rotation keeps any
-- turn the importer gave it.
function Meshes.make(name: string, at: CFrame, scale: number | Vector3, parent: Instance): MeshPart?
	local source, info = template(name), CROPS.meshes[name] or PROPS.meshes[name]
	if not source or not info then
		return nil
	end
	local s = if typeof(scale) == "Vector3" then scale else Vector3.new(scale, scale, scale)
	local turn = source.CFrame.Rotation
	local size = turn:VectorToObjectSpace(info.size * s)
	local copy = source:Clone()
	copy.Name = name
	copy.Size = Vector3.new(math.abs(size.X), math.abs(size.Y), math.abs(size.Z))
	copy.CFrame = at * CFrame.new(info.centre * s) * turn
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanTouch = false
	copy.CanQuery = false
	-- (plants cast shadows; small fruit and stubble don't need to)
	copy.CastShadow = info.size.Y * s.Y > 1.5
	if info.material then
		copy.Material = Enum.Material[info.material]
		copy.Color = info.colour
	end
	copy.Parent = parent
	return copy
end

local function place(items, base: CFrame, parent: Instance, k: number?)
	k = k or 1
	for _, item in items do
		local at = base * CFrame.new(item[2] * k, item[3] * k, item[4] * k) * CFrame.Angles(item[5], item[6], item[7])
		local scale = if item[10] then Vector3.new(item[8], item[9], item[10]) * k else item[8] * k
		Meshes.make(item[1], at, scale, parent)
	end
end

-- Whether every mesh the items name is there.
local function have(items): boolean
	for _, item in items do
		if not template(item[1]) then
			return false
		end
	end
	return true
end

-- Lays out a patch. False (and nothing built) when the meshes aren't there
-- or the stage has no meshes (Seed and Sprout are part-built).
function Meshes.patch(cropId: string, stage: string, count: number, base: CFrame, model: Instance): boolean
	local layouts = CROPS.patches[cropId]
	if not layouts or (stage ~= "Growing" and stage ~= "Ripe") or not Meshes.ready() then
		return false
	end
	local items = if stage == "Growing" then layouts.Growing else layouts.Ripe[math.clamp(count, 1, #layouts.Ripe)]
	place(items, base, model)
	return true
end

-- Builds what a thief holds. Nil when the meshes aren't there.
function Meshes.carried(cropId: string, count: number, base: CFrame, model: Instance)
	local loads = CROPS.carried[cropId]
	if not loads or not Meshes.ready() then
		return nil
	end
	local load = loads[math.clamp(count, 1, #loads)]
	place(load.items, base, model)
	return { width = load.width, height = load.height, hold = load.hold }
end

-- Heaps a crop's pieces into display regions (invisible parts, the lowest
-- first: each piece goes in the region it sits in), as many as `fraction`
-- (0..1) of the spots they have. A spot is a piece's footprint, but never
-- smaller than `smallest` studs a side (so a shelf never holds more pieces
-- than it can draw cheaply); pieces too big for a region shrink to fit it
-- (with a little overhang), and stack in layers if it's tall enough.
-- False (and nothing built) when the meshes aren't there.
function Meshes.heap(cropId: string, regions: { BasePart }, fraction: number, smallest: number): boolean
	local shelf = CROPS.shelf[cropId]
	if not shelf or not Meshes.ready() then
		return false
	end
	for _, items in shelf.pieces do
		if not have(items) then
			return false
		end
	end
	local size = shelf.size
	local spots = {}
	for _, region in regions do
		local room = region.Size
		local k = math.min(1, 1.3 * room.X / size.X, 1.3 * room.Z / size.Z)
		local cols = math.max(1, math.floor(room.X / math.max(size.X * k, smallest)))
		local rows = math.max(1, math.floor(room.Z / math.max(size.Z * k, smallest)))
		local layers = math.max(1, math.floor(room.Y / (math.max(size.Y * k, smallest) * 0.8)))
		for layer = 0, layers - 1 do
			-- (upper layers sit in the hollows of the one below)
			local c, r = math.max(1, cols - layer), math.max(1, rows - layer)
			for row = r - 1, 0, -1 do -- (back to front)
				for col = 0, c - 1 do
					local x = (col - (c - 1) / 2) * room.X / cols
					local z = (row - (r - 1) / 2) * room.Z / rows
					local y = -room.Y / 2 + layer * size.Y * k * 0.7
					table.insert(spots, { region = region, x = x, y = y, z = z, k = k })
				end
			end
		end
	end
	local count = math.clamp(math.ceil(fraction * #spots - 1e-9), 1, #spots)
	for i = 1, count do
		local spot = spots[i]
		-- (every other one turned round, all a little askew)
		local turn = (if i % 2 == 0 then math.pi else 0) + ((i * 37) % 9 - 4) * 0.05
		local at = spot.region.CFrame * CFrame.new(spot.x, spot.y, spot.z) * CFrame.Angles(0, turn, 0)
		place(shelf.pieces[(i - 1) % #shelf.pieces + 1], at, spot.region, spot.k)
	end
	return true
end

-- One piece of a crop as a display shows it (decor: a pumpkin pile, a
-- fruit cart).
function Meshes.piece(cropId: string, at: CFrame, longest: number, parent: Instance): boolean
	local shelf = CROPS.shelf[cropId]
	if not shelf or not Meshes.ready() or not have(shelf.pieces[1]) then
		return false
	end
	local size = shelf.size
	place(shelf.pieces[1], at, parent, longest / math.max(size.X, size.Y, size.Z))
	return true
end

-- One of an overgrown tile's obstacles (Config/Land's kinds) on `at`, the
-- tile's top middle.
function Meshes.obstacle(kind: string, at: CFrame, model: Instance): boolean
	local items = PROPS.wild.obstacles[kind]
	if not items or not Meshes.propsReady() or not have(items) then
		return false
	end
	place(items, at, model)
	return true
end

-- The rough grass of an overgrown block on `base`, its top middle (turn it
-- by quarter turns: the grass stays clear of the obstacles).
function Meshes.grass(base: CFrame, model: Instance): boolean
	if not Meshes.propsReady() or not have(PROPS.wild.grass) then
		return false
	end
	place(PROPS.wild.grass, base, model)
	return true
end

return Meshes
