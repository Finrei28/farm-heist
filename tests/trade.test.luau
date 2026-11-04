-- Trading (shared/TradeRules): what can go in an offer, the checks, the
-- all-or-nothing swap (nothing copied or lost, over thousands of random
-- trades) and undoing a logged trade once.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local TradeRules = harness.load("TradeRules")
	local BarnRules = harness.load("BarnRules")
	local Crops = harness.load("Config/Crops")
	local Weather = harness.load("Config/Weather")

	-- (a seeded generator: the same random trades every run)
	local function rngOf(seed: number)
		local state = seed
		local function nextNumber(): number
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end
		return {
			NextNumber = function(_)
				return nextNumber()
			end,
			NextInteger = function(_, lo: number, hi: number)
				return lo + math.floor(nextNumber() * (hi - lo + 1))
			end,
		}
	end

	local CARROT = BarnRules.key("Carrot")
	local WET_PUMPKIN = BarnRules.key("Pumpkin", "Wet")

	local function newData(coins: number?)
		return {
			coins = coins or 1000,
			silo = 0,
			inventory = { crops = { [CARROT] = 50, [WET_PUMPKIN] = 2 }, seeds = { Corn = 3 }, items = {} },
			crime = { debts = {} },
		}
	end

	local function priceOf(cropId: string): number
		return Crops.ById[cropId].value
	end

	describe("offers", function()
		it("takes crops by stack and seeds, up to what you have", function()
			local data, offer = newData(), TradeRules.newOffer()
			expect(TradeRules.setLine(offer, data, "crop", CARROT, 20)).toBe(nil)
			expect(TradeRules.setLine(offer, data, "seed", "Corn", 3)).toBe(nil)
			expect(#offer.lines).toBe(2)
			expect(TradeRules.setLine(offer, data, "crop", CARROT, 51)).toBe("NotEnough")
			expect(TradeRules.setLine(offer, data, "seed", "Pumpkin", 1)).toBe("NotFound")
			expect(TradeRules.setLine(offer, data, "crop", CARROT, 30)).toBe(nil) -- (changes the line, not a second one)
			expect(#offer.lines).toBe(2)
			expect(offer.lines[1].count).toBe(30)
			expect(TradeRules.setLine(offer, data, "crop", CARROT, 0)).toBe(nil) -- (0 takes it out)
			expect(#offer.lines).toBe(1)
		end)
		it("refuses anything that isn't a crop or seeds, and bad numbers", function()
			local data, offer = newData(), TradeRules.newOffer()
			expect(TradeRules.setLine(offer, data, "worker", "1", 1)).toBe("BadRequest")
			expect(TradeRules.setLine(offer, data, "crop", "Gold||", 1)).toBe("BadRequest")
			expect(TradeRules.setLine(offer, data, "crop", CARROT, -1)).toBe("BadRequest")
			expect(TradeRules.setLine(offer, data, "crop", CARROT, 0 / 0)).toBe("BadRequest")
			expect(TradeRules.setLine(offer, data, "crop", nil, 1)).toBe("BadRequest")
		end)
		it("holds at most 8 stacks", function()
			local data, offer = newData(), TradeRules.newOffer()
			for i, crop in Crops.List do
				data.inventory.crops[BarnRules.key(crop.id)] = 5
				local failure = TradeRules.setLine(offer, data, "crop", BarnRules.key(crop.id), 1)
				expect(failure).toBe(if i <= TradeRules.MAX_LINES then nil else "TooMany")
			end
			expect(#offer.lines).toBe(TradeRules.MAX_LINES)
		end)
		it("cleans coin amounts, and no coins while in debt", function()
			local data = newData(500)
			expect(TradeRules.cleanCoins(120.7, data)).toBe(120)
			expect(select(2, TradeRules.cleanCoins(501, data))).toBe("NotEnoughCoins")
			expect(select(2, TradeRules.cleanCoins(-5, data))).toBe("BadRequest")
			expect(select(2, TradeRules.cleanCoins(math.huge, data))).toBe("BadRequest")
			table.insert(data.crime.debts, { ownerId = 2, amount = 100, createdAt = 0 })
			expect(select(2, TradeRules.cleanCoins(10, data))).toBe("InDebt")
			expect(TradeRules.cleanCoins(0, data)).toBe(0)
		end)
		it("values crops at the price times their mutation, seeds at Barley's price", function()
			local offer = { lines = { { kind = "crop", key = WET_PUMPKIN, count = 2 }, { kind = "seed", key = "Corn", count = 3 } }, coins = 10 }
			local wet = math.floor(2 * Crops.ById.Pumpkin.value * Weather.MUTATIONS.Wet.value + 0.5)
			expect(TradeRules.offerValue(offer, priceOf)).toBe(wet + 3 * Crops.ById.Corn.seed + 10)
			expect(TradeRules.lopsided(300, 100)).toBe(true)
			expect(TradeRules.lopsided(299, 100)).toBe(false)
			expect(TradeRules.lopsided(50, 0)).toBe(true)
		end)
	end)

	describe("the swap", function()
		it("moves everything both ways", function()
			local a, b = newData(1000), newData(200)
			b.inventory.crops = {}
			local offerA, offerB = TradeRules.newOffer(), TradeRules.newOffer()
			TradeRules.setLine(offerA, a, "crop", CARROT, 50)
			offerB.coins = 200
			local ok = TradeRules.swap({ data = a, offer = offerA }, { data = b, offer = offerB })
			expect(ok).toBe(true)
			expect(a.inventory.crops[CARROT]).toBe(nil)
			expect(b.inventory.crops[CARROT]).toBe(50)
			expect(a.coins).toBe(1200)
			expect(b.coins).toBe(0)
		end)
		it("does nothing at all if a stack has gone since", function()
			local a, b = newData(), newData()
			local offerA, offerB = TradeRules.newOffer(), TradeRules.newOffer()
			TradeRules.setLine(offerA, a, "crop", CARROT, 50)
			offerB.coins = 100
			a.inventory.crops[CARROT] = 49 -- (one packed meanwhile)
			local ok, reason, side = TradeRules.swap({ data = a, offer = offerA }, { data = b, offer = offerB })
			expect(ok).toBe(false)
			expect(reason).toBe("Gone")
			expect(side).toBe("a")
			expect(a.coins).toBe(1000)
			expect(b.coins).toBe(1000)
			expect(b.inventory.crops[CARROT]).toBe(50)
		end)
		it("checks the barn has room for what's coming", function()
			local a, b = newData(), newData()
			b.inventory.crops = { [CARROT] = 1_190 } -- (room for 10 at the first Silo)
			local offerA, offerB = TradeRules.newOffer(), TradeRules.newOffer()
			TradeRules.setLine(offerA, a, "crop", CARROT, 11)
			expect(select(1, TradeRules.check({ data = a, offer = offerA }, { data = b, offer = offerB }))).toBe("BarnFull")
			TradeRules.setLine(offerA, a, "crop", CARROT, 10)
			expect(TradeRules.check({ data = a, offer = offerA }, { data = b, offer = offerB })).toBe(nil)
		end)
		it("won't swap an empty trade or coins from someone in debt", function()
			local a, b = newData(), newData()
			expect(TradeRules.check({ data = a, offer = TradeRules.newOffer() }, { data = b, offer = TradeRules.newOffer() })).toBe("Empty")
			table.insert(b.crime.debts, { ownerId = 3, amount = 50, createdAt = 0 })
			local offerB = TradeRules.newOffer()
			offerB.coins = 10
			expect(select(1, TradeRules.check({ data = a, offer = TradeRules.newOffer() }, { data = b, offer = offerB }))).toBe("InDebt")
		end)
		it("takes out of an offer what's no longer there", function()
			local data, offer = newData(), TradeRules.newOffer()
			TradeRules.setLine(offer, data, "crop", CARROT, 40)
			TradeRules.setLine(offer, data, "seed", "Corn", 3)
			offer.coins = 900
			data.inventory.crops[CARROT] = 12
			data.inventory.seeds.Corn = nil
			data.coins = 500
			expect(TradeRules.clamp(offer, data)).toBe(true)
			expect(#offer.lines).toBe(1)
			expect(offer.lines[1].count).toBe(12)
			expect(offer.coins).toBe(500)
			expect(TradeRules.clamp(offer, data)).toBe(false)
		end)
		it("never copies or loses anything, over 2,000 random trades", function()
			local rng = rngOf(8)
			local keys = { CARROT, WET_PUMPKIN, BarnRules.key("Corn"), BarnRules.key("Tomato", "Golden") }
			local seeds = { "Corn", "Carrot", "Pumpkin" }
			local players = {}
			for i = 1, 4 do
				local data = newData(rng:NextInteger(0, 5000))
				data.silo = 3
				data.inventory.crops = {}
				data.inventory.seeds = {}
				for _, key in keys do
					data.inventory.crops[key] = rng:NextInteger(0, 40)
				end
				for _, id in seeds do
					data.inventory.seeds[id] = rng:NextInteger(0, 6)
				end
				players[i] = data
			end
			local function totals()
				local t = { coins = 0 }
				for _, data in players do
					t.coins += data.coins
					for key, n in data.inventory.crops do
						t["c" .. key] = (t["c" .. key] or 0) + n
					end
					for key, n in data.inventory.seeds do
						t["s" .. key] = (t["s" .. key] or 0) + n
					end
				end
				return t
			end
			local swapped = 0
			for _ = 1, 2000 do
				local i, j = rng:NextInteger(1, 4), rng:NextInteger(1, 4)
				if i ~= j then
					local offers = { TradeRules.newOffer(), TradeRules.newOffer() }
					for side, data in { players[i], players[j] } do
						for _ = 1, rng:NextInteger(0, 3) do
							if rng:NextNumber() < 0.7 then
								TradeRules.setLine(offers[side], data, "crop", keys[rng:NextInteger(1, #keys)], rng:NextInteger(1, 15))
							else
								TradeRules.setLine(offers[side], data, "seed", seeds[rng:NextInteger(1, #seeds)], rng:NextInteger(1, 3))
							end
						end
						offers[side].coins = TradeRules.cleanCoins(rng:NextInteger(0, 800), data) or 0
					end
					-- (sometimes a stack goes in the meantime: the swap must refuse cleanly)
					if rng:NextNumber() < 0.2 then
						local have = players[i].inventory.crops[keys[1]] or 0
						players[i].inventory.crops[keys[1]] = if have > 5 then have - 5 else nil
					end
					local snapshot = totals()
					local ok = TradeRules.swap({ data = players[i], offer = offers[1] }, { data = players[j], offer = offers[2] })
					local after = totals()
					for key, n in snapshot do
						expect(after[key] or 0).toBe(n)
					end
					for key, n in after do
						expect(snapshot[key] or 0).toBe(n)
					end
					if ok then
						swapped += 1
					end
				end
			end
			expect(swapped > 300).toBe(true)
			for _, data in players do
				expect(data.coins >= 0).toBe(true)
				for _, n in data.inventory.crops do
					expect(n > 0).toBe(true) -- (no empty or negative stacks left behind)
				end
			end
		end)
	end)

	describe("undoing a trade", function()
		local function trade()
			local a, b = newData(1000), newData(1000)
			a.userId, b.userId = 1, 2
			local offerA, offerB = TradeRules.newOffer(), TradeRules.newOffer()
			TradeRules.setLine(offerA, a, "crop", CARROT, 20)
			offerB.coins = 300
			local record = {
				id = "T1",
				a = { userId = 1, lines = TradeRules.logLines(offerA, priceOf), coins = 0 },
				b = { userId = 2, lines = TradeRules.logLines(offerB, priceOf), coins = 300 },
			}
			TradeRules.swap({ data = a, offer = offerA }, { data = b, offer = offerB })
			return a, b, record
		end
		it("gives each back what they gave, once", function()
			local a, b, record = trade()
			expect(a.coins).toBe(1300)
			local reportA = TradeRules.reverse(a, TradeRules.undoFor(record, 1))
			local reportB = TradeRules.reverse(b, TradeRules.undoFor(record, 2))
			expect(a.inventory.crops[CARROT]).toBe(50)
			expect(a.coins).toBe(1000)
			expect(b.inventory.crops[CARROT]).toBe(50)
			expect(b.coins).toBe(1000)
			expect(reportA.returned).toBe(20)
			expect(reportB.taken).toBe(20)
			expect(TradeRules.reverse(a, TradeRules.undoFor(record, 1))).toBe(nil)
		end)
		it("charges for what's been sold since, never below 0 coins", function()
			local _, b, record = trade()
			b.inventory.crops[CARROT] = 60 -- (sold 10 of the 70)
			b.coins = 50
			local report = TradeRules.reverse(b, TradeRules.undoFor(record, 2))
			expect(report.taken).toBe(20)
			b.inventory.crops[CARROT] = 5
			local _, b2, record2 = trade()
			b2.inventory.crops[CARROT] = 5 -- (sold 65: only 5 left to take back)
			b2.coins = 0
			local report2 = TradeRules.reverse(b2, TradeRules.undoFor(record2, 2))
			expect(report2.taken).toBe(5)
			expect(report2.charged).toBe(15 * Crops.ById.Carrot.value)
			expect(b2.coins).toBe(0)
			expect(report2.shortfall > 0).toBe(true)
		end)
	end)
end
