-- The Cloverdale Auction House (docs/GameDesign.md §4.4, shared/AuctionRules).
return {
	INTERVAL = 8 * 60, -- an auction starts every 8 minutes on the clock
	LOTS = 5, -- (5 x 60 s, 10 s apart: about 6 minutes of the 8)
	LOT_SECONDS = 60,
	GAP = 10, -- seconds between lots
	WARNING = 60, -- the "auction starting" toast
	OPENING = 0.4, -- opening bid, as a share of the estimate (a seed's is Barley's price, so it always opens cheaper)
	MIN_RAISE = 0.05,
	-- Bids go up in steps that suit the lot: the opening and the quick bids
	-- round up to one, and a raise is at least one (so a 400-coin seed
	-- doesn't jump by 100s and its three quick bids aren't all the same)
	STEPS = { { below = 1_000, step = 10 }, { below = 10_000, step = 50 }, { step = 100 } },
	QUICK = { 0.05, 0.10, 0.25 },
	SNIPE = 10, -- a bid with less than this left puts the clock back to it

	-- What a lot can be, by weight (out of 100): the rarer, the less often
	-- (the user, 2026-11-04). A seed lot is one seed of a crop of that
	-- rarity, each crop of it as likely. Commons are always at Barley's, so
	-- never here.
	POOL = {
		{ kind = "Seed", rarity = "Uncommon", weight = 30 },
		{ kind = "Seed", rarity = "Rare", weight = 26 },
		{ kind = "Seed", rarity = "Epic", weight = 17 },
		{ kind = "Seed", rarity = "Legendary", weight = 7 },
		{ kind = "Seed", rarity = "Mythic", weight = 3 },
		{ kind = "WorkerContract", weight = 10 },
		{ kind = "Defence", weight = 7 },
	},
	ITEMS = { -- the lots that aren't seeds: what they're thought to be worth, and how often each comes (the rarer, the less)
		-- a rare worker (Config/Workers.CONTRACTS) who joins your crew
		WorkerContract = { { id = "SpeedySam", estimate = 90_000, weight = 2 }, { id = "GrandmaRose", estimate = 200_000, weight = 1 } },
		-- a defence for your barn, at its price in the Defences window
		-- (you still need its Farm Level, and room for one more)
		Defence = {
			{ id = "Cloche", estimate = 30_000, weight = 3 },
			{ id = "GuardDog", estimate = 600_000, weight = 2 },
			{ id = "Camera", estimate = 800_000, weight = 1 },
		},
	},

	-- Inside the hall (World/AuctionArt), the only place you can bid from:
	-- the room's floor, this far in from its walls.
	HALL_MARGIN = 1.5,
	-- (what Goldie Gavel says, by paddle number: AuctionRules.patter)
}
