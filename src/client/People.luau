-- What the valley's NPCs look like (docs/ArtDirection.md §8). The shoppers
-- in every store (ShopperController) and the farm crews (WorkerController)
-- are built on the body everyone shares (shared/PeopleArt, the townspeople
-- too). Shoppers dress it in all sorts of outfits picked from their `look`
-- number; workers wear their job's uniform (client/WorkerLooks) with their
-- own skin and hair. This only builds them: the controllers move them.
--
-- A figure's parts are entries { part, offset, limb?, sign?, pivot? }
-- (shared/PeopleArt). tools/peopledump renders them for a look before Studio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PeopleArt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PeopleArt"))
local WorkerLooks = require(script.Parent.WorkerLooks)

local People = {}

People.HIP = PeopleArt.HIP
People.SHOULDER = PeopleArt.SHOULDER

local SKIN = {
	Color3.fromRGB(255, 220, 177), Color3.fromRGB(240, 200, 160), Color3.fromRGB(234, 192, 134), Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(170, 110, 60), Color3.fromRGB(141, 85, 36), Color3.fromRGB(96, 60, 30),
}
local SHIRTS = {
	Color3.fromRGB(91, 182, 240), Color3.fromRGB(200, 69, 45), Color3.fromRGB(242, 179, 61), Color3.fromRGB(78, 159, 61),
	Color3.fromRGB(160, 92, 240), Color3.fromRGB(240, 120, 160), Color3.fromRGB(255, 244, 220), Color3.fromRGB(64, 120, 180),
	Color3.fromRGB(250, 250, 246), Color3.fromRGB(46, 160, 150),
}
local JACKETS = {
	Color3.fromRGB(52, 64, 96), Color3.fromRGB(196, 150, 60), Color3.fromRGB(60, 110, 70), Color3.fromRGB(128, 40, 52),
	Color3.fromRGB(86, 120, 170), Color3.fromRGB(170, 130, 90),
}
local DRESSES = {
	Color3.fromRGB(226, 92, 92), Color3.fromRGB(120, 180, 230), Color3.fromRGB(244, 200, 80), Color3.fromRGB(180, 150, 220),
	Color3.fromRGB(130, 200, 170), Color3.fromRGB(240, 150, 180),
}
local PANTS = {
	Color3.fromRGB(58, 72, 110), Color3.fromRGB(40, 52, 84), Color3.fromRGB(186, 160, 110), Color3.fromRGB(40, 44, 48),
	Color3.fromRGB(110, 80, 56), Color3.fromRGB(120, 124, 130),
}
local SHOES = { Color3.fromRGB(60, 44, 34), Color3.fromRGB(34, 34, 38), Color3.fromRGB(236, 236, 230), Color3.fromRGB(190, 60, 50) }
local HAIR = PeopleArt.HAIR
local GREY = PeopleArt.GREY
local DENIM = Color3.fromRGB(70, 104, 156)
local CREAM = Color3.fromRGB(255, 244, 220)
local WHITE = Color3.fromRGB(250, 250, 246)
local STRAW = Color3.fromRGB(240, 206, 128)
local WICKER, WICKER_DARK = Color3.fromRGB(196, 150, 84), Color3.fromRGB(150, 108, 58)
local SHADE = Color3.new(0, 0, 0)

local figure, body, head, hat = PeopleArt.figure, PeopleArt.body, PeopleArt.head, PeopleArt.hat

local function pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end

------------------------------------------------------------------------
-- Shoppers

