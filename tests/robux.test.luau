-- What Robux buys (Config/Monetization, Config/Cosmetics, shared/RobuxRules):
-- no power in the PvP, weathers that never replace a better one, the Growth
-- Boost's clock, looks owned and worn.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local Monetization = harness.load("Config/Monetization")
	local Cosmetics = harness.load("Config/Cosmetics")
	local Weather = harness.load("Config/Weather")
	local RobuxRules = harness.load("RobuxRules")

	local function newSave()
		return { weatherTokens = {}, boostLeft = 0, cosmetics = { owned = {} }, passes = {} }
	end

	describe("the catalogue (§7)", function()
		it("has the doc's passes and products at the doc's prices", function()
			expect(Monetization.PassesById.VIP.price).toBe(199)
			expect(Monetization.PassesById.BiggerBarn.price).toBe(99)
			expect(Monetization.ProductsById.RainDance.price).toBe(49)
			expect(Monetization.ProductsById.Thunderstorm.price).toBe(79)
			expect(Monetization.ProductsById.GoldenHour.price).toBe(99)
			expect(Monetization.ProductsById.HarvestMoon.price).toBe(149)
			expect(Monetization.ProductsById.GrowthBoost.price).toBe(79)
		end)
		it("gives only weather, growth or looks: never stealing, defence or levels", function()
			local ids = {}
			for _, product in Monetization.Products do
				expect(ids[product.id]).toBe(nil)
				ids[product.id] = true
				local grant = product.grant
				local kinds = 0
				for key in grant do
					expect(key == "weather" or key == "boostSeconds" or key == "cosmetic").toBe(true)
					kinds += 1
				end
				expect(kinds).toBe(1)
				if grant.weather then
					expect(Weather.TYPES[grant.weather] ~= nil).toBe(true)
				elseif grant.cosmetic then
					expect(Cosmetics.ById[grant.cosmetic] ~= nil).toBe(true)
				end
				expect(product.price >= 25 and product.price <= 249).toBe(true)
				expect(#product.blurb > 0).toBe(true)
			end
		end)
		it("sells every look with a price, and the VIP look only with the pass", function()
			for _, item in Cosmetics.LIST do
				expect(item.kind == "bat" or item.kind == "truck").toBe(true)
				if item.vip then
					expect(item.price).toBe(nil)
				else
					expect(Monetization.ProductsById[`Cosmetic_{item.id}`] ~= nil).toBe(true)
				end
			end
		end)
	end)

	describe("weather for the server", function()
		local T = 1_000_000
		local far = T + 3600
		it("starts over Clear and over a weaker weather", function()
			expect(RobuxRules.canStartWeather("Rain", { id = "Clear" }, T, far)).toBe(nil)
			expect(RobuxRules.canStartWeather("Thunderstorm", { id = "Rain" }, T, far)).toBe(nil)
			expect(RobuxRules.canStartWeather("Rain", { id = "Rain" }, T, far)).toBe(nil)
		end)
		it("never replaces a better weather", function()
			expect(RobuxRules.canStartWeather("Rain", { id = "GoldenHour" }, T, far)).toBe("BetterWeather")
			expect(RobuxRules.canStartWeather("Rain", { id = "FrostNight" }, T, far)).toBe("BetterWeather")
		end)
		it("one at a time: not while a bought (or dev) weather is on", function()
			expect(RobuxRules.canStartWeather("HarvestMoon", { id = "Rain", forced = true }, T, far)).toBe("WeatherBusy")
		end)
		it("never over or into the scheduled Harvest Moon", function()
			expect(RobuxRules.canStartWeather("HarvestMoon", { id = "HarvestMoon" }, T, far)).toBe("MoonNow")
			expect(RobuxRules.canStartWeather("Rain", { id = "Clear" }, T, T + Monetization.WEATHER_SECONDS - 1)).toBe("MoonSoon")
			expect(RobuxRules.canStartWeather("Rain", { id = "Clear" }, T, T + Monetization.WEATHER_SECONDS)).toBe(nil)
		end)
		it("keeps bought weathers in the barn until one is started", function()
			local data = newSave()
			RobuxRules.addToken(data, "Rain")
			RobuxRules.addToken(data, "Rain")
			expect(RobuxRules.takeToken(data, "Rain")).toBe(true)
			expect(data.weatherTokens.Rain).toBe(1)
			expect(RobuxRules.takeToken(data, "Rain")).toBe(true)
			expect(data.weatherTokens.Rain).toBe(nil)
			expect(RobuxRules.takeToken(data, "Rain")).toBe(false)
		end)
	end)

	describe("the Growth Boost", function()
		it("doubles growth while some is left, and only uses time played", function()
			local data = newSave()
			expect(RobuxRules.boostOver(data, 10)).toBe(1)
			RobuxRules.addBoost(data, Monetization.BOOST_SECONDS)
			expect(RobuxRules.boostOver(data, 10)).toBe(Monetization.BOOST)
			expect(data.boostLeft).toBe(Monetization.BOOST_SECONDS - 10)
		end)
		it("counts only the boosted part of a step when it runs out", function()
			local data = newSave()
			data.boostLeft = 5
			expect(RobuxRules.boostOver(data, 10)).toBe(1.5)
			expect(data.boostLeft).toBe(0)
			expect(RobuxRules.boostOver(data, 10)).toBe(1)
		end)
		it("buying more adds time", function()
			local data = newSave()
			RobuxRules.addBoost(data, 1800)
			RobuxRules.addBoost(data, 1800)
			expect(data.boostLeft).toBe(3600)
		end)
	end)

	describe("looks", function()
		it("wears only what's owned, and the VIP paint only with VIP", function()
			local data = newSave()
			expect(RobuxRules.equip(data, "bat", "GoldenBat", false)).toBe("NotOwned")
			expect(RobuxRules.unlock(data, "GoldenBat")).toBe(true)
			expect(RobuxRules.unlock(data, "GoldenBat")).toBe(false) -- (bought twice)
			expect(RobuxRules.equip(data, "bat", "GoldenBat", false)).toBe(nil)
			expect(RobuxRules.worn(data, "bat", false)).toBe("GoldenBat")
			expect(RobuxRules.equip(data, "truck", "VIPGold", false)).toBe("NotOwned")
			expect(RobuxRules.equip(data, "truck", "VIPGold", true)).toBe(nil)
			expect(RobuxRules.worn(data, "truck", true)).toBe("VIPGold")
			expect(RobuxRules.worn(data, "truck", false)).toBe(nil) -- (the pass gone: farm colours)
		end)
		it("refuses a look of the wrong kind, and takes nil for the plain one", function()
			local data = newSave()
			RobuxRules.unlock(data, "CherryPaint")
			expect(RobuxRules.equip(data, "bat", "CherryPaint", false)).toBe("BadRequest")
			expect(RobuxRules.equip(data, "hat", nil, false)).toBe("BadRequest")
			expect(RobuxRules.equip(data, "truck", "CherryPaint", false)).toBe(nil)
			expect(RobuxRules.equip(data, "truck", nil, false)).toBe(nil)
			expect(RobuxRules.worn(data, "truck", false)).toBe(nil)
		end)
	end)
end
