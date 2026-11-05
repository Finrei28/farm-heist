-- Packed crates (docs/GameDesign.md §4.6, §4.8): one stock for your trucks and
-- your store (the user, 2026-11-05: "packed crate/produce can be used for both
-- the truck and the store"). However a crate is packed, by hand or by the
-- crew, it goes into data.store.stockroom, and from there onto a truck (you
-- pick which at the dock: client DockController) or a display, whichever you
-- like. It holds what the dock rack or Cold Room and the store's stockroom
-- hold together, and when it's full, packing waits: nothing is pushed
-- somewhere it wasn't meant to go.
--
-- The Routes only tell the crew what to do with a crop (crewUse): Shed Hands
-- and Loaders load what's routed to the truck, Stockers put out what's routed
-- to the store, and by hand you can use any crate either way. A crate from a
-- split remembers which way it leans (crate.lean). A mutated crate only goes
-- by truck (CrateRules.storeable). The crew leaves mutated and Giant crops in
-- the barn unless you've chosen them (crewTakes). tests/pack.test.luau.
local BarnRules = require(script.Parent.BarnRules)
local CrateRules = require(script.Parent.CrateRules)
local Crops = require(script.Parent.Config.Crops)
local StoreLayout = require(script.Parent.StoreLayout)
local WarehouseRules = require(script.Parent.WarehouseRules)

local PackRules = {}

-- How many crates the stock holds: the rack or Cold Room's room and the
-- stockroom's, so either upgrade adds to it. data: a save, or the client's state.
function PackRules.size(data): number
	return WarehouseRules.level(data.warehouse.level).hold + StoreLayout.level(data.store.level).stockroom
end

-- How many more fit (goods coming back from a display or a truck always do,
-- even past full).
function PackRules.room(data): number
	return math.max(0, PackRules.size(data) - #data.store.stockroom)
end

-- Whether the crew may pack a barn stack: its crop isn't kept, and if it's
-- mutated or Giant you've picked 📦 Pack for that kind in the Routes tab
-- (warehouse.packs; the user, 2026-11-05: "Allow selecting which mutated
-- produce to pack or not pack"). A Giant mutated crop needs both picked.
function PackRules.crewTakes(warehouse, key: string): boolean
	local cropId, mutation, giant = BarnRules.parse(key)
	if WarehouseRules.route(warehouse, cropId) == nil then
		return false
	end
	local packs = warehouse.packs or {}
	return (mutation == nil or packs[mutation] == true) and (not giant or packs.Giant == true)
end

-- What the crew does with a crate: "Truck", "Store", or nil (it's kept for
-- you: the crop's route is Keep).
function PackRules.crewUse(warehouse, crate): string?
	local share = WarehouseRules.route(warehouse, crate.crop)
	if share == nil then
		return nil
	elseif not CrateRules.storeable(crate.key or "") then
		return "Truck"
	elseif share >= 1 then
		return "Truck"
	elseif share <= 0 then
		return "Store"
	end
	return crate.lean or "Truck"
end

-- For ShopRules' `allow`: the crates the crew may put out.
function PackRules.forStore(warehouse): (any) -> boolean
	return function(crate): boolean
		return PackRules.crewUse(warehouse, crate) == "Store"
	end
end

local function firstFor(data, use: string): number?
	for index, crate in data.store.stockroom do
		if PackRules.crewUse(data.warehouse, crate) == use then
			return index
		end
	end
	return nil
end

-- Where in the stock the next crate for the crew to load is, or nil.
function PackRules.nextForTruck(data): number?
	return firstFor(data, "Truck")
end

-- Where in the stock the next crate for a Stocker is, or nil.
function PackRules.nextForStore(data): number?
	return firstFor(data, "Store")
end

-- The stock as you see it standing at it: crates the crew will put out in the
-- store's stockroom, the rest on the rack or in the Cold Room. Only where
-- they're drawn: they're all one stock.
function PackRules.sides(data): ({ any }, { any })
	local rack, shelf = {}, {}
	for _, crate in data.store.stockroom do
		table.insert(if PackRules.crewUse(data.warehouse, crate) == "Store" then shelf else rack, crate)
	end
	return rack, shelf
end

local function keyOf(crate): string
	return crate.key or `{crate.crop}||`
end

-- Crates that are alike, for choosing from: { { key, crop, grade, crates,
-- units } }, the most valuable crops first.
function PackRules.stacks(crates)
	local byId, list = {}, {}
	for _, crate in crates do
		local id = `{keyOf(crate)}/{crate.grade}`
		local stack = byId[id]
		if not stack then
			stack = { key = keyOf(crate), crop = crate.crop, grade = crate.grade, crates = 0, units = 0 }
			byId[id] = stack
			table.insert(list, stack)
		end
		stack.crates += 1
		stack.units += crate.units
	end
	table.sort(list, function(a, b)
		local va, vb = Crops.ById[a.crop].value, Crops.ById[b.crop].value
		if va ~= vb then
			return va > vb
		elseif a.key ~= b.key then
			return a.key < b.key
		end
		return a.grade < b.grade
	end)
	return list
end

-- Takes up to `count` crates of a stack out of a list, oldest first. Returns
-- them.
function PackRules.take(crates, key: string, grade: string, count: number)
	local taken, index = {}, 1
	while index <= #crates and #taken < count do
		local crate = crates[index]
		if keyOf(crate) == key and crate.grade == grade then
			table.insert(taken, table.remove(crates, index))
		else
			index += 1
		end
	end
	return taken
end

return PackRules
