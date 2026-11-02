-- A stolen crop in a thief's hands (shared/LootRules): one at a time, its
-- value, where it goes back to, and the summary line.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local LootRules = harness.load("LootRules")

	local ALEX, SAM = 101, 202

	describe("your hands", function()
		it("hold one stolen crop at a time", function()
			local loot = LootRules.new()
			expect(LootRules.isEmpty(loot)).toBe(true)
			expect(LootRules.fits(loot)).toBe(true)
			LootRules.add(loot, "Pumpkin", "Pumpkin||", ALEX)
			expect(LootRules.crop(loot)).toBe("Pumpkin")
			expect(LootRules.fits(loot)).toBe(false)
			expect(LootRules.crop(LootRules.new())).toBe(nil)
		end)
		it("count a crop against the farm's raid cap by rarity", function()
			expect(LootRules.raidWeight("Carrot")).toBe(1)
			expect(LootRules.raidWeight("Pumpkin")).toBe(2)
			expect(LootRules.raidWeight("Moonmelon")).toBe(5)
		end)
		it("know which farm the crop came from", function()
			local loot = LootRules.new()
			LootRules.add(loot, "Carrot", "Carrot||", ALEX)
			expect(LootRules.hasFrom(loot, ALEX)).toBe(true)
			expect(LootRules.hasFrom(loot, SAM)).toBe(false)
		end)
		it("are worth the loot's market value (base values by default)", function()
			local loot = LootRules.new()
			LootRules.add(loot, "Pumpkin", "Pumpkin||", ALEX)
			expect(LootRules.value(loot.items)).toBe(610)
			expect(LootRules.value(loot.items, function()
				return 100
			end)).toBe(100)
		end)
		it("empty in one go", function()
			local loot = LootRules.new()
			LootRules.add(loot, "Carrot", "Carrot||", ALEX)
			local items = LootRules.takeAll(loot)
			expect(#items).toBe(1)
			expect(LootRules.isEmpty(loot)).toBe(true)
		end)
		it("full, you walk at 85%", function()
			expect(LootRules.speed(16, true)).toBeNear(13.6, 1e-9)
			expect(LootRules.speed(16, false)).toBe(16)
		end)
		it("sum up the loot for notes and the mugshot (with the crop mid-steal)", function()
			local items = { { crop = "Pumpkin" }, { crop = "Carrot" }, { crop = "Pumpkin" } }
			expect(LootRules.summary(items)).toBe("🎃 Pumpkin ×2, 🥕 Carrot")
		end)
	end)

	describe("returned loot", function()
		local function fromBoth()
			return { { crop = "Carrot", key = "Carrot||", ownerId = ALEX }, { crop = "Corn", key = "Corn||", ownerId = SAM } }
		end

		it("goes back to its farm's owner when they're here", function()
			local out = LootRules.returns(fromBoth(), function()
				return true
			end, ALEX)
			expect(#out[tostring(ALEX)]).toBe(1)
			expect(#out[tostring(SAM)]).toBe(1)
		end)
		it("goes to the owner who stopped the thief when its own owner has left (§4.12)", function()
			local out = LootRules.returns(fromBoth(), function(id)
				return id == ALEX
			end, ALEX)
			expect(#out[tostring(ALEX)]).toBe(2)
			expect(out[tostring(SAM)]).toBe(nil)
		end)
		it("is lost when nobody stopped them and its owner has left", function()
			local out = LootRules.returns(fromBoth(), function(id)
				return id == ALEX
			end, nil)
			expect(#out[tostring(ALEX)]).toBe(1)
			expect(out[tostring(SAM)]).toBe(nil)
		end)
	end)
end
