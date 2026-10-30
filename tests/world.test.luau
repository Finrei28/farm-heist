-- The greybox (server/World/WorldBuilder), built for real with @lune/roblox
-- Instances: it runs without errors, and what it builds matches
-- shared/PlotLayout (8 farms with zones, 64 tiles each, the start corner
-- tilled, a town spawn).
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local roblox = require("@lune/roblox")
	local PlotLayout = harness.load("PlotLayout")
	local LandRules = harness.load("LandRules")

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
		it("walls every fence higher than a jump, leaving only the gate open", function()
			local plot = world.Plot1
			local blockers = 0
			for _, child in plot:GetChildren() do
				if string.match(child.Name, "Blocker$") then
					blockers += 1
					expect(child.Size.Y).toBeGreaterThan(7.2 + 1) -- Roblox's default jump is about 7.2 studs
					expect(child.CanCollide).toBe(true)
				end
			end
			expect(blockers).toBe(4) -- the back fence and three front stretches; the gate stays open
			expect(plot.HedgeLeft.Size.Y).toBeGreaterThan(7.2 + 1)
			-- a jump hits the fence you see, not the invisible wall above it
			local top = 0
			for _, rail in plot.BackFence:GetChildren() do
				top = math.max(top, rail.CFrame.Position.Y + rail.Size.Y / 2)
			end
			expect(top).toBeGreaterThan(7.2 + 0.5)
		end)
		it("anchors everything (nothing falls when Play starts)", function()
			for _, descendant in world:GetDescendants() do
				if descendant:IsA("BasePart") and not descendant.Anchored then
					error(`{descendant:GetFullName()} isn't anchored`)
				end
			end
		end)
		it("has a town spawn and the police porch", function()
			expect(world.Town:FindFirstChild("TownSpawn") ~= nil).toBe(true)
			local porch = world.Town:FindFirstChild("PolicePorch")
			expect((porch.CFrame.Position - PlotLayout.policePorchWorld()).Magnitude).toBeLessThan(1)
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
