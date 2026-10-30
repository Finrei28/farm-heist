-- How a planted tile grows and is harvested (docs/GameDesign.md §4.2). Pure
-- functions over plain tables, so they're tested (tests/growth.test.luau).
--
-- A tile is
--   { crop = cropId, progress = 0–1, harvestsLeft, regrowing, watered, fresh, leave }
-- progress is the share of the current stage done: the first grow, or a
-- regrow for crops that give several harvests. Services settle growth from
-- elapsed time (FieldService online, every few seconds; DataService's
-- welcome-back settle offline), so nothing ticks while a player is away.
--   speed: 1 online (times weather, sprinklers, a Growth Boost);
--          Growth.OFFLINE_RATE while the owner is offline (GrowthRules.offline).
local Crops = require(script.Parent.Config.Crops)
local Growth = require(script.Parent.Config.Growth)

local GrowthRules = {}

-- A new tile. fresh: the first crop on newly cleared land (+25% growth).
function GrowthRules.plant(cropId: string, fresh: boolean?)
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
	}
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
-- regrows goes back to growing; anything else leaves the tile empty).
function GrowthRules.harvest(tile): (boolean, boolean)
	if tile.progress < 1 then
		return false, true
	end
	tile.fresh = false -- (fresh soil helps the first crop only)
	if tile.harvestsLeft > 0 then
		tile.harvestsLeft -= 1
		tile.regrowing = true
		tile.progress = 0
		tile.watered = false
		return true, true
	end
	return true, false
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

-- Coins per tile-minute at base value, after the seed (docs §6.1).
function GrowthRules.profitPerMinute(cropId: string): number
	local crop = Crops.ById[cropId]
	local profit = crop.value * GrowthRules.harvests(cropId) - crop.seed
	return profit / (GrowthRules.lifeSeconds(cropId) / 60)
end

return GrowthRules
