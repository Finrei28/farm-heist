-- Lists every flickering pair of faces in everything the server builds
-- (tests/lib/zfight, tests/lib/flickerworld). From the project folder:
--   lune run tools/flicker
local Harness = require("../tests/lib/harness")
local flickerWorld = require("../tests/lib/flickerworld")
local zfight = require("../tests/lib/zfight")

Harness.reset()
Harness.fresh()
local world = flickerWorld(Harness)
local found = zfight(world)

-- grouped by the two parts' paths without plot numbers
local groups, order = {}, {}
local function path(part)
	return (string.gsub(string.gsub(part:GetFullName(), "^.-World%.", ""), "Plot%d+", "Plot"))
end
for _, pair in found do
	local a, b = path(pair.a), path(pair.b)
	if a > b then
		a, b = b, a
	end
	local key = `{a}  ×  {b}`
	if not groups[key] then
		groups[key] = { count = 0, depth = 0, gap = 0, normal = pair.normal, d = pair.d }
		table.insert(order, key)
	end
	local g = groups[key]
	g.count += 1
	g.depth = math.max(g.depth, pair.depth)
	g.gap = math.max(g.gap, pair.gap)
end
table.sort(order)
for _, key in order do
	local g = groups[key]
	local n = g.normal
	print(string.format("%3d×  overlap %.2f  gap %.3f  facing (%.1f,%.1f,%.1f) at %.2f   %s", g.count, g.depth, g.gap, n.X, n.Y, n.Z, g.d, key))
end
print(`{#found} flickering pairs in {#order} kinds`)
