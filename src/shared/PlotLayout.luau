-- Where everything in Cloverdale is (docs/GameDesign.md §3, the design map's
-- World tab). One source of truth for WorldBuilder (the greybox), the
-- services (spawns, zones, tiles) and the tests (tests/layout.test.luau
-- checks nothing overlaps and times the raid race from these distances).
--
-- The world: the town square at the origin, north = +Z. Angles are in
-- degrees from north, clockwise seen from above (towards +X). Studs.
--
-- A plot's own frame (PlotLayout.frame): origin on the front boundary at the
-- middle of the plot, +Z (depth) runs away from the town to the back fence,
-- +Y up, and X runs across: −X is the farmhouse and shop side, +X the
-- warehouse side.
local PlotLayout = {}

------------------------------------------------------------------------
-- The valley

PlotLayout.COUNT = 8
PlotLayout.WIDTH = 160 -- across
PlotLayout.DEPTH = 240 -- front boundary to back fence
PlotLayout.FRONT_RADIUS = 240 -- from the town square to a plot's front boundary
PlotLayout.ZONE_HEIGHT = 60
PlotLayout.FENCE_HEIGHT = 8 -- what you see: taller than a Roblox jump (about 7.2 studs), so a jump hits the fence you see, not thin air (docs/ArtDirection.md §7)
PlotLayout.FENCE_BLOCK = 11 -- an invisible wall this high over every fence is what really stops you (a character climbs horizontal rails like a ladder): the only ways over are the climb (back fence, locked gate) and the open gate
PlotLayout.HEDGE_HEIGHT = 12

