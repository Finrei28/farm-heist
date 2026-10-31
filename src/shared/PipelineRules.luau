-- The farm running while its owner is away (docs/GameDesign.md §4.9): workers
-- keep going at Workers.OFFLINE_RATE for up to Workers.OFFLINE_CAP, worked
-- out in one go when the owner returns (the Welcome back card). Minute by
-- minute: crops grow, Farmhands harvest and replant, the warehouse washes,
-- packs, routes and loads, Drivers send full trucks at the market price of
-- that minute (supply counted as 1), Stockers fill displays and shoppers buy
-- at your prices. Wages come out each minute; when they can't be paid the
-- crew strikes until a sale brings the coins. No randomness: averages, so
-- the same farm always gives the same result. tests/pipeline.test.luau.
--
-- state (built by the service from the save; changed in place):
--   tiles      { ["tile"] = tile }  planted tiles (shared/GrowthRules)
--   seeds      { [cropId] = n }     Farmhands replant from these
--   replant    "same" | "cheapest" | "none"
--   barn       { [cropId] = units } waiting for the warehouse
--   barnRoom   units the barn still holds (Farmhands stop when it's full)
--   sorted     { [cropId] = units } washed and graded, waiting to be packed
--   hold       { crate }            crates waiting for a truck (rack / Cold Room) ...
--   holdSize   ... and how many it takes (packing for the truck pauses when full)
--   trucks     { { crates, roundTrip, backAt, driver, bed = { crate } } }
--   stockroom  { [cropId] = units } packed for the store ...
--   stockroomRoom ... and crates it still takes (then crates go to the truck)
--   shelves    { [cropId] = units } on the store's displays
--   routes     { [cropId] = share for the truck 0–1 (default 1) or "Keep" }
--   speeds     { Field, Shed, Sort, Pack, Load, Shelves, Register } a minute (WorkerRules.crew)
--   gradeA     share of the crew's batches that come out grade A
--   minPrice   the Drivers' rule: send only at ≥ this × base value (0: when full)
--   premium    Premium contracts: Legendary and Mythic crates this much more by truck
--   shop       { level, stars, prices = { [cropId] = coins }, capacity, staffed, boost }
--              (staffed: only staffed checkouts, so shoppers need a Cashier;
--              boost: the Greeter's extra shoppers)
--   wages      coins a minute for the whole crew, online
--   coins      the owner's coins (wages come out of them; sales go in)
-- A crate here is { crop, units, grade }.
local Crops = require(script.Parent.Config.Crops)
local Rarities = require(script.Parent.Config.Rarities)
local Shop = require(script.Parent.Config.Shop)
local Warehouse = require(script.Parent.Config.Warehouse)
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
		return 0
	end
	return math.min(budget + perMinute, math.max(1, perMinute))
end

local function crateSize(cropId: string): number
	return Rarities.ById[Crops.ById[cropId].rarity].crate
end

function PipelineRules.newState()
	return {
		tiles = {}, seeds = {}, replant = "same", barn = {}, barnRoom = math.huge, sorted = {}, hold = {}, holdSize = 6,
		trucks = { { crates = 4, roundTrip = 60, backAt = 0, driver = false, bed = {} } },
		stockroom = {}, stockroomRoom = math.huge, shelves = {}, routes = {}, speeds = {}, gradeA = 0, minPrice = 0, premium = 0,
		shop = { level = 1, stars = 3, prices = {}, capacity = 40, staffed = false, boost = 0 },
		wages = 0, coins = math.huge,
	}
end

-- The seed a Farmhand replants a tile with, or nil (and takes it from the bag).
local function replantSeed(state, cropId: string): string?
	if state.replant == "same" then
		if (state.seeds[cropId] or 0) > 0 then
			state.seeds[cropId] -= 1
			return cropId
		end
	elseif state.replant == "cheapest" then
		local best = nil
		for id, count in state.seeds do
			if count > 0 and (not best or Crops.ById[id].seed < Crops.ById[best].seed or (Crops.ById[id].seed == Crops.ById[best].seed and id < best)) then
				best = id
			end
		end
		if best then
			state.seeds[best] -= 1
			return best
		end
	end
	return nil
end

-- Runs the farm for `seconds` (capped at Workers.OFFLINE_CAP) from
-- `startTime` at `rate` (Workers.OFFLINE_RATE). priceAt(cropId, t) gives the
-- truck price (default: MarketPrice with supply 1). Returns a report:
--   { minutes, harvested, crates, shippedCrates, truckCoins, runs = { run }, shopUnits, shopCoins,
--     sold = { [cropId] = units }, stocked, wages, strikeMinutes, worked = { [station] = minutes } }
-- run = { truck, at, arriveAt, returnAt, crates = { crate + price + coins }, coins }
function PipelineRules.simulate(state, seconds: number, rate: number, startTime: number, priceAt)
	priceAt = priceAt or function(cropId, t)
		return MarketPrice.price(cropId, t)
	end
	local minutes = math.max(0, math.floor(math.min(seconds, Workers.OFFLINE_CAP) / 60))
	local speeds = state.speeds
	state.routeAcc = state.routeAcc or {}
	state.salesAcc = state.salesAcc or {}
	state.gradeAcc = state.gradeAcc or 0
	local budget = { harvest = 0, shed = 0, sort = 0, pack = 0, load = 0, stock = 0, shoppers = 0, register = 0 }
	local report = {
		minutes = minutes, harvested = 0, crates = 0, shippedCrates = 0, truckCoins = 0, runs = {},
		shopUnits = 0, shopCoins = 0, sold = {}, stocked = 0, wages = 0, strikeMinutes = 0, worked = {},
	}
	local pending = {} -- runs on the road, not paid yet (their coins come in at arriveAt)

	local function worked(station: string)
		report.worked[station] = (report.worked[station] or 0) + 1
	end

	-- A packed crate's grade: the crew's grade A share, kept exact over many crates.
	local function grade(): string
		state.gradeAcc += state.gradeA or 0
		if state.gradeAcc >= 1 - 1e-9 then
			state.gradeAcc -= 1
			return "A"
		end
		return "B"
	end

	-- Room for one more crate waiting for a truck.
	local function holdHasRoom(): boolean
		return #state.hold < state.holdSize
	end

	-- A packed crate goes to the truck or the store, as the route says (shares
	-- are kept exact over many crates); a full stockroom sends it to the truck.
	local function route(cropId: string, units: number)
		report.crates += 1
		local share = state.routes[cropId]
		share = if type(share) == "number" then share else 1
		local acc = (state.routeAcc[cropId] or 0) + share
		local crate = { crop = cropId, units = units, grade = grade() }
		if acc >= 1 - 1e-9 then
			acc -= 1
			table.insert(state.hold, crate)
		elseif state.stockroomRoom > 0 then
			state.stockroomRoom -= 1
			add(state.stockroom, cropId, units)
		else
			table.insert(state.hold, crate)
		end
		state.routeAcc[cropId] = acc
	end

	-- Crops the warehouse takes from the barn (not ones kept there).
	local function routed(cropId: string): boolean
		return state.routes[cropId] ~= "Keep"
	end

	local tileKeys = keysOf(state.tiles, true)
	for m = 0, minutes - 1 do
		local t = startTime + m * 60

		-- Trucks that reached the City pay; crops grow.
		for i = #pending, 1, -1 do
			if pending[i].arriveAt <= t then
				if state.coins ~= math.huge then
					state.coins += pending[i].coins
				end
				table.remove(pending, i)
			end
		end
		for _, key in tileKeys do
			local tile = state.tiles[key]
			if tile then
				GrowthRules.advance(tile, 60, rate)
			end
		end

		-- Wages for this minute, or a strike until they can be paid.
		local wage = (state.wages or 0) * rate
		if wage > 0 and state.coins < wage then
			report.strikeMinutes += 1
			budget = { harvest = 0, shed = 0, sort = 0, pack = 0, load = 0, stock = 0, shoppers = budget.shoppers, register = 0 }
		else
			if state.coins ~= math.huge then
				state.coins -= wage
			end
			report.wages += wage

			-- Farmhands harvest ripe tiles (not ones flagged to stay) and replant.
			budget.harvest = refill(budget.harvest, (speeds.Field or 0) * rate)
			local picked = false
			for _, key in tileKeys do
				if budget.harvest < 1 or state.barnRoom < 1 then
					break
				end
				local tile = state.tiles[key]
				if tile and not tile.leave and GrowthRules.isRipe(tile) then
					budget.harvest -= 1
					report.harvested += 1
					picked = true
					state.barnRoom -= 1
					add(state.barn, tile.crop, 1)
					local _, stays = GrowthRules.harvest(tile)
					if not stays then
						local seed = replantSeed(state, tile.crop)
						state.tiles[key] = if seed then GrowthRules.plant(seed) else nil
					end
				end
			end
			if picked then
				worked("Field")
			end

			-- The Shed Hand (Packing Shed) washes and packs full crates
			-- straight from the barn ...
			budget.shed = refill(budget.shed, (speeds.Shed or 0) * rate)
			local shedWorked = false
			for _, cropId in keysOf(state.barn) do
				local size = crateSize(cropId)
				while routed(cropId) and budget.shed >= 1 and (state.barn[cropId] or 0) >= size and holdHasRoom() do
					budget.shed -= 1
					add(state.barn, cropId, -size)
					route(cropId, size)
					shedWorked = true
				end
			end

			-- ... Sorters wash and grade (warehouses) ...
			budget.sort = refill(budget.sort, (speeds.Sort or 0) * rate)
			for _, cropId in keysOf(state.barn) do
				local units = if routed(cropId) then math.min(math.floor(budget.sort), state.barn[cropId] or 0) else 0
				if units > 0 then
					budget.sort -= units
					add(state.barn, cropId, -units)
					add(state.sorted, cropId, units)
					worked("Sort")
				end
			end

			-- ... Packers fill full crates ...
			budget.pack = refill(budget.pack, (speeds.Pack or 0) * rate)
			for _, cropId in keysOf(state.sorted) do
				local size = crateSize(cropId)
				while budget.pack >= 1 and (state.sorted[cropId] or 0) >= size and holdHasRoom() do
					budget.pack -= 1
					add(state.sorted, cropId, -size)
					route(cropId, size)
					worked("Pack")
				end
			end

			-- ... and Loaders (and the Shed Hand) load the trucks that are home.
			budget.load = refill(budget.load, ((speeds.Load or 0) + (speeds.Shed or 0)) * rate)
			for _, truck in state.trucks do
				while budget.load >= 1 and #state.hold > 0 and t >= truck.backAt and #truck.bed < truck.crates do
					budget.load -= 1
					table.insert(truck.bed, table.remove(state.hold, 1))
					if (speeds.Load or 0) > 0 then
						worked("Load")
					else
						shedWorked = true
					end
				end
			end
			if shedWorked then
				worked("Shed")
			end

			-- Drivers send full trucks if the price rule allows: the price
			-- locks now and the run pays when it reaches the City.
			for index, truck in state.trucks do
				if truck.driver and t >= truck.backAt and #truck.bed >= truck.crates then
					local coins, atBase, lines = 0, 0, {}
					for _, crate in truck.bed do
						local rarity = Crops.ById[crate.crop].rarity
						local price = priceAt(crate.crop, t)
						if (state.premium or 0) > 0 and (rarity == "Legendary" or rarity == "Mythic") then
							price = math.floor(price * (1 + state.premium) + 0.5)
						end
						local value = math.floor(crate.units * price * (if crate.grade == "A" then Warehouse.GRADE_A else 1) + 0.5)
						coins += value
						atBase += crate.units * Crops.ById[crate.crop].value
						table.insert(lines, { crop = crate.crop, units = crate.units, grade = crate.grade, price = price, coins = value })
					end
					if coins >= (state.minPrice or 0) * atBase then
						local run = { truck = index, at = t, arriveAt = t + truck.roundTrip / 2, returnAt = t + truck.roundTrip, crates = lines, coins = coins }
						report.shippedCrates += #truck.bed
						report.truckCoins += coins
						table.insert(report.runs, run)
						table.insert(pending, run)
						table.clear(truck.bed)
						truck.backAt = run.returnAt
					end
				end
				if truck.driver and t < truck.backAt then
					worked("Truck")
				end
			end

			-- Stockers move stock onto the displays, up to their capacity.
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
					report.stocked += units
					add(state.stockroom, cropId, -units)
					add(state.shelves, cropId, units)
					worked("Shelves")
				end
			end
		end

		-- Shoppers buy at your prices (they come whether or not the crew
		-- works). Honour Boxes and Self-checkouts serve themselves; a store
		-- with only Registers needs a Cashier.
		local shop = state.shop
		budget.shoppers += 60 / DemandModel.shopperInterval(shop.level, shop.stars) * rate * (1 + (shop.boost or 0))
		local arrived = math.floor(budget.shoppers)
		budget.shoppers -= arrived
		local served = arrived
		if shop.staffed then
			budget.register = refill(budget.register, (speeds.Register or 0) * rate)
			served = math.min(arrived, math.floor(budget.register))
			budget.register -= served
			if served > 0 then
				worked("Register")
			end
		end
		if served > 0 and (shop.boost or 0) > 0 then
			worked("Door")
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
					report.sold[cropId] = (report.sold[cropId] or 0) + sold
					if state.coins ~= math.huge then
						state.coins += sold * price
					end
				end
			end
		end
	end
	report.wages = math.floor(report.wages + 0.5)
	return report
end

-- Settles a whole absence on return: the workers' first OFFLINE_CAP
-- (simulate), then crops keep growing at the offline rate for the rest of
-- the time away. The window starts at `leftAt`. The caller pays the runs
-- that have arrived and saves the rest as TruckRuns.
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
