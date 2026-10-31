-- The Cloverdale Exchange (docs/GameDesign.md §4.7): the truck price every
-- sale uses, announcements for each hour's Hot Crop and Glut, and the desk
-- in town that opens the Market window. Prices come from shared/MarketPrice
-- and the server clock, so the clients work out the same numbers for the
-- board and the window without being sent them. (The supply factor from
-- MemoryStore comes in week 7; until then it's 1.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Crops = require(Shared.Config.Crops)
local Market = require(Shared.Config.Market)
local MarketPrice = require(Shared.MarketPrice)

local Notice = require(ServerScriptService.Server.Util.Notice)

local MarketService = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- The truck price of one standard unit (grade B, no mutation) at time t
-- (default now).
function MarketService.price(cropId: string, t: number?): number
	return MarketPrice.price(cropId, t or now())
end

-- MarketService.price as a priceAt(cropId) for shared/TruckRules and
-- shared/ShopRules, fixed at one moment.
function MarketService.priceAt(t: number?)
	local at = t or now()
	return function(cropId: string): number
		return MarketPrice.price(cropId, at)
	end
end

local function announce(schedule, t: number, last: number)
	local hot, glut = Crops.ById[schedule.hot.crop], Crops.ById[schedule.glut.crop]
	local minutes = Market.HOT.length // 60
	local function crossed(at: number): boolean
		return last < at and t >= at
	end
	if crossed(schedule.hot.startsAt - Market.ANNOUNCE_AHEAD) then
		Notice.all(`🔥 Hot Crop in 2 minutes: {hot.name} sells for ×{Market.HOT.mult} at the Exchange for {minutes} minutes!`, "Announce")
	elseif crossed(schedule.hot.startsAt) then
		Notice.all(`🔥 {hot.name} is the Hot Crop! Trucks get ×{Market.HOT.mult} for {minutes} minutes.`, "Announce")
	end
	if crossed(schedule.glut.startsAt - Market.ANNOUNCE_AHEAD) then
		Notice.all(`📉 Glut in 2 minutes: {glut.name} drops to ×{Market.GLUT.mult} at the Exchange. Sell it at your stand instead?`, "Announce")
	elseif crossed(schedule.glut.startsAt) then
		Notice.all(`📉 {glut.name} glut: trucks pay ×{Market.GLUT.mult} for {Market.GLUT.length // 60} minutes.`, "Announce")
	end
end

function MarketService.Start()
	local desk = workspace.World.Town:FindFirstChild("ExchangeDesk")
	if desk then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "MarketPrompt"
		prompt.ActionText = "Market prices"
		prompt.ObjectText = "Cloverdale Exchange"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Opens", "Market") -- (the client opens the window)
		prompt.Parent = desk
	else
		warn("[MarketService] no ExchangeDesk in the town")
	end

	task.spawn(function()
		local last = now()
		while true do
			task.wait(1)
			local t = now()
			announce(MarketPrice.schedule(t), t, last)
			last = t
		end
	end)
end

return MarketService
