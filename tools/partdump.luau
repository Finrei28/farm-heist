-- Dumps the parts the server builds for one farm (plot space) to JSON, so
-- tools/crop_art/partview.py can render them with the meshes for a look
-- before Studio. From the project folder:
--   lune run tools/partdump [out.json] [fieldLevel] [blocksOpen] [plot] [defences] [storeLevel]
-- (every mesh stands in for its import; the field has `blocksOpen` blocks
-- cleared, the rest overgrown; `defences`: every defence set out, the gate
-- shut and locked, the Watchman's gatehouse; `dome`: those and a dome;
-- `auction`: the Auction House instead of a farm, in its own frame;
-- `warehouse`: the farm with its warehouse at Level 20 and its semis;
-- `store`: just the store at `storeLevel` (14 unless given, the top of the
-- Market Hall), every display full, on the layout below (made for that
-- floor, and a real one: StoreLayout.check passes it);
-- `town`: the whole town and the ring road, in world space; `valley`: the
-- countryside, roads and trail with farms 1, 2 and 8, in world space).
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

if extras == "warehouse" then
	-- the biggest warehouse (Warehouse Level 20) and its semis at the docks
	local YardArt = Harness.loadServerWith("World/YardArt", globals)
	YardArt.setLevel(plot, 20)
end

