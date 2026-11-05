-- The warehouse (docs/GameDesign.md §4.6; the rules are shared/WarehouseRules,
-- the look World/YardArt): Warehouse Levels (Upgrade, and the new buildings
-- going up while the old one keeps working), washing and packing by hand, and
-- what the crew does with each crop. The trucks are TruckService's; the crew
-- is WorkerService's.
--
-- By hand, at the bench (the Packing Shed's; the warehouses' wash table) you
-- pick a barn stack, hold to wash it and let go in the green for grade A
-- (shared/CrateRules; the server times the hold itself). The crate joins your
-- packed crates, for a truck or your store (shared/PackRules): load it at the
-- dock (TruckService) or put it out at a display (StoreService). While
-- they're full there's no packing: make room first.
--
-- WarehouseAction remote: "Wash" stackKey, then "Pack" · "Upgrade" · "Route"
-- "cropId|Truck" (Store, Keep, or a share for the truck 0–1) · "PackKind"
-- "Golden|Pack" (or Keep; any mutation, or Giant) · "SendCrate" "stackKey|grade"
-- (to the stockroom, at the crates) · "DriverRule" share of the base value (0 =
-- whenever full).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local BarnRules = require(Shared.BarnRules)
local CrateRules = require(Shared.CrateRules)
local Crops = require(Shared.Config.Crops)
local Growth = require(Shared.Config.Growth)
local PackRules = require(Shared.PackRules)
local Remotes = require(Shared.Remotes)
local Warehouse = require(Shared.Config.Warehouse)
local WarehouseRules = require(Shared.WarehouseRules)
local Weather = require(Shared.Config.Weather)
local WorkerRules = require(Shared.WorkerRules)

local Server = ServerScriptService.Server
local ActionRemote = require(Server.Util.ActionRemote)
local Analytics = require(Server.Util.Analytics)
local Notice = require(Server.Util.Notice)
local YardArt = require(Server.World.YardArt)
local DataService = require(script.Parent.DataService)
local MovementService = require(script.Parent.MovementService)
local PlotService = require(script.Parent.PlotService)
local StoreService = require(script.Parent.StoreService)
local GuideService = require(script.Parent.GuideService)

local WarehouseService = {}

WarehouseService.BENCH_REACH = 12 -- studs from the bench you can pack from
local CRATES_REACH = 16 -- studs from the rack or the Cold Room's sign you can send crates from
local DRIVER_RULES = { 0, 0.9, 1, 1.1, 1.2, 1.3 } -- the Drivers' choices (share of the base value)
WarehouseService.DRIVER_RULES = DRIVER_RULES

local washing = {} -- [Player] = { key, at } while the wash is held
local rebuiltCallbacks = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function warehouseModel(index: number): Model?
	return PlotService.model(index):FindFirstChild("Warehouse") :: Model?
end

local function bench(index: number): BasePart?
	local warehouse = warehouseModel(index)
	return warehouse and warehouse.Building:FindFirstChild("Bench") :: BasePart?
end

-- What the packed crates' prompt hangs on: the rack, or the Cold Room's sign.
local function cratesSpot(index: number): BasePart?
	local warehouse = warehouseModel(index)
	local found = warehouse and (warehouse:FindFirstChild("CratesSpot", true) or warehouse:FindFirstChild("ColdRoomCount", true))
	return if found and found:IsA("BasePart") then found else nil
end

-- Redraws the packed crates where you see them (the rack, the Cold Room, the
-- stockroom).
function WarehouseService.showHold(player: Player)
	StoreService.StockroomChanged(player)
end

-- Calls callback(player, index, data) after a farm's warehouse side is
-- rebuilt (a new level): TruckService and WorkerService put their prompts,
-- crates and people back.
function WarehouseService.OnRebuilt(callback)
	table.insert(rebuiltCallbacks, callback)
end

-- The bench's prompt (the window opens on the client).
local function benchPrompt(player: Player, index: number)
	local top = bench(index)
	if not top then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BenchPrompt"
	prompt.ActionText = "Wash & pack"
	prompt.ObjectText = if WarehouseRules.level(DataService.Get(player).warehouse.level).stage == 1 then "Packing Shed" else "Wash table"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Opens", "Bench") -- (the client opens the bench window)
	prompt:SetAttribute("OwnerId", player.UserId)
	prompt.Parent = top
end

-- The packed crates' prompt (the window opens on the client: RackController).
local function cratesPrompt(player: Player, index: number)
	local at = cratesSpot(index)
	if not at then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CratesPrompt"
	prompt.ActionText = "Send to stockroom"
	prompt.ObjectText = "Packed crates"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Opens", "Rack")
	prompt:SetAttribute("OwnerId", player.UserId)
	prompt.Parent = at
