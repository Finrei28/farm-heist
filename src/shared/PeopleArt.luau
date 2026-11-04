-- The Roblox-shaped body every person in the valley shares (docs/ArtDirection
-- §8): the classic head with a face, blocky arms and legs with hands and
-- shoes, hair as a head-shaped shell over the top and back (the face left
-- clear), hats, and the work clothes that go over the shirt. Built on either
-- side: the clients dress shoppers and farm crews in it (client/People), the
-- server stands the townspeople in it (World/TownArt: Barley, Patty). Plain
-- anchored parts nothing collides with.
--
-- A figure's parts are entries { part, offset, limb?, sign?, pivot? }: the
-- offset from the feet (the figure faces −Z, its right hand at +X); a limb
-- swings about its pivot (the hip or the shoulder), `sign` its side (−1
-- left, 1 right). tools/peopledump renders them for a look before Studio.
--
-- Layers (a belt, a bib, a strap) stand at least 0.05 off what they cover:
-- closer, the depth buffer takes them for one plane and they flicker from
-- afar (tests/lib/zfight, which checks the townspeople).
local PeopleArt = {}

PeopleArt.HIP = 2.35 -- (from the feet: where the legs swing from)
PeopleArt.SHOULDER = 4.3 -- (where the arms swing from)

PeopleArt.HAIR = { Color3.fromRGB(40, 30, 26), Color3.fromRGB(84, 56, 36), Color3.fromRGB(130, 88, 52), Color3.fromRGB(222, 184, 104), Color3.fromRGB(176, 88, 40) }
PeopleArt.GREY = { Color3.fromRGB(196, 196, 196), Color3.fromRGB(236, 236, 232) }

local WHITE = Color3.fromRGB(250, 250, 246)
local BRASS = Color3.fromRGB(226, 180, 72)
local DARK = Color3.fromRGB(44, 40, 38)
local BOOTS = Color3.fromRGB(60, 44, 34)
local SHADE = Color3.new(0, 0, 0)

local function piece(model: Model, name: string, size: Vector3, color: Color3, shape: Enum.PartType?, shadow: boolean)
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
	p.CastShadow = shadow
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- A Roblox-shaped head (the classic head mesh) or hair shaped like one.
function PeopleArt.headShape(p: BasePart)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1, 1, 1)
	mesh.Parent = p
end
local headShape = PeopleArt.headShape

-- A new figure, `k` times life size: its model, its parts and `add(name,
-- size, at, color, extra?)`, which makes a part at `at` from the feet (extra:
-- shape, turn, and limb, sign, pivot for a part that swings). `shadow`: its
-- parts cast shadows.
function PeopleArt.figure(name: string, k: number, shadow: boolean)
	local model = Instance.new("Model")
	model.Name = name
	local parts = {}
	local function add(partName: string, size: Vector3, at: Vector3, color: Color3, extra: any?)
		local p = piece(model, partName, size * k, color, extra and extra.shape, shadow)
		local entry = { p, CFrame.new(at * k) * (extra and extra.turn or CFrame.identity) }
		if extra and extra.limb then
			entry[3], entry[4] = extra.limb, extra.sign
			entry[5] = if extra.pivot then extra.pivot * k else nil
		end
		table.insert(parts, entry)
		return p
	end
	return model, parts, add
end

