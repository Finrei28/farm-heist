-- The crops' meshes (World/CropMeshes and the CropMeshData that
-- tools/crop_art writes): every piece a layout names was drawn; every crop
-- has a patch growing and ripe for any number a patch can give, and a load
-- for any number a thief can hold; FarmArt and ProduceArt build them once
-- they're imported (stand-ins here), nothing in them to bump into, and the
-- part-built crops until then. (The generator checks the meshes' own
-- triangles stay on their tile.)
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local roblox = require("@lune/roblox")
	local Crops = harness.load("Config/Crops")
	local DATA = harness.loadServer("World/CropMeshData")

	local game = roblox.Instance.new("DataModel")
	local globals = { Instance = roblox.Instance, workspace = game:GetService("Workspace") }

	-- stand-ins for the import: a MeshPart for each mesh, the size it was drawn
	local models = roblox.Instance.new("Folder")
	models.Name = "CropModels"
	for name, info in DATA.meshes do
		local part = roblox.Instance.new("MeshPart")
		part.Name = name
		part.Size = info.size
		part.Parent = models
	end

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

	describe("crop meshes (World/CropMeshes)", function()
		it("draws every mesh a patch or a carried load names", function()
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
		end)

		it("has every crop growing, ripe with as many as a patch can give, and carried", function()
			for _, crop in Crops.List do
				local layouts = DATA.patches[crop.id]
				expect(layouts ~= nil and #layouts.Growing > 0).toBe(true)
				if #layouts.Ripe < most(crop) then
					error(`{crop.id}: ripe patches up to {#layouts.Ripe}, a patch can give {most(crop)}`)
				end
				expect(DATA.carried[crop.id] ~= nil and #DATA.carried[crop.id] >= most(crop)).toBe(true)
			end
		end)

		harness.setStorageChild("CropModels", models)
		local FarmArt = harness.loadServerWith("World/FarmArt", globals)
		local ProduceArt = harness.loadServerWith("World/ProduceArt", globals)

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

		harness.setStorageChild("CropModels", nil)
		local Plain = harness.loadServerWith("World/FarmArt", globals)
		it("builds the part-built crops until the meshes are imported", function()
			local model = Plain.cropModel("Carrot", "Ripe", roblox.CFrame.new(), 6)
			expect(#meshParts(model)).toBe(0)
			expect(#model:GetChildren() > 6).toBe(true)
		end)
	end)
end
