-- The Farm Guide for new players (docs/GameDesign.md §4.0; Config/Guide,
-- shared/GuideRules; drawn by the client's GuideController). The services
-- tick its steps off as they happen (GuideService.Record, or Planted for
-- the Carrots); the guide rides along in the player's state. Finishing it
-- pays Guide.REWARD_COINS once.
--   GuideAction "Hide"  closes the card (steps still count)
--   GuideAction "Show"  shows it again, or from the start once it's done
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guide = require(ReplicatedStorage.Shared.Config.Guide)
local GuideRules = require(ReplicatedStorage.Shared.GuideRules)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ActionRemote = require(script.Parent.Parent.Util.ActionRemote)
local Analytics = require(script.Parent.Parent.Util.Analytics)
local Format = require(ReplicatedStorage.Shared.Format)
local Notice = require(script.Parent.Parent.Util.Notice)
local DataService = require(script.Parent.DataService)

local GuideService = {}

local function after(player: Player, guide, result: string?)
	if not result then
		return
	end
	if result == "finished" then
		Analytics.event(player, "GuideFinished")
		if GuideRules.claimReward(guide) then
			DataService.AddCoins(player, Guide.REWARD_COINS, Analytics.GAMEPLAY, "GuideReward")
			Notice.send(player, `Farm Guide done! +{Format.number(Guide.REWARD_COINS)} coins`, "Good")
		end
	end
	DataService.NotifyState(player)
end

function GuideService.Record(player: Player, stepId: string)
	local data = DataService.Get(player)
	local guide = data and data.guide
	after(player, guide, GuideRules.record(guide, stepId))
end

-- A Carrot planted (the first step counts them).
function GuideService.Planted(player: Player, data)
	after(player, data.guide, GuideRules.planted(data.guide, data.inventory.seeds.Carrot or 0))
end

local ACTIONS = {}

function ACTIONS.Hide(player, data)
	if data.guide.hidden or data.guide.finished then
		return nil
	end
	data.guide.hidden = true
	local _, index = GuideRules.current(data.guide)
	Analytics.event(player, "GuideHidden", index) -- (which step people give up on)
	return nil
end

function ACTIONS.Show(_player, data)
	if data.guide.finished then
		GuideRules.restart(data.guide)
	else
		data.guide.hidden = false
	end
	return nil
end

-- (the /guide dev command: from the start, with the reward to earn again)
function GuideService.Reset(player: Player)
	local data = DataService.Get(player)
	if data then
		GuideRules.restart(data.guide)
		data.guide.rewarded = false
		DataService.NotifyState(player)
	end
end

function GuideService.Start()
	ActionRemote(Remotes.func("GuideAction"), ACTIONS, DataService, 0.5)
end

return GuideService
