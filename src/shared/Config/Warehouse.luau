-- The warehouse (docs/GameDesign.md §4.6): Warehouse Levels 1–20 inside 4
-- buildings, its trucks, and the hand wash. Crates per rarity are in
-- Config/Rarities (`crate`). Each level lists only what it changes;
-- shared/WarehouseRules.level adds them up (and says what's new). Worker
-- slots by level are in Config/Workers.
return {
	GRADE_A = 1.15, -- value of a grade A batch
	-- Washing by hand (a bench at the Packing Shed, the wash table in the
	-- warehouses: one hold washes and packs a crate): hold to spray, and the
	-- meter fills in `fill` seconds. Let go with it in the green
	-- (greenMin–greenMax of full) for grade A. The server times the hold
	-- itself and allows `slack` seconds either side for lag.
	WASH = { fill = 1.6, greenMin = 0.6, greenMax = 0.85, slack = 0.08 },

	-- Index = building stage. from: the level it comes with. buildSeconds:
	-- how long it takes to put up (online; a quarter as fast while you're
	-- away, like growth); the old building works until it's done. truck: the
	-- model at its docks. enclosed: walls and a roof (see-through from
	-- inside, like the stores).
	BUILDINGS = {
		{ id = "PackingShed", name = "Packing Shed", from = 1, buildSeconds = 0, truck = "Pickup" },
		{ id = "Warehouse", name = "Distribution Warehouse", from = 5, buildSeconds = 120, truck = "BoxTruck", enclosed = true },
		{ id = "BigWarehouse", name = "Big Warehouse", from = 10, buildSeconds = 300, truck = "Semi", enclosed = true },
		{ id = "DistributionCenter", name = "Distribution Center", from = 15, buildSeconds = 600, truck = "Reefer", enclosed = true },
	},
	TRUCK_NAMES = { Pickup = "Pickup", BoxTruck = "Box Truck", Semi = "Semi", Reefer = "Reefer" },

	-- Warehouse Levels: what each one changes.
	--   trucks, truckCrates, roundTrip (s): the trucks
	--   hold: crates waiting for a truck (the dock rack at the Packing Shed,
	--         the Cold Room from Level 5); a crate you set down always fits
	--   conveyors: worker speed at the Sort, Pack and Load stations ×
	--   handCart: you load up to HAND_CART crates at a time
	--   splits: a crop's route can be split between the truck and the store
	--   washLine: Sorters' grade A chance + WASH_LINE
	--   premium: Legendary and Mythic crates sell for this much more by truck
	--   express: the express lane (the trip below)
	--   goldTrim: gold trim on the building
	LEVELS = {
		{ cost = 0, farmLevel = 1, trucks = 1, truckCrates = 4, roundTrip = 60, hold = 6, conveyors = 1 },
		{ cost = 800, farmLevel = 2, truckCrates = 5 },
		{ cost = 2_000, farmLevel = 3, roundTrip = 50, hold = 10 },
		{ cost = 3_500, farmLevel = 4, truckCrates = 6 },
		{ cost = 8_000, farmLevel = 5, truckCrates = 12, roundTrip = 90, hold = 20, handCart = true, splits = true },
		{ cost = 12_000, farmLevel = 6, truckCrates = 14 },
		{ cost = 18_000, farmLevel = 7, conveyors = 1.1, hold = 30 },
		{ cost = 26_000, farmLevel = 8, roundTrip = 75 },
		{ cost = 36_000, farmLevel = 10, truckCrates = 16 },
		{ cost = 60_000, farmLevel = 12, trucks = 2, truckCrates = 24, roundTrip = 120, hold = 50 },
		{ cost = 80_000, farmLevel = 13, truckCrates = 26 },
		{ cost = 105_000, farmLevel = 14, conveyors = 1.2, washLine = true },
		{ cost = 135_000, farmLevel = 16, truckCrates = 28, hold = 70 },
		{ cost = 175_000, farmLevel = 18, truckCrates = 30, roundTrip = 110 },
		{ cost = 250_000, farmLevel = 20, truckCrates = 34, roundTrip = 100, premium = 0.10, conveyors = 1.35, hold = 100 },
		{ cost = 340_000, farmLevel = 22 },
		{ cost = 450_000, farmLevel = 24, truckCrates = 38 },
		{ cost = 600_000, farmLevel = 26, roundTrip = 80, express = true },
		{ cost = 780_000, farmLevel = 28, truckCrates = 40, conveyors = 1.5, hold = 150 },
		{ cost = 1_000_000, farmLevel = 30, trucks = 3, goldTrim = true },
	},
	HAND_CART = 4,
	WASH_LINE = 0.05,
}
