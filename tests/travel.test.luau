-- The travel buttons (shared/TravelRules): at once, no cooldowns, a moment
-- for Home with a thief on your farm, and no escaping a raid by teleport.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local TravelRules = harness.load("TravelRules")

	local CLEAN = { suspect = false, knockedOut = false, carrying = false }

	describe("travel", function()
		it("Home, Town and Visit go at once, as often as you like", function()
			for kind in TravelRules.KINDS do
				expect(TravelRules.check(kind, CLEAN)).toBe(true)
				expect(TravelRules.check(kind, CLEAN)).toBe(true)
			end
			expect(TravelRules.check("Home", nil)).toBe(true)
		end)
		it("only goes to the places it knows", function()
			expect(select(2, TravelRules.check("Moon", CLEAN))).toBe("Unknown")
		end)
	end)

	describe("raids", function()
		it("Home takes a moment with a thief on your farm, and only Home", function()
			expect(TravelRules.waitFor("Home", true)).toBe(TravelRules.RAID_WAIT)
			expect(TravelRules.RAID_WAIT > 0).toBe(true)
			expect(TravelRules.waitFor("Home", false)).toBe(0)
			expect(TravelRules.waitFor("Town", true)).toBe(0)
			expect(TravelRules.waitFor("Visit", true)).toBe(0)
		end)
		it("no teleports for Suspects, the knocked out, or anyone carrying loot", function()
			for _, status in { { suspect = true }, { knockedOut = true }, { carrying = true } } do
				for kind in TravelRules.KINDS do
					expect(select(2, TravelRules.check(kind, status))).toBe("Blocked")
				end
			end
		end)
	end)
end