-- The body: legs in shoes, the torso, and arms in long sleeves with hands
-- or bare from short ones. o = { skin, legs, shoes, top, sleeve = "short" |
-- "long", sleeveColor? (else the top's), gloves? (the hands' colour), arm?
-- (side → its limb's name; "arm") }. Returns the torso.
function PeopleArt.body(add, o)
	for _, side in { -1, 1 } do
		local x = side * 0.5
		local leg = { limb = "leg", sign = side, pivot = Vector3.new(x, PeopleArt.HIP, 0) }
		add("Leg", Vector3.new(0.92, 2.0, 0.92), Vector3.new(x, 1.35, 0), o.legs, leg)
		add("Shoe", Vector3.new(0.96, 0.36, 1.16), Vector3.new(x, 0.18, -0.1), o.shoes, leg)
	end
	local torso = add("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3.35, 0), o.top)
	for _, side in { -1, 1 } do
		local x = side * 1.5
		local arm = { limb = if o.arm then o.arm(side) else "arm", sign = side, pivot = Vector3.new(x, PeopleArt.SHOULDER, 0) }
		if o.sleeve == "short" then
			add("Sleeve", Vector3.new(1.02, 0.8, 1.02), Vector3.new(x, 3.95, 0), o.sleeveColor or o.top, arm)
			add("Arm", Vector3.new(0.92, 1.3, 0.92), Vector3.new(x, 3.0, 0), o.skin, arm)
			if o.gloves then -- (over the hand: rubber or work gloves)
				add("Glove", Vector3.new(1.02, 0.55, 1.02), Vector3.new(x, 2.6, 0), o.gloves, arm)
			end
		else
			add("Arm", Vector3.new(1, 1.9, 1), Vector3.new(x, 3.4, 0), o.sleeveColor or o.top, arm)
			add("Hand", Vector3.new(0.86, 0.36, 0.86), Vector3.new(x, 2.3, 0), o.gloves or o.skin, arm)
		end
	end
	return torso
end

-- The head with its face, and hair: "short", "bob", "bun", "ponytail",
-- "curls" or "bald" (a fringe round the back). Under a hat a bun sits low at
-- the nape (on top it poked out through a cap like a ball).
function PeopleArt.head(add, skin: Color3, style: string, hairColor: Color3, hatted: boolean)
	local h = add("Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 4.95, 0), skin)
	headShape(h)
	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = h
	if style == "bald" then
		add("Hair", Vector3.new(1.42, 0.5, 0.5), Vector3.new(0, 4.85, 0.48), hairColor)
		return h
	end
	local hair = add("Hair", Vector3.new(1.42, 1.32, 1.42), Vector3.new(0, 5.13, 0.24), hairColor) -- (over the top and back, the face clear)
	headShape(hair)
	if style == "bob" then
		for _, x in { -0.62, 0.62 } do
			add("HairSide", Vector3.new(0.28, 0.95, 1.0), Vector3.new(x, 4.75, 0.12), hairColor)
		end
	elseif style == "bun" and hatted then
		add("Bun", Vector3.new(0.6, 0.6, 0.6), Vector3.new(0, 4.92, 0.92), hairColor, { shape = Enum.PartType.Ball })
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
	return h
end

-- A hat in `color` (trim: a straw hat's band, a beanie's pompom, a peaked
-- cap's badge): "cap", "sunhat" (straw), "beanie", "hard" (a hard hat),
-- "peaked" (a guard's cap). Caps, beanies and hard hats sit high and tipped
-- back, their front edge above the face's eyes (the classic face's eyes are
-- about 5.15 from the feet; seen in Studio 2026-11-05, a cap at 5.42 hid them).
function PeopleArt.hat(add, kind: string, color: Color3, trim: Color3?)
	local lying = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder standing up)
	local facing = CFrame.Angles(0, math.rad(90), 0) -- (a cylinder facing front)
	local back = CFrame.Angles(math.rad(10), 0, 0) -- (tipped back: the front edge up)
	if kind == "cap" then
		local cap = add("Cap", Vector3.new(1.46, 0.9, 1.46), Vector3.new(0, 5.56, 0.08), color, { turn = back })
		headShape(cap)
		add("Peak", Vector3.new(1.1, 0.12, 0.72), Vector3.new(0, 5.42, -0.86), color)
	elseif kind == "sunhat" then
		add("Brim", Vector3.new(0.12, 2.5, 2.5), Vector3.new(0, 5.5, 0), color, { shape = Enum.PartType.Cylinder, turn = lying })
		add("Crown", Vector3.new(0.6, 1.4, 1.4), Vector3.new(0, 5.82, 0), color, { shape = Enum.PartType.Cylinder, turn = lying })
		add("Ribbon", Vector3.new(0.16, 1.44, 1.44), Vector3.new(0, 5.62, 0), trim or color, { shape = Enum.PartType.Cylinder, turn = lying })
	elseif kind == "beanie" then
		local beanie = add("Beanie", Vector3.new(1.46, 1.0, 1.46), Vector3.new(0, 5.64, 0.1), color, { turn = back })
		headShape(beanie)
		add("Pompom", Vector3.new(0.45, 0.45, 0.45), Vector3.new(0, 6.14, 0.18), trim or WHITE, { shape = Enum.PartType.Ball })
	elseif kind == "hard" then -- a dome with a brim all round and a ridge over the top
		local shell = add("HardHat", Vector3.new(1.56, 1.0, 1.56), Vector3.new(0, 5.7, 0.03), color)
		headShape(shell)
		add("HatBrim", Vector3.new(0.1, 1.84, 1.84), Vector3.new(0, 5.4, 0.03), color, { shape = Enum.PartType.Cylinder, turn = lying })
		add("HatRidge", Vector3.new(0.26, 0.16, 1.3), Vector3.new(0, 6.17, 0.03), color:Lerp(SHADE, 0.08))
	elseif kind == "peaked" then -- a band, a flat top, a black peak and a badge
		add("CapBand", Vector3.new(0.34, 1.42, 1.42), Vector3.new(0, 5.4, 0), color, { shape = Enum.PartType.Cylinder, turn = lying })
		add("CapTop", Vector3.new(0.22, 1.66, 1.66), Vector3.new(0, 5.66, 0.02), color, { shape = Enum.PartType.Cylinder, turn = lying })
		add("Peak", Vector3.new(1.0, 0.1, 0.5), Vector3.new(0, 5.26, -0.82), DARK)
		add("CapBadge", Vector3.new(0.3, 0.3, 0.06), Vector3.new(0, 5.42, -0.72), trim or BRASS, { shape = Enum.PartType.Cylinder, turn = facing })
	end
end

-- Work clothes on the body (client/WorkerLooks has every job's): u = {
-- shirt, sleeves ("short" | "long"), legs, shoes?, gloves?, and over the
-- shirt any of bib (dungarees), apron (a bib apron; badge: a name badge on
-- it), vest (hi-vis), collar (a polo's or a work shirt's: the collar and a
-- placket), sash (with a rosette), coat (a raincoat to the knee), torch (in
-- the left hand) }. Returns the torso.
function PeopleArt.dress(add, u, skin: Color3)
	local torso = PeopleArt.body(add, { skin = skin, legs = u.legs, shoes = u.shoes or BOOTS, top = u.coat or u.shirt, sleeve = u.sleeves or "long", gloves = u.gloves })
	if u.bib then -- dungarees: the bib with its pocket, the straps and their buttons
		add("Bib", Vector3.new(1.3, 1.0, 0.06), Vector3.new(0, 3.0, -0.52), u.bib)
		add("BibPocket", Vector3.new(0.6, 0.36, 0.04), Vector3.new(0, 3.08, -0.58), u.bib:Lerp(SHADE, 0.14))
		add("Pants", Vector3.new(2.1, 0.6, 1.1), Vector3.new(0, 2.6, 0), u.bib)
		for _, x in { -0.5, 0.5 } do
			-- (from the bib's top over the shoulder, standing over its top)
			add("Strap", Vector3.new(0.26, 0.9, 1.1), Vector3.new(x, 3.95, 0), u.bib)
			add("Button", Vector3.new(0.18, 0.18, 0.06), Vector3.new(x, 3.55, -0.58), BRASS)
		end
	end
	if u.apron then -- a bib apron: the bib, the skirt with a pocket, the ties round the waist, the neck strap
		add("ApronBib", Vector3.new(1.2, 1.05, 0.08), Vector3.new(0, 3.5, -0.54), u.apron)
		add("Apron", Vector3.new(1.7, 1.2, 0.08), Vector3.new(0, 2.42, -0.54), u.apron)
		add("ApronPocket", Vector3.new(1.0, 0.4, 0.04), Vector3.new(0, 2.38, -0.61), u.apron:Lerp(SHADE, 0.14))
		add("ApronTie", Vector3.new(2.1, 0.14, 1.1), Vector3.new(0, 2.96, 0), u.apron:Lerp(SHADE, 0.08))
		for _, x in { -0.42, 0.42 } do
			add("ApronStrap", Vector3.new(0.14, 0.42, 1.1), Vector3.new(x, 4.17, 0), u.apron:Lerp(SHADE, 0.08))
		end
		if u.badge then -- the name badge
			add("NameBadge", Vector3.new(0.5, 0.26, 0.04), Vector3.new(0.3, 3.72, -0.61), WHITE)
		end
	end
	if u.vest then -- hi-vis over the shirt, two reflective bands
		add("Vest", Vector3.new(2.1, 1.9, 1.1), Vector3.new(0, 3.38, 0), u.vest)
		for _, y in { 2.85, 3.55 } do
			add("VestBand", Vector3.new(2.2, 0.18, 1.2), Vector3.new(0, y, 0), Color3.fromRGB(226, 232, 236))
		end
	end
	if u.collar then -- a polo's or a work shirt's collar and placket (or a blouse under a cardigan)
		add("Collar", Vector3.new(1.2, 0.2, 1.1), Vector3.new(0, 4.3, 0), u.collar)
		add("Placket", Vector3.new(0.28, 0.6, 0.04), Vector3.new(0, 3.95, -0.53), u.collar)
	end
	if u.sash then -- over the right shoulder to the left hip, a rosette on the chest
		add("Sash", Vector3.new(0.45, 2.5, 1.1), Vector3.new(0, 3.35, 0), u.sash, { turn = CFrame.Angles(0, 0, math.rad(-40)) })
		add("Rosette", Vector3.new(0.1, 0.72, 0.72), Vector3.new(0.42, 3.85, -0.6), Color3.fromRGB(200, 69, 45),
			{ shape = Enum.PartType.Cylinder, turn = CFrame.Angles(0, math.rad(90), 0) })
		add("RosetteMiddle", Vector3.new(0.1, 0.32, 0.32), Vector3.new(0.42, 3.85, -0.66), u.sash,
			{ shape = Enum.PartType.Cylinder, turn = CFrame.Angles(0, math.rad(90), 0) })
	end
	if u.coat then -- a raincoat to the knee: buttoned, a collar
		add("CoatSkirt", Vector3.new(2.1, 0.85, 1.1), Vector3.new(0, 1.925, 0), u.coat) -- (from the torso down: not alongside it)
		add("Collar", Vector3.new(1.3, 0.24, 1.1), Vector3.new(0, 4.3, 0), u.coat:Lerp(SHADE, 0.1))
		add("CoatEdge", Vector3.new(0.06, 2.85, 0.04), Vector3.new(0.12, 2.92, -0.58), u.coat:Lerp(SHADE, 0.2))
		for i = 0, 3 do
			add("Button", Vector3.new(0.16, 0.16, 0.06), Vector3.new(-0.12, 4.0 - i * 0.62, -0.58), DARK)
		end
	elseif not u.bib then -- a belt
		add("Belt", Vector3.new(2.1, 0.24, 1.1), Vector3.new(0, 2.42, 0), u.legs:Lerp(SHADE, 0.25)) -- (over the torso's bottom edge, not level with it)
	end
	if u.torch then -- in the left hand, pointing ahead
		local arm = { limb = "arm", sign = -1, pivot = Vector3.new(-1.5, PeopleArt.SHOULDER, 0) }
		local ahead = CFrame.Angles(0, math.rad(90), 0)
		add("Torch", Vector3.new(1.0, 0.36, 0.36), Vector3.new(-1.5, 2.25, -0.35), DARK,
			{ shape = Enum.PartType.Cylinder, turn = ahead, limb = arm.limb, sign = arm.sign, pivot = arm.pivot })
		add("TorchHead", Vector3.new(0.3, 0.5, 0.5), Vector3.new(-1.5, 2.25, -0.78), DARK,
			{ shape = Enum.PartType.Cylinder, turn = ahead, limb = arm.limb, sign = arm.sign, pivot = arm.pivot })
		add("TorchLens", Vector3.new(0.06, 0.42, 0.42), Vector3.new(-1.5, 2.25, -0.94), Color3.fromRGB(255, 240, 170),
			{ shape = Enum.PartType.Cylinder, turn = ahead, limb = arm.limb, sign = arm.sign, pivot = arm.pivot })
	end
	return torso
end

-- Stands a figure's parts at `feet`, each limb turned forward by
-- angle(limb, side) radians (nil: at rest): for people who stay put (the
-- townspeople, galleries).
function PeopleArt.place(parts, feet: CFrame, angle: ((string, number) -> number)?)
	for _, entry in parts do
		local p, offset, limb, side, pivot = entry[1], entry[2], entry[3], entry[4], entry[5]
		local pose = offset
		if angle and limb and pivot then
			local a = angle(limb, side)
			if a ~= 0 then
				pose = CFrame.new(pivot) * CFrame.Angles(a, 0, 0) * CFrame.new(-pivot) * offset
			end
		end
		p.CFrame = feet * pose
	end
end

return PeopleArt
