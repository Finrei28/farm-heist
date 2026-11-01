-- The Loot Sack (docs/GameDesign.md §4.10, §4.12): the crops a thief has
-- taken and not yet emptied into their own barn. It's never saved: loot only
-- becomes the thief's once it's deposited. Each item remembers whose farm it
-- came from (and its line in that farm's raid ledger), so it can go back.
-- Pure functions over plain tables (tests/sack.test.luau); CrimeService
-- keeps one per player.
--
-- sack = { items = { { crop, key, weight, ownerId, entry? } } }
local Crime = require(script.Parent.Config.Crime)
local Crops = require(script.Parent.Config.Crops)
local Rarities = require(script.Parent.Config.Rarities)

local SackRules = {}

function SackRules.new()
	return { items = {} }
end

function SackRules.weightOf(cropId: string): number
	return Rarities.ById[Crops.ById[cropId].rarity].sackWeight
end

function SackRules.weight(sack): number
	local total = 0
	for _, item in sack.items do
		total += item.weight
	end
	return total
end

function SackRules.isEmpty(sack): boolean
	return #sack.items == 0
end

-- Whether one more of this crop fits.
function SackRules.fits(sack, cropId: string): boolean
	return SackRules.weight(sack) + SackRules.weightOf(cropId) <= Crime.SACK_CAPACITY
end

-- Puts a stolen crop in. key: its barn stack key; entry: its line in the
-- farm's raid ledger (shared/CrimeRules.raidAdd).
function SackRules.add(sack, cropId: string, key: string, ownerId: number, entry)
	local item = { crop = cropId, key = key, weight = SackRules.weightOf(cropId), ownerId = ownerId, entry = entry }
	table.insert(sack.items, item)
	return item
end

-- The loot's market value: priceOf(cropId) per unit (default: base values).
function SackRules.value(items, priceOf: ((string) -> number)?): number
	local total = 0
	for _, item in items do
		total += if priceOf then priceOf(item.crop) else Crops.ById[item.crop].value
	end
	return total
end

-- Whether anything in the sack came from this owner's farm (leaving it with
-- loot starts the same-farm cooldown).
function SackRules.hasFrom(sack, ownerId: number): boolean
	for _, item in sack.items do
		if item.ownerId == ownerId then
			return true
		end
	end
	return false
end

-- Empties the sack. Returns the items.
function SackRules.takeAll(sack)
	local items = sack.items
	sack.items = {}
	return items
end

-- Where returned loot goes: each item back to its own farm's owner if
-- they're still in the server (present(ownerId)), otherwise to the owner who
-- stopped the thief (stopperId, if any). Items with nowhere to go are lost
-- (a thief who disconnects with loot from a farm whose owner has left).
-- Returns { ["ownerId"] = { item } }.
function SackRules.returns(items, present: (number) -> boolean, stopperId: number?)
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

-- "🎃 Pumpkin ×2, 🥕 Carrot" (in the order they were taken).
function SackRules.summary(items): string
	local order, counts = {}, {}
	for _, item in items do
		if not counts[item.crop] then
			table.insert(order, item.crop)
			counts[item.crop] = 0
		end
		counts[item.crop] += 1
	end
	local parts = {}
	for _, cropId in order do
		local crop = Crops.ById[cropId]
		local count = counts[cropId]
		table.insert(parts, `{crop.icon} {crop.name}{if count > 1 then ` ×{count}` else ""}`)
	end
	return table.concat(parts, ", ")
end

-- Walking speed with a sack on your back (and no running).
function SackRules.speed(walkSpeed: number, carrying: boolean): number
	return if carrying then walkSpeed * Crime.SACK_SPEED else walkSpeed
end

return SackRules
