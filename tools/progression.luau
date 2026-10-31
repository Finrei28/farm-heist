-- Progression sim (from the project folder):
--   lune run tools/progression            all three player profiles
--   lune run tools/progression daily      just one
--   lune run tools/progression daily power=2.7   try another XP curve (Config/Progression XP_POWER)
-- Plays a farm minute by minute with the game's real rules and tables
-- (growth, Barley's restocks, Land Permits, market prices, Warehouse and
-- Store Levels, workers with their levels, XP, training, wages and slots,
-- the offline pipeline) and a sensible player: harvest what's ripe, sell
-- it by truck, replant the best crop they can buy, clear land as soon as a
-- permit and the fee allow, level the warehouse and the store, hire into
-- every open slot and train workers when their bar is full, each with a
-- cushion of coins kept back. Prints when each milestone comes, then checks
-- the design doc's pacing targets (§4.1b, §4.6, §4.9, §6.2) and that wages
-- stay a small share of income. Exits with code 1 if a target is missed.
--
-- Left out (so real players are a little slower or faster): raids, store
-- sales (they'd speed it up) and decor (it'd slow it down), auctions (the
-- main source of Mythic seeds), weather and mutations, quests and the login
-- streak, building times (a few minutes each), hiring a better candidate
-- than Level 1.
local process = require("@lune/process")

local Harness = require("../tests/lib/harness")
Harness.reset()
Harness.fresh()

local Crops = Harness.load("Config/Crops")
local Rarities = Harness.load("Config/Rarities")
local Settings = Harness.load("Config/Settings")
local Progression = Harness.load("Config/Progression")
local Store = Harness.load("Config/Store")
local Workers = Harness.load("Config/Workers")
local GrowthRules = Harness.load("GrowthRules")
local SeedStock = Harness.load("SeedStock")
local LandRules = Harness.load("LandRules")
local MarketPrice = Harness.load("MarketPrice")
local WarehouseRules = Harness.load("WarehouseRules")
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
local CUSHION = 2 -- coins kept back: a level is bought at CUSHION × its cost ...
local TRAIN_CUSHION = 3 -- ... training at this × the fee, hiring at 5 × the fee
local CREW = { "Farmhand", "ShedHand", "Sorter", "Packer", "Loader", "Driver" } -- (the store's crew sells nothing here: no store sales)

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
		warehouseLevel = 1, storeLevel = 1, cropdex = {},
		day = { income = 0, wages = 0, sunk = 0 },
		reached = { warehouse = {}, store = {} },
	}
end

local function workerCtx(p)
	return {
		warehouseLevel = p.warehouseLevel, storeLevel = p.storeLevel, openTiles = LandRules.openTiles(p.land),
		registers = 0, trucks = WarehouseRules.level(p.warehouseLevel).trucks,
	}
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

local function sink(p, coins)
	p.coins -= coins
	p.day.sunk += coins
end

local function hire(p, typeName, free)
	local worker = { type = typeName, level = 1, xp = 0 }
	if not WorkerRules.canHire(p.workers, typeName, workerCtx(p)) then
		return false
	end
	local fee = if free then 0 else WorkerRules.hireFee(worker)
	if p.coins < fee * 5 then
		return false
	end
	sink(p, fee)
	table.insert(p.workers, worker)
	return true
end

