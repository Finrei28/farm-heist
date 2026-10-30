-- The field (docs/GameDesign.md §4.2, §4.5): planting, watering and
-- harvesting through the FieldAction remote, growth while the owner is
-- online (every TICK) and offline (settled when they join, at
-- Growth.OFFLINE_RATE), and drawing it all on their farm (World/FarmArt).
--
-- Every action is checked here: it's your farm, you're standing within
-- REACH of the tile (trusted position), the land is open, you have the seed
-- and the level for it, the crop is ripe, the barn has room.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local BarnRules = require(Shared.BarnRules)
local Crops = require(Shared.Config.Crops)
local GrowthRules = require(Shared.GrowthRules)
local LandRules = require(Shared.LandRules)
local PlotLayout = require(Shared.PlotLayout)
local ProgressionRules = require(Shared.ProgressionRules)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)

local Server = ServerScriptService.Server
local ActionRemote = require(Server.Util.ActionRemote)
local Analytics = require(Server.Util.Analytics)
local Notice = require(Server.Util.Notice)
local FarmArt = require(Server.World.FarmArt)
local DataService = require(script.Parent.DataService)
local MovementService = require(script.Parent.MovementService)
local PlotService = require(script.Parent.PlotService)

local FieldService = {}

FieldService.REACH = 10 -- studs (across the ground) from a tile's centre you can work it from
local TICK = 1
local WELCOME_AWAY = 120 -- seconds away before "your crops grew while you were away"

local lastTick = {} -- [Player] = server time growth was last settled

local function now(): number
	return workspace:GetServerTimeNow()
end

local function tilePart(index: number, tile: number): BasePart
	return PlotService.model(index).Field[`Tile{tile}`]
end

-- Redraws a player's whole field and land on their farm.
function FieldService.Render(player: Player)
	local index = PlotService.plotOf(player)
	local data = DataService.Get(player)
	if not index or not data then
		return
	end
	local model = PlotService.model(index)
	FarmArt.applyLand(model, PlotLayout.frame(index), data.land)
	local t = now()
	for tile = 1, 64 do
		FarmArt.showTile(tilePart(index, tile), data.field[tostring(tile)], t)
	end
end

-- Grows a player's crops up to now (online speed), redrawing tiles whose
-- stage changed. draw = false while they're leaving (their farm is going).
local function settle(player: Player, data, draw: boolean)
	local t = now()
	local elapsed = t - (lastTick[player] or t)
	lastTick[player] = t
	if elapsed <= 0 then
		return
	end
	local index = PlotService.plotOf(player)
	for key, tile in data.field do
		local before = FarmArt.stage(tile)
		GrowthRules.advance(tile, elapsed, 1)
		if draw and index and FarmArt.stage(tile) ~= before then
			FarmArt.showTile(tilePart(index, tonumber(key)), tile, t)
		end
	end
end

