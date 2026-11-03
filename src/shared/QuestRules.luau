-- Daily quests, the login streak and the Cropdex (docs/GameDesign.md
-- §4.15, §4.16; Config/Quests). Pure functions over the save's tables
-- (tests/quests.test.luau); QuestService applies them.
--
-- quests  = { day, list = { { id, n, reward, progress, claimed } }, bonusClaimed }
-- streak  = { days (1–7, the last day claimed), lastClaimDay }
-- cropdex = { seen = { ["cropId|mutation"] = true }, tiers = { [rarity] = true }, sets = { [mutation] = true } }
local Config = require(script.Parent.Config.Quests)
local Crops = require(script.Parent.Config.Crops)
local Format = require(script.Parent.Format)
local Rarities = require(script.Parent.Config.Rarities)
local Weather = require(script.Parent.Config.Weather)

local QuestRules = {}

-- The day number (UTC) at unix time t: quests and the streak go by it.
function QuestRules.day(t: number): number
	return t // 86400
end

-- Your Farm Level's tier (Config.TIERS): its index and its × on coins.
function QuestRules.tier(level: number): (number, number)
	local index, scale = 1, 1
	for i, tier in Config.TIERS do
		if level >= tier.from then
			index, scale = i, tier.scale
		end
	end
	return index, scale
end

