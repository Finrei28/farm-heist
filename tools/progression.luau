-- Progression sim (from the project folder):
--   lune run tools/progression            all three player profiles
--   lune run tools/progression daily      just one
--   lune run tools/progression daily power=2.7   try another XP curve (Config/Progression XP_POWER)
-- Plays a farm minute by minute with the game's real rules (growth, Barley's
-- restocks, Land Permits, market prices, workers, the offline pipeline) and a
-- sensible player: harvest what's ripe, sell it by truck, replant the best
-- crop they can buy, clear land as soon as a permit and the fee allow, build
-- the warehouse and hire workers when they can afford to. Prints when each
-- milestone comes, then checks the design doc's pacing targets (§4.1b) and
-- that income beats wages every day. Exits with code 1 if a target is missed.
--
-- Left out (so real players are a little slower or faster): raids, the shop
-- (its extra margin roughly pays for itself), auctions (the main source of
-- Mythic seeds), weather and mutations, quests and the login streak.
local process = require("@lune/process")

local Harness = require("../tests/lib/harness")
Harness.reset()
Harness.fresh()

local Crops = Harness.load("Config/Crops")
local Rarities = Harness.load("Config/Rarities")
local Settings = Harness.load("Config/Settings")
local Progression = Harness.load("Config/Progression")
local Warehouse = Harness.load("Config/Warehouse")
local Workers = Harness.load("Config/Workers")
local GrowthRules = Harness.load("GrowthRules")
local SeedStock = Harness.load("SeedStock")
local LandRules = Harness.load("LandRules")
local MarketPrice = Harness.load("MarketPrice")
local WorkerRules = Harness.load("WorkerRules")
local PipelineRules = Harness.load("PipelineRules")
local ProgressionRules = Harness.load("ProgressionRules")

local PROFILES = {
	{ id = "casual", name = "Casual (45 min a day)", firstDay = 60, daily = 45 },
	{ id = "daily", name = "Daily (1.5 h a day)", firstDay = 120, daily = 90 },
	{ id = "keen", name = "Keen (3 h a day)", firstDay = 180, daily = 180 },
}
local DAYS = 35
local HAND_HARVESTS = 10 -- tiles a minute the player picks and replants themselves
local START = 1_760_000_000 - 1_760_000_000 % 86400 + 18 * 3600 -- 18:00 UTC

local MILESTONE_LEVELS = { 2, 3, 5, 10, 12, 14, 16, 20, 24, 28, 32 }

-- Crops best first by profit per tile-minute.
local byProfit = table.clone(Crops.List)
table.sort(byProfit, function(a, b)
	return GrowthRules.profitPerMinute(a.id) > GrowthRules.profitPerMinute(b.id)
end)

local priceCache = {}
local function price(cropId, t)
	local key = `{cropId}@{t // 60}`
	local value = priceCache[key]
	if not value then
		value = MarketPrice.price(cropId, t)
		priceCache[key] = value
	end
	return value
end

local function newPlayer()
	return {
		coins = Settings.START_COINS, xp = 0, level = 1,
		seeds = table.clone(Settings.START_SEEDS), seedStock = { index = -1, bought = {} },
		land = { cleared = {} }, tiles = {}, barn = {}, workers = {},
		warehouseTier = 0, cropdex = {},
		day = { income = 0, wages = 0 },
	}
end

local function workerCtx(p)
	return { warehouseTier = p.warehouseTier, shopTier = 0, openTiles = LandRules.openTiles(p.land), level = p.level }
end

local function addXp(p, amount)
	ProgressionRules.addXp(p, amount)
end

local function sell(p, cropId, units, t, online)
	local coins = units * price(cropId, t)
	p.coins += coins
	p.day.income += coins
	if online then
		addXp(p, ProgressionRules.salesXp(coins))
	end
end