local function spend(p, day, log)
	-- Land first: it's what levels are for.
	if LandRules.permitsLeft(p.land, p.level) > 0 then
		local block = LandRules.clearable(p.land)[1]
		if block and LandRules.canClear(p.land, p.level, p.coins, block) then
			sink(p, LandRules.startClearing(p.land, block))
			LandRules.finishClearing(p.land)
			-- fresh soil: the next crops on these tiles grow faster (planted empty below)
			for _, tile in LandRules.tilesOf(block) do
				p.freshTiles = p.freshTiles or {}
				p.freshTiles[tostring(tile)] = true
			end
			log(`permit {#p.land.cleared} used (block {block}, {LandRules.risk(block)})`)
		end
	end
	-- The next Warehouse Level, then the next Store Level, each with a cushion.
	if p.warehouseLevel < WarehouseRules.MAX_LEVEL then
		local nextLevel = WarehouseRules.level(p.warehouseLevel + 1)
		if p.level >= nextLevel.farmLevel and p.coins >= nextLevel.cost * CUSHION then
			sink(p, nextLevel.cost)
			local before = WarehouseRules.level(p.warehouseLevel)
			p.warehouseLevel += 1
			if before.stage == 1 and nextLevel.stage > 1 then
				WorkerRules.promoteShedHands(p.workers)
			end
			p.reached.warehouse[p.warehouseLevel] = day
		end
	end
	if p.storeLevel < #Store.LEVELS then
		local nextLevel = Store.LEVELS[p.storeLevel + 1]
		if p.level >= nextLevel.farmLevel and p.coins >= nextLevel.cost * CUSHION then
			sink(p, nextLevel.cost)
			p.storeLevel += 1
			p.reached.store[p.storeLevel] = day
		end
	end
	-- Workers: Farmhands first, then the warehouse crew that sells while you're away.
	for _, typeName in CREW do
		while hire(p, typeName) do
			log(`hired a {typeName}`)
		end
	end
	-- Training: anyone whose bar is full, the cheapest first.
	for _, worker in p.workers do
		local fee = WorkerRules.trainFee(worker)
		if fee and WorkerRules.ready(worker) and p.coins >= fee * TRAIN_CUSHION then
			sink(p, fee)
			WorkerRules.train(worker)
		end
	end
end

