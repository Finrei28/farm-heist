-- Farm Level from XP, and how much XP things give (docs/GameDesign.md
-- §4.15). XP is kept as a number in the save (sales give fractions); the
-- level is worked out from it and cached in data.level. Land Permits follow
-- the level (shared/LandRules). tests/progression.test.luau.
local Config = require(script.Parent.Config.Progression)
local Crops = require(script.Parent.Config.Crops)

local ProgressionRules = {}

-- Total XP needed to reach `level` (level 1 = 0).
function ProgressionRules.xpForLevel(level: number): number
	if level <= 1 then
		return 0
	end
	return math.floor(Config.XP_BASE * (level - 1) ^ Config.XP_POWER + 0.5)
end

-- The level `xp` reaches (capped at MAX_LEVEL).
function ProgressionRules.levelFor(xp: number): number
	local level = 1
	while level < Config.MAX_LEVEL and xp >= ProgressionRules.xpForLevel(level + 1) do
		level += 1
	end
	return level
end

-- For the HUD's level bar: level, XP into it, XP the level spans (nil at max).
function ProgressionRules.progress(xp: number)
	local level = ProgressionRules.levelFor(xp)
	local from = ProgressionRules.xpForLevel(level)
	if level >= Config.MAX_LEVEL then
		return level, xp - from, nil
	end
	return level, xp - from, ProgressionRules.xpForLevel(level + 1) - from
end

-- XP for picking a crop: per minute of the stage it grew, by rarity. byWorker:
-- a Farmhand picked it while you were online (half).
function ProgressionRules.harvestXp(cropId: string, regrowing: boolean?, byWorker: boolean?): number
	local crop = Crops.ById[cropId]
	local minutes = (if regrowing then crop.regrow.seconds else crop.grow) / 60
	local xp = minutes * Config.HARVEST_XP_PER_MINUTE[crop.rarity]
	return if byWorker then xp * Config.WORKER_HARVEST else xp
end

-- XP for coins of sales made while you're online.
function ProgressionRules.salesXp(coins: number): number
	return math.max(0, coins) / Config.SALES_COINS_PER_XP
end

-- Adds XP to a save (data.xp, data.level). Returns the old and new level;
-- the caller announces level-ups and new Land Permits.
function ProgressionRules.addXp(data, amount: number): (number, number)
	local before = data.level
	data.xp += math.max(0, amount)
	data.level = ProgressionRules.levelFor(data.xp)
	return before, data.level
end

return ProgressionRules
