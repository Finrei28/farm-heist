-- The pickup (docs/GameDesign.md §4.6, shared/TruckRules): loading crates
-- at the dock, dispatching it (the lever at the dock, or the Market
-- window's button from anywhere), the receipt with the prices it locked,
-- and the payout when it reaches the City. Runs are saved, so one that
-- arrives after you've left is paid when you next join, on any server.
--
-- The truck model's attributes DepartAt / ArriveAt / ReturnAt (0 = home)
-- are all the clients need to drive it there and back (TruckController).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Crops = require(Shared.Config.Crops)
local Remotes = require(Shared.Remotes)
local TruckRules = require(Shared.TruckRules)

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

local function now(): number
	return workspace:GetServerTimeNow()
end

local function truckOf(index: number): Model
	return PlotService.model(index).Truck
end

-- Shows the truck's state on its model and the dock's prompts.
local function refresh(player: Player)
	local index = PlotService.plotOf(player)
	local data = DataService.Get(player)
	if not index or not data then
		return
	end
	local warehouse = data.warehouse
	local t = now()
	local truck = truckOf(index)
	local run = TruckRules.nextBack(warehouse, t)
	truck:SetAttribute("DepartAt", if run then run.departAt else 0)
	truck:SetAttribute("ArriveAt", if run then run.arriveAt else 0)
	truck:SetAttribute("ReturnAt", if run then run.returnAt else 0)
	if not run or t >= run.arriveAt then -- (the crates ride along until they're sold in the City)
		YardArt.showBed(truck, warehouse.bed)
	end
	local tier = TruckRules.tier(warehouse)
	local model = PlotService.model(index)
	local load = model.LoadSpot:FindFirstChild("LoadPrompt")
	if load then
		load.ObjectText = if run then "Pickup: on the road" else `Pickup {#warehouse.bed}/{tier.truckCrates}`
	end
	local lever = model.LeverBase:FindFirstChild("LeverPrompt")
	if lever then
		lever.ObjectText = if run then "Pickup: on the road" else `{#warehouse.bed} crate{if #warehouse.bed == 1 then "" else "s"} · locks today's prices`
	end
end

------------------------------------------------------------------------
-- Loading and dispatching

local function load(player: Player)
	local index = PlotService.plotOf(player)
	local data = DataService.Get(player)
	if not index or not data then
		return
	end
	local position = MovementService.positionOf(player)
	local spot = PlotService.model(index).LoadSpot.Position
	if not position or (position - spot).Magnitude > TruckService.DOCK_REACH then
		return
	end
	local warehouse = data.warehouse
	local fromPile = not WarehouseService.carried(player)
	if fromPile and #warehouse.dock == 0 then
		Notice.send(player, "Pack a crate at the bench first (Truck), then bring it here.", "Error")
		return
	end
	local failure = TruckRules.cannotLoad(warehouse, now())
	if failure then
		Notice.send(player, if failure == "TruckFull" then "The pickup is full. Pull the lever to send it!" else "The pickup is out on the road. Set the crate down and load it when it's back.", "Error")
		return
	end
	local crate = if fromPile then table.remove(warehouse.dock, 1) else WarehouseService.takeCarried(player)
	TruckRules.load(warehouse, crate, now())
	if fromPile then
		WarehouseService.showDock(player)
	end
	refresh(player)
	DataService.NotifyState(player)
end

-- Sends the loaded truck: the prices lock now, and a receipt shows them.
function TruckService.Dispatch(player: Player): string?
	local data = DataService.Get(player)
	if not data or not PlotService.plotOf(player) then
		return "NoFarm"
	end
	local run, failure = TruckRules.dispatch(data.warehouse, now(), MarketService.priceAt())
	if not run then
		return failure
	end
	local lines = {}
	for _, crate in run.crates do
		local crop = Crops.ById[crate.crop]
		table.insert(lines, {
			text = `{crop.icon or ""} {crop.name} ×{crate.units}{if crate.grade == "A" then " (A)" else ""} @ {crate.price}`,
			coins = crate.coins,
		})
	end
	Notice.send(player, "Pickup sent!", "Receipt", {
		lines = lines,
		total = run.coins,
		footer = `Prices locked. Paid when it reaches the City in {math.floor(run.arriveAt - run.departAt + 0.5)} s.`,
	})
	Analytics.step(player, data, "FirstDispatch")
	refresh(player)
	return nil
end

local actions = {}

function actions.Dispatch(player)
	return TruckService.Dispatch(player)
end

------------------------------------------------------------------------
-- Payouts

-- Pays runs that have reached the City and tidies those home. live: the
-- owner is playing (sales XP; a toast) or has just come back (a summary).
local function settle(player: Player, live: boolean)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local t = now()
	local warehouse = data.warehouse
	local due = TruckRules.collect(warehouse, t)
	local paid, crates = 0, 0
	for _, run in due do
		paid += run.coins
		crates += #run.crates
		DataService.Earn(player, run.coins, "TruckSale", live)
	end
	if paid > 0 then
		if live then
			Notice.send(player, `🚚 Your pickup reached the City: +{paid} coins`, "Good")
		else
			Notice.send(player, `🚚 While you were away your pickup sold {crates} crate{if crates == 1 then "" else "s"} in the City: +{paid} coins`, "Good")
		end
	end
	local back = TruckRules.tidy(warehouse, t)
	if #due > 0 or back > 0 then
		refresh(player)
		if back > 0 and live then
			Notice.send(player, "Your pickup is back at the dock.")
		end
	end
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
	refresh(player)
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

function TruckService.Start()
	ActionRemote(Remotes.func("TruckAction"), actions, DataService, 0.5)

	PlotService.OnAssigned(function(player, index)
		local model = PlotService.model(index)
		prompt(model.LoadSpot, "LoadPrompt", "Load crate", 0, player.UserId).Triggered:Connect(function(who)
			if who == player then
				load(player)
			end
		end)
		prompt(model.LeverBase, "LeverPrompt", "Send the pickup", 0.6, player.UserId).Triggered:Connect(function(who)
			if who == player then
				local failure = TruckService.Dispatch(player)
				if failure == "TruckEmpty" then
					Notice.send(player, "Load some crates first.", "Error")
				elseif failure == "TruckAway" then
					Notice.send(player, "The pickup is already on the road.", "Error")
				end
				DataService.NotifyState(player)
			end
		end)
		settle(player, false)
		refresh(player)
	end)

	PlotService.OnReleased(function(_player, index)
		local model = PlotService.model(index)
		for _, name in { "LoadPrompt", "LeverPrompt" } do
			local p = model:FindFirstChild(name, true)
			if p then
				p:Destroy()
			end
		end
		local truck = truckOf(index)
		truck:SetAttribute("DepartAt", 0)
		truck:SetAttribute("ArriveAt", 0)
		truck:SetAttribute("ReturnAt", 0)
		YardArt.showBed(truck, {})
	end)

	DataService.OnWiped(function(player)
		refresh(player)
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			for player in PlotService.owners() do
				settle(player, true)
			end
		end
	end)
end
return TruckService
