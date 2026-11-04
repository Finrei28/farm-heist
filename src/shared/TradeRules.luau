-- The rules of trading between players (docs/GameDesign.md §4.13;
-- TradeService runs trades, the client's TradeController shows them): what
-- can be offered, when trading unlocks, the swap itself and undoing one.
-- Pure functions over plain tables (tests/trade.test.luau).
--
-- What trades: crops from the barn (by stack: crop, mutation), seeds and
-- coins. Never workers, Land Permits, defences, store items, anything bought
-- with Robux, a stolen crop still in your hands (it isn't in the barn until
-- you're home), or coins while you owe a debt.
--
-- An offer is { lines = { { kind = "crop" | "seed", key, count } }, coins }
-- (key: a barn stack key for a crop, a crop id for seeds). A side, for check
-- and swap, is { data = save data (inventory, coins, silo, crime.debts), offer }.
local BarnRules = require(script.Parent.BarnRules)
local Crops = require(script.Parent.Config.Crops)
local WeatherRules = require(script.Parent.WeatherRules)

local TradeRules = {}

TradeRules.MAX_LINES = 8 -- stacks each side can offer
TradeRules.COUNTDOWN = 5 -- seconds after both are Ready before Confirm opens
TradeRules.MIN_PLAY_SECONDS = 3600 -- play time before you can trade
TradeRules.REQUEST_SECONDS = 30 -- how long a trade request waits for an answer
TradeRules.NEAR_DISTANCE = 20 -- studs: trades are in person, with someone this close
TradeRules.APART_DISTANCE = 40 -- studs: walking this far apart cancels an open trade
TradeRules.LOPSIDED = 3 -- warn when you give this many times what you get
TradeRules.MAX_COUNT = 1_000_000 -- (a sanity cap on one line)

function TradeRules.newOffer()
	return { lines = {}, coins = 0 }
end

-- Whether two characters' positions are close enough (`limit`:
-- NEAR_DISTANCE, or APART_DISTANCE for keeping one open). Flat distance.
function TradeRules.near(a: Vector3?, b: Vector3?, limit: number?): boolean
	if not (a and b) then
		return false
	end
	local offset = a - b
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= (limit or TradeRules.NEAR_DISTANCE)
end

function TradeRules.unlocked(playSeconds: number?): boolean
	return (playSeconds or 0) >= TradeRules.MIN_PLAY_SECONDS
end

function TradeRules.inDebt(data): boolean
	return data.crime ~= nil and #(data.crime.debts or {}) > 0
end

-- How many of a line's thing a save holds.
function TradeRules.have(data, kind: string, key: string): number
	if kind == "crop" then
		return data.inventory.crops[key] or 0
	elseif kind == "seed" then
		return data.inventory.seeds[key] or 0
	end
	return 0
end

local function validKey(kind: string, key: any): boolean
	if type(key) ~= "string" then
		return false
	end
	if kind == "crop" then
		return Crops.ById[(BarnRules.parse(key))] ~= nil
	elseif kind == "seed" then
		return Crops.ById[key] ~= nil
	end
	return false
end

local function findLine(offer, kind: string, key: string)
	for index, line in offer.lines do
		if line.kind == kind and line.key == key then
			return line, index
		end
	end
	return nil, nil
end
TradeRules.findLine = findLine

-- Sets how many of a stack is offered (0 takes it out). Returns nil, or why
-- not: "BadRequest" · "NotFound" (none of it) · "NotEnough" · "TooMany"
-- (already 8 stacks).
function TradeRules.setLine(offer, data, kind: any, key: any, count: any): string?
	if (kind ~= "crop" and kind ~= "seed") or not validKey(kind, key) then
		return "BadRequest"
	end
	if type(count) ~= "number" or count ~= count or count < 0 or count > TradeRules.MAX_COUNT then
		return "BadRequest"
	end
	count = math.floor(count)
	local line, index = findLine(offer, kind, key)
	if count == 0 then
		if index then
			table.remove(offer.lines, index)
		end
		return nil
	end
	local have = TradeRules.have(data, kind, key)
	if have == 0 then
		return "NotFound"
	elseif count > have then
		return "NotEnough"
	end
	if line then
		line.count = count
	elseif #offer.lines >= TradeRules.MAX_LINES then
		return "TooMany"
	else
		table.insert(offer.lines, { kind = kind, key = key, count = count })
	end
	return nil
end

-- A coin amount from the client, made safe: a whole number from 0 to what
-- they have, and none while they owe a debt. Returns (amount, nil) or (nil, reason).
function TradeRules.cleanCoins(amount: any, data): (number?, string?)
	if type(amount) ~= "number" or amount ~= amount or amount == math.huge or amount == -math.huge then
		return nil, "BadRequest"
	end
	amount = math.floor(amount)
	if amount < 0 then
		return nil, "BadRequest"
	elseif amount > 0 and TradeRules.inDebt(data) then
		return nil, "InDebt"
	elseif amount > data.coins then
		return nil, "NotEnoughCoins"
	end
	return amount, nil
end

-- What one line is worth: crops at priceOf(cropId) (the truck price now)
-- times their mutation's value, seeds at Barley's price.
function TradeRules.lineValue(line, priceOf: (string) -> number): number
	if line.kind == "crop" then
		local cropId, mutation = BarnRules.parse(line.key)
		return math.floor(line.count * priceOf(cropId) * WeatherRules.value(mutation) + 0.5)
	end
	return line.count * Crops.ById[line.key].seed
end

function TradeRules.offerValue(offer, priceOf: (string) -> number): number
	local total = offer.coins or 0
	for _, line in offer.lines do
		total += TradeRules.lineValue(line, priceOf)
	end
	return total
end

-- Whether you'd be giving far more than you get (the window warns).
function TradeRules.lopsided(giveValue: number, getValue: number): boolean
	return giveValue > 0 and giveValue >= math.max(getValue, 1) * TradeRules.LOPSIDED
end

local function cropUnits(offer): number
	local units = 0
	for _, line in offer.lines do
		if line.kind == "crop" then
			units += line.count
		end
	end
	return units
end

-- Takes out of `offer` anything its side no longer has (sold, packed,
-- planted meanwhile). Returns whether it changed.
function TradeRules.clamp(offer, data): boolean
	local changed = false
	for index = #offer.lines, 1, -1 do
		local line = offer.lines[index]
		local have = TradeRules.have(data, line.kind, line.key)
		if have <= 0 then
			table.remove(offer.lines, index)
			changed = true
		elseif line.count > have then
			line.count = have
			changed = true
		end
	end
	if offer.coins > data.coins or (offer.coins > 0 and TradeRules.inDebt(data)) then
		offer.coins = if TradeRules.inDebt(data) then 0 else data.coins
		changed = true
	end
	return changed
end

-- Why the trade can't go ahead, as (reason, which side: "a" | "b"), or nil
-- if it can. Reasons: "Empty" (neither offers anything), "Gone" (a stack
-- isn't all there any more), "NotEnoughCoins", "InDebt", "BarnFull" (no room
-- for the crops coming in).
function TradeRules.check(a, b): (string?, string?)
	if #a.offer.lines == 0 and #b.offer.lines == 0 and a.offer.coins == 0 and b.offer.coins == 0 then
		return "Empty", "a"
	end
	for _, pair in { { a, "a" }, { b, "b" } } do
		local side, name = pair[1], pair[2]
		local seen = {}
		for _, line in side.offer.lines do
			local id = `{line.kind}:{line.key}`
			if seen[id] or line.count < 1 or TradeRules.have(side.data, line.kind, line.key) < line.count then
				return "Gone", name
			end
			seen[id] = true
		end
		if side.offer.coins < 0 or side.offer.coins > side.data.coins then
			return "NotEnoughCoins", name
		elseif side.offer.coins > 0 and TradeRules.inDebt(side.data) then
			return "InDebt", name
		end
	end
	for _, pair in { { a, b, "a" }, { b, a, "b" } } do
		local side, other, name = pair[1], pair[2], pair[3]
		local incoming, outgoing = cropUnits(other.offer), cropUnits(side.offer)
		local after = BarnRules.units(side.data.inventory) - outgoing + incoming
		if incoming > outgoing and after > BarnRules.capacityOf(side.data) then
			return "BarnFull", name
		end
	end
	return nil, nil
end

local function give(data, line, count: number)
	if line.kind == "crop" then
		BarnRules.addCrops(data.inventory, line.key, count)
	else
		BarnRules.addSeeds(data.inventory, line.key, count)
	end
end

local function take(data, line, count: number): number
	local have = TradeRules.have(data, line.kind, line.key)
	local taken = math.min(have, count)
	if taken > 0 then
		local list = if line.kind == "crop" then data.inventory.crops else data.inventory.seeds
		list[line.key] = if have == taken then nil else have - taken
	end
	return taken
end

-- Swaps the offers: all of it, or (when check fails) nothing at all.
-- Returns (true, nil, nil) or (false, reason, side).
function TradeRules.swap(a, b): (boolean, string?, string?)
	local reason, side = TradeRules.check(a, b)
	if reason then
		return false, reason, side
	end
	-- Nothing below can fail (check saw every stack and coin), so the swap
	-- never stops half done.
	for _, pair in { { a, b }, { b, a } } do
		local from, to = pair[1], pair[2]
		for _, line in from.offer.lines do
			take(from.data, line, line.count)
			give(to.data, line, line.count)
		end
	end
	a.data.coins += b.offer.coins - a.offer.coins
	b.data.coins += a.offer.coins - b.offer.coins
	return true, nil, nil
end

-- A logged side: its lines with what each was worth then (for undoing one
-- whose crops have been sold since).
function TradeRules.logLines(offer, priceOf: (string) -> number)
	local lines = {}
	for _, line in offer.lines do
		table.insert(lines, { kind = line.kind, key = line.key, count = line.count, value = TradeRules.lineValue(line, priceOf) })
	end
	return lines
end

-- What undoing a logged trade means for one of its two players
-- (record = { id, a = { userId, lines, coins }, b = {...} }):
--   take   the lines they got (each with its value then)
--   give   the lines they gave, to have back
--   coins  coins to get back: what they gave minus what they got
function TradeRules.undoFor(record, userId: number)
	local mine = if record.a.userId == userId then record.a else record.b
	local theirs = if mine == record.a then record.b else record.a
	return { tradeId = record.id, take = theirs.lines, give = mine.lines, coins = mine.coins - theirs.coins }
end

-- Undoes a trade for one player's save (from undoFor). Only ever once per
-- trade: the save remembers it in tradeUndone. What they got is taken back
-- as far as it's there; whatever's gone (sold, planted) comes off their
-- coins at what it was worth then. What they gave comes back. Coins never
-- go below 0. Returns a report, or nil if already undone.
function TradeRules.reverse(data, undo)
	data.tradeUndone = data.tradeUndone or {}
	if data.tradeUndone[undo.tradeId] then
		return nil
	end
	local report = { taken = 0, charged = 0, returned = 0, coins = 0, shortfall = 0 }
	for _, line in undo.take do
		local taken = take(data, line, line.count)
		report.taken += taken
		if taken < line.count and line.count > 0 then
			report.charged += math.floor((line.value or 0) * (line.count - taken) / line.count + 0.5)
		end
	end
	for _, line in undo.give do
		give(data, line, line.count)
		report.returned += line.count
	end
	local after = data.coins + undo.coins - report.charged
	if after < 0 then
		report.shortfall = -after
		after = 0
	end
	report.coins = after - data.coins
	data.coins = after
	data.tradeUndone[undo.tradeId] = true
	return report
end

return TradeRules