PlotLayout.TOWN = {
	plazaRadius = 160, -- (the design map's town, to scale)
	fountainRadius = 10,
	spawn = Vector3.new(0, 0, -30), -- the town's SpawnLocation (arrivals, Town button)
	buildings = { -- angle from north, distance from the square's centre, footprint
		{ id = "Exchange", name = "Cloverdale Exchange", angle = 0, radius = 115, size = Vector3.new(40, 40, 30) },
		{ id = "Auction", name = "Auction House", angle = 72, radius = 115, size = Vector3.new(44, 26, 34) },
		{ id = "HiringHall", name = "Hiring Hall", angle = 144, radius = 115, size = Vector3.new(36, 20, 28) },
		{ id = "Police", name = "Police Station", angle = 216, radius = 115, size = Vector3.new(38, 22, 30) },
		{ id = "Seeds", name = "Barley's Seeds", angle = 288, radius = 115, size = Vector3.new(36, 20, 28) },
	},
	policePorch = 92, -- distance from the centre, on the Police Station's angle (facing the square)
}

PlotLayout.RING_ROAD = { radius = 222, width = 20 } -- NPC shoppers, trucks
PlotLayout.HIGHWAY = { width = 24, from = 232, to = 560 } -- north, to the tunnel
PlotLayout.BACK_TRAIL = { radius = 500, width = 14 }
PlotLayout.VALLEY_RADIUS = 530 -- hills from here out
PlotLayout.HILLS_RADIUS = 620

------------------------------------------------------------------------
-- Inside a plot (plot space: x = across, z = depth). From the design map's
-- "One farm, front to back".

PlotLayout.PLOT = {
	shop = { min = Vector3.new(-74, 0, 0), max = Vector3.new(-18, 16, 40) },
	gate = { across = -5, width = 18 },
	path = { min = Vector3.new(-8, 0, 0), max = Vector3.new(-2, 0.2, 126) }, -- gate to field
	gatehouse = { min = Vector3.new(6, 0, 4), max = Vector3.new(15, 9, 13) },
	driveway = { min = Vector3.new(20, 0, 0), max = Vector3.new(38, 0.2, 48) },
	warehouse = { min = Vector3.new(14, 0, 48), max = Vector3.new(76, 22, 114) }, -- the site; T1 and up fill it
	-- The Packing Shed (warehouse T0) at the front of the site: one bench
	-- that washes and packs, by the dock at the top of the driveway where
	-- the pickup backs in. Crates for the truck are carried bench → dock.
	shed = { min = Vector3.new(14, 0, 48), max = Vector3.new(46, 12, 72) },
	bench = Vector3.new(30, 0, 58),
	dock = { min = Vector3.new(18, 0, 41), max = Vector3.new(42, 0.8, 48) }, -- the loading platform (low enough to step onto)
	truck = Vector3.new(29, 0, 29), -- the parked pickup's middle, nose to the road, tailgate at the dock
	lever = Vector3.new(40.5, 0, 44.5), -- the dispatch lever, on the dock
	dockPile = Vector3.new(21, 0, 44.5), -- where dropped crates wait
	-- The Farm Stand (shop T0): a counter in the front fence, served over
	-- from the yard; shoppers stand on the verge outside.
	stand = { across = -46, width = 20 },
	stations = { -- inside the warehouse, from the dock back
		{ id = "Load", z = 57 },
		{ id = "Pack", z = 73 },
		{ id = "Sort", z = 89 },
		{ id = "Intake", z = 105 },
	},
	stationAcross = 47,
	farmhouse = { min = Vector3.new(-70, 0, 60), max = Vector3.new(-26, 18, 102) },
	door = Vector3.new(-20, 0, 81), -- in front of the farmhouse door: the owner's spawn and the barn's deposit point
	field = { across = -48, depth = 126, tile = 12, size = 8 }, -- corner (row 1, column 1) and tiles
	scarecrow = Vector3.new(-58, 0, 174),
	kennel = Vector3.new(67, 0, 133),
	backFence = 240,
}

------------------------------------------------------------------------
-- Frames and conversions

-- A plot's axis angle (degrees from north). Plots sit at 22.5° + 45° × n so
-- the north gap is free for the highway.
function PlotLayout.angle(index: number): number
	return 22.5 + 45 * (index - 1)
end

local function direction(angle: number): Vector3
	local radians = math.rad(angle)
	return Vector3.new(math.sin(radians), 0, math.cos(radians))
end
PlotLayout.direction = direction

-- A point at `radius` from the town square, `angle` degrees from north.
function PlotLayout.polar(angle: number, radius: number, y: number?): Vector3
	return direction(angle) * radius + Vector3.new(0, y or 0, 0)
end

-- The plot's frame: origin at the middle of its front boundary.
function PlotLayout.frame(index: number): CFrame
	local outward = direction(PlotLayout.angle(index))
	local right = Vector3.new(outward.Z, 0, -outward.X)
	local origin = outward * PlotLayout.FRONT_RADIUS
	return CFrame.fromMatrix(origin, right, Vector3.new(0, 1, 0), outward)
end

-- Plot space → world.
function PlotLayout.toWorld(index: number, point: Vector3): Vector3
	return PlotLayout.frame(index):PointToWorldSpace(point)
end

-- The farm's zone (shared/ZoneRules): the whole plot, hedge to hedge, gate
-- to back fence.
function PlotLayout.zone(index: number)
	local centre = Vector3.new(0, PlotLayout.ZONE_HEIGHT / 2 - 5, PlotLayout.DEPTH / 2)
	return {
		cframe = PlotLayout.frame(index) * CFrame.new(centre),
		size = Vector3.new(PlotLayout.WIDTH, PlotLayout.ZONE_HEIGHT, PlotLayout.DEPTH),
	}
end

-- The middle of a field tile (1–64, row by row; column 1 is nearest the
-- farmhouse, row 1 the farmhouse side), in plot space. Matches the numbering
-- in shared/LandRules.
function PlotLayout.tileLocal(tile: number): Vector3
	local field = PlotLayout.PLOT.field
	local column = (tile - 1) % field.size + 1
	local row = (tile - 1) // field.size + 1
	return Vector3.new(field.across + (row - 0.5) * field.tile, 0, field.depth + (column - 0.5) * field.tile)
end

function PlotLayout.tileWorld(index: number, tile: number): Vector3
	return PlotLayout.toWorld(index, PlotLayout.tileLocal(tile))
end

-- The field tile a world position stands over, or nil (off the field).
function PlotLayout.tileAt(index: number, position: Vector3): number?
	local field = PlotLayout.PLOT.field
	local p = PlotLayout.frame(index):PointToObjectSpace(position)
	local column = math.floor((p.Z - field.depth) / field.tile) + 1
	local row = math.floor((p.X - field.across) / field.tile) + 1
	if column < 1 or column > field.size or row < 1 or row > field.size then
		return nil
	end
	return (row - 1) * field.size + column
end

-- The centre of a box given as { min, max } in plot space.
function PlotLayout.centre(box): Vector3
	return (box.min + box.max) / 2
end

-- Where the owner appears (join, Home button): in front of the farmhouse door.
function PlotLayout.spawnWorld(index: number): Vector3
	return PlotLayout.toWorld(index, PlotLayout.PLOT.door)
end

-- Where visitors arrive (Visit button): the sidewalk just outside the gate.
function PlotLayout.visitWorld(index: number): Vector3
	return PlotLayout.toWorld(index, Vector3.new(PlotLayout.PLOT.gate.across, 0, -5))
end

-- The town building with this id.
function PlotLayout.building(id: string)
	for _, building in PlotLayout.TOWN.buildings do
		if building.id == id then
			return building
		end
	end
	return nil
end

-- The spot `gap` studs in front of a town building, on the square's side
-- (where its counter is: Barley stands here).
function PlotLayout.frontOf(id: string, gap: number): Vector3
	local building = PlotLayout.building(id)
	return PlotLayout.polar(building.angle, building.radius - building.size.Z / 2 - gap)
end

-- Where arrested players appear: the Police Station porch.
function PlotLayout.policePorchWorld(): Vector3
	return PlotLayout.polar(PlotLayout.building("Police").angle, PlotLayout.TOWN.policePorch)
end

------------------------------------------------------------------------
-- Routes: the truck to the City, shoppers along the sidewalk

PlotLayout.SIDEWALK = { radius = 235.5, width = 5 } -- between the ring road and the farms' fronts
local TRUCK_LANE = PlotLayout.RING_ROAD.radius + 4

-- Degrees from north of a world point.
local function bearing(point: Vector3): number
	return math.deg(math.atan2(point.X, point.Z)) % 360
end

-- Points every `step` degrees along a circle, from one bearing to another
-- (either way round), not including the first.
local function arc(from: number, to: number, radius: number, step: number)
	local points = {}
	local steps = math.max(1, math.ceil(math.abs(to - from) / step))
	for i = 1, steps do
		table.insert(points, PlotLayout.polar(from + (to - from) * i / steps, radius))
	end
	return points
end

-- The pickup's road to the City, in world space: out through the truck
-- gate, round the ring road the short way to the highway, north into the
-- tunnel. The first leg (dock to gate) is the one it backs up on the way
-- home.
function PlotLayout.truckRoute(index: number): { Vector3 }
	local P = PlotLayout.PLOT
	local parked = PlotLayout.toWorld(index, P.truck)
	local out = PlotLayout.toWorld(index, Vector3.new(P.truck.X, 0, -6))
	local points = { parked, out }
	local from = bearing(out)
	local to = if from < 180 then 0 else 360
	for _, point in arc(from, to, TRUCK_LANE, 6) do
		table.insert(points, point)
	end
	table.insert(points, Vector3.new(0, 0, PlotLayout.HIGHWAY.to + 12))
	return points
end

-- A shopper's walk: in along the sidewalk from the woods on the stand's
-- side, up to the stand's counter, then on past the gate into the woods on
-- the other side. Returns the points and which one is the counter.
function PlotLayout.shopperRoute(index: number, lane: number?): ({ Vector3 }, number)
	local P = PlotLayout.PLOT
	local axis = PlotLayout.angle(index)
	local radius = PlotLayout.SIDEWALK.radius + (lane or 0)
	local counter = PlotLayout.toWorld(index, Vector3.new(P.stand.across + (lane or 0) * 2, 0, -3))
	local standBearing = bearing(counter)
	local points = { PlotLayout.polar(axis - 21, radius) }
	for _, point in arc(axis - 21, standBearing, radius, 4) do
		table.insert(points, point)
	end
	table.insert(points, counter)
	local at = #points
	table.insert(points, PlotLayout.polar(standBearing, radius))
	for _, point in arc(standBearing, axis + 21, radius, 4) do
		table.insert(points, point)
	end
	return points, at
end

-- Length of a path of points (studs), up to point `upTo` (default: all).
function PlotLayout.pathLength(points: { Vector3 }, upTo: number?): number
	local length = 0
	for i = 2, upTo or #points do
		length += (points[i] - points[i - 1]).Magnitude
	end
	return length
end

-- The point `distance` studs along a path, and the direction it's heading.
function PlotLayout.along(points: { Vector3 }, distance: number): (Vector3, Vector3)
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local span = (b - a).Magnitude
		if distance <= span or i == #points then
			local direction = if span > 0 then (b - a) / span else Vector3.new(0, 0, 1)
			return a + direction * math.clamp(distance, 0, span), direction
		end
		distance -= span
	end
	return points[#points], Vector3.new(0, 0, 1)
end

return PlotLayout
