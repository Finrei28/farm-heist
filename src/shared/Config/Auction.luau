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

	-- What a lot can be, by weight (out of 100). A seed lot is one seed of a
	-- crop of that rarity. Golden tools and cosmetics come with the
	-- cosmetics (week 9): until then their share is spread over the rest,
	-- Mythic seeds keeping their 8%.
	POOL = {
		{ kind = "Seed", rarity = "Epic", weight = 37 },
		{ kind = "Seed", rarity = "Legendary", weight = 25 },
		{ kind = "Seed", rarity = "Mythic", weight = 8 },
		{ kind = "WorkerContract", weight = 18 },
		{ kind = "Defence", weight = 12 },
	},
	ITEMS = { -- the lots that aren't seeds, and what they're thought to be worth
		-- a rare worker (Config/Workers.CONTRACTS) who joins your crew
		WorkerContract = { { id = "GrandmaRose", estimate = 200_000 }, { id = "SpeedySam", estimate = 90_000 } },
		-- a defence for your barn, at its price in the Defences window
		-- (you still need its Farm Level, and room for one more)
		Defence = { { id = "GuardDog", estimate = 600_000 }, { id = "Camera", estimate = 800_000 }, { id = "Cloche", estimate = 30_000 } },
	},

	-- Inside the hall (World/AuctionArt), the only place you can bid from:
	-- the room's floor, this far in from its walls.
	HALL_MARGIN = 1.5,
	CALLS = { "Going once...", "Going twice...", "SOLD" }, -- Goldie Gavel, in the last seconds
}
