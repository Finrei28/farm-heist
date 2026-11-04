-- What Robux buys, as rules (docs/GameDesign.md §7; Config/Monetization,
-- Config/Cosmetics): when a bought weather can start, the Growth Boost's
-- clock, which looks a save owns and wears. The server's
-- MonetizationService acts on them; the client's Robux window shows them.
-- tests/robux.test.luau.
--
-- Save fields: weatherTokens = { [weatherId] = n } (bought, not started
-- yet), boostLeft (seconds of Growth Boost still to play), cosmetics =
-- { owned = { [id] = true }, bat = id?, truck = id? }, passes = { [id] = true }.
local Cosmetics = require(script.Parent.Config.Cosmetics)
local Monetization = require(script.Parent.Config.Monetization)

local RobuxRules = {}

-- How good a weather is for your crops (what its mutation is worth on
-- average, and the Harvest Moon's growth): a bought weather never replaces
-- a better one.
RobuxRules.WEATHER_RANK = { Clear = 0, Rain = 1, FrostNight = 2, Thunderstorm = 2, GoldenHour = 3, HarvestMoon = 4 }

-- Whether a bought weather can start now, over `current`
-- (WeatherRules.weather(t)): nil, or why not:
--   WeatherBusy    a bought weather (or a dev one) is on: one at a time
--   MoonNow        the scheduled Harvest Moon is on
--   MoonSoon       the scheduled Harvest Moon starts before this would end
--   BetterWeather  the weather on now is better than this one
function RobuxRules.canStartWeather(weatherId: string, current, t: number, nextMoon: number): string?
	if current.forced then
		return "WeatherBusy"
	elseif current.id == "HarvestMoon" then
		return "MoonNow"
	elseif nextMoon - t < Monetization.WEATHER_SECONDS then
		return "MoonSoon"
	elseif (RobuxRules.WEATHER_RANK[current.id] or 0) > (RobuxRules.WEATHER_RANK[weatherId] or 0) then
		return "BetterWeather"
	end
	return nil
end

-- Bought weathers waiting to be started (the barn keeps them).
function RobuxRules.addToken(data, weatherId: string)
	data.weatherTokens = data.weatherTokens or {}
	data.weatherTokens[weatherId] = (data.weatherTokens[weatherId] or 0) + 1
end

function RobuxRules.takeToken(data, weatherId: string): boolean
	local tokens = data.weatherTokens
	if not tokens or (tokens[weatherId] or 0) < 1 then
		return false
	end
	tokens[weatherId] -= 1
	if tokens[weatherId] == 0 then
		tokens[weatherId] = nil
	end
	return true
end

-- The Growth Boost: × growth while some is left; it ticks only while you
-- play. Returns the speed for the `seconds` just played and uses them up
-- (a boost running out part-way counts that part).
function RobuxRules.boostOver(data, seconds: number): number
	local left = data.boostLeft or 0
	if left <= 0 or seconds <= 0 then
		return 1
	end
	local used = math.min(left, seconds)
	data.boostLeft = left - used
	return 1 + (Monetization.BOOST - 1) * used / seconds
end

function RobuxRules.addBoost(data, seconds: number)
	data.boostLeft = (data.boostLeft or 0) + seconds
end

-- Looks: whether a save has one (VIP ones come with the pass).
function RobuxRules.owns(data, itemId: string, vip: boolean): boolean
	local item = Cosmetics.ById[itemId]
	if not item then
		return false
	end
	if item.vip then
		return vip
	end
	return data.cosmetics ~= nil and data.cosmetics.owned[itemId] == true
end

-- Wear a look (nil: the plain one). Returns nil, or why not.
function RobuxRules.equip(data, kind: string, itemId: string?, vip: boolean): string?
	if kind ~= "bat" and kind ~= "truck" then
		return "BadRequest"
	end
	if itemId then
		local item = Cosmetics.ById[itemId]
		if not item or item.kind ~= kind then
			return "BadRequest"
		elseif not RobuxRules.owns(data, itemId, vip) then
			return "NotOwned"
		end
	end
	data.cosmetics[kind] = itemId
	return nil
end

-- What's worn, checked (a VIP look after the pass has gone is dropped).
function RobuxRules.worn(data, kind: string, vip: boolean): string?
	local id = data.cosmetics and data.cosmetics[kind]
	if id and RobuxRules.owns(data, id, vip) then
		return id
	end
	return nil
end

-- A look bought again (two purchase prompts at once): the Robux are spent,
-- so its price's worth of Growth Boost instead. Returns whether it was new.
function RobuxRules.unlock(data, itemId: string): boolean
	data.cosmetics = data.cosmetics or { owned = {} }
	if data.cosmetics.owned[itemId] then
		return false
	end
	data.cosmetics.owned[itemId] = true
	return true
end

return RobuxRules
