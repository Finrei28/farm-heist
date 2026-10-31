-- The Packing Shed (warehouse tier 0, docs/GameDesign.md §4.6). At the
-- bench you pick a barn stack and where its crate goes (the truck or your
-- Farm Stand), hold to wash it and let go in the green for grade A
-- (shared/CrateRules; the server times the hold itself). A crate for the
-- truck goes into your arms: carry it to the dock and load it
-- (TruckService). A crate for the stand goes to its stockroom (ShopService
-- puts it on the shelves).
--
-- A crate you're carrying is set down at the dock if you leave your farm,
-- travel, respawn or leave the game, so nothing is ever lost: the dock's
-- "Load crate" takes from that pile too.
--
-- WarehouseAction remote: "Wash" "stackKey|Truck" or "stackKey|Stand", then "Pack".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local BarnRules = require(Shared.BarnRules)
local CrateRules = require(Shared.CrateRules)
local Crops = require(Shared.Config.Crops)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local Warehouse = require(Shared.Config.Warehouse)

local Server = ServerScriptService.Server
local ActionRemote = require(Server.Util.ActionRemote)
local Analytics = require(Server.Util.Analytics)
local Notice = require(Server.Util.Notice)
local YardArt = require(Server.World.YardArt)
local DataService = require(script.Parent.DataService)
local MovementService = require(script.Parent.MovementService)
local PlotService = require(script.Parent.PlotService)
local ShopService = require(script.Parent.ShopService)

local WarehouseService = {}

WarehouseService.BENCH_REACH = 12 -- studs from the bench you can pack from

local washing = {} -- [Player] = { key, to, at } while the wash is held
local carrying = {} -- [Player] = crate

local function now(): number
	return workspace:GetServerTimeNow()
end

local function benchWorld(index: number): Vector3
	return PlotLayout.toWorld(index, PlotLayout.PLOT.bench)
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

-- Redraws the crates waiting at a player's dock.
function WarehouseService.showDock(player: Player)
	local index = PlotService.plotOf(player)
	local data = DataService.Get(player)
	if index and data then
		YardArt.showDockPile(PlotService.model(index), data.warehouse.dock)
	end
end

-- Sets the carried crate down at the dock (left the farm, travelled,
-- respawned, leaving). draw = false while leaving (the farm is going).
local function setDown(player: Player, data, draw: boolean, why: string?)
	local crate = carrying[player]
	if not crate then
		return
	end
	setCarrying(player, nil)
	table.insert(data.warehouse.dock, crate)
	if draw then
		WarehouseService.showDock(player)
		DataService.NotifyState(player)
		if why then
			Notice.send(player, why)
		end
	end
end

------------------------------------------------------------------------
-- Actions

local actions = {}

-- "stackKey|Truck" or "stackKey|Stand": starts the wash (the hold).
function actions.Wash(player, data, arg)
	local key, to = string.match(arg or "", "^([%w|]+)|(%a+)$")
	if not key or (to ~= "Truck" and to ~= "Stand") or not Crops.ById[BarnRules.parse(key)] then
		return "BadRequest"
	end
	local index = PlotService.plotOf(player)
	if not index then
		return "NoFarm"
	end
	local position = MovementService.positionOf(player)
	if not position or (position - benchWorld(index)).Magnitude > WarehouseService.BENCH_REACH then
		return "TooFar"
	end
	if (data.inventory.crops[key] or 0) <= 0 then
		return "NoCrops"
	end
	if to == "Truck" and carrying[player] then
		return "Carrying"
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
	local index = PlotService.plotOf(player)
	if not index then
		return "NoFarm"
	end
	if wash.to == "Truck" and carrying[player] then
		return "Carrying"
	end
	local grade = CrateRules.grade(now() - wash.at, Warehouse.WASH.slack)
	local crate = CrateRules.pack(data.inventory, wash.key, grade)
	if not crate then
		return "NoCrops"
	end
	if wash.to == "Truck" then
		setCarrying(player, crate)
	else
		table.insert(data.shop.stockroom, crate)
		ShopService.Refresh(player) -- (the stand's prompt shows the stockroom count)
	end
	Analytics.step(player, data, "FirstCrate")
	return nil, { grade = grade, units = crate.units, crop = crate.crop, to = wash.to }
end

------------------------------------------------------------------------

function WarehouseService.Start()
	ActionRemote(Remotes.func("WarehouseAction"), actions, DataService, 0.05)

	PlotService.OnAssigned(function(player, index)
		local model = PlotService.model(index)
		local bench = model.PackingShed.Bench
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BenchPrompt"
		prompt.ActionText = "Pack crates"
		prompt.ObjectText = "Packing Shed"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Opens", "Bench") -- (the client opens the bench window)
		prompt:SetAttribute("OwnerId", player.UserId)
		prompt.Parent = bench
		WarehouseService.showDock(player)
	end)

	PlotService.OnReleased(function(_player, index)
		local model = PlotService.model(index)
		local prompt = model.PackingShed.Bench:FindFirstChild("BenchPrompt")
		if prompt then
			prompt:Destroy()
		end
		YardArt.showDockPile(model, {})
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
	DataService.OnWiped(function(player)
		carrying[player] = nil
		player:SetAttribute("Carrying", nil)
		if player.Character then
			YardArt.carry(player.Character, nil)
		end
		WarehouseService.showDock(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function() -- (after BeforeRelease has set the crate down)
			washing[player] = nil
			carrying[player] = nil
		end)
	end)
end

return WarehouseService