-- 1,500 (for quests' words and notes).
QuestRules.number = Format.number

-- "Harvest 120 crops", "Arrest a thief", "Earn 1,500 coins in your store".
function QuestRules.text(quest): string
	local def = nil
	for _, entry in Config.POOL do
		if entry.id == quest.id then
			def = entry
		end
	end
	if not def then
		return quest.id
	end
	local template = if quest.n == 1 then def.one else def.many
	return (string.gsub(template, "{n}", QuestRules.number(quest.n)))
end

-- Today's three quests for a player. ctx = { level, raids (the Sprout
-- Shield is over) }. The same all day for the same player.
function QuestRules.roll(userId: number, day: number, ctx)
	local tier, scale = QuestRules.tier(ctx.level)
	local options = {}
	for _, def in Config.POOL do
		if (not def.raids or ctx.raids) and ctx.level >= (def.level or 1) then
			table.insert(options, def)
		end
	end
	local rng = Random.new((userId % 1_000_003) * 104_729 + day * 7919 + 17)
	local list = {}
	for _ = 1, math.min(Config.SLOTS, #options) do
		local def = table.remove(options, rng:NextInteger(1, #options))
		table.insert(list, { id = def.id, stat = def.stat, n = def.n[tier], reward = def.reward * scale, progress = 0, claimed = false })
	end
	return list
end

-- A new day's quests if the day has turned (or there are none). Returns
-- whether it changed.
function QuestRules.refresh(quests, userId: number, t: number, ctx): boolean
	local day = QuestRules.day(t)
	if quests.day == day and #quests.list > 0 then
		return false
	end
	quests.day = day
	quests.list = QuestRules.roll(userId, day, ctx)
	quests.bonusClaimed = false
	return true
end

function QuestRules.done(quest): boolean
	return quest.progress >= quest.n
end

-- Counts `amount` of `stat` toward today's quests. Returns the quests it
-- just finished.
function QuestRules.bump(quests, stat: string, amount: number)
	local finished = {}
	for _, quest in quests.list do
		if quest.stat == stat and not QuestRules.done(quest) and amount > 0 then
			quest.progress = math.min(quest.n, quest.progress + amount)
			if QuestRules.done(quest) then
				table.insert(finished, quest)
			end
		end
	end
	return finished
end

-- Claims quest `index`'s reward. Returns the coins, or nil and why ("NoQuest",
-- "NotDone", "Claimed").
function QuestRules.claim(quests, index: number): (number?, string?)
	local quest = quests.list[index]
	if not quest then
		return nil, "NoQuest"
	elseif quest.claimed then
		return nil, "Claimed"
	elseif not QuestRules.done(quest) then
		return nil, "NotDone"
	end
	quest.claimed = true
	return quest.reward, nil
end

-- The bonus for all three, once they're all claimed. Returns the coins, or
-- nil and why ("NotDone", "Claimed").
function QuestRules.claimBonus(quests, level: number): (number?, string?)
	if quests.bonusClaimed then
		return nil, "Claimed"
	end
	for _, quest in quests.list do
		if not quest.claimed then
			return nil, "NotDone"
		end
	end
	if #quests.list == 0 then
		return nil, "NotDone"
	end
	quests.bonusClaimed = true
	local _, scale = QuestRules.tier(level)
	return Config.BONUS * scale, nil
end

------------------------------------------------------------------------
-- The login streak

-- Claims today's streak reward if it hasn't been (on join). Returns the
-- day of the streak (1–7) and its reward (Config.STREAK, coins scaled), or
-- nil if today's is already claimed.
function QuestRules.claimStreak(streak, day: number, level: number)
	if streak.lastClaimDay == day then
		return nil, nil
	end
	local days = if streak.lastClaimDay == day - 1 then streak.days % #Config.STREAK + 1 else 1
	streak.days = days
	streak.lastClaimDay = day
	local reward = table.clone(Config.STREAK[days])
	if reward.coins then
		local _, scale = QuestRules.tier(level)
		reward.coins *= scale
	end
	return days, reward
end

------------------------------------------------------------------------
-- The Cropdex

local function shape(cropdex)
	cropdex.seen = cropdex.seen or {}
	cropdex.tiers = cropdex.tiers or {}
	cropdex.sets = cropdex.sets or {}
	return cropdex
end

function QuestRules.entry(cropId: string, mutation: string?): string
	return `{cropId}|{mutation or ""}`
end

function QuestRules.seen(cropdex, cropId: string, mutation: string?): boolean
	return shape(cropdex).seen[QuestRules.entry(cropId, mutation)] == true
end

-- The cheapest crop of the rarity after `rarityId` (a tier's seed reward),
-- or nil after Mythic.
function QuestRules.nextSeed(rarityId: string): string?
	local order = Rarities.ById[rarityId].order
	local best = nil
	for _, crop in Crops.List do
		if Rarities.ById[crop.rarity].order == order + 1 and (not best or crop.seed < best.seed) then
			best = crop
		end
	end
	return best and best.id
end

-- Records a crop that reached your barn. Returns whether it's a new entry,
-- the rarity tier it just completed (or nil) and the mutation set it just
-- completed (or nil); those are marked done so they only pay once.
function QuestRules.record(cropdex, cropId: string, mutation: string?): (boolean, string?, string?)
	shape(cropdex)
	local key = QuestRules.entry(cropId, mutation)
	if cropdex.seen[key] or not Crops.ById[cropId] then
		return false, nil, nil
	end
	cropdex.seen[key] = true
	local tier, set = nil, nil
	local rarity = Crops.ById[cropId].rarity
	if not cropdex.tiers[rarity] then
		local all = true
		for _, crop in Crops.List do
			if crop.rarity == rarity and not cropdex.seen[QuestRules.entry(crop.id)] then
				all = false
			end
		end
		if all then
			cropdex.tiers[rarity] = true
			tier = rarity
		end
	end
	if mutation and not cropdex.sets[mutation] then
		local all = true
		for _, crop in Crops.List do
			if not cropdex.seen[QuestRules.entry(crop.id, mutation)] then
				all = false
			end
		end
		if all then
			cropdex.sets[mutation] = true
			set = mutation
		end
	end
	return true, tier, set
end

-- How much of the Cropdex is found: { found, total }.
function QuestRules.progress(cropdex): (number, number)
	shape(cropdex)
	local found = 0
	for _ in cropdex.seen do
		found += 1
	end
	return found, #Crops.List * (1 + #Weather.MUTATION_ORDER)
end

return QuestRules
