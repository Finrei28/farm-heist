-- Workers (docs/GameDesign.md §4.9, shared/WorkerRules). speed is per minute
-- at level 1, in the station's own unit: field tiles harvested, units
-- sorted, crates packed or loaded, units shelved, shoppers served.
-- caps[i] = slots at building tier i − 1 (the warehouse tier for warehouse
-- workers, the shop tier for shop workers).
return {
	TYPES = {
		Farmhand = { station = "Field", wage = 6, speed = 15 }, -- cap: 1 per 16 open tiles, up to 4
		ShedHand = { station = "Shed", wage = 5, speed = 4, caps = { 1, 0, 0, 0 } }, -- sorts, packs and loads at T0
		Sorter = { station = "Sort", wage = 5, speed = 30, caps = { 0, 1, 2, 3 } },
		Packer = { station = "Pack", wage = 5, speed = 7.5, caps = { 0, 2, 3, 4 } },
		Loader = { station = "Load", wage = 5, speed = 10, caps = { 0, 1, 2, 2 } },
		Driver = { station = "Truck", wage = 8, caps = { 0, 1, 2, 2 } }, -- 1 per truck
		Stocker = { station = "Shelves", wage = 5, speed = 40, caps = { 0, 1, 2, 3 }, shop = true },
		Cashier = { station = "Register", wage = 6, speed = 6, caps = { 0, 1, 2, 2 }, shop = true }, -- 1 per register
		Watchman = { station = "Gatehouse", wage = 10, level = 8 },
	},
	TILES_PER_FARMHAND = 16,
	MAX_FARMHANDS = 4,

	MAX_LEVEL = 5,
	LEVEL_SPEED = 1.2, -- each level multiplies speed by this ...
	LEVEL_WAGE = 1.15, -- ... and the wage by this
	HIRE_FEE = 40, -- minutes of wages
	TRAIN_FEE = 60, -- minutes of the current wage, per level trained

	TRAITS = {
		Speedy = { speed = 1.2 },
		Careful = { gradeA = 0.15 },
		NightOwl = { night = 1.3 },
		Frugal = { wage = 0.8 },
	},

	-- A Sorter's chance of grade A: this, plus this much per level above 1,
	-- plus the Careful trait. (By hand, the spray minigame decides.)
	SORT_GRADE_A = 0.4,
	SORT_GRADE_A_LEVEL = 0.08,

	OFFLINE_RATE = 0.25, -- workers keep going at this speed (and wage) while you're away ...
	OFFLINE_CAP = 8 * 3600, -- ... for up to this long
}
