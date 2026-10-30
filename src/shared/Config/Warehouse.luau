-- The Distribution Warehouse tiers (docs/GameDesign.md §4.6). Crates per
-- rarity are in Config/Rarities (`crate`). Index 1 = T0.
return {
	GRADE_A = 1.15, -- value of a grade A batch
	TIERS = {
		{ id = "PackingShed", name = "Packing Shed", cost = 0, level = 1, buildSeconds = 0,
			trucks = 1, truckCrates = 4, roundTrip = 60, premium = 0 },
		{ id = "Warehouse", name = "Distribution Warehouse", cost = 5_000, level = 5, buildSeconds = 120,
			trucks = 1, truckCrates = 12, roundTrip = 90, premium = 0 },
		{ id = "BigWarehouse", name = "Big Warehouse", cost = 40_000, level = 12, buildSeconds = 300,
			trucks = 2, truckCrates = 30, roundTrip = 120, premium = 0 },
		{ id = "DistributionCenter", name = "Distribution Center", cost = 200_000, level = 20, buildSeconds = 600,
			trucks = 2, truckCrates = 40, roundTrip = 100, premium = 0.10 }, -- premium: Legendary and Mythic crates
	},
}
