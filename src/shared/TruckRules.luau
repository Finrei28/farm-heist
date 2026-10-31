-- The trucks (docs/GameDesign.md §4.6): 1 to 3 by Warehouse Level, each at
-- its own dock with its own bed. Crates are loaded into a truck while it's
-- home; dispatching locks every crate's price at that moment's market price;
-- the run is paid when the truck reaches the City (half the round trip) and
-- the truck is home again at the end of it. Runs are saved, so a run that
-- arrives while you're away is paid the next time you join, on any server.
-- tests/truck.test.luau.
--
-- In the save (shared/WarehouseRules has the rest of `warehouse`):
--   beds[truck]: crates loaded on that truck, waiting to leave (shared/CrateRules)
--   dock:        crates waiting for a truck (the rack, the Cold Room)
--   trucks:      runs on the road { id, truck, crates = { crate + price + coins }, coins, departAt, arriveAt, returnAt, paid }
local Crops = require(script.Parent.Config.Crops)
local CrateRules = require(script.Parent.CrateRules)
local WarehouseRules = require(script.Parent.WarehouseRules)

local TruckRules = {}

-- The warehouse's level info (trucks, truckCrates, roundTrip, premium ...).
function TruckRules.info(warehouse)
	return WarehouseRules.level(warehouse.level)
end

-- The run truck `truck` is out on at `now`, or nil if it's home.
function TruckRules.runOf(warehouse, truck: number, now: number)
	for _, run in warehouse.trucks do
		if (run.truck or 1) == truck and run.returnAt > now then
			return run
		end
	end
	return nil
end

function TruckRules.isHome(warehouse, truck: number, now: number): boolean
	return TruckRules.runOf(warehouse, truck, now) == nil
end

-- Trucks home at `now`.
function TruckRules.home(warehouse, now: number): number
	local count = 0
	for truck = 1, TruckRules.info(warehouse).trucks do
		if TruckRules.isHome(warehouse, truck, now) then
			count += 1
		end
	end
	return count
end

-- The run on the road that comes back first, or nil.
function TruckRules.nextBack(warehouse, now: number)
	local first = nil
	for _, run in warehouse.trucks do
		if run.returnAt > now and (not first or run.returnAt < first.returnAt) then
			first = run
		end
	end
	return first
end

-- The truck the next crate goes on: the first one home with room. Returns
-- it, or nil and why not ("TruckAway" · "TruckFull").
function TruckRules.loadable(warehouse, now: number): (number?, string?)
	local info = TruckRules.info(warehouse)
	local why = "TruckAway"
	for truck = 1, info.trucks do
		if TruckRules.isHome(warehouse, truck, now) then
			if #(warehouse.beds[truck] or {}) < info.truckCrates then
				return truck, nil
			end
			why = "TruckFull"
		end
	end
	return nil, why
end

-- Whether a crate can go on truck `truck` now; nil, or why not
-- ("TruckAway" · "TruckFull").
function TruckRules.cannotLoadInto(warehouse, truck: number, now: number): string?
	if not TruckRules.isHome(warehouse, truck, now) then
		return "TruckAway"
	elseif #(warehouse.beds[truck] or {}) >= TruckRules.info(warehouse).truckCrates then
		return "TruckFull"
	end
	return nil
end

-- Loads a crate onto truck `truck` (the one at the dock you're on). Returns
-- nil, or why not.
function TruckRules.loadInto(warehouse, truck: number, crate, now: number): string?
	local why = TruckRules.cannotLoadInto(warehouse, truck, now)
	if why then
		return why
	end
	warehouse.beds[truck] = warehouse.beds[truck] or {}
	table.insert(warehouse.beds[truck], crate)
	return nil
end

-- Whether a crate can go on a truck now; nil, or why not.
function TruckRules.cannotLoad(warehouse, now: number): string?
	local _, why = TruckRules.loadable(warehouse, now)
	return why
end

-- Loads a crate onto the first truck with room. Returns nil (and the truck),
-- or why not.
function TruckRules.load(warehouse, crate, now: number): (string?, number?)
	local truck, why = TruckRules.loadable(warehouse, now)
	if not truck then
		return why, nil
	end
	warehouse.beds[truck] = warehouse.beds[truck] or {}
	table.insert(warehouse.beds[truck], crate)
	return nil, truck
end

-- The price a crate's unit locks at: the market price, plus the Premium
-- contracts' share for Legendary and Mythic crops.
function TruckRules.unitPrice(cropId: string, market: number, premium: number?): number
	local rarity = Crops.ById[cropId].rarity
	if premium and premium > 0 and (rarity == "Legendary" or rarity == "Mythic") then
		return math.floor(market * (1 + premium) + 0.5)
	end
	return market
end

-- What a bed would lock for if it left now: total coins and each crate's
-- price and coins. priceAt(cropId) = the market price of a standard unit.
function TruckRules.quote(bed, priceAt, premium: number?)
	local total, lines = 0, {}
	for _, crate in bed do
		local price = TruckRules.unitPrice(crate.crop, priceAt(crate.crop), premium)
		local coins = CrateRules.value(crate, price)
		total += coins
		table.insert(lines, { crop = crate.crop, key = crate.key, units = crate.units, grade = crate.grade, price = price, coins = coins })
	end
	return total, lines
end

-- Sends truck `truck` off: the prices lock now. roundTrip: seconds (default
-- the level's; a Driver makes it shorter). Returns the run, or nil and why
-- not ("TruckEmpty" · "TruckAway").
function TruckRules.dispatch(warehouse, truck: number, now: number, priceAt, roundTrip: number?)
	local bed = warehouse.beds[truck]
	if not bed or #bed == 0 then
		return nil, "TruckEmpty"
	elseif not TruckRules.isHome(warehouse, truck, now) then
		return nil, "TruckAway"
	end
	local info = TruckRules.info(warehouse)
	local total, lines = TruckRules.quote(bed, priceAt, info.premium)
	local trip = roundTrip or info.roundTrip
	local run = {
		id = `{math.floor(now * 1000)}-{truck}`,
		truck = truck,
		crates = lines,
		coins = total,
		departAt = now,
		arriveAt = now + trip / 2,
		returnAt = now + trip,
		paid = false,
	}
	table.insert(warehouse.trucks, run)
	table.clear(bed)
	return run, nil
end

-- Runs that have reached the City and aren't paid yet: marked paid and
-- returned, for the caller to pay out.
function TruckRules.collect(warehouse, now: number)
	local due = {}
	for _, run in warehouse.trucks do
		if not run.paid and run.arriveAt <= now then
			run.paid = true
			table.insert(due, run)
		end
	end
	return due
end

-- Forgets runs that are paid and home. Returns how many came home.
function TruckRules.tidy(warehouse, now: number): number
	local back = 0
	for i = #warehouse.trucks, 1, -1 do
		local run = warehouse.trucks[i]
		if run.paid and run.returnAt <= now then
			table.remove(warehouse.trucks, i)
			back += 1
		end
	end
	return back
end

return TruckRules
