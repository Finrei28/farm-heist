-- Your own shop's shelves, prices, shoppers and rating (docs/GameDesign.md
-- §4.8; how a shopper decides is shared/DemandModel). Crates sent to the
-- shop wait in the stockroom; stocking moves them onto the shelves (a shelf
-- holds one crop); each NPC shopper picks one stocked shelf, rolls how much
-- they'd pay, and buys 1–4 units if your price is low enough. Grade A
-- units sell first, at your price × 1.15 (shoppers pay that much more for
-- them too, so it doesn't change whether they buy). tests/shop.test.luau.
--
-- shop (in the save) = { tier, shelves = { ["1"] = { crop, units, a } }, stockroom = { crate },
--   prices = { [cropId] = coins }, rating = { scores = { 1–5 } } }
--   a: how many of the shelf's units are grade A
-- marketPrice(cropId) gives the truck price right now (MarketService).
local BarnRules = require(script.Parent.BarnRules)
local Crops = require(script.Parent.Config.Crops)
local Shop = require(script.Parent.Config.Shop)
local Warehouse = require(script.Parent.Config.Warehouse)
local DemandModel = require(script.Parent.DemandModel)

local ShopRules = {}

function ShopRules.tier(shop)
	return Shop.TIERS[(shop.tier or 0) + 1]
end

-- The reference price shoppers judge a crop by right now.
function ShopRules.reference(cropId: string, market: number): number
	return DemandModel.reference(Crops.ById[cropId].value, market)
end

-- The rating in stars (1–5): the average of the last shoppers' scores. A
-- new shop counts RATING_SETTLE shoppers at START_STARS that the real ones
-- replace, so the first shopper or two can't swing it to 1★ or 5★.
function ShopRules.stars(shop): number
	local scores = shop.rating.scores
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

function ShopRules.addScore(shop, score: number)
	local scores = shop.rating.scores
	table.insert(scores, score)
	while #scores > Shop.RATING_WINDOW do
		table.remove(scores, 1)
	end
end

-- Seconds between shoppers at this shop's tier and rating.
function ShopRules.interval(shop): number
	return DemandModel.shopperInterval(shop.tier or 0, ShopRules.stars(shop))
end

-- Units waiting in the stockroom, by crop.
function ShopRules.stockroomUnits(shop)
	local units = {}
	for _, crate in shop.stockroom do
		units[crate.crop] = (units[crate.crop] or 0) + crate.units
	end
	return units
end

-- How many of the stocked shelves hold this crop (its share of shoppers).
function ShopRules.shelvesOf(shop, cropId: string): number
	local count = 0
	for _, key in ShopRules.stocked(shop) do
		if shop.shelves[key].crop == cropId then
			count += 1
		end
	end
	return count
end

-- Shelf numbers ("1", "2", ...) that have something on them, in order.
function ShopRules.stocked(shop)
	local keys = {}
	for i = 1, ShopRules.tier(shop).shelves do
		local shelf = shop.shelves[tostring(i)]
		if shelf and shelf.units > 0 then
			table.insert(keys, tostring(i))
		end
	end
	return keys
end

-- Open for shoppers: something on a shelf.
function ShopRules.isOpen(shop): boolean
	return #ShopRules.stocked(shop) > 0
end

-- Moves units of a crop from stockroom crates onto a shelf (up to `room`),
-- grade A first. Returns units moved.
local function fill(shop, shelf, room: number): number
	local moved = 0
	for _, grade in { "A", "B" } do
		for i = #shop.stockroom, 1, -1 do
			local crate = shop.stockroom[i]
			if crate.crop == shelf.crop and crate.grade == grade and room > 0 then
				local take = math.min(room, crate.units)
				crate.units -= take
				room -= take
				moved += take
				shelf.units += take
				if grade == "A" then
					shelf.a += take
				end
				if crate.units <= 0 then
					table.remove(shop.stockroom, i)
				end
			end
		end
	end
	return moved
end

-- Stocks the shelves from the stockroom: tops up the crops already out,
-- then puts the crops with the most waiting on the empty shelves, a
-- different crop on each while there are different ones, then more of the
-- same (a stand with only Carrots fills both baskets). A crop going out for
-- the first time gets a price: the reference, rounded. Returns units moved.
function ShopRules.stock(shop, marketPrice): number
	local tier = ShopRules.tier(shop)
	local moved = 0
	local out = {}
	for i = 1, tier.shelves do
		local shelf = shop.shelves[tostring(i)]
		if shelf then
			out[shelf.crop] = true
			moved += fill(shop, shelf, tier.shelfUnits - shelf.units)
		end
	end
	for i = 1, tier.shelves do
		local key = tostring(i)
		if not shop.shelves[key] then
			local best, most = nil, 0
			for _, fresh in { true, false } do
				for cropId, units in ShopRules.stockroomUnits(shop) do
					if (not fresh or not out[cropId]) and (units > most or (units == most and best and cropId < best)) then
						best, most = cropId, units
					end
				end
				if best then
					break
				end
			end
			if not best then
				break
			end
			out[best] = true
			local shelf = { crop = best, units = 0, a = 0 }
			shop.shelves[key] = shelf
			moved += fill(shop, shelf, tier.shelfUnits)
			if not shop.prices[best] then
				ShopRules.setPrice(shop, best, ShopRules.reference(best, marketPrice(best)), marketPrice(best))
			end
		end
	end
	return moved
end

-- Takes a shelf's units back to the stockroom (as a grade A and a grade B
-- crate). Returns units moved.
function ShopRules.takeDown(shop, key: string): number
	local shelf = shop.shelves[key]
	if not shelf then
		return 0
	end
	shop.shelves[key] = nil
	local plain = BarnRules.key(shelf.crop)
	if shelf.a > 0 then
		table.insert(shop.stockroom, { crop = shelf.crop, key = plain, units = shelf.a, grade = "A" })
	end
	if shelf.units - shelf.a > 0 then
		table.insert(shop.stockroom, { crop = shelf.crop, key = plain, units = shelf.units - shelf.a, grade = "B" })
	end
	return shelf.units
