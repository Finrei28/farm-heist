-- What each job wears (docs/ArtDirection.md §8): the NPCs on your farm
-- (WorkerController, built by client/People on the shoppers' body) and the
-- photos on their ID badges (WorkersController).
--   shirt: the shirt and its sleeves ("short" or "long"); legs: trousers;
--   shoes; gloves: the hands' colour (bare if none). Over the shirt: apron
--   (a bib apron), bib (dungarees), vest (hi-vis), sash (with a rosette),
--   coat (a raincoat to the knee: the torso and sleeves too); collar (a
--   polo's, a work shirt's); badge: a name badge on the apron; torch: in the
--   left hand. hat: "sunhat" (straw), "cap", "hard" or "peaked", in hatColor
--   with hatTrim (the band, the badge). icon: the badge's picture.
local WorkerLooks = {}

local BOOTS = Color3.fromRGB(86, 60, 40)
local BLACK = Color3.fromRGB(40, 40, 44)
local NAVY = Color3.fromRGB(58, 72, 110)
local BROWN = Color3.fromRGB(70, 60, 50)

WorkerLooks.TYPES = {
	Farmhand = { icon = "🧑‍🌾", shirt = Color3.fromRGB(240, 226, 196), sleeves = "short", legs = Color3.fromRGB(78, 140, 60), shoes = BOOTS,
		bib = Color3.fromRGB(78, 140, 60), hat = "sunhat", hatColor = Color3.fromRGB(242, 200, 110), hatTrim = Color3.fromRGB(78, 140, 60) },
	ShedHand = { icon = "📦", shirt = Color3.fromRGB(200, 69, 45), sleeves = "long", legs = BROWN, shoes = BOOTS,
		apron = Color3.fromRGB(217, 185, 138), hat = "cap", hatColor = Color3.fromRGB(200, 69, 45) },
	Sorter = { icon = "💦", shirt = Color3.fromRGB(240, 238, 230), sleeves = "short", legs = NAVY, shoes = BLACK, gloves = Color3.fromRGB(245, 200, 66),
		apron = Color3.fromRGB(70, 140, 210), hat = "cap", hatColor = Color3.fromRGB(70, 140, 210) },
	Packer = { icon = "📦", shirt = Color3.fromRGB(242, 179, 61), sleeves = "long", legs = NAVY, shoes = BOOTS,
		apron = Color3.fromRGB(122, 86, 56) },
	Loader = { icon = "🛒", shirt = Color3.fromRGB(64, 120, 180), sleeves = "long", legs = NAVY, shoes = BOOTS, gloves = Color3.fromRGB(150, 108, 70),
		vest = Color3.fromRGB(248, 140, 40), hat = "hard", hatColor = Color3.fromRGB(245, 200, 66) },
	Driver = { icon = "🧢", shirt = Color3.fromRGB(64, 92, 140), sleeves = "long", legs = BLACK, shoes = BLACK, collar = Color3.fromRGB(48, 70, 110),
		hat = "cap", hatColor = Color3.fromRGB(200, 69, 45) },
	Stocker = { icon = "🧺", shirt = Color3.fromRGB(78, 159, 61), sleeves = "short", legs = BROWN, shoes = BOOTS, collar = Color3.fromRGB(60, 128, 48),
		hat = "cap", hatColor = Color3.fromRGB(78, 159, 61) },
	Cashier = { icon = "🧾", shirt = Color3.fromRGB(255, 244, 220), sleeves = "short", legs = BLACK, shoes = BLACK,
		apron = Color3.fromRGB(200, 69, 45), badge = true },
	Greeter = { icon = "👋", shirt = Color3.fromRGB(255, 244, 220), sleeves = "long", legs = NAVY, shoes = BLACK,
		collar = Color3.fromRGB(236, 224, 196), sash = Color3.fromRGB(242, 179, 61) },
	Watchman = { icon = "🔦", shirt = Color3.fromRGB(46, 62, 102), sleeves = "long", legs = BLACK, shoes = BLACK,
		coat = Color3.fromRGB(242, 196, 48), torch = true, hat = "peaked", hatColor = Color3.fromRGB(32, 40, 66), hatTrim = Color3.fromRGB(242, 179, 61) },
}

WorkerLooks.SKIN = {
	Color3.fromRGB(255, 220, 177), Color3.fromRGB(234, 192, 134), Color3.fromRGB(198, 134, 66), Color3.fromRGB(141, 85, 36), Color3.fromRGB(96, 60, 30),
	Color3.fromRGB(240, 200, 160), Color3.fromRGB(170, 110, 60), Color3.fromRGB(120, 72, 40),
}

-- The badge's colour for a job (its most telling piece of clothing).
function WorkerLooks.color(typeName: string): Color3
	local look = WorkerLooks.TYPES[typeName]
	return look.vest or look.apron or look.bib or look.sash or look.coat or look.hatColor or look.shirt
end

return WorkerLooks
