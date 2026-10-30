-- Inside a farm or not (shared/ZoneRules): the box, the 1-stud hysteresis at
-- the edge, turned plots, and climbing.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local roblox = require("@lune/roblox")
	local Vector3, CFrame = roblox.Vector3, roblox.CFrame
	local ZoneRules = harness.load("ZoneRules")

	-- A 160 × 240-stud plot, 40 studs tall, centred at the origin.
	local zone = { cframe = CFrame.new(0, 0, 0), size = Vector3.new(160, 40, 240) }

	describe("the box", function()
		it("is inside in the middle and outside past the edge", function()
			expect(ZoneRules.inside(zone, Vector3.new(0, 3, 0))).toBe(true)
			expect(ZoneRules.inside(zone, Vector3.new(85, 3, 0))).toBe(false)
			expect(ZoneRules.inside(zone, Vector3.new(0, 3, -125))).toBe(false)
		end)
		it("lets you leave only a stud past the edge (no flickering bat)", function()
			local edge = Vector3.new(80.5, 3, 0)
			expect(ZoneRules.inside(zone, edge, false)).toBe(false)
			expect(ZoneRules.inside(zone, edge, true)).toBe(true)
			expect(ZoneRules.inside(zone, Vector3.new(81.5, 3, 0), true)).toBe(false)
		end)
		it("works for a plot turned round the ring road", function()
			local turned = { cframe = CFrame.new(300, 0, 0) * CFrame.Angles(0, math.rad(90), 0), size = zone.size }
			-- turned 90°: the long side now runs along X
			expect(ZoneRules.inside(turned, Vector3.new(300 + 110, 3, 0))).toBe(true)
			expect(ZoneRules.inside(turned, Vector3.new(300, 3, 110))).toBe(false)
		end)
	end)

	describe("climbing", function()
		it("counts as inside for the whole climb, in or out", function()
			expect(ZoneRules.inside(zone, Vector3.new(0, 3, 130), false, true)).toBe(true)
		end)
	end)
end
