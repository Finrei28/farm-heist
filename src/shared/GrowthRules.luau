-- How a planted tile grows and is harvested (docs/GameDesign.md §4.2). Pure
-- functions over plain tables, so they're tested (tests/growth.test.luau).
--
-- A tile is
--   { crop = cropId, progress = 0–1, harvestsLeft, regrowing, watered, fresh, leave, yield, mutation? }
-- progress is the share of the current stage done: the first grow, or a
-- regrow for crops that give several harvests. yield: how many it gives
-- when it's picked (6 carrots, 1 pumpkin ...: rolled when it's planted, and
-- again for each regrow, from the crop's perPatch and the Field Level), so
-- the patch can show them all while it grows. Services settle growth from
-- elapsed time (FieldService online, every few seconds; DataService's
-- welcome-back settle offline), so nothing ticks while a player is away.
-- mutation: what the weather turned the ripe crop into while it was left
-- in the field (shared/WeatherRules); picking it ends it.
--   speed: 1 online (times weather, sprinklers, a Growth Boost);
--          Growth.OFFLINE_RATE while the owner is offline (GrowthRules.offline).
local Crops = require(script.Parent.Config.Crops)
local Growth = require(script.Parent.Config.Growth)

local GrowthRules = {}

-- How many a patch of this crop gives at a Field Level's `yield` (×
-- perPatch): the whole part always, and one more if `roll` (0–1) falls
-- under what's left (8.1 carrots: 8, and 9 one time in ten).
function GrowthRules.rollYield(cropId: string, yield: number?, roll: number?): number
	local exact = Crops.ById[cropId].perPatch * (yield or 1)
	local whole = math.floor(exact + 1e-9)
	return whole + (if (roll or 1) < exact - whole - 1e-9 then 1 else 0)
end

-- A new tile. fresh: the first crop on newly cleared land (+25% growth);
-- yield: how many it'll give (default: the crop's perPatch).
function GrowthRules.plant(cropId: string, fresh: boolean?, yield: number?)
	local crop = Crops.ById[cropId]
	assert(crop, `unknown crop {cropId}`)
	return {
		crop = cropId,
		progress = 0,
		harvestsLeft = if crop.regrow then crop.regrow.times else 0,
		regrowing = false,
		watered = false,
		fresh = fresh == true,
		leave = false, -- the 🚩 "Leave in field" flag: Farmhands skip it
		yield = yield or crop.perPatch,
	}
end

-- How many the tile gives when it's picked.
function GrowthRules.yieldOf(tile): number
	return tile.yield or Crops.ById[tile.crop].perPatch
end

-- How many a thief can take from the tile at once: all of it, but only one
-- at a time of the big ones (a pumpkin, a melon).
function GrowthRules.carryOf(tile): number
	local carry = Crops.ById[tile.crop].carry
	return math.min(GrowthRules.yieldOf(tile), carry or math.huge)
end

-- Seconds the current stage takes at speed 1, before fresh soil.
function GrowthRules.stageSeconds(tile): number
	local crop = Crops.ById[tile.crop]
	return if tile.regrowing then crop.regrow.seconds else crop.grow
end

local function soil(tile): number
	return if tile.fresh then 1 + Growth.FRESH_SOIL else 1
end

-- Grows a tile for `seconds` at `speed` (see above). Stops at ripe.
function GrowthRules.advance(tile, seconds: number, speed: number?)
	if tile.progress >= 1 or seconds <= 0 then
		return
	end
	local rate = (speed or 1) * soil(tile) / GrowthRules.stageSeconds(tile)
	local progress = tile.progress + seconds * rate
	-- (many small steps add up a hair short of 1 in floating point: a crop
	-- that has had its full time is ripe)
	tile.progress = if progress >= 1 - 1e-9 then 1 else progress
end

-- Growth while the owner was offline.
function GrowthRules.offline(tile, seconds: number)
	GrowthRules.advance(tile, seconds, Growth.OFFLINE_RATE)
end

function GrowthRules.isRipe(tile): boolean
	return tile.progress >= 1
end

-- Seconds until ripe at `speed`.
function GrowthRules.secondsLeft(tile, speed: number?): number
	if tile.progress >= 1 then
		return 0
	end
	return (1 - tile.progress) * GrowthRules.stageSeconds(tile) / ((speed or 1) * soil(tile))
end

-- Watering takes WATER_CUT off the time left in this stage, once per stage.
-- Returns whether it did anything.
function GrowthRules.water(tile): boolean
	if tile.watered or tile.progress >= 1 then
		return false
	end
	tile.progress += (1 - tile.progress) * Growth.WATER_CUT
	tile.watered = true
	return true
end

-- Picks a ripe tile. Returns ok and whether the plant stays (a crop that
-- regrows goes back to growing, giving `nextYield` next time; anything else
-- leaves the tile empty). How many it gave: yieldOf, before picking.
function GrowthRules.harvest(tile, nextYield: number?): (boolean, boolean)
	if tile.progress < 1 then
		return false, true
	end
	tile.fresh = false -- (fresh soil helps the first crop only)
	tile.mutation = nil -- (the next fruit starts plain)
	if tile.harvestsLeft > 0 then
		tile.harvestsLeft -= 1
		tile.regrowing = true
		tile.progress = 0
		tile.watered = false
		tile.yield = nextYield or Crops.ById[tile.crop].perPatch
		return true, true
	end
	return true, false
end

-- A thief takes `count` off a ripe tile. If that's all of it, it's picked
-- (as harvest); otherwise the rest stays ripe for the owner. Returns
-- whether the plant stays (false: the tile is empty now).
function GrowthRules.take(tile, count: number, nextYield: number?): boolean
	local left = GrowthRules.yieldOf(tile) - count
	if left > 0 then
		tile.yield = left
		return true
	end
	local _, stays = GrowthRules.harvest(tile, nextYield)
	return stays
end

-- Harvests one seed gives over its whole life.
function GrowthRules.harvests(cropId: string): number
	local crop = Crops.ById[cropId]
	return 1 + (if crop.regrow then crop.regrow.times else 0)
end

-- Seconds from planting to the last harvest, at speed 1.
function GrowthRules.lifeSeconds(cropId: string): number
	local crop = Crops.ById[cropId]
	return crop.grow + (if crop.regrow then crop.regrow.times * crop.regrow.seconds else 0)
end

-- Coins a patch gives at base value (a picking, for crops that regrow),
-- at a Field Level's `yield` (default Level 1).
function GrowthRules.patchValue(cropId: string, yield: number?): number
	local crop = Crops.ById[cropId]
	return crop.value * crop.perPatch * (yield or 1)
end

-- Coins per tile-minute at base value, after the seed (docs §6.1).
function GrowthRules.profitPerMinute(cropId: string, yield: number?): number
	local crop = Crops.ById[cropId]
	local profit = GrowthRules.patchValue(cropId, yield) * GrowthRules.harvests(cropId) - crop.seed
	return profit / (GrowthRules.lifeSeconds(cropId) / 60)
end

return GrowthRules
