-- Your store (docs/GameDesign.md §4.8): the grid, the buildings, Store
-- Levels 1–20 and the catalog. How shoppers decide is Config/Shop and
-- shared/DemandModel; the layout rules are shared/StoreLayout.
--
-- The floor is a grid of CELL-stud cells. x runs across from the gate end
-- (1) toward the hedge, y from the front wall (1) to the back: seen from the
-- road, x reads left to right. The front door is always at (DOOR_X, 1) and
-- the staff door (owner only, into the yard) in the gate-side wall beside
-- (1, STAFF_Y), in every building, so a layout carries over when the store
-- grows. Positions in the world: shared/PlotLayout.storeLocal.
local Store = {}

Store.CELL = 4
Store.DOOR_X = 3
Store.STAFF_Y = 2
Store.MAX_FLOOR_ITEMS = 100
Store.MAX_WALL_ITEMS = 40
Store.QUEUE_CELLS = 2 -- free cells in a line behind a checkout's front cell
Store.SELL_BACK = 0.5 -- selling an item back pays this share of its cost
Store.NAME_MAX = 24
Store.BACK_SOON_IDLE = 300 -- seconds of decorating without saving before it ends on its own

-- Index = building stage. cells: the building's whole floor (taped off
-- until the levels open it). buildSeconds: how long it takes to put up
-- (online; a quarter as fast while you're away, like growth). gift: a free
-- display already placed in the new space. shoppers: how many can be on
-- their visit at once (the sidewalk included; the next one waits), more in
-- a bigger store with longer aisles.
Store.BUILDINGS = {
	{ id = "CornerStore", name = "Corner Store", from = 1, cells = { 8, 6 }, buildSeconds = 0, shoppers = 8 },
	{ id = "FarmShop", name = "Farm Shop", from = 5, cells = { 11, 9 }, buildSeconds = 120, gift = "TieredRack", shoppers = 12 },
	{ id = "MarketHall", name = "Market Hall", from = 10, cells = { 15, 11 }, buildSeconds = 300, gift = "GlassShowcase", shoppers = 16 },
	{ id = "Supermarket", name = "Supermarket", from = 15, cells = { 20, 14 }, buildSeconds = 600, gift = "SelfCheckout", shoppers = 24 },
}

-- Store Levels. floor = open cells { across, deep }: every level opens a
-- row or a column, and both at Levels 4, 5, 10, 15 and 20 (the move into
-- each new building, the Corner Store's last level and the very last), so
-- each building's whole floor is open by its last level and the Supermarket
-- reaches 20 × 14 (it fills the store's lot, PlotLayout.PLOT.shop). The rest
-- of each is worked out: the building, stockroom crates (6 + 2 a level),
-- checkouts allowed and how many crops a shopper wants (StoreLayout.level).
Store.LEVELS = {
	{ cost = 0, farmLevel = 1, floor = { 6, 4 } },
	{ cost = 300, farmLevel = 1, floor = { 7, 4 } },
	{ cost = 900, farmLevel = 3, floor = { 7, 5 } },
	{ cost = 2_500, farmLevel = 4, floor = { 8, 6 } },
	{ cost = 6_000, farmLevel = 5, floor = { 9, 7 } },
	{ cost = 10_000, farmLevel = 6, floor = { 10, 7 } },
	{ cost = 16_000, farmLevel = 7, floor = { 10, 8 } },
	{ cost = 24_000, farmLevel = 8, floor = { 11, 8 } },
	{ cost = 35_000, farmLevel = 10, floor = { 11, 9 } },
	{ cost = 55_000, farmLevel = 12, floor = { 12, 10 } },
	{ cost = 75_000, farmLevel = 13, floor = { 13, 10 } },
	{ cost = 100_000, farmLevel = 14, floor = { 14, 10 } },
	{ cost = 130_000, farmLevel = 16, floor = { 14, 11 } },
	{ cost = 170_000, farmLevel = 18, floor = { 15, 11 } },
	{ cost = 240_000, farmLevel = 20, floor = { 16, 12 }, billboard = true },
	{ cost = 330_000, farmLevel = 22, floor = { 17, 12 } },
	{ cost = 440_000, farmLevel = 24, floor = { 17, 13 } },
	{ cost = 580_000, farmLevel = 26, floor = { 18, 13 } },
	{ cost = 760_000, farmLevel = 28, floor = { 19, 13 } },
	{ cost = 1_000_000, farmLevel = 30, floor = { 20, 14 }, goldStar = true },
}
Store.STOCKROOM = 6 -- crates at Level 1 ...
Store.STOCKROOM_PER_LEVEL = 2 -- ... and this many more a level
Store.CHECKOUTS = { { from = 1, count = 1 }, { from = 3, count = 2 }, { from = 10, count = 3 }, { from = 15, count = 4 } }
Store.WANTS = { { from = 1, min = 1, max = 1 }, { from = 5, min = 1, max = 2 }, { from = 10, min = 1, max = 3 }, { from = 15, min = 2, max = 3 } }
Store.BILLBOARD = 0.15 -- the Supermarket's billboard: this many more shoppers

-- Every 10 Charm is +0.1★, up to +1★ at 100 (a second copy of an item
-- counts half, a third a third ...).
Store.CHARM_STEP = 10
Store.CHARM_STAR_STEP = 0.1
Store.CHARM_MAX_STARS = 1

-- The catalog. kind: Display · Checkout · Decor · Wall. size = { across,
-- deep } in cells (a wall item: cells along the wall). Displays: slots ×
-- units each, the rarities they hold, and `present`: what shoppers will pay
-- there (× their willingness). Checkouts: seconds per shopper (`serve`);
-- `staffed`: only while you (or a Cashier, week 4) stand behind it. flat:
-- shoppers walk over it. level: the Store Level that unlocks buying it.
Store.ITEMS = {
	-- Displays
	ProduceCrate = { kind = "Display", name = "Produce Crate", size = { 1, 1 }, slots = 1, units = 12,
		rarities = { "Common", "Uncommon" }, present = 1.00, cost = 150, level = 1 },
	WoodenShelf = { kind = "Display", name = "Wooden Shelf", size = { 2, 1 }, slots = 2, units = 15,
		rarities = { "Common", "Uncommon", "Rare" }, present = 1.00, cost = 600, level = 1 },
	BulkBin = { kind = "Display", name = "Bulk Bin", size = { 1, 1 }, slots = 1, units = 40,
		rarities = { "Common" }, present = 0.95, cost = 900, level = 3 },
	TieredRack = { kind = "Display", name = "Tiered Produce Rack", size = { 2, 1 }, slots = 3, units = 15,
		rarities = { "Common", "Uncommon", "Rare" }, present = 1.05, cost = 2_500, level = 5, charm = 1 },
	ChillerCabinet = { kind = "Display", name = "Chiller Cabinet", size = { 2, 1 }, slots = 2, units = 12,
		rarities = { "Uncommon", "Rare", "Epic" }, present = 1.10, cost = 8_000, level = 8 },
	GlassShowcase = { kind = "Display", name = "Glass Showcase", size = { 1, 1 }, slots = 1, units = 4,
		rarities = { "Rare", "Epic", "Legendary", "Mythic" }, present = 1.15, cost = 25_000, level = 10, charm = 2 },
	VelvetPedestal = { kind = "Display", name = "Velvet Pedestal", size = { 1, 1 }, slots = 1, units = 1,
		rarities = { "Legendary", "Mythic" }, present = 1.25, cost = 120_000, level = 15, charm = 4 },

	-- Checkouts
	HonourBox = { kind = "Checkout", name = "Honour Box", size = { 1, 1 }, serve = 6, cost = 500, level = 1 },
	Register = { kind = "Checkout", name = "Register", size = { 2, 1 }, serve = 3, staffed = true, cost = 3_000, level = 3 },
	SelfCheckout = { kind = "Checkout", name = "Self-checkout", size = { 1, 1 }, serve = 4, cost = 60_000, level = 15 },

	-- Decor (Charm)
	PottedPlant = { kind = "Decor", name = "Potted Plant", size = { 1, 1 }, charm = 2, cost = 200, level = 1 },
	HayBaleSeat = { kind = "Decor", name = "Hay Bale Seat", size = { 1, 1 }, charm = 2, cost = 400, level = 1 },
	FlowerBarrel = { kind = "Decor", name = "Flower Barrel", size = { 1, 1 }, charm = 3, cost = 500, level = 2 },
	PumpkinPile = { kind = "Decor", name = "Pumpkin Pile", size = { 1, 1 }, charm = 3, cost = 800, level = 3 },
	LampPost = { kind = "Decor", name = "Lamp Post", size = { 1, 1 }, charm = 4, cost = 1_500, level = 5 },
	Rug = { kind = "Decor", name = "Rug", size = { 1, 1 }, charm = 3, cost = 1_200, level = 5, flat = true },
	FruitCart = { kind = "Decor", name = "Fruit Cart", size = { 2, 1 }, charm = 6, cost = 5_000, level = 6 },
	Bench = { kind = "Decor", name = "Bench", size = { 2, 1 }, charm = 4, cost = 2_500, level = 9 },
	Fountain = { kind = "Decor", name = "Fountain", size = { 2, 2 }, charm = 12, cost = 40_000, level = 10 },
	FlowerArch = { kind = "Decor", name = "Flower Arch", size = { 2, 1 }, charm = 10, cost = 30_000, level = 12 },
	GoldenScarecrow = { kind = "Decor", name = "Golden Scarecrow", size = { 1, 1 }, charm = 20, cost = 250_000, level = 17 },

	-- On the walls
	PaintedSign = { kind = "Wall", name = "Painted Sign", size = { 1, 1 }, charm = 3, cost = 1_000, level = 4 },
	ChalkBoard = { kind = "Wall", name = "Chalk Board", size = { 1, 1 }, charm = 3, cost = 600, level = 4 },
	Clock = { kind = "Wall", name = "Clock", size = { 1, 1 }, charm = 3, cost = 2_000, level = 4 },
	FairyLights = { kind = "Wall", name = "Fairy Lights", size = { 1, 1 }, charm = 5, cost = 3_000, level = 6 },
	Mural = { kind = "Wall", name = "Mural", size = { 2, 1 }, charm = 8, cost = 20_000, level = 9 },
	NeonSign = { kind = "Wall", name = "Neon Sign", size = { 1, 1 }, charm = 8, cost = 25_000, level = 12 },
}

-- The drawer's tabs, in order, and the order of cards in each.
Store.ORDER = {
	"ProduceCrate", "WoodenShelf", "BulkBin", "TieredRack", "ChillerCabinet", "GlassShowcase", "VelvetPedestal",
	"HonourBox", "Register", "SelfCheckout",
	"PottedPlant", "HayBaleSeat", "FlowerBarrel", "PumpkinPile", "LampPost", "Rug", "FruitCart", "Bench",
	"Fountain", "FlowerArch", "GoldenScarecrow",
	"PaintedSign", "ChalkBoard", "Clock", "FairyLights", "Mural", "NeonSign",
}

-- A new store's furniture (free, kept forever, can't be sold): the shelf
-- and crates along the back wall facing the door, a plant beside them, the
-- Honour Box in the corner by the door with its queue up the side wall, and
-- the middle of the floor left free for your first new things.
--   y=4  [Shelf  Shelf][Crate][Crate][Plant][  q  ]   (back wall)
--   y=3  [  aisle ............................][  q  ]
--   y=2  [staff][  .  ][  .  ][  .  ][  .  ][  q  ]
--   y=1  [  .  ][  .  ][door ][  .  ][  .  ][ Box ]
Store.START = {
	{ item = "WoodenShelf", x = 1, y = 4, rot = 0 },
	{ item = "ProduceCrate", x = 3, y = 4, rot = 0 },
	{ item = "ProduceCrate", x = 4, y = 4, rot = 0 },
	{ item = "PottedPlant", x = 5, y = 4, rot = 0 },
	{ item = "HonourBox", x = 6, y = 1, rot = 2 },
}

for id, item in Store.ITEMS do
	item.id = id
end

return Store
