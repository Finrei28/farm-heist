-- A stolen crop in a thief's hands (shared/LootRules): one at a time, its
-- value, where it goes back to, who can take back or grab one a bonked
-- thief dropped, and the summary line.
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
			expect(LootRules.value(loot.items)).toBe(6_100)
			expect(LootRules.value(loot.items, function()
				return 100
			end)).toBe(100)
		end)
		it("hold a whole patch: every carrot counts", function()
			local loot = LootRules.new()
			LootRules.add(loot, "Carrot", "Carrot||", ALEX, nil, 6)
			local cropId, count = LootRules.crop(loot)
			expect(cropId).toBe("Carrot")
			expect(count).toBe(6)
			expect(LootRules.value(loot.items)).toBe(180)
			expect(LootRules.summary(loot.items)).toBe("🥕 6 carrots")
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
		it("a stolen crop only slows you on a farm, where you can still be bonked", function()
			expect(LootRules.slowed(true, 3)).toBe(true)
			expect(LootRules.slowed(true, 0)).toBe(false)
			expect(LootRules.slowed(false, 3)).toBe(false)
		end)
		it("sum up the loot for notes and the mugshot (with the crop mid-steal)", function()
			local items = { { crop = "Pumpkin" }, { crop = "Carrot", count = 6 }, { crop = "Pumpkin", count = 1 } }
			expect(LootRules.summary(items)).toBe("🎃 2 pumpkins, 🥕 6 carrots")
		end)
		it("say a mutated crop's mutation, and count it at its value (for the fine)", function()
			local items = { { crop = "Carrot", key = "Carrot|Wet|", count = 6 } }
			expect(LootRules.summary(items)).toBe("🥕 6 Wet carrots")
			expect(LootRules.value(items)).toBeNear(6 * 30 * 1.3, 1e-6)
			expect(LootRules.value({ { crop = "Pumpkin", key = "Pumpkin|Moonlit|" } })).toBe(6_100 * 5)
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

	describe("a dropped crop (§4.12)", function()
		local KIM, LEE = 303, 404
		local function role(o)
			local d = { whoId = KIM, cropOwnerId = ALEX, farmOwnerId = ALEX, trustedByCrop = false, trustedByFarm = false }
			for k, v in o do
				d[k] = v
			end
			return LootRules.dropRole(d)
		end
		it("its owner takes back, and so do their Trusted friends", function()
			expect(role({ whoId = ALEX })).toBe("TakeBack")
			expect(role({ trustedByCrop = true })).toBe("TakeBack")
		end)
		it("anyone else grabs it, the thief who dropped it too", function()
			expect(role({})).toBe("Grab")
			expect(role({ whoId = LEE })).toBe("Grab")
		end)
		it("carried into another farm, that farm's owner (and friends) can take it back too", function()
			expect(role({ whoId = SAM, farmOwnerId = SAM })).toBe("TakeBack")
			expect(role({ farmOwnerId = SAM, trustedByFarm = true })).toBe("TakeBack")
		end)
		it("only one person gets it: whoever finishes first; anyone after finds it gone", function()
			local drop = { id = 7, items = { { crop = "Pumpkin", key = "Pumpkin||", ownerId = ALEX } } }
			local drops = { [7] = drop }
			expect(LootRules.takeDrop(drops, 7)).toBe(drop) -- (the farmer's Take back)
			expect(LootRules.takeDrop(drops, 7)).toBe(nil) -- (the grabber, a moment later)
			expect(LootRules.takeDrop(drops, 7)).toBe(nil) -- (its 30 s running out)
			expect(next(drops)).toBe(nil)
		end)
		it("taken back, it goes to its owner's barn, or the farm's owner's when they've left", function()
			local items = { { crop = "Pumpkin", key = "Pumpkin||", ownerId = SAM } }
			local home = LootRules.returns(items, function()
				return true
			end, ALEX)
			expect(#home[tostring(SAM)]).toBe(1)
			local gone = LootRules.returns(items, function(id)
				return id ~= SAM
			end, ALEX)
			expect(#gone[tostring(ALEX)]).toBe(1)
		end)
	end)
end
