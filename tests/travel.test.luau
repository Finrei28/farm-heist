-- The travel buttons (shared/TravelRules): 3 s channels, no cooldowns, and
-- no escaping a raid by teleport.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local Vector3 = require("@lune/roblox").Vector3
	local TravelRules = harness.load("TravelRules")

	local NOW = 1_000_000
	local HERE = Vector3.new(10, 3, 10)
	local CLEAN = { suspect = false, knockedOut = false, carrying = false }

	describe("channels", function()
		it("take 3 s standing still, then go", function()
			local travel = TravelRules.new()
			expect(TravelRules.start(travel, "Home", NOW, HERE, CLEAN)).toBe(true)
			local ok, why = TravelRules.finish(travel, NOW + 2, HERE, CLEAN)
			expect(ok).toBe(false)
			expect(why).toBe("TooSoon")
			local done, kind = TravelRules.finish(travel, NOW + 3, HERE, CLEAN)
			expect(done).toBe(true)
			expect(kind).toBe("Home")
		end)
		it("are cancelled by walking away", function()
			local travel = TravelRules.new()
			TravelRules.start(travel, "Town", NOW, HERE, CLEAN)
			local ok, why = TravelRules.finish(travel, NOW + 3, HERE + Vector3.new(4, 0, 0), CLEAN)
			expect(ok).toBe(false)
			expect(why).toBe("Moved")
			expect(travel.channel).toBe(nil)
		end)
		it("one at a time, and only known buttons", function()
			local travel = TravelRules.new()
			TravelRules.start(travel, "Home", NOW, HERE, CLEAN)
			expect(select(2, TravelRules.start(travel, "Town", NOW, HERE, CLEAN))).toBe("Busy")
			expect(select(2, TravelRules.start(TravelRules.new(), "Moon", NOW, HERE, CLEAN))).toBe("Unknown")
		end)
	end)

	describe("no cooldowns", function()
		it("you can go Home again straight after a trip (the channel is the only wait)", function()
			local travel = TravelRules.new()
			TravelRules.start(travel, "Home", NOW, HERE, CLEAN)
			TravelRules.finish(travel, NOW + 3, HERE, CLEAN)
			expect(TravelRules.start(travel, "Town", NOW + 3.5, HERE, CLEAN)).toBe(true)
			TravelRules.finish(travel, NOW + 6.5, HERE, CLEAN)
			expect(TravelRules.start(travel, "Home", NOW + 7, HERE, CLEAN)).toBe(true)
		end)
	end)

	describe("raids", function()
		it("no teleports for Suspects, the knocked out, or anyone carrying loot", function()
			for _, status in { { suspect = true }, { knockedOut = true }, { carrying = true } } do
				expect(select(2, TravelRules.start(TravelRules.new(), "Home", NOW, HERE, status))).toBe("Blocked")
			end
		end)
		it("checked again at the end: starting a steal mid-channel stops it", function()
			local travel = TravelRules.new()
			TravelRules.start(travel, "Town", NOW, HERE, CLEAN)
			local ok, why = TravelRules.finish(travel, NOW + 3, HERE, { suspect = true })
			expect(ok).toBe(false)
			expect(why).toBe("Blocked")
			expect(travel.channel).toBe(nil)
		end)
	end)
end
