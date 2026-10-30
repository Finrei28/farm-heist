-- The six crop rarities (docs/GameDesign.md §4.2): their colour, how long a
-- steal takes, how much of the 5-weight Loot Sack one crop fills, Barley's
-- stock (Commons are unlimited; other seeds come in on `seedChance` of
-- restocks, 1–`maxPacks` packs of `packSeeds` seeds each), how many fit in
-- a crate, and the Farm Level needed to buy (and plant) them. Harvest XP is
-- in Config/Progression.
local Rarities = {}

Rarities.List = {
	{ id = "Common", order = 1, color = Color3.fromRGB(184, 184, 184),
		stealHold = 1.0, sackWeight = 1, unlimited = true, seedChance = 1, maxPacks = 0, packSeeds = 0, crate = 12, seedLevel = 1 },
	{ id = "Uncommon", order = 2, color = Color3.fromRGB(92, 199, 92),
		stealHold = 1.5, sackWeight = 1, seedChance = 0.85, maxPacks = 5, packSeeds = 5, crate = 10, seedLevel = 2 },
	{ id = "Rare", order = 3, color = Color3.fromRGB(62, 142, 240),
		stealHold = 2.5, sackWeight = 2, seedChance = 0.55, maxPacks = 4, packSeeds = 3, crate = 6, seedLevel = 5 },
	{ id = "Epic", order = 4, color = Color3.fromRGB(160, 92, 240),
		stealHold = 3.5, sackWeight = 3, seedChance = 0.25, maxPacks = 2, packSeeds = 2, crate = 4, seedLevel = 10 },
	{ id = "Legendary", order = 5, color = Color3.fromRGB(245, 179, 35),
		stealHold = 5.0, sackWeight = 5, seedChance = 0.08, maxPacks = 1, packSeeds = 1, crate = 2, seedLevel = 16 },
	{ id = "Mythic", order = 6, color = Color3.fromRGB(240, 79, 168),
		stealHold = 7.0, sackWeight = 5, seedChance = 0.02, maxPacks = 1, packSeeds = 1, crate = 1, seedLevel = 20 },
}

Rarities.ById = {}
for _, rarity in Rarities.List do
	Rarities.ById[rarity.id] = rarity
end

return Rarities
