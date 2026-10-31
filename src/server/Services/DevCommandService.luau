-- Chat commands for play-testing (docs/PlaytestPlan.md, "Dev commands").
-- Registered in Studio only, for everyone there (Util/Staff); never in live
-- servers yet.
--   /coins 5000          add coins (default 10,000)
--   /level 5             set your Farm Level (XP to the start of it)
--   /xp 120              add Farm XP
--   /grow 60             grow your crops N seconds at online speed (/grow ripe = all ripe)
--   /away 2              as if you'd been away N hours (offline speed, 25%)
--   /restock [full]      Barley moves to the next restock now (full = every seed in)
--   /seeds Pumpkin 10    give seeds by crop id (/seeds all 5 = 5 of each)
--   /crops Pumpkin 40    put harvested crops in your barn (past its capacity)
--   /truck               your pickup reaches the City and comes home now
--   /shoppers 5          the next N shoppers come to your store one after another
--   /store 5             your store straight to Store Level N (up only; buildings done at once)
--   /tp town · /tp porch · /tp barley · /tp exchange · /tp home · /tp shed · /tp store · /tp 3 (a farm's gate)
--   /wipe                start your save over (in place)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local BarnRules = require(Shared.BarnRules)
local Crops = require(Shared.Config.Crops)
local PlotLayout = require(Shared.PlotLayout)
local ProgressionRules = require(Shared.ProgressionRules)
local SeedStock = require(Shared.SeedStock)
local Store = require(Shared.Config.Store)

local Server = ServerScriptService.Server
local Analytics = require(Server.Util.Analytics)
local Notice = require(Server.Util.Notice)
local Staff = require(Server.Util.Staff)
local DataService = require(script.Parent.DataService)
local FieldService = require(script.Parent.FieldService)
local LandService = require(script.Parent.LandService)
local PlotService = require(script.Parent.PlotService)
local StoreService = require(script.Parent.StoreService)
local TravelService = require(script.Parent.TravelService)
local TruckService = require(script.Parent.TruckService)

local DevCommandService = {}

local function reply(player: Player, text: string)
	Notice.send(player, text)
end

local function register(name: string, alias: string, handler)
	local command = Instance.new("TextChatCommand")
	command.Name = name
	command.PrimaryAlias = alias
	command.AutocompleteVisible = true
	command.Triggered:Connect(function(textSource, text)
		local player = Players:GetPlayerByUserId(textSource.UserId)
		if not player or not Staff.isStaff(player) or not DataService.Get(player) then
			return
		end
		local args = {}
		for word in string.gmatch(text, "%S+") do
			table.insert(args, word)
		end
		handler(player, DataService.Get(player), args)
	end)
	command.Parent = TextChatService
end

local function findCrop(id: string?)
	for _, crop in Crops.List do
		if string.lower(crop.id) == string.lower(id or "") then
			return crop
		end
	end
	return nil
end

local function setLevel(player: Player, data, level: number)
	local target = ProgressionRules.xpForLevel(level)
	if target > data.xp then
		DataService.AddXp(player, target - data.xp) -- (as if earned: the level-up card, any new Land Permit's signs)
		return
	end
	data.xp = target
	data.level = ProgressionRules.levelFor(target)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Level") then
		leaderstats.Level.Value = data.level
	end
	DataService.NotifyState(player)
	LandService.Refresh(player)
end

function DevCommandService.Start()
	if not RunService:IsStudio() then
		return
	end

	register("DevCoins", "/coins", function(player, _data, args)
		local amount = tonumber(args[2]) or 10_000
		DataService.AddCoins(player, amount, Analytics.GAMEPLAY, "Dev")
		reply(player, `+{amount} coins`)
	end)

	register("DevLevel", "/level", function(player, data, args)
		local level = math.clamp(math.floor(tonumber(args[2]) or data.level + 1), 1, 50)
		setLevel(player, data, level)
		reply(player, `Farm Level {data.level}`)
	end)

	register("DevXp", "/xp", function(player, _data, args)
		DataService.AddXp(player, tonumber(args[2]) or 60)
	end)

	register("DevGrow", "/grow", function(player, _data, args)
		local seconds = if args[2] == "ripe" then 1e7 else tonumber(args[2]) or 60
		FieldService.FastForward(player, seconds, false)
		reply(player, if args[2] == "ripe" then "Everything's ripe" else `Grew {seconds} s`)
	end)

	register("DevAway", "/away", function(player, _data, args)
		local hours = tonumber(args[2]) or 1
		FieldService.FastForward(player, hours * 3600, true)
		reply(player, `As if away {hours} h (crops grew at quarter speed)`)
	end)

	register("DevRestock", "/restock", function(player, _data, args)
		local shift = (ReplicatedStorage:GetAttribute("SeedStockShift") or 0) + 1
		ReplicatedStorage:SetAttribute("SeedStockShift", shift)
		if args[2] == "full" then
			ReplicatedStorage:SetAttribute("SeedStockFull", SeedStock.index())
		end
		reply(player, `Barley restocked (restock {SeedStock.index()}{if args[2] == "full" then ", everything in" else ""})`)
	end)

	register("DevSeeds", "/seeds", function(player, data, args)
		local count = math.clamp(math.floor(tonumber(args[3]) or 10), 1, 999)
		if args[2] == "all" then
			for _, crop in Crops.List do
				BarnRules.addSeeds(data.inventory, crop.id, count)
			end
		else
			local crop = findCrop(args[2])
			if not crop then
				reply(player, "Which crop? e.g. /seeds Pumpkin 10")
				return
			end
			BarnRules.addSeeds(data.inventory, crop.id, count)
		end
		DataService.NotifyState(player)
		reply(player, `+{count} seeds`)
	end)

	register("DevCrops", "/crops", function(player, data, args)
		local crop = findCrop(args[2])
		if not crop then
			reply(player, "Which crop? e.g. /crops Pumpkin 40")
			return
		end
		local count = math.clamp(math.floor(tonumber(args[3]) or 24), 1, 9999)
		BarnRules.addCrops(data.inventory, BarnRules.key(crop.id), count)
		DataService.NotifyState(player)
		reply(player, `+{count} {crop.name} in your barn`)
	end)

	register("DevTruck", "/truck", function(player)
		TruckService.Hurry(player)
		reply(player, "Pickup: there and back")
	end)

	register("DevShoppers", "/shoppers", function(player, _data, args)
		local count = math.clamp(math.floor(tonumber(args[2]) or 5), 1, 50)
		StoreService.Rush(player, count)
		reply(player, `{count} shoppers on their way (if anything's on display)`)
	end)

	register("DevStore", "/store", function(player, data, args)
		local to = math.floor(tonumber(args[2]) or data.store.level + 1)
		if to <= data.store.level then
			reply(player, `Your store is at Level {data.store.level}; /store only goes up (/wipe starts over)`)
			return
		end
		StoreService.SetLevel(player, to)
		reply(player, `Store Level {data.store.level}`)
	end)

	register("DevTeleport", "/tp", function(player, _data, args)
		local where = string.lower(args[2] or "town")
		local frame
		if where == "town" then
			frame = TravelService.townFrame()
		elseif where == "porch" then
			local at = PlotLayout.policePorchWorld() + Vector3.new(0, 3, 0)
			frame = CFrame.lookAt(at, Vector3.new(0, at.Y, 0))
		elseif where == "barley" then
			local at = PlotLayout.frontOf("Seeds", 10) + Vector3.new(0, 3, 0)
			frame = CFrame.lookAt(at, PlotLayout.frontOf("Seeds", 0) + Vector3.new(0, 3, 0))
		elseif where == "exchange" then
			local at = PlotLayout.frontOf("Exchange", 12) + Vector3.new(0, 3, 0)
			frame = CFrame.lookAt(at, PlotLayout.frontOf("Exchange", 0) + Vector3.new(0, 3, 0))
		elseif where == "home" then
			local index = PlotService.plotOf(player)
			frame = index and PlotService.homeFrame(index)
		elseif where == "shed" then
			local index = PlotService.plotOf(player)
			if index then
				local spot, look = PlotLayout.PLOT.bench + Vector3.new(0, 3, -6), PlotLayout.PLOT.bench + Vector3.new(0, 3, 0)
				frame = CFrame.lookAt(PlotLayout.toWorld(index, spot), PlotLayout.toWorld(index, look))
			end
		elseif where == "store" then
			local index = PlotService.plotOf(player)
			if index then
				-- on the sidewalk, looking in at the door
				local at = PlotLayout.storeWorld(index, Store.DOOR_X, -2.5, 3)
				frame = CFrame.lookAt(at, PlotLayout.storeWorld(index, Store.DOOR_X, 2, 3))
			end
		elseif tonumber(where) and PlotLayout.COUNT >= tonumber(where) then
			frame = TravelService.visitFrame(tonumber(where))
		end
		if frame then
			TravelService.Send(player, frame)
		else
			reply(player, "Where? /tp town · porch · barley · exchange · home · shed · store · 1–8")
		end
	end)

	register("DevWipe", "/wipe", function(player)
		DataService.Wipe(player)
		reply(player, "Save wiped: a brand-new farm")
	end)
end

return DevCommandService
