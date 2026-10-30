-- The travel buttons (docs/GameDesign.md §4.11, shared/TravelRules): Home
-- (your farmhouse door), Town (the town spawn) and Visit (the sidewalk
-- outside a player's gate). Each is a 3 s channel that moving cancels, then
-- the server teleports you (MovementService.Teleport). Cooldowns go on the
-- player as attributes (HomeReadyAt, TownReadyAt, VisitReadyAt: server
-- time), so the HUD can grey its buttons. Suspects, knocked-out players and
-- sack carriers can't travel: that status comes with the stealing week.
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

local travels = {} -- [Player] = TravelRules state
local destinations = {} -- [Player] = CFrame for the channel under way

local function now(): number
	return workspace:GetServerTimeNow()
end

local function townFrame(): CFrame
	local at = PlotLayout.TOWN.spawn + Vector3.new(0, 3, 0)
	return CFrame.lookAt(at, at + Vector3.new(0, 0, 1))
end

local function visitFrame(index: number): CFrame
	local at = PlotLayout.visitWorld(index) + Vector3.new(0, 3, 0)
	return CFrame.lookAt(at, at + PlotLayout.frame(index).ZVector) -- (facing the gate)
end

local function travelOf(player: Player)
	travels[player] = travels[player] or TravelRules.new()
	return travels[player]
end

local function begin(player: Player, kind: string, destination: CFrame): string?
	local position = MovementService.positionOf(player)
	if not position then
		return "NoCharacter"
	end
	local travel = travelOf(player)
	local ok, reason = TravelRules.start(travel, kind, now(), position, nil)
	if not ok then
		return reason
	end
	destinations[player] = destination
	local channel = travel.channel
	task.delay(TravelRules.CHANNEL + 0.05, function()
		if travel.channel ~= channel or player.Parent ~= Players then
			return -- (cancelled, or they left)
		end
		local at = MovementService.positionOf(player) or position
		local done, result = TravelRules.finish(travel, now(), at, nil)
		if done then
			player:SetAttribute(`{result}ReadyAt`, travel.readyAt[result])
			MovementService.Teleport(player, destinations[player])
		elseif result == "Moved" then
			Notice.send(player, "Travel cancelled: you moved.", "Error")
		end
		destinations[player] = nil
	end)
	return nil
end

local actions = {}

function actions.Home(player, _data, _arg)
	local index = PlotService.plotOf(player)
	if not index then
		return "NoFarm"
	end
	return begin(player, "Home", PlotService.homeFrame(index))
end

function actions.Town(player, _data, _arg)
	return begin(player, "Town", townFrame())
end

-- "userId": to that player's gate.
function actions.Visit(player, _data, arg)
	local target = Players:GetPlayerByUserId(tonumber(arg) or 0)
	local index = target and PlotService.plotOf(target)
	if not index then
		return "NoFarm"
	end
	return begin(player, "Visit", visitFrame(index))
end

function actions.Cancel(player, _data, _arg)
	TravelRules.cancel(travelOf(player))
	destinations[player] = nil
	return nil
end

-- Teleports a player now, with no channel (dev commands).
function TravelService.Send(player: Player, frame: CFrame)
	MovementService.Teleport(player, frame)
end

TravelService.townFrame = townFrame
TravelService.visitFrame = visitFrame

function TravelService.Start()
	ActionRemote(Remotes.func("TravelAction"), actions, DataService, 0.2)
	Players.PlayerRemoving:Connect(function(player)
		travels[player] = nil
		destinations[player] = nil
	end)
end

return TravelService
