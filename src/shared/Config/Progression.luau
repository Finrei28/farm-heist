-- Farm Level and XP (docs/GameDesign.md §4.15, shared/ProgressionRules).
-- Levels gate seeds, buildings, defences, workers and Land Permits, so they
-- only come from playing: nothing earns XP while you're offline.
-- Tuned with `lune run tools/progression` (§4.1b pacing targets).
return {
	MAX_LEVEL = 50,

	-- Total XP to reach level L = XP_BASE × (L − 1) ^ XP_POWER (Lv 2 = 60 XP).
	XP_BASE = 60,
	XP_POWER = 2.65, -- the daily player (1.5 h a day): Lv 12 on day 3, Lv 32 (the full 8×8) on day 23

	-- Harvest XP per minute the crop grew, by rarity: rarer crops pay a
	-- little more per minute of field time, so XP per tile-minute rises
	-- gently with rarity instead of favouring 1-minute Carrots.
	HARVEST_XP_PER_MINUTE = {
		Common = 3,
		Uncommon = 3.6,
		Rare = 4,
		Epic = 4.5,
		Legendary = 5,
		Mythic = 5.5,
	},
	WORKER_HARVEST = 0.5, -- a Farmhand's harvest (while you're online) gives this share

	SALES_COINS_PER_XP = 50, -- truck and shop sales while you're online
	ARREST_XP = 50, -- only arrests that count for the Sheriff board (CrimeRules.countsForBoard)
	CROPDEX_XP = 25, -- each new Cropdex entry

	GUIDE_COINS = 300, -- the Farm Guide's reward
}
