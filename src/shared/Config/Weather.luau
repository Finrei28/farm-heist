-- Day, night and the weather (docs/GameDesign.md §4.14, shared/WeatherRules).
-- Worked out from the time, so every server and every player has the same
-- sky (like Barley's restocks).
return {
	DAY = 24 * 60, -- one Cloverdale day: 16 minutes of daylight, then 8 of night
	NIGHT = 8 * 60,
	SLOT = 4 * 60, -- the weather can change every 4 minutes (6 a day: 4 by day, 2 by night)
	ROLL = 30, -- seconds between mutation rolls on ripe crops left in the field
	WARNING = 5 * 60, -- the Harvest Moon's warning

	-- growth: × crop growth while it's on (online only); mutation and
	-- chance: what a ripe crop left in the field can turn into on each roll;
	-- odds: the chance a 4-minute slot has it (FrostNight: night slots only,
	-- GoldenHour: the last daylight slot, its final 3 minutes); length: how
	-- long it lasts in its slot.
	TYPES = {
		Clear = { name = "Clear", icon = "☀️", growth = 1 },
		Rain = { name = "Rain", icon = "🌧️", growth = 1.5, mutation = "Wet", chance = 0.03, odds = 0.22, length = 240 },
		Thunderstorm = { name = "Thunderstorm", icon = "⛈️", growth = 1.5, mutation = "Shocked", chance = 0.015, odds = 0.12, length = 180 },
		FrostNight = { name = "Frost Night", icon = "❄️", growth = 0.75, mutation = "Frosted", chance = 0.02, odds = 0.21, length = 240, night = true },
		GoldenHour = { name = "Golden Hour", icon = "🌇", growth = 1, mutation = "Golden", chance = 0.05, odds = 0.56, length = 180, dusk = true },
		HarvestMoon = { name = "Harvest Moon", icon = "🌕", growth = 2, mutation = "Moonlit", chance = 0.02, length = 360 },
	},
	-- Any weather (each roll, after the weather's own): Golden Hour's 5%
	-- Golden replaces the usual 0.5%.
	ANY = {
		{ mutation = "Golden", chance = 0.005 },
		{ mutation = "Rainbow", chance = 0.0005 },
	},
	-- × value, the aura's colour, and its name's colour on a cream card (the
	-- aura's are too pale to read there: client/CropNames).
	MUTATIONS = {
		Wet = { value = 1.3, color = Color3.fromRGB(90, 170, 240), text = Color3.fromHex("1667C4") },
		Frosted = { value = 2.5, color = Color3.fromRGB(190, 235, 255), text = Color3.fromHex("0A8FA6") },
		Golden = { value = 2, color = Color3.fromRGB(255, 200, 40), text = Color3.fromHex("B87A00") },
		Shocked = { value = 3, color = Color3.fromRGB(250, 240, 90), text = Color3.fromHex("D9480F") },
		Moonlit = { value = 5, color = Color3.fromRGB(190, 120, 255), text = Color3.fromHex("7B3FE4") },
		Rainbow = { value = 8, color = Color3.fromRGB(255, 120, 200), text = Color3.fromHex("D6249F") },
	},
	MUTATION_ORDER = { "Wet", "Golden", "Frosted", "Shocked", "Moonlit", "Rainbow" },
	GIANT_TEXT = Color3.fromHex("2E8B3D"), -- (a Giant crop's name, as `text` above)

	-- The Harvest Moon: at these hours (UTC) every day, the sky turns to night
	-- for it whatever the time of day. Heist Night: steal holds are quicker
	-- (Crime.HARVEST_MOON_HOLD).
	HARVEST_MOON = { hours = { 1, 12, 19 } },
}
