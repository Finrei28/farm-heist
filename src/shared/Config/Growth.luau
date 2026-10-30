-- How crops grow (docs/GameDesign.md §4.2, shared/GrowthRules).
return {
	OFFLINE_RATE = 0.25, -- growth speed while the owner is offline
	WATER_CUT = 0.10, -- watering takes off this share of the time left in the stage (once per stage)
	FRESH_SOIL = 0.25, -- +25% growth for the first crop on newly cleared land
	SPRINKLER = 0.20, -- +20% in a sprinkler's area (online only)
}
