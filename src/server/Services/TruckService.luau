-- The trucks (docs/GameDesign.md §4.6, shared/TruckRules): loading crates at
-- each dock, dispatching (the dock's lever, or the Market window's Send now
-- from anywhere: every truck that's home and loaded), the receipt with the
-- prices it locked, and the payout when it reaches the City. Runs are
-- saved, so one that arrives after you've left is paid when you next join,
-- on any server. A truck with a Driver (WorkerService) makes a shorter trip.
--
-- Each truck model's attributes DepartAt / ArriveAt / ReturnAt (0 = home)
-- are all the clients need to drive it there and back (TruckController).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Crops = require(Shared.Config.Crops)
local Remotes = require(Shared.Remotes)
local TruckRules = require(Shared.TruckRules)
local Warehouse = require(Shared.Config.Warehouse)
local WarehouseRules = require(Shared.WarehouseRules)

local Server = ServerScriptService.Server
local ActionRemote = require(Server.Util.ActionRemote)
local Analytics = require(Server.Util.Analytics)
local Notice = require(Server.Util.Notice)
local YardArt = require(Server.World.YardArt)
local DataService = require(script.Parent.DataService)
local MarketService = require(script.Parent.MarketService)
local MovementService = require(script.Parent.MovementService)
local PlotService = require(script.Parent.PlotService)
local WarehouseService = require(script.Parent.WarehouseService)

local TruckService = {}

TruckService.DOCK_REACH = 12 -- studs from the dock's edge you can load from
local TICK = 0.5

-- tripFor(player, data, truck) → seconds: the round trip (WorkerService sets
-- it: a Driver makes it shorter). Default: the level's.
TruckService.tripFor = function(_player: Player, data, _truck: number): number
	return WarehouseRules.level(data.warehouse.level).roundTrip
end

local ready = {} -- [Player] = true once their time away is settled (WorkerService): live payouts start then

local function now(): number
	return workspace:GetServerTimeNow()
end

local function truckName(data): string
	return Warehouse.TRUCK_NAMES[WarehouseRules.level(data.warehouse.level).truck]
end

local function truckModel(index: number, truck: number): Model?
	local warehouse = PlotService.model(index):FindFirstChild("Warehouse")
	return warehouse and warehouse.Trucks:FindFirstChild(`Truck{truck}`) :: Model?
end

local function docks(index: number): Instance?
	local warehouse = PlotService.model(index):FindFirstChild("Warehouse")
	return warehouse and warehouse:FindFirstChild("Docks")
end

-- Shows each truck's state on its model and the docks' prompts.
function TruckService.Refresh(player: Player)
	local index = PlotService.plotOf(player)
	local data = DataService.Get(player)
	if not index or not data then
		return
	end
	local warehouse = data.warehouse
	local t = now()
	local info = WarehouseRules.level(warehouse.level)
	local name = truckName(data)
	for truck = 1, info.trucks do
		local model = truckModel(index, truck)
		if model then
			local run = TruckRules.runOf(warehouse, truck, t)
			model:SetAttribute("DepartAt", if run then run.departAt else 0)
			model:SetAttribute("ArriveAt", if run then run.arriveAt else 0)
			model:SetAttribute("ReturnAt", if run then run.returnAt else 0)
			if not run or t >= run.arriveAt then -- (the crates ride along until they're sold in the City)
				YardArt.showBed(model, warehouse.beds[truck] or {})
			end
			local bed = #(warehouse.beds[truck] or {})
			local folder = docks(index)
			local load = folder and folder:FindFirstChild(`LoadSpot{truck}`)
			local prompt = load and load:FindFirstChild("LoadPrompt")
			if prompt then
				prompt.ObjectText = if run then `{name}: on the road` else `{name} {bed}/{info.truckCrates}`
			end
			local leverBase = folder and folder:FindFirstChild(`LeverBase{truck}`)
			local lever = leverBase and leverBase:FindFirstChild("LeverPrompt")
			if lever then
				lever.ObjectText = if run then `{name}: on the road` else `{bed} crate{if bed == 1 then "" else "s"} · locks today's prices`
			end
		end
	end
end

------------------------------------------------------------------------
-- Loading and dispatching

-- "Load crate" at dock `truck`: the crate in your arms or one from the rack
-- at the Packing Shed; at the warehouses, a hand cart's worth from the Cold Room.
local function load(player: Player, truck: number)
	local index = PlotService.plotOf(player)
	local data = DataService.Get(player)
	if not index or not data then
		return
	end
	local folder = docks(index)
	local spot = folder and folder:FindFirstChild(`LoadSpot{truck}`)
	local position = MovementService.positionOf(player)
	if not spot or not position or (position - spot.Position).Magnitude > TruckService.DOCK_REACH then
		return
	end
	local warehouse = data.warehouse
	local info = WarehouseRules.level(warehouse.level)
	local name = truckName(data)
	local carried = WarehouseService.carried(player)
	if not carried and #warehouse.dock == 0 then
		Notice.send(player, if info.stage == 1 then "Pack a crate at the bench first (Truck), then bring it here."
			else "The Cold Room is empty: wash and pack crates at the wash table (Truck), or let your crew do it.", "Error")
		return
	end
	local failure = TruckRules.cannotLoadInto(warehouse, truck, now())
	if failure then
		Notice.send(player, if failure == "TruckFull" then `The {name} is full. Pull the lever to send it!`
			else `The {name} is out on the road. {if carried then "Set the crate down and load it" else "Load it"} when it's back.`, "Error")
		return
	end
	local count = if carried then 1 elseif info.handCart then Warehouse.HAND_CART else 1
	local moved = 0
	while moved < count and TruckRules.cannotLoadInto(warehouse, truck, now()) == nil do
		local crate = if moved == 0 and carried then WarehouseService.takeCarried(player) else table.remove(warehouse.dock, 1)
		if not crate then
			break
		end
		TruckRules.loadInto(warehouse, truck, crate, now())
		moved += 1
		carried = nil
	end
	if moved > 1 then
		Notice.send(player, `🛒 {moved} crates loaded with the hand cart.`)
	end
	WarehouseService.showHold(player)
	TruckService.Refresh(player)
	DataService.NotifyState(player)
end

-- Sends truck `truck` (nil: every truck that's home and loaded): the prices
-- lock now, and a receipt shows them. by: who sent it ("Driver" for the
-- crew's, quietly). Returns nil, or why none left.
function TruckService.Dispatch(player: Player, truck: number?, by: string?): string?
	local data = DataService.Get(player)
	if not data or not PlotService.plotOf(player) then
		return "NoFarm"
	end
	local info = WarehouseRules.level(data.warehouse.level)
	local name = truckName(data)
	local sent, failure = 0, "TruckEmpty"
	for i = 1, info.trucks do
		if truck == nil or truck == i then
			local run, why = TruckRules.dispatch(data.warehouse, i, now(), MarketService.priceAt(), TruckService.tripFor(player, data, i))
			if run then
				sent += 1
				local lines = {}
				for _, crate in run.crates do
					local crop = Crops.ById[crate.crop]
					table.insert(lines, {
						text = `{crop.icon or ""} {crop.name} ×{crate.units}{if crate.grade == "A" then " (A)" else ""} @ {crate.price}`,
						coins = crate.coins,
					})
				end
				local which = if info.trucks > 1 then ` {i}` else ""
				Notice.send(player, if by == "Driver" then `Your Driver sent {name}{which}!` else `{name}{which} sent!`, "Receipt", {
					lines = lines,
					total = run.coins,
					footer = `Prices locked. Paid when it reaches the City in {math.floor(run.arriveAt - run.departAt + 0.5)} s.`,
				})
			elseif why == "TruckAway" and failure == "TruckEmpty" and truck ~= nil then
				failure = why
			end
		end
	end
	if sent == 0 then
		return failure
	end
	Analytics.step(player, data, "FirstDispatch")
	TruckService.Refresh(player)
	DataService.NotifyState(player)
	return nil
end

local actions = {}

-- "Dispatch" (every truck home and loaded) or "Dispatch" "2" (that truck).
function actions.Dispatch(player, _data, arg)
	return TruckService.Dispatch(player, tonumber(arg))
end

------------------------------------------------------------------------
-- Payouts

-- Pays runs that have reached the City and tidies those home. live: the
-- owner is playing (sales XP; a toast) or has just come back (the Welcome
-- back card says it, WorkerService).
local function settle(player: Player, live: boolean)
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local t = now()
	local warehouse = data.warehouse
	local due = TruckRules.collect(warehouse, t)
	local paid = 0
	for _, run in due do
		paid += run.coins
		DataService.Earn(player, run.coins, "TruckSale", live)
	end
	if paid > 0 and live then
		Notice.send(player, `🚚 Your {truckName(data)} reached the City: +{paid} coins`, "Good")
	end
	local back = TruckRules.tidy(warehouse, t)
	if #due > 0 or back > 0 then
		TruckService.Refresh(player)
		if back > 0 and live then
			Notice.send(player, `Your {truckName(data)} is back at the dock.`)
		end
	end
	return paid
end

-- Pays runs that arrived while you were away (WorkerService, on your
-- return, for the Welcome back card; no sales XP for them). From then on
-- runs are paid live. Returns the coins.
function TruckService.SettleAway(player: Player): number
	local paid = settle(player, false)
	ready[player] = true
	return paid
end

-- Dev command /truck: every run on the road arrives and comes home now.
function TruckService.Hurry(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local t = now()
	for _, run in data.warehouse.trucks do
		run.arriveAt = math.min(run.arriveAt, t)
		run.returnAt = math.min(run.returnAt, t)
	end
	settle(player, true)
	TruckService.Refresh(player)
end

------------------------------------------------------------------------

local function prompt(parent: Instance, name: string, action: string, hold: number, ownerId: number)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.HoldDuration = hold
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p:SetAttribute("OwnerId", ownerId)
	p.Parent = parent
	return p
end

-- The docks' prompts (after every rebuild of the warehouse side).
local function addPrompts(player: Player, index: number, data)
	local folder = docks(index)
	if not folder then
		return
	end
	local info = WarehouseRules.level(data.warehouse.level)
	for truck = 1, info.trucks do
		local spot = folder:FindFirstChild(`LoadSpot{truck}`)
		if spot then
			prompt(spot, "LoadPrompt", if info.handCart then "Load crates" else "Load crate", 0, player.UserId).Triggered:Connect(function(who)
				if who == player then
					load(player, truck)
				end
			end)
		end
		local leverBase = folder:FindFirstChild(`LeverBase{truck}`)
		if leverBase then
			prompt(leverBase, "LeverPrompt", `Send the {truckName(data)}`, 0.6, player.UserId).Triggered:Connect(function(who)
				if who == player then
					local failure = TruckService.Dispatch(player, truck)
					if failure == "TruckEmpty" then
						Notice.send(player, "Load some crates first.", "Error")
					elseif failure == "TruckAway" then
						Notice.send(player, `The {truckName(data)} is already on the road.`, "Error")
					end
				end
			end)
		end
	end
	TruckService.Refresh(player)
end

function TruckService.Start()
	ActionRemote(Remotes.func("TruckAction"), actions, DataService, 0.5)

	WarehouseService.OnRebuilt(addPrompts)
	PlotService.OnReleased(function(player)
		ready[player] = nil
	end)

	DataService.OnWiped(function(player)
		TruckService.Refresh(player)
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			for player in PlotService.owners() do
				if ready[player] then
					local ok, err = pcall(settle, player, true)
					if not ok then
						warn(`[TruckService] {player.Name}'s trucks: {err}`)
					end
				end
			end
		end
	end)
end
return TruckService
