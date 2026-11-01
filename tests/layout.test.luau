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
	local Store = harness.load("Config/Store")
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
		it("puts every warehouse building on its site, its stations, bench and Cold Room inside it", function()
			local site = P.warehouse
			local function inside(point, box, margin)
				return point.X >= box.min.X + margin and point.X <= box.max.X - margin and point.Z >= box.min.Z + margin and point.Z <= box.max.Z - margin
			end
			for stage, layout in PlotLayout.WAREHOUSES do
				expect(layout.min.X >= site.min.X and layout.max.X <= site.max.X and layout.min.Z >= site.min.Z and layout.max.Z <= site.max.Z).toBe(true)
				expect(layout.max.Y <= site.max.Y).toBe(true)
				expect(inside(layout.bench, layout, 4)).toBe(true)
				if stage > 1 then
					for _, at in layout.stations do
						expect(inside(at, layout, 3)).toBe(true)
					end
					local room = layout.coldRoom
					expect(room.min.X >= layout.min.X and room.max.X <= layout.max.X and room.min.Z >= layout.min.Z and room.max.Z <= layout.max.Z).toBe(true)
				end
				-- each bigger than the last, and the old one inside the new (it keeps working while the new one goes up)
				if stage > 1 then
					local before = PlotLayout.WAREHOUSES[stage - 1]
					expect(layout.max.X >= before.max.X and layout.max.Z > before.max.Z).toBe(true)
					expect(#layout.docks >= #before.docks).toBe(true)
				end
			end
			-- the biggest leaves a walkway to the hedge and the field
			expect(W / 2 - site.max.X >= 3).toBe(true)
			expect(P.field.depth - site.max.Z >= 15).toBe(true)
		end)
		it("gives each dock its own lane, inside the farm, clear of the gatehouse and each other", function()
			local docks = PlotLayout.WAREHOUSES[#PlotLayout.WAREHOUSES].docks
			for i, across in docks do
				local lane = PlotLayout.lane(across)
				expect(lane.min.X >= P.gatehouse.max.X and lane.max.X <= W / 2 - 3).toBe(true)
				if i > 1 then
					expect(lane.min.X >= PlotLayout.lane(docks[i - 1]).max.X).toBe(true)
				end
			end
			expect(PlotLayout.lane(docks[1]).min.X).toBe(P.driveway.min.X)
		end)
		it("puts every store building on the shop lot, its stockroom too", function()
			for stage = 1, #Store.BUILDINGS do
				local box = PlotLayout.storeBox(stage)
				local back = box.max.Z + P.store.backRoom + P.store.wall
				expect(box.min.X >= P.shop.min.X and box.max.X <= P.shop.max.X).toBe(true)
				expect(box.min.Z >= -P.store.wall and back <= P.shop.max.Z).toBe(true)
			end
		end)
		it("leaves room round the biggest store: the strip by the gate, the yard before the farmhouse, inside the hedge", function()
			-- the strip from the store to the gate: the owner's way to the staff door
			expect(P.gate.across - P.gate.width / 2 - P.shop.max.X >= 6).toBe(true)
			-- a yard (8 studs or more) between the stockroom and the farmhouse
			expect(P.farmhouse.min.Z - P.shop.max.Z >= 8).toBe(true)
			-- inside the hedge, with room for a stretch of picket fence beside it
			expect(P.shop.min.X - -W / 2 >= 3).toBe(true)
			-- and the lot is used: the biggest building and its stockroom fill it
			local biggest = PlotLayout.storeBox(#Store.BUILDINGS)
			expect(biggest.max.Z + P.store.backRoom + P.store.wall).toBe(P.shop.max.Z)
			expect(biggest.min.X).toBe(P.shop.min.X)
		end)
		it("keeps neighbouring farms apart, so every farm has the same room", function()
			-- the corners of the front of a plot against its neighbour's
			for index = 1, PlotLayout.COUNT do
				local nextIndex = index % PlotLayout.COUNT + 1
				local a = PlotLayout.toWorld(index, Vector3.new(-W / 2 - 3, 0, 0))
				local b = PlotLayout.toWorld(nextIndex, Vector3.new(W / 2 + 3, 0, 0))
				local c = PlotLayout.toWorld(index, Vector3.new(W / 2 + 3, 0, 0))
				local d = PlotLayout.toWorld(nextIndex, Vector3.new(-W / 2 - 3, 0, 0))
				expect(math.min((a - b).Magnitude, (c - d).Magnitude, (a - d).Magnitude, (c - b).Magnitude)).toBeGreaterThan(10)
			end
		end)
		it("cuts the store out of the farm's zone, but not its stockroom", function()
			for stage = 1, #Store.BUILDINGS do
				local zone = PlotLayout.zone(2, stage)
				local cells = Store.BUILDINGS[stage].cells
				expect(ZoneRules.inside(zone, PlotLayout.storeWorld(2, 1, 1, 3))).toBe(false)
				expect(ZoneRules.inside(zone, PlotLayout.storeWorld(2, cells[1], cells[2], 3))).toBe(false)
				expect(ZoneRules.inside(PlotLayout.storeZone(2, stage), PlotLayout.storeWorld(2, cells[1], cells[2], 3))).toBe(true)
				-- the stockroom, behind the back wall, is the farm's
				local stockroom = PlotLayout.storeWorld(2, 1, cells[2] + 1 + P.store.backRoom / 2 / Store.CELL, 3)
				expect(ZoneRules.inside(zone, stockroom)).toBe(true)
				-- the yard beside the store, by the staff door
				local yard = PlotLayout.storeWorld(2, -0.5, Store.STAFF_Y, 3)
				expect(ZoneRules.inside(zone, yard)).toBe(true)
			end
		end)
		it("finds store cells from world positions", function()
			local x, y = PlotLayout.storeCellAt(5, PlotLayout.storeWorld(5, 4, 2, 3))
			expect(x).toBeNear(4, 1e-4)
			expect(y).toBeNear(2, 1e-4)
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
		it("finds the tile under a position (and none off the field)", function()
			for index = 1, PlotLayout.COUNT do
				for tile = 1, 64 do
					local centre = PlotLayout.tileWorld(index, tile)
					expect(PlotLayout.tileAt(index, centre)).toBe(tile)
					-- near a corner of the tile, still the same tile
					local nearCorner = PlotLayout.toWorld(index, PlotLayout.tileLocal(tile) + Vector3.new(5.5, 3, -5.5))
					expect(PlotLayout.tileAt(index, nearCorner)).toBe(tile)
				end
				expect(PlotLayout.tileAt(index, PlotLayout.spawnWorld(index))).toBe(nil)
				expect(PlotLayout.tileAt(index, PlotLayout.toWorld(index, Vector3.new(0, 0, P.backFence - 1)))).toBe(nil)
			end
		end)
		it("puts Barley's counter in front of the seed shop, on the square", function()
			local counter = PlotLayout.frontOf("Seeds", 4)
			local building = PlotLayout.building("Seeds")
			expect(radius(counter)).toBeLessThan(building.radius - building.size.Z / 2)
			expect(radius(counter)).toBeLessThan(PlotLayout.TOWN.plazaRadius)
		end)
		it("has its spawn inside and its Visit point outside the farm", function()
			for index = 1, PlotLayout.COUNT do
				expect(ZoneRules.inside(PlotLayout.zone(index), PlotLayout.spawnWorld(index))).toBe(true)
				expect(ZoneRules.inside(PlotLayout.zone(index), PlotLayout.visitWorld(index))).toBe(false)
			end
		end)
	end)

	describe("distances in the design doc (§3)", function()
		it("town spawn to a farm's gate: 285–345 studs, 18–21.5 s on foot", function()
			for index = 1, PlotLayout.COUNT do
				local distance = (PlotLayout.visitWorld(index) - PlotLayout.TOWN.spawn).Magnitude
				expect(distance >= 285 and distance <= 345).toBe(true)
			end
		end)
		-- Walking routes, not straight lines: the plots are in the way, so you
		-- go out through the gap on either side of the farm, along the back
		-- trail and in to the fence (play-test 2026-10-30 walked 785 studs to
		-- Farm 1, where a straight line says 570).
		local function length(points: { Vector3 }): number
			local total = 0
			for i = 2, #points do
				total += (points[i] - points[i - 1]).Magnitude
			end
			return total
		end
		local function behind(index: number): Vector3
			return PlotLayout.toWorld(index, Vector3.new(0, 0, D + 6))
		end
		it("police porch to the back of a farm on foot: 735–910 studs, 46–57 s", function()
			local porch = PlotLayout.policePorchWorld()
			for index = 1, PlotLayout.COUNT do
				local best = math.huge
				for _, side in { -1, 1 } do
					local gap = PlotLayout.angle(index) + side * 22.5
					best = math.min(best, length({
						porch,
						PlotLayout.polar(gap, PlotLayout.RING_ROAD.radius + 10),
						PlotLayout.polar(gap, PlotLayout.BACK_TRAIL.radius),
						PlotLayout.polar(gap - side * 11.25, PlotLayout.BACK_TRAIL.radius),
						behind(index),
					}))
				end
				expect(best >= 735 and best <= 910).toBe(true)
			end
		end)
		it("a farm's Visit point round the hedge to its back fence: 490–510 studs, about 31 s", function()
			for index = 1, PlotLayout.COUNT do
				for _, side in { -1, 1 } do
					local x = side * (PlotLayout.WIDTH / 2 + 8)
					local distance = length({
						PlotLayout.visitWorld(index),
						PlotLayout.toWorld(index, Vector3.new(x, 0, -5)),
						PlotLayout.toWorld(index, Vector3.new(x, 0, D + 6)),
						behind(index),
					})
					expect(distance >= 490 and distance <= 510).toBe(true)
				end
			end
		end)
	end)

	describe("routes (week 2)", function()
		local function inAnyFarm(point)
			for index = 1, PlotLayout.COUNT do
				local p = PlotLayout.frame(index):PointToObjectSpace(point)
				if math.abs(p.X) < PlotLayout.WIDTH / 2 + 3 and p.Z > 0 and p.Z < D then
					return index
				end
			end
			return nil
		end
		it("every truck leaves through its own lane's gate, keeps off every farm, and ends in the tunnel", function()
			for index = 1, PlotLayout.COUNT do
				for _, across in PlotLayout.WAREHOUSES[#PlotLayout.WAREHOUSES].docks do
					local route = PlotLayout.truckRoute(index, across, 36)
					local lane = PlotLayout.lane(across)
					local gate = PlotLayout.frame(index):PointToObjectSpace(route[2])
					expect(gate.Z < 0).toBe(true)
					expect(gate.X > lane.min.X and gate.X < lane.max.X).toBe(true)
					for i = 2, #route do
						expect(inAnyFarm(route[i])).toBe(nil)
					end
					local last = route[#route]
					expect(last.Z).toBeGreaterThan(PlotLayout.HIGHWAY.to)
					expect(math.abs(last.X)).toBeLessThan(PlotLayout.HIGHWAY.width / 2)
					-- the short way round: at most half the ring
					expect(PlotLayout.pathLength(route)).toBeLessThan(math.pi * PlotLayout.RING_ROAD.radius + 500)
				end
			end
		end)
		it("shoppers walk the sidewalk to the store's door without setting foot in a farm", function()
			for index = 1, PlotLayout.COUNT do
				for _, side in { -1, 1 } do
					for _, lane in { -1, 0, 1 } do
						local route = PlotLayout.storeApproach(index, side, lane)
						for _, point in route do
							expect(inAnyFarm(point)).toBe(nil)
						end
						-- they end at the door, just outside the front wall
						local cx, cy = PlotLayout.storeCellAt(index, route[#route])
						expect(math.abs(cx - Store.DOOR_X)).toBeLessThan(0.5)
						expect(cy < 0.25 and cy > -1).toBe(true)
					end
				end
			end
		end)
		it("measures and walks a path", function()
			local path = { Vector3.new(0, 0, 0), Vector3.new(0, 0, 10), Vector3.new(10, 0, 10) }
			expect(PlotLayout.pathLength(path)).toBe(20)
			expect(PlotLayout.pathLength(path, 2)).toBe(10)
			local at, heading = PlotLayout.along(path, 15)
			expect((at - Vector3.new(5, 0, 10)).Magnitude).toBeLessThan(1e-6)
			expect((heading - Vector3.new(1, 0, 0)).Magnitude).toBeLessThan(1e-6)
			expect((PlotLayout.along(path, 99) - Vector3.new(10, 0, 10)).Magnitude).toBeLessThan(1e-6)
		end)
	end)

	describe("climbing the back fence (§4.10)", function()
		it("starts within reach of the fence, in from the trail and out from the field", function()
			expect(PlotLayout.climbAt(Vector3.new(0, 0, D + 3), 4)).toBe("In")
			expect(PlotLayout.climbAt(Vector3.new(0, 0, D - 3), 4)).toBe("Out")
			expect(PlotLayout.climbAt(Vector3.new(0, 0, D - 6), 4)).toBe(nil)
			expect(PlotLayout.climbAt(Vector3.new(0, 0, D + 6), 4)).toBe(nil)
		end)
		it("not in the corners by the hedges", function()
			expect(PlotLayout.climbAt(Vector3.new(W / 2 - 1, 0, D - 2), 4)).toBe(nil)
		end)
		it("goes over the top of the fence and lands on the other side, clear of it", function()
			local zone = PlotLayout.zone(1)
			for _, direction in { "In", "Out" } do
				local path = PlotLayout.climbPath(10, direction)
				local top = 0
				for _, point in path do
					top = math.max(top, point.Y)
				end
				expect(top - 3 > PlotLayout.FENCE_HEIGHT).toBe(true) -- (the feet, 3 below the root, clear it)
				local landing = PlotLayout.toWorld(1, path[#path])
				expect(ZoneRules.inside(zone, landing, false)).toBe(direction == "In")
				expect(PlotLayout.climbAt(path[#path], 4) ~= direction).toBe(true)
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
