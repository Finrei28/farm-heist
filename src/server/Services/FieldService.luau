-- The field (docs/GameDesign.md §4.2, §4.5): planting, watering and
-- harvesting through the FieldAction remote (and Farmhands' harvests,
-- WorkerService), growth while the owner is online (every TICK, at the
-- weather's speed), the weather's mutations on ripe crops left in the field
-- (every Weather.ROLL seconds, shared/WeatherRules), and drawing it all on
-- their farm (World/FarmArt). Growth while they were
-- away is settled with the crew's work when they join (WorkerService,
-- shared/PipelineRules, at Growth.OFFLINE_RATE).
--
-- Every action is checked here: it's your farm, you're standing within
-- REACH of the tile (trusted position), the land is open, you have the seed
-- and the level for it, the crop is ripe, the barn has room. Friends on
-- your Trusted list can water and harvest for you while they stand in your
-- farm (§4.1): the crops go to your barn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Monetization = require(Shared.Config.Monetization)
local RobuxRules = require(Shared.RobuxRules)
local BarnRules = require(Shared.BarnRules)
local Crops = require(Shared.Config.Crops)
local DefenceRules = require(Shared.DefenceRules)
local GrowthRules = require(Shared.GrowthRules)
local LandRules = require(Shared.LandRules)
local PlotLayout = require(Shared.PlotLayout)
local Progression = require(Shared.Config.Progression)
local ProgressionRules = require(Shared.ProgressionRules)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local Weather = require(Shared.Config.Weather)
local WeatherRules = require(Shared.WeatherRules)

local Server = ServerScriptService.Server
local ActionRemote = require(Server.Util.ActionRemote)
local Analytics = require(Server.Util.Analytics)
local Notice = require(Server.Util.Notice)
local FarmArt = require(Server.World.FarmArt)
local DataService = require(script.Parent.DataService)
local MovementService = require(script.Parent.MovementService)
local PlotService = require(script.Parent.PlotService)
local QuestService = require(script.Parent.QuestService)
local GuideService = require(script.Parent.GuideService)

local FieldService = {}

FieldService.REACH = 10 -- studs (across the ground) from a tile's centre you can work it from
local TICK = 1

local lastTick = {} -- [Player] = server time growth was last settled

local function now(): number
	return workspace:GetServerTimeNow()
end

local function tilePart(index: number, tile: number): BasePart
	return PlotService.model(index).Field[`Tile{tile}`]
end

-- How many a new patch (or a regrowing one's next picking) of this crop
-- will give on this farm: its perPatch at the Field Level, the extra rolled.
local function rollYield(data, cropId: string): number
	return GrowthRules.rollYield(cropId, LandRules.fieldYield(data.land), math.random())
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
	-- the weather's speed, and the Growth Boost's while some is left (it's
	-- used up only while you play: shared/RobuxRules)
	local speed = WeatherRules.growth(WeatherRules.now(t)) * RobuxRules.boostOver(data, elapsed)
	local field = index and PlotService.model(index):FindFirstChild("Field")
	local boost = if (data.boostLeft or 0) > 0 then Monetization.BOOST else nil
	if draw and field and field:GetAttribute("Boost") ~= boost then
		field:SetAttribute("Boost", boost) -- (FarmArt counts the ripe times with it)
		task.defer(FieldService.Render, player)
	end
	for key, tile in data.field do
		local before = FarmArt.stage(tile)
		GrowthRules.advance(tile, elapsed, speed)
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

-- Whose field you'd water or harvest: a friend's that you're standing in
-- and Trusted on, else your own. Returns the owner and their save.
local function workFarm(player: Player, data)
	local farm = PlotService.inFarm(player)
	local owner = if farm > 0 then PlotService.ownerOf(farm) else nil
	if owner and owner ~= player then
		local ownerData = DataService.Get(owner)
		if ownerData and DefenceRules.isTrusted(ownerData.trusted, player.UserId) then
			return owner, ownerData
		end
	end
	return player, data
end

-- The checks every action shares: `player` stands within reach of the tile
-- on `owner`'s farm (their own, unless they're helping). Returns the plot
-- index, or nil and why.
local function reach(player: Player, tile: number?, owner: Player?): (number?, string?)
	if not tile then
		return nil, "BadRequest"
	end
	local index = PlotService.plotOf(owner or player)
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
	data.field[key] = GrowthRules.plant(cropId, fresh, rollYield(data, cropId))
	local part = tilePart(index, tile)
	FarmArt.setTileOpen(part, true, false)
	FarmArt.showTile(part, data.field[key], now())
	Analytics.step(player, data, "FirstPlant")
	GuideService.Planted(player, data, cropId)
	return nil
end