-- Moves every crop on by `seconds` (dev commands: /grow, /away).
function FieldService.FastForward(player: Player, seconds: number, offline: boolean?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	settle(player, data, false)
	for _, tile in data.field do
		if offline then
			GrowthRules.offline(tile, seconds)
		else
			GrowthRules.advance(tile, seconds, 1)
		end
	end
	FieldService.Render(player)
end

------------------------------------------------------------------------
-- Actions

local function parseTile(arg: string?): number?
	local tile = tonumber(arg)
	if tile and tile == math.floor(tile) and tile >= 1 and tile <= 64 then
		return tile
	end
	return nil
end

-- The checks every action shares. Returns the plot index, or nil and why.
local function reach(player: Player, tile: number?): (number?, string?)
	if not tile then
		return nil, "BadRequest"
	end
	local index = PlotService.plotOf(player)
	if not index then
		return nil, "NoFarm"
	end
	local position = MovementService.positionOf(player)
	local centre = PlotLayout.tileWorld(index, tile)
	if not position or Vector2.new(position.X - centre.X, position.Z - centre.Z).Magnitude > FieldService.REACH then
		return nil, "TooFar"
	end
	return index, nil
end

local actions = {}

-- "tile|cropId"
function actions.Plant(player, data, arg)
	local tileText, cropId = string.match(arg or "", "^(%d+)|(%w+)$")
	local tile = parseTile(tileText)
	local index, failure = reach(player, tile)
	if not index then
		return failure
	end
	local crop = Crops.ById[cropId]
	if not crop then
		return "BadRequest"
	end
	if not LandRules.isTileOpen(data.land, tile) then
		return "Overgrown"
	end
	local key = tostring(tile)
	if data.field[key] then
		return "Planted"
	end
	if data.level < Rarities.ById[crop.rarity].seedLevel then
		return "Locked"
	end
	if not BarnRules.takeSeed(data.inventory, cropId) then
		return "NoSeeds"
	end
	settle(player, data, true)
	local fresh = data.land.fresh[key] == true
	data.land.fresh[key] = nil
	data.field[key] = GrowthRules.plant(cropId, fresh)
	local part = tilePart(index, tile)
	FarmArt.setTileOpen(part, true, false)
	FarmArt.showTile(part, data.field[key], now())
	Analytics.step(player, data, "FirstPlant")
	return nil
end

function actions.Water(player, data, arg)
	local tile = parseTile(arg)
	local index, failure = reach(player, tile)
	if not index then
		return failure
	end
	local planted = data.field[tostring(tile)]
	if not planted then
		return "Empty"
	end
	settle(player, data, true)
	if not GrowthRules.water(planted) then
		return "NotNeeded"
	end
	FarmArt.showTile(tilePart(index, tile), planted, now())
	return nil
end

function actions.Harvest(player, data, arg)
	local tile = parseTile(arg)
	local index, failure = reach(player, tile)
	if not index then
		return failure
	end
	local key = tostring(tile)
	local planted = data.field[key]
	if not planted then
		return "Empty"
	end
	settle(player, data, true)
	if not GrowthRules.isRipe(planted) then
		return "NotRipe"
	end
	if not BarnRules.hasRoom(data.inventory, data.silo, 1) then
		Notice.send(player, "Barn full! Sell some crops to make room.", "Error")
		return "BarnFull"
	end
	local regrowing = planted.regrowing
	local _, stays = GrowthRules.harvest(planted)
	if not stays then
		data.field[key] = nil
	end
	BarnRules.addCrops(data.inventory, BarnRules.key(planted.crop), 1)
	data.stats.harvested += 1
	FarmArt.showTile(tilePart(index, tile), data.field[key], now())
	Analytics.step(player, data, "FirstHarvest")
	DataService.AddXp(player, ProgressionRules.harvestXp(planted.crop, regrowing))
	return nil
end

-- 🚩 Leave in field: Farmhands skip it (§4.2).
function actions.Flag(player, data, arg)
	local tile = parseTile(arg)
	local index, failure = reach(player, tile)
	if not index then
		return failure
	end
	local planted = data.field[tostring(tile)]
	if not planted then
		return "Empty"
	end
	planted.leave = not planted.leave
	FarmArt.showTile(tilePart(index, tile), planted, now())
	return nil
end

------------------------------------------------------------------------

function FieldService.Start()
	ActionRemote(Remotes.func("FieldAction"), actions, DataService, 0.1)

	PlotService.OnAssigned(function(player, _index, data)
		-- Growth while they were away, at the offline rate (§4.2).
		local away = DataService.AwaySeconds(player)
		local grew = false
		for _, tile in data.field do
			if not GrowthRules.isRipe(tile) then
				grew = true
			end
			GrowthRules.offline(tile, away)
		end
		lastTick[player] = now()
		FieldService.Render(player)
		if grew and away >= WELCOME_AWAY then
			Notice.send(player, "Welcome back! Your crops kept growing while you were away (at quarter speed).", "Good")
		end
	end)

	PlotService.OnReleased(function(_player, index)
		local model = PlotService.model(index)
		FarmArt.applyLand(model, PlotLayout.frame(index), { cleared = {}, fresh = {} })
		local t = now()
		for tile = 1, 64 do
			FarmArt.showTile(tilePart(index, tile), nil, t)
		end
	end)

	DataService.OnWiped(function(player)
		lastTick[player] = now()
		FieldService.Render(player)
	end)

	-- Growth up to the moment they leave goes into the save.
	DataService.BeforeRelease(function(player, data)
		settle(player, data, false)
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function() -- (after the save's BeforeRelease has used it)
			lastTick[player] = nil
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			for player in PlotService.owners() do
				local data = DataService.Get(player)
				if data and lastTick[player] then
					settle(player, data, true)
				end
			end
		end
	end)
end

return FieldService
