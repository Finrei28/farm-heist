-- How NPC shoppers react to the prices you set in your store
-- (docs/GameDesign.md §4.8). Each shopper has a willingness to pay w,
-- log-normal around 1 (σ = Shop.SIGMA), lifted by your Store Rating, the
-- display's presentation and grade A. They buy if
--   yourPrice ≤ ref × w × (1 + rating bonus) × presentation × (grade A ? 1.15 : 1)
-- where ref = ½ base + ½ today's market price: shoppers half-remember the
-- usual price, so when the market crashes your store pays better than the
-- truck, and when it spikes the truck does. tests/demand.test.luau.
local Shop = require(script.Parent.Config.Shop)

local DemandModel = {}

-- The reference price shoppers judge you by.
function DemandModel.reference(base: number, market: number): number
	return Shop.REF_BASE * base + (1 - Shop.REF_BASE) * market
end

-- +0 at 1★ up to +RATING_BONUS at 5★.
function DemandModel.ratingBonus(stars: number): number
	return Shop.RATING_BONUS * (math.clamp(stars, 1, 5) - 1) / 4
end

-- The error function (Abramowitz & Stegun 7.1.26, good to 1.5e-7).
local function erf(x: number): number
	local t = 1 / (1 + 0.3275911 * math.abs(x))
	local y = 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * math.exp(-x * x)
	return if x >= 0 then y else -y
end

-- The standard normal CDF.
function DemandModel.phi(z: number): number
	return 0.5 * (1 + erf(z / math.sqrt(2)))
end

-- The chance one shopper buys at `price` (0–1), at a display with this
-- presentation (default 1).
function DemandModel.buyChance(price: number, ref: number, stars: number, gradeA: boolean?, present: number?): number
	if price <= 0 then
		return 1
	end
	local lift = ref * (1 + DemandModel.ratingBonus(stars)) * (if gradeA then Shop.GRADE_A else 1) * (present or 1)
	return 1 - DemandModel.phi(math.log(price / lift) / Shop.SIGMA)
end

-- The prices you may set for a crop: 50–300% of the reference.
function DemandModel.priceRange(ref: number): (number, number)
	return math.max(1, math.floor(ref * Shop.PRICE_MIN + 0.5)), math.floor(ref * Shop.PRICE_MAX + 0.5)
end

-- Seconds between shoppers at a Store Level and rating (before variety and
-- the billboard: ShopRules.interval).
function DemandModel.shopperInterval(level: number, stars: number): number
	local base = Shop.INTERVAL * Shop.INTERVAL_DECAY ^ (math.max(1, level) - 1)
	return base / (1 + Shop.FLOW_PER_STAR * (math.clamp(stars, 1, 5) - 3))
end

-- Units of a crop sold a minute, on average: `shoppers` a minute, `share`
-- of them wanting it, each buying with this chance.
function DemandModel.salesPerMinute(chance: number, shoppers: number, share: number): number
	return shoppers * share * Shop.UNITS_PER_SHOPPER * chance
end

-- The demand face on a price tag.
function DemandModel.face(chance: number): string
	if chance > 0.7 then
		return "😀"
	elseif chance > 0.45 then
		return "🙂"
	elseif chance > 0.2 then
		return "😐"
	end
	return "😟"
end

return DemandModel