end

-- Sets a crop's price, kept within 50–300% of today's reference. Returns
-- the price set.
function ShopRules.setPrice(shop, cropId: string, coins: number, market: number): number
	local low, high = DemandModel.priceRange(ShopRules.reference(cropId, market))
	local price = math.clamp(math.floor(coins + 0.5), low, high)
	shop.prices[cropId] = price
	return price
end

-- One standard normal number.
local function normal(rng): number
	local u1 = math.max(1e-9, rng:NextNumber())
	local u2 = rng:NextNumber()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

-- One shopper's visit (rng: a Random). Changes the shelves and the rating
-- and returns what happened, or nil if the shop is closed:
--   { shelf, crop, units, coins, score }   (units 0: too dear)
function ShopRules.visit(shop, rng, marketPrice)
	local stocked = ShopRules.stocked(shop)
	if #stocked == 0 then
		return nil
	end
	local key = stocked[rng:NextInteger(1, #stocked)]
	local shelf = shop.shelves[key]
	local price = shop.prices[shelf.crop] or ShopRules.reference(shelf.crop, marketPrice(shelf.crop))
	local ref = ShopRules.reference(shelf.crop, marketPrice(shelf.crop))
	local stars = ShopRules.stars(shop)
	local willing = ref * math.exp(Shop.SIGMA * normal(rng)) * (1 + DemandModel.ratingBonus(stars))
	local visit = { shelf = key, crop = shelf.crop, units = 0, coins = 0, score = Shop.SCORE_TOO_DEAR }
	if price <= willing then
		local units = math.min(rng:NextInteger(1, 4), shelf.units)
		local a = math.min(units, shelf.a)
		visit.units = units
		visit.coins = a * math.floor(price * Warehouse.GRADE_A + 0.5) + (units - a) * price
		visit.score = Shop.SCORE_BOUGHT
		shelf.units -= units
		shelf.a -= a
		if shelf.units <= 0 then
			shop.shelves[key] = nil
		end
	end
	ShopRules.addScore(shop, visit.score)
	return visit
end

return ShopRules
