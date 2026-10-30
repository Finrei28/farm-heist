-- The global market price for truck sales (docs/GameDesign.md §4.7):
--   price(crop, t) = base × wave(t) × event(t) × supply, clamped to 0.5–2 × base
-- The wave and the hourly Hot Crop / Glut are worked out from the time and
-- the crop id alone, so every server agrees without messaging. supply comes
-- from MarketService (MemoryStore counters of units sold everywhere in the
-- last window, MarketPrice.supply); 1 when unknown.
-- tests/market.test.luau.
local Config = require(script.Parent.Config.Market)
local Crops = require(script.Parent.Config.Crops)

local MarketPrice = {}

-- FNV-1a, 32-bit (the multiply split so it stays exact in a double).
local function hash(text: string): number
	local h = 2166136261
	for i = 1, #text do
		h = bit32.bxor(h, string.byte(text, i))
		h = (bit32.lshift(h, 24) + h * 403) % 4294967296 -- h × 16777619 mod 2^32
	end
	return h
end
MarketPrice.hash = hash

-- The slow ups and downs: 1 ± the waves' amplitudes.
function MarketPrice.wave(cropId: string, t: number): number
	local value = 1
	for index, wave in Config.WAVES do
		local phase = (hash(`{cropId}#{index}`) % 100000) / 100000 * 2 * math.pi
		value += wave.amp * math.sin(2 * math.pi * t / wave.period + phase)
	end
	return value
end

-- The Hot Crop and the Glut for an hour (by hour index): two different
-- crops, never Mythics.
function MarketPrice.events(hourIndex: number): { hot: string, glut: string }
	local candidates = {}
	for _, crop in Crops.List do
		if crop.rarity ~= "Mythic" then
			table.insert(candidates, crop.id)
		end
	end
	local rng = Random.new(hourIndex * 7919 + 17)
	local hot = candidates[rng:NextInteger(1, #candidates)]
	local glut = hot
	while glut == hot do
		glut = candidates[rng:NextInteger(1, #candidates)]
	end
	return { hot = hot, glut = glut }
end

-- What the hour's events do to this crop right now (1 if nothing).
function MarketPrice.eventMultiplier(cropId: string, t: number): number
	local events = MarketPrice.events(t // 3600)
	local intoHour = t % 3600
	local function during(window)
		return intoHour >= window.start and intoHour < window.start + window.length
	end
	if cropId == events.hot and during(Config.HOT) then
		return Config.HOT.mult
	elseif cropId == events.glut and during(Config.GLUT) then
		return Config.GLUT.mult
	end
	return 1
end

-- This hour's events with their times, for the Exchange board and the
-- "Hot Crop in 2:00" announcement.
function MarketPrice.schedule(t: number)
	local hourStart = t - t % 3600
	local events = MarketPrice.events(t // 3600)
	return {
		hot = { crop = events.hot, startsAt = hourStart + Config.HOT.start, endsAt = hourStart + Config.HOT.start + Config.HOT.length },
		glut = { crop = events.glut, startsAt = hourStart + Config.GLUT.start, endsAt = hourStart + Config.GLUT.start + Config.GLUT.length },
	}
end

-- Supply pressure from units sold to the market in the last window, by
-- every server: 1 at nothing sold, −12% at `expected`, more beyond, never
-- below SUPPLY_MIN.
function MarketPrice.supply(cropId: string, sold: number): number
	local crop = Crops.ById[cropId]
	local expected = Config.EXPECTED[crop.rarity]
	local value = 1 - Config.SUPPLY_SLOPE * math.log(1 + math.max(0, sold) / expected, 2)
	return math.clamp(value, Config.SUPPLY_MIN, 1)
end

-- The price as a share of base value (clamped).
function MarketPrice.multiplier(cropId: string, t: number, supply: number?): number
	local raw = MarketPrice.wave(cropId, t) * MarketPrice.eventMultiplier(cropId, t) * (supply or 1)
	return math.clamp(raw, Config.CLAMP_MIN, Config.CLAMP_MAX)
end

-- Coins for one standard unit (grade B, no mutation) sold by truck now.
function MarketPrice.price(cropId: string, t: number, supply: number?): number
	local crop = Crops.ById[cropId]
	return math.floor(crop.value * MarketPrice.multiplier(cropId, t, supply) + 0.5)
end

return MarketPrice
