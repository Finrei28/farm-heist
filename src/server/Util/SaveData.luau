-- The shape of a player's save (docs/GameDesign.md §8), and filling in fields
-- added since an old save was written. Kept apart from DataService (which
-- needs ProfileStore and Roblox's data stores) so tests can load it
-- (tests/savedata.test.luau).
--
-- Saves go to DataStores as JSON, so lists are arrays and maps use string
-- keys (never sparse number keys).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local Store = require(ReplicatedStorage.Shared.Config.Store)
local StoreLayout = require(ReplicatedStorage.Shared.StoreLayout)

-- New fields added here are filled in automatically for existing saves.
local TEMPLATE = {
	version = 1,
	coins = Settings.START_COINS,
	xp = 0,
	level = 1,
	playSeconds = 0, -- time played: the Sprout Shield (Config/Crime) and trading unlock count this

	-- The field: ["tileNumber"] = tile (shared/GrowthRules). Tiles 1–64 of
	-- the 8×8 grid; only open land can be planted (shared/LandRules).
	field = {},
	-- cleared: block numbers cleared with Land Permits, in order (the start
	-- blocks aren't listed). While a block is being cleared there's also
	-- clearing = { block, obstacles }. Permits come from the level (shared/LandRules).
	-- fresh: ["tile"] = true for newly cleared tiles not planted yet (+25% growth).
	land = { cleared = {}, fresh = {} },
	silo = 0, -- Silo upgrades bought (barn capacity)

	inventory = {
		crops = {}, -- ["cropId|mutation|giant"] = units
		seeds = Settings.START_SEEDS, -- [cropId] = seeds
		items = {}, -- [itemId] = count (tools, defences not placed, auction prizes)
	},
	seedStock = { index = -1, bought = {} }, -- packs bought in the current Barley's restock (shared/SeedStock)

	-- The warehouse (shared/TruckRules): crates in the truck's bed, crates set
	-- down at the dock, and truck runs on the road (paid when they reach the
	-- City, even if you've left by then).
	warehouse = { tier = 0, buildingUntil = 0, queues = {}, routes = {}, bed = {}, dock = {}, trucks = {} },
	-- Your store (shared/ShopRules, shared/StoreLayout): its level, a new
	-- building going up (build = { to, left } seconds of work), its name (nil:
	-- "<you>'s <building>"), the layout (["id"] = item on the floor or a wall),
	-- the items you own and how many of them were free, the stockroom's
	-- crates, your prices, the last shoppers' scores. A new store's starter
	-- kit is laid out by SaveData.migrate (a layout in here would be filled
	-- back in on every load by reconcile).
	store = { level = 1, started = false, layout = {}, owned = {}, gifts = {}, nextId = 1,
		stockroom = {}, prices = {}, rating = { scores = {} } },
	workers = {}, -- ["uid"] = { type, level, trait, hiredAt } (shared/WorkerRules)
	freeHireUsed = false,

	defences = { placed = {}, owned = {} },
	trusted = {}, -- user ids (numbers), up to 10

	-- Raids and arrests (shared/CrimeRules, shared/FineRules).
	crime = {
		earn = {}, -- ["fiveMinuteBucket"] = sales income in it (the last hour, for fines)
		arrests = {}, -- unix times you were arrested (repeat-offender multiplier)
		debts = {}, -- { ownerId, amount, createdAt }, oldest first
		lastArrestAt = 0,
		fled = false, -- left while knocked out: the next join starts on the police porch
	},
	payoutsClaimed = {}, -- ["payoutId"] = true: fines collected for you on other servers, already paid

	onboarded = {}, -- [step] = true: onboarding steps logged to analytics (Util/Analytics)
	guide = { done = {}, finished = false, hidden = false, rewarded = false },
	cropdex = {},
	quests = { day = 0, list = {}, bonusClaimed = false },
	streak = { days = 0, lastClaimDay = 0 },
	stats = { harvested = 0, arrestsMade = 0, timesArrested = 0, stolenValue = 0 },
	settings = { music = true, sfx = true, flashing = 1, reducedMotion = false, trades = true, quiet = false },
	purchaseIds = {}, -- recent developer product receipts already granted (so none is granted twice)
	lastOnline = 0, -- unix time of the last save, for offline growth and workers
}

local function deepCopy(value)
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Lays out a new store's starter kit (free items, kept forever).
local function startStore(store)
	for _, entry in Store.START do
		local id = tostring(store.nextId)
		store.nextId += 1
		store.layout[id] = { item = entry.item, x = entry.x, y = entry.y, rot = entry.rot, slots = StoreLayout.newSlots(entry.item) }
		store.owned[entry.item] = (store.owned[entry.item] or 0) + 1
		store.gifts[entry.item] = (store.gifts[entry.item] or 0) + 1
	end
	store.started = true
end

-- Changes an old save's shape to today's, after reconcile: a new store gets
-- its starter kit, and the Farm Stand's goods, prices and rating (week 2's
-- `shop`) move into the store, nothing lost.
local function migrate(data)
	if not data.store.started then
		startStore(data.store)
	end
	local shop = data.shop
	if shop then
		for _, crate in shop.stockroom or {} do
			table.insert(data.store.stockroom, crate)
		end
		for _, shelf in shop.shelves or {} do
			if shelf.units and shelf.units > 0 then
				if shelf.a > 0 then
					table.insert(data.store.stockroom, { crop = shelf.crop, key = `{shelf.crop}||`, units = shelf.a, grade = "A" })
				end
				if shelf.units - shelf.a > 0 then
					table.insert(data.store.stockroom, { crop = shelf.crop, key = `{shelf.crop}||`, units = shelf.units - shelf.a, grade = "B" })
				end
			end
		end
		for cropId, price in shop.prices or {} do
			data.store.prices[cropId] = data.store.prices[cropId] or price
		end
		if shop.rating and #shop.rating.scores > 0 then
			data.store.rating.scores = shop.rating.scores
		end
		data.shop = nil
	end
end

-- Fills in any keys added to TEMPLATE since the player last saved.
local function reconcile(data, template)
	for key, default in template do
		if data[key] == nil then
			data[key] = deepCopy(default)
		elseif typeof(default) == "table" and typeof(data[key]) == "table" then
			reconcile(data[key], default)
		end
	end
end

return {
	TEMPLATE = TEMPLATE,
	deepCopy = deepCopy,
	reconcile = reconcile,
	migrate = migrate,
}
