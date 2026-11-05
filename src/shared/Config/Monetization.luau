-- Robux (docs/GameDesign.md §7): game passes (owned forever) and developer
-- products (bought again and again). No paid power in the PvP: passes are
-- comfort and status, products are weather the whole server shares, a
-- growth boost for your own field, and looks (Config/Cosmetics). Never sold:
-- land, defences, steal speed, reach, knockouts, worker slots, levels.
--
-- IDs come from the Creator Dashboard (Monetization > Passes / Developer
-- Products). An id of 0 isn't set up yet: hidden in a live game; in Studio
-- it shows, and Buy grants it without a purchase (for testing). `price` is
-- shown until Roblox reports the real one.
local Cosmetics = require(script.Parent.Cosmetics)
local Weather = require(script.Parent.Weather)

local Monetization = {}

Monetization.VIP_BONUS = 0.1 -- +10% coins from every truck and store sale
Monetization.BARN_MULT = 2.5 -- the Bigger Barn
Monetization.WEATHER_SECONDS = 5 * 60 -- a bought weather lasts 5 minutes
Monetization.BOOST = 2 -- the Growth Boost: your field grows ×2...
Monetization.BOOST_SECONDS = 30 * 60 -- ...for 30 minutes of play (online only)

Monetization.Passes = {
	{
		id = "VIP", name = "VIP", icon = "⭐", passId = 2068706437, price = 199, color = Color3.fromRGB(242, 179, 61),
		perks = { "+10% coins from every truck and store sale", "A gold VIP tag over your head and in chat", "VIP Gold truck paint and a gold store awning" },
	},
	{
		id = "BiggerBarn", name = "Bigger Barn", icon = "🏚️", passId = 2072390308, price = 99, color = Color3.fromRGB(200, 69, 45),
		perks = { `Your barn holds {Monetization.BARN_MULT}× as many crops`, "Fewer trips to the warehouse when your field is big" },
	},
}

-- The weather a product starts, for the whole server (Weather.TYPES).
local function weatherBlurb(id: string, extra: string?): string
	local kind = Weather.TYPES[id]
	local mutation = Weather.MUTATIONS[kind.mutation]
	local growth = if kind.growth ~= 1 then `crops grow ×{kind.growth}, and ` else ""
	return `{kind.name} on the whole server for {Monetization.WEATHER_SECONDS // 60} minutes: {growth}ripe crops can turn {kind.mutation} (worth ×{mutation.value}).{extra or ""}`
end

--   grant  what one purchase gives: { weather = id } | { boostSeconds = n } | { cosmetic = id }
Monetization.Products = {
	{ id = "RainDance", name = "Rain Dance", icon = "🌧️", productId = 0, price = 49, grant = { weather = "Rain" }, blurb = weatherBlurb("Rain") },
	{ id = "Thunderstorm", name = "Thunderstorm", icon = "⛈️", productId = 0, price = 79, grant = { weather = "Thunderstorm" }, blurb = weatherBlurb("Thunderstorm") },
	{ id = "GoldenHour", name = "Golden Hour", icon = "🌇", productId = 0, price = 99, grant = { weather = "GoldenHour" }, blurb = weatherBlurb("GoldenHour") },
	{
		id = "HarvestMoon", name = "Harvest Moon", icon = "🌕", productId = 0, price = 149, grant = { weather = "HarvestMoon" },
		blurb = weatherBlurb("HarvestMoon", " It's a Heist Night too: stealing is quicker for everyone!"),
	},
	{
		id = "GrowthBoost", name = "Growth Boost", icon = "🚀", productId = 0, price = 79, grant = { boostSeconds = Monetization.BOOST_SECONDS },
		blurb = `Your field grows ×{Monetization.BOOST} as fast for {Monetization.BOOST_SECONDS // 60} minutes of play (it waits while you're away). Buy more to add time.`,
	},
}
for _, item in Cosmetics.LIST do
	if item.price then
		table.insert(Monetization.Products, {
			id = `Cosmetic_{item.id}`, name = item.name, icon = item.icon, productId = item.productId or 0, price = item.price,
			grant = { cosmetic = item.id }, blurb = item.blurb,
		})
	end
end

Monetization.PassesById, Monetization.ProductsById, Monetization.ProductsByProductId = {}, {}, {}
for _, pass in Monetization.Passes do
	Monetization.PassesById[pass.id] = pass
end
for _, product in Monetization.Products do
	Monetization.ProductsById[product.id] = product
	if product.productId ~= 0 then
		Monetization.ProductsByProductId[product.productId] = product
	end
end

-- The product that starts a weather (its id), or nil.
function Monetization.weatherProduct(weatherId: string)
	for _, product in Monetization.Products do
		if product.grant.weather == weatherId then
			return product
		end
	end
	return nil
end

return Monetization