end

-- Builds the warehouse side for the owner's level and puts everything back.
local function rebuild(player: Player, index: number, data)
	local model = PlotService.model(index)
	YardArt.setLevel(model, data.warehouse.level)
	model:SetAttribute("WarehouseLevel", data.warehouse.level)
	benchPrompt(player, index)
	cratesPrompt(player, index)
	WarehouseService.showHold(player)
	if data.warehouse.build then
		YardArt.showConstruction(model, data.warehouse.build.to, math.ceil(data.warehouse.build.left))
	else
		YardArt.showConstruction(model, nil)
	end
	for _, callback in rebuiltCallbacks do
		task.spawn(callback, player, index, data)
	end
end

-- A level reached (instantly, or a building finished): the new building,
-- Shed Hands become Packers in the first warehouse, and a card.
local function reached(player: Player, data, before: number)
	local after = data.warehouse.level
	local index = PlotService.plotOf(player)
	local was, info = WarehouseRules.level(before), WarehouseRules.level(after)
	if was.stage == 1 and info.stage > 1 then
		local packers = WorkerRules.count(data.workers, "ShedHand")
		WorkerRules.promoteShedHands(data.workers)
		if packers > 0 then
			Notice.send(player, `Your Shed Hand{if packers == 1 then " is" else "s are"} a Packer now: same level, same XP.`)
		end
	end
	if index then
		rebuild(player, index, data)
	end
	if info.stage ~= was.stage then
		Notice.send(player, `🏭 Your {info.building.name} is ready!`, "Good")
	end
	Notice.send(player, `Warehouse Level {after}! {table.concat(WarehouseRules.news(after), " · ")}`, "Good")
	Analytics.progress(player, "WarehouseLevel", after)
	DataService.NotifyState(player)
end

