-- Farm Level and XP (shared/ProgressionRules): the curve, harvest and sales
-- XP, and level-ups that bring Land Permits.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local ProgressionRules = harness.load("ProgressionRules")
	local Progression = harness.load("Config/Progression")
	local LandRules = harness.load("LandRules")
	local Crops = harness.load("Config/Crops")

	describe("the curve", function()
		it("starts at 0 XP, needs 60 for Lv 2 (reached during the Farm Guide), and keeps rising", function()
			expect(ProgressionRules.xpForLevel(1)).toBe(0)
			expect(ProgressionRules.xpForLevel(2)).toBe(60)
			for level = 3, Progression.MAX_LEVEL do
				expect(ProgressionRules.xpForLevel(level)).toBeGreaterThan(ProgressionRules.xpForLevel(level - 1))
			end
		end)
		it("turns XP back into the level, capped at 50", function()
			expect(ProgressionRules.levelFor(0)).toBe(1)
			expect(ProgressionRules.levelFor(59)).toBe(1)
			expect(ProgressionRules.levelFor(60)).toBe(2)
			for level = 2, Progression.MAX_LEVEL do
				expect(ProgressionRules.levelFor(ProgressionRules.xpForLevel(level))).toBe(level)
				expect(ProgressionRules.levelFor(ProgressionRules.xpForLevel(level) - 1)).toBe(level - 1)
			end
			expect(ProgressionRules.levelFor(1e12)).toBe(Progression.MAX_LEVEL)
		end)
		it("fills the level bar", function()
			local level, into, span = ProgressionRules.progress(90)
			expect(level).toBe(2)
			expect(into).toBe(30)
			expect(span).toBe(ProgressionRules.xpForLevel(3) - 60)
			local _, _, none = ProgressionRules.progress(1e12)
			expect(none).toBe(nil)
		end)
	end)

	describe("earning XP", function()
		it("a Carrot gives 3, a Tomato regrow 14.4, a Farmhand's pick half", function()
			expect(ProgressionRules.harvestXp("Carrot")).toBeNear(3, 1e-9)
			expect(ProgressionRules.harvestXp("Tomato", true)).toBeNear(14.4, 1e-9)
			expect(ProgressionRules.harvestXp("Carrot", false, true)).toBeNear(1.5, 1e-9)
		end)
		it("never gives more per minute of field time for a commoner crop", function()
			for _, crop in Crops.List do
				local perMinute = ProgressionRules.harvestXp(crop.id) / (crop.grow / 60)
				expect(perMinute >= Progression.HARVEST_XP_PER_MINUTE.Common - 1e-9).toBe(true)
			end
		end)
		it("sales give 1 XP per 50 coins", function()
			expect(ProgressionRules.salesXp(500)).toBe(10)
			expect(ProgressionRules.salesXp(-5)).toBe(0)
		end)
	end)

	describe("levelling up", function()
		it("can jump several levels at once, and each permit level brings a Land Permit", function()
			local data = { xp = 0, level = 1 }
			local before, after = ProgressionRules.addXp(data, ProgressionRules.xpForLevel(12))
			expect(before).toBe(1)
			expect(after).toBe(12)
			expect(LandRules.permitsEarned(after) - LandRules.permitsEarned(before)).toBe(6)
		end)
	end)
end
