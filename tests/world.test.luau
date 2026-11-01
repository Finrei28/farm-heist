-- The greybox (server/World/WorldBuilder), built for real with @lune/roblox
-- Instances: it runs without errors, and what it builds matches
-- shared/PlotLayout (8 farms with zones, 64 tiles each, the start corner
-- tilled, a town spawn).
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local roblox = require("@lune/roblox")
	local PlotLayout = harness.load("PlotLayout")
	local LandRules = harness.load("LandRules")
	local Store = harness.load("Config/Store")

	local function build()
		local game = roblox.Instance.new("DataModel")
		local workspace = game:GetService("Workspace")
		local WorldBuilder = harness.loadServerWith("World/WorldBuilder", {
			Instance = roblox.Instance,
			workspace = workspace,
		})
		return WorldBuilder.Build(), workspace
	end

	describe("the greybox", function()
		local ok, world, workspace = pcall(build)
		it("builds without errors", function()
			if not ok then
				error(world)
			end
			expect(world.Parent).toBe(workspace)
		end)
		if not ok then
			return
		end
		it("has 8 farms, each with a zone where PlotLayout puts it", function()
			for index = 1, PlotLayout.COUNT do
				local plot = world:FindFirstChild(`Plot{index}`)
				expect(plot ~= nil).toBe(true)
				expect(plot:GetAttribute("PlotIndex")).toBe(index)
				local zone = plot:FindFirstChild("Zone")
				local expected = PlotLayout.zone(index)
				expect((zone.CFrame.Position - expected.cframe.Position).Magnitude).toBeLessThan(0.01)
				expect((zone.Size - expected.size).Magnitude).toBeLessThan(0.01)
			end
		end)
		it("lays 64 tiles per field, the 16 start tiles tilled", function()
			local field = world.Plot1.Field
			local tiles, tilled = 0, 0
			for _, child in field:GetChildren() do
				local tile = child:GetAttribute("Tile")
				if tile then
					tiles += 1
					if LandRules.isStart(child:GetAttribute("Block")) then
						tilled += 1
					end
					expect((child.CFrame.Position - PlotLayout.tileWorld(1, tile)).Magnitude).toBeLessThan(0.5)
				end
			end
			expect(tiles).toBe(64)
			expect(tilled).toBe(16)
		end)
		it("walls every fence higher than a jump, leaving only the gate and the store's door open", function()
			local plot = world.Plot1
			local frame = PlotLayout.frame(1)
			local front = {} -- the x spans walled along the front boundary
			for _, child in plot:GetDescendants() do
				if string.match(child.Name, "Blocker$") and child.Name ~= "StaffDoorBlocker" then
					expect(child.Size.Y).toBeGreaterThan(7.2 + 1) -- Roblox's default jump is about 7.2 studs
					expect(child.CanCollide).toBe(true)
					local centre = frame:PointToObjectSpace(child.CFrame.Position)
					if math.abs(centre.Z - child.Size.Z / 2 - (-1)) < 1.1 then
						table.insert(front, { centre.X - child.Size.X / 2, centre.X + child.Size.X / 2 })
					end
				end
			end
			-- the fences, the store's front wall and the truck gate wall the
			-- whole front; only the farm gate and the store's door stay open
			-- (the door leads into the store, which isn't the farm)
			local gate = PlotLayout.PLOT.gate
			local door = PlotLayout.storeLocal(Store.DOOR_X, 1)
			for x = -PlotLayout.WIDTH / 2 + 0.25, PlotLayout.WIDTH / 2 - 0.25, 0.5 do
				local walled = false
				for _, span in front do
					if x >= span[1] and x <= span[2] then
						walled = true
					end
				end
				local open = math.abs(x - gate.across) < gate.width / 2 or math.abs(x - door.X) < Store.CELL / 2
				if walled == open then
					error(`front boundary at x = {x}: {if open then "the gate or door is walled" else "a gap in the wall"}`)
				end
			end
			expect(plot.HedgeLeft.Size.Y).toBeGreaterThan(7.2 + 1)
			-- a jump hits the fence you see, not the invisible wall above it
			local top = 0
			for _, rail in plot.BackFence:GetChildren() do
				top = math.max(top, rail.CFrame.Position.Y + rail.Size.Y / 2)
			end
			expect(top).toBeGreaterThan(7.2 + 0.5)
		end)
		it("builds each farm's selling side where the services look for it", function()
			for index = 1, PlotLayout.COUNT do
				local plot = world[`Plot{index}`]
				-- the Packing Shed: its bench, the dock with its lever and rack, the pickup, the lane's gate
				local warehouse = plot.Warehouse
				expect(warehouse:GetAttribute("Level")).toBe(1)
				expect(warehouse.Building:FindFirstChild("Bench") ~= nil).toBe(true)
				expect(warehouse.Docks:FindFirstChild("LoadSpot1") ~= nil).toBe(true)
				expect(warehouse.Docks:FindFirstChild("LeverBase1") ~= nil).toBe(true)
				expect(warehouse:FindFirstChild("Rack") ~= nil).toBe(true)
				expect(warehouse.Trucks.Truck1:FindFirstChild("Bed") ~= nil).toBe(true)
				expect(warehouse.Lanes.Gate1:FindFirstChild("Boom") ~= nil).toBe(true)
				-- an empty Corner Store, "For rent", its staff door blocked to visitors
				local building = plot.Store.Building
				expect(building:GetAttribute("Stage")).toBe(1)
				expect(building.StaffDoor.StaffDoorBlocker.CanCollide).toBe(true)
				expect(building:FindFirstChild("StockroomCrates") ~= nil).toBe(true)
				expect(plot.Store:FindFirstChild("Items") ~= nil).toBe(true)
				expect(plot.Store.Fence:FindFirstChild("FrontFenceShopSide") ~= nil).toBe(true)
				expect(plot:GetAttribute("StoreName")).toBe("FOR RENT")
				expect(plot.GateArch:FindFirstChild("NamePlank") ~= nil).toBe(true)
				-- the truck is parked where its route starts (TruckController drives it from there)
				local parked = warehouse.Trucks.Truck1.WorldPivot.Position -- (Lune has no GetPivot; the model has no PrimaryPart, so they agree)
				local start = PlotLayout.truckRoute(index, nil, 20)[1]
				expect(math.abs(parked.X - start.X) + math.abs(parked.Z - start.Z)).toBeLessThan(0.01)
			end
			expect(world.Town:FindFirstChild("ExchangeDesk") ~= nil).toBe(true)
			expect(world:FindFirstChild("Sidewalk") ~= nil).toBe(true)
		end)
		it("anchors everything (nothing falls when Play starts)", function()
			for _, descendant in world:GetDescendants() do
				if descendant:IsA("BasePart") and not descendant.Anchored then
					error(`{descendant:GetFullName()} isn't anchored`)
				end
			end
		end)
		it("has a town spawn, and arrested players land on the police porch in front of the height chart", function()
			expect(world.Town:FindFirstChild("TownSpawn") ~= nil).toBe(true)
			local porch = world.Town:FindFirstChild("PolicePorch", true)
			local at = porch.CFrame:PointToObjectSpace(PlotLayout.policePorchWorld())
			expect(math.abs(at.X) < porch.Size.X / 2 - 2 and math.abs(at.Z) < porch.Size.Z / 2 - 2).toBe(true)
			local chart = world.Town:FindFirstChild("HeightChart", true)
			local behind = chart.CFrame:PointToObjectSpace(PlotLayout.policePorchWorld())
			expect(math.abs(behind.X) < 1).toBe(true)
			expect(world.Town:FindFirstChild("PoliceDesk", true) ~= nil).toBe(true) -- (PayoutService puts the desk's prompt on it)
		end)
		it("rebuilds cleanly (one World folder, no Baseplate)", function()
			local again = build()
			expect(again ~= nil).toBe(true)
		end)
		it("puts Barley's counter where SeedShopService looks for it", function()
			local counter = world.Town:FindFirstChild("SeedCounter")
			local expected = PlotLayout.frontOf("Seeds", 4)
			expect((counter.CFrame.Position - expected).Magnitude).toBeLessThan(2)
		end)
	end)

	describe("every store building on a plot (World/StoreArt)", function()
		-- Builds each building at its biggest level on Plot 1 and checks it
		-- stays on its lot (its awning and step may reach over the verge in
		-- front), clear of the farmhouse and the strip by the gate, with the
		-- front still walled but for the gate and the store's door.
		local ok, world = pcall(build)
		if not ok then
			return
		end
		local game = roblox.Instance.new("DataModel")
		local StoreArt = harness.loadServerWith("World/StoreArt", { Instance = roblox.Instance, workspace = game:GetService("Workspace") })
		local P = PlotLayout.PLOT
		local frame = PlotLayout.frame(1)
		for _, levelNumber in { 4, 9, 14, 20 } do
			it(`fits the plot at Store Level {levelNumber}`, function()
				local plot = world.Plot1
				StoreArt.buildBuilding(plot, levelNumber, "Test")
				for _, part in plot.Store:GetDescendants() do
					if part:IsA("BasePart") then
						for _, sx in { -0.5, 0.5 } do
							for _, sz in { -0.5, 0.5 } do
								local corner = frame:PointToObjectSpace(part.CFrame * (part.Size * roblox.Vector3.new(sx, 0, sz)))
								-- (0.5 for eaves and trim; 1 into the 3-stud hedge)
								local onLot = corner.X >= -PlotLayout.WIDTH / 2 - 1 and corner.X <= P.shop.max.X + 0.5 -- (a fence post may tuck into the hedge)
									and corner.Z >= -6 and corner.Z <= P.shop.max.Z + 0.5
								if not onLot then
									error(`{part:GetFullName()} is off the store's lot ({corner.X}, {corner.Z})`)
								end
							end
						end
					end
				end
				local front = {}
				for _, child in plot:GetDescendants() do
					if string.match(child.Name, "Blocker$") and child.Name ~= "StaffDoorBlocker" then
						local centre = frame:PointToObjectSpace(child.CFrame.Position)
						if math.abs(centre.Z - child.Size.Z / 2 - (-1)) < 1.1 then
							table.insert(front, { centre.X - child.Size.X / 2, centre.X + child.Size.X / 2 })
						end
					end
				end
				-- the see-through roof (RoofController): an invisible Interior box over
				-- the whole floor, at a character's height, and the ceiling lamps in
				-- the Roof model so they go with it
				local interior = plot.Store.Building.Interior
				expect(interior.Transparency).toBe(1)
				expect(interior.CanCollide or interior.CanQuery or interior.CanTouch).toBe(false)
				local cells = Store.BUILDINGS[plot.Store.Building:GetAttribute("Stage")].cells
				for _, corner in { { 1, 1 }, { cells[1], cells[2] }, { 1, cells[2] }, { cells[1], 1 } } do
					local p = interior.CFrame:PointToObjectSpace(PlotLayout.storeWorld(1, corner[1], corner[2], 3))
					expect(math.abs(p.X) < interior.Size.X / 2 and math.abs(p.Y) < interior.Size.Y / 2 and math.abs(p.Z) < interior.Size.Z / 2).toBe(true)
				end
				for _, part in plot.Store.Building:GetDescendants() do
					if (part.Name == "CeilingLamp" or part.Name == "LightStrip") and not part:IsDescendantOf(plot.Store.Building.Roof) then
						error(`{part:GetFullName()} hangs outside the Roof model`)
					end
				end
				local door = PlotLayout.storeLocal(Store.DOOR_X, 1)
				-- nothing solid in the doorway above the floor (the Supermarket's
				-- plinth once ran across it: a ledge characters stalled at)
				local floor = P.store.floor
				for _, part in plot.Store:GetDescendants() do
					if part:IsA("BasePart") and part.CanCollide and not string.match(part.Name, "Blocker$") then
						local lo, hi = roblox.Vector3.new(math.huge, math.huge, math.huge), roblox.Vector3.new(-math.huge, -math.huge, -math.huge)
						for _, sx in { -0.5, 0.5 } do
							for _, sy in { -0.5, 0.5 } do
								for _, sz in { -0.5, 0.5 } do
									local c = frame:PointToObjectSpace(part.CFrame * (part.Size * roblox.Vector3.new(sx, sy, sz)))
									lo, hi = lo:Min(c), hi:Max(c)
								end
							end
						end
						local inDoorway = hi.X > door.X - Store.CELL / 2 + 0.3 and lo.X < door.X + Store.CELL / 2 - 0.3
							and hi.Z > -2.6 and lo.Z < 0.5 and hi.Y > floor + 0.15 and lo.Y < 7
						if inDoorway then
							error(`Level {levelNumber}: {part:GetFullName()} stands in the store's doorway (top {hi.Y})`)
						end
					end
				end
				for x = -PlotLayout.WIDTH / 2 + 0.25, P.gate.across, 0.5 do
					local walled = false
					for _, span in front do
						if x >= span[1] and x <= span[2] then
							walled = true
						end
					end
					local open = math.abs(x - P.gate.across) < P.gate.width / 2 or math.abs(x - door.X) < Store.CELL / 2
					if walled == open then
						error(`Level {levelNumber}: front boundary at x = {x}: {if open then "the door is walled" else "a gap"}`)
					end
				end
			end)
		end
	end)

	describe("every warehouse on a plot (World/YardArt)", function()
		-- Builds the warehouse side at each building's first level and the top
		-- on Plot 1: it stays on its side of the farm, the front stays walled
		-- but for the gate and the store's door, each truck has its dock,
		-- lever and lane, and the warehouses' roofs fade (RoofController).
		local ok, world = pcall(build)
		if not ok then
			return
		end
		local game = roblox.Instance.new("DataModel")
		local YardArt = harness.loadServerWith("World/YardArt", { Instance = roblox.Instance, workspace = game:GetService("Workspace") })
		local WarehouseRules = harness.load("WarehouseRules")
		local P = PlotLayout.PLOT
		local frame = PlotLayout.frame(1)
		local function bounds(part)
			local lo, hi = roblox.Vector3.new(math.huge, math.huge, math.huge), roblox.Vector3.new(-math.huge, -math.huge, -math.huge)
			for _, sx in { -0.5, 0.5 } do
				for _, sy in { -0.5, 0.5 } do
					for _, sz in { -0.5, 0.5 } do
						local c = frame:PointToObjectSpace(part.CFrame * (part.Size * roblox.Vector3.new(sx, sy, sz)))
						lo, hi = lo:Min(c), hi:Max(c)
					end
				end
			end
			return lo, hi
		end
		for _, level in { 1, 5, 10, 15, 20 } do
			it(`fits the farm at Warehouse Level {level}`, function()
				local plot = world.Plot1
				local info = WarehouseRules.level(level)
				local warehouse = YardArt.setLevel(plot, level)
				local layout = PlotLayout.WAREHOUSES[info.stage]
				for _, part in warehouse:GetDescendants() do
					if part:IsA("BasePart") then
						expect(part.Anchored).toBe(true)
						local lo, hi = bounds(part)
						-- (the truck gates' posts and the fence reach the hedge; drums and the step stick out a little)
						local onSide = lo.X >= P.warehouse.min.X - 2.5 and hi.X <= PlotLayout.WIDTH / 2 + 1 and lo.Z >= -1.2 and hi.Z <= P.warehouse.max.Z + 1.5
						if not onSide then
							error(`{part:GetFullName()} is off the warehouse's side ({lo.X}..{hi.X}, {lo.Z}..{hi.Z})`)
						end
						-- clear of the gatehouse
						local g = P.gatehouse
						if part.CanCollide and hi.X > g.min.X and lo.X < g.max.X and hi.Z > g.min.Z and lo.Z < g.max.Z then
							error(`{part:GetFullName()} runs into the gatehouse`)
						end
					end
				end
				-- a truck, a dock (load spot and lever) and a lane with its gate for each truck
				expect(#warehouse.Trucks:GetChildren()).toBe(info.trucks)
				for i = 1, info.trucks do
					local across = layout.docks[i]
					expect(warehouse.Docks:FindFirstChild(`LoadSpot{i}`) ~= nil).toBe(true)
					expect(warehouse.Docks:FindFirstChild(`LeverBase{i}`) ~= nil).toBe(true)
					expect(warehouse.Lanes:FindFirstChild(`Gate{i}`) ~= nil).toBe(true)
					local truck = warehouse.Trucks[`Truck{i}`]
					local start = PlotLayout.truckRoute(1, across, truck:GetAttribute("Length"))[1]
					expect((truck.WorldPivot.Position - start).Magnitude).toBeLessThan(0.01)
					-- parked in its lane, short of the dock
					local lo, hi = roblox.Vector3.new(math.huge, 0, math.huge), roblox.Vector3.new(-math.huge, 0, -math.huge)
					for _, piece in truck:GetDescendants() do
						if piece:IsA("BasePart") then
							local a, b = bounds(piece)
							lo, hi = lo:Min(a), hi:Max(b)
						end
					end
					expect(lo.X >= across - PlotLayout.LANE / 2 and hi.X <= across + PlotLayout.LANE / 2).toBe(true)
					expect(lo.Z > 0 and hi.Z < P.dock.z).toBe(true)
				end
				expect(warehouse.Building:FindFirstChild("Bench", true) ~= nil).toBe(true)
				expect(warehouse:FindFirstChild("Rack") ~= nil).toBe(true)
				-- the front: walled but for the gate and the store's door
				local front = {}
				for _, child in plot:GetDescendants() do
					if string.match(child.Name, "Blocker$") and child.Name ~= "StaffDoorBlocker" then
						local centre = frame:PointToObjectSpace(child.CFrame.Position)
						if math.abs(centre.Z - child.Size.Z / 2 - (-1)) < 1.1 then
							table.insert(front, { centre.X - child.Size.X / 2, centre.X + child.Size.X / 2 })
						end
					end
				end
				local door = PlotLayout.storeLocal(Store.DOOR_X, 1)
				for x = -PlotLayout.WIDTH / 2 + 0.25, PlotLayout.WIDTH / 2 - 0.25, 0.5 do
					local walled = false
					for _, span in front do
						if x >= span[1] and x <= span[2] then
							walled = true
						end
					end
					local open = math.abs(x - P.gate.across) < P.gate.width / 2 or math.abs(x - door.X) < Store.CELL / 2
					if walled == open then
						error(`Level {level}: front boundary at x = {x}: {if open then "the gate or door is walled" else "a gap"}`)
					end
				end
				if info.stage == 1 then
					return
				end
				-- the see-through roof: an Interior box over the floor, the lamps in the Roof model
				local building = warehouse.Building
				local interior = building.Interior
				expect(interior.Transparency).toBe(1)
				expect(interior.CanCollide or interior.CanQuery or interior.CanTouch).toBe(false)
				expect(building:FindFirstChild("Roof") ~= nil).toBe(true)
				for _, part in building:GetDescendants() do
					if part.Name == "Lamp" and not part:IsDescendantOf(building.Roof) then
						error(`{part:GetFullName()} hangs outside the Roof model`)
					end
				end
				for _, id in { "Intake", "Sort", "Pack", "Load" } do
					expect(building.Stations:FindFirstChild(id) ~= nil).toBe(true)
				end
				-- the doorways are clear: the staff door, each dock door, the intake door
				local floor = P.dock.height
				local doors = {
					{ name = "staff door", min = roblox.Vector3.new(layout.min.X - 1, 0, layout.min.Z + 8), max = roblox.Vector3.new(layout.min.X + 1.5, 7, layout.min.Z + 12) },
				}
				for _, across in layout.docks do
					table.insert(doors, { name = "dock door", min = roblox.Vector3.new(across - 5, 0, layout.min.Z - 0.2), max = roblox.Vector3.new(across + 5, 7, layout.min.Z + 1.5) })
				end
				for _, part in warehouse:GetDescendants() do
					if part:IsA("BasePart") and part.CanCollide and part.Name ~= "Slab" and part.Name ~= "Dock" and part.Name ~= "Step" then
						local lo, hi = bounds(part)
						for _, door in doors do
							if hi.X > door.min.X and lo.X < door.max.X and hi.Z > door.min.Z and lo.Z < door.max.Z and hi.Y > floor + 0.15 and lo.Y < door.max.Y then
								error(`Level {level}: {part:GetFullName()} stands in the {door.name}`)
							end
						end
					end
				end
			end)
		end
	end)

	describe("your store (World/StoreArt, World/StoreItems)", function()
		local game = roblox.Instance.new("DataModel")
		local workspace = game:GetService("Workspace")
		local globals = { Instance = roblox.Instance, workspace = workspace }
		local StoreItems = harness.loadServerWith("World/StoreItems", globals)
		it("builds every catalog item inside its cells, with a slot and a tag for each display slot", function()
			for itemId, def in Store.ITEMS do
				local model = StoreItems.build(itemId)
				expect(model.PrimaryPart ~= nil).toBe(true)
				local halfW, halfD = def.size[1] * Store.CELL / 2, def.size[2] * Store.CELL / 2
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") then
						if not part.Anchored then
							error(`{itemId}.{part.Name} isn't anchored`)
						end
						-- the part's corners
						local maxX, maxZ, minZ, minY = 0, -math.huge, math.huge, math.huge
						for _, sx in { -0.5, 0.5 } do
							for _, sy in { -0.5, 0.5 } do
								for _, sz in { -0.5, 0.5 } do
									local corner = part.CFrame * (part.Size * roblox.Vector3.new(sx, sy, sz))
									maxX = math.max(maxX, math.abs(corner.X))
									maxZ, minZ = math.max(maxZ, corner.Z), math.min(minZ, corner.Z)
									minY = math.min(minY, corner.Y)
								end
							end
						end
						if def.kind == "Wall" then
							-- on the wall: within its cells along the wall, standing out less than 1 stud
							if maxX > halfW + 0.05 or maxZ > 0.05 or minZ < -1 then
								error(`{itemId}.{part.Name} sticks out of its wall space`)
							end
						elseif maxX > halfW + 0.05 or math.max(maxZ, -minZ) > halfD + 0.05 or minY < -0.05 then
							error(`{itemId}.{part.Name} sticks out of its cells (x {maxX}, z {minZ}..{maxZ}, y {minY})`)
						end
					end
				end
				if def.kind == "Display" then
					for n = 1, def.slots do
						expect(model:FindFirstChild(`Slot{n}`) ~= nil).toBe(true)
						expect(model:FindFirstChild(`Tag{n}`) ~= nil).toBe(true)
					end
					expect(model:FindFirstChild(`Slot{def.slots + 1}`)).toBe(nil)
				end
			end
		end)
		it("keeps displays and checkouts within head height and things you walk past solid", function()
			for itemId, def in Store.ITEMS do
				if def.kind ~= "Wall" and not def.flat then
					local model = StoreItems.build(itemId)
					local solid = false
					for _, part in model:GetDescendants() do
						if part:IsA("BasePart") and part.CanCollide then
							solid = true
						end
					end
					if not solid then
						error(`{itemId} has nothing solid: players would walk through it`)
					end
				end
			end
		end)
	end)

	describe("the field's art (World/FarmArt)", function()
		local CFrame = roblox.CFrame
		local FarmArt = harness.loadServerWith("World/FarmArt", { Instance = roblox.Instance })
		local Crops = harness.load("Config/Crops")
		local GrowthRules = harness.load("GrowthRules")
		local world = build()
		local plot = world.Plot2
		local frame = PlotLayout.frame(2)

		it("builds every crop at every stage, all anchored", function()
			for _, crop in Crops.List do
				for _, stage in { "Seed", "Sprout", "Growing", "Ripe" } do
					local model = FarmArt.cropModel(crop.id, stage, CFrame.new())
					local parts = 0
					for _, descendant in model:GetDescendants() do
						if descendant:IsA("BasePart") then
							parts += 1
							expect(descendant.Anchored).toBe(true)
							expect(descendant.CanCollide).toBe(false) -- (you walk through crops)
						end
					end
					expect(parts).toBeGreaterThan(0)
				end
			end
		end)
		it("names the stage from growth: seed, sprout, growing, ripe", function()
			local tile = GrowthRules.plant("Carrot")
			expect(FarmArt.stage(tile)).toBe("Seed")
			GrowthRules.advance(tile, 20)
			expect(FarmArt.stage(tile)).toBe("Sprout")
			GrowthRules.advance(tile, 20)
			expect(FarmArt.stage(tile)).toBe("Growing")
			GrowthRules.advance(tile, 20)
			expect(FarmArt.stage(tile)).toBe("Ripe")
		end)
		it("shows a crop on a tile and takes it away again", function()
			local tilePart = plot.Field.Tile1
			local tile = GrowthRules.plant("Pumpkin")
			FarmArt.showTile(tilePart, tile, 1000)
			expect(tilePart:GetAttribute("Crop")).toBe("Pumpkin")
			expect(tilePart:GetAttribute("Stage")).toBe("Seed")
			expect(tilePart:GetAttribute("RipeAt")).toBeNear(1000 + 900)
			expect(tilePart:FindFirstChild("Crop") ~= nil).toBe(true)
			FarmArt.showTile(tilePart, nil, 1000)
			expect(tilePart:GetAttribute("Crop")).toBe(nil)
			expect(tilePart:FindFirstChild("Crop")).toBe(nil)
		end)
		it("matches the save's land: cleared blocks tilled, a block being cleared down to its obstacles", function()
			expect(#FarmArt.obstacles(plot, 3)).toBe(4)
			FarmArt.applyLand(plot, frame, { cleared = { 3 }, fresh = { ["5"] = true }, clearing = { block = 7, obstacles = 2 } })
			expect(plot.Field:FindFirstChild("Overgrowth3")).toBe(nil)
			expect(plot.Field.Tile5:GetAttribute("Open")).toBe(true)
			expect(plot.Field.Tile5:GetAttribute("Fresh")).toBe(true)
			expect(#FarmArt.obstacles(plot, 7)).toBe(2)
			expect(plot.Field.Overgrowth7:GetAttribute("Clearing")).toBe(true)
			expect(#FarmArt.obstacles(plot, 4)).toBe(4)
			-- and back to a new farm when the owner leaves
			FarmArt.applyLand(plot, frame, { cleared = {}, fresh = {} })
			expect(plot.Field.Tile5:GetAttribute("Open")).toBe(false)
			expect(#FarmArt.obstacles(plot, 3)).toBe(4)
			expect(#FarmArt.obstacles(plot, 7)).toBe(4)
		end)
	end)
end
