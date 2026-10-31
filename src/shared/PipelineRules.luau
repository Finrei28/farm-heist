-- The farm running while its owner is away (docs/GameDesign.md §4.9): workers
-- keep going at Workers.OFFLINE_RATE for up to Workers.OFFLINE_CAP, worked
-- out in one go when the owner returns (the Welcome back card). Minute by
-- minute: crops grow, Farmhands harvest and replant, the warehouse sorts,
-- packs, routes and loads, a Driver dispatches full trucks at the market
-- price of that minute (supply counted as 1), Stockers fill shelves and
-- shoppers buy at your prices. No randomness: averages, so the same farm
-- always gives the same result. tests/pipeline.test.luau.
--
-- state (built by the service from the save; changed in place):
--   tiles      { ["tile"] = tile }  planted tiles (shared/GrowthRules)
--   seeds      { [cropId] = n }     Farmhands replant from these
--   replant    "same" | "none"
--   barn       { [cropId] = units } waiting for the warehouse
--   sorted     { [cropId] = units } washed and graded, waiting to be packed
--   truckQueue { { crop, units } }  crates waiting for the truck
--   bed        { { crop, units } }  crates on the truck
--   stockroom  { [cropId] = units } packed for the shop
--   shelves    { [cropId] = units }
--   routes     { [cropId] = share } of crates for the truck, 0–1 (default 1)
--   speeds     { Field, Shed, Sort, Pack, Load, Shelves, Register } a minute (WorkerRules.crew)
--   drivers    number of Drivers (no Driver: trucks wait for you)
--   minPrice   Driver rule: dispatch only at ≥ this × base value (default 0)
--   truck      { crates, roundTrip, backAt }
--   shop       { level, stars, prices = { [cropId] = coins }, capacity, staffed }
--              (staffed: only staffed checkouts, so shoppers need a Cashier)
--   wages      coins a minute for the whole crew, online
local Crops = require(script.Parent.Config.Crops)
local Rarities = require(script.Parent.Config.Rarities)
local Shop = require(script.Parent.Config.Shop)
local Workers = require(script.Parent.Config.Workers)
local DemandModel = require(script.Parent.DemandModel)
local GrowthRules = require(script.Parent.GrowthRules)
local MarketPrice = require(script.Parent.MarketPrice)

local PipelineRules = {}

local function keysOf(map, numeric: boolean?)
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		if numeric then
			return (tonumber(a) or 0) < (tonumber(b) or 0)
		end
		return tostring(a) < tostring(b)
	end)
	return keys
end

local function add(map, key, amount)
	map[key] = (map[key] or 0) + amount
	if map[key] <= 0 then
		map[key] = nil
	end
end

-- Work budget for a station: speed a minute builds up, never more than a
-- minute's worth (or 1, so slow stations still get there).
local function refill(budget: number, perMinute: number): number
	if perMinute <= 0 then
		return budget
	end
	return math.min(budget + perMinute, math.max(1, perMinute))
end

local function crateSize(cropId: string): number
	return Rarities.ById[Crops.ById[cropId].rarity].crate
end

function PipelineRules.newState()
	return {
		tiles = {}, seeds = {}, replant = "same", barn = {}, sorted = {}, truckQueue = {}, bed = {},
		stockroom = {}, shelves = {}, routes = {}, speeds = {}, drivers = 0, minPrice = 0,
		truck = { crates = 4, roundTrip = 60, backAt = 0 },
		shop = { level = 1, stars = 3, prices = {}, capacity = 40, staffed = false },
		wages = 0,
	}
end

