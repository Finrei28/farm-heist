-- The Farm Guide (shared/GuideRules, Config/Guide): steps ticked off in any
-- order, the Carrots counted for the first one, the reward paid once.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local GuideRules = harness.load("GuideRules")
	local Guide = harness.load("Config/Guide")
	local Settings = harness.load("Config/Settings")

	local function newGuide()
		return { done = {}, planted = 0, finished = false, hidden = false, rewarded = false }
	end

	describe("the steps", function()
		it("has the eight steps of the design doc, in order, each with a spot", function()
			local ids = {}
			for _, step in Guide.STEPS do
				table.insert(ids, step.id)
				expect(type(step.where)).toBe("string")
				expect(#step.hint > 0).toBe(true)
			end
			expect(table.concat(ids, " ")).toBe("Plant Water Harvest Pack Dispatch Seeds Store Hire")
		end)
		it("starts at Plant and moves on as steps are done, in any order", function()
			local guide = newGuide()
			expect(GuideRules.current(guide).id).toBe("Plant")
			expect(GuideRules.record(guide, "Water")).toBe("done")
			expect(GuideRules.current(guide).id).toBe("Plant") -- (the card still asks for the first not done)
			expect(GuideRules.record(guide, "Plant")).toBe("done")
			expect(GuideRules.current(guide).id).toBe("Harvest")
			expect(GuideRules.count(guide)).toBe(2)
		end)
		it("ignores a step done twice or one it doesn't know", function()
			local guide = newGuide()
			GuideRules.record(guide, "Harvest")
			expect(GuideRules.record(guide, "Harvest")).toBe(nil)
			expect(GuideRules.record(guide, "Fly")).toBe(nil)
			expect(GuideRules.count(guide)).toBe(1)
		end)
	end)

	describe("planting the free Carrots", function()
		it("gives the player exactly the Carrots the first step asks for", function()
			expect(Settings.START_SEEDS.Carrot).toBe(Guide.PLANT_COUNT)
		end)
		it("is done at the fifth Carrot", function()
			local guide = newGuide()
			for left = 4, 1, -1 do
				expect(GuideRules.planted(guide, left)).toBe(nil)
			end
			expect(guide.planted).toBe(4)
			expect(GuideRules.planted(guide, 0)).toBe("done")
			expect(guide.done.Plant).toBe(true)
			expect(GuideRules.planted(guide, 0)).toBe(nil) -- (it doesn't count on)
		end)
		it("is done sooner if there are no seeds left to plant", function()
			local guide = newGuide()
			GuideRules.planted(guide, 3)
			expect(GuideRules.planted(guide, 0)).toBe("done")
		end)
	end)

	describe("finishing", function()
		it("says finished at the last step and pays once", function()
			local guide = newGuide()
			for i, step in Guide.STEPS do
				local result = GuideRules.record(guide, step.id)
				expect(result).toBe(if i == #Guide.STEPS then "finished" else "done")
			end
			expect(GuideRules.visible(guide)).toBe(false)
			expect(GuideRules.claimReward(guide)).toBe(true)
			expect(GuideRules.claimReward(guide)).toBe(false)
			expect(Guide.REWARD_COINS).toBe(3_000)
		end)
		it("starts again from the first step without paying again", function()
			local guide = newGuide()
			for _, step in Guide.STEPS do
				GuideRules.record(guide, step.id)
			end
			GuideRules.claimReward(guide)
			GuideRules.restart(guide)
			expect(GuideRules.visible(guide)).toBe(true)
			expect(GuideRules.current(guide).id).toBe("Plant")
			expect(guide.planted).toBe(0)
			for _, step in Guide.STEPS do
				GuideRules.record(guide, step.id)
			end
			expect(GuideRules.claimReward(guide)).toBe(false)
		end)
		it("stays hidden once closed, but still counts steps", function()
			local guide = newGuide()
			guide.hidden = true
			expect(GuideRules.visible(guide)).toBe(false)
			expect(GuideRules.record(guide, "Plant")).toBe("done")
		end)
	end)
end
