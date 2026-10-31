-- Your Farm Stand (shop tier 0, docs/GameDesign.md §4.8, shared/ShopRules):
-- stocking its shelves from the stockroom (the "Stock shelves" prompt at the
-- counter), your prices (the Shop window), and NPC shoppers while you're in
-- the server. Shoppers are simulated here; each client draws them walking
-- the sidewalk from the ShopperEvent remote (ShopperController). A shopper
-- decides at the counter, so the coins come in when they get there.
--
-- (Shoppers only come while you're playing. Selling while you're away is
-- worked out on your return with the workers, in week 3.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Crops = require(Shared.Config.Crops)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local Shop = require(Shared.Config.Shop)
local ShopRules = require(Shared.ShopRules)

local Server = ServerScriptService.Server
local ActionRemote = require(Server.Util.ActionRemote)
local Analytics = require(Server.Util.Analytics)
local Notice = require(Server.Util.Notice)
local YardArt = require(Server.World.YardArt)
local DataService = require(script.Parent.DataService)
local MarketService = require(script.Parent.MarketService)
local MovementService = require(script.Parent.MovementService)
local PlotService = require(script.Parent.PlotService)

local ShopService = {}

ShopService.STAND_REACH = 12 -- studs from the counter you can stock it from
local TICK = 0.25
local RUSH_GAP = 1.5 -- seconds between shoppers during /shoppers

local ShopperEvent = Remotes.event("ShopperEvent")
local rng = Random.new()

local nextAt = {} -- [Player] = server time the next shopper sets off
local rush = {} -- [Player] = shoppers left to send quickly (/shoppers)
local walking = {} -- { { player, plot, id, arriveAt } }
local soldOutTold = {} -- [Player] = true once told the stand sold out (until restocked)
local lastId = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Redraws a player's stand: each shelf's produce and price tag.
function ShopService.Refresh(player: Player)
	local index = PlotService.plotOf(player)
	local data = DataService.Get(player)
	if not index or not data then
		return
	end
	local model = PlotService.model(index)
	local shop = data.shop
	for i = 1, ShopRules.tier(shop).shelves do
		local key = tostring(i)
		local shelf = shop.shelves[key]
		YardArt.showShelf(model, key, shelf, shelf and shop.prices[shelf.crop])
	end
	local prompt = model.FarmStand.Counter:FindFirstChild("StockPrompt")
	if prompt then
		local waiting = 0
		for _, crate in shop.stockroom do
			waiting += crate.units
		end
		prompt.ObjectText = `Stockroom: {waiting}`
	end
end

local function stock(player: Player)
	local index = PlotService.plotOf(player)
	local data = DataService.Get(player)
	if not index or not data then
		return
	end
	local position = MovementService.positionOf(player)
	local counter = PlotService.model(index).FarmStand.Counter.Position
	if not position or (position - counter).Magnitude > ShopService.STAND_REACH then
		return
	end
	if #data.shop.stockroom == 0 then
		Notice.send(player, "The stockroom is empty. Pack crates at the bench and send them to the Stand.", "Error")
		return
	end
	local moved = ShopRules.stock(data.shop, MarketService.priceAt())
	if moved == 0 then
		Notice.send(player, "The shelves are full.", "Error")
		return
	end
	soldOutTold[player] = nil
	ShopService.Refresh(player)
	DataService.NotifyState(player)
end

------------------------------------------------------------------------
-- Actions (the Shop window)

local actions = {}

-- "cropId|coins"
function actions.Price(player, data, arg)
	local cropId, coinsText = string.match(arg or "", "^(%w+)|(%d+)$")
	local coins = tonumber(coinsText)
	if not Crops.ById[cropId] or not coins then
		return "BadRequest"
	end
	ShopRules.setPrice(data.shop, cropId, coins, MarketService.price(cropId))
	ShopService.Refresh(player)
	return nil
end

-- shelf: "1", "2", ... back to the stockroom
function actions.TakeDown(player, data, arg)
	if not data.shop.shelves[arg or ""] then
		return "BadRequest"
	end
	ShopRules.takeDown(data.shop, arg)
	ShopService.Refresh(player)
	return nil
end

------------------------------------------------------------------------
-- Shoppers

local function sendShopper(player: Player, index: number, t: number)
	lastId += 1
	local lane = rng:NextInteger(-1, 1)
	local route, counter = PlotLayout.shopperRoute(index, lane)
	local arriveAt = t + PlotLayout.pathLength(route, counter) / Shop.SHOPPER_SPEED
	table.insert(walking, { player = player, plot = index, id = lastId, arriveAt = arriveAt })
	ShopperEvent:FireAllClients("Arrive", { plot = index, id = lastId, at = t, lane = lane, look = rng:NextInteger(1, 1000) })
end

local function arrive(shopper)
	local player = shopper.player
	local data = DataService.Get(player)
	local visit = nil
	if data and PlotService.plotOf(player) == shopper.plot then
		visit = ShopRules.visit(data.shop, rng, MarketService.priceAt())
	end
	ShopperEvent:FireAllClients("Done", {
		plot = shopper.plot, id = shopper.id,
		crop = visit and visit.crop, units = visit and visit.units or 0, coins = visit and visit.coins or 0,
	})
	if not visit then
		return
	end
	if visit.coins > 0 then
		DataService.Earn(player, visit.coins, "StandSale", true)
		Analytics.step(player, data, "FirstShopSale")
	end
	ShopService.Refresh(player)
	DataService.NotifyState(player)
	if not ShopRules.isOpen(data.shop) and not soldOutTold[player] then
		soldOutTold[player] = true
		Notice.send(player, if #data.shop.stockroom > 0
			then "Your Farm Stand sold out! Stock it again from the stockroom."
			else "Your Farm Stand sold out! Send it more crates from the Packing Shed.")
	end
end

-- Dev command /shoppers N: the next N shoppers come one after another.
function ShopService.Rush(player: Player, count: number)
	rush[player] = count
	nextAt[player] = now()
end

local function tick()
	local t = now()
	for player, index in PlotService.owners() do
		local data = DataService.Get(player)
		if data and t >= (nextAt[player] or 0) then
			if ShopRules.isOpen(data.shop) then
				sendShopper(player, index, t)
				if (rush[player] or 0) > 0 then
					rush[player] -= 1
					nextAt[player] = t + RUSH_GAP
				else
					nextAt[player] = t + ShopRules.interval(data.shop) * rng:NextNumber(0.75, 1.25)
				end
			else
				nextAt[player] = t + 2 -- (closed: look again soon)
			end
		end
	end
	for i = #walking, 1, -1 do
		local shopper = walking[i]
		if t >= shopper.arriveAt then
			table.remove(walking, i)
			arrive(shopper)
		end
	end
end

------------------------------------------------------------------------

function ShopService.Start()
	ActionRemote(Remotes.func("ShopAction"), actions, DataService, 0.1)

	PlotService.OnAssigned(function(player, index)
		local counter = PlotService.model(index).FarmStand.Counter
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StockPrompt"
		prompt.ActionText = "Stock shelves"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("OwnerId", player.UserId)
		prompt.Parent = counter
		prompt.Triggered:Connect(function(who)
			if who == player then
				stock(player)
			end
		end)
		nextAt[player] = now() + 5
		ShopService.Refresh(player)
	end)

	PlotService.OnReleased(function(player, index)
		local model = PlotService.model(index)
		local prompt = model.FarmStand.Counter:FindFirstChild("StockPrompt")
		if prompt then
			prompt:Destroy()
		end
		for key = 1, Shop.TIERS[#Shop.TIERS].shelves do
			YardArt.showShelf(model, tostring(key), nil, nil)
		end
		nextAt[player], rush[player], soldOutTold[player] = nil, nil, nil
	end)

	DataService.OnWiped(function(player)
		ShopService.Refresh(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		nextAt[player], rush[player], soldOutTold[player] = nil, nil, nil
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			tick()
		end
	end)
end

return ShopService
