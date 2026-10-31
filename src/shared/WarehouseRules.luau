-- Warehouse Levels (docs/GameDesign.md §4.6, Config/Warehouse): everything a
-- level gives, added up from the table, what's new at each one, and
-- levelling up. tests/warehouse.test.luau.
--
-- warehouse (in the save) = { level, build?, routes, beds, dock, sorted, trucks, driverRule }
--   build:  { to, left } a new building going up (seconds of work left)
--   routes: [cropId] = share for the truck (0–1; 1 = all, the default) or "Keep"
--   beds:   [truck] = { crate } loaded on each truck (shared/TruckRules)
--   dock:   { crate } waiting for a truck (the rack, the Cold Room)
--   sorted: { batch } washed and graded, waiting for a Packer
--   driverRule: the Drivers send a truck once it's full and the price is at
--               least this × the base value (0: whenever it's full)
local Warehouse = require(script.Parent.Config.Warehouse)
local Workers = require(script.Parent.Config.Workers)

local WarehouseRules = {}

WarehouseRules.MAX_LEVEL = #Warehouse.LEVELS

local cache = {}

-- The building stage (1–4) at a level.
function WarehouseRules.stage(level: number): number
	local stage = 1
	for index, building in Warehouse.BUILDINGS do
		if level >= building.from then
			stage = index
		end
	end
	return stage
end

-- Everything at Warehouse Level n: cost, farmLevel, trucks, truckCrates,
-- roundTrip, hold, conveyors, premium, and the flags (Config/Warehouse),
-- plus stage, building and truck (the model's name).
function WarehouseRules.level(n: number)
	n = math.clamp(n, 1, WarehouseRules.MAX_LEVEL)
	if cache[n] then
		return cache[n]
	end
	local info = { premium = 0 }
	for i = 1, n do
		for key, value in Warehouse.LEVELS[i] do
			info[key] = value
		end
	end
	info.level = n
	info.cost = Warehouse.LEVELS[n].cost
	info.farmLevel = Warehouse.LEVELS[n].farmLevel
	info.stage = WarehouseRules.stage(n)
	info.building = Warehouse.BUILDINGS[info.stage]
	info.truck = info.building.truck
	cache[n] = info
	return info
end

local ORDINALS = { "", "2nd", "3rd", "4th", "5th" }

-- "room for a Sorter", "room for a 2nd Packer".
local function room(index: number, name: string): string
	return if index == 1 then `room for a {name}` else `room for a {ORDINALS[index] or `{index}th`} {name}`
end

-- Worker slots that open at exactly this level, as { "room for a 2nd Sorter", ... }.
local function slotsOpening(n: number): { string }
	local lines = {}
	for _, typeName in Workers.ORDER do
		local kind = Workers.TYPES[typeName]
		local at = kind.slots and kind.slots.warehouse
		if at then
			local index = table.find(at, n)
			if index and not (kind.untilLevel and n >= kind.untilLevel) then
				table.insert(lines, room(index, kind.name))
			end
		end
	end
	if n == Workers.DRIVERS_FROM then
		table.insert(lines, room(1, "Driver"))
	elseif n > Workers.DRIVERS_FROM and WarehouseRules.level(n).trucks > WarehouseRules.level(n - 1).trucks then
		table.insert(lines, room(WarehouseRules.level(n).trucks, "Driver"))
	end
	return lines
end

-- What's new at Warehouse Level n, for the ladder, in plain words:
-- { "a new building: the Distribution Warehouse (2 min to build)", "Box Truck: 12 crates", ... }.
function WarehouseRules.news(n: number): { string }
	local info = WarehouseRules.level(n)
	local before = if n > 1 then WarehouseRules.level(n - 1) else nil
	local lines = {}
	local function changed(key)
		return before == nil or info[key] ~= before[key]
	end
	if before and info.stage ~= before.stage then
		table.insert(lines, `a new building: the {info.building.name} ({info.building.buildSeconds // 60} min to build)`)
	end
	local truckName = Warehouse.TRUCK_NAMES[info.truck]
	if changed("trucks") and info.trucks > 1 then
		table.insert(lines, `{info.trucks} {truckName}s, {info.truckCrates} crates each`)
	elseif changed("truck") then
		table.insert(lines, `{truckName}: {info.truckCrates} crates`)
	elseif changed("truckCrates") then
		table.insert(lines, `trucks carry {info.truckCrates} crates`)
	end
	if changed("roundTrip") then
		table.insert(lines, `trips take {info.roundTrip} s{if info.express and not before.express then " (the express lane)" else ""}`)
	end
	if changed("hold") then
		table.insert(lines, if info.stage == 1 then `the dock rack holds {info.hold}` else `the Cold Room holds {info.hold} crates`)
	end
	if changed("conveyors") and info.conveyors > 1 then
		table.insert(lines, `conveyors {math.floor((info.conveyors - 1) * 100 + 0.5)}% faster`)
	end
	if info.handCart and not (before and before.handCart) then
		table.insert(lines, `a hand cart ({Warehouse.HAND_CART} crates at a time)`)
	end
	if info.splits and not (before and before.splits) then
		table.insert(lines, "split a crop between truck and store")
	end
	if info.washLine and not (before and before.washLine) then
		table.insert(lines, `the Wash Line (Sorters +{math.floor(Warehouse.WASH_LINE * 100 + 0.5)}% grade A)`)
	end
	if changed("premium") and info.premium > 0 then
		table.insert(lines, `Premium contracts (Legendary and Mythic crates +{math.floor(info.premium * 100 + 0.5)}%)`)
	end
	if info.goldTrim then
		table.insert(lines, "gold trim on the building")
	end
	for _, slot in slotsOpening(n) do
		table.insert(lines, slot)
	end
	return lines
end

-- Whether the warehouse can go up a level now: nil, or why not:
-- "MaxLevel" · "Building" · "NeedLevel" · "NoCoins".
function WarehouseRules.cannotUpgrade(warehouse, farmLevel: number, coins: number): string?
	if warehouse.level >= WarehouseRules.MAX_LEVEL then
		return "MaxLevel"
	elseif warehouse.build then
		return "Building"
	end
	local nextLevel = WarehouseRules.level(warehouse.level + 1)
	if farmLevel < nextLevel.farmLevel then
		return "NeedLevel"
	elseif coins < nextLevel.cost then
		return "NoCoins"
	end
	return nil
end

-- Goes up a level (the caller has taken the coins). A level that comes with
-- a new building starts it going up instead: build = { to, left }; the old
-- building keeps working until finish. Returns "Built" or "Building".
function WarehouseRules.upgrade(warehouse): string
	local to = warehouse.level + 1
	local info = WarehouseRules.level(to)
	if info.stage ~= WarehouseRules.stage(warehouse.level) and info.building.buildSeconds > 0 then
		warehouse.build = { to = to, left = info.building.buildSeconds }
		return "Building"
	end
	WarehouseRules.finish(warehouse, to)
	return "Built"
end

-- Reaches level `to` (an instant level, or a building that's done): a bed
-- for each truck.
function WarehouseRules.finish(warehouse, to: number)
	warehouse.level = to
	warehouse.build = nil
	for truck = #warehouse.beds + 1, WarehouseRules.level(to).trucks do
		warehouse.beds[truck] = {}
	end
end

-- Seconds of work on a building in progress: true once it's done (and the
-- level reached).
function WarehouseRules.work(warehouse, seconds: number): boolean
	local build = warehouse.build
	if not build then
		return false
	end
	build.left -= seconds
	if build.left <= 0 then
		WarehouseRules.finish(warehouse, build.to)
		return true
	end
	return false
end

-- Where a crop's crates go: the share for the truck (0–1), or nil to keep
-- it in the barn (workers leave it alone). Without split routes a split
-- counts as all to the truck.
function WarehouseRules.route(warehouse, cropId: string): number?
	local route = warehouse.routes[cropId]
	if route == "Keep" then
		return nil
	end
	local share = if type(route) == "number" then math.clamp(route, 0, 1) else 1
	if share > 0 and share < 1 and not WarehouseRules.level(warehouse.level).splits then
		return 1
	end
	return share
end

-- The save from before Warehouse Levels (week 2's `tier` and one `bed`).
function WarehouseRules.migrate(warehouse)
	if warehouse.tier then
		warehouse.level = math.max(warehouse.level or 1, Warehouse.BUILDINGS[warehouse.tier + 1].from)
		warehouse.tier = nil
	end
	if warehouse.bed then
		if #(warehouse.beds[1] or {}) == 0 then
			warehouse.beds[1] = warehouse.bed
		else
			for _, crate in warehouse.bed do
				table.insert(warehouse.dock, crate)
			end
		end
		warehouse.bed = nil
	end
	warehouse.buildingUntil = nil
	warehouse.queues = nil
	for truck = #warehouse.beds + 1, WarehouseRules.level(warehouse.level).trucks do
		warehouse.beds[truck] = {}
	end
end

return WarehouseRules
