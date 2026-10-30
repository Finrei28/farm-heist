-- The global market price (shared/MarketPrice): the same on every server,
-- within its bounds, moved by the hourly events and by supply.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local MarketPrice = harness.load("MarketPrice")
	local Market = harness.load("Config/Market")
	local Crops = harness.load("Config/Crops")

	local T0 = 1_760_000_000

	describe("the wave", function()
		it("is the same for the same crop and time (every server agrees)", function()
			expect(MarketPrice.price("Pumpkin", T0)).toBe(MarketPrice.price("Pumpkin", T0))
			expect(MarketPrice.hash("Pumpkin#1")).toBe(MarketPrice.hash("Pumpkin#1"))
		end)
		it("stays within 0.8–1.2 and really moves over a few hours", function()
			for _, crop in Crops.List do
				local low, high = math.huge, -math.huge
				for minute = 0, 6 * 60 do
					local w = MarketPrice.wave(crop.id, T0 + minute * 60)
					low, high = math.min(low, w), math.max(high, w)
				end
				expect(low >= 0.8 - 1e-9).toBe(true)
				expect(high <= 1.2 + 1e-9).toBe(true)
				expect(high - low).toBeGreaterThan(0.2)
			end
		end)
		it("isn't in step for every crop (different phases)", function()
			local same = 0
			for _, crop in Crops.List do
				if math.abs(MarketPrice.wave(crop.id, T0) - MarketPrice.wave("Carrot", T0)) < 1e-9 then
					same += 1
				end
			end
			expect(same < 3).toBe(true)
		end)
	end)

	describe("hourly events", function()
		it("pick two different crops, never a Mythic", function()
			for hour = 1, 500 do
				local events = MarketPrice.events(hour)
				expect(events.hot ~= events.glut).toBe(true)
				expect(Crops.ById[events.hot].rarity ~= "Mythic").toBe(true)
				expect(Crops.ById[events.glut].rarity ~= "Mythic").toBe(true)
			end
		end)
		it("make the Hot Crop ×1.5 from :10 to :25, and the Glut ×0.75 from :40 to :55", function()
			local hourStart = T0 - T0 % 3600
			local events = MarketPrice.events(hourStart // 3600)
			expect(MarketPrice.eventMultiplier(events.hot, hourStart + 9 * 60)).toBe(1)
			expect(MarketPrice.eventMultiplier(events.hot, hourStart + 10 * 60)).toBe(1.5)
			expect(MarketPrice.eventMultiplier(events.hot, hourStart + 25 * 60)).toBe(1)
			expect(MarketPrice.eventMultiplier(events.glut, hourStart + 45 * 60)).toBe(0.75)
			local schedule = MarketPrice.schedule(hourStart + 5)
			expect(schedule.hot.crop).toBe(events.hot)
			expect(schedule.hot.startsAt).toBe(hourStart + Market.HOT.start)
		end)
	end)

	describe("supply", function()
		it("is 1 with nothing sold, −12% at the expected amount, never below 0.7", function()
			expect(MarketPrice.supply("Carrot", 0)).toBe(1)
			expect(MarketPrice.supply("Carrot", Market.EXPECTED.Common)).toBeNear(0.88, 1e-9)
			expect(MarketPrice.supply("Carrot", 1e9)).toBe(Market.SUPPLY_MIN)
		end)
		it("dumping carrots drops carrots, not pumpkins", function()
			local t = T0
			expect(MarketPrice.price("Carrot", t, MarketPrice.supply("Carrot", 8000))).toBeLessThan(MarketPrice.price("Carrot", t))
			expect(MarketPrice.price("Pumpkin", t, 1)).toBe(MarketPrice.price("Pumpkin", t))
		end)
	end)

	describe("the price", function()
		it("is a whole number of coins between 0.5× and 2× base, whatever happens", function()
			for _, crop in Crops.List do
				for step = 0, 200 do
					local t = T0 + step * 977
					for _, supply in { 0.7, 1 } do
						local price = MarketPrice.price(crop.id, t, supply)
						expect(price).toBe(math.floor(price))
						expect(price >= math.floor(crop.value * 0.5)).toBe(true)
						expect(price <= math.ceil(crop.value * 2)).toBe(true)
					end
				end
			end
		end)
	end)
end
