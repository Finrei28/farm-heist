-- Builds everything the server can build into one world, for the flicker
-- check (tests/flicker.test.luau, tools/flicker): the greybox with its
-- town and police station, a warehouse side at each building's levels, a
-- store at each building's levels with every catalog item, scaffolding,
-- every crop at every stage, crates, the carried crops and the bat.
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
	YardArt.showHold(world.Plot1, { { crop = "Carrot", units = 12, grade = "A" }, { crop = "Pumpkin", units = 6, grade = "B" } })

	-- every crop at every stage, in a grid on the meadow beyond the valley
	local gallery = roblox.Instance.new("Folder")
	gallery.Name = "Gallery"
	gallery.Parent = world
	local origin = roblox.CFrame.new(0, 0, PlotLayout.HIGHWAY.to + 400)
	for i, crop in Crops.List do
		for s, stage in { "Seed", "Sprout", "Growing", "Ripe" } do
			FarmArt.cropModel(crop.id, stage, origin * roblox.CFrame.new(i * 14, 0, s * 14)).Parent = gallery
		end
		ProduceArt.build(crop.id, origin * roblox.CFrame.new(i * 14, 0, 80)).Parent = gallery
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
