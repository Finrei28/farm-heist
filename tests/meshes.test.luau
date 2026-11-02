-- The low-poly meshes (World/Meshes and the CropMeshData and PropMeshData
-- that tools/crop_art writes): every piece a layout names was drawn; every
-- crop has a patch growing and ripe for any number a patch can give, a
-- load for any number a thief can hold, and a piece for shelves; every
-- obstacle kind has its mesh; tilled tiles are the furrowed soil. FarmArt, ProduceArt, StoreArt, YardArt and
-- StoreItems build them once they're imported (stand-ins here), nothing in
-- them to bump into, never more shelf pieces than the balls they replace,
-- and the part-built stand-ins until then. (The generator checks the
-- meshes' own triangles stay on their tile or block.)
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local roblox = require("@lune/roblox")
	local Crops = harness.load("Config/Crops")
	local Land = harness.load("Config/Land")
	local Store = harness.load("Config/Store")
	local LandRules = harness.load("LandRules")
	local PlotLayout = harness.load("PlotLayout")
	local Parts = harness.loadServer("World/Parts")
	local DATA = harness.loadServer("World/CropMeshData")
	local PROPS = harness.loadServer("World/PropMeshData")

	local game = roblox.Instance.new("DataModel")
	local globals = { Instance = roblox.Instance, workspace = game:GetService("Workspace") }

	-- stand-ins for an import: a MeshPart for each mesh, the size it was drawn
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
	local cropModels = standIns("CropModels", DATA.meshes)
	local propModels = standIns("PropModels", PROPS.meshes)

	local function most(crop)
		return math.ceil(crop.perPatch * 1.5 - 1e-9)
	end

	local function meshParts(model)
		local out = {}
		for _, part in model:GetDescendants() do
			if part:IsA("MeshPart") then
				table.insert(out, part)
			end
		end
		return out
	end

	local function named(model, name)
		local n = 0
		for _, part in model:GetDescendants() do
			if part.Name == name then
				n += 1
			end
		end
		return n
	end

	local function noBumps(model, where)
		for _, part in model:GetDescendants() do
			if part:IsA("MeshPart") and (part.CanCollide or part.CanTouch) then
				error(`{where}: {part.Name} can be bumped into`)
			end
		end
	end

	describe("meshes (World/Meshes)", function()
		it("draws every mesh a patch, a carried load or a shelf piece names", function()
			local function check(items, where)
				for _, item in items do
					if not DATA.meshes[item[1]] then
						error(`{where}: no mesh {item[1]}`)
					end
				end
			end
			for crop, layouts in DATA.patches do
				check(layouts.Growing, `{crop} Growing`)
				for n, items in layouts.Ripe do
					check(items, `{crop} Ripe {n}`)
				end
			end
			for crop, loads in DATA.carried do
				for n, load in loads do
					check(load.items, `{crop} carried {n}`)
				end
			end
			for crop, shelf in DATA.shelf do
				for n, items in shelf.pieces do
					check(items, `{crop} shelf piece {n}`)
				end
			end
		end)

		it("has every crop growing, ripe with as many as a patch can give, carried and on a shelf", function()
			for _, crop in Crops.List do
				local layouts = DATA.patches[crop.id]
				expect(layouts ~= nil and #layouts.Growing > 0).toBe(true)
				if #layouts.Ripe < most(crop) then
					error(`{crop.id}: ripe patches up to {#layouts.Ripe}, a patch can give {most(crop)}`)
				end
				expect(DATA.carried[crop.id] ~= nil and #DATA.carried[crop.id] >= most(crop)).toBe(true)
				local shelf = DATA.shelf[crop.id]
				expect(shelf ~= nil and #shelf.pieces > 0 and shelf.size.Magnitude > 0.5).toBe(true)
			end
		end)

		it("draws every obstacle kind and the grass of wild land from the props", function()
			local kinds = 0
			for kind, items in PROPS.wild.obstacles do
				kinds += 1
				for _, item in items do
					if not PROPS.meshes[item[1]] then
						error(`obstacle {kind}: no prop {item[1]}`)
					end
				end
			end
			expect(kinds).toBe(Land.OBSTACLES)
			for _, item in PROPS.wild.grass do
				expect(PROPS.meshes[item[1]] ~= nil).toBe(true)
			end
			-- (a crop and a prop never share a name: each import has its own)
			for name in PROPS.meshes do
				expect(DATA.meshes[name]).toBe(nil)
			end
		end)

		harness.setStorageChild("CropModels", cropModels)
		harness.setStorageChild("PropModels", propModels)
		local FarmArt = harness.loadServerWith("World/FarmArt", globals)
		local ProduceArt = harness.loadServerWith("World/ProduceArt", globals)
		local StoreArt = harness.loadServerWith("World/StoreArt", globals)
		local StoreItems = harness.loadServerWith("World/StoreItems", globals)
		local YardArt = harness.loadServerWith("World/YardArt", globals)

		it("builds each patch from the meshes, on its tile, nothing to bump into", function()
			for _, crop in Crops.List do
				local runs = { { "Sprout", crop.perPatch }, { "Growing", crop.perPatch } }
				for n = 1, most(crop) do
					table.insert(runs, { "Ripe", n })
				end
				for _, run in runs do
					local stage, n = run[1], run[2]
					local model = FarmArt.cropModel(crop.id, stage, roblox.CFrame.new(), n)
					local parts = meshParts(model)
					local expected = if stage == "Sprout" then 6 elseif stage == "Growing" then #DATA.patches[crop.id].Growing else #DATA.patches[crop.id].Ripe[n]
					if #parts ~= expected then
						error(`{crop.id} {stage} {n}: {#parts} meshes, the layout has {expected}`)
					end
					for _, part in model:GetDescendants() do
						if part:IsA("BasePart") then
							if part.CanCollide or part.CanTouch then
								error(`{crop.id}: {part.Name} can be bumped into`)
							end
							local p = part.CFrame.Position
							if math.abs(p.X) > 6 or math.abs(p.Z) > 6 or p.Y < -1 or p.Y > 10 then
								error(`{crop.id} {stage} {n}: {part.Name} at {p} is off its tile`)
							end
						end
					end
					if stage == "Ripe" then
						expect(model:FindFirstChild("Shine") ~= nil).toBe(true)
					end
				end
			end
		end)

		it("gives the glowing pieces their glow, and the Phoenix Pepper its flames", function()
			local model = FarmArt.cropModel("PhoenixPepper", "Ripe", roblox.CFrame.new(), 1)
			local tip = model:FindFirstChild("PhoenixTip")
			expect(tip ~= nil and tip.Material == roblox.Enum.Material.Neon).toBe(true)
			expect(tip:FindFirstChild("Flame") ~= nil).toBe(true)
			local melon = FarmArt.cropModel("Moonmelon", "Ripe", roblox.CFrame.new(), 1)
			expect(melon:FindFirstChild("MoonmelonGlow").Material == roblox.Enum.Material.Neon).toBe(true)
		end)

		it("builds what a thief holds from the meshes, the size it says", function()
			for _, crop in Crops.List do
				for _, n in { 1, crop.perPatch, most(crop) } do
					local model, core = ProduceArt.build(crop.id, roblox.CFrame.new(), n)
					local width, height, hold = core:GetAttribute("Width"), core:GetAttribute("Height"), core:GetAttribute("HoldY")
					expect(width > 0.5 and height > 0.5 and hold > 0 and hold < height).toBe(true)
					local parts = meshParts(model)
					if #parts ~= #DATA.carried[crop.id][n].items then
						error(`{crop.id} ×{n}: {#parts} meshes`)
					end
					for _, part in parts do
						if part.CanCollide or part.CanTouch then
							error(`{crop.id}: {part.Name} can be bumped into`)
						end
						local p = part.CFrame.Position
						if math.abs(p.X) > width / 2 + 0.6 or p.Y < -0.3 or p.Y > height + 0.3 then
							error(`{crop.id} ×{n}: {part.Name} at {p} is outside {width} × {height}`)
						end
					end
				end
			end
		end)

		-- a store with one of each display, for its shelves
		local function displays()
			local plot = roblox.Instance.new("Model")
			local store = roblox.Instance.new("Model")
			store.Name = "Store"
			store.Parent = plot
			local items = roblox.Instance.new("Folder")
			items.Name = "Items"
			items.Parent = store
			local ids = {}
			for id, def in Store.ITEMS do
				if def.kind == "Display" then
					local item = StoreItems.build(id)
					item.Name = id
					item.Parent = items
					table.insert(ids, id)
				end
			end
			table.sort(ids)
			return plot, ids
		end

		it("fills displays with each crop's own pieces, never more than the balls they replace, inside the display", function()
			local Balls = harness.loadServerWith("World/StoreArt", globals) -- (its own copy: called with nothing imported)
			for _, crop in Crops.List do
				local withMeshes, ids = displays()
				local withBalls = displays()
				for _, id in ids do
					local def = Store.ITEMS[id]
					local slots = {}
					for n = 1, def.slots do
						slots[n] = { crop = crop.id, units = def.patches * crop.perPatch }
					end
					StoreArt.showDisplay(withMeshes, id, { item = id, slots = slots }, {})
					harness.setStorageChild("CropModels", nil)
					Balls.showDisplay(withBalls, id, { item = id, slots = slots }, {})
					harness.setStorageChild("CropModels", cropModels)
					local item = withMeshes.Store.Items[id]
					local pieces = #meshParts(item)
					local balls = named(withBalls.Store.Items[id], "Produce")
					if pieces == 0 or balls == 0 then
						error(`{crop.id} on a {id}: {pieces} pieces, {balls} balls`)
					end
					-- (a piece is one mesh, or two for a glowing one)
					local per = #DATA.shelf[crop.id].pieces[1]
					if pieces > balls * per then
						error(`{crop.id} on a {id}: {pieces / per} pieces, more than its {balls} balls`)
					end
					expect(named(item, "Produce")).toBe(0)
					noBumps(item, `{crop.id} on a {id}`)
					local w, d = def.size[1] * Store.CELL, def.size[2] * Store.CELL
					for _, part in meshParts(item) do
						local p = part.CFrame.Position
						if math.abs(p.X) > w / 2 + 0.3 or math.abs(p.Z) > d / 2 + 0.3 then
							error(`{crop.id} on a {id}: a piece at {p} is off the display ({w} × {d})`)
						end
					end
				end
			end
		end)

		it("shows a half-full display half full", function()
			local plot = displays()
			local id = "WoodenShelf"
			local def = Store.ITEMS[id]
			local full = def.patches * 6
			StoreArt.showDisplay(plot, id, { item = id, slots = { { crop = "Carrot", units = full }, { crop = "Carrot", units = full / 2 } } }, {})
			local item = plot.Store.Items[id]
			local function inSlot(n)
				local count = 0
				for _, region in item:GetChildren() do
					if region.Name == `Slot{n}` or string.match(region.Name, `^Slot{n}_%d+$`) then
						count += #meshParts(region)
					end
				end
				return count
			end
			expect(inSlot(2) > 0 and inSlot(2) < inSlot(1)).toBe(true)
		end)

		it("heaps a crate's produce on top, as full as the crate is", function()
			local folder = roblox.Instance.new("Folder")
			local fullCrate = YardArt.crate({ crop = "Tomato", units = 60, grade = "A" }, roblox.CFrame.new(), folder)
			local halfCrate = YardArt.crate({ crop = "Tomato", units = 20, grade = "B" }, roblox.CFrame.new(10, 0, 0), folder)
			local empty = YardArt.crate({ crop = "Tomato", units = 0, grade = "B" }, roblox.CFrame.new(20, 0, 0), folder)
			expect(#meshParts(fullCrate) > #meshParts(halfCrate) and #meshParts(halfCrate) > 0).toBe(true)
			expect(#meshParts(empty)).toBe(0)
			expect(named(fullCrate, "Produce")).toBe(0)
			noBumps(fullCrate, "a crate")
			for _, crop in Crops.List do
				local crate = YardArt.crate({ crop = crop.id, units = crop.crate, grade = "B" }, roblox.CFrame.new(), folder)
				expect(#meshParts(crate) > 0).toBe(true)
			end
		end)

		it("puts real pumpkins on the Pumpkin Pile and fruit on the Fruit Cart", function()
			expect(named(StoreItems.build("PumpkinPile"), "Pumpkin")).toBe(4)
			local cart = StoreItems.build("FruitCart")
			expect(named(cart, "Fruit")).toBe(0)
			expect(#meshParts(cart) >= 10).toBe(true)
		end)

		it("grows wild land from the props: each obstacle on its tile, grass between, nothing to bump into", function()
			local model = roblox.Instance.new("Model")
			local frame = PlotLayout.frame(1)
			FarmArt.buildField(model, frame)
			local field = model.Field
			local blocks = 0
			for block = 1, 16 do
				local overgrowth = field:FindFirstChild(`Overgrowth{block}`)
				if overgrowth then
					blocks += 1
					noBumps(overgrowth, `block {block}`)
					local obstacles = FarmArt.obstacles(model, block)
					expect(#obstacles).toBe(Land.OBSTACLES)
					local tiles = LandRules.tilesOf(block)
					for _, obstacle in obstacles do
						local k = obstacle:GetAttribute("Obstacle")
						expect(obstacle.PrimaryPart ~= nil and obstacle.PrimaryPart:IsA("MeshPart")).toBe(true)
						local centre = frame * PlotLayout.tileLocal(tiles[k])
						for _, part in meshParts(obstacle) do
							local p = part.CFrame.Position
							if math.abs(p.X - centre.X) > 6 or math.abs(p.Z - centre.Z) > 6 then
								error(`block {block}: {obstacle.Name}'s {part.Name} is off its tile`)
							end
						end
					end
					expect(named(overgrowth, "Leaf")).toBe(0) -- (no part-built tufts)
					expect(#meshParts(overgrowth) > #obstacles + 6).toBe(true)
				end
			end
			expect(blocks).toBe(16 - #Land.START_BLOCKS)
			-- tilled tiles: the furrowed soil, one mesh, in the ridges' colour
			local open = 0
			for _, tile in field:GetChildren() do
				if tile:GetAttribute("Open") then
					open += 1
					local ridges = tile.Ridges:GetChildren()
					expect(#ridges).toBe(1)
					expect(ridges[1].Name).toBe("Furrows")
					expect(ridges[1].Color).toBe(Parts.COLORS.ridge)
					noBumps(tile.Ridges, `tile {tile.Name}`)
				end
			end
			expect(open).toBe(#Land.START_BLOCKS * 4)
		end)

		harness.setStorageChild("CropModels", nil)
		harness.setStorageChild("PropModels", nil)
		local Plain = harness.loadServerWith("World/FarmArt", globals)
		local PlainItems = harness.loadServerWith("World/StoreItems", globals)
		it("builds the part-built stand-ins until the meshes are imported", function()
			local model = Plain.cropModel("Carrot", "Ripe", roblox.CFrame.new(), 6)
			expect(#meshParts(model)).toBe(0)
			expect(#model:GetChildren() > 6).toBe(true)
			local farm = roblox.Instance.new("Model")
			Plain.buildField(farm, PlotLayout.frame(1))
			expect(#meshParts(farm)).toBe(0)
			expect(#Plain.obstacles(farm, 3)).toBe(Land.OBSTACLES)
			expect(#farm.Field.Tile1.Ridges:GetChildren()).toBe(3) -- (cylinders)
			expect(named(PlainItems.build("PumpkinPile"), "Pumpkin")).toBe(4)
			expect(#meshParts(PlainItems.build("FruitCart"))).toBe(0)
		end)
	end)
end
