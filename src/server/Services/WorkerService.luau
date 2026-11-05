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
local Format = require(Shared.Format)
local GrowthRules = require(Shared.GrowthRules)
local LandRules = require(Shared.LandRules)
local PackRules = require(Shared.PackRules)
local PipelineRules = require(Shared.PipelineRules)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local ShopRules = require(Shared.ShopRules)
local Store = require(Shared.Config.Store)
local StoreLayout = require(Shared.StoreLayout)
local TruckRules = require(Shared.TruckRules)
local WarehouseRules = require(Shared.WarehouseRules)
local WeatherRules = require(Shared.WeatherRules)
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
local GuideService = require(script.Parent.GuideService)

local WorkerService = {}

local TICK = 1
local XP_SECOND = Workers.XP_PER_MINUTE / 60
local HIRE_LEVEL = 2 -- Farm Level to hire (§4.9)
local WELCOME_AWAY = 120 -- seconds away before the Welcome back card
local SORTED_MAX = 12 -- batches Sorters wash ahead of the Packers
local PAUSE = 0.6 -- seconds at the far end of a walk out and back (client/WorkerController's)
local PULL = 0.3 -- seconds a Farmhand bends over a crop before it comes up
local STOCK_ROUND = 8 -- patches' worth a Stocker can take out in one go
local HOME_AFTER = 4 -- seconds with nothing to do before a Farmhand walks back to their post

local WorkerEvent = Remotes.event("WorkerEvent")
local rng = Random.new()

-- [Player] = { budgets = { [uid] = n }, routeAcc = {}, wageAt, told = {}, spots = { [uid] = their post },
--   at = { [uid] = where they went last }, trips = { [uid] = the tile they're on their way to },
--   worked = { [uid] = { at, crop }: their last harvest }, loading = { [truck] = crates being carried to it } }
local crews = {}

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

-- The tills (Shop Counters and Registers) in the layout, in id order: the
-- first Cashier works the first.
local function registers(store): { string }
	local ids = {}
	for id, entry in store.layout do
		local def = Store.ITEMS[entry.item]
		if def and def.staffed then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	return ids
end

-- What WorkerRules.slots needs about a farm.
local context = WorkerRules.context
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
	local offsets = { 0, -3.4, 3.4, -6.8, 6.8 } -- (closer, their arms go through each other)
	local t = worker.type
	if t == "Farmhand" then
		return at(Vector3.new(-14 + nth * 6, 0.2, PlotLayout.PLOT.field.depth - 3), Vector3.new(0, 0, 1))
	elseif t == "ShedHand" then
		return at(layout.bench + Vector3.new(-2.5 + (nth - 1) * 5, floor, -3), Vector3.new(0, 0, 1))
	elseif (t == "Sorter" or t == "Packer" or t == "Loader") and layout.stations then
		local station = layout.stations[if t == "Sorter" then "Sort" elseif t == "Packer" then "Pack" else "Load"]
		local spread = if t == "Loader" then { 0, -3.4, -6.8 } else offsets -- (Loaders: not onto the pallets behind them)
		return at(station + Vector3.new(0, floor, spread[(nth - 1) % #spread + 1]), Vector3.new(1, 0, 0))
	elseif t == "Driver" then
		local across = layout.docks[math.min(nth, #layout.docks)]
		local length = YardArt.TRUCK_LENGTH[info.truck]
		return at(PlotLayout.truckParked(across, length) + Vector3.new(-6, 0.2, -length / 2 + 6), Vector3.new(1, 0, 0))
	elseif t == "Stocker" then -- (by the staff door, clear of the Cashier and the shoppers: StoreLayout.stockerSpot)
		local cx, cy = StoreLayout.stockerSpot(data.store.layout, data.store.level, nth)
		return at(PlotLayout.storeLocal(cx, cy, PlotLayout.PLOT.store.floor), Vector3.new(-1, 0, 0))
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
	elseif t == "Watchman" then
		-- in his gatehouse, at the window over the gate (World/DefenceArt)
		local g = PlotLayout.PLOT.gatehouse
		return at(Vector3.new(g.min.X + 2.4, 0.5, (g.min.Z + g.max.Z) / 2 - 1), Vector3.new(-1, 0, 0))
	end
	return at(PlotLayout.PLOT.door, Vector3.new(0, 0, 1))
end

-- The way along the store's aisles between two points, for a Stocker: the
-- corners to go by, or nil to go straight.
local function aisle(index: number, data, from: Vector3, to: Vector3): { Vector3 }?
	local store = data.store
	local ax, ay = PlotLayout.storeCellAt(index, from)
	local bx, by = PlotLayout.storeCellAt(index, to)
	local cells = StoreLayout.path(store.layout, store.level, { math.round(ax), math.round(ay) }, { math.round(bx), math.round(by) })
	if not cells then
		return nil
	end
	local points = StoreLayout.smooth(store.layout, store.level, cells)
	local via = {}
	for i = 2, #points - 1 do
		table.insert(via, PlotLayout.storeWorld(index, points[i][1], points[i][2], PlotLayout.PLOT.store.floor))
	end
	return via
end

-- The corners a worker goes by to get out of their building, for the walk
-- to the picket line: through a door, never a wall.
local function wayOut(index: number, data, entry, from: Vector3): { Vector3 }
	local t = entry.worker.type
	local frame = PlotLayout.frame(index)
	local here = frame:PointToObjectSpace(from)
	local function at(x: number, y: number, z: number): Vector3
		return frame:PointToWorldSpace(Vector3.new(x, y, z))
	end
	local P = PlotLayout.PLOT
	if t == "Sorter" or t == "Packer" or t == "Loader" then -- (by the staff door, on the gate side)
		local layout = PlotLayout.WAREHOUSES[WarehouseRules.level(data.warehouse.level).stage]
		local doorZ = layout.min.Z + 10
		return { at(layout.min.X + 3, here.Y, doorZ), at(layout.min.X - 4, 0.2, doorZ) }
	elseif t == "ShedHand" then -- (the shed's open at the side)
		return { at(10, 0.2, 62) }
	elseif t == "Driver" then -- (along the dock, behind the trucks)
		return { at(here.X, P.dock.height, P.dock.z + 3.5), at(10, 0.2, P.dock.z + 3.5) }
	elseif t == "Watchman" then -- (his door, on the yard side)
		local g = P.gatehouse
		return { at(g.min.X + 5.4, here.Y, g.max.Z - 2), at(g.min.X + 5.4, 0.2, g.max.Z + 2) }
	elseif t == "Stocker" or t == "Cashier" or t == "Greeter" then -- (by the staff door)
		local cx, cy = StoreLayout.staffCell()
		local door = PlotLayout.storeWorld(index, cx, cy, P.store.floor)
		local outside = at(P.store.right + 5, 0.2, PlotLayout.storeLocal(cx, cy).Z)
		if t == "Cashier" then
			return { door, outside } -- (they work in the doorway)
		end
		local _, y = PlotLayout.storeCellAt(index, from)
		local beside = PlotLayout.storeWorld(index, cx, if y < cy then cy - 1 else cy + 1, P.store.floor)
		local via = aisle(index, data, from, beside) or {}
		table.insert(via, beside)
		table.insert(via, door)
		table.insert(via, outside)
		return via
	end
	return {}
end

-- Tells the clients (every one, or just `to`) where this farm's crew
-- stands (after a hire, a level, a strike, a new building ...). On strike
-- that's the picket line by your door; the moment one starts or ends they
-- get the way there too.
local function showCrew(player: Player, to: Player?)
	local index = PlotService.plotOf(player)
	local data = DataService.Get(player)
	if not index or not data then
		return
	end
	local st = crews[player]
	local striking = data.crew.strike == true
	local turned = st ~= nil and st.striking ~= nil and st.striking ~= striking
	local wasAt = st and st.at or {}
	if st then
		st.striking = striking
		if turned then
			st.at, st.worked = {}, {} -- (they walk from wherever they were)
		end
	end
	local list, counts = {}, {}
	for _, entry in roster(data) do
		local t = entry.worker.type
		counts[t] = (counts[t] or 0) + 1
		local position, face = spotOf(index, data, entry, counts[t])
		local via = nil
		if turned then
			via = wayOut(index, data, entry, if striking then wasAt[entry.uid] or position else position)
			if not striking then -- (back the way they came)
				local out = via
				via = {}
				for i = #out, 1, -1 do
					table.insert(via, out[i])
				end
			end
		end
		if striking then
			position = PlotLayout.toWorld(index, PlotLayout.picketLocal(#list + 1))
			face = PlotLayout.frame(index):VectorToWorldSpace(Vector3.new(0, 0, -1))
		end
		if st then
			st.spots[entry.uid] = position
		end
		table.insert(list, {
			id = entry.uid, type = t, name = entry.worker.name, level = entry.worker.level, look = entry.worker.look or 1,
			at = position, face = face, strike = striking, nth = counts[t], via = via,
		})
	end
	if to then
		WorkerEvent:FireClient(to, "Crew", { plot = index, workers = list })
	else
		WorkerEvent:FireAllClients("Crew", { plot = index, workers = list })
	end
end
WorkerService.ShowCrew = showCrew

-- How long a walk takes, by way of the points in `via`, at `pace` (default
-- a worker's walk), and no longer than `most` seconds (WorkerRules.walkTime).
local function walkTime(from: Vector3, via: { Vector3 }?, to: Vector3, most: number?, pace: number?): number
	local length, last = 0, from
	for _, point in via or {} do
		length += (point - last).Magnitude
		last = point
	end
	length += (to - last).Magnitude
	return WorkerRules.walkTime(length, pace, most)
end

-- A worker walks to a world point and back (a crate to a truck), by way of
-- `via`, carrying `carry` there or, with `back`, on the way back. Returns how
-- long the way there takes.
local function walk(index: number, uid: string, from: Vector3, to: Vector3, carry: string?, back: boolean?, most: number?, via: { Vector3 }?): number
	local seconds = walkTime(from, via, to, most)
	WorkerEvent:FireAllClients("Do", { plot = index, id = uid, at = now(), to = to, via = via, seconds = seconds, carry = carry, back = back })
	return seconds
end

-- A worker walks one way and stays there (a Farmhand from crop to crop, a
-- Stocker from display to display), and home with `home`. Returns how long
-- it takes.
local function goTo(index: number, st, uid: string, to: Vector3, carry: string?, home: boolean?, most: number?, via: { Vector3 }?, pace: number?): number
	local seconds = walkTime(st.at[uid] or st.spots[uid] or to, via, to, most, pace)
	st.at[uid] = to
	WorkerEvent:FireAllClients("Do", { plot = index, id = uid, at = now(), to = to, via = via, seconds = seconds, carry = carry, stay = true, home = home })
	return seconds
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

-- Which way the next crate of a crop leans by its route, "Truck" or "Store"
-- (a split's shares kept exact over many crates), and the route's count to
-- keep once it's packed (commit). It says what the crew does with the crate,
-- not where it can go: it joins the stock either way (shared/PackRules).
local function leanOf(st, data, cropId: string): (string, () -> ())
	local share = WarehouseRules.route(data.warehouse, cropId) or 1
	local acc = (st.routeAcc[cropId] or 0) + share
	local lean = "Store"
	if acc >= 1 - 1e-9 then
		acc -= 1
		lean = "Truck"
	end
	return lean, function()
		st.routeAcc[cropId] = acc
	end
end

-- A plain barn stack the crew may take (routed, not kept; mutated ones wait
-- for you at the wash table) with a full crate's worth in it, or nil. takes:
-- only crops it says yes to.
local function nextStack(data, takes: ((string) -> boolean)?): (string?, string?)
	local keys = {}
	for key, units in data.inventory.crops do
		local cropId = BarnRules.parse(key)
		if Crops.ById[cropId] and CrateRules.storeable(key) and WarehouseRules.route(data.warehouse, cropId)
			and units >= CrateRules.size(cropId) and (not takes or takes(cropId)) then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	local key = keys[1]
	return key, key and BarnRules.parse(key)
end

-- The packed crates are full, so the crew has stopped packing (the user,
-- 2026-11-05: "wait for space ... and not just pack for the truck"). Said once.
local function tellFull(player: Player, st)
	if not st.told.packedFull then
		st.told.packedFull = true
		Notice.send(player, "📦 Your packed crates are full, so your crew has stopped packing. Load a truck or fill your displays to make room.", "Error")
	end
end

local JOBS = {}

-- A Farmhand has reached their crop: it comes up now, not when they set off.
local function reachCrop(player: Player, st, uid: string, key: string)
	st.trips[uid] = nil
	local data = DataService.Get(player)
	if crews[player] ~= st or not data or data.crew.strike or not data.workers[uid] then
		return
	end
	local cropId = data.field[key] and data.field[key].crop
	local failure, note = FieldService.WorkerHarvest(player, data, key, data.crew.replant)
	if failure ~= nil then
		st.budgets[uid] = (st.budgets[uid] or 0) + 1 -- (someone got there first: that wasn't a job done)
		return
	end
	st.worked[uid] = { at = now(), crop = cropId }
	if note == "NoSeeds" and cropId and not st.told[`seeds{cropId}`] then
		st.told[`seeds{cropId}`] = true
		Notice.send(player, `🌱 Out of {Crops.ById[cropId].name} seeds: your Farmhands harvest but can't replant. Barley sells more in town.`, "Error")
	end
end

-- Nothing to do for a while: back to their post, with the last crop;
-- route(from, to) gives the way if they can't walk straight there.
local function headHome(index: number, st, uid: string, route: ((Vector3, Vector3) -> { Vector3 }?)?, pace: number?)
	local spot, last = st.spots[uid], st.worked[uid]
	if spot and last and now() - last.at >= HOME_AFTER then
		st.worked[uid] = nil
		goTo(index, st, uid, spot, last.crop, true, nil, route and route(st.at[uid] or spot, spot), pace)
	end
end

-- Carries a crate to a truck and back, out through the dock door, quick
-- enough to be back for the next one. The crate shows on the truck as they
-- reach it.
local function carryToTruck(player: Player, data, st, uid: string, speed: number, index: number, truck: number, crop: string)
	local folder = PlotService.model(index):FindFirstChild("Warehouse")
	local spot = folder and folder.Docks:FindFirstChild(`LoadSpot{truck}`)
	local from = st.spots[uid]
	if not spot or not from then
		st.trucksChanged = true
		return
	end
	local layout = PlotLayout.WAREHOUSES[WarehouseRules.level(data.warehouse.level).stage]
	-- (the warehouses: to the middle of the dock's door; the Packing Shed is open
	-- at the front, with a post in the middle of it to go round)
	local door = PlotLayout.toWorld(index, Vector3.new(layout.docks[truck] - (if layout.stations then 0 else 4), 0, layout.min.Z + 2))
	local to = spot.Position - Vector3.new(0, spot.Size.Y / 2, 0) -- (on the dock)
	local seconds = walk(index, uid, from, to, crop, false, (60 / speed - PAUSE) / 2, { Vector3.new(door.X, from.Y, door.Z) })
	st.loading[truck] = (st.loading[truck] or 0) + 1
	task.delay(seconds, function()
		st.loading[truck] -= 1
		if crews[player] == st then
			TruckService.Refresh(player)
		end
	end)
end

-- A Farmhand walks at their own pace, quicker with each level
-- (WorkerRules.walkSpeed): they used to hurry to keep up with their speed, and
-- outran a thief to the crop (the user, 2026-11-05). A long way to the next
-- crop takes as long as it takes.
function JOBS.Farmhand(player, data, st, entry, speed, index)
	local uid = entry.uid
	local pace = WorkerRules.walkSpeed(entry.worker)
	if st.trips[uid] then
		charge(st, uid, speed, 1)
		return true
	end
	if not st.ripe then
		st.ripe = FieldService.RipeTiles(player, data)
		for _, key in st.trips do -- (not the ones a Farmhand's already on the way to)
			local at = table.find(st.ripe, key)
			if at then
				table.remove(st.ripe, at)
			end
		end
	end
	if #st.ripe == 0 then
		rest(st, uid)
		headHome(index, st, uid, nil, pace)
		return false
	end
	if not BarnRules.hasRoom(data, 1) then
		rest(st, uid)
		headHome(index, st, uid, nil, pace)
		if not st.told.barnFull then
			st.told.barnFull = true
			Notice.send(player, "Barn full: your Farmhands are waiting. Sell or pack some crops.", "Error")
		end
		return false
	end
	st.told.barnFull = nil
	local budget = charge(st, uid, speed, 1)
	if budget < 1 then
		return true -- (still busy over the last crop)
	end
	local function tile(key: string): Vector3
		return PlotLayout.tileWorld(index, tonumber(key) :: number)
	end
	local from = st.at[uid] or st.spots[uid] or tile(st.ripe[1])
	local key = table.remove(st.ripe, WorkerRules.nearest(st.ripe, function(k)
		return (tile(k) - from).Magnitude
	end))
	st.budgets[uid] = budget - 1
	st.trips[uid] = key
	task.delay(goTo(index, st, uid, tile(key), nil, nil, nil, nil, pace) + PULL, reachCrop, player, st, uid, key)
	return true
end

-- The Shed Hand: loads the pickup when it's home with the crates routed to
-- it, and packs full crates from the barn into the stock. A crate for the
-- truck goes straight on when there's room on it, stock full or not; anything
-- else waits for space.
function JOBS.ShedHand(player, data, st, entry, speed, index)
	local warehouse = data.warehouse
	local t = now()
	local truckHome = TruckRules.cannotLoad(warehouse, t) == nil
	local ready = if truckHome then PackRules.nextForTruck(data) else nil
	local room = PackRules.room(data) > 0
	local key, cropId = nextStack(data, function(id: string): boolean
		return room or (truckHome and WarehouseRules.route(warehouse, id) == 1)
	end)
	if room then
		st.told.packedFull = nil
	elseif not key and nextStack(data) then
		tellFull(player, st)
	end
	if not ready and not key then
		rest(st, entry.uid)
		return false
	end
	local budget = charge(st, entry.uid, speed, 1)
	local changed, carried = false, nil
	if budget >= 1 and ready then
		budget -= 1
		local crate = table.remove(data.store.stockroom, ready)
		TruckRules.load(warehouse, crate, t)
		changed, carried = true, crate.crop
	end
	if budget >= 1 and key and cropId then
		local lean, commit = leanOf(st, data, cropId)
		local straight = lean == "Truck" and TruckRules.cannotLoad(warehouse, t) == nil
		if straight or PackRules.room(data) > 0 then
			commit()
			budget -= 1
			local grade = if rng:NextNumber() < WorkerRules.gradeAChance(entry.worker) then "A" else "B"
			local crate = CrateRules.pack(data.inventory, key, grade)
			if crate then
				crate.lean = lean
				if straight then
					TruckRules.load(warehouse, crate, t)
					carried = crate.crop
				else
					table.insert(data.store.stockroom, crate)
				end
				changed = true
			end
		end
	end
	st.budgets[entry.uid] = budget
	if changed then
		st.holdChanged = true
	end
	if carried then
		carryToTruck(player, data, st, entry.uid, speed, index, 1, carried)
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
	local work = CrateRules.patches(cropId, size) -- (a Sorter's speed is in patches' worth)
	local budget = charge(st, entry.uid, speed, work)
	if budget >= work - 1e-9 then
		local info = WarehouseRules.level(data.warehouse.level)
		local grade = if rng:NextNumber() < WorkerRules.gradeAChance(entry.worker, info.washLine) then "A" else "B"
		local units = math.min(size, data.inventory.crops[key] or 0)
		if units > 0 and BarnRules.takeCrops(data.inventory, key, units) then
			table.insert(data.warehouse.sorted, { crop = cropId, key = key, units = units, grade = grade })
			budget -= work
		end
	end
	st.budgets[entry.uid] = budget
	return true
end

-- Packers turn washed batches into crates, while there's room for them.
function JOBS.Packer(player, data, st, entry, speed, _index)
	local batch = data.warehouse.sorted[1]
	if not batch then
		rest(st, entry.uid)
		return false
	end
	if PackRules.room(data) <= 0 then
		rest(st, entry.uid)
		tellFull(player, st)
		return false
	end
	st.told.packedFull = nil
	local budget = charge(st, entry.uid, speed, 1)
	if budget >= 1 then
		budget -= 1
		local lean, commit = leanOf(st, data, batch.crop)
		commit()
		local crate = table.remove(data.warehouse.sorted, 1)
		crate.lean = lean
		table.insert(data.store.stockroom, crate)
		st.holdChanged = true
	end
	st.budgets[entry.uid] = budget
	return true
end

-- Loaders take the crates routed to the trucks to the ones that are home.
function JOBS.Loader(player, data, st, entry, speed, index)
	local warehouse = data.warehouse
	local t = now()
	local truck = TruckRules.loadable(warehouse, t)
	local ready = truck and PackRules.nextForTruck(data)
	if not ready then
		rest(st, entry.uid)
		return false
	end
	local budget = charge(st, entry.uid, speed, 1)
	if budget >= 1 then
		budget -= 1
		local crate = table.remove(data.store.stockroom, ready)
		TruckRules.load(warehouse, crate, t)
		st.holdChanged = true
		carryToTruck(player, data, st, entry.uid, speed, index, truck, crate.crop)
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
	if #bed < info.truckCrates or (st.loading[nth] or 0) > 0 then -- (not with the last crate still on its way to it)
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

-- A Stocker has reached the display: what they brought goes on it.
local function reachDisplay(player: Player, st, uid: string)
	st.trips[uid] = nil
	if crews[player] ~= st then
		return
	end
	local moved = StoreService.Restock(player, math.floor(st.budgets[uid] or 0)) -- (patches' worth)
	st.budgets[uid] = (st.budgets[uid] or 0) - moved
	if moved > 0 then
		st.worked[uid] = { at = now() }
	end
end

-- Stockers take the crates routed to the store to the emptiest displays,
-- along the aisles, and go back to their spot when there's nothing left to do.
function JOBS.Stocker(player, data, st, entry, speed, index, nth)
	local uid = entry.uid
	if st.trips[uid] then
		charge(st, uid, speed, STOCK_ROUND)
		return true
	end
	local function route(from: Vector3, to: Vector3): { Vector3 }?
		return aisle(index, data, from, to)
	end
	local first = PackRules.nextForStore(data)
	if not first or StoreService.IsDecorating(player) then
		rest(st, uid)
		headHome(index, st, uid, route)
		return false
	end
	local budget = charge(st, uid, speed, STOCK_ROUND)
	if budget < 1 then
		return true
	end
	local taken = {}
	for _, id in st.trips do
		taken[id] = true
	end
	local id = ShopRules.nextDisplay(data.store, taken, PackRules.forStore(data.warehouse))
	if not id then
		rest(st, uid)
		headHome(index, st, uid, route)
		return false
	end
	local fronts = StoreLayout.fronts(data.store.layout[id])
	local front = fronts[(nth - 1) % #fronts + 1] -- (not on top of each other)
	local to = PlotLayout.storeWorld(index, front[1], front[2], PlotLayout.PLOT.store.floor)
	local via = route(st.at[uid] or st.spots[uid] or to, to)
	st.trips[uid] = id
	task.delay(goTo(index, st, uid, to, data.store.stockroom[first].crop, nil, nil, via) + PULL, reachDisplay, player, st, uid)
	return true
end

-- The Greeter works while the store is open.
function JOBS.Greeter(player, data, _st, _entry, _speed, _index)
	return ShopRules.isOpen(data.store) and not StoreService.IsDecorating(player)
end

-- The Watchman is on watch (and learns) while your farm is here: thieves
-- can only come while you're in the server (DefenceService does his work).
function JOBS.Watchman(_player, _data, _st, _entry, _speed, _index)
	return true
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
		Notice.send(player, `🪧 Your crew is on strike: wages are {Format.number(due)} coins a minute and you're short. They'll start again once you can pay.`, "Error")
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
	local opts = { conveyors = info.conveyors, night = WeatherRules.isNight(WeatherRules.now(t)) } -- (Night Owls: +30%)
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
	return { crop = crate.crop, key = crate.key or `{crate.crop}||`, units = crate.units, grade = crate.grade or "B", lean = crate.lean }
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
	state.fieldYield = LandRules.fieldYield(data.land)
	for key, units in data.inventory.crops do
		local cropId, mutation, giant = BarnRules.parse(key)
		if Crops.ById[cropId] and not mutation and not giant then
			state.barn[cropId] = units
		end
	end
	state.barnRoom = math.max(0, BarnRules.capacityOf(data) - BarnRules.units(data.inventory))
	for _, batch in data.warehouse.sorted do
		state.sorted[batch.crop] = (state.sorted[batch.crop] or 0) + batch.units
	end
	-- the packed crates, by what the crew will do with them
	for _, crate in data.store.stockroom do
		local use = PackRules.crewUse(data.warehouse, crate)
		if use == "Truck" then
			table.insert(state.hold, crateOf(crate))
		elseif use == "Store" then
			state.stockroom[crate.crop] = (state.stockroom[crate.crop] or 0) + crate.units
		end
	end
	state.packedRoom = PackRules.room(data)
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
	local speeds, wages = WorkerRules.crew(data.workers, { conveyors = info.conveyors, away = true })
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
	local state = pipelineState(player, data)
	local before = { barn = {} }
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
	-- washed batches, the trucks' beds and runs on the road
	local sorted = {}
	for cropId, units in state.sorted do
		local size = CrateRules.size(cropId)
		while units > 0 do
			table.insert(sorted, { crop = cropId, key = BarnRules.key(cropId), units = math.min(size, units), grade = "B" })
			units -= size
		end
	end
	data.warehouse.sorted = sorted
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
			table.insert(lines, { crop = line.crop, key = line.key or BarnRules.key(line.crop), units = line.units, grade = line.grade, price = line.price, coins = line.coins })
		end
		table.insert(data.warehouse.trucks, {
			id = `{math.floor(run.at * 1000)}-{run.truck}`, truck = run.truck, crates = lines, coins = run.coins,
			departAt = run.at, arriveAt = run.arriveAt, returnAt = run.returnAt, paid = false,
		})
	end
	-- the packed crates: those the crew was to load are where they ended up,
	-- the ones still waiting go back with the rest, and new crates for the
	-- store join them. Then the Stockers' work and the sales in rounds (as
	-- they went), paid for what really left the displays
	local store = data.store
	local stock = {}
	for _, crate in store.stockroom do
		if PackRules.crewUse(data.warehouse, crate) ~= "Truck" then
			table.insert(stock, crate)
		end
	end
	for _, crate in state.hold do
		table.insert(stock, crateOf(crate))
	end
	store.stockroom = stock
	-- (what was packed for the store, not what's left of it: what the Stockers
	-- took comes off once, below, when it really goes out. Working it out from
	-- what was left took it off twice, and those crops were gone: 240 of them
	-- in Studio, 2026-11-05)
	for cropId, new in report.forStore do
		local a = math.floor(new * state.gradeA + 0.5)
		if a > 0 then
			ShopRules.restock(store, cropId, a, "A", "Store")
		end
		if new - a > 0 then
			ShopRules.restock(store, cropId, new - a, "B", "Store")
		end
	end
	local stockLeft, soldLeft, storeCoins, storeUnits = report.stockedPatches, table.clone(report.sold), 0, 0
	local price = MarketService.priceAt()
	for _ = 1, 100 do
		local moved = if stockLeft > 0 then ShopRules.restockDisplays(store, price, stockLeft, PackRules.forStore(data.warehouse)) else 0
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
	local key = WorkerRules.hireKey(window, typeName, tonumber(slot) :: number)
	if hired.ids[key] then
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
	hired.ids[key] = true
	local uid = tostring(data.crew.nextId)
	data.crew.nextId += 1
	data.workers[uid] = {
		type = typeName, level = candidate.level, xp = 0, trait = candidate.trait, name = candidate.name, look = candidate.look, hiredAt = os.time(),
	}
	Notice.send(player, `👋 {candidate.name} the {Workers.TYPES[typeName].name} starts now!{if free then " (No fee on your first hire: you just pay their wage.)" else ""}`, "Good")
	Analytics.step(player, data, "FirstHire")
	GuideService.Record(player, "Hire")
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
	Analytics.event(player, "WorkerTrained", worker.level)
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
-- A rare worker won at the Auction House (AuctionService) joins the crew:
-- `worker` from WorkerRules.fromContract.
function WorkerService.AddWorker(player: Player, worker)
	local data = DataService.Get(player)
	if not data or not Workers.TYPES[worker.type] then
		return false
	end
	local uid = tostring(data.crew.nextId)
	data.crew.nextId += 1
	worker.hiredAt = os.time()
	data.workers[uid] = worker
	showCrew(player)
	DataService.NotifyState(player)
	return true
end

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
	StoreService.crew.moved = function(player: Player)
		showCrew(player)
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
		crews[player] = { budgets = {}, routeAcc = {}, wageAt = now() + 60, told = {}, spots = {}, at = {}, trips = {}, worked = {}, loading = {} }
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
