-- Draws the NPC shoppers in every store (docs/ArtDirection.md §8) from the
-- ShopperEvent remote (StoreService decides what they do). Each "Path" is a
-- walk from server time `at` through world points at Shop.SPEED, replacing
-- the last one: along the sidewalk, through the door, down the aisles to a
-- display, into a checkout queue, out again. They say what happened in a
-- bubble ("🥕×3", "Too dear!"), their basket fills with what they picked,
-- and a coin pop shows when they pay. Roblox-shaped people in all sorts of
-- outfits (below), made of local parts: nothing here matters to the game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local Shop = require(Shared.Config.Shop)
local Sfx = require(script.Parent.Parent.Sfx)

local ShopperController = {}

-- Who comes shopping (docs/ArtDirection.md §8; redrawn 2026-11-04, the
-- user: "Customer needs new art"): Roblox-shaped people (the classic head
-- with a face, blocky arms and legs with hands and shoes), each picked from
-- `look`: a kid, a grown-up or an old-timer; a skin tone; an outfit (a tee,
-- an open jacket, a dress, dungarees, a hoodie, an old-timer's cardigan);
-- hair (short, a bob, a bun, a ponytail, curls) and maybe a cap, a sun hat
-- or a beanie. They carry a wicker basket that shows what they picked.
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
local HAIR = { Color3.fromRGB(40, 30, 26), Color3.fromRGB(84, 56, 36), Color3.fromRGB(130, 88, 52), Color3.fromRGB(222, 184, 104), Color3.fromRGB(176, 88, 40) }
local GREY = { Color3.fromRGB(196, 196, 196), Color3.fromRGB(236, 236, 232) }
local WICKER, WICKER_DARK = Color3.fromRGB(196, 150, 84), Color3.fromRGB(150, 108, 58)
-- What a basket shows: each crop's colour (big ones fill it alone).
local PRODUCE = {
	Carrot = Color3.fromRGB(240, 130, 40), Wheat = Color3.fromRGB(232, 196, 96), Potato = Color3.fromRGB(196, 150, 96),
	Lettuce = Color3.fromRGB(120, 190, 80), Corn = Color3.fromRGB(246, 206, 70), Onion = Color3.fromRGB(200, 140, 90),
	Strawberry = Color3.fromRGB(220, 50, 60), Tomato = Color3.fromRGB(226, 64, 48), BellPepper = Color3.fromRGB(220, 60, 40),
	Pumpkin = Color3.fromRGB(236, 130, 40), Watermelon = Color3.fromRGB(70, 140, 60), Blueberry = Color3.fromRGB(70, 90, 190),
	Pineapple = Color3.fromRGB(232, 190, 60), CocoaPod = Color3.fromRGB(150, 90, 50), Dragonfruit = Color3.fromRGB(230, 70, 140),
	GrapeVine = Color3.fromRGB(120, 60, 140), Moonmelon = Color3.fromRGB(200, 220, 255), Starfruit = Color3.fromRGB(250, 220, 80),
	GoldenApple = Color3.fromRGB(250, 200, 60), CrystalRose = Color3.fromRGB(160, 220, 255), PhoenixPepper = Color3.fromRGB(255, 120, 40),
	DragonsEyePumpkin = Color3.fromRGB(180, 40, 60),
}
local BIG = { Pumpkin = true, Watermelon = true, Moonmelon = true, DragonsEyePumpkin = true }
local FADE = 1
local CULL = 300 -- studs from the camera: farther shoppers aren't drawn (a busy Supermarket has 24, and there are 8 stores)

local folder = Instance.new("Folder")
folder.Name = "Shoppers"
local shoppers = {} -- [id] = shopper

local function piece(model: Model, name: string, size: Vector3, color: Color3, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Shape = shape or Enum.PartType.Block
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- A Roblox-shaped head (the classic head mesh) or hair shaped like one.
local function headShape(p: BasePart)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1, 1, 1)
	mesh.Parent = p
end

local function pick(rng: Random, list)
	return list[rng:NextInteger(1, #list)]
end

-- A shopper from their `look` number. Parts are { part, offset (from the
-- feet; the model faces −Z), limb?, sign?, pivot? }: limbs swing about their
-- pivot as they walk (legs, arms; the basket arm only a little).
local function build(look: number)
	local rng = Random.new(look)
	local model = Instance.new("Model")
	model.Name = "Shopper"
	local age = rng:NextNumber()
	local kind = if age < 0.18 then "kid" elseif age > 0.86 then "elder" else "adult"
	local k = if kind == "kid" then 0.72 else 1 -- (a kid is the same shape, smaller)
	local skin = pick(rng, SKIN)
	local outfit = if kind == "elder" then "cardigan" else pick(rng, { "tee", "tee", "jacket", "dress", "overalls", "hoodie" })
	local shirt = pick(rng, SHIRTS)
	local pants = pick(rng, PANTS)
	local shoe = pick(rng, SHOES)
	local hairColor = if kind == "elder" then pick(rng, GREY) else pick(rng, HAIR)
	local parts = {}
	local function add(name, size, at, color, extra)
		local p = piece(model, name, size * k, color, extra and extra.shape)
		local entry = { p, CFrame.new(at * k) * (extra and extra.turn or CFrame.identity) }
		if extra and extra.limb then
			entry[3], entry[4], entry[5] = extra.limb, extra.sign, extra.pivot * k
		end
		table.insert(parts, entry)
		return p
	end
	local hip, shoulder = Vector3.new(0, 2.35, 0), Vector3.new(0, 4.3, 0)

	-- legs and shoes (a dress shows the legs below its hem)
	local legColor = if outfit == "dress" then skin elseif outfit == "overalls" then Color3.fromRGB(70, 104, 156) else pants
	for _, side in { -1, 1 } do
		local x = side * 0.5
		local leg = { limb = "leg", sign = side, pivot = Vector3.new(x, hip.Y, 0) }
		add("Leg", Vector3.new(0.92, 2.0, 0.92), Vector3.new(x, 1.35, 0), legColor, leg)
		add("Shoe", Vector3.new(0.96, 0.36, 1.16), Vector3.new(x, 0.18, -0.1), shoe, leg)
	end
	-- the body
	local top = if outfit == "dress" then pick(rng, DRESSES) elseif outfit == "jacket" then pick(rng, JACKETS)
		elseif outfit == "hoodie" then pick(rng, SHIRTS) elseif outfit == "cardigan" then pick(rng, { Color3.fromRGB(150, 96, 120), Color3.fromRGB(110, 130, 100), Color3.fromRGB(176, 140, 100) })
		else shirt
	add("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3.35, 0), top)
	if outfit == "jacket" then -- open at the front: the shirt down the middle, a collar
		add("Shirt", Vector3.new(0.7, 1.9, 0.06), Vector3.new(0, 3.4, -0.52), shirt)
		add("Collar", Vector3.new(1.2, 0.2, 1.06), Vector3.new(0, 4.3, 0), top)
	elseif outfit == "dress" then -- a flared skirt to the knee
		add("Skirt", Vector3.new(2.2, 0.75, 1.2), Vector3.new(0, 2.25, 0), top)
		add("SkirtHem", Vector3.new(2.4, 0.5, 1.36), Vector3.new(0, 1.7, 0), top)
		add("Belt", Vector3.new(2.06, 0.2, 1.06), Vector3.new(0, 2.68, 0), Color3.fromRGB(255, 244, 220))
	elseif outfit == "overalls" then -- the bib and straps over the shirt
		add("Bib", Vector3.new(1.3, 1.0, 0.06), Vector3.new(0, 3.0, -0.52), Color3.fromRGB(70, 104, 156))
		add("Pants", Vector3.new(2.04, 0.6, 1.04), Vector3.new(0, 2.6, 0), Color3.fromRGB(70, 104, 156))
		for _, x in { -0.5, 0.5 } do
			add("Strap", Vector3.new(0.26, 1.0, 1.06), Vector3.new(x, 3.85, 0), Color3.fromRGB(70, 104, 156))
		end
	elseif outfit == "hoodie" then -- the hood down the back, a pocket, the strings
		add("Hood", Vector3.new(1.4, 0.8, 0.4), Vector3.new(0, 4.2, 0.62), top)
		add("Pocket", Vector3.new(1.2, 0.5, 0.06), Vector3.new(0, 2.85, -0.52), top:Lerp(Color3.new(0, 0, 0), 0.12))
		for _, x in { -0.25, 0.25 } do
			add("String", Vector3.new(0.08, 0.6, 0.06), Vector3.new(x, 3.9, -0.53), Color3.fromRGB(250, 250, 246))
		end
	elseif outfit == "cardigan" then -- buttons up the front
		for i = 0, 2 do
			add("Button", Vector3.new(0.16, 0.16, 0.08), Vector3.new(0, 3.95 - i * 0.55, -0.53), Color3.fromRGB(72, 48, 30))
		end
	else -- a tee with a pocket
		add("Pocket", Vector3.new(0.45, 0.45, 0.06), Vector3.new(-0.5, 3.8, -0.52), shirt:Lerp(Color3.new(0, 0, 0), 0.15))
	end
	if outfit ~= "dress" and outfit ~= "overalls" then
		add("Belt", Vector3.new(2.04, 0.22, 1.04), Vector3.new(0, 2.46, 0), pants:Lerp(Color3.new(0, 0, 0), 0.25))
	end
	-- arms and hands (a jacket's or hoodie's sleeves; short sleeves on a tee or a dress)
	local sleeve = if outfit == "tee" or outfit == "dress" or outfit == "overalls" then "short" else "long"
	for _, side in { -1, 1 } do
		local x = side * 1.5
		local arm = { limb = if side > 0 then "basketArm" else "arm", sign = side, pivot = Vector3.new(x, shoulder.Y, 0) }
		if sleeve == "short" then
			add("Sleeve", Vector3.new(1.02, 0.8, 1.02), Vector3.new(x, 3.95, 0), if outfit == "overalls" then shirt else top, arm)
			add("Arm", Vector3.new(0.92, 1.3, 0.92), Vector3.new(x, 3.0, 0), skin, arm)
		else
			add("Arm", Vector3.new(1, 1.9, 1), Vector3.new(x, 3.4, 0), top, arm)
			add("Hand", Vector3.new(0.86, 0.36, 0.86), Vector3.new(x, 2.3, 0), skin, arm)
		end
	end
	-- the head, its face, the hair and any hat
	local head = add("Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 4.95, 0), skin)
	headShape(head)
	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head
	local style = if kind == "elder" then pick(rng, { "short", "bun", "bald" }) else pick(rng, { "short", "short", "bob", "bun", "ponytail", "curls" })
	local hat = if kind == "elder" then pick(rng, { "none", "none", "sunhat", "cap" }) else pick(rng, { "none", "none", "none", "cap", "sunhat", "beanie" })
	if style == "bald" then -- a fringe of hair round the back
		add("Hair", Vector3.new(1.42, 0.5, 0.5), Vector3.new(0, 4.85, 0.48), hairColor)
	else
		local hair = add("Hair", Vector3.new(1.42, 1.32, 1.42), Vector3.new(0, 5.13, 0.24), hairColor) -- (over the top and back, the face clear)
		headShape(hair)
		if style == "bob" then
			for _, x in { -0.62, 0.62 } do
				add("HairSide", Vector3.new(0.28, 0.95, 1.0), Vector3.new(x, 4.75, 0.12), hairColor)
			end
		elseif style == "bun" then
			add("Bun", Vector3.new(0.7, 0.7, 0.7), Vector3.new(0, 5.75, 0.32), hairColor, { shape = Enum.PartType.Ball })
		elseif style == "ponytail" then
			add("Ponytail", Vector3.new(0.42, 1.0, 0.42), Vector3.new(0, 4.75, 0.85), hairColor, { turn = CFrame.Angles(math.rad(-18), 0, 0) })
		elseif style == "curls" then
			for i = 0, 4 do
				local a = math.rad(-60 + i * 30)
				add("Curl", Vector3.new(0.55, 0.55, 0.55), Vector3.new(math.sin(a) * 0.6, 5.45, 0.2 + math.cos(a) * 0.3), hairColor, { shape = Enum.PartType.Ball })
			end
		end
	end
	if hat == "cap" then
		local color = pick(rng, SHIRTS)
		local cap = add("Cap", Vector3.new(1.46, 0.9, 1.46), Vector3.new(0, 5.42, 0.05), color)
		headShape(cap)
		add("Peak", Vector3.new(1.1, 0.12, 0.7), Vector3.new(0, 5.4, -0.8), color)
	elseif hat == "sunhat" then
		local straw = Color3.fromRGB(240, 206, 128)
		add("Brim", Vector3.new(0.12, 2.5, 2.5), Vector3.new(0, 5.5, 0), straw, { shape = Enum.PartType.Cylinder, turn = CFrame.Angles(0, 0, math.rad(90)) })
		add("Crown", Vector3.new(0.6, 1.4, 1.4), Vector3.new(0, 5.82, 0), straw, { shape = Enum.PartType.Cylinder, turn = CFrame.Angles(0, 0, math.rad(90)) })
		add("Ribbon", Vector3.new(0.16, 1.44, 1.44), Vector3.new(0, 5.62, 0), pick(rng, DRESSES), { shape = Enum.PartType.Cylinder, turn = CFrame.Angles(0, 0, math.rad(90)) })
	elseif hat == "beanie" then
		local color = pick(rng, JACKETS)
		local beanie = add("Beanie", Vector3.new(1.46, 1.0, 1.46), Vector3.new(0, 5.5, 0.08), color)
		headShape(beanie)
		add("Pompom", Vector3.new(0.45, 0.45, 0.45), Vector3.new(0, 6.0, 0.08), Color3.fromRGB(250, 250, 246), { shape = Enum.PartType.Ball })
	end

	-- the basket in the right hand (shown once there's something in it)
	local carry = { limb = "basketArm", sign = 1, pivot = Vector3.new(1.5, shoulder.Y, 0) }
	local basket = {}
	local function basketPart(name, size, at, color, shape)
		local p = add(name, size, at, color, { shape = shape, limb = carry.limb, sign = carry.sign, pivot = carry.pivot })
		p.Transparency = 1
		table.insert(basket, p)
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
		local good = basketPart(`Good{i}`, Vector3.new(0.42, 0.42, 0.42), at, PRODUCE.Carrot, Enum.PartType.Ball)
		table.insert(goods, good)
	end
	local big = basketPart("GoodBig", Vector3.new(0.85, 0.85, 0.85), Vector3.new(1.5, hand - 0.3, -0.25), PRODUCE.Pumpkin, Enum.PartType.Ball)

	local bubble = Instance.new("BillboardGui")
	bubble.Size = UDim2.fromScale(6, 1.6)
	bubble.StudsOffsetWorldSpace = Vector3.new(0, 4.1 * k, 0) -- (under a Corner Store's 10-stud ceiling)
	bubble.MaxDistance = 90
	bubble.Enabled = false
	bubble.Adornee = parts[5][1] -- (the torso)
	for _, entry in parts do
		if entry[1].Name == "Torso" then
			bubble.Adornee = entry[1]
		end
	end
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(255, 244, 220)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(58, 42, 28)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = label
	label.Parent = bubble
	bubble.Parent = model
	model.Parent = folder
	return model, parts, bubble, label, { all = basket, goods = goods, big = big }
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- A bubble's colour by what they said: pleased green, cross red, else cream.
local MOOD = { good = Color3.fromRGB(214, 240, 196), bad = Color3.fromRGB(255, 206, 196) }
local TURN = math.rad(540) -- how fast they turn round (degrees a second): never a snap

local function say(shopper, text: string, color: Color3?)
	shopper.label.Text = text
	shopper.label.BackgroundColor3 = color or Color3.fromRGB(255, 244, 220)
	shopper.bubble.Enabled = true
	shopper.sayToken += 1
	local token = shopper.sayToken
	task.delay(2.6, function()
		if shopper.sayToken == token then
			shopper.bubble.Enabled = false
		end
	end)
end

-- The basket shows once there's something in it: a few of the crop, or one
-- big one (a pumpkin, a melon).
local function fillBasket(shopper, units: number, crop: string?)
	local basket, hidden = shopper.basket, shopper.hidden
	local has = units > 0
	local big = crop ~= nil and BIG[crop] == true
	local color = PRODUCE[crop or ""] or PRODUCE.Carrot
	for _, p in basket.all do
		hidden[p] = not has
	end
	for i, p in basket.goods do
		hidden[p] = not has or big or (i == 3 and units < 12)
		p.Color = color
	end
	hidden[basket.big] = not has or not big
	basket.big.Color = color
end

local function path(event)
	local shopper = shoppers[event.id]
	if not shopper then
		local model, parts, bubble, label, basket = build(event.look)
		shopper = { model = model, parts = parts, bubble = bubble, label = label, basket = basket, hidden = {}, plot = event.plot, sayToken = 0,
			phase = (event.look % 17) / 17 * math.pi * 2, list = {}, cframes = {} }
		for _, entry in parts do
			table.insert(shopper.list, entry[1])
		end
		shoppers[event.id] = shopper
	end
	shopper.points = event.points
	shopper.at = event.at
	shopper.length = PlotLayout.pathLength(event.points)
	shopper.face = event.face
	shopper.leave = event.leave == true
	fillBasket(shopper, event.basket or 0, event.crop)
	if event.say then
		say(shopper, event.say, MOOD[event.mood or ""])
	end
end

local function paid(event)
	local shopper = shoppers[event.id]
	if shopper and event.coins > 0 then
		say(shopper, `+{Format.number(event.coins)}`, Color3.fromRGB(242, 179, 61))
		if event.plot == Players.LocalPlayer:GetAttribute("Plot") then -- (your own store's sales)
			Sfx.play("Coins", shopper.model.PrimaryPart or shopper.model:FindFirstChildWhichIsA("BasePart"))
		end
	end
end

local function clear(event)
	for id, shopper in shoppers do
		if shopper.plot == event.plot then
			shopper.model:Destroy()
			shoppers[id] = nil
		end
	end
end

local function step(dt: number)
	local t = now()
	local eye = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or Vector3.zero
	for id, shopper in shoppers do
		local walked = math.max(0, (t - shopper.at) * Shop.SPEED)
		local walking = walked > 0 and walked < shopper.length
		if (shopper.leave and walked >= shopper.length + FADE * Shop.SPEED) or t - shopper.at > 240 then
			shopper.model:Destroy()
			shoppers[id] = nil
			continue
		end
		local position, direction = PlotLayout.along(shopper.points, math.min(walked, shopper.length))
		local near = (position - eye).Magnitude < CULL
		shopper.model.Parent = if near then folder else nil
		if not near then
			continue
		end
		-- Which way they face: along the walk while walking; once there, toward
		-- what they came for (`face`); and before their next walk starts (still
		-- choosing at a shelf, the walk to the queue already sent) the way they
		-- already faced: they used to turn to the till while still picking.
		local want = nil
		if walking then
			want = Vector3.new(direction.X, 0, direction.Z)
		elseif t >= shopper.at then
			local toward = if shopper.face and not shopper.leave then shopper.face - position else direction
			want = Vector3.new(toward.X, 0, toward.Z)
		end
		local heading = shopper.heading
		if want and want.Magnitude > 0.01 then
			want = want.Unit
			if not heading then
				heading = want
			else -- (turned toward it a little at a time, not snapped round)
				local angle = math.atan2(heading:Cross(want).Y, heading:Dot(want))
				local most = TURN * dt
				heading = CFrame.Angles(0, math.clamp(angle, -most, most), 0):VectorToWorldSpace(heading)
			end
		end
		heading = heading or Vector3.zAxis
		shopper.heading = heading
		local beat = t * 9 + shopper.phase
		local swing = if walking then math.sin(beat) * math.rad(26) else 0
		local bob = if walking then math.abs(math.sin(beat)) * 0.08 else 0
		local feet = CFrame.lookAt(position, position + heading) + Vector3.new(0, bob, 0)
		local fade = if shopper.leave then math.clamp((walked - shopper.length) / (FADE * Shop.SPEED), 0, 1) else 0
		local cframes, hidden = shopper.cframes, shopper.hidden
		for i, entry in shopper.parts do
			local p, offset, limb = entry[1], entry[2], entry[3]
			local pose = offset
			if limb then -- (legs swing; each arm against its leg; the basket arm only a little)
				local angle = if limb == "leg" then swing * entry[4] elseif limb == "arm" then -swing * entry[4] * 0.8 else -swing * entry[4] * 0.2
				local pivot = entry[5]
				pose = CFrame.new(pivot) * CFrame.Angles(angle, 0, 0) * CFrame.new(-pivot) * offset
			end
			cframes[i] = feet * pose
			local transparency = if hidden[p] then 1 else fade
			if p.Transparency ~= transparency then
				p.Transparency = transparency
				local face = p:FindFirstChild("Face")
				if face then
					face.Transparency = transparency
				end
			end
		end
		workspace:BulkMoveTo(shopper.list, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function ShopperController.Start()
	folder.Parent = workspace
	Remotes.event("ShopperEvent").OnClientEvent:Connect(function(kind, event)
		if kind == "Path" then
			path(event)
		elseif kind == "Paid" then
			paid(event)
		elseif kind == "Clear" then
			clear(event)
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return ShopperController
