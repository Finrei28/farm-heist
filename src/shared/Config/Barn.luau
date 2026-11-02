-- The Barn: your crop inventory (docs/GameDesign.md §4.5, shared/BarnRules).
return {
	-- Crops it holds (carrots, pumpkins, punnets ...: about 200 patches' worth
	-- at the start), by Silo upgrades bought (data.silo: 0 = none).
	CAPACITY = { [0] = 1_200, [1] = 3_000, [2] = 9_000, [3] = 30_000 },
	SILO_COST = { 20_000, 200_000, 1_200_000 }, -- the 1st, 2nd and 3rd Silo upgrade
}
