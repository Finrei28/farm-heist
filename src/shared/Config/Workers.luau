-- Workers (docs/GameDesign.md §4.9, shared/WorkerRules). speed is per
-- minute at Level 10, in the station's own unit: field tiles harvested,
-- units sorted, crates packed or loaded, units shelved, shoppers served. A
-- worker at Level L works at efficiency(L) of it and is paid wagePart(L) of
-- wage (coins a minute).
-- slots: the levels that open each slot, of the Warehouse (warehouse) or
-- the Store (store); Shed Hands only work at the Packing Shed (before
-- `until`). Farmhands, Drivers and Cashiers have their own rules
-- (WorkerRules.slots). The Watchman comes with the defences (week 6).
return {
	TYPES = {
		Farmhand = { name = "Farmhand", station = "Field", wage = 10.5, speed = 30, job = "Harvests ripe crops and replants" },
		ShedHand = { name = "Shed Hand", station = "Shed", wage = 8.75, speed = 8, slots = { warehouse = { 1, 4 } }, untilLevel = 5,
			job = "Washes, packs and loads crates at the Packing Shed" },
		Sorter = { name = "Sorter", station = "Sort", wage = 8.75, speed = 60, slots = { warehouse = { 5, 8, 12, 18 } }, job = "Washes and grades crops" },
		Packer = { name = "Packer", station = "Pack", wage = 8.75, speed = 15, slots = { warehouse = { 5, 6, 10, 13, 16 } }, job = "Packs crates" },
		Loader = { name = "Loader", station = "Load", wage = 8.75, speed = 20, slots = { warehouse = { 5, 9, 15 } }, job = "Loads the trucks from the Cold Room" },
		Driver = { name = "Driver", station = "Truck", wage = 14, job = "Sends a truck by your rule; quicker trips with levels" }, -- 1 per truck, from Warehouse Level 5
		Stocker = { name = "Stocker", station = "Shelves", wage = 8.75, speed = 80, slots = { store = { 2, 8, 14 } }, job = "Fills your store's displays" },
		Cashier = { name = "Cashier", station = "Register", wage = 10.5, speed = 12, job = "Serves at a Register" }, -- 1 per Register
		Greeter = { name = "Greeter", station = "Door", wage = 8.75, slots = { store = { 8 } }, job = "Welcomes shoppers in: more shoppers" },
	},
	-- The order they're listed in (the Workers window, the Hiring Hall).
	ORDER = { "Farmhand", "ShedHand", "Sorter", "Packer", "Loader", "Driver", "Stocker", "Cashier", "Greeter" },
	TILES_PER_FARMHAND = 16,
	MAX_FARMHANDS = 4,
	DRIVERS_FROM = 5, -- Warehouse Level: the first Driver (1 per truck)

	-- Levels: efficiency 40% at Level 1 up to 100% at Level 10 (+6.7% a
	-- level); the wage from 60% to 100%, so a trained worker costs less per job.
	MAX_LEVEL = 10,
	EFFICIENCY_MIN = 0.4,
	WAGE_MIN = 0.6,
	-- Experience: XP_PER_MINUTE of real work (a crate moves on, a shopper is
	-- served), OFFLINE_RATE of it while you're away. A full bar waits for
	-- Train. XP to the next level = XP_BASE × XP_GROWTH^(Level − 1).
	XP_PER_MINUTE = 10,
	XP_BASE = 600,
	XP_GROWTH = 1.5,
	-- Training fee = TRAIN_BASE × (wage ÷ TRAIN_WAGE) × TRAIN_GROWTH^(Level − 1).
	TRAIN_BASE = 250,
	TRAIN_WAGE = 8.75,
	TRAIN_GROWTH = 1.9,

	-- Hiring: the board (the Hiring Hall, the Workers window) has BOARD_SIZE
	-- candidates per type, new every BOARD_SECONDS; each a level from
	-- HIRE_LEVELS (weights) and a trait. The fee is HIRE_FEE minutes of their
	-- wage; the first hire is free.
	BOARD_SIZE = 3,
	BOARD_SECONDS = 600,
	HIRE_LEVELS = { 0.6, 0.3, 0.1 },
	HIRE_FEE = 40,

	-- for: which jobs a trait comes on ("speed": jobs with a speed; "grade":
	-- jobs that grade crates; nil: any job). A Farmhand is never Careful.
	TRAITS = {
		Speedy = { name = "Speedy", speed = 1.2, text = "+20% speed", ["for"] = "speed" },
		Careful = { name = "Careful", gradeA = 0.1, text = "+10% grade A", ["for"] = "grade" },
		NightOwl = { name = "Night Owl", night = 1.3, text = "+30% at night", ["for"] = "speed" },
		Frugal = { name = "Frugal", wage = 0.8, text = "−20% wage" },
	},
	TRAIT_ORDER = { "Speedy", "Careful", "NightOwl", "Frugal" },

	-- A Sorter's chance of grade A (a Shed Hand's too): this at Level 1, plus
	-- this much a level (85% at Level 10), plus the Careful trait and the
	-- Wash Line; never more than GRADE_A_MAX. (By hand, the spray decides.)
	SORT_GRADE_A = 0.4,
	SORT_GRADE_A_LEVEL = 0.05,
	GRADE_A_MAX = 0.95,

	DRIVER_TRIP = 0.1, -- a Level 10 Driver's trips are this much shorter (none at Level 1)
	GREETER = 0.25, -- a Level 10 Greeter brings this many more shoppers (× efficiency)

	OFFLINE_RATE = 0.25, -- workers keep going at this speed (and wage, and XP) while you're away ...
	OFFLINE_CAP = 8 * 3600, -- ... for up to this long

	NAMES = {
		"Abe", "Bea", "Cal", "Dot", "Eli", "Fay", "Gus", "Hattie", "Ike", "June", "Kit", "Lou", "Mabel", "Ned", "Olive", "Pip",
		"Quinn", "Rosie", "Sam", "Tess", "Ugo", "Vera", "Wes", "Xena", "Yuri", "Zelda", "Arlo", "Birdie", "Clem", "Daisy",
		"Ezra", "Flo", "Hank", "Ivy", "Jed", "Lula", "Moss", "Nell", "Otis", "Pearl", "Rex", "Sadie", "Toby", "Wren",
	},
}
