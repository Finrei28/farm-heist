-- Barley's Seeds stock (docs/GameDesign.md §4.3). The shop restocks every
-- RESTOCK_SECONDS on the clock, the same on every server and for every
-- player, worked out from the time (so the client shows the stock and the
-- countdown without asking). Commons are always in, with no limit; every
-- other seed rolls its rarity's chance, then 1–maxPacks packs of packSeeds
-- seeds. Players don't share stock: buying never takes any from someone
-- else. What a player bought is kept in their save for that restock
-- (data.seedStock), so rejoining or hopping servers doesn't refill it.
--
-- Dev: ReplicatedStorage attribute SeedStockShift moves to another
-- restock's stock, and SeedStockFull = that restock number puts everything
-- in for it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crops = require(script.Parent.Config.Crops)
local Rarities = require(script.Parent.Config.Rarities)

local SeedStock = {
	RESTOCK_SECONDS = 300,
	UNLIMITED = math.huge,
}

-- The restock that's on now (a whole number; counts up every RESTOCK_SECONDS).
function SeedStock.index(now: number?): number
	now = now or workspace:GetServerTimeNow()
	return now // SeedStock.RESTOCK_SECONDS + (ReplicatedStorage:GetAttribute("SeedStockShift") or 0)
end

-- When the next restock comes (server time).
function SeedStock.nextAt(now: number?): number
	now = now or workspace:GetServerTimeNow()
	return (now // SeedStock.RESTOCK_SECONDS + 1) * SeedStock.RESTOCK_SECONDS
end

-- { [cropId] = seeds each player may buy } for a restock (0 = not in;
-- SeedStock.UNLIMITED for Commons).
function SeedStock.stock(index: number): { [string]: number }
	local full = ReplicatedStorage:GetAttribute("SeedStockFull") == index
	local rng = Random.new(index * 7919 + 101)
	local stock = {}
	for _, crop in Crops.List do
		local rarity = Rarities.ById[crop.rarity]
		-- (rolled for every crop, so each one's luck doesn't depend on the others')
		local roll = rng:NextNumber()
		local packs = rng:NextInteger(1, math.max(1, rarity.maxPacks))
		if rarity.unlimited then
			stock[crop.id] = SeedStock.UNLIMITED
		elseif full then
			stock[crop.id] = rarity.maxPacks * rarity.packSeeds
		elseif roll < rarity.seedChance then
			stock[crop.id] = packs * rarity.packSeeds
		else
			stock[crop.id] = 0
		end
	end
	return stock
end

-- Seeds of `cropId` this player can still buy in the current restock.
function SeedStock.left(data, cropId: string, now: number?): number
	local index = SeedStock.index(now)
	local seeds = SeedStock.stock(index)[cropId] or 0
	if seeds == SeedStock.UNLIMITED then
		return seeds
	end
	local record = data.seedStock
	local bought = if record and record.index == index then (record.bought[cropId] or 0) else 0
	return math.max(0, seeds - bought)
end

-- Whether a player may buy `count` seeds now. Returns ok, reason.
function SeedStock.canBuy(data, cropId: string, count: number, level: number, now: number?): (boolean, string?)
	local crop = Crops.ById[cropId]
	if not crop or count < 1 or count ~= math.floor(count) then
		return false, "BadRequest"
	end
	local rarity = Rarities.ById[crop.rarity]
	if level < rarity.seedLevel then
		return false, "Locked" -- (auction lots have no level lock; planting a Mythic still needs Lv 20)
	end
	if SeedStock.left(data, cropId, now) < count then
		return false, "SoldOut"
	end
	if (data.coins or 0) < crop.seed * count then
		return false, "TooPoor"
	end
	return true, nil
end

-- Notes seeds bought in the current restock (server, after charging).
function SeedStock.record(data, cropId: string, count: number, now: number?)
	local index = SeedStock.index(now)
	if not data.seedStock or data.seedStock.index ~= index then
		data.seedStock = { index = index, bought = {} }
	end
	data.seedStock.bought[cropId] = (data.seedStock.bought[cropId] or 0) + count
end

return SeedStock
