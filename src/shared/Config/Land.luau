-- The field's land (docs/GameDesign.md §4.1b, shared/LandRules). The field is
-- an 8×8 grid of tiles, in 4×4 blocks of 2×2 tiles. Columns run from the
-- front (by the farmhouse, column 1) to the back fence (column 4); rows run
-- across. Block number = (row − 1) × 4 + column. The 4 start blocks are open;
-- the other 12 each need a Land Permit (earned at a Farm Level) and a
-- clearing fee, and must touch land already cleared.
return {
	GRID_TILES = 8,
	BLOCK_TILES = 2,
	BLOCKS_PER_SIDE = 4,
	START_BLOCKS = { 1, 2, 5, 6 }, -- the 4×4 corner by the farmhouse
	RISKY_FROM_COLUMN = 3, -- blocks this far back or more sit near the back fence, where raiders climb in

	-- In order: each permit is earned at its level; using the nth permit costs the nth fee.
	PERMITS = {
		{ level = 2, fee = 250 }, -- cheap: the Farm Guide ends by pointing at it
		{ level = 4, fee = 2_000 },
		{ level = 6, fee = 4_000 },
		{ level = 8, fee = 7_000 },
		{ level = 10, fee = 12_000 },
		{ level = 12, fee = 20_000 },
		{ level = 14, fee = 35_000 },
		{ level = 17, fee = 55_000 },
		{ level = 20, fee = 85_000 },
		{ level = 24, fee = 130_000 },
		{ level = 28, fee = 190_000 },
		{ level = 32, fee = 250_000 },
	},

	OBSTACLES = 4, -- a stump, a rock, weeds, a bush
	OBSTACLE_HOLD = 2, -- seconds per obstacle by hand
	FARMHAND_CLEAR_SECONDS = 30,
}