-- Digs up a growing crop, to plant something else there (the user, 2026-11-06:
-- "Allow players to remove existing planted crops"). The seed's gone with it,
-- so it can't re-roll a yield. A ripe crop you harvest instead.
function actions.Dig(player, data, arg)
	local tile = parseTile(arg)
	local index, failure = reach(player, tile)
	if not index then
		return failure
	end
	local key = tostring(tile)
	if not data.field[key] then
		return "Empty"
	end
	settle(player, data, true)
	local planted = data.field[key]
	if not planted then
		return "Empty"
	elseif GrowthRules.isRipe(planted) then
		return "Ripe"
	end
	data.field[key] = nil
	FarmArt.showTile(tilePart(index, tile), nil, now())
	return nil
end

function actions.Water(player, data, arg)
	local tile = parseTile(arg)
	local owner, ownerData = workFarm(player, data)
	local index, failure = reach(player, tile, owner)
	if not index then
		return failure
	end
	local planted = ownerData.field[tostring(tile)]
	if not planted then
		return "Empty"
	end
	settle(owner, ownerData, true)
	if not GrowthRules.water(planted) then
		return "NotNeeded"
	end
	FarmArt.showTile(tilePart(index, tile), planted, now())
	if owner == player then
		GuideService.Record(player, "Water")
	end
	return nil
end

-- Your own crops, or a friend's (they go to the friend's barn, and the
-- friend gets the XP a Farmhand's harvest gives).
function actions.Harvest(player, data, arg)
	local tile = parseTile(arg)
	local owner, ownerData = workFarm(player, data)
	local helping = owner ~= player
	local index, failure = reach(player, tile, owner)
	if not index then
		return failure
	end
	local key = tostring(tile)
	local planted = ownerData.field[key]
	if not planted then
		return "Empty"
	end
	settle(owner, ownerData, true)
	if not GrowthRules.isRipe(planted) then
		return "NotRipe"
	end
	local count = GrowthRules.yieldOf(planted)
	if not BarnRules.hasRoom(ownerData, count) then
		Notice.send(player, if helping then `{owner.DisplayName}'s barn is full.` else "Barn full! Sell some crops to make room.", "Error")
		return "BarnFull"
	end
	local regrowing, mutation = planted.regrowing, planted.mutation
	local _, stays = GrowthRules.harvest(planted, rollYield(ownerData, planted.crop))
	if not stays then
		ownerData.field[key] = nil
	end
	BarnRules.addCrops(ownerData.inventory, BarnRules.key(planted.crop, mutation), count)
	ownerData.stats.harvested += count
	QuestService.Record(owner, planted.crop, mutation)
	if not helping then
		QuestService.Bump(player, "harvest", count)
		if mutation then
			QuestService.Bump(player, "mutations", 1)
		end
	end
	FarmArt.showTile(tilePart(index, tile), ownerData.field[key], now())
	local xp = ProgressionRules.harvestXp(planted.crop, regrowing)
	if helping then
		DataService.AddXp(owner, xp * Progression.WORKER_HARVEST)
		DataService.NotifyState(owner)
	else
		Analytics.step(player, data, "FirstHarvest")
		GuideService.Record(player, "Harvest")
		DataService.AddXp(player, xp)
	end
	return nil, { crop = planted.crop, count = count, mutation = mutation, owner = if helping then owner.DisplayName else nil }
end

-- A Farmhand's harvest of a ripe tile (not one flagged to stay), replanted
-- with `replant` ("same" · "cheapest" · "none") from your seed bag. Half
-- the XP of picking it yourself. Returns nil (and "NoSeeds" if it couldn't
-- be replanted), or why not: "NotRipe" · "BarnFull" · "Leave".
function FieldService.WorkerHarvest(player: Player, data, key: string, replant: string): (string?, string?)
	local index = PlotService.plotOf(player)
	local planted = data.field[key]
	if not index or not planted then
		return "Empty"
	elseif planted.leave then
		return "Leave"
	elseif not GrowthRules.isRipe(planted) then
		return "NotRipe"
	elseif not BarnRules.hasRoom(data, GrowthRules.yieldOf(planted)) then
		return "BarnFull"
	end
	local regrowing, mutation = planted.regrowing, planted.mutation
	local count = GrowthRules.yieldOf(planted)
	local _, stays = GrowthRules.harvest(planted, rollYield(data, planted.crop))
	BarnRules.addCrops(data.inventory, BarnRules.key(planted.crop, mutation), count)
	data.stats.harvested += count
	QuestService.Record(player, planted.crop, mutation)
	if not stays then
		data.field[key] = nil
		local seed = nil
		if replant == "same" and (data.inventory.seeds[planted.crop] or 0) > 0 then
			seed = planted.crop
		elseif replant == "cheapest" then
			for cropId, count in data.inventory.seeds do
				if count > 0 and data.level >= Rarities.ById[Crops.ById[cropId].rarity].seedLevel
					and (not seed or Crops.ById[cropId].seed < Crops.ById[seed].seed or (Crops.ById[cropId].seed == Crops.ById[seed].seed and cropId < seed)) then
					seed = cropId
				end
			end
		end
		if seed and BarnRules.takeSeed(data.inventory, seed) then
			local fresh = data.land.fresh[key] == true
			data.land.fresh[key] = nil
			data.field[key] = GrowthRules.plant(seed, fresh, rollYield(data, seed))
		end
	end
	FarmArt.showTile(tilePart(index, tonumber(key) :: number), data.field[key], now())
	DataService.AddXp(player, ProgressionRules.harvestXp(planted.crop, regrowing, true))
	return nil, if not stays and replant ~= "none" and not data.field[key] then "NoSeeds" else nil
