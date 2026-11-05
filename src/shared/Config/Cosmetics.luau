-- Looks bought with Robux (docs/GameDesign.md §7): never power. A skinned
-- bat swings, reaches and bonks exactly like the plain one; a paint is
-- only a colour. Each one with a price is a developer product
-- (Config/Monetization); `vip` ones come with the VIP pass instead.
--   kind     "bat" (CrimeArt.bat draws it) or "truck" (YardArt paints the
--            farm's trucks with it)
--   look     the bat: `shape`, what it's drawn as ("golden", "baguette",
--            "carrot": CrimeArt) in its two colours, `wood` and `dark`
--            a truck: body (the colour that was the farm's) and its material
--            (a Material's name; nil keeps the truck's own)
local Cosmetics = {}

Cosmetics.KINDS = {
	{ id = "bat", name = "Bat skins", none = "Classic Bat", noneIcon = "🏏", noneBlurb = "Ash wood and red grip tape: the bat every farmer gets." },
	{ id = "truck", name = "Truck paint", none = "Farm colours", noneIcon = "🚚", noneBlurb = "Your trucks in your farm's own colour." },
}

Cosmetics.LIST = {
	{
		id = "GoldenBat", kind = "bat", name = "Golden Bat", icon = "🏆", price = 149, productId = 3728392617,
		blurb = "Glowing gold, set with rubies. It sparkles, swings with a gold trail and bonks in a burst of gold.",
		-- (Neon brightens its colour a lot: this reads as gold on screen, anything lighter as lemon)
		look = { shape = "golden", wood = Color3.fromRGB(205, 112, 22), dark = Color3.fromRGB(150, 92, 18) },
	},
	{
		id = "Baguette", kind = "bat", name = "Baguette", icon = "🥖", price = 79, productId = 3728392650,
		blurb = "A long French loaf, crusty and scored. Thieves won't know what hit them.",
		look = { shape = "baguette", wood = Color3.fromRGB(214, 150, 78), dark = Color3.fromRGB(164, 100, 46) },
	},
	{
		id = "CarrotClub", kind = "bat", name = "Carrot Club", icon = "🥕", price = 79, productId = 3728392679,
		blurb = "A giant carrot, leafy top and all. Grown on your own farm, probably.",
		look = { shape = "carrot", wood = Color3.fromRGB(240, 128, 40), dark = Color3.fromRGB(206, 100, 28) },
	},
	{
		id = "CherryPaint", kind = "truck", name = "Cherry Red", icon = "🍒", price = 49, productId = 3728392725,
		blurb = "Shiny cherry red, like a farm truck from a picture book.",
		look = { body = Color3.fromRGB(196, 40, 52) },
	},
	{
		id = "MintPaint", kind = "truck", name = "Mint Green", icon = "🌿", price = 49, productId = 3728392753,
		blurb = "Soft mint green. Very ice-cream van.",
		look = { body = Color3.fromRGB(130, 210, 175) },
	},
	{
		id = "MidnightPaint", kind = "truck", name = "Midnight Blue", icon = "🌙", price = 49, productId = 3728392772,
		blurb = "Deep night blue, for farmers who deliver after dark.",
		look = { body = Color3.fromRGB(40, 56, 110) },
	},
	{
		id = "VIPGold", kind = "truck", name = "VIP Gold", icon = "⭐", vip = true,
		blurb = "Shiny gold paint for VIP farms (with the VIP pass).",
		look = { body = Color3.fromRGB(236, 168, 36) }, -- (warm gold: Metal turned it a dull olive in daylight, Studio check 2026-11-04)
	},
}

Cosmetics.ById = {}
for _, item in Cosmetics.LIST do
	Cosmetics.ById[item.id] = item
end

-- VIP's store awning (StoreArt), in place of the farm's colour.
Cosmetics.VIP_AWNING = Color3.fromRGB(232, 182, 50)

return Cosmetics
