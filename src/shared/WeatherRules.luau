-- Day, night and the weather (docs/GameDesign.md §4.14). Worked out from the
-- time, so every server and every player has the same sky and the client
-- shows it without asking (like SeedStock). tests/weather.test.luau.
--
-- A Cloverdale day is Weather.DAY seconds on the clock: 16 minutes of
-- daylight (06:00 to 18:00 on the sky's clock), then 8 of night. The
-- weather can change every 4-minute slot, rolled from the slot's number.
-- The Harvest Moon comes at fixed hours (UTC) and turns the sky to night
-- for its 6 minutes, whatever the time of day.
--
-- Dev: ReplicatedStorage attribute ClockShift moves the clock by that many
-- seconds (`/time`); WeatherForce = a weather id puts it on until
-- WeatherForceUntil (`/weather`).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weather = require(script.Parent.Config.Weather)

local WeatherRules = {}

local TYPES = Weather.TYPES
local DAYLIGHT = Weather.DAY - Weather.NIGHT
local SLOTS = Weather.DAY // Weather.SLOT
local DUSK_SLOT = DAYLIGHT // Weather.SLOT - 1 -- (the last daylight slot)

-- The time the sky and the weather go by: server time, plus the dev shift.
function WeatherRules.now(t: number?): number
	return (t or workspace:GetServerTimeNow()) + (ReplicatedStorage:GetAttribute("ClockShift") or 0)
end

-- Seconds into the Cloverdale day (0 = 06:00, sunrise).
local function phase(t: number): number
	return t % Weather.DAY
end

-- The Harvest Moon on at t: its start, or nil.
local function moonAt(t: number): number?
	local length = TYPES.HarvestMoon.length
	local day = t - t % 86400
	for _, hour in Weather.HARVEST_MOON.hours do
		for _, start in { day + hour * 3600, day - 86400 + hour * 3600 } do
			if t >= start and t < start + length then
				return start
			end
		end
	end
	return nil
end

-- When the next Harvest Moon starts (after t; the one on now counts as
-- started, not next).
function WeatherRules.nextMoon(t: number): number
	local day = t - t % 86400
	local best = math.huge
	for offset = 0, 1 do
		for _, hour in Weather.HARVEST_MOON.hours do
			local start = day + offset * 86400 + hour * 3600
			if start > t and start < best then
				best = start
			end
		end
	end
	return best
end

-- The scheduled weather in 4-minute slot `slot`: its id and how many
-- seconds into the slot it starts and ends (the rest of the slot is Clear).
local function slotWeather(slot: number): (string, number, number)
	local rng = Random.new(slot * 15_485_863 + 7)
	local roll = rng:NextNumber()
	local within = slot % SLOTS
	local night = within > DUSK_SLOT
	local function take(id: string): boolean
		local odds = TYPES[id].odds
		if roll < odds then
			return true
		end
		roll -= odds
		return false
	end
	if night and take("FrostNight") then
		return "FrostNight", 0, TYPES.FrostNight.length
	elseif within == DUSK_SLOT and take("GoldenHour") then
		-- the last 3 minutes of daylight, ending at sunset
		return "GoldenHour", Weather.SLOT - TYPES.GoldenHour.length, Weather.SLOT
	elseif take("Rain") then
		return "Rain", 0, TYPES.Rain.length
	elseif take("Thunderstorm") then
		return "Thunderstorm", 0, TYPES.Thunderstorm.length
	end
	return "Clear", 0, Weather.SLOT
end

-- The weather at (shifted) time t: { id, startsAt, endsAt }, where Clear
-- runs to the next change.
function WeatherRules.weather(t: number)
	local forced = ReplicatedStorage:GetAttribute("WeatherForce")
	local forcedUntil = ReplicatedStorage:GetAttribute("WeatherForceUntil") or 0
	if forced and TYPES[forced] and t < forcedUntil then
		return { id = forced, startsAt = forcedUntil - (TYPES[forced].length or Weather.SLOT), endsAt = forcedUntil, forced = true }
	end
	local moon = moonAt(t)
	if moon then
		return { id = "HarvestMoon", startsAt = moon, endsAt = moon + TYPES.HarvestMoon.length }
	end
	local slot = t // Weather.SLOT
	local slotStart = slot * Weather.SLOT
	local id, from, to = slotWeather(slot)
	local into = t - slotStart
	if id ~= "Clear" and into >= from and into < to then
		return { id = id, startsAt = slotStart + from, endsAt = math.min(slotStart + to, WeatherRules.nextMoon(t)) }
	end
	-- Clear: from the last change to the next one (a few slots on at most)
	local endsAt = slotStart + (if into < from then from else Weather.SLOT)
	if into >= from then
		for ahead = 1, SLOTS do
			local nextId, nextFrom = slotWeather(slot + ahead)
			if nextId ~= "Clear" then
				endsAt = (slot + ahead) * Weather.SLOT + nextFrom
				break
			end
			endsAt = (slot + ahead + 1) * Weather.SLOT
		end
	end
	return { id = "Clear", startsAt = slotStart, endsAt = math.min(endsAt, WeatherRules.nextMoon(t)) }
end

-- The sky's clock, 0–24: 06:00 at sunrise, 18:00 at sunset, through the
-- night to 06:00. The Harvest Moon holds it at midnight.
function WeatherRules.clock(t: number): number
	if WeatherRules.weather(t).id == "HarvestMoon" then
		return 0
	end
	local p = phase(t)
	if p < DAYLIGHT then
		return 6 + 12 * p / DAYLIGHT
	end
	return (18 + 12 * (p - DAYLIGHT) / Weather.NIGHT) % 24
end

-- Night: the last 8 minutes of each day, and the whole Harvest Moon. Name
-- tags shrink to 20 studs (Floodlights cancel that on your farm).
function WeatherRules.isNight(t: number): boolean
	return phase(t) >= DAYLIGHT or WeatherRules.weather(t).id == "HarvestMoon"
end

-- Seconds until night falls (0 at night).
function WeatherRules.untilNight(t: number): number
	if WeatherRules.isNight(t) then
		return 0
	end
	return DAYLIGHT - phase(t)
end

-- × crop growth (online) at t.
function WeatherRules.growth(t: number): number
	return TYPES[WeatherRules.weather(t).id].growth
end

-- Heist Night: steal holds are quicker under the Harvest Moon
-- (CrimeRules.stealHold's harvestMoon).
function WeatherRules.isHeistNight(t: number): boolean
	return WeatherRules.weather(t).id == "HarvestMoon"
end

-- One mutation roll for a ripe crop in `weatherId`: roll is 0–1. The
-- weather's own mutation first, then the any-weather ones (Golden Hour's
-- Golden replaces the usual Golden). nil: nothing this time.
function WeatherRules.mutate(weatherId: string, roll: number): string?
	local weather = TYPES[weatherId]
	if weather.mutation then
		if roll < weather.chance then
			return weather.mutation
		end
		roll -= weather.chance
	end
	for _, any in Weather.ANY do
		if any.mutation ~= weather.mutation then
			if roll < any.chance then
				return any.mutation
			end
			roll -= any.chance
		end
	end
	return nil
end

-- × value for a crop with this mutation (nil: 1).
function WeatherRules.value(mutation: string?): number
	local entry = mutation and Weather.MUTATIONS[mutation]
	return if entry then entry.value else 1
end

-- The chance a crop left out through `seconds` of `weatherId` mutates.
function WeatherRules.chanceOver(weatherId: string, seconds: number): number
	local each = 0
	local weather = TYPES[weatherId]
	if weather.mutation then
		each += weather.chance
	end
	for _, any in Weather.ANY do
		if any.mutation ~= weather.mutation then
			each += any.chance
		end
	end
	return 1 - (1 - each) ^ (seconds // Weather.ROLL)
end

return WeatherRules
