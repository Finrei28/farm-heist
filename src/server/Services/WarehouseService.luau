-- The warehouse (docs/GameDesign.md §4.6; the rules are shared/WarehouseRules,
-- the look World/YardArt): Warehouse Levels (Upgrade, and the new buildings
-- going up while the old one keeps working), washing and packing by hand,
-- where each crop's crates go, and the crates waiting for a truck. The
-- trucks are TruckService's; the crew is WorkerService's.
--
-- By hand, at the bench (the Packing Shed's; the warehouses' wash table) you
-- pick a barn stack and where its crate goes (the truck or your store),
-- hold to wash it and let go in the green for grade A (shared/CrateRules;
-- the server times the hold itself). A crate for the store goes to its
-- stockroom (StoreService; you put it out with Fill), unless the
-- stockroom's full: then it's for the truck. A crate for the truck goes
-- into your arms at the Packing Shed (carry it to the dock and load it,
-- TruckService), and onto the conveyor to the Cold Room in the warehouses.
--
-- A crate you're carrying is set down on the dock's rack if you leave your
-- farm, travel, respawn or leave the game, so nothing is ever lost: the
-- dock's "Load crate" takes from the rack too.
--
-- WarehouseAction remote: "Wash" "stackKey|Truck" or "stackKey|Store", then
-- "Pack" · "Upgrade" · "Route" "cropId|Truck" (Store, Keep, or a share for
-- the truck 0–1) · "DriverRule" share of the base value (0 = whenever full).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local BarnRules = require(Shared.BarnRules)
local CrateRules = require(Shared.CrateRules)
local Crops = require(Shared.Config.Crops)
local Growth = require(Shared.Config.Growth)
local Remotes = require(Shared.Remotes)
local ShopRules = require(Shared.ShopRules)
local Warehouse = require(Shared.Config.Warehouse)
local WarehouseRules = require(Shared.WarehouseRules)
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

local WarehouseService = {}

WarehouseService.BENCH_REACH = 12 -- studs from the bench you can pack from
local DRIVER_RULES = { 0, 0.9, 1, 1.1, 1.2, 1.3 } -- the Drivers' choices (share of the base value)
WarehouseService.DRIVER_RULES = DRIVER_RULES

local washing = {} -- [Player] = { key, to, at } while the wash is held
local carrying = {} -- [Player] = crate
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

-- The crate a player is carrying, or nil.
function WarehouseService.carried(player: Player)
	return carrying[player]
end

local function setCarrying(player: Player, crate)
	carrying[player] = crate
	player:SetAttribute("Carrying", if crate then crate.crop else nil)
	if player.Character then
		YardArt.carry(player.Character, crate)
	end
end

-- Takes the crate out of a player's arms (TruckService loading it).
function WarehouseService.takeCarried(player: Player)
	local crate = carrying[player]
	if crate then
		setCarrying(player, nil)
	end
	return crate
end

-- Redraws the crates waiting for a truck (the rack, the Cold Room).
function WarehouseService.showHold(player: Player)
	local index = PlotService.plotOf(player)
	local data = DataService.Get(player)
	if index and data then
		YardArt.showHold(PlotService.model(index), data.warehouse.dock)
	end
end

-- Puts a crate on the rack or in the Cold Room (it always fits: nothing's lost).
function WarehouseService.hold(player: Player, data, crate)
	table.insert(data.warehouse.dock, crate)
	WarehouseService.showHold(player)
end

-- Sets the carried crate down on the rack (left the farm, travelled,
-- respawned, leaving). draw = false while leaving (the farm is going).
local function setDown(player: Player, data, draw: boolean, why: string?)
	local crate = carrying[player]
	if not crate then
		return
	end
	setCarrying(player, nil)
	table.insert(data.warehouse.dock, crate)
	if draw then
		WarehouseService.showHold(player)
		DataService.NotifyState(player)
		if why then
			Notice.send(player, why)
		end
	end
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

-- Builds the warehouse side for the owner's level and puts everything back.
local function rebuild(player: Player, index: number, data)
	local model = PlotService.model(index)
	YardArt.setLevel(model, data.warehouse.level)
	model:SetAttribute("WarehouseLevel", data.warehouse.level)
	benchPrompt(player, index)
	YardArt.showHold(model, data.warehouse.dock)
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
		if carrying[player] then
			setDown(player, data, false)
		end
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
	Analytics.step(player, data, `Warehouse{after}`)
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

-- "stackKey|Truck" or "stackKey|Store": starts the wash (the hold).
function actions.Wash(player, data, arg)
	local key, to = string.match(arg or "", "^([%w|]+)|(%a+)$")
	if not key or (to ~= "Truck" and to ~= "Store") or not Crops.ById[BarnRules.parse(key)] then
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
	end
	local shed = WarehouseRules.level(data.warehouse.level).stage == 1
	if shed and to == "Truck" and carrying[player] then
		return "Carrying"
	end
	if shed and to == "Store" and ShopRules.stockroomRoom(data.store) <= 0 and carrying[player] then
		return "StockroomFull" -- (the crate would have to go to the truck, but your arms are full)
	end
	washing[player] = { key = key, to = to, at = now() }
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
	end
	local shed = WarehouseRules.level(data.warehouse.level).stage == 1
	if shed and wash.to == "Truck" and carrying[player] then
		return "Carrying"
	end
	local grade = CrateRules.grade(now() - wash.at, Warehouse.WASH.slack)
	local crate = CrateRules.pack(data.inventory, wash.key, grade)
	if not crate then
		return "NoCrops"
	end
	local to = wash.to
	if to == "Store" and ShopRules.stockroomRoom(data.store) <= 0 then
		to = "Truck" -- (a full stockroom: this one's for the truck)
		Notice.send(player, "Your store's stockroom is full, so this crate's for the truck. A higher Store Level holds more.")
	end
	if to == "Store" then
		table.insert(data.store.stockroom, crate)
		StoreService.StockroomChanged(player) -- (the stockroom's crates and the displays' prompts)
	elseif shed then
		setCarrying(player, crate)
	else
		WarehouseService.hold(player, data, crate) -- (along the conveyor to the Cold Room)
	end
	Analytics.step(player, data, "FirstCrate")
	DataService.NotifyState(player)
	return nil, { grade = grade, units = crate.units, crop = crate.crop, to = if to == "Truck" and not shed then "ColdRoom" else to }
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

	-- Leaving your farm (walking out, travelling) sets the crate down at the dock.
	local function watch(player: Player)
		player:GetAttributeChangedSignal("InFarm"):Connect(function()
			local data = DataService.Get(player)
			if data and carrying[player] and PlotService.inFarm(player) ~= PlotService.plotOf(player) then
				setDown(player, data, true, "You left your farm, so you set the crate down at the dock.")
			end
		end)
		player.CharacterRemoving:Connect(function()
			local data = DataService.Get(player)
			if data then
				setDown(player, data, true)
			end
		end)
		player.CharacterAdded:Connect(function()
			washing[player] = nil
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	DataService.BeforeRelease(function(player, data)
		setDown(player, data, false)
	end)
	DataService.OnWiped(function(player, data)
		carrying[player] = nil
		player:SetAttribute("Carrying", nil)
		if player.Character then
			YardArt.carry(player.Character, nil)
		end
		local index = PlotService.plotOf(player)
		if index then
			rebuild(player, index, data)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function() -- (after BeforeRelease has set the crate down)
			washing[player] = nil
			carrying[player] = nil
		end)
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
