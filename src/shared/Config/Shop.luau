-- Your own shop (docs/GameDesign.md §4.8, shared/DemandModel).
return {
	-- Shoppers judge your price against ref = REF_BASE × base + (1 − REF_BASE) × market.
	REF_BASE = 0.5,
	-- Each shopper's willingness to pay is log-normal around 1 with this spread ...
	SIGMA = 0.2,
	-- ... times the rating bonus (0 at 1★ up to this at 5★) ...
	RATING_BONUS = 0.25,
	-- ... times this for grade A crops.
	GRADE_A = 1.15,
	PRICE_MIN = 0.5, -- allowed prices, as a share of the reference
	PRICE_MAX = 3.0,
	UNITS_PER_SHOPPER = 2.5, -- 1–4 units, on average
	PATIENCE = 20, -- seconds a shopper waits at the register
	RATING_WINDOW = 50, -- shoppers the rating averages over
	FLOW_PER_STAR = 0.15, -- shoppers come this much more often per star above 3 (less below)

	TIERS = { -- index 1 = T0; interval = seconds between shoppers at 3★
		{ id = "FarmStand", name = "Farm Stand", cost = 0, level = 1, shelves = 2, shelfUnits = 20, registers = 0, interval = 20 },
		{ id = "FarmShop", name = "Farm Shop", cost = 2_500, level = 3, shelves = 6, shelfUnits = 20, registers = 1, interval = 12 },
		{ id = "MarketHall", name = "Market Hall", cost = 25_000, level = 10, shelves = 12, shelfUnits = 20, registers = 2, interval = 8 },
		{ id = "Supermarket", name = "Supermarket", cost = 150_000, level = 18, shelves = 20, shelfUnits = 20, registers = 2, interval = 5.2 },
	},
}
