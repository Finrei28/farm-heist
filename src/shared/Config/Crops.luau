-- Every crop (docs/GameDesign.md §6.1). seed = Barley's price (for Mythics,
-- the auction estimate: Barley stocks them only 2% of restocks); grow =
-- seconds to ripen online; value = base market value of one unit; regrow =
-- harvests after the first and the seconds between them. Profit per
-- tile-minute (shared/GrowthRules.profitPerMinute) rises with rarity:
-- tests/config.test.luau keeps it that way when numbers change.
local Crops = {}

local function crop(id, name, rarity, seed, grow, value, regrow)
	return { id = id, name = name, rarity = rarity, seed = seed, grow = grow, value = value, regrow = regrow }
end

Crops.List = {
	crop("Carrot", "Carrot", "Common", 10, 60, 18),
	crop("Wheat", "Wheat", "Common", 15, 90, 27),
	crop("Potato", "Potato", "Common", 25, 120, 42),
	crop("Lettuce", "Lettuce", "Common", 30, 150, 52),

	crop("Corn", "Corn", "Uncommon", 90, 300, 145),
	crop("Onion", "Onion", "Uncommon", 110, 360, 175),
	crop("Strawberry", "Strawberry", "Uncommon", 120, 240, 70, { times = 3, seconds = 180 }),
	crop("Tomato", "Tomato", "Uncommon", 150, 300, 90, { times = 3, seconds = 240 }),

	crop("BellPepper", "Bell Pepper", "Rare", 350, 720, 520),
	crop("Pumpkin", "Pumpkin", "Rare", 400, 900, 610),
	crop("Watermelon", "Watermelon", "Rare", 550, 1200, 830),
	crop("Blueberry", "Blueberry Bush", "Rare", 700, 720, 260, { times = 4, seconds = 480 }),

	crop("Pineapple", "Pineapple", "Epic", 2000, 2700, 2900),
	crop("CocoaPod", "Cocoa Pod", "Epic", 2400, 3000, 3400),
	crop("Dragonfruit", "Dragonfruit", "Epic", 3000, 3600, 4200),
	crop("GrapeVine", "Grape Vine", "Epic", 4000, 2700, 1500, { times = 4, seconds = 1800 }),

	crop("Moonmelon", "Moonmelon", "Legendary", 12000, 7200, 15600),
	crop("Starfruit", "Starfruit", "Legendary", 15000, 9000, 19500),
	crop("GoldenApple", "Golden Apple Tree", "Legendary", 25000, 7200, 7000, { times = 5, seconds = 5400 }),

	crop("CrystalRose", "Crystal Rose", "Mythic", 40000, 21600, 60000),
	crop("PhoenixPepper", "Phoenix Pepper", "Mythic", 42000, 21600, 64000),
	crop("DragonsEyePumpkin", "Dragon's Eye Pumpkin", "Mythic", 48000, 21600, 70000),
}

Crops.ById = {}
for _, entry in Crops.List do
	Crops.ById[entry.id] = entry
end

return Crops
