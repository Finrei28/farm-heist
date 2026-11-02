-- The farmhouse and barn (docs/ArtDirection.md §7, §11 step 14), on
-- PlotLayout's farmhouse lot between the yard and the field. The owner
-- appears at the farmhouse's front door (PlotLayout.PLOT.door) and stolen
-- crops go into the barn there, so the door is the thing to find: it faces
-- the path to the field, under a porch, painted in the farm's colour.
--
--   The farmhouse: two storeys of cream boards on a stone plinth, a barn-red
--   roof with a brick chimney, shutters and the front door in the farm
--   colour, a porch with a railing, a bench, milk churns and pumpkins, two
--   steps and stepping stones down to the doormat (the Door part).
--   The barn: barn red with white trim, board battens, a slate gambrel roof
--   with a weathervane, big X-braced doors and a hayloft (with its hoist)
--   facing the field, a barn quilt in the farm colour facing the road, hay
--   bales and a wheelbarrow by its doors.
--
-- Everything stays inside PlotLayout.PLOT.farmhouse and under its 18 studs
-- (the barn's weathervane and the chimney poke above), and nothing on the
-- field side is over 3 studs tall, so the owner sees the whole field (the
-- play-test's rule, ArtDirection §7). The buildings are solid blocks inside
-- (no rooms: the farmhouse never fades its roof). Props are the meshes
-- (World/Meshes) when they're imported, with invisible walls so you don't
-- walk through a hay bale; plain blocks until then.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
local Meshes = require(script.Parent.Meshes)
local Parts = require(script.Parent.Parts)

local COLORS = Parts.COLORS

local FarmhouseArt = {}

local CREAM = COLORS.cream
local TRIM = Color3.fromRGB(250, 248, 240) -- (the white trim: cream walls need a whiter trim to show)
local BARN = COLORS.barnRed
local BARN_DARK = Color3.fromRGB(170, 56, 38) -- (door leaves, battens)
local ROOF = Color3.fromRGB(184, 62, 42) -- the farmhouse's roof
local SLATE = Color3.fromRGB(96, 102, 112) -- the barn's roof
local STONE = Color3.fromRGB(150, 146, 140)
local BRICK = Color3.fromRGB(160, 78, 58)
local DECK = Color3.fromRGB(176, 136, 90)
local GLASS = Color3.fromRGB(176, 214, 232)
local WOOD = COLORS.post

-- The barn: x across, z from the road to the field (plot space).
local BARN_X0, BARN_X1, BARN_Z0, BARN_Z1 = -70, -52, 74, 112
local BARN_WALL, BARN_KNEE, BARN_RIDGE = 10, 15, 18
local KNEE_IN = 3.2 -- how far in from the wall the gambrel's knee is
-- The farmhouse (its back runs a little into the barn's wall).
local HOUSE_X0, HOUSE_X1, HOUSE_Z0, HOUSE_Z1 = -52.6, -35, 80, 106
local HOUSE_WALL, HOUSE_RIDGE = 13, 18
local PORCH_X1, PORCH_Z0, PORCH_Z1, PORCH_FLOOR = -29.5, 85, 101, 0.8

function FarmhouseArt.build(model: Model, frame: CFrame, index: number): Model
	local P = PlotLayout.PLOT
	local house = Instance.new("Model")
	house.Name = "Farmhouse"
	local paint = Parts.farmColor(index)

	-- A box between plot-space corners; solid ones you bump into.
	local function box(name, x0, y0, z0, x1, y1, z1, color, solid, extra)
		local props = {
			Name = name,
			Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)),
			CFrame = frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
			Color = color,
		}
		for key, value in extra or {} do
			props[key] = value
		end
		return if solid then Parts.part(props, house) else Parts.prop(props, house)
	end
	-- A board in an upright X-Y plane from (xa, ya) to (xb, yb), `width`
	-- across, between z0 and z1. With `lift` it lies on that line instead (a
	-- roof's board, its underside on the slope, lifted that much more).
	local function board(name, xa, ya, xb, yb, z0, z1, width, color, solid, lift: number?)
		local dx, dy = xb - xa, yb - ya
		local length = math.sqrt(dx * dx + dy * dy)
		local along = Vector3.new(dx / length, dy / length, 0)
		local normal = Vector3.new(-along.Y, along.X, 0)
		if normal.Y < 0 then
			normal = -normal
		end
		local middle = Vector3.new((xa + xb) / 2, (ya + yb) / 2, (z0 + z1) / 2)
		if lift then
			middle += normal * (width / 2 + lift)
		end
		local props = {
			Name = name,
			Size = Vector3.new(length, width, math.abs(z1 - z0)),
			CFrame = frame * CFrame.fromMatrix(middle, along, normal),
			Color = color,
		}
		return if solid then Parts.part(props, house) else Parts.prop(props, house)
	end
	-- Half a gable: the triangle from the wall top at x = xr up to the peak
	-- at x = xv, y0 to y1, between z0 and z1.
	local function gable(name, xv, xr, y0, y1, z0, z1, color)
		local wedge = Instance.new("WedgePart")
		wedge.Name = name
		wedge.Anchored = true
		wedge.Material = Enum.Material.SmoothPlastic
		wedge.Color = color
		wedge.Size = Vector3.new(math.abs(z1 - z0), y1 - y0, math.abs(xv - xr))
		-- (a wedge's tall side is its +Z: turned toward the peak)
		wedge.CFrame = frame * CFrame.new((xv + xr) / 2, (y0 + y1) / 2, (z0 + z1) / 2) * CFrame.Angles(0, if xv > xr then math.pi / 2 else -math.pi / 2, 0)
		wedge.Parent = house
		return wedge
	end
	-- A roof slope in courses (shingles or sheets): boards from the eave
	-- (xa, ya) up to (xb, yb), each course a little proud of the one below.
	local function slope(name, xa, ya, xb, yb, z0, z1, color, courses)
		for c = 0, courses - 1 do
			local t0, t1 = c / courses, math.min(1, (c + 1) / courses + 0.06)
			board(name, xa + (xb - xa) * t0, ya + (yb - ya) * t0, xa + (xb - xa) * t1, ya + (yb - ya) * t1, z0, z1, 0.45, color, true,
				(c % 2) * 0.08)
		end
	end
	-- A window on a wall facing `out` ("+X", "-Z" or "+Z"): glass, a frame,
	-- a sill, and shutters in the farm colour if `shutters`.
	local function window(face: string, at: number, plane: number, y0: number, y1: number, width: number, shutters: boolean)
		local s = if string.sub(face, 1, 1) == "-" then -1 else 1
		local function on(name, a0, b0, a1, b1, proud, depth, color)
			-- (a0..a1 along the wall, b0..b1 up it, `proud` out from it)
			local n0, n1 = plane + s * proud, plane + s * (proud + depth)
			if string.sub(face, 2) == "X" then
				box(name, n0, b0, a0, n1, b1, a1, color)
			else
				box(name, a0, b0, n0, a1, b1, n1, color)
			end
		end
		local h = width / 2
		on("Glass", at - h, y0, at + h, y1, 0, 0.1, GLASS)
		on("Frame", at - h - 0.3, y1, at + h + 0.3, y1 + 0.3, 0, 0.25, TRIM)
		on("Frame", at - h - 0.3, y0 - 0.25, at + h + 0.3, y0, 0, 0.35, TRIM) -- (the sill, deeper)
		on("Frame", at - h - 0.3, y0, at - h, y1, 0, 0.25, TRIM)
		on("Frame", at + h, y0, at + h + 0.3, y1, 0, 0.25, TRIM)
		on("Mullion", at - 0.1, y0, at + 0.1, y1, 0.1, 0.1, TRIM)
		on("Mullion", at - h, (y0 + y1) / 2 - 0.1, at + h, (y0 + y1) / 2 + 0.1, 0.1, 0.1, TRIM)
		if shutters then
			for _, side in { -1, 1 } do
				local a = at + side * (h + 0.35)
				on("Shutter", math.min(a, a + side * 1.1), y0, math.max(a, a + side * 1.1), y1, 0, 0.2, paint)
				on("ShutterSlat", math.min(a, a + side * 1.1) + 0.2, (y0 + y1) / 2 - 0.08, math.max(a, a + side * 1.1) - 0.2, (y0 + y1) / 2 + 0.08,
					0.2, 0.08, TRIM)
			end
		end
	end
	-- A mesh prop, or a plain block of its size until the props are imported;
	-- `blocker`: an invisible wall round it so you don't walk through it.
	local function prop(name, x, y, z, turn, scale, size: Vector3, color, blocker: boolean?)
		local at = frame * CFrame.new(x, y, z) * CFrame.Angles(0, turn, 0)
		if not Meshes.make(name, at, scale, house) then
			Parts.prop({ Name = name, Size = size * scale, CFrame = at * CFrame.new(0, size.Y * scale / 2, 0), Color = color }, house)
		end
		if blocker then
			Parts.part({ Name = `{name}Solid`, Size = size * scale, CFrame = at * CFrame.new(0, size.Y * scale / 2, 0),
				Transparency = 1, CanQuery = false, CanTouch = false }, house)
		end
	end

	--------------------------------------------------------------------
	-- The barn

	local bx = (BARN_X0 + BARN_X1) / 2
	local half = (BARN_X1 - BARN_X0) / 2
	box("Barn", BARN_X0, 0, BARN_Z0, BARN_X1, BARN_WALL, BARN_Z1, BARN, true)
	box("BarnPlinth", BARN_X0 - 0.15, 0, BARN_Z0 - 0.15, BARN_X1 + 0.15, 0.75, BARN_Z1 + 0.15, STONE) -- (a little under the farmhouse's: level tops would flicker)
	-- the gable ends: the gambrel's outline above the walls, a wall's thickness deep
	for _, z in { BARN_Z0, BARN_Z1 - 1 } do
		box("Gable", bx - half + KNEE_IN, BARN_WALL, z, bx + half - KNEE_IN, BARN_KNEE, z + 1, BARN, true)
		gable("Gable", bx - half + KNEE_IN, bx - half, BARN_WALL, BARN_KNEE, z, z + 1, BARN)
		gable("Gable", bx + half - KNEE_IN, bx + half, BARN_WALL, BARN_KNEE, z, z + 1, BARN)
		gable("Gable", bx, bx - half + KNEE_IN, BARN_KNEE, BARN_RIDGE, z, z + 1, BARN)
		gable("Gable", bx, bx + half - KNEE_IN, BARN_KNEE, BARN_RIDGE, z, z + 1, BARN)
	end
	-- the roof: steep lower slopes, shallow upper ones, sheets in courses, a ridge cap
	local over = 0.8
	local function eave(sign)
		-- (the lower slope carried on past the wall, down and out)
		local dx, dy = KNEE_IN, BARN_KNEE - BARN_WALL
		local k = 0.9 / math.sqrt(dx * dx + dy * dy)
		return bx + sign * (half + dx * k), BARN_WALL - dy * k
	end
	for _, sign in { -1, 1 } do
		local ex, ey = eave(sign)
		slope("BarnRoof", ex, ey, bx + sign * (half - KNEE_IN), BARN_KNEE, BARN_Z0 - over, BARN_Z1 + over, SLATE, 3)
		slope("BarnRoof", bx + sign * (half - KNEE_IN), BARN_KNEE, bx, BARN_RIDGE, BARN_Z0 - over, BARN_Z1 + over, SLATE, 3)
	end
	box("RidgeCap", bx - 0.5, BARN_RIDGE + 0.15, BARN_Z0 - over, bx + 0.5, BARN_RIDGE + 0.75, BARN_Z1 + over, SLATE, true)
	-- white trim: corner boards, the gables' edges under the roof, a band over the doors
	for _, x in { BARN_X0 - 0.2, BARN_X1 - 0.6 } do
		for _, z in { BARN_Z0 - 0.2, BARN_Z1 - 0.6 } do
			box("Corner", x, 0.8, z, x + 0.8, BARN_WALL - 0.2, z + 0.8, TRIM)
		end
	end
	for _, side in { { BARN_Z0 - 0.15, BARN_Z0 }, { BARN_Z1, BARN_Z1 + 0.15 } } do
		local z0, z1 = side[1], side[2]
		for _, sign in { -1, 1 } do
			local kx = bx + sign * (half - KNEE_IN)
			board("Barge", bx + sign * half, BARN_WALL - 0.3, kx, BARN_KNEE - 0.3, z0, z1, 0.6, TRIM)
			board("Barge", kx, BARN_KNEE - 0.3, bx, BARN_RIDGE - 0.3, z0, z1, 0.6, TRIM)
		end
	end
	-- board battens up the walls (not over the doors and windows)
	local function battens(face: string, from: number, to: number, skip)
		local a = from + 1.2
		while a < to - 0.8 do
			local clear = true
			for _, gap in skip do
				if a > gap[1] - 0.3 and a < gap[2] + 0.3 then
					clear = false
				end
			end
			if clear then
				if face == "-X" then
					box("Batten", BARN_X0 - 0.12, 0.9, a - 0.17, BARN_X0, BARN_WALL - 0.3, a + 0.17, BARN_DARK)
				elseif face == "+X" then
					box("Batten", BARN_X1, 0.9, a - 0.17, BARN_X1 + 0.12, BARN_WALL - 0.3, a + 0.17, BARN_DARK)
				elseif face == "-Z" then
					box("Batten", a - 0.17, 0.9, BARN_Z0 - 0.12, a + 0.17, BARN_WALL - 0.3, BARN_Z0, BARN_DARK)
				else
					box("Batten", a - 0.17, 0.9, BARN_Z1, a + 0.17, BARN_WALL - 0.3, BARN_Z1 + 0.12, BARN_DARK)
				end
			end
			a += 2.4
		end
	end
	local sideWindows = { 81, 89, 97, 105 }
	local skipSide = {}
	for _, z in sideWindows do
		table.insert(skipSide, { z - 1.4, z + 1.4 })
	end
	battens("-X", BARN_Z0, BARN_Z1, skipSide)
	battens("+X", BARN_Z0, BARN_Z1, { { HOUSE_Z0 - 0.6, HOUSE_Z1 + 0.6 } }) -- (only where the farmhouse doesn't cover it)
	battens("-Z", BARN_X0, BARN_X1, { { bx - 6.4, bx - 3.6 }, { bx + 3.6, bx + 6.4 } })
	battens("+Z", BARN_X0, BARN_X1, { { bx - 5.4, bx + 5.4 } })
	for _, z in sideWindows do
		window("-X", z, BARN_X0, 5.2, 7.4, 2.2, false)
	end
	for _, x in { bx - 5, bx + 5 } do
		window("-Z", x, BARN_Z0, 4.6, 6.8, 2.2, false)
	end
	-- the big doors to the field: two leaves, white frames and X braces
	local doorTop = 8.6
	box("DoorHeader", bx - 5.6, doorTop, BARN_Z1, bx + 5.6, doorTop + 0.6, BARN_Z1 + 0.3, TRIM)
	for _, sign in { -1, 1 } do
		local x0, x1 = bx + sign * 0.1, bx + sign * 5
		local lo, hi = math.min(x0, x1), math.max(x0, x1)
		box("DoorLeaf", lo, 0.8, BARN_Z1, hi, doorTop, BARN_Z1 + 0.2, BARN_DARK)
		box("DoorFrame", lo, 0.8, BARN_Z1 + 0.2, hi, 1.3, BARN_Z1 + 0.45, TRIM)
		box("DoorFrame", lo, doorTop - 0.5, BARN_Z1 + 0.2, hi, doorTop, BARN_Z1 + 0.45, TRIM)
		box("DoorFrame", lo, 1.3, BARN_Z1 + 0.2, lo + 0.45, doorTop - 0.5, BARN_Z1 + 0.45, TRIM)
		box("DoorFrame", hi - 0.45, 1.3, BARN_Z1 + 0.2, hi, doorTop - 0.5, BARN_Z1 + 0.45, TRIM)
		board("DoorBrace", lo + 0.45, 1.3, hi - 0.45, doorTop - 0.5, BARN_Z1 + 0.2, BARN_Z1 + 0.4, 0.4, TRIM)
		board("DoorBrace", lo + 0.45, doorTop - 0.5, hi - 0.45, 1.3, BARN_Z1 + 0.25, BARN_Z1 + 0.45, 0.4, TRIM)
	end
	box("DoorTrack", bx - 10.5, doorTop + 0.6, BARN_Z1 + 0.3, bx + 10.5, doorTop + 0.85, BARN_Z1 + 0.5, WOOD)
	-- the hayloft door over them, the hoist beam and its rope
	local loft0, loft1 = 11.0, 14.4
	box("LoftDoor", bx - 1.8, loft0, BARN_Z1, bx + 1.8, loft1, BARN_Z1 + 0.2, BARN_DARK)
	box("LoftFrame", bx - 2.1, loft1, BARN_Z1, bx + 2.1, loft1 + 0.35, BARN_Z1 + 0.35, TRIM)
	box("LoftFrame", bx - 2.1, loft0 - 0.35, BARN_Z1, bx + 2.1, loft0, BARN_Z1 + 0.35, TRIM)
	box("LoftFrame", bx - 2.1, loft0, BARN_Z1, bx - 1.8, loft1, BARN_Z1 + 0.35, TRIM)
	box("LoftFrame", bx + 1.8, loft0, BARN_Z1, bx + 2.1, loft1, BARN_Z1 + 0.35, TRIM)
	board("LoftBrace", bx - 1.6, loft0 + 0.2, bx + 1.6, loft1 - 0.2, BARN_Z1 + 0.2, BARN_Z1 + 0.35, 0.3, TRIM)
	board("LoftBrace", bx - 1.6, loft1 - 0.2, bx + 1.6, loft0 + 0.2, BARN_Z1 + 0.22, BARN_Z1 + 0.37, 0.3, TRIM)
	box("HoistBeam", bx - 0.3, 16.0, BARN_Z1 - 1, bx + 0.3, 16.6, BARN_Z1 + 3.2, WOOD, true)
	Parts.cylinder("Pulley", frame * CFrame.new(bx, 15.7, BARN_Z1 + 2.7) * CFrame.Angles(0, 0, math.pi / 2), 0.7, 0.25, { Color = COLORS.dark }, house)
	box("Rope", bx - 0.06, 12.4, BARN_Z1 + 3.0, bx + 0.06, 15.6, BARN_Z1 + 3.12, Color3.fromRGB(196, 160, 100))
	-- the barn quilt on the gable facing the road: a diamond of farm colour
	-- framed in white, a white star of squares in its middle
	local quilt = frame * CFrame.new(bx, 13.1, BARN_Z0) * CFrame.Angles(0, 0, math.rad(45))
	for i, layer in { { 4.4, TRIM }, { 3.6, paint }, { 1.9, TRIM }, { 1.1, paint } } do
		Parts.prop({ Name = "Quilt", Size = Vector3.new(layer[1], layer[1], 0.1), CFrame = quilt * CFrame.new(0, 0, -0.05 - i * 0.06), Color = layer[2] }, house)
	end
	-- the weathervane on the ridge
	prop("Weathervane", bx, BARN_RIDGE + 0.75, (BARN_Z0 + BARN_Z1) / 2, math.rad(70), 1, Vector3.new(0.3, 4.4, 0.3), COLORS.dark)

	--------------------------------------------------------------------
	-- The farmhouse

	local hx = (BARN_X1 + HOUSE_X1) / 2 -- (the ridge, over the part you see)
	box("House", HOUSE_X0, 0, HOUSE_Z0, HOUSE_X1, HOUSE_WALL, HOUSE_Z1, CREAM, true)
	box("HousePlinth", BARN_X1, 0, HOUSE_Z0 - 0.15, HOUSE_X1 + 0.15, 0.8, HOUSE_Z1 + 0.15, STONE)
	for _, z in { HOUSE_Z0, HOUSE_Z1 - 1 } do
		gable("Gable", hx, BARN_X1, HOUSE_WALL, HOUSE_RIDGE, z, z + 1, CREAM)
		gable("Gable", hx, HOUSE_X1, HOUSE_WALL, HOUSE_RIDGE, z, z + 1, CREAM)
	end
	local run = HOUSE_X1 - hx
	local pitch = (HOUSE_RIDGE - HOUSE_WALL) / run
	slope("Roof", HOUSE_X1 + 0.9, HOUSE_WALL - 0.9 * pitch, hx, HOUSE_RIDGE, HOUSE_Z0 - 0.8, HOUSE_Z1 + 0.8, ROOF, 4)
	slope("Roof", BARN_X1 - 0.5, HOUSE_WALL - 0.5 * pitch, hx, HOUSE_RIDGE, HOUSE_Z0 - 0.8, HOUSE_Z1 + 0.8, ROOF, 4)
	box("RidgeCap", hx - 0.45, HOUSE_RIDGE + 0.1, HOUSE_Z0 - 0.8, hx + 0.45, HOUSE_RIDGE + 0.6, HOUSE_Z1 + 0.8, ROOF, true)
	for _, z in { HOUSE_Z0 - 0.15, HOUSE_Z1 } do
		board("Barge", BARN_X1, HOUSE_WALL - 0.3, hx, HOUSE_RIDGE - 0.3, z, z + 0.15, 0.6, TRIM)
		board("Barge", HOUSE_X1, HOUSE_WALL - 0.3, hx, HOUSE_RIDGE - 0.3, z, z + 0.15, 0.6, TRIM)
	end
	-- the chimney, through the back of the roof
	box("Chimney", -48.6, 11, 99, -46.4, 20.6, 101.2, BRICK, true)
	box("ChimneyCap", -48.9, 20.6, 98.7, -46.1, 21.1, 101.5, STONE)
	-- white corner boards and the band between the storeys
	for _, z in { HOUSE_Z0 - 0.2, HOUSE_Z1 - 0.6 } do
		box("Corner", HOUSE_X1 - 0.6, 0.8, z, HOUSE_X1 + 0.2, HOUSE_WALL - 0.2, z + 0.8, TRIM)
	end
	for _, z in { HOUSE_Z0 - 0.15, HOUSE_Z1 } do
		box("Band", BARN_X1, 8.4, z, HOUSE_X1 - 0.6, 8.8, z + 0.15, TRIM)
	end
	-- the front: the door in the farm colour, windows with shutters
	local front = HOUSE_X1
	local doorZ = P.door.Z
	box("DoorFrame", front, PORCH_FLOOR, doorZ - 1.9, front + 0.3, 7.4, doorZ - 1.5, TRIM)
	box("DoorFrame", front, PORCH_FLOOR, doorZ + 1.5, front + 0.3, 7.4, doorZ + 1.9, TRIM)
	box("DoorFrame", front, 7.0, doorZ - 1.9, front + 0.3, 7.4, doorZ + 1.9, TRIM)
	box("FrontDoor", front, PORCH_FLOOR, doorZ - 1.5, front + 0.2, 7.0, doorZ + 1.5, paint)
	box("DoorPane", front + 0.2, 4.6, doorZ - 0.8, front + 0.28, 6.4, doorZ + 0.8, GLASS)
	box("DoorPanel", front + 0.2, 1.4, doorZ - 1.0, front + 0.3, 3.8, doorZ - 0.15, paint:Lerp(Color3.new(0, 0, 0), 0.15))
	box("DoorPanel", front + 0.2, 1.4, doorZ + 0.15, front + 0.3, 3.8, doorZ + 1.0, paint:Lerp(Color3.new(0, 0, 0), 0.15))
	Parts.ball("Knob", frame * CFrame.new(front + 0.35, 3.9, doorZ + 1.1), 0.35, { Color = COLORS.hay }, house)
	-- a lantern on a bracket by the door: warm glass, a dark cap and base
	local lz = doorZ - 2.45
	box("LanternBracket", front, 6.3, lz - 0.08, front + 0.75, 6.45, lz + 0.08, COLORS.dark)
	box("LanternCap", front + 0.35, 6.0, lz - 0.38, front + 1.05, 6.3, lz + 0.38, COLORS.dark)
	box("LanternGlass", front + 0.42, 5.2, lz - 0.3, front + 0.98, 6.0, lz + 0.3, Color3.fromRGB(255, 222, 140))
	box("LanternBase", front + 0.38, 5.0, lz - 0.34, front + 1.02, 5.2, lz + 0.34, COLORS.dark)
	for _, z in { 87.2, 98.8 } do
		window("+X", z, front, 2.6, 5.8, 2.6, true)
	end
	for _, z in { 84.5, doorZ, 101.5 } do
		window("+X", z, front, 9.8, 12.2, 2.3, true)
	end
	-- the gable ends (one faces the road, one the field)
	for _, face in { { "-Z", HOUSE_Z0 }, { "+Z", HOUSE_Z1 } } do
		for _, x in { -48.0, -39.5 } do
			window(face[1], x, face[2], 2.6, 5.8, 2.6, true)
		end
		window(face[1], hx, face[2], 9.8, 12.2, 2.3, true)
		window(face[1], hx, face[2], 14.3, 15.9, 1.4, false)
	end
	-- flower boxes under the road end's windows
	for _, x in { -48.0, -39.5 } do
		box("FlowerBox", x - 1.6, 1.7, HOUSE_Z0 - 0.9, x + 1.6, 2.3, HOUSE_Z0, WOOD)
		for _, dx in { -0.75, 0.75 } do
			prop("Wildflowers", x + dx, 2.3, HOUSE_Z0 - 0.45, dx, 0.8, Vector3.new(1.3, 1.2, 1.3), COLORS.leaf)
		end
	end

	-- the porch: a deck on the plinth, posts, a lean-to roof, a railing
	box("Porch", front, 0, PORCH_Z0, PORCH_X1, PORCH_FLOOR, PORCH_Z1, DECK, true)
	box("PorchEdge", PORCH_X1, 0.1, PORCH_Z0, PORCH_X1 + 0.15, PORCH_FLOOR - 0.05, PORCH_Z1, TRIM)
	local postX = PORCH_X1 - 0.6
	local posts = { PORCH_Z0 + 0.5, doorZ - 2.4, doorZ + 2.4, PORCH_Z1 - 0.5 }
	for _, z in posts do
		box("PorchPost", postX - 0.3, PORCH_FLOOR, z - 0.3, postX + 0.3, 7.3, z + 0.3, TRIM, true)
	end
	box("PorchBeam", postX - 0.35, 7.3, PORCH_Z0, postX + 0.35, 7.8, PORCH_Z1, TRIM)
	board("PorchRoof", front, 9.0, PORCH_X1 + 0.4, 7.7, PORCH_Z0 - 0.4, PORCH_Z1 + 0.4, 0.4, ROOF, true, 0)
	box("PorchFascia", PORCH_X1 + 0.35, 7.25, PORCH_Z0 - 0.45, PORCH_X1 + 0.55, 7.75, PORCH_Z1 + 0.45, TRIM)
	for _, z in { PORCH_Z0 - 0.55, PORCH_Z1 + 0.4 } do
		board("PorchFascia", front, 8.75, PORCH_X1 + 0.45, 7.45, z, z + 0.15, 0.5, TRIM)
	end
	local function railing(name, x0, z0, x1, z1)
		-- (along one side: two rails, and spindles between them)
		local alongZ = math.abs(z1 - z0) > math.abs(x1 - x0)
		local w = 0.18
		if alongZ then
			box(name, x0 - w, 3.3, z0, x0 + w, 3.6, z1, TRIM, true)
			box(name, x0 - w, 1.2, z0, x0 + w, 1.4, z1, TRIM)
		else
			box(name, x0, 3.3, z0 - w, x1, 3.6, z0 + w, TRIM, true)
			box(name, x0, 1.2, z0 - w, x1, 1.4, z0 + w, TRIM)
		end
		local length = if alongZ then math.abs(z1 - z0) else math.abs(x1 - x0)
		local n = math.max(1, math.floor(length / 0.9))
		for i = 1, n - 1 do
			local t = i / n
			local x, z = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
			box("Spindle", x - 0.1, 1.4, z - 0.1, x + 0.1, 3.3, z + 0.1, TRIM)
		end
	end
	railing("Rail", postX, posts[1] + 0.3, postX, posts[2] - 0.3)
	railing("Rail", postX, posts[3] + 0.3, postX, posts[4] - 0.3)
	railing("Rail", front + 0.3, PORCH_Z0 + 0.5, postX - 0.3, PORCH_Z0 + 0.5)
	railing("Rail", front + 0.3, PORCH_Z1 - 0.5, postX - 0.3, PORCH_Z1 - 0.5)
	-- the steps down to the doormat, and stepping stones to it
	box("Step", PORCH_X1, 0, doorZ - 2.0, PORCH_X1 + 1.4, 0.45, doorZ + 2.0, DECK, true)
	for i, x in { PORCH_X1 + 2.5, PORCH_X1 + 4.6 } do
		Parts.cylinder("SteppingStone", frame * CFrame.new(x, 0.25, doorZ + (i - 1.5) * 0.4), 1.8, 0.1, { Color = STONE }, house)
	end
	-- a bench by the door, milk churns and pumpkins
	-- (the bench: slats on two ends, its back leaning on the wall)
	for i, x in { front + 0.65, front + 1.0, front + 1.35 } do
		box("BenchSlat", x - 0.16, 1.95, 86.7, x + 0.16, 2.15, 89.9, if i == 2 then DECK else Color3.fromRGB(190, 150, 100))
	end
	for _, y in { 2.6, 3.2 } do
		box("BenchSlat", front + 0.36, y, 86.7, front + 0.44, y + 0.32, 89.9, Color3.fromRGB(190, 150, 100)) -- (inside the ends' faces)
	end
	for _, z in { 86.95, 89.65 } do
		box("BenchEnd", front + 0.3, PORCH_FLOOR, z - 0.12, front + 1.5, 1.95, z + 0.12, DECK)
		box("BenchEnd", front + 0.3, 1.95, z - 0.12, front + 0.5, 3.6, z + 0.12, DECK)
	end
	prop("MilkChurn", front + 1.0, PORCH_FLOOR, 99.2, 0.4, 0.85, Vector3.new(1.3, 2.4, 1.3), Color3.fromRGB(178, 186, 194))
	prop("MilkChurn", front + 2.2, PORCH_FLOOR, 99.9, 1.7, 0.85, Vector3.new(1.3, 2.4, 1.3), Color3.fromRGB(178, 186, 194))
	for i, z in { posts[2] - 1.0, posts[3] + 1.0 } do
		if not Meshes.piece("Pumpkin", frame * CFrame.new(postX - 1.2, PORCH_FLOOR, z) * CFrame.Angles(0, i * 2, 0), 1.5, house) then
			Parts.ball("Pumpkin", frame * CFrame.new(postX - 1.2, PORCH_FLOOR + 0.6, z), 1.2, { Color = Color3.fromRGB(240, 128, 30) }, house)
		end
	end

	--------------------------------------------------------------------
	-- By the barn's doors (low: the owner sees the field over them)

	prop("HayBale", -67.4, 0.2, BARN_Z1 + 2.4, math.rad(90), 1, Vector3.new(3, 1.6, 1.8), COLORS.hay, true)
	prop("HayBale", -69.6, 0.2, BARN_Z1 + 2.6, math.rad(84), 1, Vector3.new(3, 1.6, 1.8), COLORS.hay, true)
	prop("HayBale", -68.5, 0.2, BARN_Z1 + 6.0, math.rad(8), 1, Vector3.new(3, 1.6, 1.8), COLORS.hay, true)
	prop("Wheelbarrow", -52.8, 0.2, BARN_Z1 + 3.4, math.rad(200), 1, Vector3.new(2, 1.9, 4.4), BARN, true)

	house.Parent = model
	return house
end

return FarmhouseArt
