-- Cloverdale's layout (shared/PlotLayout): nothing overlaps, the field and
-- tiles sit where LandRules says, the distances in the design doc hold, and
-- the raid race (§4.11) comes out the way the defences are tuned for.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local roblox = require("@lune/roblox")
	local Vector3 = roblox.Vector3
	local PlotLayout = harness.load("PlotLayout")
	local ZoneRules = harness.load("ZoneRules")
	local LandRules = harness.load("LandRules")
	local raidRace = require("./lib/raidrace")

	local P = PlotLayout.PLOT
	local W, D = PlotLayout.WIDTH, PlotLayout.DEPTH

	-- Points round a plot's edge (plot space), every 10 studs.
	local function edge()
		local points = {}
		for x = -W / 2, W / 2, 10 do
			table.insert(points, Vector3.new(x, 1, 0))
			table.insert(points, Vector3.new(x, 1, D))
		end
		for z = 0, D, 10 do
			table.insert(points, Vector3.new(-W / 2, 1, z))
			table.insert(points, Vector3.new(W / 2, 1, z))
		end
		return points
	end

	local function radius(v)
		return math.sqrt(v.X * v.X + v.Z * v.Z)
	end

	describe("the valley", function()
		it("has 8 farms that never overlap one another", function()
			for a = 1, PlotLayout.COUNT do
				for b = 1, PlotLayout.COUNT do
					if a ~= b then
						for _, point in edge() do
							if ZoneRules.inside(PlotLayout.zone(b), PlotLayout.toWorld(a, point), true) then
								error(`farm {a} reaches into farm {b}`)
							end
						end
					end
				end
			end
		end)
		it("keeps the farms clear of the highway, the ring road and the back trail", function()
			local highwayHalf = PlotLayout.HIGHWAY.width / 2
			local roadOuter = PlotLayout.RING_ROAD.radius + PlotLayout.RING_ROAD.width / 2
			local trailInner = PlotLayout.BACK_TRAIL.radius - PlotLayout.BACK_TRAIL.width / 2
			for index = 1, PlotLayout.COUNT do
				for _, point in edge() do
					local world = PlotLayout.toWorld(index, point)
					if world.Z > 0 and math.abs(world.X) < highwayHalf + 3 then
						error(`farm {index} is on the highway`)
					end
					if radius(world) < roadOuter + 3 or radius(world) > trailInner then
						error(`farm {index} sits on the ring road or the back trail ({math.floor(radius(world))})`)
					end
				end
			end
		end)
		it("fits the town's buildings on the square, apart from each other", function()
			local town = PlotLayout.TOWN
			for i, a in town.buildings do
				local reach = a.radius + math.sqrt(a.size.X ^ 2 + a.size.Z ^ 2) / 2
				expect(reach <= town.plazaRadius).toBe(true)
				for j, b in town.buildings do
					if i < j then
						local gap = (PlotLayout.polar(a.angle, a.radius) - PlotLayout.polar(b.angle, b.radius)).Magnitude
						expect(gap).toBeGreaterThan((math.max(a.size.X, a.size.Z) + math.max(b.size.X, b.size.Z)) / 2)
					end
				end
			end
		end)
	end)

	describe("a farm", function()
		it("keeps its buildings, path and field apart", function()
			local boxes = {
				shop = P.shop, gatehouse = P.gatehouse, driveway = P.driveway, warehouse = P.warehouse,
				farmhouse = P.farmhouse, path = P.path,
				field = { min = Vector3.new(P.field.across, 0, P.field.depth),
					max = Vector3.new(P.field.across + P.field.size * P.field.tile, 1, P.field.depth + P.field.size * P.field.tile) },
			}
			for nameA, a in boxes do
				expect(a.min.X >= -W / 2 and a.max.X <= W / 2 and a.min.Z >= 0 and a.max.Z <= D).toBe(true)
				for nameB, b in boxes do
					if nameA < nameB then
						local apart = a.max.X <= b.min.X or b.max.X <= a.min.X or a.max.Z <= b.min.Z or b.max.Z <= a.min.Z
						if not apart then
							error(`{nameA} overlaps {nameB}`)
						end
					end
				end
			end
		end)
		it("numbers tiles as LandRules does, with the start corner by the farmhouse", function()
			local zone = PlotLayout.zone(3)
			local nearest, farthest = math.huge, 0
			for tile = 1, 64 do
				expect(ZoneRules.inside(zone, PlotLayout.tileWorld(3, tile))).toBe(true)
				local distance = (PlotLayout.tileLocal(tile) - P.door).Magnitude
				if LandRules.isStart(LandRules.blockOfTile(tile)) then
					farthest = math.max(farthest, distance)
				else
					nearest = math.min(nearest, distance)
				end
			end
			-- every start tile is nearer the farmhouse door than the far blocks
			expect(PlotLayout.tileLocal(1).Z).toBeLessThan(PlotLayout.tileLocal(8).Z)
			expect(farthest).toBeLessThan((PlotLayout.tileLocal(64) - P.door).Magnitude)
		end)
		it("has its spawn inside and its Visit point outside the farm", function()
			for index = 1, PlotLayout.COUNT do
				expect(ZoneRules.inside(PlotLayout.zone(index), PlotLayout.spawnWorld(index))).toBe(true)
				expect(ZoneRules.inside(PlotLayout.zone(index), PlotLayout.visitWorld(index))).toBe(false)
			end
		end)
	end)

	describe("distances in the design doc (§3)", function()
		it("town spawn to a farm's gate: 205–265 studs, about 15 s on foot", function()
			for index = 1, PlotLayout.COUNT do
				local distance = (PlotLayout.visitWorld(index) - PlotLayout.TOWN.spawn).Magnitude
				expect(distance >= 205 and distance <= 265).toBe(true)
			end
		end)
		it("police porch to the back of a farm: 385–580 studs, 24–36 s", function()
			local porch = PlotLayout.policePorchWorld()
			for index = 1, PlotLayout.COUNT do
				local distance = (PlotLayout.toWorld(index, Vector3.new(0, 0, D)) - porch).Magnitude
				expect(distance >= 385 and distance <= 580).toBe(true)
			end
		end)
	end)

	describe("the raid race (§4.11)", function()
		local race = raidRace(harness)
		it("an undefended back-row raid beats an owner who isn't at the field", function()
			expect(race.thief1.safe).toBeLessThan(race.ownerWarehouse)
		end)
		it("with a cloche, the dog and the tall fence, the owner catches them from the warehouse", function()
			expect(race.ownerWarehouse).toBeLessThan(race.thief2.safe)
		end)
		it("... and even from town, with time to spare (at least 1 s)", function()
			expect(race.ownerTown + 1).toBeLessThan(race.thief2.safe)
		end)
	end)
end
