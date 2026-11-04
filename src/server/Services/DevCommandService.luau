-- Chat commands for play-testing (docs/PlaytestPlan.md, "Dev commands").
-- Registered in Studio only, for everyone there (Util/Staff); never in live
-- servers yet.
--   /coins 50000         add coins (default 100,000)
--   /level 5             set your Farm Level (XP to the start of it)
--   /xp 120              add Farm XP
--   /grow 60             grow your crops N seconds at online speed (/grow ripe = all ripe)
--   /away 2              as if you'd been away N hours (growth, the crew at 25%, store sales: the Welcome back card)
--   /restock [full]      Barley moves to the next restock now (full = every seed in)
--   /seeds Pumpkin 10    give seeds by crop id (/seeds all 5 = 5 of each)
--   /crops Carrot 72     put harvested crops in your barn (past its capacity; default a crate's worth)
--   /truck               your trucks reach the City and come home now
--   /warehouse 5         your warehouse straight to Warehouse Level N (up only; buildings done at once)
--   /hire Packer 3       a worker of that type joins at that level (free, past the slots)
--   /crew 5              a Level N worker in every open slot (default 1)
--   /workers 5           every worker to Level N, their XP bars full
--   /trainxp             every worker's XP bar full (ready to train)
--   /state               prints your warehouse, trucks and crew to the Output
--   /shoppers 5          the next N shoppers come to your store one after another
--   /store 5             your store straight to Store Level N (up only; buildings done at once)
--   /tp town · /tp porch · /tp barley · /tp exchange · /tp hiring · /tp auction (inside, by the doors) · /tp home · /tp shed (the bench) · /tp dock · /tp store · /tp 3 (a farm's gate)
--   /tp back [3]         outside a farm's back fence (yours by default), facing it
--   /tp field [3]        in a farm's field (yours by default), on its first open block
--   /plant Pumpkin       plant that crop on every open, empty tile of your field (free; /grow ripe ripens them)
--   /field 3             your field straight to Field Level N (crops planted after it give more)
--   /land all · none     every block of your field cleared (all 64 tiles open) · back to the 4 start blocks
--   /ko [suspect]        knock yourself out where you stand (as a Suspect: the arrest screen)
--   /suspect             mark yourself a Suspect of the farm you're in
--   /carry Carrot 8      stolen crops in your hands (default: what a thief takes from a patch; in your own farm they go straight into your barn, so use it outside); /carry none empties them
--   /debt 3000           owe 3,000 coins (to yourself) for the police desk and paying off debts
--   /earn 2000           as if you'd sold crops for 2,000 coins (sales XP; half goes to any debts)
--   /crimelog            prints your visits, what you carry, cooldowns, debts, arrests and your farm's raid ledger
--   /shield off · on     end your Sprout Shield and arrival grace now · start them again (as a new player)
--   /defences all · none one of every defence, set out round your field (4 mud patches, 4 cloches) · none at all
--   /trust Name          put a player in this server on your Trusted list (/trust none empties it)
--   /auction now        an auction starts this moment (three lots, off the 8-minute clock)
--   /auction soon       the auction clock moves so the next one starts in 70 s (its 1-minute note, the bell); /auction off back to the real clock
--   /quests Arrest Deposit Mutation   today's quests set to these (Harvest · Ship · Store · Mutation · Arrest · Deposit · Auction), at your level
--   /weather Rain        that weather now, for its usual length (Clear · Rain · Thunderstorm · FrostNight · GoldenHour · HarvestMoon); /weather off back to the schedule; /weather says what's on
--   /time night          the sky's clock to sunrise · noon · dusk · night · midnight or an hour (0–23), for everyone; /time off back to the real clock
--   /guide               the Farm Guide from its first step again (its coins to earn again)
--   /wipe                start your save over (in place)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local BarnRules = require(Shared.BarnRules)
local FineRules = require(Shared.FineRules)
local GrowthRules = require(Shared.GrowthRules)
local Land = require(Shared.Config.Land)
local LandRules = require(Shared.LandRules)
local Crops = require(Shared.Config.Crops)
local PlotLayout = require(Shared.PlotLayout)
local ProgressionRules = require(Shared.ProgressionRules)
local SeedStock = require(Shared.SeedStock)
local WarehouseRules = require(Shared.WarehouseRules)
local Store = require(Shared.Config.Store)
local Auction = require(Shared.Config.Auction)
local QuestRules = require(Shared.QuestRules)
local Quests = require(Shared.Config.Quests)
local Weather = require(Shared.Config.Weather)
local WeatherRules = require(Shared.WeatherRules)
local Workers = require(Shared.Config.Workers)

local Server = ServerScriptService.Server
local Analytics = require(Server.Util.Analytics)
local AuctionService = require(script.Parent.AuctionService)
local Notice = require(Server.Util.Notice)
local Staff = require(Server.Util.Staff)
local CrimeService = require(script.Parent.CrimeService)
local DataService = require(script.Parent.DataService)
local DefenceService = require(script.Parent.DefenceService)
local FieldService = require(script.Parent.FieldService)
local GuideService = require(script.Parent.GuideService)
local LandService = require(script.Parent.LandService)
local PlotService = require(script.Parent.PlotService)
local StoreService = require(script.Parent.StoreService)
local TravelService = require(script.Parent.TravelService)
local TruckService = require(script.Parent.TruckService)
local WarehouseService = require(script.Parent.WarehouseService)
local WorkerService = require(script.Parent.WorkerService)

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
		local amount = tonumber(args[2]) or 100_000
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
		WorkerService.DevAway(player, math.floor(hours * 3600))
		reply(player, `As if away {hours} h`)
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
			reply(player, "Which crop? e.g. /crops Pumpkin 40 (default: a crate's worth)")
			return
		end
		local count = math.clamp(math.floor(tonumber(args[3]) or crop.crate), 1, 99999)
		BarnRules.addCrops(data.inventory, BarnRules.key(crop.id), count)
		DataService.NotifyState(player)
		reply(player, `+{Crops.count(crop.id, count)} in your barn`)
	end)

	register("DevTruck", "/truck", function(player)
		TruckService.Hurry(player)
		reply(player, "Trucks: there and back")
	end)

	register("DevWarehouse", "/warehouse", function(player, data, args)
		local to = math.floor(tonumber(args[2]) or data.warehouse.level + 1)
		if to <= data.warehouse.level then
			reply(player, `Your warehouse is at Level {data.warehouse.level}; /warehouse only goes up (/wipe starts over)`)
			return
		end
		WarehouseService.SetLevel(player, to)
		reply(player, `Warehouse Level {data.warehouse.level}`)
	end)

	register("DevHire", "/hire", function(player, _data, args)
		local typeName = nil
		for name in Workers.TYPES do
			if string.lower(name) == string.lower(args[2] or "") then
				typeName = name
			end
		end
		if not typeName then
			reply(player, "Who? e.g. /hire Packer 3 (Farmhand, ShedHand, Sorter, Packer, Loader, Driver, Stocker, Cashier, Greeter)")
			return
		end
		WorkerService.DevHire(player, typeName, tonumber(args[3]))
		reply(player, `A {Workers.TYPES[typeName].name} joined your crew`)
	end)

	register("DevCrew", "/crew", function(player, _data, args)
		local joined = WorkerService.DevCrew(player, tonumber(args[2]) or 1)
		reply(player, if joined > 0 then `{joined} workers joined (every open slot)` else "Every slot is full")
	end)

	register("DevWorkers", "/workers", function(player, _data, args)
		local level = math.clamp(math.floor(tonumber(args[2]) or 5), 1, Workers.MAX_LEVEL)
		WorkerService.DevSetLevels(player, level)
		reply(player, `Every worker is Level {level}`)
	end)

	register("DevState", "/state", function(player, data)
		local w = data.warehouse
		local beds = {}
		for i, bed in w.beds do
			table.insert(beds, `{i}:{#bed}`)
		end
		print(`[state] coins {data.coins} · auction held {data.auctionHeld or 0} · Warehouse {w.level}{if w.build then ` (building to {w.build.to}, {math.ceil(w.build.left)} s)` else ""} · hold {#w.dock} · sorted {#w.sorted} · beds {table.concat(beds, " ")} · runs {#w.trucks} · strike {data.crew.strike}`)
		for key, units in data.inventory.crops do
			print(`[state] barn {key} ×{units}`)
		end
		for uid, worker in data.workers do
			print(`[state] worker {uid} {worker.name} {worker.type} Lv {worker.level} xp {math.floor(worker.xp or 0)}`)
		end
		reply(player, "Printed to the Output")
	end)

	register("DevTrainXp", "/trainxp", function(player)
		WorkerService.DevFillXp(player)
		reply(player, "Every worker is ready to train")
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
		elseif where == "back" then
			local index = tonumber(args[3]) or PlotService.plotOf(player)
			if index then
				local at = PlotLayout.toWorld(index, Vector3.new(0, 3, PlotLayout.DEPTH + 3.5))
				frame = CFrame.lookAt(at, PlotLayout.toWorld(index, Vector3.new(0, 3, PlotLayout.DEPTH - 20)))
			end
		elseif where == "field" then
			local index = tonumber(args[3]) or PlotService.plotOf(player)
			if index then
				local at = PlotLayout.tileWorld(index, 10) + Vector3.new(0, 3, 0)
				frame = CFrame.lookAt(at, PlotLayout.tileWorld(index, 12) + Vector3.new(0, 3, 0))
			end
		elseif where == "porch" or where == "police" then
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
		elseif where == "auction" then
			local hall = PlotLayout.buildingFrame("Auction")
			frame = hall * CFrame.new(0, 3.6, -9) -- (behind the benches, looking along −Z: at the stage)
		elseif where == "hiring" then
			local at = PlotLayout.frontOf("HiringHall", 12) + Vector3.new(0, 3, 0)
			frame = CFrame.lookAt(at, PlotLayout.frontOf("HiringHall", 0) + Vector3.new(0, 3, 0))
		elseif where == "shed" or where == "dock" then
			local index = PlotService.plotOf(player)
			local data = DataService.Get(player)
			if index and data then
				local layout = PlotLayout.WAREHOUSES[WarehouseRules.level(data.warehouse.level).stage]
				local spot, look
				if where == "shed" then
					spot, look = layout.bench + Vector3.new(0, 3, -6), layout.bench + Vector3.new(0, 3, 0)
				else
					spot, look = PlotLayout.leverLocal(layout.docks[1]) + Vector3.new(-6, 4, 0), PlotLayout.loadLocal(layout.docks[1]) + Vector3.new(0, 3, -8)
				end
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
			reply(player, "Where? /tp town · porch · barley · exchange · hiring · auction · home · shed · dock · store · back · 1–8")
		end
	end)

	register("DevPlant", "/plant", function(player, data, args)
		local crop = findCrop(args[2] or "Carrot")
		if not crop then
			reply(player, "Which crop? e.g. /plant Pumpkin")
			return
		end
		local planted = 0
		for tile = 1, 64 do
			local key = tostring(tile)
			if LandRules.isTileOpen(data.land, tile) and not data.field[key] then
				data.field[key] = GrowthRules.plant(crop.id, false, GrowthRules.rollYield(crop.id, LandRules.fieldYield(data.land), math.random()))
				planted += 1
			end
		end
		FieldService.Render(player)
		DataService.NotifyState(player)
		reply(player, `Planted {planted} {crop.name}. /grow ripe ripens them`)
	end)

	register("DevKnockOut", "/ko", function(player, _data, args)
		CrimeService.DevKnockOut(player, string.lower(args[2] or "") == "suspect")
		reply(player, "Bonk! (yourself)")
	end)

	register("DevSuspect", "/suspect", function(player)
		local plot = CrimeService.DevSuspect(player)
		reply(player, if plot > 0 then `You're a Suspect of farm {plot}` else "Stand in someone's farm first")
	end)

	register("DevCarry", "/carry", function(player, _data, args)
		if string.lower(args[2] or "") == "none" then
			CrimeService.DevCarry(player, nil, player.UserId)
			reply(player, "Your hands are empty")
			return
		end
		local crop = findCrop(args[2] or "Carrot")
		if not crop then
			reply(player, "Which crop? e.g. /carry Pumpkin, /carry Carrot 8")
			return
		end
		local count = tonumber(args[3])
		CrimeService.DevCarry(player, crop.id, player.UserId, if count then math.clamp(math.floor(count), 1, 50) else nil)
		reply(player, `Carrying stolen crops ({crop.name}). Walk into your own farm to put them in your barn`)
	end)

	register("DevLand", "/land", function(player, data, args)
		local all = string.lower(args[2] or "all") ~= "none"
		data.land.cleared = {}
		data.land.clearing = nil
		if all then
			for block = 1, Land.BLOCKS_PER_SIDE ^ 2 do
				if not LandRules.isStart(block) then
					table.insert(data.land.cleared, block)
				end
			end
		else
			for key in data.field do
				if not LandRules.isTileOpen(data.land, tonumber(key) or 0) then
					data.field[key] = nil -- (nothing grows on overgrown land)
				end
			end
		end
		FieldService.Render(player)
		LandService.Refresh(player)
		DataService.NotifyState(player)
		reply(player, if all then "Every block cleared: 64 tiles open" else "Back to the 4 start blocks")
	end)

	register("DevField", "/field", function(player, data, args)
		local to = math.clamp(math.floor(tonumber(args[2]) or (data.land.fieldLevel or 1) + 1), 1, LandRules.MAX_FIELD_LEVEL)
		data.land.fieldLevel = to
		FieldService.Render(player)
		DataService.NotifyState(player)
		reply(player, `Field Level {to}: {LandRules.fieldLevel(to).name} (crops planted from now on)`)
	end)

	register("DevDebt", "/debt", function(player, data, args)
		local amount = math.floor(tonumber(args[2]) or 3_000)
		table.insert(data.crime.debts, { ownerId = player.UserId, ownerName = "Sheriff Clucks (a test)", amount = amount, createdAt = os.time() })
		DataService.NotifyState(player)
		reply(player, `You owe {FineRules.totalDebt(data.crime, os.time())} coins. Sell something (half pays it) or pay at the police desk`)
	end)

	register("DevEarn", "/earn", function(player, _data, args)
		local amount = math.floor(tonumber(args[2]) or 2_000)
		DataService.Earn(player, amount, "Dev", true)
		reply(player, `Sold crops for {amount} coins (half goes to any debts)`)
	end)

	register("DevCrimeLog", "/crimelog", function(player)
		local text = CrimeService.DevLog(player)
		print(text)
		reply(player, "Crime log printed to the Output")
	end)

	register("DevShield", "/shield", function(player, _data, args)
		local on = args[2] == "on"
		DefenceService.DevShield(player, on)
		reply(player, if on then "Sprout Shield on: 45 minutes, and 2 of arrival grace" else "Sprout Shield and arrival grace off: you can steal and be stolen from")
	end)

	register("DevDefences", "/defences", function(player, _data, args)
		local all = args[2] ~= "none"
		DefenceService.DevAll(player, all)
		reply(player, if all then "Every defence set out round your field" else "No defences")
	end)

	register("DevTrust", "/trust", function(player, data, args)
		local name = string.lower(args[2] or "")
		if name == "none" then
			table.clear(data.trusted)
			DefenceService.Redraw(player)
			reply(player, "Trusted list emptied")
			return
		end
		for _, other in Players:GetPlayers() do
			if other ~= player and (string.lower(other.Name) == name or string.lower(other.DisplayName) == name) then
				table.insert(data.trusted, { id = other.UserId, name = other.DisplayName })
				DefenceService.Redraw(player)
				reply(player, `{other.DisplayName} is Trusted`)
				return
			end
		end
		reply(player, "Nobody here by that name")
	end)

	register("DevAuction", "/auction", function(player, _data, args)
		local wanted = string.lower(args[2] or "now")
		if wanted == "soon" then
			local real = workspace:GetServerTimeNow()
			ReplicatedStorage:SetAttribute("AuctionShift", (Auction.INTERVAL - 70 - real % Auction.INTERVAL) % Auction.INTERVAL)
			reply(player, "The next auction starts in 70 s (its note comes 60 s before)")
		elseif wanted == "off" then
			ReplicatedStorage:SetAttribute("AuctionShift", nil)
			reply(player, "The auction clock is back to the real time")
		else
			AuctionService.DevStart()
			reply(player, "An auction starts now: /tp auction to bid")
		end
	end)

	register("DevQuests", "/quests", function(player, data, args)
		local tier, scale = QuestRules.tier(data.level)
		local list = {}
		for i = 2, #args do
			for _, def in Quests.POOL do
				if string.lower(def.id) == string.lower(args[i]) then
					table.insert(list, { id = def.id, stat = def.stat, n = def.n[tier], reward = def.reward * scale, progress = 0, claimed = false })
				end
			end
		end
		if #list == 0 then
			reply(player, "Quests: Harvest · Ship · Store · Mutation · Arrest · Deposit · Auction")
			return
		end
		data.quests.day = QuestRules.day(os.time())
		data.quests.list = list
		data.quests.bonusClaimed = false
		DataService.NotifyState(player)
		reply(player, `Today's quests: {#list} set`)
	end)

	register("DevWeather", "/weather", function(player, _data, args)
		local wanted = string.lower(args[2] or "")
		if wanted == "off" then
			ReplicatedStorage:SetAttribute("WeatherForce", nil)
			ReplicatedStorage:SetAttribute("WeatherForceUntil", nil)
		elseif wanted ~= "" then
			local id = nil
			for key in Weather.TYPES do
				if string.lower(key) == wanted then
					id = key
				end
			end
			if not id then
				reply(player, "Weather: Clear · Rain · Thunderstorm · FrostNight · GoldenHour · HarvestMoon (or off)")
				return
			end
			ReplicatedStorage:SetAttribute("WeatherForce", id)
			ReplicatedStorage:SetAttribute("WeatherForceUntil", WeatherRules.now() + (Weather.TYPES[id].length or Weather.SLOT))
		end
		local t = WeatherRules.now()
		local w = WeatherRules.weather(t)
		reply(player, `{Weather.TYPES[w.id].name} for {math.floor(w.endsAt - t)} s{if w.forced then " (forced)" else ""}; the next Harvest Moon in {math.floor((WeatherRules.nextMoon(t) - t) / 60)} min`)
	end)

	register("DevTime", "/time", function(player, _data, args)
		local wanted = string.lower(args[2] or "")
		local hours = ({ sunrise = 6, noon = 12, dusk = 16.5, night = 20, midnight = 0 })[wanted] or tonumber(wanted)
		if wanted == "off" then
			ReplicatedStorage:SetAttribute("ClockShift", nil)
		elseif hours and hours >= 0 and hours < 24 then
			-- seconds into the day that show this hour on the sky's clock
			local daylight = Weather.DAY - Weather.NIGHT
			local target = if hours >= 6 and hours < 18 then (hours - 6) / 12 * daylight else daylight + ((hours - 18) % 24) / 12 * Weather.NIGHT
			local real = workspace:GetServerTimeNow()
			ReplicatedStorage:SetAttribute("ClockShift", (target - real % Weather.DAY) % Weather.DAY)
		else
			reply(player, "Time: sunrise · noon · dusk · night · midnight, an hour 0–23, or off")
			return
		end
		local t = WeatherRules.now()
		reply(player, string.format("The clock says %02d:%02d%s", math.floor(WeatherRules.clock(t)), math.floor(WeatherRules.clock(t) % 1 * 60), if WeatherRules.isNight(t) then " (night)" else ""))
	end)

	register("DevGuide", "/guide", function(player)
		GuideService.Reset(player)
		reply(player, "The Farm Guide starts again (its coins to earn again)")
	end)

	register("DevWipe", "/wipe", function(player)
		DataService.Wipe(player)
		reply(player, "Save wiped: a brand-new farm")
	end)
end

return DevCommandService
