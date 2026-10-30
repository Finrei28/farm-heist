-- How shoppers react to your prices (shared/DemandModel), against the
-- numbers in docs/GameDesign.md §4.8.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local DemandModel = harness.load("DemandModel")

	describe("the reference price", function()
		it("is half base, half today's market", function()
			expect(DemandModel.reference(610, 626)).toBe(618)
		end)
		it("makes the shop pay better than the truck when the market crashes, and worse when it spikes", function()
			local base = 100
			expect(DemandModel.reference(base, 60)).toBeGreaterThan(60)
			expect(DemandModel.reference(base, 150)).toBeLessThan(150)
			expect(DemandModel.reference(base, 100)).toBe(100)
		end)
	end)

	describe("buying", function()
		it("at the reference: about half buy at 1★ and 85% at 5★", function()
			expect(DemandModel.buyChance(100, 100, 1)).toBeNear(0.5, 0.01)
			expect(DemandModel.buyChance(100, 100, 5)).toBeNear(0.87, 0.02)
		end)
		it("at 1.2× the reference: about 18% at 1★ and 58% at 5★", function()
			expect(DemandModel.buyChance(120, 100, 1)).toBeNear(0.18, 0.01)
			expect(DemandModel.buyChance(120, 100, 5)).toBeNear(0.58, 0.01)
		end)
		it("drops as the price rises, and grade A lifts it", function()
			local last = 1
			for price = 50, 300, 10 do
				local chance = DemandModel.buyChance(price, 100, 3)
				expect(chance <= last).toBe(true)
				last = chance
			end
			expect(DemandModel.buyChance(120, 100, 3, true)).toBeGreaterThan(DemandModel.buyChance(120, 100, 3))
		end)
		it("matches the Pumpkin on the shop mockup (690 against 618 at 4★: 🙂, ~3 a minute)", function()
			local chance = DemandModel.buyChance(690, 618, 4)
			expect(chance).toBeNear(0.62, 0.01)
			expect(DemandModel.face(chance)).toBe("🙂")
		end)
	end)

	describe("shoppers", function()
		it("come every 20 s to a Farm Stand at 3★, and every 4 s to a Supermarket at 5★", function()
			expect(DemandModel.shopperInterval(0, 3)).toBeNear(20, 1e-9)
			expect(DemandModel.shopperInterval(3, 5)).toBeNear(4, 1e-9)
		end)
		it("come less often to a 1★ shop", function()
			expect(DemandModel.shopperInterval(1, 1)).toBeGreaterThan(DemandModel.shopperInterval(1, 3))
		end)
	end)

	describe("price limits", function()
		it("are 50–300% of the reference", function()
			local low, high = DemandModel.priceRange(618)
			expect(low).toBe(309)
			expect(high).toBe(1854)
		end)
	end)
end
