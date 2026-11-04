-- The Cloverdale Exchange (docs/GameDesign.md §4.7): the truck price every
-- sale uses, announcements for each hour's Hot Crop and Glut, and the desk
-- in town that opens the Market window. Prices come from shared/MarketPrice
-- and the server clock, so the clients work out the same numbers for the
-- board and the window without being sent them.
--
-- The supply factor: crops sent to the City by truck on every server pull
-- that crop's price down for a while. Each server adds what its trucks took
-- to MemoryStore counters (`<window>|<crop>|<shard>` in the "MarketSupply"
-- sorted map, 10-minute windows, this server's shard of 8, written every
-- 30 s), reads every server's last two windows back every 30 s, and works
-- each crop's supply out (MarketPrice.supply, over the last 10 minutes). It
-- publishes them as ReplicatedStorage.MarketSupply's attributes, which the
-- clients' MarketPrice reads, so the board and window match the price a
-- truck locks. If MemoryStore fails, supply stays at 1.
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Crops = require(Shared.Config.Crops)
local Market = require(Shared.Config.Market)
local MarketPrice = require(Shared.MarketPrice)

local Notice = require(ServerScriptService.Server.Util.Notice)

local MarketService = {}

local SHARDS = 8
local FLUSH_EVERY = 30 -- seconds between writes (and reads)

local supplyFolder = Instance.new("Folder")
supplyFolder.Name = "MarketSupply"
supplyFolder.Parent = ReplicatedStorage

local supply = {} -- [cropId] = the supply factor now (1: none to speak of)
local pending = {} -- [cropId] = units sold here since the last write
local shard = math.random(1, SHARDS)

local function now(): number
	return workspace:GetServerTimeNow()
end

-- (prices everywhere on the server, MarketPrice.price included, use it)
MarketPrice.supplyOf = function(cropId: string): number
	return supply[cropId] or 1
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

-- Units of a crop just sent to the City by truck (TruckService, at dispatch).
function MarketService.Sold(cropId: string, units: number)
	if Crops.ById[cropId] and units > 0 then
		pending[cropId] = (pending[cropId] or 0) + units
	end
end

local function map()
	local ok, sorted = pcall(MemoryStoreService.GetSortedMap, MemoryStoreService, "MarketSupply")
	return if ok then sorted else nil
end

-- Adds this server's sales to its shard of the current window.
local function flush(sorted)
	local window = math.floor(now() / Market.SUPPLY_WINDOW)
	for cropId, units in pending do
		local ok = pcall(sorted.UpdateAsync, sorted, `{window}|{cropId}|{shard}`, function(old)
			return (tonumber(old) or 0) + units
		end, Market.SUPPLY_WINDOW * 3)
		if ok then
			pending[cropId] = nil
		end
	end
end

-- Every server's sales in a window: [cropId] = units, or nil if unreadable.
local function readWindow(sorted, window: number)
	local ok, items = pcall(sorted.GetRangeAsync, sorted, Enum.SortDirection.Ascending, 200, `{window}|`, `{window}|~`)
	if not ok then
		return nil
	end
	local counts = {}
	for _, item in items do
		local cropId = string.match(item.key, "^%d+|([^|]+)|")
		if cropId then
			counts[cropId] = (counts[cropId] or 0) + (tonumber(item.value) or 0)
		end
	end
	return counts
end

-- Works out every crop's supply from the last two windows (the one before
-- weighing less as the current one goes on) and publishes the changes.
local function refresh(sorted)
	local t = now()
	local window = math.floor(t / Market.SUPPLY_WINDOW)
	local into = (t % Market.SUPPLY_WINDOW) / Market.SUPPLY_WINDOW
	local current, previous = readWindow(sorted, window), readWindow(sorted, window - 1)
	if not (current and previous) then
		return
	end
	for _, crop in Crops.List do
		local sold = (current[crop.id] or 0) + (pending[crop.id] or 0) + (previous[crop.id] or 0) * (1 - into)
		local value = math.floor(MarketPrice.supply(crop.id, sold) * 1000 + 0.5) / 1000
		if supply[crop.id] ~= value then
			supply[crop.id] = if value < 1 then value else nil
			supplyFolder:SetAttribute(crop.id, supply[crop.id])
		end
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
		while true do
			task.wait(FLUSH_EVERY)
			local sorted = map()
			if sorted then
				flush(sorted)
				refresh(sorted)
			end
		end
	end)

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
