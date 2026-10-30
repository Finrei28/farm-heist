-- The Barn: your crop inventory (docs/GameDesign.md §4.5, shared/BarnRules).
return {
	-- Crop units it holds, by Silo upgrades bought (data.silo: 0 = none).
	CAPACITY = { [0] = 200, [1] = 500, [2] = 1_500, [3] = 5_000 },
	SILO_COST = { 2_000, 20_000, 120_000 }, -- the 1st, 2nd and 3rd Silo upgrade
}