-- The best crop the player can plant now: unlocked, in their seed bag or in
-- Barley's stock, and affordable. Buys the seed. Returns the crop id or nil.
local function getSeed(p, t)
	for _, crop in byProfit do
		local unlocked = p.level >= Rarities.ById[crop.rarity].seedLevel
		if unlocked and (p.seeds[crop.id] or 0) > 0 then
			p.seeds[crop.id] -= 1
			return crop.id
		end
		if unlocked and SeedStock.canBuy(p, crop.id, 1, p.level, t) then
			p.coins -= crop.seed
			SeedStock.record(p, crop.id, 1, t)
			return crop.id
		end
	end
	return nil
end

local function harvestTile(p, key, tile, t, byWorker, online)
	local xp = ProgressionRules.harvestXp(tile.crop, tile.regrowing, byWorker)
	if not p.cropdex[tile.crop] then
		p.cropdex[tile.crop] = true
		xp += Progression.CROPDEX_XP
	end
	if online then
		addXp(p, xp)
	end
	sell(p, tile.crop, 1, t, online)
	local _, stays = GrowthRules.harvest(tile)
	if not stays then
		p.tiles[key] = nil
	end
end

local function hire(p, typeName, free)
	local worker = { type = typeName, level = 1 }
	if not WorkerRules.canHire(p.workers, typeName, workerCtx(p)) then
		return false
	end
	local fee = if free then 0 else WorkerRules.hireFee(worker)
	if p.coins < fee * 5 then
		return false
	end
	p.coins -= fee
	table.insert(p.workers, worker)
	return true
end

local function spend(p, t, log)
	-- Land first: it's what levels are for.
	if LandRules.permitsLeft(p.land, p.level) > 0 then
		local block = LandRules.clearable(p.land)[1]
		if block and LandRules.canClear(p.land, p.level, p.coins, block) then
			p.coins -= LandRules.startClearing(p.land, block)
			LandRules.finishClearing(p.land)
			-- fresh soil: the next crops on these tiles grow faster (planted empty below)
			for _, tile in LandRules.tilesOf(block) do
				p.freshTiles = p.freshTiles or {}
				p.freshTiles[tostring(tile)] = true
			end
			log(`permit {#p.land.cleared} used (block {block}, {LandRules.risk(block)})`)
		end
	end
	-- The next warehouse tier, keeping a cushion for seeds.
	local nextTier = Warehouse.TIERS[p.warehouseTier + 2]
	if nextTier and p.level >= nextTier.level and p.coins >= nextTier.cost * 2 then
		p.coins -= nextTier.cost
		p.warehouseTier += 1
		WorkerRules.promoteShedHands(p.workers)
		log(`built the {nextTier.name}`)
	end
	-- Workers: Farmhands first, then the warehouse crew that sells while you're away.
	for _, typeName in { "Farmhand", "Sorter", "Packer", "Loader", "Driver" } do
		if hire(p, typeName) then
			log(`hired a {typeName}`)
		end
	end
end

local function onlineMinute(p, t, log)
	-- Anything left in the barn from being away gets sold.
	for cropId, units in p.barn do
		sell(p, cropId, units, t, true)
		p.barn[cropId] = nil
	end
	local keys = {}
	for key in p.tiles do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tonumber(a) < tonumber(b)
	end)
	for _, key in keys do
		GrowthRules.advance(p.tiles[key], 60, 1)
	end
	-- Harvest: the player's own picks, then Farmhands (half XP).
	local speeds, wages = WorkerRules.crew(p.workers)
	local hand, helpers = HAND_HARVESTS, math.floor(speeds.Field or 0)
	for _, key in keys do
		local tile = p.tiles[key]
		if tile and GrowthRules.isRipe(tile) then
			if hand > 0 then
				hand -= 1
				harvestTile(p, key, tile, t, false, true)
			elseif helpers > 0 then
				helpers -= 1
				harvestTile(p, key, tile, t, true, true)
			end
		end
	end
	-- Replant every empty open tile.
	for tile = 1, 64 do
		local key = tostring(tile)
		if not p.tiles[key] and LandRules.isTileOpen(p.land, tile) then
			local cropId = getSeed(p, t)
			if not cropId then
				break
			end
			local fresh = p.freshTiles and p.freshTiles[key]
			if fresh then
				p.freshTiles[key] = nil
			end
			p.tiles[key] = GrowthRules.plant(cropId, fresh)
		end
	end
	-- Wages.
	local pay = math.min(wages, math.max(0, p.coins))
	p.coins -= pay
	p.day.wages += pay
	spend(p, t, log)
