-- The Cloverdale Auction House (docs/GameDesign.md §4.4, shared/AuctionRules).
return {
	INTERVAL = 8 * 60, -- an auction starts every 8 minutes on the clock
	LOTS = 3,
	LOT_SECONDS = 60,
	GAP = 10, -- seconds between lots
	WARNING = 60, -- the "auction starting" toast
	OPENING = 0.4, -- opening bid, as a share of the estimate
	MIN_RAISE = 0.05,
	MIN_STEP = 100, -- coins
	ROUND_TO = 100, -- quick bids round up to this
	QUICK = { 0.05, 0.10, 0.25 },
	SNIPE = 10, -- a bid with less than this left puts the clock back to it

	-- What a lot can be, by weight.
	POOL = {
		{ kind = "Seed", rarity = "Epic", weight = 30 },
		{ kind = "Seed", rarity = "Legendary", weight = 20 },
		{ kind = "Seed", rarity = "Mythic", weight = 8 },
		{ kind = "GoldenTool", weight = 12 },
		{ kind = "WorkerContract", weight = 15 },
		{ kind = "Defence", weight = 10 },
		{ kind = "Cosmetic", weight = 5 },
	},
	ITEMS = { -- estimates for the lots that aren't seeds
		GoldenTool = { { id = "GoldenWateringCan", estimate = 80_000 }, { id = "GoldenHoe", estimate = 80_000 } },
		WorkerContract = { { id = "GrandmaRose", estimate = 200_000 }, { id = "SpeedySam", estimate = 90_000 } },
		Defence = { { id = "GuardDog", estimate = 60_000 }, { id = "SecurityCamera", estimate = 40_000 }, { id = "GlassCloche", estimate = 4_000 } },
		Cosmetic = { { id = "ScarecrowPumpkinKing", estimate = 50_000 }, { id = "TruckPaintHay", estimate = 30_000 } },
	},
}
