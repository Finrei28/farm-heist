-- Dirt paths that look walked on (docs/ArtDirection.md §5, §7). A plain
-- strip of trail colour read as a flat ribbon, so each path is dressed with
-- low-poly tiles (tools/crop_art/valley.py) laid end to end along it:
--   * PathWear1–3: two worn ruts, darker, wavering, sometimes broken,
--   * PathEdge1–3: the dirt spilling into the grass with a wavy, bitten
--     edge, grass growing up at it (one along each side),
-- and pebbles on it, grass and now and then wildflowers or a stone along
-- the verges. The farms' lanes from the town and each farm's path from the
-- gate to the field use it (WorldBuilder). It sits on a path part the
-- caller built: nothing here is walked on (no collisions, no queries).
--
-- Heights (nothing flat may share a height with something it overlaps, or
-- it flickers): the ruts are 0.05 over the path's top; the spilt dirt 0.05
-- under it (so the path part's straight edge hardly shows), 0.15 over the
-- grass (0.2 under the path). Without the
-- props imported (Meshes.propsReady) a path stays plain.
local Server = script.Parent.Parent
local Meshes = require(Server.World.Meshes)

local PathArt = {}

local TILE = 16 -- a tile's length (stretched a little so whole tiles fill a path)
local TURN = CFrame.Angles(0, math.pi, 0)

-- Dresses a straight path from `from` to `to` (points on its middle line;
-- only X and Z are used), `width` studs wide (the tiles are drawn for 6),
-- its top at `top`, on grass whose top is `ground`. seed: the same path
-- looks the same every time. skip(point) → true keeps pebbles and verge
-- plants off that spot (a road crossing it, a signpost); the flat tiles
-- don't need it (a road's top covers them).
function PathArt.dress(from: Vector3, to: Vector3, width: number, top: number, ground: number, parent: Instance, seed: number,
	skip: ((Vector3) -> boolean)?)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	if length < 4 or not Meshes.propsReady() then
		return
	end
	local along = flat.Unit
	local across = along:Cross(Vector3.yAxis) -- (the path's right, as CFrame.lookAt's +X)
	local start = Vector3.new(from.X, 0, from.Z)
	local rng = Random.new(seed)
	local folder = Instance.new("Model")
	folder.Name = "PathDressing"
	local half = width / 2
	local function at(d: number, side: number): Vector3
		return start + along * d + across * side
	end
	local function bare(point: Vector3): boolean
		return skip ~= nil and skip(point)
	end
	local function spin(): CFrame
		return CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	end

	-- The tiles: ruts down the middle, spilt dirt along each side.
	local count = math.max(1, math.round(length / TILE))
	local step = length / count
	local stretch = Vector3.new(width / 6, 1, step / TILE)
	for i = 0, count - 1 do
		local middle = at((i + 0.5) * step, 0) + Vector3.new(0, top, 0)
		local base = CFrame.lookAt(middle, middle + along)
		Meshes.make(`PathWear{rng:NextInteger(1, 3)}`, if rng:NextNumber() < 0.5 then base * TURN else base, stretch, folder)
		Meshes.make(`PathEdge{rng:NextInteger(1, 3)}`, base, stretch, folder)
		Meshes.make(`PathEdge{rng:NextInteger(1, 3)}`, base * TURN, stretch, folder)
	end

	-- Pebbles on the path, one every 4–7 studs.
	local d = rng:NextNumber(1, 4)
	while d < length - 1 do
		local point = at(d, rng:NextNumber(-half + 0.5, half - 0.5))
		if not bare(point) then
			Meshes.make("Rock", CFrame.new(point + Vector3.new(0, top - 0.04, 0)) * spin(), rng:NextNumber(0.07, 0.14), folder)
		end
		d += rng:NextNumber(4, 7)
	end

	-- The verges: a clump of grass every 9–15 studs a side, some wildflowers,
	-- now and then a stone.
	for _, side in { -1, 1 } do
		d = rng:NextNumber(2, 9)
		while d < length - 1 do
			local point = at(d, side * (half + rng:NextNumber(1.1, 2.2)))
			if not bare(point) then
				local base = CFrame.new(point + Vector3.new(0, ground, 0)) * spin()
				local roll = rng:NextNumber()
				if roll < 0.3 then
					Meshes.make("Wildflowers", base, rng:NextNumber(0.85, 1.15), folder)
				elseif roll < 0.4 then
					Meshes.make("Rock", base, rng:NextNumber(0.18, 0.3), folder)
				else
					Meshes.make("GrassPatch", base, Vector3.new(rng:NextNumber(0.3, 0.42), rng:NextNumber(0.45, 0.65), rng:NextNumber(0.3, 0.42)), folder)
				end
			end
			d += rng:NextNumber(9, 15)
		end
	end
	folder.Parent = parent
end

return PathArt
