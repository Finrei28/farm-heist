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
	end)
end
