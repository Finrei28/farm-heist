-- The travel buttons (docs/GameDesign.md §4.11, shared/TravelRules): Home
-- (your farmhouse door), Town (the town spawn) and Visit (the sidewalk
-- outside a player's gate). The server teleports you at once
-- (MovementService.Teleport), with no cooldown, except Home with a thief on
-- your farm, which takes a moment (TravelRules.RAID_WAIT). Suspects,
-- knocked-out players and anyone carrying stolen crops can't travel
-- (TravelService.status and .raided, set by CrimeService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local TravelRules = require(Shared.TravelRules)

local Server = ServerScriptService.Server
local ActionRemote = require(Server.Util.ActionRemote)
local Notice = require(Server.Util.Notice)
local DataService = require(script.Parent.DataService)
local MovementService = require(script.Parent.MovementService)
local PlotService = require(script.Parent.PlotService)

local TravelService = {}

local waits = {} -- [Player] = { ends }: a trip home that's waiting to go

local function now(): number
	return workspace:GetServerTimeNow()
end

local function townFrame(): CFrame
	local at = PlotLayout.TOWN.spawn + Vector3.new(0, 3, 0)
	return CFrame.lookAt(at, PlotLayout.TOWN.spawnLook + Vector3.new(0, 3, 0))
end

local function visitFrame(index: number): CFrame
	local at = PlotLayout.visitWorld(index) + Vector3.new(0, 3, 0)
	return CFrame.lookAt(at, at + PlotLayout.frame(index).ZVector) -- (facing the gate)
end

-- { suspect, knockedOut, carrying } for a player (CrimeService sets it).
TravelService.status = nil :: ((Player) -> { [string]: boolean })?

-- Whether there's a thief on a player's farm (CrimeService sets it).
TravelService.raided = nil :: ((Player) -> boolean)?

local function statusOf(player: Player)
	return if TravelService.status then TravelService.status(player) else nil
end

-- Returns a failure reason, or nil and { seconds } if there's a wait.
local function go(player: Player, kind: string, destination: CFrame): (string?, { seconds: number }?)
	local ok, reason = TravelRules.check(kind, statusOf(player))
	if not ok then
		return reason
	end
	if not MovementService.positionOf(player) then
		return "NoCharacter"
	end
	local waiting = waits[player]
	if waiting and kind == "Home" then
		return nil, { seconds = waiting.ends - now() } -- (pressed again: it's on its way)
	end
	waits[player] = nil -- (going somewhere else instead)
	local seconds = TravelRules.waitFor(kind, TravelService.raided ~= nil and TravelService.raided(player))
	if seconds == 0 then
		MovementService.Teleport(player, destination)
		return nil
	end
	local trip = { ends = now() + seconds }
	waits[player] = trip
	task.delay(seconds, function()
		if waits[player] ~= trip then
			return
		end
		waits[player] = nil
		if player.Parent ~= Players then
			return
		end
		if TravelRules.check(kind, statusOf(player)) then
			MovementService.Teleport(player, destination)
		else
			Notice.send(player, "You can't go home now: you're a Suspect, knocked out or carrying stolen crops.", "Error")
		end
	end)
	return nil, { seconds = seconds }
end

local actions = {}

function actions.Home(player, _data, _arg)
	local index = PlotService.plotOf(player)
	if not index then
		return "NoFarm"
	end
	return go(player, "Home", PlotService.homeFrame(index))
end

function actions.Town(player, _data, _arg)
	return go(player, "Town", townFrame())
end

-- "userId": to that player's gate. Your own farm is Home, with Home's wait
-- when there's a thief on it (Visit has none).
function actions.Visit(player, data, arg)
	local target = Players:GetPlayerByUserId(tonumber(arg) or 0)
	local index = target and PlotService.plotOf(target)
	if not index then
		return "NoFarm"
	elseif target == player then
		return actions.Home(player, data, nil)
	end
	return go(player, "Visit", visitFrame(index))
end

-- Teleports a player now, whatever they're doing (dev commands).
function TravelService.Send(player: Player, frame: CFrame)
	MovementService.Teleport(player, frame)
end

TravelService.townFrame = townFrame
TravelService.visitFrame = visitFrame

function TravelService.Start()
	ActionRemote(Remotes.func("TravelAction"), actions, DataService, 0.2)
	Players.PlayerRemoving:Connect(function(player)
		waits[player] = nil
	end)
end

return TravelService
