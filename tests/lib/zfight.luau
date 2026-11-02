-- Finds flicker (z-fighting) in a built world (@lune/roblox Instances): two
-- visible faces that face the same way in the same plane and overlap. The
-- renderer can't tell which is in front, so the overlap shimmers between
-- them as the camera moves. Faces facing each other (a box standing on a
-- floor) are fine: one of them is always hidden.
--
-- Knows blocks, wedges, cylinders' flat ends and balls (no flat faces), and
-- SpecialMesh spheres (none) and bricks. Invisible parts (Transparency 1)
-- don't count, nor do two faces that look the same (one colour and
-- material, nothing drawn on them), nor an overlap pressed against
-- something solid (two boxes' bottoms on a floor), nor faces under the
-- ground, which nobody can see.
-- tests/flicker.test.luau, tools/flicker.
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

local PLANE = 0.03 -- studs: faces closer than this are one plane to the depth buffer
local MIN_OVERLAP = 0.03 -- studs: overlaps thinner than this (faces that only meet at an edge) don't show

local function boxFaces(cf, half: Vector3, out, part)
	local axes = { cf.RightVector, cf.UpVector, cf.LookVector * -1 } -- (local X, Y, Z)
	local h = { half.X, half.Y, half.Z }
	for i = 1, 3 do
		local j, k = i % 3 + 1, (i + 1) % 3 + 1
		for _, s in { -1, 1 } do
			local normal = axes[i] * s
			local centre = cf.Position + normal * h[i]
			local a, b = axes[j] * h[j], axes[k] * h[k]
			table.insert(out, { part = part, normal = normal, points = { centre + a + b, centre - a + b, centre - a - b, centre + a - b } })
		end
	end
end

-- A WedgePart: the slope rises from its front (-Z) bottom edge to its back
-- (+Z) top edge.
local function wedgeFaces(cf, half: Vector3, out, part)
	local function at(x, y, z)
		return cf * Vector3.new(x, y, z)
	end
	local hx, hy, hz = half.X, half.Y, half.Z
	local function face(normalLocal: Vector3, points)
		table.insert(out, { part = part, normal = cf:VectorToWorldSpace(normalLocal.Unit), points = points })
	end
	face(Vector3.new(0, -1, 0), { at(hx, -hy, hz), at(-hx, -hy, hz), at(-hx, -hy, -hz), at(hx, -hy, -hz) })
	face(Vector3.new(0, 0, 1), { at(hx, -hy, hz), at(-hx, -hy, hz), at(-hx, hy, hz), at(hx, hy, hz) })
	face(Vector3.new(0, hz, -hy), { at(hx, hy, hz), at(-hx, hy, hz), at(-hx, -hy, -hz), at(hx, -hy, -hz) })
	for _, s in { -1, 1 } do
		face(Vector3.new(s, 0, 0), { at(s * hx, -hy, -hz), at(s * hx, -hy, hz), at(s * hx, hy, hz) })
	end
end

local function cylinderFaces(cf, half: Vector3, out, part)
	local r = math.min(half.Y, half.Z)
	for _, s in { -1, 1 } do
		local normal = cf.RightVector * s
		local centre = cf.Position + normal * half.X
		local points = {}
		for i = 0, 15 do
			local a = i / 16 * math.pi * 2
			table.insert(points, centre + cf.UpVector * (math.cos(a) * r) + cf.LookVector * (math.sin(a) * r))
		end
		table.insert(out, { part = part, normal = normal, points = points })
	end
end

local function facesOf(part, out)
	if part.Transparency >= 1 then
		return
	end
	local cf, half = part.CFrame, part.Size / 2
	local mesh = part:FindFirstChildWhichIsA("SpecialMesh")
	if mesh then
		if mesh.MeshType.Name == "Brick" then
			boxFaces(cf * roblox.CFrame.new(mesh.Offset), half * mesh.Scale, out, part)
		end
		return -- (spheres have no flat faces; file meshes aren't known here)
	end
	if part.ClassName == "WedgePart" then
		wedgeFaces(cf, half, out, part)
	elseif part.ClassName == "Part" or part.ClassName == "SpawnLocation" or part.ClassName == "Seat" then
		local shape = part.Shape.Name
		if shape == "Block" then
			boxFaces(cf, half, out, part)
		elseif shape == "Cylinder" then
			cylinderFaces(cf, half, out, part)
		end
	end
end

-- 2D projections and the separating-axis test for two convex polygons:
-- how deep they overlap (0 or less: apart).
local function project(points, u: Vector3, v: Vector3)
	local out = {}
	for _, p in points do
		table.insert(out, { p:Dot(u), p:Dot(v) })
	end
	return out
end

local function overlapDepth(a, b): number
	local depth = math.huge
	for _, poly in { a, b } do
		local n = #poly
		for i = 1, n do
			local p, q = poly[i], poly[i % n + 1]
			local ex, ey = q[1] - p[1], q[2] - p[2]
			local length = math.sqrt(ex * ex + ey * ey)
			if length > 1e-6 then
				local nx, ny = -ey / length, ex / length
				local minA, maxA, minB, maxB = math.huge, -math.huge, math.huge, -math.huge
				for _, s in a do
					local d = s[1] * nx + s[2] * ny
					minA, maxA = math.min(minA, d), math.max(maxA, d)
				end
				for _, s in b do
					local d = s[1] * nx + s[2] * ny
					minB, maxB = math.min(minB, d), math.max(maxB, d)
				end
				depth = math.min(depth, math.min(maxA, maxB) - math.max(minA, minB))
				if depth <= 0 then
					return depth
				end
			end
		end
	end
	return depth
end

-- Whether a point is inside a part (solid shapes only).
local function inside(part, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	if math.abs(p.X) > h.X or math.abs(p.Y) > h.Y or math.abs(p.Z) > h.Z then
		return false
	end
	if part.ClassName == "WedgePart" then
		return p.Y * h.Z <= p.Z * h.Y -- (under the slope)
	end
	local shape = if part.ClassName == "Part" then part.Shape.Name else "Block"
	if shape == "Cylinder" then
		return p.Y * p.Y + p.Z * p.Z <= math.min(h.Y, h.Z) ^ 2
	elseif shape == "Ball" then
		return p.Magnitude <= math.min(h.X, h.Y, h.Z)
	end
	return true
end

-- Opaque parts in a grid of cells, for "is this spot covered?".
local CELL = 32
local function grid(parts)
	local cells = {}
	for _, part in parts do
		local cf, h = part.CFrame, part.Size / 2
		local extent = Vector3.new(
			math.abs(cf.RightVector.X) * h.X + math.abs(cf.UpVector.X) * h.Y + math.abs(cf.LookVector.X) * h.Z,
			math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z,
			math.abs(cf.RightVector.Z) * h.X + math.abs(cf.UpVector.Z) * h.Y + math.abs(cf.LookVector.Z) * h.Z)
		local lo, hi = cf.Position - extent, cf.Position + extent
		for x = math.floor(lo.X / CELL), math.floor(hi.X / CELL) do
			for y = math.floor(lo.Y / CELL), math.floor(hi.Y / CELL) do
				for z = math.floor(lo.Z / CELL), math.floor(hi.Z / CELL) do
					local k = `{x},{y},{z}`
					cells[k] = cells[k] or {}
					table.insert(cells[k], part)
				end
			end
		end
	end
	return function(point: Vector3): boolean
		local k = `{math.floor(point.X / CELL)},{math.floor(point.Y / CELL)},{math.floor(point.Z / CELL)}`
		for _, part in cells[k] or {} do
			if inside(part, point) then
				return true
			end
		end
		return false
	end
end

local function drawnOn(part): boolean
	return part:FindFirstChildWhichIsA("Decal") ~= nil or part:FindFirstChildWhichIsA("Texture") ~= nil
end

local function looksSame(a, b): boolean
	return a.Color == b.Color and a.Material == b.Material and a.Transparency == b.Transparency
		and a.Reflectance == b.Reflectance and not drawnOn(a) and not drawnOn(b)
end

local function pointIn(poly, x: number, y: number): boolean
	local sign = 0
	local n = #poly
	for i = 1, n do
		local p, q = poly[i], poly[i % n + 1]
		local cross = (q[1] - p[1]) * (y - p[2]) - (q[2] - p[2]) * (x - p[1])
		if math.abs(cross) > 1e-9 then
			local s = if cross > 0 then 1 else -1
			if sign ~= 0 and s ~= sign then
				return false
			end
			sign = s
		end
	end
	return true
end

local function key(normal: Vector3): string
	return string.format("%.3f,%.3f,%.3f", normal.X, normal.Y, normal.Z)
end

-- Every flickering pair under `root`: { { a, b, depth, gap } }.
return function(root)
	local faces, solid = {}, {}
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") then
			facesOf(part, faces)
			if part.Transparency == 0 then
				table.insert(solid, part)
			end
		end
	end
	local covered = grid(solid)
	-- Whether any of the overlap can be seen: spots in it, just off the
	-- face, not inside something solid.
	local function seen(a, b, u: Vector3, v: Vector3, normal: Vector3, d: number): boolean
		if normal.Y < -0.99 and -d < 0.35 then
			return false -- (facing down at ground level: the camera never goes under the ground)
		end
		local lo1, hi1 = math.max(a.lo, b.lo), math.min(a.hi, b.hi)
		local lo2, hi2 = math.max(a.lov, b.lov), math.min(a.hiv, b.hiv)
		local steps = 6
		for i = 0, steps do
			for j = 0, steps do
				local x = lo1 + (hi1 - lo1) * (0.02 + 0.96 * i / steps)
				local y = lo2 + (hi2 - lo2) * (0.02 + 0.96 * j / steps)
				if pointIn(a.flat, x, y) and pointIn(b.flat, x, y) then
					local point = u * x + v * y + normal * (d + 0.06)
					if not covered(point) then
						return true
					end
				end
			end
		end
		return false
	end
	local groups = {}
	for _, face in faces do
		local k = key(face.normal)
		groups[k] = groups[k] or {}
		face.d = face.points[1]:Dot(face.normal)
		table.insert(groups[k], face)
	end
	local found = {}
	for _, group in groups do
		local normal = group[1].normal
		local u = if math.abs(normal.Y) < 0.9 then normal:Cross(Vector3.new(0, 1, 0)).Unit else normal:Cross(Vector3.new(1, 0, 0)).Unit
		local v = normal:Cross(u)
		table.sort(group, function(a, b)
			return a.d < b.d
		end)
		-- runs of faces in one plane, then a sweep along u within each run
		local i = 1
		while i <= #group do
			local j = i
			while j < #group and group[j + 1].d - group[j].d < PLANE do
				j += 1
			end
			if j > i then
				local run = {}
				for n = i, j do
					local face = group[n]
					local flat = project(face.points, u, v)
					local lo, hi = math.huge, -math.huge
					local lov, hiv = math.huge, -math.huge
					for _, p in flat do
						lo, hi = math.min(lo, p[1]), math.max(hi, p[1])
						lov, hiv = math.min(lov, p[2]), math.max(hiv, p[2])
					end
					table.insert(run, { face = face, flat = flat, lo = lo, hi = hi, lov = lov, hiv = hiv })
				end
				table.sort(run, function(a, b)
					return a.lo < b.lo
				end)
				for x = 1, #run do
					local a = run[x]
					for y = x + 1, #run do
						local b = run[y]
						if b.lo >= a.hi - MIN_OVERLAP then
							break
						end
						if a.face.part ~= b.face.part and b.lov < a.hiv - MIN_OVERLAP and a.lov < b.hiv - MIN_OVERLAP
							and math.abs(a.face.d - b.face.d) < PLANE then
							local depth = overlapDepth(a.flat, b.flat)
							if depth > MIN_OVERLAP and not looksSame(a.face.part, b.face.part) and seen(a, b, u, v, normal, a.face.d) then
								table.insert(found, { a = a.face.part, b = b.face.part, depth = depth, gap = math.abs(a.face.d - b.face.d), normal = normal, d = a.face.d })
							end
						end
					end
				end
			end
			i = j + 1
		end
	end
	return found
end
