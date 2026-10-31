-- Selling in your store (docs/GameDesign.md §4.8; how a shopper decides is
-- shared/DemandModel, the floor plan shared/StoreLayout). Crates sent to the
-- store wait in its stockroom; Fill moves them onto a display's slots (a
-- slot holds one crop: the one it's set to, or Auto). Shoppers want 1–3
-- crops from what's on display, walk to a display with each, take 1–4
-- units if your price is low enough for them, and pay at a checkout (or
-- put it all back if they give up in the queue). Grade A units go first,
-- at your price × 1.15 (shoppers pay that much more for them too, so it
-- doesn't change whether they buy). The rating is the last shoppers'
-- scores plus Charm. tests/shop.test.luau.
--
-- store (in the save) = { level, build?, name?, layout, owned, gifts, nextId,
--   stockroom = { crate }, prices = { [cropId] = coins }, rating = { scores = { 1–5 } } }
-- A display's slots: { { set = cropId?, crop = cropId?, units, a } } (set:
-- the crop it's kept to, nil for Auto; crop: what's on it; a: how many of
-- the units are grade A).
-- marketPrice(cropId) gives the truck price right now (MarketService).
local Crops = require(script.Parent.Config.Crops)
local Shop = require(script.Parent.Config.Shop)
local Store = require(script.Parent.Config.Store)
local Warehouse = require(script.Parent.Config.Warehouse)
local CrateRules = require(script.Parent.CrateRules)
local DemandModel = require(script.Parent.DemandModel)
local StoreLayout = require(script.Parent.StoreLayout)

local ShopRules = {}

-- The reference price shoppers judge a crop by right now.
function ShopRules.reference(cropId: string, market: number): number
	return DemandModel.reference(Crops.ById[cropId].value, market)
end

------------------------------------------------------------------------
-- The rating

