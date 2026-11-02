-- Tunable gameplay constants shared by the server and the client.
return {
	WALK_SPEED = 16, -- Roblox default
	RUN_SPEED = 24, -- hold Shift (or tap Run on mobile); carrying a stolen crop stops sprinting (Config/Crime)

	-- What a brand-new save starts with (docs/GameDesign.md §4.1).
	START_COINS = 1_000,
	START_SEEDS = { Carrot = 5 },

	-- Saves live in a ProfileStore (session-locked; autosaves every 5 minutes
	-- and on leave). v2: coins ×10 and crops counted one by one (2026-11-02,
	-- before launch: test saves from v1 start over).
	PROFILE_STORE_NAME = "FarmHeist_Profiles_v2",
}
