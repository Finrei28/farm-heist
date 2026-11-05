-- Stolen crops in a thief's hands (docs/GameDesign.md §4.10, §4.12): you
-- carry what you stole held up over your head, so the farmer sees at a
-- glance which of their crops is walking off. One at a time: your hands are
-- full until you get it home to your farmhouse door (where it goes into your
-- barn). It's never saved: loot only becomes the thief's once it's home.
-- The crop remembers whose farm it came from (and its line in that farm's
-- raid ledger), so it can go back; knocked out, they drop it. Pure functions over plain tables
-- (tests/loot.test.luau); CrimeService keeps one per player.
--
-- loot = { items = { { crop, key, ownerId, entry?, count } } } (at most one
-- item: a whole patch's carrots, or one pumpkin; a list so the crop
-- mid-steal can join it for a fine)
local BarnRules = require(script.Parent.BarnRules)
local Crime = require(script.Parent.Config.Crime)
local Crops = require(script.Parent.Config.Crops)
local Rarities = require(script.Parent.Config.Rarities)
local WeatherRules = require(script.Parent.WeatherRules)

local LootRules = {}

function LootRules.new()
	return { items = {} }
end

function LootRules.isEmpty(loot): boolean
	return #loot.items == 0
end

-- The crop in their hands, if any, and how many.
function LootRules.crop(loot): (string?, number)
	local item = loot.items[1]
	return item and item.crop, if item then item.count or 1 else 0
end

-- Whether they can take another: only with empty hands.
function LootRules.fits(loot): boolean
	return LootRules.isEmpty(loot)
end

-- What a crop counts for against a farm's raid cap (shared/CrimeRules).
function LootRules.raidWeight(cropId: string): number
	return Rarities.ById[Crops.ById[cropId].rarity].raidWeight
end

-- Puts a stolen crop in their hands: `count` of it (default 1). key: its
-- barn stack key; entry: its line in the farm's raid ledger
-- (shared/CrimeRules.raidAdd).
function LootRules.add(loot, cropId: string, key: string, ownerId: number, entry, count: number?)
	local item = { crop = cropId, key = key, ownerId = ownerId, entry = entry, count = count or 1 }
	table.insert(loot.items, item)
	return item
end

-- The loot's market value: priceOf(cropId) each (default: base values).
function LootRules.value(items, priceOf: ((string) -> number)?): number
	local total = 0
	for _, item in items do
		local _, mutation = BarnRules.parse(item.key or "")
		total += (item.count or 1) * (if priceOf then priceOf(item.crop) else Crops.ById[item.crop].value) * WeatherRules.value(mutation)
	end
	return total
end

-- Whether what they carry came from this owner's farm (leaving it with
-- loot starts the same-farm cooldown).
function LootRules.hasFrom(loot, ownerId: number): boolean
	for _, item in loot.items do
		if item.ownerId == ownerId then
			return true
		end
	end
	return false
end

-- Empties their hands. Returns the items.
function LootRules.takeAll(loot)
	local items = loot.items
	loot.items = {}
	return items
end

-- Where returned loot goes: each item back to its own farm's owner if
-- they're still in the server (present(ownerId)), otherwise to the owner who
-- stopped the thief (stopperId, if any). Items with nowhere to go are lost
-- (a thief who disconnects with loot from a farm whose owner has left).
-- Returns { ["ownerId"] = { item } }.
function LootRules.returns(items, present: (number) -> boolean, stopperId: number?)
	local out = {}
	for _, item in items do
		local to = if present(item.ownerId) then item.ownerId else stopperId
		if to then
			local key = tostring(to)
			out[key] = out[key] or {}
			table.insert(out[key], item)
		end
	end
	return out
end

-- A bonked thief drops the crop in their hands on the ground (§4.12), for
-- anyone to pick up. What picking it up does for someone: "TakeBack" (it
-- goes back to its owner's barn, LootRules.returns with the farm's owner
-- as the stopper) for the crop's owner, the owner of the farm it lies in,
-- and anyone either of them trusts; "Grab" (into their hands, stolen, like
-- a steal) for anyone else. d = { whoId, cropOwnerId, farmOwnerId,
-- trustedByCrop, trustedByFarm }.
function LootRules.dropRole(d): string
	if d.whoId == d.cropOwnerId or d.whoId == d.farmOwnerId or d.trustedByCrop or d.trustedByFarm then
		return "TakeBack"
	end
	return "Grab"
end

-- Takes a dropped crop off the ground: drops = { [id] = drop }. The drop
-- for whoever asks first, nil for anyone after, so two people finishing a
-- pick-up together can't both have it (§4.12).
function LootRules.takeDrop(drops, id: number)
	local drop = drops[id]
	drops[id] = nil
	return drop
end

-- "🎃 1 pumpkin, 🥕 6 carrots" (in the order they were taken).
function LootRules.summary(items): string
	local order, counts = {}, {}
	for _, item in items do
		local _, mutation = BarnRules.parse(item.key or "")
		local kind = `{item.crop}|{mutation or ""}`
		if not counts[kind] then
			table.insert(order, { crop = item.crop, mutation = mutation, kind = kind })
			counts[kind] = 0
		end
		counts[kind] += item.count or 1
	end
	local parts = {}
	for _, entry in order do
		table.insert(parts, `{Crops.ById[entry.crop].icon} {Crops.count(entry.crop, counts[entry.kind], entry.mutation)}`)
	end
	return table.concat(parts, ", ")
end

-- Whether a stolen crop in your hands slows you where you are (`farm`: the
-- farm you're in, 0 for none). Only on a farm, where someone can bonk you for
-- it: off farmland nobody can stop you, so you can run (the user, 2026-11-05).
function LootRules.slowed(carrying: boolean, farm: number): boolean
	return carrying and farm > 0
end

-- Walking speed with a stolen crop in your hands on a farm (and no running).
function LootRules.speed(walkSpeed: number, carrying: boolean): number
	return if carrying then walkSpeed * Crime.CARRY_SPEED else walkSpeed
end

return LootRules
