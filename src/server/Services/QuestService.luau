-- Daily quests, the login streak and the Cropdex (docs/GameDesign.md
-- §4.15, §4.16; shared/QuestRules, Config/Quests).
--
--   * Quests: three a day, new at midnight UTC. What you do counts through
--     QuestService.Bump(player, stat, amount), called by the services
--     (harvests, truck crates, store sales, arrests, stolen crops home,
--     auction wins, mutated harvests); a finished quest's coins are claimed
--     in the Quests window (QuestAction "Claim" index, "Bonus").
--   * The streak: claimed when you join, once a day.
--   * The Cropdex: every crop that reaches your barn (picked, a Farmhand's,
--     a stolen one taken home), plain and mutated, through
--     QuestService.Record. A new entry is worth XP; a whole rarity pays
--     coins and a seed; a whole mutation set pays coins and a badge.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Crime = require(Shared.Config.Crime)
local Crops = require(Shared.Config.Crops)
local QuestRules = require(Shared.QuestRules)
local Quests = require(Shared.Config.Quests)
local Remotes = require(Shared.Remotes)
local Store = require(Shared.Config.Store)

local Server = ServerScriptService.Server
local ActionRemote = require(Server.Util.ActionRemote)
local Analytics = require(Server.Util.Analytics)
local Notice = require(Server.Util.Notice)
local DataService = require(script.Parent.DataService)

local QuestService = {}

local function ctxOf(data)
	return { level = data.level, raids = data.playSeconds >= Crime.SHIELD_SECONDS or data.crime.shieldDropped == true }
end

local function refresh(player: Player, data): boolean
	return QuestRules.refresh(data.quests, player.UserId, os.time(), ctxOf(data))
end

-- Counts something toward today's quests (stat: Config/Quests).
function QuestService.Bump(player: Player, stat: string, amount: number?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	refresh(player, data)
	for _, quest in QuestRules.bump(data.quests, stat, amount or 1) do
		Notice.send(player, `✅ Quest done: {QuestRules.text(quest)}! Claim your {QuestRules.number(quest.reward)} coins in Quests.`, "Good")
	end
	DataService.NotifyState(player)
end

-- A crop reached a player's barn: the Cropdex. (A mutated one counts as
-- the plain crop too: you've had a pumpkin.)
function QuestService.Record(player: Player, cropId: string, mutation: string?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if mutation then
		QuestService.Record(player, cropId, nil)
	end
	local new, tier, set = QuestRules.record(data.cropdex, cropId, mutation)
	if not new then
		return
	end
	local crop = Crops.ById[cropId]
	DataService.AddXp(player, Quests.CROPDEX_XP)
	Notice.send(player, `📖 New in your Cropdex: {crop.icon} {if mutation then mutation .. " " else ""}{crop.name}! (+{Quests.CROPDEX_XP} XP)`, "Good")
	if tier then
		local coins = Quests.CROPDEX_TIER[tier]
		DataService.AddCoins(player, coins, Analytics.GAMEPLAY, "Cropdex")
		local seed = QuestRules.nextSeed(tier)
		if seed then
			data.inventory.seeds[seed] = (data.inventory.seeds[seed] or 0) + 1
		end
		Notice.send(player, `📖 Every {tier} crop found! +{QuestRules.number(coins)} coins{if seed then ` and a {Crops.ById[seed].name} seed` else ""}.`, "Announce")
	end
	if set then
		DataService.AddCoins(player, Quests.CROPDEX_SET, Analytics.GAMEPLAY, "Cropdex")
		Notice.send(player, `🏅 The {set} set: every crop {set}! A badge for your Cropdex and +{QuestRules.number(Quests.CROPDEX_SET)} coins.`, "Announce")
	end
	DataService.NotifyState(player)
end

-- Today's streak reward, when they join.
local function streak(player: Player, data)
	local days, reward = QuestRules.claimStreak(data.streak, QuestRules.day(os.time()), data.level)
	if not days then
		return
	end
	local parts = {}
	if reward.coins then
		DataService.AddCoins(player, reward.coins, Analytics.GAMEPLAY, "Streak")
		table.insert(parts, `{QuestRules.number(reward.coins)} coins`)
	end
	for cropId, count in reward.seeds or {} do
		data.inventory.seeds[cropId] = (data.inventory.seeds[cropId] or 0) + count
		table.insert(parts, `{count} {Crops.ById[cropId].name} seed{if count == 1 then "" else "s"}`)
	end
	if reward.decor then
		-- a gift for your store (kept forever, like the starter kit: Decorate)
		data.store.owned[reward.decor] = (data.store.owned[reward.decor] or 0) + 1
		data.store.gifts[reward.decor] = (data.store.gifts[reward.decor] or 0) + 1
		table.insert(parts, `a {Store.ITEMS[reward.decor].name} for your store`)
	end
	Notice.send(player, `🔥 Day {days} of {#Quests.STREAK} in a row: {table.concat(parts, " and ")}!{if days < #Quests.STREAK then " Come back tomorrow for more." else " A full week!"}`, "Announce")
	DataService.NotifyState(player)
end

local actions = {}

-- "Claim" index: a finished quest's coins.
function actions.Claim(player, data, arg)
	refresh(player, data)
	local coins, why = QuestRules.claim(data.quests, tonumber(arg) or 0)
	if not coins then
		return why
	end
	DataService.AddCoins(player, coins, Analytics.GAMEPLAY, "Quest")
	return nil, { coins = coins }
end

-- "Bonus": all three claimed.
function actions.Bonus(player, data)
	local coins, why = QuestRules.claimBonus(data.quests, data.level)
	if not coins then
		return why
	end
	DataService.AddCoins(player, coins, Analytics.GAMEPLAY, "QuestBonus")
	return nil, { coins = coins }
end

function QuestService.Start()
	ActionRemote(Remotes.func("QuestAction"), actions, DataService, 0.2)
	DataService.OnLoaded(function(player, data)
		refresh(player, data)
		task.delay(6, function() -- (after the welcome: the note doesn't get lost under the loading cover)
			if player.Parent and DataService.Get(player) == data then
				streak(player, data)
			end
		end)
		DataService.NotifyState(player)
	end)
	-- a new day while you play: new quests (and the streak)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				if data and refresh(player, data) then
					Notice.send(player, "📋 New day, new quests! (Quests)", "Announce")
					streak(player, data)
					DataService.NotifyState(player)
				end
			end
		end
	end)
end

return QuestService
