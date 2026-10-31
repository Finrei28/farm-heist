-- The Farm Stand's shelves, prices, shoppers and rating (shared/ShopRules),
-- against docs/GameDesign.md §4.8 and shared/DemandModel.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local ShopRules = harness.load("ShopRules")
	local DemandModel = harness.load("DemandModel")
	local Shop = harness.load("Config/Shop")

	local function newShop()
		return { tier = 0, shelves = {}, stockroom = {}, prices = {}, rating = { scores = {} } }
	end
	local function crate(crop, units, grade)
		return { crop = crop, key = `{crop}||`, units = units, grade = grade or "B" }
	end
	local function market(price)
		return function()
			return price
		end
	end

	describe("stocking", function()
		it("puts the crops with most waiting on the stand's 2 shelves, 20 units each", function()
			local shop = newShop()
			shop.stockroom = { crate("Carrot", 12), crate("Carrot", 12), crate("Pumpkin", 6), crate("Wheat", 3) }
			local moved = ShopRules.stock(shop, market(20))
			expect(moved).toBe(26)
			expect(shop.shelves["1"].crop).toBe("Carrot")
			expect(shop.shelves["1"].units).toBe(20)
			expect(shop.shelves["2"].crop).toBe("Pumpkin")
			expect(ShopRules.stockroomUnits(shop).Carrot).toBe(4)
			expect(ShopRules.stockroomUnits(shop).Wheat).toBe(3)
		end)
		it("fills both baskets when there's only one crop (a new farm's Carrots)", function()
			local shop = newShop()
			shop.stockroom = { crate("Carrot", 12), crate("Carrot", 12), crate("Carrot", 12) }
			expect(ShopRules.stock(shop, market(18))).toBe(36)
			expect(shop.shelves["1"].crop).toBe("Carrot")
			expect(shop.shelves["1"].units).toBe(20)
			expect(shop.shelves["2"].crop).toBe("Carrot")
			expect(shop.shelves["2"].units).toBe(16)
			expect(ShopRules.shelvesOf(shop, "Carrot")).toBe(2)
		end)
		it("tops up a shelf with its own crop, grade A first", function()
			local shop = newShop()
			shop.shelves["1"] = { crop = "Carrot", units = 15, a = 0 }
			shop.stockroom = { crate("Carrot", 12, "B"), crate("Carrot", 3, "A") }
			ShopRules.stock(shop, market(20))
			expect(shop.shelves["1"].units).toBe(20)
			expect(shop.shelves["1"].a).toBe(3)
			expect(shop.shelves["2"].units).toBe(10) -- (the rest fills the empty basket)
			expect(ShopRules.stockroomUnits(shop).Carrot).toBe(nil)
		end)
		it("prices a crop going out for the first time at the reference, and keeps your price after", function()
			local shop = newShop()
			shop.stockroom = { crate("Carrot", 12) }
			ShopRules.stock(shop, market(22))
			expect(shop.prices.Carrot).toBe(20) -- ½ × 18 + ½ × 22
			shop.prices.Carrot = 30
			shop.stockroom = { crate("Carrot", 12) }
			ShopRules.stock(shop, market(22))
			expect(shop.prices.Carrot).toBe(30)
		end)
		it("takes a shelf down into the stockroom without losing grade A", function()
			local shop = newShop()
			shop.shelves["1"] = { crop = "Carrot", units = 10, a = 4 }
			expect(ShopRules.takeDown(shop, "1")).toBe(10)
			expect(shop.shelves["1"]).toBe(nil)
			expect(ShopRules.stockroomUnits(shop).Carrot).toBe(10)
			ShopRules.stock(shop, market(18))
			expect(shop.shelves["1"].a).toBe(4)
		end)
	end)

	describe("prices", function()
		it("stay within 50–300% of the reference", function()
			local shop = newShop()
			expect(ShopRules.setPrice(shop, "Carrot", 1, 18)).toBe(9)
			expect(ShopRules.setPrice(shop, "Carrot", 1000, 18)).toBe(54)
			expect(ShopRules.setPrice(shop, "Carrot", 25.4, 18)).toBe(25)
		end)
	end)

	describe("shoppers", function()
		it("don't come to a stand with nothing on its shelves", function()
			local shop = newShop()
			expect(ShopRules.isOpen(shop)).toBe(false)
			expect(ShopRules.visit(shop, harness.Random.new(1), market(18))).toBe(nil)
			expect(#shop.rating.scores).toBe(0)
		end)
		it("buy as often as DemandModel says (the window's estimate, play-test C3)", function()
			local rng = harness.Random.new(7)
			for _, case in { { price = 18, stars = 3 }, { price = 22, stars = 3 }, { price = 18, stars = 5 }, { price = 26, stars = 1 } } do
				local bought, visits = 0, 4000
				for _ = 1, visits do
					local shop = newShop()
					shop.shelves["1"] = { crop = "Carrot", units = 20, a = 0 }
					shop.prices.Carrot = case.price
					for _ = 1, 10 do
						table.insert(shop.rating.scores, case.stars)
					end
					if ShopRules.visit(shop, rng, market(18)).units > 0 then
						bought += 1
					end
				end
				expect(bought / visits).toBeNear(DemandModel.buyChance(case.price, 18, case.stars), 0.03)
			end
		end)
		it("buy 1–4 units (2.5 on average), grade A first at 15% more", function()
			local rng = harness.Random.new(3)
			local units, buyers = 0, 0
			for _ = 1, 2000 do
				local shop = newShop()
				shop.shelves["1"] = { crop = "Carrot", units = 20, a = 20 }
				shop.prices.Carrot = 6 -- cheap: everyone buys
				local visit = ShopRules.visit(shop, rng, market(18))
				expect(visit.units >= 1 and visit.units <= 4).toBe(true)
				expect(visit.coins).toBe(visit.units * 7) -- 6 × 1.15, rounded
				expect(shop.shelves["1"].a).toBe(20 - visit.units)
				units += visit.units
				buyers += 1
			end
			expect(units / buyers).toBeNear(Shop.UNITS_PER_SHOPPER, 0.1)
		end)
		it("empty a shelf and never sell more than is on it", function()
			local shop = newShop()
			shop.shelves["1"] = { crop = "Carrot", units = 1, a = 0 }
			shop.prices.Carrot = 9
			local visit = ShopRules.visit(shop, harness.Random.new(5), market(18))
			expect(visit.units).toBe(1)
			expect(shop.shelves["1"]).toBe(nil)
			expect(ShopRules.isOpen(shop)).toBe(false)
		end)
	end)

	describe("the rating", function()
		it("starts at 3★ and averages the last 50 shoppers", function()
			local shop = newShop()
			expect(ShopRules.stars(shop)).toBe(3)
			for _ = 1, 60 do
				ShopRules.addScore(shop, Shop.SCORE_BOUGHT)
			end
			expect(#shop.rating.scores).toBe(Shop.RATING_WINDOW)
			expect(ShopRules.stars(shop)).toBe(5)
			for _ = 1, 25 do
				ShopRules.addScore(shop, Shop.SCORE_TOO_DEAR)
			end
			expect(ShopRules.stars(shop)).toBeNear(3.5, 1e-9)
		end)
		it("doesn't swing a new stand to 2★ on one unlucky shopper", function()
			local shop = newShop()
			ShopRules.addScore(shop, Shop.SCORE_TOO_DEAR)
			expect(ShopRules.stars(shop)).toBeNear(2.9, 1e-9)
			for _ = 2, Shop.RATING_SETTLE do
				ShopRules.addScore(shop, Shop.SCORE_BOUGHT)
			end
			expect(ShopRules.stars(shop)).toBeNear((2 + 5 * (Shop.RATING_SETTLE - 1)) / Shop.RATING_SETTLE, 1e-9)
		end)
		it("settles above 4★ at the reference price, and near 3★ at 1.2× it", function()
			local function settle(price)
				local rng = harness.Random.new(11)
				local shop = newShop()
				shop.prices.Carrot = price
				for _ = 1, 400 do
					shop.shelves["1"] = { crop = "Carrot", units = 20, a = 0 }
					ShopRules.visit(shop, rng, market(18))
				end
				return ShopRules.stars(shop)
			end
			expect(settle(18)).toBeGreaterThan(4)
			expect(settle(22)).toBeLessThan(3.6)
		end)
		it("brings shoppers every 20 s at 3★ to the Farm Stand, more often when rated higher", function()
			local shop = newShop()
			expect(ShopRules.interval(shop)).toBe(20)
			for _ = 1, 50 do
				ShopRules.addScore(shop, 5)
			end
			expect(ShopRules.interval(shop)).toBeLessThan(20)
		end)
	end)
end
