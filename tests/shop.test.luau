-- Selling in your store (shared/ShopRules): the stockroom, filling
-- displays, prices, shoppers' picks and the rating, against
-- docs/GameDesign.md §4.8 and shared/DemandModel.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local ShopRules = harness.load("ShopRules")
	local DemandModel = harness.load("DemandModel")
	local StoreLayout = harness.load("StoreLayout")
	local Shop = harness.load("Config/Shop")
	local Store = harness.load("Config/Store")

	-- A store with one Honour Box and the displays given ({ id = itemId }).
	local function newStore(displays)
		local layout = { box = { item = "HonourBox", x = 5, y = 1, rot = 2 } }
		local x = 1
		for id, itemId in displays or {} do
			layout[id] = { item = itemId, x = x, y = 3, rot = 0, slots = StoreLayout.newSlots(itemId) }
			x += Store.ITEMS[itemId].size[1]
		end
		return { level = 1, layout = layout, stockroom = {}, prices = {}, rating = { scores = {} } }
	end
	local function crate(crop, units, grade)
		return { crop = crop, key = `{crop}||`, units = units, grade = grade or "B" }
	end
	local function market(price)
		return function()
			return price
		end
	end
	local function slot(store, id, index)
		return store.layout[id].slots[index]
	end

	describe("filling", function()
		it("tops each slot up from the stockroom, grade A first, emptying small crates first", function()
			local store = newStore({ s = "WoodenShelf" })
			store.stockroom = { crate("Carrot", 12, "B"), crate("Carrot", 3, "B"), crate("Carrot", 2, "A") }
			local moved = ShopRules.fill(store, "s", market(18))
			expect(moved).toBe(17)
			expect(slot(store, "s", 1).crop).toBe("Carrot")
			expect(slot(store, "s", 1).units).toBe(15)
			expect(slot(store, "s", 1).a).toBe(2)
			expect(slot(store, "s", 2).units).toBe(2) -- (Auto: the second slot takes what's left)
			expect(#store.stockroom).toBe(0)
		end)
		it("puts a different crop on each Auto slot while there are different ones", function()
			local store = newStore({ s = "WoodenShelf" })
			store.stockroom = { crate("Carrot", 12), crate("Carrot", 12), crate("Wheat", 5) }
			ShopRules.fill(store, "s", market(18))
			expect(slot(store, "s", 1).crop).toBe("Carrot")
			expect(slot(store, "s", 2).crop).toBe("Wheat")
		end)
		it("only puts out crops a display can hold (Pumpkins need more than a Produce Crate)", function()
			local store = newStore({ c = "ProduceCrate", s = "WoodenShelf" })
			store.stockroom = { crate("Pumpkin", 6) }
			ShopRules.fillAll(store, market(610))
			expect(slot(store, "c", 1).units).toBe(0)
			expect(slot(store, "s", 1).crop).toBe("Pumpkin")
			expect(ShopRules.canHold("ProduceCrate", "Pumpkin")).toBe(false)
			expect(ShopRules.canHold("ChillerCabinet", "Pineapple")).toBe(true)
		end)
		it("keeps a slot to its set crop, and sends the old crop back", function()
			local store = newStore({ s = "WoodenShelf" })
			store.stockroom = { crate("Carrot", 12), crate("Wheat", 12) }
			ShopRules.fill(store, "s", market(18))
			expect(ShopRules.setSlot(store, "s", 1, "Wheat")).toBe(nil)
			expect(slot(store, "s", 1).units).toBe(0)
			expect(ShopRules.stockroomUnits(store).Carrot).toBe(12)
			ShopRules.fill(store, "s", market(18))
			expect(slot(store, "s", 1).crop).toBe("Wheat")
			expect(ShopRules.setSlot(store, "s", 2, "Pineapple")).toBe("CantHold")
		end)
		it("prices a crop going out for the first time at the reference, and keeps your price after", function()
			local store = newStore({ c = "ProduceCrate" })
			store.stockroom = { crate("Carrot", 12) }
			ShopRules.fill(store, "c", market(22))
			expect(store.prices.Carrot).toBe(20) -- ½ × 18 + ½ × 22
			store.prices.Carrot = 30
			ShopRules.empty(store, "c")
			ShopRules.fill(store, "c", market(22))
			expect(store.prices.Carrot).toBe(30)
		end)
		it("empties a display back into the stockroom, topping up part-full crates", function()
			local store = newStore({ s = "WoodenShelf" })
			store.stockroom = { crate("Carrot", 12), crate("Carrot", 12), crate("Carrot", 6, "A") }
			ShopRules.fill(store, "s", market(18))
			expect(#store.stockroom).toBe(0)
			expect(ShopRules.empty(store, "s")).toBe(30)
			expect(ShopRules.stockroomUnits(store).Carrot).toBe(30)
			expect(#store.stockroom).toBe(3) -- 6 A, then 24 B in two full crates
		end)
		it("counts the stockroom's room at this level", function()
			local store = newStore()
			expect(ShopRules.stockroomRoom(store)).toBe(6)
			for _ = 1, 7 do
				table.insert(store.stockroom, crate("Carrot", 1))
			end
			expect(ShopRules.stockroomRoom(store)).toBe(0)
			store.level = 3
			expect(ShopRules.stockroomRoom(store)).toBe(3)
		end)
	end)

	describe("a Stocker", function()
		it("fills only as many units as their round allows, the emptiest display first", function()
			local store = newStore({ a = "WoodenShelf", b = "WoodenShelf" })
			store.stockroom = { crate("Carrot", 12), crate("Wheat", 12) }
			slot(store, "a", 1).crop, slot(store, "a", 1).units = "Carrot", 4
			store.stockroom[1].units = 8
			local moved = ShopRules.restockDisplays(store, market(18), 5)
			expect(moved).toBe(5)
			local onA, onB = 0, 0
			for _, s in store.layout.a.slots do
				onA += s.units
			end
			for _, s in store.layout.b.slots do
				onB += s.units
			end
			expect(onA).toBe(4) -- (b was emptier)
			expect(onB).toBe(5)
		end)
		it("leaves displays alone when there's nothing for them", function()
			local store = newStore({ a = "WoodenShelf" })
			expect(ShopRules.restockDisplays(store, market(18), 50)).toBe(0)
		end)
	end)

	describe("selling while you're away", function()
		it("takes the units off the displays, grade A first, at your price", function()
			local store = newStore({ a = "WoodenShelf" })
			local s1 = slot(store, "a", 1)
			s1.crop, s1.units, s1.a = "Carrot", 6, 2
			store.prices.Carrot = 20
			local taken, coins = ShopRules.sellOff(store, "Carrot", 4)
			expect(taken).toBe(4)
			expect(coins).toBe(2 * 23 + 2 * 20)
			expect(s1.units).toBe(2)
			expect(s1.a).toBe(0)
			taken = ShopRules.sellOff(store, "Carrot", 10)
			expect(taken).toBe(2)
			expect(s1.crop).toBe(nil)
		end)
	end)

	describe("prices", function()
		it("stay within 50–300% of the reference", function()
			local store = newStore()
			expect(ShopRules.setPrice(store, "Carrot", 1, 18)).toBe(9)
			expect(ShopRules.setPrice(store, "Carrot", 1000, 18)).toBe(54)
			expect(ShopRules.setPrice(store, "Carrot", 25.4, 18)).toBe(25)
		end)
	end)

	describe("shoppers", function()
		it("don't come to a store with nothing on display", function()
			local store = newStore({ c = "ProduceCrate" })
			expect(ShopRules.isOpen(store)).toBe(false)
			expect(#ShopRules.wants(store, harness.Random.new(1))).toBe(0)
		end)
		it("want 1 crop at Level 1, 2–3 at Level 15, from what's out", function()
			local store = newStore({ a = "ProduceCrate", b = "ProduceCrate", c = "ProduceCrate" })
			slot(store, "a", 1).crop, slot(store, "a", 1).units = "Carrot", 5
			slot(store, "b", 1).crop, slot(store, "b", 1).units = "Wheat", 5
			slot(store, "c", 1).crop, slot(store, "c", 1).units = "Potato", 5
			local rng = harness.Random.new(4)
			for _ = 1, 50 do
				expect(#ShopRules.wants(store, rng)).toBe(1)
			end
			store.level = 15
			for _ = 1, 50 do
				local wants = ShopRules.wants(store, rng)
				expect(#wants >= 2 and #wants <= 3).toBe(true)
				expect(wants[1] ~= wants[2]).toBe(true)
			end
		end)
		it("buy as often as DemandModel says, presentation included (the window's estimate)", function()
			local rng = harness.Random.new(7)
			for _, case in { { item = "ProduceCrate", price = 18, stars = 3 }, { item = "ProduceCrate", price = 22, stars = 5 },
				{ item = "BulkBin", price = 18, stars = 3 }, { item = "TieredRack", price = 24, stars = 1 } } do
				local bought, visits = 0, 4000
				local present = Store.ITEMS[case.item].present
				for _ = 1, visits do
					local store = newStore({ d = case.item })
					slot(store, "d", 1).crop, slot(store, "d", 1).units = "Carrot", 12
					store.prices.Carrot = case.price
					for _ = 1, 10 do
						table.insert(store.rating.scores, case.stars)
					end
					if ShopRules.pick(store, "d", "Carrot", rng, market(18)) == "Bought" then
						bought += 1
					end
				end
				expect(bought / visits).toBeNear(DemandModel.buyChance(case.price, 18, case.stars, false, present), 0.03)
			end
		end)
		it("take 1–4 units (2.5 on average), grade A first at 15% more", function()
			local rng = harness.Random.new(3)
			local units, buyers = 0, 0
			for _ = 1, 2000 do
				local store = newStore({ c = "ProduceCrate" })
				slot(store, "c", 1).crop, slot(store, "c", 1).units, slot(store, "c", 1).a = "Carrot", 12, 12
				store.prices.Carrot = 6 -- cheap: everyone buys
				local result, line = ShopRules.pick(store, "c", "Carrot", rng, market(18))
				expect(result).toBe("Bought")
				expect(line.units >= 1 and line.units <= 4).toBe(true)
				expect(line.coins).toBe(line.units * 7) -- 6 × 1.15, rounded
				expect(slot(store, "c", 1).a).toBe(12 - line.units)
				units += line.units
				buyers += 1
			end
			expect(units / buyers).toBeNear(Shop.UNITS_PER_SHOPPER, 0.1)
		end)
		it("find a display sold out, and never take more than is on it", function()
			local store = newStore({ c = "ProduceCrate" })
			slot(store, "c", 1).crop, slot(store, "c", 1).units = "Carrot", 1
			store.prices.Carrot = 9
			local result, line = ShopRules.pick(store, "c", "Carrot", harness.Random.new(5), market(18))
			expect(result).toBe("Bought")
			expect(line.units).toBe(1)
			expect(slot(store, "c", 1).crop).toBe(nil)
			expect(ShopRules.isOpen(store)).toBe(false)
			expect((ShopRules.pick(store, "c", "Carrot", harness.Random.new(5), market(18)))).toBe("SoldOut")
		end)
		it("put their basket back on the display when they give up in the queue", function()
			local store = newStore({ c = "ProduceCrate" })
			slot(store, "c", 1).crop, slot(store, "c", 1).units, slot(store, "c", 1).a = "Carrot", 12, 2
			store.prices.Carrot = 6
			local _, line = ShopRules.pick(store, "c", "Carrot", harness.Random.new(9), market(18))
			ShopRules.putBack(store, line)
			expect(slot(store, "c", 1).units).toBe(12)
			expect(slot(store, "c", 1).a).toBe(2)
			-- ... or to the stockroom if the display's gone
			_, line = ShopRules.pick(store, "c", "Carrot", harness.Random.new(9), market(18))
			store.layout.c = nil
			ShopRules.putBack(store, line)
			expect(ShopRules.stockroomUnits(store).Carrot).toBe(line.units)
		end)
	end)

	describe("the rating", function()
		it("starts at 3★ and averages the last 50 shoppers", function()
			local store = newStore()
			expect(ShopRules.stars(store)).toBe(3)
			for _ = 1, 60 do
				ShopRules.addScore(store, Shop.SCORE_BOUGHT)
			end
			expect(#store.rating.scores).toBe(Shop.RATING_WINDOW)
			expect(ShopRules.stars(store)).toBe(5)
			for _ = 1, 25 do
				ShopRules.addScore(store, Shop.SCORE_TOO_DEAR)
			end
			expect(ShopRules.stars(store)).toBeNear(3.5, 1e-9)
		end)
		it("doesn't swing a new store to 2★ on one unlucky shopper", function()
			local store = newStore()
			ShopRules.addScore(store, Shop.SCORE_TOO_DEAR)
			expect(ShopRules.stars(store)).toBeNear(2.9, 1e-9)
		end)
		it("adds Charm, up to 5★", function()
			local store = newStore()
			store.layout.f = { item = "Fountain", x = 1, y = 5, rot = 0 }
			store.layout.s = { item = "GoldenScarecrow", x = 3, y = 5, rot = 0 }
			expect(ShopRules.stars(store)).toBeNear(3.3, 1e-9)
			for _ = 1, 50 do
				ShopRules.addScore(store, Shop.SCORE_BOUGHT)
			end
			expect(ShopRules.stars(store)).toBe(5)
		end)
		it("brings shoppers every 20 s at Level 1 and 3★, 5% more often for each extra crop out", function()
			local store = newStore({ a = "ProduceCrate", b = "ProduceCrate" })
			slot(store, "a", 1).crop, slot(store, "a", 1).units = "Carrot", 5
			expect(ShopRules.interval(store)).toBeNear(20, 1e-9)
			slot(store, "b", 1).crop, slot(store, "b", 1).units = "Wheat", 5
			expect(ShopRules.interval(store)).toBeNear(20 / 1.05, 1e-9)
			store.level = 16
			expect(ShopRules.interval(store)).toBeNear(DemandModel.shopperInterval(16, 3) / 1.05 / 1.15, 1e-9)
		end)
	end)
end