-- A shopper from their `look` number (redrawn 2026-11-04, the user:
-- "Customer needs new art"): a kid, a grown-up or an old-timer; a skin
-- tone; an outfit (a tee, an open jacket, a dress, dungarees, a hoodie, an
-- old-timer's cardigan); hair (short, a bob, a bun, a ponytail, curls) and
-- maybe a cap, a sun hat or a beanie. A wicker basket in the right hand
-- that shows what they picked (hidden until then). Returns the model, its
-- parts, the torso, the basket's parts ({ all, goods, big }) and the scale.
function People.shopper(look: number)
	local rng = Random.new(look)
	local age = rng:NextNumber()
	local kind = if age < 0.18 then "kid" elseif age > 0.86 then "elder" else "adult"
	local k = if kind == "kid" then 0.72 else 1 -- (a kid is the same shape, smaller)
	local skin = pick(rng, SKIN)
	local outfit = if kind == "elder" then "cardigan" else pick(rng, { "tee", "tee", "jacket", "dress", "overalls", "hoodie" })
	local shirt = pick(rng, SHIRTS)
	local pants = pick(rng, PANTS)
	local shoe = pick(rng, SHOES)
	local hairColor = if kind == "elder" then pick(rng, GREY) else pick(rng, HAIR)
	local top = if outfit == "dress" then pick(rng, DRESSES) elseif outfit == "jacket" then pick(rng, JACKETS)
		elseif outfit == "hoodie" then pick(rng, SHIRTS) elseif outfit == "cardigan" then pick(rng, { Color3.fromRGB(150, 96, 120), Color3.fromRGB(110, 130, 100), Color3.fromRGB(176, 140, 100) })
		else shirt
	local model, parts, add = figure("Shopper", k, false)

	-- (a dress shows the legs below its hem; short sleeves on a tee, a dress or dungarees)
	local sleeve = if outfit == "tee" or outfit == "dress" or outfit == "overalls" then "short" else "long"
	local torso = body(add, {
		skin = skin, shoes = shoe, top = top, sleeve = sleeve,
		legs = if outfit == "dress" then skin elseif outfit == "overalls" then DENIM else pants,
		sleeveColor = if outfit == "overalls" then shirt else nil,
		arm = function(side)
			return if side > 0 then "basketArm" else "arm"
		end,
	})
	if outfit == "jacket" then -- open at the front: the shirt down the middle, a collar
		add("Shirt", Vector3.new(0.7, 1.9, 0.06), Vector3.new(0, 3.4, -0.52), shirt)
		add("Collar", Vector3.new(1.2, 0.2, 1.1), Vector3.new(0, 4.3, 0), top)
	elseif outfit == "dress" then -- a flared skirt to the knee
		add("Skirt", Vector3.new(2.2, 0.75, 1.2), Vector3.new(0, 2.25, 0), top)
		add("SkirtHem", Vector3.new(2.4, 0.5, 1.36), Vector3.new(0, 1.7, 0), top)
		add("Belt", Vector3.new(2.1, 0.2, 1.1), Vector3.new(0, 2.68, 0), CREAM)
	elseif outfit == "overalls" then -- the bib and straps over the shirt
		add("Bib", Vector3.new(1.3, 1.0, 0.06), Vector3.new(0, 3.0, -0.52), DENIM)
		add("Pants", Vector3.new(2.1, 0.6, 1.1), Vector3.new(0, 2.6, 0), DENIM)
		for _, x in { -0.5, 0.5 } do
			add("Strap", Vector3.new(0.26, 0.9, 1.1), Vector3.new(x, 3.95, 0), DENIM) -- (from the bib's top over the shoulder)
		end
	elseif outfit == "hoodie" then -- the hood down the back, a pocket, the strings
		add("Hood", Vector3.new(1.4, 0.8, 0.4), Vector3.new(0, 4.2, 0.62), top)
		add("Pocket", Vector3.new(1.2, 0.5, 0.06), Vector3.new(0, 2.85, -0.52), top:Lerp(SHADE, 0.12))
		for _, x in { -0.25, 0.25 } do
			add("String", Vector3.new(0.08, 0.6, 0.06), Vector3.new(x, 3.9, -0.53), WHITE)
		end
	elseif outfit == "cardigan" then -- buttons up the front
		for i = 0, 2 do
			add("Button", Vector3.new(0.16, 0.16, 0.08), Vector3.new(0, 3.95 - i * 0.55, -0.53), Color3.fromRGB(72, 48, 30))
		end
	else -- a tee with a pocket
		add("Pocket", Vector3.new(0.45, 0.45, 0.06), Vector3.new(-0.5, 3.8, -0.52), shirt:Lerp(SHADE, 0.15))
	end
	if outfit ~= "dress" and outfit ~= "overalls" then
		add("Belt", Vector3.new(2.1, 0.24, 1.1), Vector3.new(0, 2.42, 0), pants:Lerp(SHADE, 0.25))
	end
	-- the head, the hair and any hat
	local style = if kind == "elder" then pick(rng, { "short", "bun", "bald" }) else pick(rng, { "short", "short", "bob", "bun", "ponytail", "curls" })
	local hatKind = if kind == "elder" then pick(rng, { "none", "none", "sunhat", "cap" }) else pick(rng, { "none", "none", "none", "cap", "sunhat", "beanie" })
	head(add, skin, style, hairColor, hatKind ~= "none")
	if hatKind == "cap" then
		hat(add, "cap", pick(rng, SHIRTS))
	elseif hatKind == "sunhat" then
		hat(add, "sunhat", STRAW, pick(rng, DRESSES))
	elseif hatKind == "beanie" then
		hat(add, "beanie", pick(rng, JACKETS))
	end

	-- the basket in the right hand (shown once there's something in it)
	local carry = { limb = "basketArm", sign = 1, pivot = Vector3.new(1.5, People.SHOULDER, 0) }
	local all = {}
	local function basketPart(name, size, at, color, shape)
		local p = add(name, size, at, color, { shape = shape, limb = carry.limb, sign = carry.sign, pivot = carry.pivot })
		p.Transparency = 1
		table.insert(all, p)
		return p
	end
	local hand = if sleeve == "short" then 2.25 else 2.3
	basketPart("Basket", Vector3.new(1.3, 0.75, 0.95), Vector3.new(1.5, hand - 0.95, -0.25), WICKER)
	basketPart("BasketRim", Vector3.new(1.4, 0.14, 1.05), Vector3.new(1.5, hand - 0.55, -0.25), WICKER_DARK)
	for _, z in { -0.66, 0.16 } do
		basketPart("Handle", Vector3.new(0.12, 0.55, 0.12), Vector3.new(1.5, hand - 0.25, z), WICKER_DARK)
	end
	basketPart("HandleTop", Vector3.new(0.12, 0.12, 0.94), Vector3.new(1.5, hand + 0.02, -0.25), WICKER_DARK)
	local goods = {}
	for i, at in { Vector3.new(1.25, hand - 0.4, -0.45), Vector3.new(1.72, hand - 0.38, -0.12), Vector3.new(1.55, hand - 0.32, -0.5) } do
		table.insert(goods, basketPart(`Good{i}`, Vector3.new(0.42, 0.42, 0.42), at, Color3.fromRGB(240, 130, 40), Enum.PartType.Ball))
	end
	local big = basketPart("GoodBig", Vector3.new(0.85, 0.85, 0.85), Vector3.new(1.5, hand - 0.3, -0.25), Color3.fromRGB(236, 130, 40), Enum.PartType.Ball)
	return model, parts, torso, { all = all, goods = goods, big = big }, k
end

------------------------------------------------------------------------
-- Workers

-- A worker in their job's uniform (client/WorkerLooks; 2026-11-05, given
-- the shoppers' body: "continue with the art for the workers"): their skin
-- from `look` (1–8), their hair from `look` and `seed` (so two with the
-- same look aren't twins; a few are going grey). Grown-ups, life size, with
-- shadows (they work out in the sun). Returns the model, its parts, `add`
-- (for the controller's own props: what they carry, the strike sign) and
-- the torso.
function People.worker(typeName: string, look: number, seed: number)
	local u = WorkerLooks.TYPES[typeName] or WorkerLooks.TYPES.Packer
	local skin = WorkerLooks.SKIN[(look - 1) % #WorkerLooks.SKIN + 1]
	local rng = Random.new(look * 7919 + seed)
	local older = rng:NextNumber() < 0.15
	local hairColor = if older then pick(rng, GREY) else pick(rng, HAIR)
	local style = if older then pick(rng, { "short", "bun", "bald" }) else pick(rng, { "short", "short", "bob", "bun", "ponytail", "curls" })
	local model, parts, add = figure("Worker", 1, true)
	local torso = PeopleArt.dress(add, u, skin)
	head(add, skin, style, hairColor, u.hat ~= nil)
	if u.hat then
		hat(add, u.hat, u.hatColor, u.hatTrim)
	end
	return model, parts, add, torso
end

return People