end

-- Before logging off, buy seeds so the Farmhands can replant while you're away.
local function stockUpForFarmhands(p, t)
	if WorkerRules.count(p.workers, "Farmhand") == 0 then
		return
	end
	local planted = {}
	for _, tile in p.tiles do
		planted[tile.crop] = (planted[tile.crop] or 0) + 1
	end
	for cropId, count in planted do
		local crop = Crops.ById[cropId]
		local buy = math.min(count * 2, SeedStock.left(p, cropId, t), math.floor(p.coins / crop.seed))
		if buy >= 1 then
			p.coins -= buy * crop.seed
			SeedStock.record(p, cropId, buy, t)
			p.seeds[cropId] = (p.seeds[cropId] or 0) + buy
		end
	end
end

local function away(p, seconds, leftAt)
	local state = PipelineRules.newState()
	state.tiles, state.seeds, state.barn = p.tiles, p.seeds, p.barn
	local speeds, wages = WorkerRules.crew(p.workers)
	state.speeds, state.wages = speeds, wages
	state.drivers = WorkerRules.count(p.workers, "Driver")
	local tier = Warehouse.TIERS[p.warehouseTier + 1]
	state.truck = { crates = tier.truckCrates * tier.trucks, roundTrip = tier.roundTrip, backAt = 0 }
	local report = PipelineRules.settle(state, seconds, leftAt, price)
	p.tiles, p.seeds, p.barn = state.tiles, state.seeds, state.barn
	-- Truck runs pay out; the crops are sold by the time you're back.
	p.coins += report.truckCoins
	p.day.income += report.truckCoins
	-- Whatever the crew didn't ship (washed, packed or waiting for the truck)
	-- is sold by hand in the first minute back, with the rest of the barn.
	for _, place in { state.sorted, state.stockroom, state.shelves } do
		for crop, units in place do
			p.barn[crop] = (p.barn[crop] or 0) + units
		end
	end
	for _, crate in state.truckQueue do
		p.barn[crate.crop] = (p.barn[crate.crop] or 0) + crate.units
	end
	for _, crate in state.bed do
		p.barn[crate.crop] = (p.barn[crate.crop] or 0) + crate.units
	end
	local pay = math.min(report.wages, math.max(0, p.coins))
	p.coins -= pay
	p.day.wages += pay
end