-- Runs the farm for `seconds` (capped at Workers.OFFLINE_CAP) from
-- `startTime` at `rate` (Workers.OFFLINE_RATE). priceAt(cropId, t) gives the
-- truck price (default: MarketPrice with supply 1). Returns a report:
--   { minutes, harvested, crates, shippedCrates, truckCoins, runs = { { at, arriveAt, crates, coins } },
--     shopUnits, shopCoins, wages }
function PipelineRules.simulate(state, seconds: number, rate: number, startTime: number, priceAt)
	priceAt = priceAt or function(cropId, t)
		return MarketPrice.price(cropId, t)
	end
	local minutes = math.max(0, math.floor(math.min(seconds, Workers.OFFLINE_CAP) / 60))
	local speeds = state.speeds
	local truck = state.truck
	state.routeAcc = state.routeAcc or {}
	state.salesAcc = state.salesAcc or {}
	local budget = { harvest = 0, shed = 0, sort = 0, pack = 0, load = 0, stock = 0, shoppers = 0, register = 0 }
	local report = {
		minutes = minutes, harvested = 0, crates = 0, shippedCrates = 0, truckCoins = 0, runs = {},
		shopUnits = 0, shopCoins = 0, wages = 0,
	}

	-- A packed crate goes to the truck or the shop, as the route says (shares
	-- are kept exact over many crates).
	local function route(cropId: string, units: number)
		report.crates += 1
		local acc = (state.routeAcc[cropId] or 0) + (state.routes[cropId] or 1)
		if acc >= 1 - 1e-9 then
			acc -= 1
			table.insert(state.truckQueue, { crop = cropId, units = units })
		else
			add(state.stockroom, cropId, units)
		end
		state.routeAcc[cropId] = acc
	end

	local tileKeys = keysOf(state.tiles, true)
	for m = 0, minutes - 1 do
		local t = startTime + m * 60

		-- Crops grow.
		for _, key in tileKeys do
			local tile = state.tiles[key]
			if tile then
				GrowthRules.advance(tile, 60, rate)
			end
		end

		-- Farmhands harvest ripe tiles (not ones flagged to stay) and replant.
		budget.harvest = refill(budget.harvest, (speeds.Field or 0) * rate)
		for _, key in tileKeys do
			if budget.harvest < 1 then
				break
			end
			local tile = state.tiles[key]
			if tile and not tile.leave and GrowthRules.isRipe(tile) then
				budget.harvest -= 1
				report.harvested += 1
				add(state.barn, tile.crop, 1)
				local _, stays = GrowthRules.harvest(tile)
				if not stays then
					if state.replant == "same" and (state.seeds[tile.crop] or 0) > 0 then
						state.seeds[tile.crop] -= 1
						state.tiles[key] = GrowthRules.plant(tile.crop)
					else
						state.tiles[key] = nil
					end
				end
			end
		end

		-- The Shed Hand (T0) packs straight from the barn.
		budget.shed = refill(budget.shed, (speeds.Shed or 0) * rate)
		for _, cropId in keysOf(state.barn) do
			local size = crateSize(cropId)
			while budget.shed >= 1 and (state.barn[cropId] or 0) >= size do
				budget.shed -= 1
				add(state.barn, cropId, -size)
				route(cropId, size)
			end
		end

		-- Sorters wash and grade (offline batches count as grade B).
		budget.sort = refill(budget.sort, (speeds.Sort or 0) * rate)
		for _, cropId in keysOf(state.barn) do
			local units = math.min(math.floor(budget.sort), state.barn[cropId] or 0)
			if units > 0 then
				budget.sort -= units
				add(state.barn, cropId, -units)
				add(state.sorted, cropId, units)
			end
		end

		-- Packers fill full crates.
		budget.pack = refill(budget.pack, (speeds.Pack or 0) * rate)
		for _, cropId in keysOf(state.sorted) do
			local size = crateSize(cropId)
			while budget.pack >= 1 and (state.sorted[cropId] or 0) >= size do
				budget.pack -= 1
				add(state.sorted, cropId, -size)
				route(cropId, size)
			end
		end

		-- Loaders (and the Shed Hand) load the truck while it's home.
		budget.load = refill(budget.load, ((speeds.Load or 0) + (speeds.Shed or 0)) * rate)
		while budget.load >= 1 and #state.truckQueue > 0 and t >= truck.backAt and #state.bed < truck.crates do
			budget.load -= 1
			table.insert(state.bed, table.remove(state.truckQueue, 1))
		end

		-- A Driver dispatches a full truck if the price rule allows; the
		-- price locks now and the run pays when it reaches the City.
		if state.drivers > 0 and t >= truck.backAt and #state.bed >= truck.crates then
			local coins, atBase = 0, 0
			for _, crate in state.bed do
				coins += crate.units * priceAt(crate.crop, t)
				atBase += crate.units * Crops.ById[crate.crop].value
			end
			if coins >= (state.minPrice or 0) * atBase then
				report.shippedCrates += #state.bed
				report.truckCoins += coins
				table.insert(report.runs, { at = t, arriveAt = t + truck.roundTrip / 2, crates = #state.bed, coins = coins })
				table.clear(state.bed)
				truck.backAt = t + truck.roundTrip
			end
		end

		-- Stockers move stock onto the shelves, up to the shop's capacity.
		budget.stock = refill(budget.stock, (speeds.Shelves or 0) * rate)
		local onShelves = 0
		for _, units in state.shelves do
			onShelves += units
		end
		for _, cropId in keysOf(state.stockroom) do
			local units = math.min(math.floor(budget.stock), state.stockroom[cropId] or 0, state.shop.capacity - onShelves)
			if units > 0 then
				budget.stock -= units
				onShelves += units
				add(state.stockroom, cropId, -units)
				add(state.shelves, cropId, units)
			end
		end

		-- Shoppers buy at your prices. Honour Boxes and Self-checkouts serve
		-- themselves; a store with only Registers needs a Cashier.
		local shop = state.shop
		budget.shoppers += 60 / DemandModel.shopperInterval(shop.level, shop.stars) * rate
		local arrived = math.floor(budget.shoppers)
		budget.shoppers -= arrived
		local served = arrived
		if shop.staffed then
			budget.register = refill(budget.register, (speeds.Register or 0) * rate)
			served = math.min(arrived, math.floor(budget.register))
			budget.register -= served
		end
		local stocked = keysOf(state.shelves)
		for _, cropId in stocked do
			local price = shop.prices[cropId]
			if price and served > 0 then
				local ref = DemandModel.reference(Crops.ById[cropId].value, priceAt(cropId, t))
				local chance = DemandModel.buyChance(price, ref, shop.stars)
				local acc = (state.salesAcc[cropId] or 0) + served * Shop.UNITS_PER_SHOPPER * chance / #stocked
				local sold = math.min(math.floor(acc), state.shelves[cropId] or 0)
				state.salesAcc[cropId] = if sold < (state.shelves[cropId] or 0) then acc - sold else 0
				if sold > 0 then
					add(state.shelves, cropId, -sold)
					report.shopUnits += sold
					report.shopCoins += sold * price
				end
			end
		end

		report.wages += (state.wages or 0) * rate
	end
	report.wages = math.floor(report.wages + 0.5)
	return report
end

-- Settles a whole absence on return: the workers' first OFFLINE_CAP
-- (simulate), then crops keep growing at the offline rate for the rest of
-- the time away. The window starts at `leftAt`. Truck runs in the report
-- that arrive after `leftAt + awaySeconds` become saved TruckRuns.
function PipelineRules.settle(state, awaySeconds: number, leftAt: number, priceAt)
	local report = PipelineRules.simulate(state, awaySeconds, Workers.OFFLINE_RATE, leftAt, priceAt)
	local rest = awaySeconds - report.minutes * 60
	if rest > 0 then
		for _, tile in state.tiles do
			GrowthRules.offline(tile, rest)
		end
	end
	return report
end

return PipelineRules
