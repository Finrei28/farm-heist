-- The global market price for truck sales (docs/GameDesign.md §4.7,
-- shared/MarketPrice):
--   price = base × wave(t) × event(t) × supply, clamped to 0.5–2 × base.
return {
	-- Two slow waves per crop, the same on every server (phases come from a
	-- hash of the crop id): together 0.8–1.2.
	WAVES = {
		{ amp = 0.12, period = 45 * 60 },
		{ amp = 0.08, period = 3 * 3600 },
	},

	-- Each hour (from the hour index, so every server agrees) one crop is Hot
	-- and another is in a Glut, at fixed minutes past the hour.
	HOT = { mult = 1.5, start = 10 * 60, length = 15 * 60 },
	GLUT = { mult = 0.75, start = 40 * 60, length = 15 * 60 },
	ANNOUNCE_AHEAD = 120,

	CLAMP_MIN = 0.5,
	CLAMP_MAX = 2.0,

	-- Player-driven supply: units sold to the market by every server in a
	-- 10-minute window (MemoryStore counters, sharded). Selling `expected`
	-- units in a window takes 12% off; selling more takes more, down to 30%.
	SUPPLY_WINDOW = 600,
	SUPPLY_SLOPE = 0.12,
	SUPPLY_MIN = 0.7,
	EXPECTED = { -- units per window, by rarity (tune with live data)
		Common = 2000,
		Uncommon = 800,
		Rare = 300,
		Epic = 80,
		Legendary = 20,
		Mythic = 3,
	},
}
