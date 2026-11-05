-- The leaderboards (docs/GameDesign.md §4.15; server LeaderboardService, the
-- boards in town: World/BoardArt). Pure functions over a save
-- (tests/leaders.test.luau):
--   Net Worth    coins + crops, seeds and crates (at their usual value) +
--                what the buildings, the field, the store's items and the
--                defences cost
--   Sheriff      arrests this week that count (CrimeRules.countsForBoard)
--   Most Wanted  the value of crops stolen this week (taken home)
--   Top Store    the Store Rating, for stores with 200 shoppers this week
-- Weeks start on Monday 00:00 UTC. A save keeps this week's numbers in
-- `weekly` = { week, arrests, stolen, shoppers }; a new week starts it over.
local BarnRules = require(script.Parent.BarnRules)
local Barn = require(script.Parent.Config.Barn)
local Crops = require(script.Parent.Config.Crops)
local Defences = require(script.Parent.Config.Defences)
local Land = require(script.Parent.Config.Land)
local Store = require(script.Parent.Config.Store)
local Warehouse = require(script.Parent.Config.Warehouse)
local WeatherRules = require(script.Parent.WeatherRules)

local LeaderRules = {}

LeaderRules.WEEK = 7 * 86400
LeaderRules.MONDAY = 4 * 86400 -- (1 January 1970 was a Thursday)
LeaderRules.TOP_STORE_SHOPPERS = 200
LeaderRules.SIZE = 10 -- rows on a board
LeaderRules.SPARE = 10 -- rows read past that, in case test players are stored there

LeaderRules.BOARDS = {
	{ id = "NetWorth", title = "RICHEST FARMS", what = "net worth", weekly = false },
	{ id = "TopStore", title = "TOP STORES", what = "★ this week (200+ shoppers)", weekly = true },
	{ id = "Sheriff", title = "SHERIFF OF THE WEEK", what = "arrests this week", weekly = true },
	{ id = "Wanted", title = "MOST WANTED", what = "coins of crops stolen this week", weekly = true },
}

-- Whether a player belongs on the boards. Studio's test players (Player1,
-- Player2 ...) have negative ids, and Studio writes to the same boards as the
-- live game: a test save can hold anything (one showed 89 million on RICHEST
-- FARMS, 2026-11-05).
function LeaderRules.counts(userId: number): boolean
	return userId > 0
end

function LeaderRules.week(t: number): number
	return (t - LeaderRules.MONDAY) // LeaderRules.WEEK
end

-- Seconds until the week turns over.
function LeaderRules.weekLeft(t: number): number
	return LeaderRules.WEEK - (t - LeaderRules.MONDAY) % LeaderRules.WEEK
end

local function fresh(t: number)
	return { week = LeaderRules.week(t), arrests = 0, stolen = 0, shoppers = 0 }
end

-- Adds to a stat this week (a new week starts every stat over).
function LeaderRules.bump(data, stat: string, amount: number, t: number)
	if not data.weekly or data.weekly.week ~= LeaderRules.week(t) then
		data.weekly = fresh(t)
	end
	data.weekly[stat] = (data.weekly[stat] or 0) + amount
end

-- A stat this week (0 if the save's numbers are from an older week).
function LeaderRules.thisWeek(data, stat: string, t: number): number
	local weekly = data.weekly
	if not weekly or weekly.week ~= LeaderRules.week(t) then
		return 0
	end
	return weekly[stat] or 0
end

local function crateWorth(crates): number
	local total = 0
	for _, crate in crates or {} do
		local crop = Crops.ById[crate.crop]
		if crop then
			local _, mutation = BarnRules.parse(crate.key or "")
			total += (crate.units or 0) * crop.value * WeatherRules.value(mutation)
		end
	end
	return total
end

-- Everything a farm is worth, in coins (whole).
function LeaderRules.netWorth(data): number
	local total = data.coins
	for key, units in data.inventory.crops do
		local cropId, mutation = BarnRules.parse(key)
		local crop = Crops.ById[cropId]
		if crop then
			total += units * crop.value * WeatherRules.value(mutation)
		end
	end
	for cropId, count in data.inventory.seeds do
		local crop = Crops.ById[cropId]
		if crop then
			total += count * crop.seed
		end
	end
	local warehouse = data.warehouse
	total += crateWorth(data.store.stockroom)
	for _, bed in warehouse.beds or {} do
		total += crateWorth(bed)
	end
	for _, entry in data.store.layout do
		for _, slot in entry.slots or {} do
			local crop = slot.crop and Crops.ById[slot.crop]
			if crop then
				total += (slot.units or 0) * crop.value
			end
		end
	end
	for i = 2, math.min(warehouse.level or 1, #Warehouse.LEVELS) do
		total += Warehouse.LEVELS[i].cost
	end
	for i = 2, math.min(data.store.level or 1, #Store.LEVELS) do
		total += Store.LEVELS[i].cost
	end
	for itemId, count in data.store.owned do
		local def = Store.ITEMS[itemId]
		if def then
			total += math.max(0, count - (data.store.gifts[itemId] or 0)) * (def.cost or 0) -- (the free starter kit isn't counted)
		end
	end
	for itemId, count in data.defences.owned do
		local def = Defences.ITEMS[itemId]
		if def then
			total += count * def.cost
		end
	end
	for i = 1, math.min(data.silo or 0, #Barn.SILO_COST) do
		total += Barn.SILO_COST[i]
	end
	for i = 2, math.min(data.land.fieldLevel or 1, #Land.FIELD_LEVELS) do
		total += Land.FIELD_LEVELS[i].cost
	end
	return math.floor(total)
end

-- A store's place on Top Store: its rating × 100 (a whole number, for an
-- OrderedDataStore), or nil until it's had 200 shoppers this week.
function LeaderRules.storeScore(data, stars: number, t: number): number?
	if LeaderRules.thisWeek(data, "shoppers", t) < LeaderRules.TOP_STORE_SHOPPERS then
		return nil
	end
	return math.floor(stars * 100 + 0.5)
end

-- How a board shows a value: "1,250,000" · "4.6★" · "12".
function LeaderRules.show(boardId: string, value: number, format: (number) -> string): string
	if boardId == "TopStore" then
		return string.format("%.1f★", value / 100)
	end
	return format(value)
end

return LeaderRules
