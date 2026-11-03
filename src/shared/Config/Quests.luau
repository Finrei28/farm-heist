-- Daily quests, the login streak and the Cropdex (docs/GameDesign.md
-- §4.15, §4.16; shared/QuestRules, server QuestService).
--
-- Quests: 3 a day (UTC days) from POOL, picked for you (the same all day,
-- whichever server). n and the reward grow with your Farm Level's tier
-- (TIERS: × scale on coins), so they matter all game. raids: only once your
-- Sprout Shield is over (you can steal and be stolen from); level: from that
-- Farm Level. stat: what counts toward it (QuestService.Bump).
return {
	SLOTS = 3,
	TIERS = { { from = 1, scale = 1 }, { from = 8, scale = 4 }, { from = 20, scale = 15 } },
	POOL = {
		{ id = "Harvest", stat = "harvest", n = { 30, 120, 400 }, reward = 2_000, one = "Harvest {n} crop", many = "Harvest {n} crops" },
		{ id = "Ship", stat = "crates", n = { 2, 5, 12 }, reward = 4_000, one = "Send a crate by truck", many = "Send {n} crates by truck" },
		{ id = "Store", stat = "storeCoins", n = { 1_500, 15_000, 120_000 }, reward = 4_000, one = "Earn {n} coin in your store", many = "Earn {n} coins in your store" },
		{ id = "Mutation", stat = "mutations", n = { 1, 2, 3 }, reward = 6_000, one = "Harvest a mutated crop", many = "Harvest {n} mutated crops" },
		{ id = "Arrest", stat = "arrests", n = { 1, 1, 2 }, reward = 8_000, raids = true, one = "Arrest a thief", many = "Arrest {n} thieves" },
		{ id = "Deposit", stat = "deposits", n = { 1, 2, 3 }, reward = 8_000, raids = true, one = "Take a stolen crop home", many = "Take {n} stolen crops home" },
		{ id = "Auction", stat = "auctions", n = { 1, 1, 2 }, reward = 10_000, level = 8, one = "Win an auction lot", many = "Win {n} auction lots" },
	},
	BONUS = 10_000, -- all three done and claimed (× scale)

	-- The 7-day login streak: one a day, claimed when you join; miss a day and
	-- it starts again at day 1; after day 7, day 1 again. Coins × scale.
	STREAK = {
		{ coins = 2_000 },
		{ seeds = { Corn = 3 } },
		{ coins = 5_000 },
		{ seeds = { Pumpkin = 1 } },
		{ coins = 10_000 },
		{ seeds = { Pineapple = 1 } },
		{ coins = 20_000, decor = "FlowerBarrel" }, -- (for your store: Decorate)
	},

	-- The Cropdex: every crop, plain and with each mutation. A new entry is
	-- worth XP; finding every crop of a rarity pays coins and a seed of the
	-- next rarity's cheapest crop (a Legendary set: a Mythic seed); every crop
	-- with one mutation is a badge and SET coins.
	CROPDEX_XP = 25,
	CROPDEX_TIER = { Common = 2_000, Uncommon = 8_000, Rare = 40_000, Epic = 150_000, Legendary = 600_000, Mythic = 2_000_000 },
	CROPDEX_SET = 100_000,
}