end

-- The ripe crop on a tile (growth settled up to now) and how many a thief
-- would get (CrimeService), or nil.
function FieldService.RipeCrop(player: Player, data, key: string): (string?, number)
	settle(player, data, true)
	local tile = data.field[key]
	if tile and GrowthRules.isRipe(tile) then
		return tile.crop, GrowthRules.carryOf(tile)
	end
	return nil, 0
end

-- A thief takes the ripe crop on a tile (CrimeService has checked the rest):
-- like a harvest, but into their hands, and no XP. They take the whole patch,
-- or one of the big ones (the rest stays ripe); regrowing plants only lose
-- their fruit. Returns the crop id, its barn key and how many, or nil.
function FieldService.TakeRipe(player: Player, data, key: string): (string?, string?, number)
	settle(player, data, true)
	local index = PlotService.plotOf(player)
	local tile = data.field[key]
	if not index or not tile or not GrowthRules.isRipe(tile) then
		return nil, nil, 0
	end
	local count, mutation = GrowthRules.carryOf(tile), tile.mutation
	if not GrowthRules.take(tile, count, rollYield(data, tile.crop)) then
		data.field[key] = nil
	end
	FarmArt.showTile(tilePart(index, tonumber(key) :: number), data.field[key], now())
	return tile.crop, BarnRules.key(tile.crop, mutation), count
end

-- Ripe tiles Farmhands could harvest now (not flagged to stay), in tile order.
function FieldService.RipeTiles(player: Player, data): { string }
	settle(player, data, true)
	local keys = {}
	for key, tile in data.field do
		if not tile.leave and GrowthRules.isRipe(tile) then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a, b)
		return tonumber(a) < tonumber(b)
	end)
	return keys
end

-- Every Weather.ROLL seconds: each ripe crop left in a field rolls the
-- weather's mutation (and the any-weather ones). A crop holds one mutation;
-- one already mutated keeps rolling and takes a new one only if it's worth
-- more (WeatherRules.better). It shows as an aura that thieves see too (§4.14).
local function rollMutations()
	local t = now()
	local weatherId = WeatherRules.weather(WeatherRules.now(t)).id
	for player in PlotService.owners() do
		local data = DataService.Get(player)
		local index = PlotService.plotOf(player)
		if data and index and lastTick[player] then
			settle(player, data, true)
			local turned = {}
			for key, tile in data.field do
				if GrowthRules.isRipe(tile) then
					local mutation = WeatherRules.mutate(weatherId, math.random())
					if WeatherRules.better(tile.mutation, mutation) then
						turned[tile] = tile.mutation or false -- (what it was before)
						tile.mutation = mutation
						FarmArt.showTile(tilePart(index, tonumber(key) :: number), tile, t)
					end
				end
			end
			local count, only, was = 0, nil, nil
			for tile, before in turned do
				count += 1
				only, was = tile, before
			end
			if count == 1 then
				local crop = Crops.ById[only.crop]
				-- ("Your 🥕 6 Wet carrots turned Shocked: worth ×3 now!")
				local what = `{crop.icon} {Crops.count(only.crop, GrowthRules.yieldOf(only), was or nil)}`
				Notice.send(player, `✨ Your {what} turned {only.mutation}: worth ×{WeatherRules.value(only.mutation)} now!`, "Good")
			elseif count > 1 then
				Notice.send(player, `✨ {count} of your ripe crops mutated! Harvest them, or leave them out for something even better.`, "Good")
			end
			if count > 0 then
				Analytics.event(player, "Mutation", count)
			end
		end
	end
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

	-- (Growth while they were away is settled with the crew's work: WorkerService.)
	PlotService.OnAssigned(function(player)
		lastTick[player] = now()
		FieldService.Render(player)
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
		local speed = nil
		while true do
			task.wait(TICK)
			for player in PlotService.owners() do
				local data = DataService.Get(player)
				if data and lastTick[player] then
					settle(player, data, true)
				end
			end
			-- the weather changed how fast crops grow: every tile's ripe time
			-- (the RipeAt the client counts down) changes with it
			local nowSpeed = WeatherRules.growth(WeatherRules.now(now()))
			if speed and nowSpeed ~= speed then
				for player in PlotService.owners() do
					FieldService.Render(player)
				end
			end
			speed = nowSpeed
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Weather.ROLL)
			rollMutations()
		end
	end)
end

return FieldService
