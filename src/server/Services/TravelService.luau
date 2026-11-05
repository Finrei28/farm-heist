-- The travel buttons (docs/GameDesign.md §4.11, shared/TravelRules): Home
-- (your farmhouse door), Town (the town spawn) and Visit (the sidewalk
-- outside a player's gate). The server teleports you at once
-- (MovementService.Teleport), with no cooldown. Suspects, knocked-out players
-- and anyone carrying stolen crops can't travel (TravelService.status, set by
-- CrimeService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local TravelRules = require(Shared.TravelRules)

local Server = ServerScriptService.Server
local ActionRemote = require(Server.Util.ActionRemote)
local DataService = require(script.Parent.DataService)
local MovementService = require(script.Parent.MovementService)
local PlotService = require(script.Parent.PlotService)

local TravelService = {}

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

local function statusOf(player: Player)
	return if TravelService.status then TravelService.status(player) else nil
end

local function go(player: Player, kind: string, destination: CFrame): string?
	local ok, reason = TravelRules.check(kind, statusOf(player))
	if not ok then
		return reason
	end
	if not MovementService.positionOf(player) then
		return "NoCharacter"
	end
	MovementService.Teleport(player, destination)
	return nil
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

-- "userId": to that player's gate.
function actions.Visit(player, _data, arg)
	local target = Players:GetPlayerByUserId(tonumber(arg) or 0)
	local index = target and PlotService.plotOf(target)
	if not index then
		return "NoFarm"
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
end

return TravelService