local sources = { plot }
if extras == "store" then
	-- rows of displays rising toward the back wall, seen from the checkout:
	-- tiered racks either side of the middle aisle, shelves, the wall's chillers
	local StoreItems = Harness.loadServerWith("World/StoreItems", globals)
	local StoreArt = Harness.loadServerWith("World/StoreArt", globals)
	local Store = Harness.load("Config/Store")
	local StoreLayout = Harness.load("StoreLayout")
	local Crops = Harness.load("Config/Crops")
	local catalog = roblox.Instance.new("Folder")
	catalog.Name = "StoreCatalog"
	for itemId in Store.ITEMS do
		StoreItems.build(itemId).Parent = catalog
	end
	Harness.setStorageChild("StoreCatalog", catalog)

	local level = tonumber(process.args[6]) or 14
	local layout = {}
	local function put(item, x, y, rot, crops)
		local entry = { item = item, x = x, y = y, rot = rot or 0, slots = {} }
		for n, cropId in crops or {} do
			local crop = Crops.ById[cropId]
			assert(StoreLayout.holds(item, crop.rarity), `{item} can't hold {cropId}`)
			entry.slots[n] = { crop = cropId, units = Store.ITEMS[item].patches * crop.perPatch }
		end
		layout[`{item}{x}_{y}`] = entry
	end
	local function onWall(item, at)
		layout[`{item}{at}`] = { item = item, side = "back", at = at }
	end
	local RACKS = {
		{ "Pumpkin", "Corn", "Watermelon" },
		{ "Tomato", "BellPepper", "Blueberry" },
		{ "Watermelon", "Lettuce", "Pumpkin" },
		{ "Strawberry", "Corn", "Tomato" },
		{ "Pumpkin", "Blueberry", "BellPepper" },
		{ "Watermelon", "Tomato", "Carrot" },
	}
	for i, x in { 1, 3, 5, 10, 12, 14 } do
		put("TieredRack", x, 6, 0, RACKS[i])
	end
	local SHELVES = { { "Pumpkin", "Watermelon" }, { "BellPepper", "Tomato" }, { "Corn", "Blueberry" }, { "Lettuce", "Strawberry" }, { "Tomato", "Pumpkin" }, { "Watermelon", "Corn" } }
	for i, x in { 1, 3, 5, 8, 10, 13 } do
		put("WoodenShelf", x, 8, 0, SHELVES[i])
	end
	local CHILLERS = { { "Strawberry", "Pineapple" }, { "GrapeVine", "BellPepper" }, { "Dragonfruit", "Blueberry" } }
	for i, x in { 1, 3, 5, 7, 9, 11, 13 } do
		put("ChillerCabinet", x, 11, 0, CHILLERS[(i - 1) % 3 + 1])
	end
	put("PottedPlant", 15, 11)
	put("Register", 8, 4, 3)
	put("ProduceCrate", 10, 4, 1, { "Strawberry" }) -- (and so the till's queue turns to run along its belt)
	put("ProduceCrate", 10, 3, 0, { "Carrot" })
	for _, at in { 1, 2, 3, 5, 6, 10, 11, 13, 14, 15 } do
		onWall("FairyLights", at)
	end
	onWall("PaintedSign", 4)
	onWall("Mural", 7)
	onWall("Clock", 9)
	onWall("NeonSign", 12)
	local fine, why, id = StoreLayout.check(layout, level)
	assert(fine, `the store's layout: {why} {id}`)

	local stage = StoreLayout.level(level).stage
	plot:SetAttribute("PlotIndex", index)
	StoreArt.buildBuilding(plot, level, "Hank's Market")
	for id, entry in layout do -- (StoreArt.placeItems, but for Model:PivotTo, which Lune hasn't got)
		local item = catalog[entry.item]:Clone()
		item.Name = id
		local at = PlotLayout.storeItemFrame(index, entry, stage)
		for _, part in item:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame = at * part.CFrame
			end
		end
		item.Parent = plot.Store.Items
	end
	local prices = {}
	for _, crop in Crops.List do
		prices[crop.id] = crop.value
	end
	for itemId, entry in layout do
		StoreArt.showDisplay(plot, itemId, entry, prices)
	end
	sources = { plot.Store }
elseif extras == "auction" then
	sources = { world.Town.AuctionHouse }
	frame = PlotLayout.buildingFrame("Auction")
elseif extras == "town" then
	sources = { world.Town, world.RingRoad, world.Sidewalk }
	frame = roblox.CFrame.new()
elseif extras == "valley" then
	sources = { world.Countryside, world.RingRoad, world.Sidewalk, world.BackTrail, world.Highway, world.Plot1, world.Plot2, world.Plot8 }
	frame = roblox.CFrame.new()
elseif extras == "bats" then
	-- the bat and its skins (Config/Cosmetics), standing in a row
	local CrimeArt = Harness.loadServerWith("World/CrimeArt", { Instance = roblox.Instance, workspace = game:GetService("Workspace") })
	local row = roblox.Instance.new("Model")
	for i, skin in { false, "GoldenBat", "Baguette", "CarrotClub" } do
		local bat = CrimeArt.bat(skin or nil)
		for _, part in bat:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame = roblox.CFrame.new(i * 2.5, 1.5, 0) * part.CFrame
			end
		end
		bat.Parent = row
	end
	sources = { row }
	frame = roblox.CFrame.new()
end
local all = {}
for _, source in sources do
	if source:IsA("BasePart") then
		table.insert(all, source)
	end
	for _, part in source:GetDescendants() do
		table.insert(all, part)
	end
end
local parts = {}
for _, part in all do
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
		local gui = part:FindFirstChildOfClass("SurfaceGui")
		local label = gui and gui:FindFirstChildOfClass("TextLabel")
		if label and label.Text ~= "" then -- (what it says, for stage.py to letter)
			entry.text = label.Text
			entry.textColor = { label.TextColor3.R, label.TextColor3.G, label.TextColor3.B }
			entry.textFont = label.Font.Name
		end
		if part:IsA("Part") then
			entry.shape = part.Shape.Name
			local special = part:FindFirstChildOfClass("SpecialMesh")
			if special and special.MeshType == roblox.Enum.MeshType.Sphere then
				entry.shape = "Ellipsoid"
			elseif special and special.MeshType == roblox.Enum.MeshType.Head then
				entry.shape = "Head" -- (the townspeople: shared/PeopleArt)
			end
		end
		table.insert(parts, entry)
		if part:FindFirstChild("Face") then -- (the face decal's stand-in: two eyes and a smile)
			local dark = { 0.16, 0.13, 0.12 }
			local s = part.Size.X / 1.3
			for _, x in { -0.2, 0.2 } do
				local eye = cf * roblox.CFrame.new(x * s, 0.18 * s, -0.6 * s)
				table.insert(parts, { name = "Eye", class = "Part", size = { 0.16, 0.22, 0.1 }, cframe = { eye:GetComponents() }, color = dark, shape = "Ball", transparency = 0 })
			end
			local smile = cf * roblox.CFrame.new(0, -0.1 * s, -0.6 * s)
			table.insert(parts, { name = "Smile", class = "Part", size = { 0.4, 0.07, 0.1 }, cframe = { smile:GetComponents() }, color = dark, transparency = 0 })
		end
	end
end
fs.writeFile(out, serde.encode("json", parts))
print(`{#parts} parts -> {out}`)
