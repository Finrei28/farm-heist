-- What each job wears (docs/ArtDirection.md §8): the NPCs on your farm
-- (WorkerController) and the photos on their ID badges (WorkersController).
--   shirt, legs: the clothes; apron/vest: worn over the shirt; hat: a straw
--   hat, a cap or a hard hat; icon: the badge's picture.
local WorkerLooks = {}

WorkerLooks.TYPES = {
	Farmhand = { icon = "🧑‍🌾", shirt = Color3.fromRGB(240, 226, 196), legs = Color3.fromRGB(78, 140, 60), bib = Color3.fromRGB(78, 140, 60), hat = "straw" },
	ShedHand = { icon = "📦", shirt = Color3.fromRGB(200, 69, 45), legs = Color3.fromRGB(70, 60, 50), apron = Color3.fromRGB(217, 185, 138), hat = "cap", hatColor = Color3.fromRGB(200, 69, 45) },
	Sorter = { icon = "💦", shirt = Color3.fromRGB(240, 238, 230), legs = Color3.fromRGB(58, 72, 110), apron = Color3.fromRGB(70, 140, 210), hat = "cap", hatColor = Color3.fromRGB(70, 140, 210) },
	Packer = { icon = "📦", shirt = Color3.fromRGB(242, 179, 61), legs = Color3.fromRGB(58, 72, 110), apron = Color3.fromRGB(122, 86, 56) },
	Loader = { icon = "🛒", shirt = Color3.fromRGB(64, 120, 180), legs = Color3.fromRGB(58, 72, 110), vest = Color3.fromRGB(248, 140, 40), hat = "hard", hatColor = Color3.fromRGB(245, 200, 66) },
	Driver = { icon = "🧢", shirt = Color3.fromRGB(64, 92, 140), legs = Color3.fromRGB(40, 44, 48), hat = "cap", hatColor = Color3.fromRGB(200, 69, 45) },
	Stocker = { icon = "🧺", shirt = Color3.fromRGB(78, 159, 61), legs = Color3.fromRGB(70, 60, 50), hat = "cap", hatColor = Color3.fromRGB(78, 159, 61) },
	Cashier = { icon = "🧾", shirt = Color3.fromRGB(255, 244, 220), legs = Color3.fromRGB(40, 44, 48), apron = Color3.fromRGB(200, 69, 45) },
	Greeter = { icon = "👋", shirt = Color3.fromRGB(255, 244, 220), legs = Color3.fromRGB(58, 72, 110), sash = Color3.fromRGB(242, 179, 61) },
}

WorkerLooks.SKIN = {
	Color3.fromRGB(255, 220, 177), Color3.fromRGB(234, 192, 134), Color3.fromRGB(198, 134, 66), Color3.fromRGB(141, 85, 36), Color3.fromRGB(96, 60, 30),
	Color3.fromRGB(240, 200, 160), Color3.fromRGB(170, 110, 60), Color3.fromRGB(120, 72, 40),
}

-- The badge's colour for a job (its most telling piece of clothing).
function WorkerLooks.color(typeName: string): Color3
	local look = WorkerLooks.TYPES[typeName]
	return look.vest or look.apron or look.bib or look.sash or look.hatColor or look.shirt
end

return WorkerLooks
