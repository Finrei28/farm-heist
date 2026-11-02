-- Dumps the parts the server builds for one farm (plot space) to JSON, so
-- tools/crop_art/partview.py can render them with the meshes for a look
-- before Studio. From the project folder:
--   lune run tools/partdump [out.json] [fieldLevel] [blocksOpen] [plot] [defences]
-- (every mesh stands in for its import; the field has `blocksOpen` blocks
-- cleared, the rest overgrown; `defences`: every defence set out, the gate
-- shut and locked, the Watchman's gatehouse; `dome`: those and a dome).
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Harness = require("../tests/lib/harness")

local out = process.args[1] or "partdump.json"
local fieldLevel = tonumber(process.args[2]) or 1
local open = tonumber(process.args[3]) or 4
local index = tonumber(process.args[4]) or 1
local extras = process.args[5]

Harness.reset()
Harness.fresh()
local function standIns(name, meshes)
	local models = roblox.Instance.new("Folder")
	models.Name = name
	for mesh, info in meshes do
		local part = roblox.Instance.new("MeshPart")
		part.Name = mesh
		part.Size = info.size
		part.Parent = models
	end
	return models
end
Harness.setStorageChild("CropModels", standIns("CropModels", Harness.loadServer("World/CropMeshData").meshes))
Harness.setStorageChild("PropModels", standIns("PropModels", Harness.loadServer("World/PropMeshData").meshes))

local PlotLayout = Harness.load("PlotLayout")
local game = roblox.Instance.new("DataModel")
local globals = { Instance = roblox.Instance, workspace = game:GetService("Workspace") }
local WorldBuilder = Harness.loadServerWith("World/WorldBuilder", globals)
local FarmArt = Harness.loadServerWith("World/FarmArt", globals)
local world = WorldBuilder.Build()
local plot = world[`Plot{index}`]
local frame = PlotLayout.frame(index)
local cleared = {}
for block = 1, open do
	table.insert(cleared, ({ 1, 2, 5, 6, 3, 7, 9, 10, 4, 8, 11, 12, 13, 14, 15, 16 })[block])
end
local land = { cleared = cleared, fresh = {}, fieldLevel = fieldLevel }
FarmArt.applyLand(plot, frame, land)

if extras == "defences" or extras == "dome" then
	local DefenceArt = Harness.loadServerWith("World/DefenceArt", globals)
	local DefenceRules = Harness.load("DefenceRules")
	local Defences = Harness.load("Config/Defences")
	local d = { owned = {}, placed = {} }
	for _, itemId in Defences.ORDER do
		for _ = 1, math.min(Defences.ITEMS[itemId].max, 4) do
			DefenceRules.buy(d, itemId)
		end
	end
	DefenceRules.place(d, "Scarecrow", "yard:4")
	DefenceRules.place(d, "GuardDog", "yard:13")
	for _, n in { 10, 12, 15, 17 } do
		DefenceRules.place(d, "MudPatch", `yard:{n}`)
	end
	local cloches = 0
	for tile = 1, 64 do
		if cloches < 4 and DefenceRules.canPlace(d, land, "Cloche", `tile:{tile}`) then
			DefenceRules.place(d, "Cloche", `tile:{tile}`)
			cloches += 1
		end
	end
	DefenceArt.show(plot, frame, index, d)
	DefenceArt.setGate(plot, false, true)
	DefenceArt.gatehouse(plot, frame, index, true)
	if extras == "dome" then
		DefenceArt.dome(plot, frame, "Shield", 100)
	end
end

local parts = {}
for _, part in plot:GetDescendants() do
	if part:IsA("BasePart") and part.Transparency < 1 then
		local cf = frame:ToObjectSpace(part.CFrame)
		local entry = {
			name = part.Name,
			class = part.ClassName,
			size = { part.Size.X, part.Size.Y, part.Size.Z },
			cframe = { cf:GetComponents() },
			color = { part.Color.R, part.Color.G, part.Color.B },
			neon = part.Material == roblox.Enum.Material.Neon,
			transparency = part.Transparency,
		}
		if part:IsA("Part") then
			entry.shape = part.Shape.Name
			local special = part:FindFirstChildOfClass("SpecialMesh")
			if special and special.MeshType == roblox.Enum.MeshType.Sphere then
				entry.shape = "Ellipsoid"
			end
		end
		table.insert(parts, entry)
	end
end
fs.writeFile(out, serde.encode("json", parts))
print(`{#parts} parts -> {out}`)
