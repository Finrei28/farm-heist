-- Raids, knockouts, arrests and fines (docs/GameDesign.md §4.10–4.12;
-- shared/CrimeRules, shared/FineRules, shared/TravelRules).
return {
	-- Who can steal, from whom, and how much
	SHIELD_SECONDS = 45 * 60, -- Sprout Shield: your first 45 minutes of play
	ARRIVAL_GRACE = 120, -- seconds after joining a server
	SAME_FARM_COOLDOWN = 180, -- seconds before you can steal from a farm you just left with loot, or were arrested in
	RAID_CAP_WEIGHT = 10, -- the most sack weight a farm can lose ...
	RAID_WINDOW = 600, -- ... in this many seconds, to all thieves together
	SACK_CAPACITY = 5,
	SACK_SPEED = 0.85, -- walk speed with a sack (no sprinting)
	CLOCHE_HOLD = 2, -- steal holds take this many times longer under a Glass Cloche
	HARVEST_MOON_HOLD = 0.75, -- ... and this much as long on a Harvest Moon (Heist Night)

	DEPOSIT_RANGE = 12, -- studs from your own farmhouse door where your sack empties into your barn
	ALARM_GAP = 15, -- seconds between theft alarms about the same thief

	-- Climbing and the defences that slow thieves (§4.11)
	FENCE_CLIMB = 1.5, -- seconds over the back fence
	CLIMB_REACH = 4, -- studs from the back fence you can start climbing it, either side
	TALL_FENCE_CLIMB = 3.5, -- ... with the Tall Back Fence (3 s left an owner coming from town only 0.6 s: tools/raidrace)
	GATE_CLIMB = 2, -- over a locked gate
	DOG_SLOW = 0.4, -- the guard dog slows a thief by this much ...
	DOG_SLOW_SECONDS = 3, -- ... for this long ...
	DOG_COOLDOWN = 20, -- ... once per this many seconds

	-- Suspects
	SUSPECT_LINGER = 60, -- seconds a Suspect mark lasts after the last suspicious act

	-- The bat
	SWING_NEAR = 10, -- the context button says Swing when someone is this close
	SWING_COOLDOWN = 0.8,
	HIT_RANGE = 7,
	HIT_LAG = 1, -- extra studs allowed for latency
	HIT_ARC = 100, -- degrees, centred on where the owner faces ...
	HIT_CLOSE = 3, -- ... except within this many studs, where a swing reaches round you (play-test 2026-11-02)

	-- Knockouts and arrests
	KO_SECONDS = 5,
	IMMUNE_SECONDS = 6, -- after waking: hits only nudge
	ARREST_HOLD = 1,
	ARREST_RANGE = 8,
	CHASE_RANGE = 30, -- leaving while the owner is this close (with loot) counts as fleeing
	CHASE_SWING = 10, -- ... or within this many seconds of the owner swinging at you
	POLICE_PORCH_REJOIN = 120, -- rejoining this soon after an arrest starts on the police porch

	-- Fines (shared/FineRules)
	FINE_RATE = 0.08, -- of the thief's sales income in the last hour
	FLOOR_LOOT = 1.5, -- the fine is at least this many times the loot's market value ...
	FLOOR_MIN = 25, -- ... and never less than this
	REPEAT_WINDOW = 30 * 60,
	REPEAT = { 1, 1.5, 2 }, -- multiplier for the 1st, 2nd, 3rd-and-later arrest in the window
	FLEE = 1.5, -- extra multiplier for fleeing (quitting while knocked out, or while chased)
	EARN_BUCKET = 300, -- income is kept in 5-minute buckets ...
	EARN_BUCKETS = 12, -- ... for the last hour
	GARNISH = 0.5, -- share of income that goes to debts
	DEBT_EXPIRY = 7 * 86400,
	PAYOUT_BATCH = 300, -- debt payments to an owner in another server go out at most this often (one queue record each)
	PAYOUT_KEEP = 14 * 86400, -- unclaimed payout records (and claimed ids) are kept this long

	-- Boards and XP: staged arrests between friends don't count
	ARREST_XP = 50,
	BOARD_MIN_LOOT = 50,
	BOARD_PAIR_LIMIT = 3, -- arrests per thief–owner pair per UTC day
}
