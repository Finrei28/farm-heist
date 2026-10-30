-- Barley's restocks (shared/SeedStock): the same stock for everyone every 5
-- minutes, Commons without limit, rarer seeds only sometimes.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local SeedStock = harness.load("SeedStock")
	local Crops = harness.load("Config/Crops")
	local Rarities = harness.load("Config/Rarities")

	describe("restocks", function()
		it("change every 5 minutes, on the clock", function()
			local t = 1_760_000_000 - 1_760_000_000 % 300
			expect(SeedStock.index(t)).toBe(SeedStock.index(t + 299))
			expect(SeedStock.index(t + 300)).toBe(SeedStock.index(t) + 1)
			expect(SeedStock.nextAt(t + 10)).toBe(t + 300)
		end)
		it("roll the same stock every time (every server agrees)", function()
			local a, b = SeedStock.stock(1234), SeedStock.stock(1234)
			for _, crop in Crops.List do
				expect(a[crop.id]).toBe(b[crop.id])
			end
		end)
		it("always have every Common, with no limit", function()
			for index = 1, 200 do
				local stock = SeedStock.stock(index)
				for _, crop in Crops.List do
					if crop.rarity == "Common" then
						expect(stock[crop.id]).toBe(SeedStock.UNLIMITED)
					end
				end
			end
		end)
		it("bring in rarer seeds about as often as their chance, in whole packs", function()
			local seen, N = {}, 4000
			for index = 1, N do
				for _, crop in Crops.List do
					local seeds = SeedStock.stock(index)[crop.id]
					local rarity = Rarities.ById[crop.rarity]
					if not rarity.unlimited and seeds > 0 then
						seen[crop.id] = (seen[crop.id] or 0) + 1
						expect(seeds % rarity.packSeeds).toBe(0)
						expect(seeds <= rarity.maxPacks * rarity.packSeeds).toBe(true)
					end
				end
			end
			for _, crop in Crops.List do
				local rarity = Rarities.ById[crop.rarity]
				if not rarity.unlimited then
					expect((seen[crop.id] or 0) / N).toBeNear(rarity.seedChance, 0.03)
				end
			end
		end)
	end)

	describe("buying", function()
		local function findRestockWith(cropId)
			for index = 1, 5000 do
				if SeedStock.stock(index)[cropId] > 0 then
					return index * SeedStock.RESTOCK_SECONDS
				end
			end
			error(`no restock has {cropId}`)
		end

		it("counts down your seeds, then sells out, and starts fresh next restock", function()
			local now = findRestockWith("Pumpkin")
			local data = { coins = 1e9 }
			local seeds = SeedStock.left(data, "Pumpkin", now)
			expect(SeedStock.canBuy(data, "Pumpkin", seeds, 5, now)).toBe(true)
			SeedStock.record(data, "Pumpkin", seeds, now)
			expect(SeedStock.left(data, "Pumpkin", now)).toBe(0)
			local ok, reason = SeedStock.canBuy(data, "Pumpkin", 1, 5, now)
			expect(ok).toBe(false)
			expect(reason).toBe("SoldOut")
			expect(SeedStock.left(data, "Pumpkin", now + 300) == SeedStock.stock(SeedStock.index(now + 300)).Pumpkin).toBe(true)
		end)
		it("never runs out of Carrots", function()
			local data = { coins = 1e9 }
			SeedStock.record(data, "Carrot", 10_000, harness.getTime())
			expect(SeedStock.canBuy(data, "Carrot", 500, 1, harness.getTime())).toBe(true)
		end)
		it("locks seeds above your Farm Level, Mythics until Lv 20", function()
			local now = findRestockWith("Pumpkin")
			local _, reason = SeedStock.canBuy({ coins = 1e9 }, "Pumpkin", 1, 4, now)
			expect(reason).toBe("Locked")
			local mythicAt = findRestockWith("CrystalRose")
			expect(select(2, SeedStock.canBuy({ coins = 1e9 }, "CrystalRose", 1, 19, mythicAt))).toBe("Locked")
			expect(SeedStock.canBuy({ coins = 1e9 }, "CrystalRose", 1, 20, mythicAt)).toBe(true)
		end)
		it("needs the coins", function()
			local _, reason = SeedStock.canBuy({ coins = 99 }, "Carrot", 10, 1, harness.getTime())
			expect(reason).toBe("TooPoor")
			expect(SeedStock.canBuy({ coins = 100 }, "Carrot", 10, 1, harness.getTime())).toBe(true)
		end)
		it("rejects nonsense counts", function()
			expect((SeedStock.canBuy({ coins = 1e9 }, "Carrot", 0, 1))).toBe(false)
			expect((SeedStock.canBuy({ coins = 1e9 }, "Carrot", 1.5, 1))).toBe(false)
			expect((SeedStock.canBuy({ coins = 1e9 }, "Nope", 1, 1))).toBe(false)
		end)
	end)
end
