-- The truck (docs/GameDesign.md §4.6): crates are loaded into its bed while
-- it's home; dispatching locks every crate's price at that moment's market
-- price; the run is paid when the truck reaches the City (half the round
-- trip) and the truck is home again at the end of it. Runs are saved, so a
-- run that arrives while you're away is paid the next time you join, on any
-- server. tests/truck.test.luau.
--
-- warehouse (in the save) = { tier, bed = { crate }, dock = { crate }, trucks = { run } }
--   bed:   crates loaded, waiting to leave (shared/CrateRules)
--   dock:  crates set down by the ramp (dropped on the way to the truck)
--   run:   { id, crates = { crate + price + coins }, coins, departAt, arriveAt, returnAt, paid }
local Warehouse = require(script.Parent.Config.Warehouse)
local CrateRules = require(script.Parent.CrateRules)

local TruckRules = {}

function TruckRules.tier(warehouse)
	return Warehouse.TIERS[(warehouse.tier or 0) + 1]
end

-- Trucks home at `now` (not out on a run).
function TruckRules.home(warehouse, now: number): number
	local away = 0
	for _, run in warehouse.trucks do
		if run.returnAt > now then
			away += 1
		end
	end
	return math.max(0, TruckRules.tier(warehouse).trucks - away)
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

-- Whether a crate can go in the bed now; nil, or why not.
function TruckRules.cannotLoad(warehouse, now: number): string?
	if TruckRules.home(warehouse, now) < 1 then
		return "TruckAway"
	elseif #warehouse.bed >= TruckRules.tier(warehouse).truckCrates then
		return "TruckFull"
	end
	return nil
end

function TruckRules.load(warehouse, crate, now: number): string?
	local failure = TruckRules.cannotLoad(warehouse, now)
	if failure then
		return failure
	end
	table.insert(warehouse.bed, crate)
	return nil
end

-- What the bed would lock for if it left now: total coins and each crate's
-- price and coins. priceAt(cropId) = the market price of a standard unit.
function TruckRules.quote(bed, priceAt)
	local total, lines = 0, {}
	for _, crate in bed do
		local price = priceAt(crate.crop)
		local coins = CrateRules.value(crate, price)
		total += coins
		table.insert(lines, { crop = crate.crop, key = crate.key, units = crate.units, grade = crate.grade, price = price, coins = coins })
	end
	return total, lines
end

-- Sends the loaded truck off: the prices lock now. Returns the run, or nil
-- and why not.
function TruckRules.dispatch(warehouse, now: number, priceAt)
	if #warehouse.bed == 0 then
		return nil, "TruckEmpty"
	elseif TruckRules.home(warehouse, now) < 1 then
		return nil, "TruckAway"
	end
	local total, lines = TruckRules.quote(warehouse.bed, priceAt)
	local roundTrip = TruckRules.tier(warehouse).roundTrip
	local run = {
		id = `{math.floor(now * 1000)}`,
		crates = lines,
		coins = total,
		departAt = now,
		arriveAt = now + roundTrip / 2,
		returnAt = now + roundTrip,
		paid = false,
	}
	table.insert(warehouse.trucks, run)
	table.clear(warehouse.bed)
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
