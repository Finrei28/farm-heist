-- Your crew (docs/GameDesign.md §4.9; the rules are shared/WorkerRules):
-- hiring from the board (the Hiring Hall in town, or the Workers window),
-- training, firing and the Farmhands' replanting; the crew at work while
-- you play, a second at a time (Farmhands harvest and replant, a Shed Hand
-- or the Sorters, Packers and Loaders move crates along, Drivers send full
-- trucks by your rule, Stockers fill displays; Cashiers and the Greeter
-- work in StoreService through StoreService.crew), earning XP only for
-- real work; wages every minute and strikes when they can't be paid; and,
-- when you come back, your time away worked out in one go
-- (shared/PipelineRules: growth, the crew at a quarter speed for up to 8
-- hours, store sales) with the Welcome back card.
--
-- WorkerAction remote: "Hire" candidateId · "Train" uid · "Fire" uid ·
-- "Replant" "same" | "cheapest" | "none".
-- WorkerEvent remote (S→C): where each worker stands, and their walks
-- (WorkerController draws them).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local BarnRules = require(Shared.BarnRules)
local CrateRules = require(Shared.CrateRules)
local Crops = require(Shared.Config.Crops)
local GrowthRules = require(Shared.GrowthRules)
local LandRules = require(Shared.LandRules)
local PipelineRules = require(Shared.PipelineRules)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local ShopRules = require(Shared.ShopRules)
local Store = require(Shared.Config.Store)
local StoreLayout = require(Shared.StoreLayout)
local TruckRules = require(Shared.TruckRules)
local WarehouseRules = require(Shared.WarehouseRules)
local WorkerRules = require(Shared.WorkerRules)
local Workers = require(Shared.Config.Workers)

local Server = ServerScriptService.Server
local ActionRemote = require(Server.Util.ActionRemote)
local Analytics = require(Server.Util.Analytics)
local Notice = require(Server.Util.Notice)
local YardArt = require(Server.World.YardArt)
local DataService = require(script.Parent.DataService)
local FieldService = require(script.Parent.FieldService)
local MarketService = require(script.Parent.MarketService)
local PlotService = require(script.Parent.PlotService)
local StoreService = require(script.Parent.StoreService)
local TruckService = require(script.Parent.TruckService)
local WarehouseService = require(script.Parent.WarehouseService)

local WorkerService = {}

local TICK = 1
local XP_SECOND = Workers.XP_PER_MINUTE / 60
local HIRE_LEVEL = 2 -- Farm Level to hire (§4.9)
local WELCOME_AWAY = 120 -- seconds away before the Welcome back card
local SORTED_MAX = 12 -- batches Sorters wash ahead of the Packers
local WALK = 10 -- studs a second, a worker's walk

local WorkerEvent = Remotes.event("WorkerEvent")
local rng = Random.new()

local crews = {} -- [Player] = { budgets = { [uid] = n }, routeAcc = {}, wageAt, told = {} }

local function now(): number
	return workspace:GetServerTimeNow()
end

-- The crew in hiring order: { { uid, worker } }.
local function roster(data)
	local list = {}
	for uid, worker in data.workers do
		table.insert(list, { uid = uid, worker = worker })
	end
	table.sort(list, function(a, b)
		return (tonumber(a.uid) or 0) < (tonumber(b.uid) or 0)
	end)
	return list
end

-- Workers of a type in hiring order (the first Driver drives truck 1, the
-- first Cashier works the first Register ...).
local function ofType(data, typeName: string)
	local list = {}
	for _, entry in roster(data) do
		if entry.worker.type == typeName then
			table.insert(list, entry)
		end
	end
	return list
end

-- The Registers in the layout, in id order.
local function registers(store): { string }
	local ids = {}
	for id, entry in store.layout do
		if entry.item == "Register" then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	return ids
end

-- What WorkerRules.slots needs about a farm.
local function context(data)
	local info = WarehouseRules.level(data.warehouse.level)
	return {
		warehouseLevel = data.warehouse.level,
		storeLevel = data.store.level,
		openTiles = LandRules.openTiles(data.land),
		registers = #registers(data.store),
		trucks = info.trucks,
	}
end
WorkerService.context = context

------------------------------------------------------------------------
-- Where they stand (world space), for the clients

