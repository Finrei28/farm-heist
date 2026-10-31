-- Shoppers in your store (docs/GameDesign.md §4.8, shared/DemandModel,
-- shared/ShopRules). The store itself (grid, levels, catalog) is Config/Store.
return {
	-- Shoppers judge your price against ref = REF_BASE × base + (1 − REF_BASE) × market.
	REF_BASE = 0.5,
	-- Each shopper's willingness to pay is log-normal around 1 with this spread ...
	SIGMA = 0.2,
	-- ... times the rating bonus (0 at 1★ up to this at 5★) ...
	RATING_BONUS = 0.25,
	-- ... times the display's presentation (Config/Store) ... times this for grade A crops.
	GRADE_A = 1.15,
	PRICE_MIN = 0.5, -- allowed prices, as a share of the reference
	PRICE_MAX = 3.0,
	UNITS_PER_SHOPPER = 2.5, -- 1–4 units, on average
	RATING_WINDOW = 50, -- shoppers the rating averages over
	START_STARS = 3, -- a store nobody has visited yet ...
	RATING_SETTLE = 10, -- ... counts as this many 3★ shoppers until real ones replace them
	-- What each shopper adds to the rating (1–5): they bought; everything
	-- they looked at was too dear (or sold out by the time they got there);
	-- they gave up waiting in the queue. (A store with nothing on display is
	-- closed, so nobody comes to find it empty: a new farm doesn't sink to
	-- 1★ before its first harvest.)
	SCORE_BOUGHT = 5,
	SCORE_TOO_DEAR = 2,
	SCORE_LEFT_QUEUE = 1,

	-- How often shoppers come: every INTERVAL × INTERVAL_DECAY^(Store Level − 1)
	-- seconds at 3★ (20 s at Level 1, 4 s at 20), FLOW_PER_STAR more often for
	-- each star above 3 (less below), VARIETY more for each different crop on
	-- display after the first (up to VARIETY_MAX).
	INTERVAL = 20,
	INTERVAL_DECAY = 0.92,
	FLOW_PER_STAR = 0.15,
	VARIETY = 0.05,
	VARIETY_MAX = 0.25,
	-- (How many shoppers a store holds at once grows with its building: Config/Store.BUILDINGS.)

	-- The visit (StoreService; clients draw them from ShopperEvent).
	SPEED = 8, -- studs a second
	BROWSE = 2.5, -- seconds at each display
	QUEUE_LENGTH = 4, -- shoppers waiting at a checkout, besides the one paying
	PATIENCE = 20, -- seconds a shopper waits in a queue before putting their basket back
}
