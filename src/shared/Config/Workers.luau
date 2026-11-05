-- Workers (docs/GameDesign.md §4.9, shared/WorkerRules). speed is per
-- minute at Level 10, in the station's own unit: field tiles harvested,
-- patches' worth sorted (a patch of carrots is 6 carrots, of pumpkins 1
-- pumpkin: shared/CrateRules.patches), crates packed or loaded, patches'
-- worth shelved, shoppers served. A
-- worker at Level L works at efficiency(L) of it and is paid wagePart(L) of
-- wage (coins a minute).
-- slots: the levels that open each slot, of the Warehouse (warehouse),
-- the Store (store) or the farm (farm: Farm Level); Shed Hands only work at
-- the Packing Shed (before `until`). Farmhands, Drivers and Cashiers have
-- their own rules (WorkerRules.slots). The Watchman (§4.11, with the
-- defences, Farm Level 20) works in his gatehouse by the gate: when the
-- alarm goes off he rings the bell and follows the thief with his
-- spotlight; once they have the crop he shuts the gate on them
-- (shared/DefenceRules.watchmanShut). He never knocks anyone out.
return {
	TYPES = {
		Farmhand = { name = "Farmhand", station = "Field", wage = 105, speed = 30, job = "Harvests ripe crops and replants" },
		ShedHand = { name = "Shed Hand", station = "Shed", wage = 87.5, speed = 8, slots = { warehouse = { 1, 4 } }, untilLevel = 5,
			job = "Washes, packs and loads crates at the Packing Shed" },
		Sorter = { name = "Sorter", station = "Sort", wage = 87.5, speed = 60, slots = { warehouse = { 5, 8, 12, 18 } }, job = "Washes and grades crops" },
		Packer = { name = "Packer", station = "Pack", wage = 87.5, speed = 15, slots = { warehouse = { 5, 6, 10, 13, 16 } }, job = "Packs crates" },
		Loader = { name = "Loader", station = "Load", wage = 87.5, speed = 20, slots = { warehouse = { 5, 9, 15 } }, job = "Loads the crates routed to the trucks" },
		Driver = { name = "Driver", station = "Truck", wage = 140, job = "Sends a truck by your rule; quicker trips with levels" }, -- 1 per truck, from Warehouse Level 5
		Stocker = { name = "Stocker", station = "Shelves", wage = 87.5, speed = 80, slots = { store = { 2, 8, 14 } }, job = "Fills your store's displays" },
		Cashier = { name = "Cashier", station = "Register", wage = 105, speed = 12, job = "Serves shoppers at the tills" }, -- 1 per till (Counter or Register), from Store Level CASHIERS_FROM; a free one walks to a till nobody's at
		Greeter = { name = "Greeter", station = "Door", wage = 87.5, slots = { store = { 8 } }, job = "Welcomes shoppers in: more shoppers" },
		Watchman = { name = "Watchman", station = "Gatehouse", wage = 175, slots = { farm = { 20 } },
			job = "Rings the bell on thieves, lights them up and shuts the gate on them" },
	},
	-- The order they're listed in (the Workers window, the Hiring Hall).
	ORDER = { "Farmhand", "ShedHand", "Sorter", "Packer", "Loader", "Driver", "Stocker", "Cashier", "Greeter", "Watchman" },
	TILES_PER_FARMHAND = 16,
	MAX_FARMHANDS = 4,
	DRIVERS_FROM = 5, -- Warehouse Level: the first Driver (1 per truck)
	CASHIERS_FROM = 3, -- Store Level: Cashiers (1 per till); till then you serve your shoppers yourself

	-- Levels: efficiency 40% at Level 1 up to 100% at Level 10 (+6.7% a
	-- level); the wage from 60% to 100%, so a trained worker costs less per job.
	MAX_LEVEL = 10,
	EFFICIENCY_MIN = 0.4,
	WALK = 10, -- studs a second, a worker's walk
	-- A Farmhand's pace at Level 1 and at the top level (WorkerRules.walkSpeed,
	-- 2 more a level). It's a race with thieves for ripe crops: a new one is
	-- slower than a thief with their hands full, Level 5 matches a player
	-- walking (Config/Settings.WALK_SPEED), Level 9 one running (RUN_SPEED),
	-- and at the top they outpace a running thief (the user, 2026-11-05).
	FARMHAND_WALK = { 8, 26 },
	WAGE_MIN = 0.6,
	-- Experience: XP_PER_MINUTE of real work (a crate moves on, a shopper is
	-- served), OFFLINE_RATE of it while you're away. A full bar waits for
	-- Train. XP to the next level = XP_BASE × XP_GROWTH^(Level − 1).
	XP_PER_MINUTE = 10,
	XP_BASE = 600,
	XP_GROWTH = 1.5,
	-- Training fee = TRAIN_BASE × (wage ÷ TRAIN_WAGE) × TRAIN_GROWTH^(Level − 1).
	TRAIN_BASE = 2_500,
	TRAIN_WAGE = 87.5,
	TRAIN_GROWTH = 1.9,

	-- Hiring: the board (the Hiring Hall, the Workers window) has BOARD_SIZE
	-- candidates per type, new every BOARD_SECONDS; each a level from
	-- HIRE_LEVELS (weights) and a trait. The fee is HIRE_FEE minutes of their
	-- wage; the first hire has no fee (only the wage).
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
		-- only rare workers, from auction contracts (not on the board):
		Tireless = { name = "Tireless", away = 2, text = "works at 50% while you're away, not 25%" },
	},
	TRAIT_ORDER = { "Speedy", "Careful", "NightOwl", "Frugal" }, -- (the hiring board's: Tireless isn't one)

	-- Rare workers (§4.9), won at the Auction House (Config/Auction): they
	-- join your crew at their level with their own trait, if you have a free
	-- slot for their job when you bid.
	CONTRACTS = {
		GrandmaRose = { name = "Grandma Rose", title = "Legendary Packer", type = "Packer", level = 8, trait = "Tireless", look = 7 },
		SpeedySam = { name = "Speedy Sam", title = "Rare Farmhand", type = "Farmhand", level = 7, trait = "Speedy", look = 4 },
	},

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
