-- The six crop rarities (docs/GameDesign.md §4.2): their colour, how long a
-- steal takes, what one counts for against a farm's raid cap, Barley's
-- stock (Commons are unlimited; other seeds come in on `seedChance` of
-- restocks, 1–`maxPacks` packs of `packSeeds` seeds each), how many
-- patches' worth fit in a crate (`cratePatches`: each crop's crate in
-- Config/Crops is that many patches or a few fewer), and the Farm Level
-- needed to buy (and plant) them. Harvest XP is in Config/Progression.
-- Mythic seeds aren't sold at Barley's at all (`atBarleys = false`): they
-- only come from the Auction House (the user, 2026-11-04).
local Rarities = {}

Rarities.List = {
	{ id = "Common", order = 1, color = Color3.fromRGB(184, 184, 184),
		stealHold = 1.0, raidWeight = 1, unlimited = true, seedChance = 1, maxPacks = 0, packSeeds = 0, cratePatches = 12, seedLevel = 1 },
	{ id = "Uncommon", order = 2, color = Color3.fromRGB(92, 199, 92),
		stealHold = 1.5, raidWeight = 1, seedChance = 0.85, maxPacks = 5, packSeeds = 5, cratePatches = 10, seedLevel = 2 },
	{ id = "Rare", order = 3, color = Color3.fromRGB(62, 142, 240),
		stealHold = 2.5, raidWeight = 2, seedChance = 0.55, maxPacks = 4, packSeeds = 3, cratePatches = 6, seedLevel = 5 },
	{ id = "Epic", order = 4, color = Color3.fromRGB(160, 92, 240),
		stealHold = 3.5, raidWeight = 3, seedChance = 0.25, maxPacks = 2, packSeeds = 2, cratePatches = 4, seedLevel = 10 },
	{ id = "Legendary", order = 5, color = Color3.fromRGB(245, 179, 35),
		stealHold = 5.0, raidWeight = 5, seedChance = 0.08, maxPacks = 1, packSeeds = 1, cratePatches = 2, seedLevel = 16 },
	{ id = "Mythic", order = 6, color = Color3.fromRGB(240, 79, 168),
		stealHold = 7.0, raidWeight = 5, atBarleys = false, seedChance = 0, maxPacks = 0, packSeeds = 0, cratePatches = 1, seedLevel = 20 },
}

Rarities.ById = {}
for _, rarity in Rarities.List do
	Rarities.ById[rarity.id] = rarity
end

return Rarities
