-- The crops' low-poly meshes (docs/ArtDirection.md §7, §9): drawn by
-- tools/crop_art (Python) into art/crops/FarmHeistCrops.glb, imported once
-- in Studio as ReplicatedStorage.CropModels (Home > Import 3D; README).
-- The generator also writes where every piece goes (CropMeshData): each
-- crop's patch growing and ripe with any number on it, and what a thief
-- holds. It checked each of them by eye in its previews.
--
-- Until the meshes are imported, ready() is false and FarmArt and
-- ProduceArt build their part-built crops instead.
--
--   CropMeshes.ready() -> boolean
--   CropMeshes.make(name, at, scale, parent) -> MeshPart?   one mesh standing
--       on `at` (the point it was drawn round), `scale` a number or Vector3
--   CropMeshes.patch(cropId, stage, count, base, model) -> boolean   a
--       "Growing" or "Ripe" patch of `count` on `base` (the tile's top middle)
--   CropMeshes.carried(cropId, count, base, model) -> { width, height, hold }?
--       what a thief holds, standing on `base` (its bottom middle)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DATA = require(script.Parent.CropMeshData)

local CropMeshes = {}

CropMeshes.FOLDER = "CropModels"

local templates = {} -- [name] = MeshPart | false

local function folder()
	return ReplicatedStorage:FindFirstChild(CropMeshes.FOLDER)
end

local function template(name: string): MeshPart?
	local cached = templates[name]
	if cached ~= nil then
		return cached or nil
	end
	local models = folder()
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

function CropMeshes.ready(): boolean
	return folder() ~= nil and template("Seedling") ~= nil
end

-- A copy of mesh `name` standing on `at`. Its size comes from the data, not
-- the import, so the importer's units don't matter; its rotation keeps any
-- turn the importer gave it.
function CropMeshes.make(name: string, at: CFrame, scale: number | Vector3, parent: Instance): MeshPart?
	local source, info = template(name), DATA.meshes[name]
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

local function place(items, base: CFrame, parent: Instance)
	for _, item in items do
		local at = base * CFrame.new(item[2], item[3], item[4]) * CFrame.Angles(item[5], item[6], item[7])
		local scale = if item[10] then Vector3.new(item[8], item[9], item[10]) else item[8]
		CropMeshes.make(item[1], at, scale, parent)
	end
end

-- Lays out a patch. False (and nothing built) when the meshes aren't there
-- or the stage has no meshes (Seed and Sprout are part-built).
function CropMeshes.patch(cropId: string, stage: string, count: number, base: CFrame, model: Instance): boolean
	local layouts = DATA.patches[cropId]
	if not layouts or (stage ~= "Growing" and stage ~= "Ripe") or not CropMeshes.ready() then
		return false
	end
	local items = if stage == "Growing" then layouts.Growing else layouts.Ripe[math.clamp(count, 1, #layouts.Ripe)]
	place(items, base, model)
	return true
end

-- Builds what a thief holds. Nil when the meshes aren't there.
function CropMeshes.carried(cropId: string, count: number, base: CFrame, model: Instance)
	local loads = DATA.carried[cropId]
	if not loads or not CropMeshes.ready() then
		return nil
	end
	local load = loads[math.clamp(count, 1, #loads)]
	place(load.items, base, model)
	return { width = load.width, height = load.height, hold = load.hold }
end

return CropMeshes