-- Dev command /warehouse N: straight to level N (up only; buildings done at once).
function WarehouseService.SetLevel(player: Player, to: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local before = data.warehouse.level
	to = math.clamp(to, before, WarehouseRules.MAX_LEVEL)
	WarehouseRules.finish(data.warehouse, to)
	YardArt.showConstruction(PlotService.model(PlotService.plotOf(player) or 1), nil)
	reached(player, data, before)
end

------------------------------------------------------------------------
-- Actions

local actions = {}

-- stackKey: starts the wash (the hold).
function actions.Wash(player, data, key)
	if not key or not string.match(key, "^[%w|]+$") or not Crops.ById[BarnRules.parse(key)] then
		return "BadRequest"
	end
	local index = PlotService.plotOf(player)
	if not index then
		return "NoFarm"
	end
	local top = bench(index)
	local position = MovementService.positionOf(player)
	if not top or not position or (position - top.Position).Magnitude > WarehouseService.BENCH_REACH then
		return "TooFar"
	end
	if (data.inventory.crops[key] or 0) <= 0 then
		return "NoCrops"
	elseif PackRules.room(data) <= 0 then
		return "PackedFull"
	end
	washing[player] = { key = key, at = now() }
	return nil
end

-- Letting go: the grade is from the server's own timing of the hold.
function actions.Pack(player, data)
	local wash = washing[player]
	washing[player] = nil
	if not wash then
		return "NotWashing"
	end
	if not PlotService.plotOf(player) then
		return "NoFarm"
	elseif PackRules.room(data) <= 0 then
		return "PackedFull" -- (the crew filled the last space meanwhile)
	end
	local grade = CrateRules.grade(now() - wash.at, Warehouse.WASH.slack)
	local crate = CrateRules.pack(data.inventory, wash.key, grade)
	if not crate then
		return "NoCrops"
	end
	local units = crate.units
	PackRules.stow(data, crate)
	WarehouseService.showHold(player)
	Analytics.step(player, data, "FirstCrate")
	GuideService.Record(player, "Pack")
	DataService.NotifyState(player)
	return nil, { grade = grade, units = units, crop = crate.crop }
end

function actions.Upgrade(player, data)
	local failure = WarehouseRules.cannotUpgrade(data.warehouse, data.level, data.coins)
	if failure then
		return failure
	end
	local before = data.warehouse.level
	local cost = WarehouseRules.level(before + 1).cost
	if not DataService.SpendCoins(player, cost, Analytics.SHOP, `Warehouse{before + 1}`) then
		return "NoCoins"
	end
	if WarehouseRules.upgrade(data.warehouse) == "Building" then
		local to = WarehouseRules.level(data.warehouse.build.to)
		YardArt.showConstruction(PlotService.model(PlotService.plotOf(player) or 1), data.warehouse.build.to, math.ceil(data.warehouse.build.left))
		Notice.send(player, `🏗 The builders are putting up your {to.building.name}: {to.building.buildSeconds // 60} minutes. Your {WarehouseRules.level(before).building.name} keeps working meanwhile.`, "Good")
		DataService.NotifyState(player)
		return nil, { building = true }
	end
	reached(player, data, before)
	return nil, { building = false }
end

-- "cropId|Truck" · "cropId|Store" · "cropId|Keep" · "cropId|0.7" (a split:
-- that share for the truck; from Warehouse Level 5).
function actions.Route(player, data, arg)
	local cropId, choice = string.match(arg or "", "^(%w+)|([%w%.]+)$")
	if not cropId or not Crops.ById[cropId] then
		return "BadRequest"
	end
	local routes = data.warehouse.routes
	if choice == "Truck" then
		routes[cropId] = nil
	elseif choice == "Store" then
		routes[cropId] = 0
	elseif choice == "Keep" then
		routes[cropId] = "Keep"
	else
		local share = tonumber(choice)
		if not share or share ~= share then
			return "BadRequest"
		end
		if not WarehouseRules.level(data.warehouse.level).splits then
			return "NeedWarehouse5"
		end
		share = math.clamp(math.round(share * 10) / 10, 0, 1)
		routes[cropId] = if share >= 1 then nil else share
	end
	DataService.NotifyState(player)
	return nil
end

-- "stackKey|grade": crates of that stack to the stockroom (with the hand cart,
-- up to four at a time).
function actions.SendCrate(player, data, arg)
	local key, grade = string.match(arg or "", "^([%w|]+)|(%a)$")
	local index = PlotService.plotOf(player)
	local at = index and cratesSpot(index)
	local position = MovementService.positionOf(player)
	if not key or not grade then
		return "BadRequest"
	elseif not at or not position or (position - at.Position).Magnitude > CRATES_REACH then
		return "TooFar"
	elseif not CrateRules.storeable(key) then
		return "TruckOnly"
	elseif PackRules.stockroomRoom(data) <= 0 then
		return "StockroomFull"
	end
	local info = WarehouseRules.level(data.warehouse.level)
	if PackRules.send(data, key, grade, if info.handCart then Warehouse.HAND_CART else 1) == 0 then
		return "NoCrate"
	end
	WarehouseService.showHold(player)
	DataService.NotifyState(player)
	return nil
end

-- Whether the crew packs a kind of mutated crop (PackRules.crewTakes).
function actions.PackKind(player, data, arg)
	local kind, choice = string.match(arg or "", "^(%a+)|(%a+)$")
	if not kind or (kind ~= "Giant" and not Weather.MUTATIONS[kind]) or (choice ~= "Pack" and choice ~= "Keep") then
		return "BadRequest"
	end
	data.warehouse.packs[kind] = if choice == "Pack" then true else nil
	DataService.NotifyState(player)
	return nil
end

function actions.DriverRule(player, data, arg)
	local share = tonumber(arg)
	if not share or not table.find(DRIVER_RULES, share) then
		return "BadRequest"
	end
	data.warehouse.driverRule = share
	DataService.NotifyState(player)
	return nil
end

------------------------------------------------------------------------

function WarehouseService.Start()
	ActionRemote(Remotes.func("WarehouseAction"), actions, DataService, 0.05)

	PlotService.OnAssigned(function(player, index)
		local data = DataService.Get(player)
		-- a building that went up while you were away (at the offline rate)
		local build = data.warehouse.build
		if build then
			local before = data.warehouse.level
			if WarehouseRules.work(data.warehouse, DataService.AwaySeconds(player) * Growth.OFFLINE_RATE) then
				reached(player, data, before)
				return
			end
		end
		rebuild(player, index, data)
	end)

	PlotService.OnReleased(function(_player, index)
		local model = PlotService.model(index)
		YardArt.showConstruction(model, nil)
		YardArt.setLevel(model, 1)
		model:SetAttribute("WarehouseLevel", nil)
	end)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			washing[player] = nil
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	DataService.OnWiped(function(player, data)
		local index = PlotService.plotOf(player)
		if index then
			rebuild(player, index, data)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		washing[player] = nil
	end)

	-- Buildings going up, a second at a time.
	task.spawn(function()
		while true do
			task.wait(1)
			for player in PlotService.owners() do
				local data = DataService.Get(player)
				local build = data and data.warehouse.build
				if build then
					local ok, err = pcall(function()
						local before = data.warehouse.level
						if WarehouseRules.work(data.warehouse, 1) then
							reached(player, data, before)
						else
							YardArt.showConstruction(PlotService.model(PlotService.plotOf(player)), build.to, math.ceil(build.left))
						end
					end)
					if not ok then
						warn(`[WarehouseService] {player.Name}'s building: {err}`)
					end
				end
			end
		end
	end)
end

return WarehouseService
