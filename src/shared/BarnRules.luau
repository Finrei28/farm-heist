-- The Barn inventory (docs/GameDesign.md §4.5). Crops stack by crop,
-- mutation and Giant, under a string key (saves are JSON: no table keys):
--   "Carrot||"  a plain Carrot · "Pumpkin|Wet|"  a Wet Pumpkin · "Pumpkin||G"  a Giant
-- Harvesting stops when the barn is full; deposits and returned loot always
-- go in (even over capacity), so callers decide whether capacity applies.
-- tests/barn.test.luau.
--
-- inventory (in the save) = { crops = { [key] = units }, seeds = { [cropId] = n }, items = {...} }
local Barn = require(script.Parent.Config.Barn)

local BarnRules = {}

function BarnRules.key(cropId: string, mutation: string?, giant: boolean?): string
	return `{cropId}|{mutation or ""}|{if giant then "G" else ""}`
end

-- cropId, mutation (or nil), giant
function BarnRules.parse(key: string): (string, string?, boolean)
	local cropId, mutation, giant = string.match(key, "^([^|]*)|([^|]*)|([^|]*)$")
	if not cropId then
		return key, nil, false
	end
	return cropId, if mutation == "" then nil else mutation, giant == "G"
end

-- Crop units in the barn (all stacks).
function BarnRules.units(inventory): number
	local total = 0
	for _, count in inventory.crops do
		total += count
	end
	return total
end

-- bigger: the Bigger Barn pass (Config/Monetization: ×2.5).
function BarnRules.capacity(silo: number?, bigger: boolean?): number
	local level = math.clamp(silo or 0, 0, #Barn.SILO_COST)
	return if bigger then math.floor(Barn.CAPACITY[level] * Barn.BIGGER) else Barn.CAPACITY[level]
end

-- A save's barn space (its Silo, and the Bigger Barn pass in data.passes).
function BarnRules.capacityOf(data): number
	return BarnRules.capacity(data.silo, data.passes ~= nil and data.passes.BiggerBarn == true)
end

-- Room for `count` more units from a harvest in this save's barn.
function BarnRules.hasRoom(data, count: number?): boolean
	return BarnRules.units(data.inventory) + (count or 1) <= BarnRules.capacityOf(data)
end

function BarnRules.addCrops(inventory, key: string, count: number)
	inventory.crops[key] = (inventory.crops[key] or 0) + count
end

-- Takes `count` units of a stack. Returns whether there were enough.
function BarnRules.takeCrops(inventory, key: string, count: number): boolean
	local have = inventory.crops[key] or 0
	if count < 1 or have < count then
		return false
	end
	inventory.crops[key] = if have == count then nil else have - count
	return true
end

-- Uses one seed (planting). Returns whether there was one.
function BarnRules.takeSeed(inventory, cropId: string): boolean
	local have = inventory.seeds[cropId] or 0
	if have < 1 then
		return false
	end
	inventory.seeds[cropId] = if have == 1 then nil else have - 1
	return true
end

function BarnRules.addSeeds(inventory, cropId: string, count: number)
	inventory.seeds[cropId] = (inventory.seeds[cropId] or 0) + count
end

return BarnRules