local function onlineMinute(p, t, day, log)
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
	local info = WarehouseRules.level(p.warehouseLevel)
	local speeds, wages = WorkerRules.crew(p.workers, { conveyors = info.conveyors })
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
	-- Wages, and the crew learns (online they're kept busy).
	local pay = math.min(wages, math.max(0, p.coins))
	p.coins -= pay
	p.day.wages += pay
	for _, worker in p.workers do
		WorkerRules.addXp(worker, Workers.XP_PER_MINUTE)
	end
	spend(p, day, log)
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

local STATIONS = { Field = "Farmhand", Shed = "ShedHand", Sort = "Sorter", Pack = "Packer", Load = "Loader", Truck = "Driver" }

local function away(p, seconds, leftAt)
	local info = WarehouseRules.level(p.warehouseLevel)
	local state = PipelineRules.newState()
	state.tiles, state.seeds, state.barn = p.tiles, p.seeds, p.barn
	local speeds, wages = WorkerRules.crew(p.workers, { conveyors = info.conveyors })
	state.speeds, state.wages = speeds, wages
	state.holdSize = info.hold
	state.premium = info.premium
	state.trucks = {}
	local drivers = WorkerRules.count(p.workers, "Driver")
	for i = 1, info.trucks do
		state.trucks[i] = { crates = info.truckCrates, roundTrip = info.roundTrip, backAt = 0, driver = i <= drivers, bed = {} }
	end
	local graders, chance = 0, 0
	for _, worker in p.workers do
		if worker.type == "Sorter" or worker.type == "ShedHand" then
			graders += 1
			chance += WorkerRules.gradeAChance(worker, info.washLine)
		end
	end
	state.gradeA = if graders > 0 then chance / graders else 0
	state.coins = math.max(0, p.coins)
	local report = PipelineRules.settle(state, seconds, leftAt, price)
	p.tiles, p.seeds, p.barn = state.tiles, state.seeds, state.barn
	-- Truck runs pay out; the crops are sold by the time you're back.
	p.coins += report.truckCoins
	p.day.income += report.truckCoins
	-- Whatever the crew didn't ship (washed, packed or waiting for a truck)
	-- is sold by hand in the first minute back, with the rest of the barn.
	for _, place in { state.sorted, state.stockroom, state.shelves } do
		for crop, units in place do
			p.barn[crop] = (p.barn[crop] or 0) + units
		end
	end
	local crates = table.clone(state.hold)
	for _, truck in state.trucks do
		for _, crate in truck.bed do
			table.insert(crates, crate)
		end
	end
	for _, crate in crates do
		p.barn[crate.crop] = (p.barn[crate.crop] or 0) + crate.units
	end
	local pay = math.min(report.wages, math.max(0, p.coins))
	p.coins -= pay
	p.day.wages += pay
	-- The crew learns from the work it did (at the offline rate).
	for station, typeName in STATIONS do
		local minutes = report.worked[station] or 0
		if minutes > 0 then
			for _, worker in p.workers do
				if worker.type == typeName then
					WorkerRules.addXp(worker, minutes * Workers.XP_PER_MINUTE * Workers.OFFLINE_RATE)
				end
			end
		end
	end
end

local function averageLevel(p): (number, number)
	local total, count, best = 0, 0, 0
	for _, worker in p.workers do
		total += worker.level
		count += 1
		best = math.max(best, worker.level)
	end
	return if count > 0 then total / count else 0, best
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
		p.day = { income = 0, wages = 0, sunk = 0 }
		local function log(text)
			table.insert(events, { day = day, hours = played / 60, text = text })
		end
		for minute = 1, minutes do
			if day == 1 and minute == 10 then
				p.coins += Progression.GUIDE_COINS -- the Farm Guide's reward
				hire(p, "ShedHand", true) -- "First one's on the house!"
			end
			onlineMinute(p, t, day, log)
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
		local average, best = averageLevel(p)
		table.insert(daysLog, { day = day, income = p.day.income, wages = p.day.wages, sunk = p.day.sunk, coins = p.coins, level = p.level,
			permits = #p.land.cleared, workerLevel = average, bestWorker = best, warehouse = p.warehouseLevel, store = p.storeLevel })
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
	local p = result.player
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
	local ladder = {}
	for _, level in { 5, 10, 15, 20 } do
		table.insert(ladder, `Lv {level}: warehouse day {p.reached.warehouse[level] or "-"}, store day {p.reached.store[level] or "-"}`)
	end
	print(`  levels  {table.concat(ladder, " · ")}`)
	local last = result.days[#result.days]
	local sunk = 0
	for _, d in result.days do
		sunk += d.sunk
	end
	print(`  after {DAYS} days: Lv {last.level}, {last.permits}/12 permits used, Warehouse {last.warehouse}, Store {last.store}, {fmt(last.coins)} coins (sank {fmt(sunk)})`)
	local line, crew = {}, {}
	for _, d in result.days do
		if table.find({ 1, 3, 7, 14, 21, 28, 35 }, d.day) then
			table.insert(line, `d{d.day} {fmt(d.income)}`)
			table.insert(crew, `d{d.day} {string.format("%.1f", d.workerLevel)} (best {d.bestWorker})`)
		end
	end
	print(`  income a day: {table.concat(line, " · ")}`)
	print(`  workers' average level: {table.concat(crew, " · ")} ({#p.workers} workers)`)
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
		print("  targets (docs/GameDesign.md §4.1b, §4.6, §4.9):")
		check(firstPermitDay == 1, `Land Permit 1 in the first session (day {firstPermitDay or "-"})`)
		local lv12 = result.reached[12]
		check(lv12 ~= nil and lv12.day >= 2 and lv12.day <= 4, `permit 6 (Lv 12) around day 3 (day {lv12 and lv12.day or "-"})`)
		check(fullDay ~= nil and fullDay >= 15 and fullDay <= 28, `the full 8×8 in weeks 3–4 (day {fullDay or "-"})`)
		local w5, w10, w15 = p.reached.warehouse[5], p.reached.warehouse[10], p.reached.warehouse[15]
		check(w5 ~= nil and w5 <= 3, `Warehouse Level 5 by day 3 (day {w5 or "-"})`)
		check(w10 ~= nil and w10 >= 8 and w10 <= 16, `Warehouse Level 10 in days 8–16 (day {w10 or "-"})`)
		check(w15 ~= nil and w15 >= 22 and w15 <= 35, `Warehouse Level 15 in days 22–35 (day {w15 or "-"})`)
		local d14, d28 = result.days[14], result.days[28]
		check(d14.workerLevel >= 5 and d14.workerLevel <= 8, `workers average Level 5–8 by day 14 ({string.format("%.1f", d14.workerLevel)})`)
		check(d28.workerLevel >= 6.5 and d28.bestWorker >= 8, `about 7 by day 28, the first hires at 8 or more ({string.format("%.1f", d28.workerLevel)}, best {d28.bestWorker})`)
		check(d14.bestWorker < 10, `nobody at Level 10 by day 14: a full crew is a long-term goal (best {d14.bestWorker})`)
	end
	check(worstDay == nil or worstDay.wages < worstDay.income * 0.15, "wages stay under 15% of income every day")
end

if failures > 0 then
	print(`\n\27[31m{failures} target(s) missed.\27[0m Tune the configs (Progression, Warehouse, Store, Workers) or the land fees.`)
	process.exit(1)
end
print("\n\27[32mAll targets met.\27[0m")