-- The shoppers' average (1–5): the last RATING_WINDOW scores, with a new
-- store counting RATING_SETTLE shoppers at START_STARS that the real ones
-- replace, so the first shopper or two can't swing it to 1★ or 5★.
function ShopRules.shopperStars(store): number
	local scores = store.rating.scores
	local settle = math.max(0, Shop.RATING_SETTLE - #scores)
	local sum = Shop.START_STARS * settle
	for _, score in scores do
		sum += score
	end
	if #scores + settle == 0 then
		return Shop.START_STARS
	end
	return math.clamp(sum / (#scores + settle), 1, 5)
end

-- The Store Rating: the shoppers' average plus Charm (up to +1★), 1–5.
function ShopRules.stars(store): number
	return math.clamp(ShopRules.shopperStars(store) + StoreLayout.charmStars(store.layout), 1, 5)
end

function ShopRules.addScore(store, score: number)
	local scores = store.rating.scores
	table.insert(scores, score)
	while #scores > Shop.RATING_WINDOW do
		table.remove(scores, 1)
	end
end

------------------------------------------------------------------------
-- What's on display

-- Each crop out on the floor: { [cropId] = { slots, units } }.
function ShopRules.onDisplay(store)
	local out = {}
	for _, id in StoreLayout.ofKind(store.layout, "Display") do
		for _, slot in store.layout[id].slots or {} do
			if slot.crop and slot.units > 0 then
				local entry = out[slot.crop] or { slots = 0, units = 0 }
				entry.slots += 1
				entry.units += slot.units
				out[slot.crop] = entry
			end
		end
	end
	return out
end

-- How many different crops are out.
function ShopRules.variety(store): number
	local count = 0
	for _ in ShopRules.onDisplay(store) do
		count += 1
	end
	return count
end

-- Open for shoppers: something on display.
function ShopRules.isOpen(store): boolean
	return next(ShopRules.onDisplay(store)) ~= nil
end

-- Seconds between shoppers: the level and rating (DemandModel), more often
-- with each different crop out after the first (+5%, up to +25%) and with
-- the Supermarket's billboard.
function ShopRules.interval(store): number
	local level = StoreLayout.level(store.level)
	local variety = math.min(Shop.VARIETY_MAX, Shop.VARIETY * math.max(0, ShopRules.variety(store) - 1))
	local billboard = if level.billboard then Store.BILLBOARD else 0
	return DemandModel.shopperInterval(store.level, ShopRules.stars(store)) / (1 + variety) / (1 + billboard)
end

------------------------------------------------------------------------
-- The stockroom

-- Units waiting in the stockroom, by crop.
function ShopRules.stockroomUnits(store)
	local units = {}
	for _, crate in store.stockroom do
		units[crate.crop] = (units[crate.crop] or 0) + crate.units
	end
	return units
end

-- Crates the stockroom holds at this level, and how many more fit.
function ShopRules.stockroomSize(store): number
	return StoreLayout.level(store.level).stockroom
end
function ShopRules.stockroomRoom(store): number
	return math.max(0, ShopRules.stockroomSize(store) - #store.stockroom)
end

-- Puts units back in the stockroom: topping up a part-full crate of the
-- same crop and grade first, then new crates. Always fits (goods coming
-- back are never lost, even past full).
function ShopRules.restock(store, cropId: string, units: number, grade: string)
	local size = CrateRules.size(cropId)
	for _, crate in store.stockroom do
		if units <= 0 then
			break
		end
		if crate.crop == cropId and crate.grade == grade and crate.units < size then
			local add = math.min(units, size - crate.units)
			crate.units += add
			units -= add
		end
	end
	while units > 0 do
		local add = math.min(units, size)
		table.insert(store.stockroom, { crop = cropId, key = `{cropId}||`, units = add, grade = grade })
		units -= add
	end
end

------------------------------------------------------------------------
-- Filling displays

local function rarityOf(cropId: string): string
	return Crops.ById[cropId].rarity
end

-- Whether this display can hold this crop.
function ShopRules.canHold(itemId: string, cropId: string): boolean
	return Crops.ById[cropId] ~= nil and StoreLayout.holds(itemId, rarityOf(cropId))
end

-- Moves units of the slot's crop from the stockroom onto it, up to `room`:
-- grade A first, the smallest crates first (so crates empty and free up
-- stockroom space). Returns units moved.
local function topUp(store, slot, room: number): number
	local moved = 0
	for _, grade in { "A", "B" } do
		while room > 0 do
			local best = nil
			for i, crate in store.stockroom do
				if crate.crop == slot.crop and crate.grade == grade and (not best or crate.units < store.stockroom[best].units) then
					best = i
				end
			end
			if not best then
				break
			end
			local crate = store.stockroom[best]
			local take = math.min(room, crate.units)
			crate.units -= take
			room -= take
			moved += take
			slot.units += take
			if grade == "A" then
				slot.a += take
			end
			if crate.units <= 0 then
				table.remove(store.stockroom, best)
			end
		end
	end
	return moved
end

-- Which crop an empty Auto slot takes: one the display can hold that isn't
-- out anywhere yet (variety brings shoppers), then one not on this display,
-- then any; the most units waiting first.
local function autoCrop(store, entry): string?
	local out = ShopRules.onDisplay(store)
	local here = {}
	for _, slot in entry.slots do
		if slot.crop and slot.units > 0 then
			here[slot.crop] = true
		end
	end
	local waiting = ShopRules.stockroomUnits(store)
	for pass = 1, 3 do
		local best, most = nil, 0
		for cropId, units in waiting do
			local fresh = (pass == 1 and not out[cropId]) or (pass == 2 and not here[cropId]) or pass == 3
			if fresh and ShopRules.canHold(entry.item, cropId) and (units > most or (units == most and best and cropId < best)) then
				best, most = cropId, units
			end
		end
		if best then
			return best
		end
	end
	return nil
end

-- Fills one display from the stockroom: each slot topped up with its crop,
-- an empty slot given its set crop or (Auto) a crop chosen for it. A crop
-- going out for the first time is priced at the reference. Returns units
-- moved.
function ShopRules.fill(store, id: string, marketPrice): number
	local entry = store.layout[id]
	local def = entry and Store.ITEMS[entry.item]
	if not def or def.kind ~= "Display" then
		return 0
	end
	local moved = 0
	for _, slot in entry.slots do
		if slot.units <= 0 then
			slot.units, slot.a = 0, 0
			slot.crop = if slot.set then slot.set else autoCrop(store, entry)
		end
		if slot.crop then
			moved += topUp(store, slot, def.units - slot.units)
			if slot.units > 0 and not store.prices[slot.crop] then
				ShopRules.setPrice(store, slot.crop, ShopRules.reference(slot.crop, marketPrice(slot.crop)), marketPrice(slot.crop))
			end
			if slot.units <= 0 and not slot.set then
				slot.crop = nil
			end
		end
	end
	return moved
end

-- Fills every display. Returns units moved.
function ShopRules.fillAll(store, marketPrice): number
	local moved = 0
	for _, id in StoreLayout.ofKind(store.layout, "Display") do
		moved += ShopRules.fill(store, id, marketPrice)
	end
	return moved
end

-- Takes everything off a display and back to the stockroom. Returns units.
function ShopRules.empty(store, id: string): number
	local entry = store.layout[id]
	local units = 0
	for _, slot in (entry and entry.slots) or {} do
		if slot.crop and slot.units > 0 then
			if slot.a > 0 then
				ShopRules.restock(store, slot.crop, slot.a, "A")
			end
			if slot.units - slot.a > 0 then
				ShopRules.restock(store, slot.crop, slot.units - slot.a, "B")
			end
			units += slot.units
		end
		slot.units, slot.a = 0, 0
		slot.crop = slot.set
	end
	return units
end

-- Keeps a slot to one crop (cropId) or sets it back to Auto (nil). What's
-- on it now goes back to the stockroom if it's a different crop. Returns
-- nil, or why not: "BadRequest" · "CantHold".
function ShopRules.setSlot(store, id: string, index: number, cropId: string?): string?
	local entry = store.layout[id]
	local slot = entry and entry.slots and entry.slots[index]
	if not slot then
		return "BadRequest"
	end
	if cropId and not ShopRules.canHold(entry.item, cropId) then
		return "CantHold"
	end
	slot.set = cropId
	if cropId and slot.crop and slot.crop ~= cropId and slot.units > 0 then
		if slot.a > 0 then
			ShopRules.restock(store, slot.crop, slot.a, "A")
		end
		if slot.units - slot.a > 0 then
			ShopRules.restock(store, slot.crop, slot.units - slot.a, "B")
		end
		slot.units, slot.a = 0, 0
		slot.crop = cropId
	elseif slot.units <= 0 then
		slot.crop = cropId
	end
	return nil
end

-- Sets a crop's price, kept within 50–300% of today's reference. Returns
-- the price set.
function ShopRules.setPrice(store, cropId: string, coins: number, market: number): number
	local low, high = DemandModel.priceRange(ShopRules.reference(cropId, market))
	local price = math.clamp(math.floor(coins + 0.5), low, high)
	store.prices[cropId] = price
	return price
end

------------------------------------------------------------------------
-- Shoppers

-- One standard normal number.
local function normal(rng): number
	local u1 = math.max(1e-9, rng:NextNumber())
	local u2 = rng:NextNumber()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

-- The crops a new shopper wants (rng: a Random): 1–3 of what's on display,
-- as many as the level's baskets, crops on more slots picked more often.
function ShopRules.wants(store, rng): { string }
	local range = StoreLayout.level(store.level).wants
	local count = rng:NextInteger(range[1], range[2])
	local pool = {}
	for cropId, entry in ShopRules.onDisplay(store) do
		table.insert(pool, { crop = cropId, weight = entry.slots })
	end
	table.sort(pool, function(a, b)
		return a.crop < b.crop
	end)
	local wants = {}
	while #wants < count and #pool > 0 do
		local total = 0
		for _, option in pool do
			total += option.weight
		end
		local roll = rng:NextNumber() * total
		for i, option in pool do
			roll -= option.weight
			if roll <= 0 or i == #pool then
				table.insert(wants, option.crop)
				table.remove(pool, i)
				break
			end
		end
	end
	return wants
end

-- A display with this crop on it (one picked at random), or nil.
function ShopRules.displayWith(store, cropId: string, rng): string?
	local ids = {}
	for _, id in StoreLayout.ofKind(store.layout, "Display") do
		for _, slot in store.layout[id].slots or {} do
			if slot.crop == cropId and slot.units > 0 then
				table.insert(ids, id)
				break
			end
		end
	end
	if #ids == 0 then
		return nil
	end
	return ids[rng:NextInteger(1, #ids)]
end

-- A shopper at display `id` looking for `cropId`. Rolls what they'd pay
-- (their willingness × the rating bonus × the display's presentation) and,
-- if your price is low enough, takes 1–4 units off the display into their
-- basket. Returns "Bought", line · "TooDear" · "SoldOut", where
-- line = { display, crop, units, a, coins } (paid at the checkout).
function ShopRules.pick(store, id: string, cropId: string, rng, marketPrice)
	local entry = store.layout[id]
	local def = entry and Store.ITEMS[entry.item]
	local have = 0
	for _, slot in (entry and entry.slots) or {} do
		if slot.crop == cropId then
			have += slot.units
		end
	end
	if not def or have <= 0 then
		return "SoldOut", nil
	end
	local ref = ShopRules.reference(cropId, marketPrice(cropId))
	local price = store.prices[cropId] or math.floor(ref + 0.5)
	local willing = ref * math.exp(Shop.SIGMA * normal(rng)) * (1 + DemandModel.ratingBonus(ShopRules.stars(store))) * def.present
	if price > willing then
		return "TooDear", nil
	end
	local want = math.min(rng:NextInteger(1, 4), have)
	local line = { display = id, crop = cropId, units = 0, a = 0, coins = 0 }
	for _, slot in entry.slots do
		if slot.crop == cropId and want > 0 then
			local take = math.min(want, slot.units)
			local a = math.min(take, slot.a)
			slot.units -= take
			slot.a -= a
			want -= take
			line.units += take
			line.a += a
			if slot.units <= 0 then
				slot.units, slot.a = 0, 0
				if not slot.set then
					slot.crop = nil
				end
			end
		end
	end
	line.coins = line.a * math.floor(price * Warehouse.GRADE_A + 0.5) + (line.units - line.a) * price
	return "Bought", line
end

-- A shopper gives up and puts their basket back: onto the display it came
-- from if it still holds that crop and has room, the rest to the stockroom.
function ShopRules.putBack(store, line)
	local entry = store.layout[line.display]
	local def = entry and Store.ITEMS[entry.item]
	local units, a = line.units, line.a
	if def and def.kind == "Display" then
		for _, slot in entry.slots do
			if units > 0 and (slot.crop == line.crop or (slot.units <= 0 and (slot.set == nil or slot.set == line.crop))) then
				local room = def.units - (if slot.crop == line.crop then slot.units else 0)
				local back = math.min(units, room)
				if back > 0 then
					if slot.crop ~= line.crop then
						slot.crop, slot.units, slot.a = line.crop, 0, 0
					end
					local backA = math.min(back, a)
					slot.units += back
					slot.a += backA
					units -= back
					a -= backA
				end
			end
		end
	end
	if a > 0 then
		ShopRules.restock(store, line.crop, a, "A")
	end
	if units - a > 0 then
		ShopRules.restock(store, line.crop, units - a, "B")
	end
end

return ShopRules