local function run(profile)
	local p = newPlayer()
	local events = {}
	local reached = {}
	local played = 0
	local daysLog = {}
	local t = START
	for day = 1, DAYS do
		local minutes = if day == 1 then profile.firstDay else profile.daily
		p.day = { income = 0, wages = 0 }
		local function log(text)
			table.insert(events, { day = day, hours = played / 60, text = text })
		end
		for minute = 1, minutes do
			if day == 1 and minute == 10 then
				p.coins += Progression.GUIDE_COINS -- the Farm Guide's reward
				hire(p, "ShedHand", true) -- "First one's on the house!"
			end
			onlineMinute(p, t, log)
			played += 1
			for _, level in MILESTONE_LEVELS do
				if not reached[level] and p.level >= level then
					reached[level] = { day = day, hours = played / 60 }
				end
			end
			t += 60
		end
		stockUpForFarmhands(p, t)
		local awayFor = 86400 - minutes * 60
		away(p, awayFor, t)
		t += awayFor
		table.insert(daysLog, { day = day, income = p.day.income, wages = p.day.wages, coins = p.coins, level = p.level, permits = #p.land.cleared })
	end
	return { player = p, events = events, reached = reached, days = daysLog }
end

local function fmt(n)
	local s = tostring(math.floor(n + 0.5))
	return (string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,"))):gsub("^,", ""))
end

local only = nil
for _, arg in process.args do
	local power = string.match(arg, "^power=([%d%.]+)$")
	if power then
		Progression.XP_POWER = tonumber(power) -- (the loaded config table, shared with ProgressionRules)
	else
		only = arg
	end
end
local failures = 0
local function check(ok, text)
	print(`  {if ok then "\27[32m✓\27[0m" else "\27[31m✗\27[0m"} {text}`)
	if not ok then
		failures += 1
	end
end

for _, profile in PROFILES do
	if only and only ~= profile.id then
		continue
	end
	local result = run(profile)
	print(`\n\27[1m{profile.name}\27[0m  (XP curve: {Progression.XP_BASE} × (L−1)^{Progression.XP_POWER})`)
	for _, level in MILESTONE_LEVELS do
		local at = result.reached[level]
		local permits = LandRules.permitsEarned(level)
		print(string.format("  Lv %2d  %-28s %s", level,
			if at then `day {at.day} ({string.format("%.1f", at.hours)} h played)` else "not in 35 days",
			if permits > LandRules.permitsEarned(level - 1) then `→ Land Permit {permits}` else ""))
	end
	local firstPermitDay, fullDay
	for _, event in result.events do
		if string.find(event.text, "^permit 1 ") then
			firstPermitDay = event.day
		end
		if string.find(event.text, "^permit 12 ") then
			fullDay = event.day
		end
	end
	for _, event in result.events do
		if string.find(event.text, "built") or string.find(event.text, "^permit 12") then
			print(`  day {event.day}: {event.text}`)
		end
	end
	local last = result.days[#result.days]
	print(`  after {DAYS} days: Lv {last.level}, {last.permits}/12 permits used, {fmt(last.coins)} coins`)
	local line = {}
	for _, d in result.days do
		if table.find({ 1, 3, 7, 14, 21, 28, 35 }, d.day) then
			table.insert(line, `d{d.day} {fmt(d.income)}`)
		end
	end
	print(`  income a day: {table.concat(line, " · ")}`)
	local worstDay
	for _, d in result.days do
		if d.day > 1 and d.wages > 0 and (not worstDay or d.wages / math.max(1, d.income) > worstDay.wages / math.max(1, worstDay.income)) then
			worstDay = d
		end
	end
	if worstDay then
		print(string.format("  wages peak at %.0f%% of income (day %d: %s of %s)", worstDay.wages / math.max(1, worstDay.income) * 100,
			worstDay.day, fmt(worstDay.wages), fmt(worstDay.income)))
	end
	if profile.id == "daily" then
		print("  targets (docs/GameDesign.md §4.1b):")
		check(firstPermitDay == 1, `Land Permit 1 in the first session (day {firstPermitDay or "-"})`)
		local lv12 = result.reached[12]
		check(lv12 ~= nil and lv12.day >= 2 and lv12.day <= 4, `permit 6 (Lv 12) around day 3 (day {lv12 and lv12.day or "-"})`)
		check(fullDay ~= nil and fullDay >= 15 and fullDay <= 28, `the full 8×8 in weeks 3–4 (day {fullDay or "-"})`)
	end
	check(worstDay == nil or worstDay.wages < worstDay.income * 0.25, "wages stay under a quarter of income every day")
end

if failures > 0 then
	print(`\n\27[31m{failures} target(s) missed.\27[0m Tune Config/Progression (XP curve) or the land fees.`)
	process.exit(1)
end
print("\n\27[32mAll targets met.\27[0m")
