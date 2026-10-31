-- Crates (docs/GameDesign.md §4.6). At the Packing Shed bench a crate is
-- packed from one barn stack, up to the rarity's crate size (a crate can go
-- out part-full), and washed by hand to grade A (×1.15) or B. A crate is
--   { crop = cropId, key = barn stack key, units = n, grade = "A" | "B" }
-- and goes to the truck (priced when it leaves) or the Farm Stand's
-- stockroom (shared/ShopRules). tests/crate.test.luau.
local BarnRules = require(script.Parent.BarnRules)
local Crops = require(script.Parent.Config.Crops)
local Rarities = require(script.Parent.Config.Rarities)
local Warehouse = require(script.Parent.Config.Warehouse)

local WASH = Warehouse.WASH

local CrateRules = {}

-- Units that fit in one crate of this crop.
function CrateRules.size(cropId: string): number
	return Rarities.ById[Crops.ById[cropId].rarity].crate
end

-- The wash meter (0–1) after holding for `seconds`. It stays full if you
-- keep holding: over-sprayed is grade B too.
function CrateRules.meter(seconds: number): number
	return math.clamp(seconds / WASH.fill, 0, 1)
end

-- The grade for a hold of `seconds`, with `slack` seconds of give either
-- side of the green (the server's allowance for lag).
function CrateRules.grade(seconds: number, slack: number?): string
	local give = slack or 0
	local from = WASH.greenMin * WASH.fill - give
	local to = WASH.greenMax * WASH.fill + give
	return if seconds >= from and seconds <= to then "A" else "B"
end

-- Packs a crate from barn stack `key`, taking up to a crate's worth. nil if
-- the stack is empty or isn't a crop.
function CrateRules.pack(inventory, key: string, grade: string)
	local cropId = BarnRules.parse(key)
	if not Crops.ById[cropId] then
		return nil
	end
	local units = math.min(inventory.crops[key] or 0, CrateRules.size(cropId))
	if units <= 0 or not BarnRules.takeCrops(inventory, key, units) then
		return nil
	end
	return { crop = cropId, key = key, units = units, grade = if grade == "A" then "A" else "B" }
end

-- What a unit of this crate is worth when a standard unit sells for `price`.
function CrateRules.unitPrice(crate, price: number): number
	return price * (if crate.grade == "A" then Warehouse.GRADE_A else 1)
end

-- Coins for the whole crate at `price` a standard unit.
function CrateRules.value(crate, price: number): number
	return math.floor(crate.units * CrateRules.unitPrice(crate, price) + 0.5)
end

return CrateRules
