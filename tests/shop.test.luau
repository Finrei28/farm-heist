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

	-- A store with one Shop Counter and the displays given ({ id = itemId }).
	local function newStore(displays)
		local layout = { box = { item = "ShopCounter", x = 2, y = 2, rot = 3 } }
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
			store.stockroom = { crate("Carrot", 72, "B"), crate("Carrot", 18, "B"), crate("Carrot", 12, "A") }
			local moved, patches = ShopRules.fill(store, "s", market(30))
			expect(moved).toBe(102)
			expect(patches).toBeNear(17, 1e-9)
			expect(slot(store, "s", 1).crop).toBe("Carrot")
			expect(slot(store, "s", 1).units).toBe(90) -- (a Wooden Shelf slot: 15 patches' worth)
			expect(slot(store, "s", 1).a).toBe(12)
			expect(slot(store, "s", 2).units).toBe(12) -- (Auto: the second slot takes what's left)
			expect(#store.stockroom).toBe(0)
		end)
		it("holds a patches' worth of whatever's on a slot: 90 carrots or 15 pumpkins on a shelf", function()
			expect(ShopRules.slotRoom(Store.ITEMS.WoodenShelf, "Carrot")).toBe(90)
			expect(ShopRules.slotRoom(Store.ITEMS.WoodenShelf, "Pumpkin")).toBe(15)
			expect(ShopRules.slotRoom(Store.ITEMS.VelvetPedestal, "GoldenApple")).toBe(5)
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
			store.stockroom = { crate("Carrot", 72) }
			ShopRules.fill(store, "c", market(34))
			expect(store.prices.Carrot).toBe(32) -- ½ × 30 + ½ × 34
			store.prices.Carrot = 40
			ShopRules.empty(store, "c")
			ShopRules.fill(store, "c", market(34))
			expect(store.prices.Carrot).toBe(40)
		end)
		it("empties a display back into the stockroom, topping up part-full crates", function()
			local store = newStore({ s = "WoodenShelf" })
			store.stockroom = { crate("Carrot", 72), crate("Carrot", 72), crate("Carrot", 36, "A") }
			ShopRules.fill(store, "s", market(30))
			expect(#store.stockroom).toBe(0)
			expect(ShopRules.empty(store, "s")).toBe(180)
			expect(ShopRules.stockroomUnits(store).Carrot).toBe(180)
			expect(#store.stockroom).toBe(3) -- 36 A, then 144 B in two full crates
		end)
	end)

	describe("taking crops off a shelf", function()
		local function shelf()
			local store = newStore({ s = "WoodenShelf" })
			store.stockroom = { crate("Carrot", 72), crate("Carrot", 72), crate("Carrot", 36, "A") }
			ShopRules.fill(store, "s", market(30))
			return store
		end
		it("sends one slot back to your packed crates, grade A and all", function()
			local store = shelf()
			local slot = store.layout.s.slots[1]
			local units, a = slot.units, slot.a
			expect(ShopRules.takeOff(store, "s", 1)).toBe(units)
			expect(slot.units).toBe(0)
			expect(slot.a).toBe(0)
			expect(ShopRules.stockroomUnits(store).Carrot).toBe(units)
			local graded = 0
			for _, c in store.stockroom do
				if c.grade == "A" then
					graded += c.units
				end
			end
			expect(graded).toBe(a)
		end)
		it("loses nothing, slot by slot", function()
			local store = shelf()
			local function total()
				local out = ShopRules.onDisplay(store).Carrot
				return (if out then out.units else 0) + (ShopRules.stockroomUnits(store).Carrot or 0)
			end
			local before = total()
			ShopRules.takeOff(store, "s", 1)
			expect(total()).toBe(before)
			ShopRules.takeOff(store, "s", 2)
			expect(total()).toBe(before)
			expect(ShopRules.onDisplay(store).Carrot).toBe(nil)
		end)
		it("stays empty: no Stocker, no Fill all", function()
			local store = shelf()
			ShopRules.takeOff(store, "s", 1)
			expect(ShopRules.nextDisplay(store)).toBe(nil)
			expect(ShopRules.restockDisplays(store, market(30), 8)).toBe(0)
			expect(ShopRules.fillAll(store, market(30))).toBe(0)
			expect(store.layout.s.slots[1].units).toBe(0)
		end)
		it("fills again once you pick a crop", function()
			local store = shelf()
			ShopRules.takeOff(store, "s", 1)
			expect(ShopRules.setSlot(store, "s", 1, "Carrot")).toBe(nil)
			expect(ShopRules.fill(store, "s", market(30)) > 0).toBe(true)
			ShopRules.takeOff(store, "s", 1)
			expect(ShopRules.setSlot(store, "s", 1, nil)).toBe(nil) -- (Auto too)
			expect(ShopRules.fill(store, "s", market(30)) > 0).toBe(true)
		end)
		it("does nothing to an empty slot", function()
			local store = newStore({ s = "WoodenShelf" })
			expect(ShopRules.takeOff(store, "s", 1)).toBe(0)
			expect(store.layout.s.slots[1].off).toBe(nil)
			expect(ShopRules.takeOff(store, "s", 9)).toBe(0)
		end)
		it("doesn't count a slot left empty as room for the time-away sums", function()
			local store = shelf()
			local room = ShopRules.displayRoom(store)
			ShopRules.takeOff(store, "s", 1)
			expect(ShopRules.displayRoom(store) < room).toBe(true)
		end)
	end)

	describe("a Stocker", function()
		it("fills only as many patches' worth as their round allows, the emptiest display first", function()
			local store = newStore({ a = "WoodenShelf", b = "WoodenShelf" })
			store.stockroom = { crate("Carrot", 48), crate("Wheat", 24) }
			slot(store, "a", 1).crop, slot(store, "a", 1).units = "Carrot", 24
			local moved = ShopRules.restockDisplays(store, market(30), 5)
			expect(moved).toBeNear(5, 1e-9)
			local onA, onB = 0, 0
			for _, s in store.layout.a.slots do
				onA += s.units
			end
			for _, s in store.layout.b.slots do
				onB += s.units
			end
			expect(onA).toBe(24) -- (b was emptier)
			expect(onB).toBe(15) -- (5 patches of wheat: 3 sheaves each)
		end)
		it("goes to the emptiest display, or the next if another Stocker's on the way there", function()
			local store = newStore({ a = "WoodenShelf", b = "WoodenShelf" })
			store.stockroom = { crate("Carrot", 48) }
			slot(store, "a", 1).crop, slot(store, "a", 1).units = "Carrot", 24
			expect(ShopRules.nextDisplay(store)).toBe("b")
			expect(ShopRules.nextDisplay(store, { b = true })).toBe("a")
			expect(ShopRules.nextDisplay(store, { a = true, b = true })).toBe(nil)
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
			expect(ShopRules.setPrice(store, "Carrot", 1, 30)).toBe(15)
			expect(ShopRules.setPrice(store, "Carrot", 1000, 30)).toBe(90)
			expect(ShopRules.setPrice(store, "Carrot", 25.4, 30)).toBe(25)
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
			for _, case in { { item = "ProduceCrate", price = 30, stars = 3 }, { item = "ProduceCrate", price = 36, stars = 5 },
				{ item = "BulkBin", price = 30, stars = 3 }, { item = "TieredRack", price = 40, stars = 1 } } do
				local bought, visits = 0, 4000
				local present = Store.ITEMS[case.item].present
				for _ = 1, visits do
					local store = newStore({ d = case.item })
					slot(store, "d", 1).crop, slot(store, "d", 1).units = "Carrot", 12
					store.prices.Carrot = case.price
					for _ = 1, 10 do
						table.insert(store.rating.scores, case.stars)
					end
					if ShopRules.pick(store, "d", "Carrot", rng, market(30)) == "Bought" then
						bought += 1
					end
				end
				expect(bought / visits).toBeNear(DemandModel.buyChance(case.price, 30, case.stars, false, present), 0.03)
			end
		end)
		it("say how the price felt: under 1 when they buy (a bargain far under), over 1 when they turn it down", function()
			local rng = harness.Random.new(11)
			local cheap, dear = 0, 0
			for _ = 1, 400 do
				for _, price in { 6, 300 } do
					local store = newStore({ c = "ProduceCrate" })
					slot(store, "c", 1).crop, slot(store, "c", 1).units = "Carrot", 72
					store.prices.Carrot = price
					local result, _, felt = ShopRules.pick(store, "c", "Carrot", rng, market(30))
					if result == "Bought" then
						expect(felt <= 1).toBe(true)
						if felt < Shop.BARGAIN then
							cheap += 1
						end
					else
						expect(result).toBe("TooDear")
						expect(felt > 1).toBe(true)
						if felt > Shop.RIP_OFF then
							dear += 1
						end
					end
				end
			end
			expect(cheap > 300).toBe(true) -- (6 coins for a 30-coin carrot: nearly always a bargain)
			expect(dear > 300).toBe(true) -- (300: ten times over, a rip-off)
		end)
		it("have something to say for every case (plain lines and Kiwi slang), short enough for a bubble", function()
			for _, kind in { "bargain", "bought", "pricey", "tooDear", "ripOff", "soldOut", "queueLong", "nobody", "tooSlow", "thanks", "moved" } do
				expect(#Shop.LINES[kind] >= 3).toBe(true)
				for _, text in Shop.LINES[kind] do
					expect(#text > 0 and #text <= 26).toBe(true) -- (fits a bubble)
					expect(text ~= "Too dear!").toBe(true)
				end
			end
			for kind, mood in Shop.MOODS do
				expect(Shop.LINES[kind] ~= nil).toBe(true)
				expect(mood == "good" or mood == "bad").toBe(true)
			end
			expect(Shop.BARGAIN < Shop.PRICEY and Shop.PRICEY < 1 and Shop.RIP_OFF > 1).toBe(true)
		end)
		it("use every line: each price reaction comes up at prices players set, the rest from the store's events", function()
			-- the shelf: a sweep of prices (half to three times what shoppers
			-- expect), a Produce Crate at 3★ with carrots at 30
			local rng = harness.Random.new(21)
			local seen, atDefault = {}, {}
			local visits = 0
			for _, times in { 0.5, 0.8, 1, 1.2, 1.5, 2, 3 } do
				for _ = 1, 600 do
					local store = newStore({ c = "ProduceCrate" })
					slot(store, "c", 1).crop, slot(store, "c", 1).units = "Carrot", 72
					local ref = ShopRules.reference("Carrot", 30)
					store.prices.Carrot = math.floor(ref * times + 0.5)
					local result, _, felt = ShopRules.pick(store, "c", "Carrot", rng, market(30))
					local kind = ShopRules.reaction(result, felt, rng:NextNumber()) or "none"
					seen[kind] = (seen[kind] or 0) + 1
					if times == 1 then
						atDefault[kind] = (atDefault[kind] or 0) + 1
						visits += 1
					end
				end
			end
			local empty = newStore({ c = "ProduceCrate" })
			local result = ShopRules.pick(empty, "c", "Carrot", rng, market(30))
			seen[ShopRules.reaction(result, nil, 0) :: string] = 1
			for _, kind in { "bargain", "bought", "pricey", "tooDear", "ripOff", "soldOut" } do
				expect(seen[kind] ~= nil).toBe(true)
			end
			-- at the price a store starts with, the everyday ones come up often
			expect((atDefault.bargain or 0) / visits > 0.02).toBe(true)
			expect((atDefault.bought or 0) / visits > 0.1).toBe(true)
			expect((atDefault.pricey or 0) / visits > 0.05).toBe(true)
			expect((atDefault.tooDear or 0) / visits > 0.1).toBe(true)
			-- every other pool is said by the store when its moment comes
			-- (a full queue, an unserved or slow till, paying at a till, a
			-- re-decorate, a crop gone before they got to it)
			local source = require("@lune/fs").readFile("src/server/Services/StoreService.luau")
			for kind in Shop.LINES do
				local used = string.find(source, `line("{kind}")`, 1, true) ~= nil or string.find(source, `"{kind}"`, 1, true) ~= nil
					or table.find({ "bargain", "bought", "pricey", "tooDear", "ripOff" }, kind) ~= nil -- (ShopRules.reaction)
				if not used then
					error(`nothing says the "{kind}" lines`)
				end
			end
		end)
		it("take 1–4 patches' worth (6–24 carrots, 15 on average), grade A first at 15% more", function()
			local rng = harness.Random.new(3)
			local units, buyers = 0, 0
			for _ = 1, 2000 do
				local store = newStore({ c = "ProduceCrate" })
				slot(store, "c", 1).crop, slot(store, "c", 1).units, slot(store, "c", 1).a = "Carrot", 72, 72
				store.prices.Carrot = 10 -- cheap: everyone buys
				local result, line = ShopRules.pick(store, "c", "Carrot", rng, market(30))
				expect(result).toBe("Bought")
				expect(line.units >= 6 and line.units <= 24).toBe(true)
				expect(line.coins).toBe(line.units * 12) -- 10 × 1.15, rounded
				expect(slot(store, "c", 1).a).toBe(72 - line.units)
				units += line.units
				buyers += 1
			end
			expect(units / buyers).toBeNear(Shop.UNITS_PER_SHOPPER * 6, 0.5)
		end)
		it("take 1–4 pumpkins", function()
			local rng = harness.Random.new(8)
			for _ = 1, 200 do
				local store = newStore({ s = "WoodenShelf" })
				slot(store, "s", 1).crop, slot(store, "s", 1).units = "Pumpkin", 15
				store.prices.Pumpkin = 3_050
				local _, line = ShopRules.pick(store, "s", "Pumpkin", rng, market(6_100))
				expect(line.units >= 1 and line.units <= 4).toBe(true)
			end
		end)
		it("find a display sold out, and never take more than is on it", function()
			local store = newStore({ c = "ProduceCrate" })
			slot(store, "c", 1).crop, slot(store, "c", 1).units = "Carrot", 1
			store.prices.Carrot = 15
			local result, line = ShopRules.pick(store, "c", "Carrot", harness.Random.new(5), market(30))
			expect(result).toBe("Bought")
			expect(line.units).toBe(1)
			expect(slot(store, "c", 1).crop).toBe(nil)
			expect(ShopRules.isOpen(store)).toBe(false)
			expect((ShopRules.pick(store, "c", "Carrot", harness.Random.new(5), market(30)))).toBe("SoldOut")
		end)
		it("put their basket back on the display when they give up in the queue", function()
			local store = newStore({ c = "ProduceCrate" })
			slot(store, "c", 1).crop, slot(store, "c", 1).units, slot(store, "c", 1).a = "Carrot", 60, 2
			store.prices.Carrot = 16
			local _, line = ShopRules.pick(store, "c", "Carrot", harness.Random.new(9), market(30))
			ShopRules.putBack(store, line)
			expect(slot(store, "c", 1).units).toBe(60)
			expect(slot(store, "c", 1).a).toBe(2)
			-- ... or to the stockroom if the display's gone
			_, line = ShopRules.pick(store, "c", "Carrot", harness.Random.new(9), market(30))
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
