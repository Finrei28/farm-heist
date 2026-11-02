-- No flicker anywhere in the world (the user, 2026-11-02: "make sure no
-- flickering ever happens anywhere in the world"): everything the server
-- builds, at every building level, every crop and store item, has no two
-- visible faces facing the same way in the same plane (tests/lib/zfight).
-- `lune run tools/flicker` lists them when this fails.
return function(spec, harness)
	local describe, it = spec.describe, spec.it
	local flickerWorld = require("./lib/flickerworld")
	local zfight = require("./lib/zfight")

	describe("flicker (z-fighting)", function()
		it("has no two faces fighting over one plane, anywhere the server builds", function()
			local world = flickerWorld(harness)
			local found = zfight(world)
			if #found > 0 then
				local lines = {}
				for i = 1, math.min(5, #found) do
					local pair = found[i]
					table.insert(lines, `{pair.a:GetFullName()} × {pair.b:GetFullName()}`)
				end
				error(`{#found} flickering pairs (lune run tools/flicker), e.g.\n       {table.concat(lines, "\n       ")}`)
			end
		end)
	end)
end
