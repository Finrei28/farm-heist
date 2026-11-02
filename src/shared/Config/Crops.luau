-- Every crop (docs/GameDesign.md §6.1). seed = Barley's price for one
-- seed, which plants a whole patch (for Mythics, the auction estimate:
-- Barley stocks them only 2% of restocks); grow = seconds to ripen online;
-- perPatch = how many a patch gives at Field Level 1 (a picking, for crops
-- that regrow), drawn on the ripe patch so you harvest what you see; value
-- = base market value of one of them; crate = how many fit in a crate
-- (12 patches' worth of a Common, 10 of an Uncommon, 6 of a Rare, 4 of an
-- Epic, 2 of a Legendary, 1 Mythic; a few rounded down to look like a real
-- crate); regrow = harvests after the first and the seconds between them;
-- unit = what one is called when it isn't the crop itself ({ one, many });
-- carry = how many a thief can hold up at once (nil: the whole patch).
-- Profit per tile-minute (shared/GrowthRules.profitPerMinute) rises with
-- rarity: tests/config.test.luau keeps it that way when numbers change.
local Crops = {}

local function crop(id, name, rarity, seed, grow, perPatch, value, crate, extra)
	local entry = { id = id, name = name, rarity = rarity, seed = seed, grow = grow, perPatch = perPatch, value = value, crate = crate }
	for key, v in extra or {} do
		entry[key] = v
	end
	return entry
end

Crops.List = {
	crop("Carrot", "Carrot", "Common", 100, 60, 6, 30, 72),
	crop("Wheat", "Wheat", "Common", 150, 90, 3, 90, 24, { unit = { "sheaf of wheat", "sheaves of wheat" } }),
	crop("Potato", "Potato", "Common", 250, 120, 10, 42, 100),
	crop("Lettuce", "Lettuce", "Common", 300, 150, 4, 130, 24),

	crop("Corn", "Corn", "Uncommon", 900, 300, 6, 240, 60, { unit = { "corn cob", "corn cobs" } }),
	crop("Onion", "Onion", "Uncommon", 1_100, 360, 7, 250, 70),
	crop("Strawberry", "Strawberry", "Uncommon", 1_200, 240, 4, 175, 24,
		{ unit = { "punnet of strawberries", "punnets of strawberries" }, regrow = { times = 3, seconds = 180 } }),
	crop("Tomato", "Tomato", "Uncommon", 1_500, 300, 6, 150, 60, { regrow = { times = 3, seconds = 240 } }),

	crop("BellPepper", "Bell Pepper", "Rare", 3_500, 720, 4, 1_300, 24),
	crop("Pumpkin", "Pumpkin", "Rare", 4_000, 900, 1, 6_100, 6, { carry = 1 }),
	crop("Watermelon", "Watermelon", "Rare", 5_500, 1200, 1, 8_300, 6, { carry = 1 }),
	crop("Blueberry", "Blueberry Bush", "Rare", 7_000, 720, 4, 650, 24,
		{ unit = { "punnet of blueberries", "punnets of blueberries" }, regrow = { times = 4, seconds = 480 } }),

	crop("Pineapple", "Pineapple", "Epic", 20_000, 2700, 2, 14_500, 8),
	crop("CocoaPod", "Cocoa Pod", "Epic", 24_000, 3000, 4, 8_500, 16),
	crop("Dragonfruit", "Dragonfruit", "Epic", 30_000, 3600, 3, 14_000, 12),
	crop("GrapeVine", "Grape Vine", "Epic", 40_000, 2700, 3, 5_000, 12,
		{ unit = { "bunch of grapes", "bunches of grapes" }, regrow = { times = 4, seconds = 1800 } }),

	crop("Moonmelon", "Moonmelon", "Legendary", 120_000, 7200, 1, 156_000, 2, { carry = 1 }),
	crop("Starfruit", "Starfruit", "Legendary", 150_000, 9000, 3, 65_000, 6),
	crop("GoldenApple", "Golden Apple Tree", "Legendary", 250_000, 7200, 5, 14_000, 10,
		{ unit = { "golden apple", "golden apples" }, regrow = { times = 5, seconds = 5400 } }),

	crop("CrystalRose", "Crystal Rose", "Mythic", 400_000, 21600, 1, 600_000, 1),
	crop("PhoenixPepper", "Phoenix Pepper", "Mythic", 420_000, 21600, 1, 640_000, 1),
	crop("DragonsEyePumpkin", "Dragon's Eye Pumpkin", "Mythic", 480_000, 21600, 1, 700_000, 1, { carry = 1 }),
}

-- What the HUD and windows show for each crop until there are 3D pictures
-- (emoji Roblox can draw: nothing newer than Unicode 12, so no 🫑 or 🫐).
local ICONS = {
	Carrot = "🥕", Wheat = "🌾", Potato = "🥔", Lettuce = "🥬",
	Corn = "🌽", Onion = "🧅", Strawberry = "🍓", Tomato = "🍅",
	BellPepper = "🌶️", Pumpkin = "🎃", Watermelon = "🍉", Blueberry = "🌳",
	Pineapple = "🍍", CocoaPod = "🍫", Dragonfruit = "🐉", GrapeVine = "🍇",
	Moonmelon = "🌕", Starfruit = "⭐", GoldenApple = "🍎",
	CrystalRose = "🌹", PhoenixPepper = "🔥", DragonsEyePumpkin = "👁️",
}

Crops.ById = {}
for _, entry in Crops.List do
	entry.icon = ICONS[entry.id]
	Crops.ById[entry.id] = entry
end

-- "6 carrots", "1 pumpkin", "4 punnets of strawberries" (lower case, for
-- sentences and tags).
function Crops.count(cropId: string, n: number): string
	local entry = Crops.ById[cropId]
	if entry.unit then
		return `{n} {entry.unit[if n == 1 then 1 else 2]}`
	end
	local name = string.lower(entry.name)
	if n == 1 then
		return `1 {name}`
	end
	return `{n} {name}{if string.sub(name, -1) == "o" then "es" else "s"}` -- (potatoes, tomatoes)
end

return Crops
