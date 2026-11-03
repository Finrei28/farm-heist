-- Day, night and the weather (shared/WeatherRules, §4.14): the same sky on
-- every server, the weather's shares and where it falls in the day, the
-- Harvest Moon, and the mutations a ripe crop left out can get.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local WeatherRules = harness.load("WeatherRules")
	local Weather = harness.load("Config/Weather")

	local DAY, NIGHT = Weather.DAY, Weather.NIGHT
	-- A day that starts at sunrise, well away from a Harvest Moon (02:00 UTC).
	local T = 1_762_135_200 + 2 * 3600 - (1_762_135_200 + 2 * 3600) % DAY + DAY

	local function moonFree(t: number): boolean
		return WeatherRules.weather(t).id ~= "HarvestMoon"
	end

	describe("the day", function()
		it("is 16 minutes of daylight, 06:00 to 18:00, then 8 of night", function()
			expect(WeatherRules.clock(T)).toBeNear(6, 1e-9)
			expect(WeatherRules.clock(T + 8 * 60)).toBeNear(12, 1e-9)
			expect(WeatherRules.clock(T + DAY - NIGHT)).toBeNear(18, 1e-9)
			expect(WeatherRules.clock(T + DAY - NIGHT / 2)).toBeNear(0, 1e-9)
			expect(WeatherRules.clock(T + DAY - 1)).toBeGreaterThan(5.9)
			expect(WeatherRules.isNight(T + DAY - NIGHT - 1)).toBe(false)
			expect(WeatherRules.isNight(T + DAY - NIGHT)).toBe(true)
			expect(WeatherRules.isNight(T + DAY)).toBe(false)
		end)
		it("says how long until night falls", function()
			expect(WeatherRules.untilNight(T)).toBe(DAY - NIGHT)
			expect(WeatherRules.untilNight(T + DAY - NIGHT + 5)).toBe(0)
		end)
		it("is the same on every server (worked out from the time)", function()
			for i = 0, 200 do
				local t = T + i * 97
				expect(WeatherRules.weather(t).id).toBe(WeatherRules.weather(t).id)
			end
		end)
	end)

	describe("the weather", function()
		local function shares(days: number)
			local seen, total = {}, 0
			for t = T, T + days * DAY - 1, 30 do
				if moonFree(t) then
					local id = WeatherRules.weather(t).id
					seen[id] = (seen[id] or 0) + 1
					total += 1
				end
			end
			for id, n in seen do
				seen[id] = n / total
			end
			return seen
		end
		it("is clear about 57% of the time, rain 20%, storms 8%, frost and golden hours 7% each", function()
			local s = shares(600)
			expect(s.Clear).toBeNear(0.58, 0.04)
			expect(s.Rain).toBeNear(0.20, 0.03)
			expect(s.Thunderstorm).toBeNear(0.08, 0.02)
			expect(s.FrostNight).toBeNear(0.07, 0.02)
			expect(s.GoldenHour).toBeNear(0.07, 0.02)
		end)
		it("brings Frost Nights only at night, and Golden Hour only in the last 3 minutes before sunset", function()
			for t = T, T + 300 * DAY, 60 do
				local id = WeatherRules.weather(t).id
				if id == "FrostNight" then
					expect(WeatherRules.isNight(t)).toBe(true)
				elseif id == "GoldenHour" then
					expect(WeatherRules.untilNight(t)).toBeGreaterThan(0)
					expect(WeatherRules.untilNight(t)).toBeLessThan(181)
				end
			end
		end)
		it("lasts its length and says when it ends", function()
			local checked = 0
			for t = T, T + 50 * DAY, 30 do
				local w = WeatherRules.weather(t)
				if moonFree(t) and w.id ~= "Clear" then
					expect(w.endsAt - w.startsAt).toBe(Weather.TYPES[w.id].length)
					expect(WeatherRules.weather(w.endsAt - 1).id).toBe(w.id)
					expect(WeatherRules.weather(w.endsAt).id ~= w.id or w.endsAt % Weather.SLOT == 0).toBe(true)
					checked += 1
				elseif w.id == "Clear" then
					expect(w.endsAt).toBeGreaterThan(t)
					expect(WeatherRules.weather(w.endsAt - 1).id).toBe("Clear")
				end
			end
			expect(checked).toBeGreaterThan(100)
		end)
		it("grows crops faster in rain and storms, slower in frost", function()
			expect(Weather.TYPES.Rain.growth).toBe(1.5)
			expect(Weather.TYPES.Thunderstorm.growth).toBe(1.5)
			expect(Weather.TYPES.FrostNight.growth).toBe(0.75)
			expect(Weather.TYPES.Clear.growth).toBe(1)
		end)
	end)

	describe("the Harvest Moon", function()
		local day = T - T % 86400
		it("comes at 01:00, 12:00 and 19:00 UTC for 6 minutes", function()
			for _, hour in { 1, 12, 19 } do
				local start = day + hour * 3600
				expect(WeatherRules.weather(start).id).toBe("HarvestMoon")
				expect(WeatherRules.weather(start + 359).id).toBe("HarvestMoon")
				expect(WeatherRules.weather(start + 360).id ~= "HarvestMoon").toBe(true)
				expect(WeatherRules.weather(start - 1).id ~= "HarvestMoon").toBe(true)
			end
		end)
		it("turns the sky to night whatever the time of day", function()
			local noon = day + 12 * 3600 + 60
			expect(WeatherRules.isNight(noon)).toBe(true)
			expect(WeatherRules.clock(noon)).toBe(0)
		end)
		it("doubles growth and makes steal holds 25% quicker (Heist Night)", function()
			local CrimeRules = harness.load("CrimeRules")
			local moon = day + 19 * 3600 + 10
			expect(WeatherRules.growth(moon)).toBe(2)
			expect(WeatherRules.isHeistNight(moon)).toBe(true)
			expect(WeatherRules.isHeistNight(T)).toBe(false)
			expect(CrimeRules.stealHold("Mythic", { harvestMoon = true })).toBe(5.25)
		end)
		it("is announced: the next one is known in advance", function()
			expect(WeatherRules.nextMoon(day + 11 * 3600)).toBe(day + 12 * 3600)
			expect(WeatherRules.nextMoon(day + 12 * 3600)).toBe(day + 19 * 3600)
			expect(WeatherRules.nextMoon(day + 20 * 3600)).toBe(day + 86400 + 3600)
		end)
		it("ends whatever weather was on when it starts", function()
			local w = WeatherRules.weather(day + 12 * 3600 - 30)
			expect(w.endsAt).toBeLessThan(day + 12 * 3600 + 1)
		end)
	end)

	describe("mutations on ripe crops left out", function()
		it("come from the weather first, then Golden and Rainbow in any weather", function()
			expect(WeatherRules.mutate("Rain", 0.01)).toBe("Wet")
			expect(WeatherRules.mutate("Rain", 0.032)).toBe("Golden")
			expect(WeatherRules.mutate("Rain", 0.0352)).toBe("Rainbow")
			expect(WeatherRules.mutate("Rain", 0.5)).toBe(nil)
			expect(WeatherRules.mutate("Clear", 0.004)).toBe("Golden")
			expect(WeatherRules.mutate("Clear", 0.0052)).toBe("Rainbow")
			expect(WeatherRules.mutate("Clear", 0.006)).toBe(nil)
		end)
		it("in Golden Hour are Golden ten times as often", function()
			expect(WeatherRules.mutate("GoldenHour", 0.049)).toBe("Golden")
			expect(WeatherRules.mutate("GoldenHour", 0.0502)).toBe("Rainbow")
		end)
		it("come about 1 time in 5 for a crop left out through a whole Rain or Harvest Moon", function()
			expect(WeatherRules.chanceOver("Rain", 240)).toBeNear(0.25, 0.05)
			expect(WeatherRules.chanceOver("HarvestMoon", 360)).toBeNear(0.25, 0.05)
		end)
		it("multiply the crop's value", function()
			expect(WeatherRules.value("Wet")).toBe(1.3)
			expect(WeatherRules.value("Rainbow")).toBe(8)
			expect(WeatherRules.value(nil)).toBe(1)
			for _, id in Weather.MUTATION_ORDER do
				expect(Weather.MUTATIONS[id].value).toBeGreaterThan(1)
			end
		end)
	end)

	describe("dev commands", function()
		it("/weather puts a weather on until it would end", function()
			harness.setStorageAttribute("WeatherForce", "Thunderstorm")
			harness.setStorageAttribute("WeatherForceUntil", T + 180)
			expect(WeatherRules.weather(T).id).toBe("Thunderstorm")
			expect(WeatherRules.weather(T + 180).id ~= "Thunderstorm" or not WeatherRules.weather(T + 180).forced).toBe(true)
			harness.setStorageAttribute("WeatherForce", "Clear") -- (Clear has no length of its own)
			harness.setStorageAttribute("WeatherForceUntil", T + 240)
			expect(WeatherRules.weather(T).id).toBe("Clear")
			harness.setStorageAttribute("WeatherForce", nil)
			harness.setStorageAttribute("WeatherForceUntil", nil)
		end)
		it("/time moves the clock", function()
			harness.setStorageAttribute("ClockShift", DAY - NIGHT)
			expect(WeatherRules.isNight(WeatherRules.now(T))).toBe(true)
			harness.setStorageAttribute("ClockShift", nil)
			expect(WeatherRules.isNight(WeatherRules.now(T))).toBe(false)
		end)
	end)
end
