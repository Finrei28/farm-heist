-- Builds everything the server can build into one world, for the flicker
-- check (tests/flicker.test.luau, tools/flicker): the greybox with its
-- town and police station, a warehouse side at each building's levels, a
-- store at each building's levels with every catalog item, scaffolding, a
-- whole field at every Field Level, every crop at every stage on a tilled
-- tile (ripe as it comes and on a bumper patch), crates, the carried crops
-- and the bat.
local roblox = require("@lune/roblox")

return function(harness)
	local PlotLayout = harness.load("PlotLayout")
	local Crops = harness.load("Config/Crops")
	local game = roblox.Instance.new("DataModel")
	local workspace = game:GetService("Workspace")
	local globals = { Instance = roblox.Instance, workspace = workspace }
	local WorldBuilder = harness.loadServerWith("World/WorldBuilder", globals)
	local YardArt = harness.loadServerWith("World/YardArt", globals)
	local StoreArt = harness.loadServerWith("World/StoreArt", globals)
	local StoreItems = harness.loadServerWith("World/StoreItems", globals)
	local FarmArt = harness.loadServerWith("World/FarmArt", globals)
	local CrimeArt = harness.loadServerWith("World/CrimeArt", globals)
	local ProduceArt = harness.loadServerWith("World/ProduceArt", globals)
	local world = WorldBuilder.Build()

	-- warehouses (Plot 1 keeps the Packing Shed) and stores, one level a plot
	for i, level in { 5, 10, 15, 20 } do
		YardArt.setLevel(world[`Plot{i + 1}`], level)
	end
	YardArt.showConstruction(world.Plot6, 5, 90)
	for i, level in { 1, 5, 10, 18, 20 } do
		StoreArt.buildBuilding(world[`Plot{i + 1}`], level, "Test")
	end
	StoreArt.showConstruction(world.Plot7, 5, 90)
	YardArt.showHold(world.Plot1, { { crop = "Carrot", units = 72, grade = "A" }, { crop = "Pumpkin", units = 6, grade = "B" } })

	-- a whole field, all of it cleared, at each Field Level (plot n + 1 at Level n)
	local everyBlock = {}
	for block = 1, 16 do
		table.insert(everyBlock, block)
	end
	for level = 1, 5 do
		local index = level + 1
		FarmArt.applyLand(world[`Plot{index}`], PlotLayout.frame(index), { cleared = everyBlock, fresh = {}, fieldLevel = level })
	end

	-- every crop at every stage, in a grid on the meadow beyond the valley
	local gallery = roblox.Instance.new("Folder")
	gallery.Name = "Gallery"
	gallery.Parent = world
	local origin = roblox.CFrame.new(0, 0, PlotLayout.HIGHWAY.to + 400)
	for i, crop in Crops.List do
		-- (on a tilled tile, its ridges and all: what the crop really stands on)
		for s, stage in { "Seed", "Sprout", "Growing", "Ripe", "Bumper" } do
			local tile = roblox.Instance.new("Part")
			tile.Name = `Tile{s}`
			tile.Anchored = true
			tile.Size = roblox.Vector3.new(11.4, 0.4, 11.4)
			tile.CFrame = origin * roblox.CFrame.new(i * 14, 0.3, s * 14)
			tile.Parent = gallery
			FarmArt.setTileOpen(tile, true)
			local count = if stage == "Bumper" then math.ceil(crop.perPatch * 1.5 - 1e-9) else crop.perPatch
			FarmArt.cropModel(crop.id, if stage == "Bumper" then "Ripe" else stage, tile.CFrame * roblox.CFrame.new(0, 0.2, 0), count).Parent = tile
		end
		ProduceArt.build(crop.id, origin * roblox.CFrame.new(i * 14, 0, 90)).Parent = gallery
	end
	local function move(model, cframe)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame = cframe * part.CFrame
			end
		end
	end
	local Store = harness.load("Config/Store")
	local ids = {}
	for id in Store.ITEMS do
		table.insert(ids, id)
	end
	table.sort(ids)
	for i, id in ids do
		local item = StoreItems.build(id)
		move(item, origin * roblox.CFrame.new(i * 20, 0, -60))
		item.Parent = gallery
	end
	local bat = CrimeArt.bat()
	bat.Parent = gallery
	return world, workspace
end