local function spotOf(index: number, data, entry, nth: number): (Vector3, Vector3)
	local worker = entry.worker
	local frame = PlotLayout.frame(index)
	local function at(local_: Vector3, face: Vector3): (Vector3, Vector3)
		return frame:PointToWorldSpace(local_), frame:VectorToWorldSpace(face)
	end
	local info = WarehouseRules.level(data.warehouse.level)
	local layout = PlotLayout.WAREHOUSES[info.stage]
	local floor = if info.stage == 1 then 0.5 else PlotLayout.PLOT.dock.height
	local offsets = { 0, -2.6, 2.6, -5.2, 5.2 }
	local t = worker.type
	if t == "Farmhand" then
		return at(Vector3.new(-14 + nth * 6, 0.2, PlotLayout.PLOT.field.depth - 3), Vector3.new(0, 0, 1))
	elseif t == "ShedHand" then
		return at(layout.bench + Vector3.new(-2.5 + (nth - 1) * 5, floor, -3), Vector3.new(0, 0, 1))
	elseif (t == "Sorter" or t == "Packer" or t == "Loader") and layout.stations then
		local station = layout.stations[if t == "Sorter" then "Sort" elseif t == "Packer" then "Pack" else "Load"]
		return at(station + Vector3.new(0, floor, offsets[(nth - 1) % #offsets + 1]), Vector3.new(1, 0, 0))
	elseif t == "Driver" then
		local across = layout.docks[math.min(nth, #layout.docks)]
		local length = YardArt.TRUCK_LENGTH[info.truck]
		return at(PlotLayout.truckParked(across, length) + Vector3.new(-6, 0.2, -length / 2 + 6), Vector3.new(1, 0, 0))
	elseif t == "Stocker" then
		return at(PlotLayout.storeLocal(1.3, Store.STAFF_Y + 0.5 + (nth - 1) * 0.8, PlotLayout.PLOT.store.floor), Vector3.new(-1, 0, 0))
	elseif t == "Cashier" then
		local id = registers(data.store)[nth]
		local entry_ = id and data.store.layout[id]
		local behind = entry_ and StoreLayout.behind(entry_)[1]
		if behind then
			local spot = PlotLayout.storeLocal(behind[1], behind[2], PlotLayout.PLOT.store.floor)
			local front = PlotLayout.storeLocal(entry_.x, entry_.y, PlotLayout.PLOT.store.floor)
			return at(spot, (front - spot).Unit)
		end
	elseif t == "Greeter" then
		return at(PlotLayout.storeLocal(Store.DOOR_X - 0.9, 1, PlotLayout.PLOT.store.floor), Vector3.new(0, 0, -1))
	end
	return at(PlotLayout.PLOT.door, Vector3.new(0, 0, 1))
end

-- Tells the clients (every one, or just `to`) where this farm's crew
-- stands (after a hire, a level, a strike, a new building ...).
local function showCrew(player: Player, to: Player?)
	local index = PlotService.plotOf(player)
	local data = DataService.Get(player)
	if not index or not data then
		return
	end
	local st = crews[player]
	local list, counts = {}, {}
	for _, entry in roster(data) do
		local t = entry.worker.type
		counts[t] = (counts[t] or 0) + 1
		local position, face = spotOf(index, data, entry, counts[t])
		if st then
			st.spots[entry.uid] = position
		end
		table.insert(list, {
			id = entry.uid, type = t, name = entry.worker.name, level = entry.worker.level, look = entry.worker.look or 1,
			at = position, face = face, strike = data.crew.strike, nth = counts[t],
		})
	end
	if to then
		WorkerEvent:FireClient(to, "Crew", { plot = index, workers = list })
	else
		WorkerEvent:FireAllClients("Crew", { plot = index, workers = list })
	end
end
WorkerService.ShowCrew = showCrew

-- A worker walks to a world point and back (a harvest, a load, a refill).
local function walk(index: number, uid: string, from: Vector3, to: Vector3, carry: string?)
	local seconds = (to - from).Magnitude / WALK
	WorkerEvent:FireAllClients("Do", { plot = index, id = uid, at = now(), to = to, seconds = math.clamp(seconds, 0.4, 6), carry = carry })
end

------------------------------------------------------------------------
-- The crew at work (a second at a time while you play)

-- A worker's budget for its unit of work this second: builds up at their
-- speed while there's work, never more than a unit's worth ahead.
local function charge(st, uid: string, perMinute: number, cost: number): number
	local budget = (st.budgets[uid] or 0) + perMinute / 60
	budget = math.min(budget, cost + perMinute / 60)
	st.budgets[uid] = budget
	return budget
end

local function rest(st, uid: string)
	st.budgets[uid] = math.min(st.budgets[uid] or 0, 0)
end

-- Where the next crate of a crop goes by its route (shares kept exact over
-- many crates): "Truck" or "Store" (a full stockroom sends it to the
-- truck), and the route's count to keep once it's packed (commit).
local function destination(st, data, cropId: string): (string, () -> ())
	local share = WarehouseRules.route(data.warehouse, cropId) or 1
	local acc = (st.routeAcc[cropId] or 0) + share
	local to = "Store"
	if acc >= 1 - 1e-9 then
		acc -= 1
		to = "Truck"
	end
	local function commit()
		st.routeAcc[cropId] = acc
	end
	if to == "Store" and ShopRules.stockroomRoom(data.store) <= 0 then
		return "Truck", commit
	end
	return to, commit
end

-- A barn stack the warehouse may take (routed, not kept) with a full crate's
-- worth in it, or nil.
local function nextStack(data): (string?, string?)
	local keys = {}
	for key, units in data.inventory.crops do
		local cropId = BarnRules.parse(key)
		if Crops.ById[cropId] and WarehouseRules.route(data.warehouse, cropId) and units >= CrateRules.size(cropId) then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	local key = keys[1]
	return key, key and BarnRules.parse(key)
end

local function holdRoom(data): number
	return WarehouseRules.level(data.warehouse.level).hold - #data.warehouse.dock
end

local JOBS = {}

function JOBS.Farmhand(player, data, st, entry, speed, index)
	if not st.ripe then
		st.ripe = FieldService.RipeTiles(player, data)
	end
	if #st.ripe == 0 then
		rest(st, entry.uid)
		return false
	end
	if not BarnRules.hasRoom(data.inventory, data.silo, 1) then
		rest(st, entry.uid)
		if not st.told.barnFull then
			st.told.barnFull = true
			Notice.send(player, "Barn full: your Farmhands are waiting. Sell or pack some crops.", "Error")
		end
		return false
	end
	st.told.barnFull = nil
	local budget = charge(st, entry.uid, speed, 1)
	while budget >= 1 and #st.ripe > 0 do
		local key = table.remove(st.ripe, 1)
		local cropId = data.field[key] and data.field[key].crop
		local failure, note = FieldService.WorkerHarvest(player, data, key, data.crew.replant)
		if failure == nil then
			budget -= 1
			if note == "NoSeeds" and cropId and not st.told[`seeds{cropId}`] then
				st.told[`seeds{cropId}`] = true
				Notice.send(player, `🌱 Out of {Crops.ById[cropId].name} seeds: your Farmhands harvest but can't replant. Barley sells more in town.`, "Error")
			end
			walk(index, entry.uid, st.spots[entry.uid] or PlotLayout.tileWorld(index, tonumber(key) :: number), PlotLayout.tileWorld(index, tonumber(key) :: number), BarnRules.parse(key))
		end
	end
	st.budgets[entry.uid] = budget
	return true
end

-- The Shed Hand: loads the pickup from the rack when it's home, and packs
-- full crates from the barn (to the pickup, the rack, or the store).
function JOBS.ShedHand(player, data, st, entry, speed, _index)
	local warehouse = data.warehouse
	local t = now()
	local loadable = #warehouse.dock > 0 and TruckRules.cannotLoad(warehouse, t) == nil
	local key, cropId = nextStack(data)
	local canPack = key ~= nil and (TruckRules.cannotLoad(warehouse, t) == nil or holdRoom(data) > 0 or ShopRules.stockroomRoom(data.store) > 0)
	if not loadable and not canPack then
		rest(st, entry.uid)
		return false
	end
	local budget = charge(st, entry.uid, speed, 1)
	local changed = false
	if budget >= 1 and loadable then
		budget -= 1
		TruckRules.load(warehouse, table.remove(warehouse.dock, 1), t)
		changed = true
	end
	if budget >= 1 and canPack and key and cropId then
		local to, commit = destination(st, data, cropId)
		if to == "Truck" and TruckRules.cannotLoad(warehouse, t) ~= nil and holdRoom(data) <= 0 then
			to = "Wait"
		end
		if to ~= "Wait" then
			commit()
			budget -= 1
			local grade = if rng:NextNumber() < WorkerRules.gradeAChance(entry.worker) then "A" else "B"
			local crate = CrateRules.pack(data.inventory, key, grade)
			if crate and to == "Store" then
				table.insert(data.store.stockroom, crate)
				StoreService.StockroomChanged(player)
			elseif crate and TruckRules.load(warehouse, crate, t) ~= nil then
				table.insert(warehouse.dock, crate)
			end
			changed = true
		end
	end
	st.budgets[entry.uid] = budget
	if changed then
		st.trucksChanged = true
		st.holdChanged = true
	end
	return true
end

-- Sorters wash a crate's worth at a time and grade it.
function JOBS.Sorter(_player, data, st, entry, speed, _index)
	local key, cropId = nextStack(data)
	if not key or not cropId or #data.warehouse.sorted >= SORTED_MAX then
		rest(st, entry.uid)
		return false
	end
	local size = CrateRules.size(cropId)
	local budget = charge(st, entry.uid, speed, size)
	if budget >= size then
		local info = WarehouseRules.level(data.warehouse.level)
		local grade = if rng:NextNumber() < WorkerRules.gradeAChance(entry.worker, info.washLine) then "A" else "B"
		local units = math.min(size, data.inventory.crops[key] or 0)
		if units > 0 and BarnRules.takeCrops(data.inventory, key, units) then
			table.insert(data.warehouse.sorted, { crop = cropId, key = key, units = units, grade = grade })
			budget -= size
		end
	end
	st.budgets[entry.uid] = budget
	return true
end

-- Packers turn washed batches into crates: to the Cold Room or the store.
function JOBS.Packer(player, data, st, entry, speed, _index)
	local batch = data.warehouse.sorted[1]
	if not batch then
		rest(st, entry.uid)
		return false
	end
	local to, commit = destination(st, data, batch.crop)
	if to == "Truck" and holdRoom(data) <= 0 then
		rest(st, entry.uid)
		if not st.told.coldRoomFull then
			st.told.coldRoomFull = true
			Notice.send(player, "The Cold Room is full: packing has paused until a truck takes some.", "Error")
		end
		return false
	end
	st.told.coldRoomFull = nil
	local budget = charge(st, entry.uid, speed, 1)
	if budget >= 1 then
		budget -= 1
		commit()
		local crate = table.remove(data.warehouse.sorted, 1)
		if to == "Store" then
			table.insert(data.store.stockroom, crate)
			StoreService.StockroomChanged(player)
		else
			table.insert(data.warehouse.dock, crate)
			st.holdChanged = true
		end
	end
	st.budgets[entry.uid] = budget
	return true
end

-- Loaders take crates from the Cold Room to the trucks that are home.
function JOBS.Loader(_player, data, st, entry, speed, index)
	local warehouse = data.warehouse
	local t = now()
	local truck = #warehouse.dock > 0 and TruckRules.loadable(warehouse, t)
	if not truck then
		rest(st, entry.uid)
		return false
	end
	local budget = charge(st, entry.uid, speed, 1)
	if budget >= 1 then
		budget -= 1
		local crate = table.remove(warehouse.dock, 1)
		TruckRules.load(warehouse, crate, t)
		st.trucksChanged = true
		st.holdChanged = true
		local folder = PlotService.model(index):FindFirstChild("Warehouse")
		local spot = folder and folder.Docks:FindFirstChild(`LoadSpot{truck}`)
		if spot and st.spots[entry.uid] then
			walk(index, entry.uid, st.spots[entry.uid], spot.Position, crate.crop)
		end
	end
	st.budgets[entry.uid] = budget
	return true
end

-- Drivers send their truck once it's full and the price is right (your
-- rule); they learn while they drive.
function JOBS.Driver(player, data, st, entry, _speed, _index, nth)
	local warehouse = data.warehouse
	local info = WarehouseRules.level(warehouse.level)
	if nth > info.trucks then
		return false
	end
	local t = now()
	if not TruckRules.isHome(warehouse, nth, t) then
		return true -- (on the road)
	end
	local bed = warehouse.beds[nth] or {}
	if #bed < info.truckCrates then
		return false
	end
	local price = MarketService.priceAt()
	local coins, atBase = 0, 0
	for _, crate in bed do
		coins += crate.units * price(crate.crop)
		atBase += crate.units * Crops.ById[crate.crop].value
	end
	if coins >= (warehouse.driverRule or 0) * atBase then
		TruckService.Dispatch(player, nth, "Driver")
		return true
	end
	return false
end

-- Stockers fill the emptiest displays from the stockroom.
function JOBS.Stocker(player, data, st, entry, speed, _index)
	if #data.store.stockroom == 0 or StoreService.IsDecorating(player) then
		rest(st, entry.uid)
		return false
	end
	local budget = charge(st, entry.uid, speed, 1)
	local units = math.floor(budget)
	if units < 1 then
		return true
	end
	local moved = StoreService.Restock(player, units)
	if moved == 0 then
		rest(st, entry.uid)
		return false
	end
	st.budgets[entry.uid] = budget - moved
	return true
end

-- The Greeter works while the store is open.
function JOBS.Greeter(player, data, _st, _entry, _speed, _index)
	return ShopRules.isOpen(data.store) and not StoreService.IsDecorating(player)
end

-- Wages for the minute, or a strike until they can be paid.
local function payWages(player: Player, data)
	local _, wages = WorkerRules.crew(data.workers)
	if wages <= 0 then
		data.crew.strike = false
		return
	end
	local due = math.ceil(wages)
	if data.coins >= due then
		DataService.AddCoins(player, -due, Analytics.GAMEPLAY, "Wages")
		if data.crew.strike then
			data.crew.strike = false
			Notice.send(player, "💰 Wages paid: your crew is back at work.", "Good")
			showCrew(player)
		end
	elseif not data.crew.strike then
		data.crew.strike = true
		Notice.send(player, `🪧 Your crew is on strike: wages are {due} coins a minute and you're short. They'll start again once you can pay.`, "Error")
		showCrew(player)
	end
end

local function tick(player: Player, data, st, index: number, t: number)
	if t >= st.wageAt then
		st.wageAt = t + 60
		payWages(player, data)
	end
	if data.crew.strike then
		return
	end
	local info = WarehouseRules.level(data.warehouse.level)
	local opts = { conveyors = info.conveyors }
	st.ripe = nil
	st.trucksChanged, st.holdChanged = false, false
	local counts = {}
	for _, entry in roster(data) do
		local t_ = entry.worker.type
		counts[t_] = (counts[t_] or 0) + 1
		local job = JOBS[t_]
		if job then
			local busy = job(player, data, st, entry, WorkerRules.speed(entry.worker, opts), index, counts[t_])
			if busy and WorkerRules.addXp(entry.worker, XP_SECOND) then
				Notice.send(player, `⭐ {entry.worker.name} the {Workers.TYPES[t_].name} is ready to train! (Workers window)`, "Good")
				DataService.NotifyState(player)
			end
		end
	end
	if st.holdChanged then
		WarehouseService.showHold(player)
	end
	if st.trucksChanged then
		TruckService.Refresh(player)
	end
	if st.holdChanged or st.trucksChanged then
		DataService.NotifyState(player)
	end
end

------------------------------------------------------------------------
-- Your time away (shared/PipelineRules) and the Welcome back card

local STATIONS = {
	Field = "Farmhand", Shed = "ShedHand", Sort = "Sorter", Pack = "Packer", Load = "Loader",
	Truck = "Driver", Shelves = "Stocker", Register = "Cashier", Door = "Greeter",
}

local function crateOf(crate)
	return { crop = crate.crop, key = `{crate.crop}||`, units = crate.units, grade = crate.grade or "B" }
end

-- Builds the pipeline's state from the save: growth, the plain barn stacks
-- (mutated ones wait for you), the warehouse, trucks, store and crew.
local function pipelineState(player: Player, data)
	local info = WarehouseRules.level(data.warehouse.level)
	local state = PipelineRules.newState()
	local t = now()
	state.tiles = data.field
	state.seeds = data.inventory.seeds
	state.replant = data.crew.replant
	for key, units in data.inventory.crops do
		local cropId, mutation, giant = BarnRules.parse(key)
		if Crops.ById[cropId] and not mutation and not giant then
			state.barn[cropId] = units
		end
	end
	state.barnRoom = math.max(0, BarnRules.capacity(data.silo) - BarnRules.units(data.inventory))
	for _, batch in data.warehouse.sorted do
		state.sorted[batch.crop] = (state.sorted[batch.crop] or 0) + batch.units
	end
	for _, crate in data.warehouse.dock do
		table.insert(state.hold, crateOf(crate))
	end
	state.holdSize = info.hold
	local drivers = ofType(data, "Driver")
	state.trucks = {}
	for i = 1, info.trucks do
		local run = TruckRules.runOf(data.warehouse, i, t)
		local bed = {}
		for _, crate in data.warehouse.beds[i] or {} do
			table.insert(bed, crateOf(crate))
		end
		state.trucks[i] = { crates = info.truckCrates, roundTrip = TruckService.tripFor(player, data, i), backAt = if run then run.returnAt else 0, driver = drivers[i] ~= nil, bed = bed }
	end
	for cropId in Crops.ById do
		local route = WarehouseRules.route(data.warehouse, cropId)
		state.routes[cropId] = if route == nil then "Keep" else route
	end
	local speeds, wages = WorkerRules.crew(data.workers, { conveyors = info.conveyors })
	state.speeds, state.wages = speeds, wages
	local graders = ofType(data, if info.stage == 1 then "ShedHand" else "Sorter")
	local chance = 0
	for _, entry in graders do
		chance += WorkerRules.gradeAChance(entry.worker, info.washLine)
	end
	state.gradeA = if #graders > 0 then chance / #graders else 0
	state.minPrice = data.warehouse.driverRule or 0
	state.premium = info.premium
	local store = data.store
	state.stockroom = ShopRules.stockroomUnits(store)
	state.stockroomRoom = ShopRules.stockroomRoom(store)
	for cropId, out in ShopRules.onDisplay(store) do
		state.shelves[cropId] = out.units
	end
	local selfServe = false
	for _, entry in store.layout do
		local def = Store.ITEMS[entry.item]
		if def and def.kind == "Checkout" and not def.staffed then
			selfServe = true
		end
	end
	state.shop = {
		level = store.level, stars = ShopRules.stars(store), prices = store.prices,
		capacity = ShopRules.displayRoom(store), staffed = not selfServe, boost = StoreService.crew.boost(player),
	}
	state.coins = data.coins
	return state
end

-- Works out the time away and writes it back into the save. Returns the
-- report for the card.
local function settleAway(player: Player, data, away: number)
	local before = { barn = {}, stockroom = ShopRules.stockroomUnits(data.store) }
	local state = pipelineState(player, data)
	for cropId, units in state.barn do
		before.barn[cropId] = units
	end
	local report = PipelineRules.settle(state, away, now() - away)

	-- the barn's plain stacks
	for cropId in before.barn do
		data.inventory.crops[BarnRules.key(cropId)] = nil
	end
	for cropId, units in state.barn do
		if units > 0 then
			data.inventory.crops[BarnRules.key(cropId)] = units
		end
	end
	-- washed batches, crates waiting, the trucks' beds and runs on the road
	local sorted = {}
	for cropId, units in state.sorted do
		local size = CrateRules.size(cropId)
		while units > 0 do
			table.insert(sorted, { crop = cropId, key = BarnRules.key(cropId), units = math.min(size, units), grade = "B" })
			units -= size
		end
	end
	data.warehouse.sorted = sorted
	local dock = {}
	for _, crate in state.hold do
		table.insert(dock, crateOf(crate))
	end
	data.warehouse.dock = dock
	for i, truck in state.trucks do
		local bed = {}
		for _, crate in truck.bed do
			table.insert(bed, crateOf(crate))
		end
		data.warehouse.beds[i] = bed
	end
	for _, run in report.runs do
		local lines = {}
		for _, line in run.crates do
			table.insert(lines, { crop = line.crop, key = BarnRules.key(line.crop), units = line.units, grade = line.grade, price = line.price, coins = line.coins })
		end
		table.insert(data.warehouse.trucks, {
			id = `{math.floor(run.at * 1000)}-{run.truck}`, truck = run.truck, crates = lines, coins = run.coins,
			departAt = run.at, arriveAt = run.arriveAt, returnAt = run.returnAt, paid = false,
		})
	end
	-- the store: new crates in the stockroom, then the Stockers' work and the
	-- sales in rounds (as they went), paid for what really left the displays
	local store = data.store
	for cropId, units in state.stockroom do
		local new = units - (before.stockroom[cropId] or 0)
		if new > 0 then
			local a = math.floor(new * state.gradeA + 0.5)
			if a > 0 then
				ShopRules.restock(store, cropId, a, "A")
			end
			if new - a > 0 then
				ShopRules.restock(store, cropId, new - a, "B")
			end
		end
	end
	local stockLeft, soldLeft, storeCoins, storeUnits = report.stocked, table.clone(report.sold), 0, 0
	local price = MarketService.priceAt()
	for _ = 1, 100 do
		local moved = if stockLeft > 0 then ShopRules.restockDisplays(store, price, stockLeft) else 0
		stockLeft -= moved
		local sold = 0
		for cropId, units in soldLeft do
			local taken, coins = ShopRules.sellOff(store, cropId, units)
			soldLeft[cropId] = units - taken
			sold += taken
			storeUnits += taken
			storeCoins += coins
		end
		if moved == 0 and sold == 0 then
			break
		end
	end
	-- coins: the store's sales in, the wages out (runs that reached the City
	-- are paid by TruckService next)
	if storeCoins > 0 then
		DataService.Earn(player, storeCoins, "StoreSale", false)
	end
	if report.wages > 0 then
		DataService.AddCoins(player, -math.min(report.wages, data.coins), Analytics.GAMEPLAY, "Wages")
	end
	-- the crew learns from the work they did (at the offline rate)
	local ready = {}
	for _, entry in roster(data) do
		for station, typeName in STATIONS do
			if typeName == entry.worker.type and (report.worked[station] or 0) > 0 then
				local wasReady = WorkerRules.ready(entry.worker)
				WorkerRules.addXp(entry.worker, report.worked[station] * Workers.XP_PER_MINUTE * Workers.OFFLINE_RATE)
				if not wasReady and WorkerRules.ready(entry.worker) then
					table.insert(ready, entry.worker.name)
				end
			end
		end
	end
	report.storeUnits, report.storeCoins, report.ready = storeUnits, storeCoins, ready
	return report
end

-- On your return: the time away settled, runs that reached the City paid,
-- and the Welcome back card.
local function welcome(player: Player, data, awayFor: number?)
	local away = awayFor or DataService.AwaySeconds(player)
	local report = nil
	if away > 0 and (data.lastOnline > 0 or awayFor) then
		local ok, result = pcall(settleAway, player, data, away)
		if ok then
			report = result
		else
			warn(`[WorkerService] {player.Name}'s time away: {result}`)
			for _, tile in data.field do -- (at least the crops grow)
				GrowthRules.offline(tile, away)
			end
		end
	end
	local truckCoins = TruckService.SettleAway(player)
	FieldService.Render(player)
	StoreService.Redraw(player)
	WarehouseService.showHold(player)
	TruckService.Refresh(player)
	DataService.NotifyState(player)
	if not report or away < WELCOME_AWAY then
		return
	end
	local onRoad = 0
	for _, run in data.warehouse.trucks do
		if not run.paid then
			onRoad += run.coins
		end
	end
	Notice.send(player, "Welcome back!", "Welcome", {
		away = away,
		minutes = report.minutes,
		harvested = report.harvested,
		crates = report.crates,
		runs = #report.runs,
		truckCoins = truckCoins,
		onRoad = onRoad,
		storeUnits = report.storeUnits,
		storeCoins = report.storeCoins,
		wages = report.wages,
		strikeMinutes = report.strikeMinutes,
		ready = report.ready,
		crew = #roster(data),
	})
	Analytics.event(player, "WelcomeBack", math.floor(away / 60))
end

------------------------------------------------------------------------
-- Actions

local actions = {}

function actions.Hire(player, data, arg)
	local window, typeName, slot = string.match(arg or "", "^(%d+):(%a+):(%d)$")
	window = tonumber(window)
	if not window or not Workers.TYPES[typeName] then
		return "BadRequest"
	end
	if data.level < HIRE_LEVEL and data.freeHireUsed then
		return "NeedLevel2"
	end
	local current = WorkerRules.boardWindow(os.time())
	if window ~= current then
		return "BoardChanged"
	end
	local hired = data.crew.hired
	if hired.window ~= current then
		hired.window = current
		hired.ids = {}
	end
	if hired.ids[arg] then
		return "Hired"
	end
	local ok, why = WorkerRules.canHire(data.workers, typeName, context(data))
	if not ok then
		return why
	end
	local candidate = WorkerRules.candidates(player.UserId, window, typeName)[tonumber(slot) :: number]
	if not candidate then
		return "BadRequest"
	end
	local free = not data.freeHireUsed
	if not free and not DataService.SpendCoins(player, candidate.fee, Analytics.SHOP, `Hire{typeName}`) then
		return "NoCoins"
	end
	data.freeHireUsed = true
	hired.ids[arg] = true
	local uid = tostring(data.crew.nextId)
	data.crew.nextId += 1
	data.workers[uid] = {
		type = typeName, level = candidate.level, xp = 0, trait = candidate.trait, name = candidate.name, look = candidate.look, hiredAt = os.time(),
	}
	Notice.send(player, `👋 {candidate.name} the {Workers.TYPES[typeName].name} starts now!{if free then " (Your first hire is on the house.)" else ""}`, "Good")
	Analytics.step(player, data, "FirstHire")
	showCrew(player)
	DataService.NotifyState(player)
	return nil, { uid = uid }
end

function actions.Train(player, data, uid)
	local worker = data.workers[uid or ""]
	if not worker then
		return "BadRequest"
	end
	local failure = WorkerRules.cannotTrain(worker, data.coins)
	if failure then
		return failure
	end
	local fee = WorkerRules.trainFee(worker) :: number
	if not DataService.SpendCoins(player, fee, Analytics.SHOP, `Train{worker.type}`) then
		return "NoCoins"
	end
	WorkerRules.train(worker)
	Notice.send(player, `🎓 {worker.name} is Level {worker.level}: {math.floor(WorkerRules.efficiency(worker.level) * 100 + 0.5)}% speed.`, "Good")
	Analytics.step(player, data, "FirstTrain")
	showCrew(player)
	DataService.NotifyState(player)
	return nil
end

function actions.Fire(player, data, uid)
	local worker = data.workers[uid or ""]
	if not worker then
		return "BadRequest"
	end
	data.workers[uid] = nil
	local st = crews[player]
	if st then
		st.budgets[uid] = nil
	end
	Notice.send(player, `{worker.name} has left your crew.`)
	showCrew(player)
	DataService.NotifyState(player)
	return nil
end

function actions.Replant(player, data, rule)
	if rule ~= "same" and rule ~= "cheapest" and rule ~= "none" then
		return "BadRequest"
	end
	data.crew.replant = rule
	DataService.NotifyState(player)
	return nil
end

------------------------------------------------------------------------

-- Dev command /hire Type [level]: a worker of that type joins now (free, past the slots).
function WorkerService.DevHire(player: Player, typeName: string, level: number?)
	local data = DataService.Get(player)
	if not data or not Workers.TYPES[typeName] then
		return false
	end
	local uid = tostring(data.crew.nextId)
	data.crew.nextId += 1
	data.workers[uid] = { type = typeName, level = math.clamp(level or 1, 1, Workers.MAX_LEVEL), xp = 0, name = Workers.NAMES[rng:NextInteger(1, #Workers.NAMES)],
		look = rng:NextInteger(1, 8), hiredAt = os.time() }
	showCrew(player)
	DataService.NotifyState(player)
	return true
end

-- Dev command /away N: as if you'd been away N seconds (the settlement and
-- the Welcome back card).
function WorkerService.DevAway(player: Player, seconds: number)
	local data = DataService.Get(player)
	if data then
		welcome(player, data, seconds)
		showCrew(player)
	end
end

-- Dev command /workers N: every worker to Level N, their bars full.
function WorkerService.DevSetLevels(player: Player, level: number)
	local data = DataService.Get(player)
	for _, worker in (data and data.workers) or {} do
		worker.level = math.clamp(math.floor(level), 1, Workers.MAX_LEVEL)
		worker.xp = WorkerRules.xpToNext(worker.level) or 0
	end
	showCrew(player)
	DataService.NotifyState(player)
end

-- Dev command /crew N: a Level N worker in every open slot. Returns how many joined.
function WorkerService.DevCrew(player: Player, level: number): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local joined = 0
	for _, typeName in Workers.ORDER do
		while WorkerRules.canHire(data.workers, typeName, context(data)) do
			WorkerService.DevHire(player, typeName, level)
			joined += 1
		end
	end
	return joined
end

-- Dev command /trainxp: every worker's bar full.
function WorkerService.DevFillXp(player: Player)
	local data = DataService.Get(player)
	for _, worker in (data and data.workers) or {} do
		local need = WorkerRules.xpToNext(worker.level)
		if need then
			worker.xp = need
		end
	end
	DataService.NotifyState(player)
end

function WorkerService.Start()
	ActionRemote(Remotes.func("WorkerAction"), actions, DataService, 0.2)

	-- The store's crew, for StoreService.
	StoreService.crew.cashier = function(player: Player, checkout: string)
		local data = DataService.Get(player)
		if not data or data.crew.strike then
			return nil, nil
		end
		local nth = table.find(registers(data.store), checkout)
		local entry = nth and ofType(data, "Cashier")[nth]
		if not entry then
			return nil, nil
		end
		return entry, 60 / math.max(0.1, WorkerRules.speed(entry.worker))
	end
	StoreService.crew.boost = function(player: Player): number
		local data = DataService.Get(player)
		local entry = data and not data.crew.strike and ofType(data, "Greeter")[1]
		return if entry then WorkerRules.greeterBoost(entry.worker) else 0
	end
	StoreService.crew.served = function(player: Player, entry, seconds: number)
		if WorkerRules.addXp(entry.worker, XP_SECOND * seconds) then
			Notice.send(player, `⭐ {entry.worker.name} the Cashier is ready to train! (Workers window)`, "Good")
			DataService.NotifyState(player)
		end
	end
	-- A Driver makes their truck's trip shorter.
	TruckService.tripFor = function(_player: Player, data, truck: number): number
		local trip = WarehouseRules.level(data.warehouse.level).roundTrip
		local entry = ofType(data, "Driver")[truck]
		return if entry then trip * (1 - WorkerRules.tripShave(entry.worker)) else trip
	end

	-- The Hiring Hall's job board opens the Workers window's Hire tab.
	local board = workspace.World.Town:FindFirstChild("JobBoard")
	if board then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "HirePrompt"
		prompt.ActionText = "Hire workers"
		prompt.ObjectText = "Hiring Hall"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Opens", "HiringHall")
		prompt.Parent = board
	end

	PlotService.OnAssigned(function(player, _index, data)
		crews[player] = { budgets = {}, routeAcc = {}, wageAt = now() + 60, told = {}, spots = {} }
		welcome(player, data)
		showCrew(player)
	end)
	PlotService.OnReleased(function(player, index)
		crews[player] = nil
		WorkerEvent:FireAllClients("Clear", { plot = index })
	end)
	WarehouseService.OnRebuilt(function(player)
		showCrew(player)
	end)
	DataService.OnWiped(function(player)
		local st = crews[player]
		if st then
			table.clear(st.budgets)
		end
		showCrew(player)
	end)
	-- Players who join see every farm's crew.
	Players.PlayerAdded:Connect(function(newcomer)
		newcomer.CharacterAdded:Wait()
		for player in PlotService.owners() do
			if player ~= newcomer then
				showCrew(player, newcomer)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			local t = now()
			for player, index in PlotService.owners() do
				local data = DataService.Get(player)
				local st = crews[player]
				if data and st and next(data.workers) then
					local ok, err = pcall(tick, player, data, st, index, t)
					if not ok then
						warn(`[WorkerService] {player.Name}'s crew: {err}`)
					end
				end
			end
		end
	end)
end

return WorkerService
