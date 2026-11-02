-- A crop's produce as you'd carry it out of the field (docs/ArtDirection.md
-- §9): what a thief holds up over their head (CrimeArt.showCarried), so the
-- farmer knows at a glance which of their crops is walking off. Small crops
-- come as a bunch (carrots, wheat, corn, onions) or in a basket or punnet
-- (potatoes, tomatoes, blueberries, strawberries); big ones on their own.
-- Rare crops and up sparkle in their rarity's colour, like a ripe crop.
--
-- ProduceArt.build(cropId, base) builds it standing on `base` (its bottom
-- middle; it faces -Z) and returns the model, its main part (Core) carrying
-- Width (side to side), Height, and HoldY (how high up the sides it's held).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crops = require(ReplicatedStorage.Shared.Config.Crops)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Parts = require(script.Parent.Parts)

local COLORS = Parts.COLORS

local ProduceArt = {}

local TWINE = Color3.fromRGB(226, 204, 158)
local WICKER = Color3.fromRGB(196, 150, 84)
local WICKER_DARK = Color3.fromRGB(140, 98, 50)
local STEM = Color3.fromRGB(112, 86, 52)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function part(model: Model, name: string, cframe: CFrame, size: Vector3, color: Color3, extra)
	local props = { Name = name, Size = size, CFrame = cframe, Color = color, CastShadow = false }
	for key, value in extra or {} do
		props[key] = value
	end
	return Parts.prop(props, model)
end

-- An ellipsoid (a block drawn as a sphere stretched to its size).
local function egg(model: Model, name: string, cframe: CFrame, size: Vector3, color: Color3, extra)
	local p = part(model, name, cframe, size, color, extra)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function ball(model: Model, name: string, cframe: CFrame, diameter: number, color: Color3, extra)
	local p = part(model, name, cframe, Vector3.new(diameter, diameter, diameter), color, extra)
	p.Shape = Enum.PartType.Ball
	return p
end

-- A cylinder standing along `cframe`'s Y axis.
local function rod(model: Model, name: string, cframe: CFrame, diameter: number, length: number, color: Color3, extra)
	local p = part(model, name, cframe * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(length, diameter, diameter), color, extra)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A root, pepper or pod that narrows to a point: rings from `top` down its
-- -Y, each `step` long.
local function taper(model: Model, name: string, top: CFrame, diameters: { number }, step: number, color: Color3, extra)
	for i, d in diameters do
		rod(model, name, top * CFrame.new(0, -(i - 0.5) * step, 0), d, step + 0.02, color, extra)
	end
	ball(model, name .. "Tip", top * CFrame.new(0, -#diameters * step, 0), diameters[#diameters] * 0.9, color, extra)
end

-- A round wicker basket `d` wide and `h` tall: upright staves round it, a
-- rim; produce heaps on the rim's top (returned, as a height).
local function basket(model: Model, base: CFrame, d: number, h: number): number
	rod(model, "Basket", base * CFrame.new(0, h / 2, 0), d, h, WICKER)
	for i = 0, 11 do
		local a = math.rad(i * 30)
		part(model, "Stave", base * CFrame.Angles(0, a, 0) * CFrame.new(0, h / 2, d / 2), Vector3.new(0.08, h, 0.1), WICKER_DARK)
	end
	rod(model, "Rim", base * CFrame.new(0, h, 0), d + 0.16, 0.14, WICKER_DARK)
	return h + 0.07
end

-- A little wooden crate `size` big, two slats round it; produce heaps on
-- its top (returned, as a height).
local function crate(model: Model, base: CFrame, size: Vector3): number
	part(model, "Crate", base * CFrame.new(0, size.Y / 2, 0), size, COLORS.edging)
	for _, y in { size.Y * 0.28, size.Y * 0.74 } do
		part(model, "Slat", base * CFrame.new(0, y, 0), Vector3.new(size.X + 0.08, 0.12, size.Z + 0.08), COLORS.post)
	end
	return size.Y
end

-- Produce heaped in rings on a basket: `count` pieces of `size` from
-- `top`, the last one on top of the heap.
local function heap(top: CFrame, count: number, radius: number, size: number): { CFrame }
	local spots = {}
	local ring = count - 1
	for i = 1, ring do
		local a = (i / ring) * math.pi * 2 + 0.3
		table.insert(spots, top * CFrame.new(math.cos(a) * radius, size * 0.42, math.sin(a) * radius) * CFrame.Angles(a, i * 1.7, a * 0.5))
	end
	table.insert(spots, top * CFrame.new(0, size * 0.85, 0) * CFrame.Angles(0.4, 0, 0.3))
	return spots
end

local BUILDERS = {}

-- A bunch of five carrots tied at the top, roots hanging, a spray of
-- feathery leaves above the tie.
function BUILDERS.Carrot(m, base)
	local spots = { { -0.22, 0.04 }, { -0.06, -0.14 }, { 0.12, 0.1 }, { 0.24, -0.08 }, { 0, 0.2 } }
	for i, s in spots do
		local tilt = CFrame.Angles(math.rad(s[2] * 15), 0, math.rad(-s[1] * 15)) -- (the tips lean in a little)
		local top = base * CFrame.new(s[1], 1.45, s[2]) * tilt
		taper(m, "Root", top, { 0.38, 0.33, 0.26, 0.18 }, 0.31, Color3.fromRGB(242, 140, 40))
		for k = 0, 2 do
			local frond = base * CFrame.new(s[1] * 0.6, 1.5, s[2] * 0.6) * CFrame.Angles(0, math.rad(i * 72 + k * 120), math.rad(14 + k * 13)) * CFrame.new(0, 0.62, 0)
			part(m, "Leaf", frond, Vector3.new(0.06, 1.25, 0.16), if (i + k) % 2 == 0 then COLORS.leafDark else COLORS.leaf)
		end
	end
	rod(m, "Twine", base * CFrame.new(0, 1.42, 0), 0.74, 0.14, Color3.fromRGB(176, 120, 60))
	return { width = 0.9, height = 2.65, hold = 1.0 }
end

-- A sheaf: golden stalks tied in the middle, splayed above and below,
-- with their ears at the top.
function BUILDERS.Wheat(m, base)
	local count = 14
	for i = 1, count do
		local a = i / count * math.pi * 2
		local r = if i % 2 == 0 then 0.2 else 0.12
		local foot = Vector3.new(math.cos(a) * r * 2.2, 0, math.sin(a) * r * 2.2)
		local head = Vector3.new(math.cos(a) * r * 2.6, 2.25, math.sin(a) * r * 2.6)
		local tie = Vector3.new(math.cos(a) * r, 1.0, math.sin(a) * r)
		for _, span in { { foot, tie }, { tie, head } } do
			local from, to = span[1], span[2]
			local mid = (from + to) / 2
			local stalk = base * CFrame.lookAt(mid, mid + (to - from)) * CFrame.Angles(math.rad(90), 0, 0)
			rod(m, "Stalk", stalk, 0.09, (to - from).Magnitude + 0.04, Color3.fromRGB(222, 186, 92))
		end
		local ear = base * CFrame.new(head) * CFrame.lookAt(Vector3.zero, Vector3.new(head.X, 4, head.Z)) * CFrame.Angles(math.rad(-90), 0, 0)
		egg(m, "Ear", ear * CFrame.new(0, 0.22, 0), Vector3.new(0.17, 0.52, 0.17), Color3.fromRGB(236, 200, 96))
	end
	rod(m, "Twine", base * CFrame.new(0, 1.0, 0), 0.62, 0.2, Color3.fromRGB(176, 120, 60))
	return { width = 1.15, height = 2.75, hold = 0.72 }
end

-- A little crate of potatoes.
function BUILDERS.Potato(m, base)
	local top = crate(m, base, Vector3.new(1.45, 0.7, 1.05))
	local tones = { Color3.fromRGB(176, 128, 80), Color3.fromRGB(158, 112, 68), Color3.fromRGB(186, 140, 90) }
	for i, at in heap(base * CFrame.new(0, top, 0), 6, 0.38, 0.5) do
		egg(m, "Potato", at, Vector3.new(0.58, 0.42, 0.45), tones[i % 3 + 1])
	end
	return { width = 1.53, height = 1.45, hold = 0.4 }
end

-- A head of lettuce: a pale heart cupped in darker leaves.
function BUILDERS.Lettuce(m, base)
	egg(m, "Heart", base * CFrame.new(0, 0.6, 0), Vector3.new(1.1, 1.05, 1.1), Color3.fromRGB(176, 224, 116))
	for i = 1, 7 do
		local a = math.rad(i * 360 / 7)
		local leaf = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.48, 0.42) * CFrame.Angles(math.rad(28), 0, 0)
		egg(m, "Leaf", leaf, Vector3.new(0.95, 0.85, 0.24), if i % 2 == 0 then Color3.fromRGB(110, 182, 72) else Color3.fromRGB(128, 196, 84))
	end
	return { width = 1.55, height = 1.15, hold = 0.5 }
end

-- Three cobs side by side, husks peeled back, tied at the bottom.
function BUILDERS.Corn(m, base)
	for i, x in { -0.42, 0, 0.42 } do
		local cob = base * CFrame.new(x, 0.85, if i == 2 then -0.12 else 0.06) * CFrame.Angles(0, 0, math.rad(-x * 22))
		egg(m, "Cob", cob, Vector3.new(0.44, 1.5, 0.44), Color3.fromRGB(245, 211, 61))
		for k = 0, 3 do -- (rows of kernels: four thin eggs turned round the cob, each two ridges)
			egg(m, "Kernels", cob * CFrame.Angles(0, math.rad(k * 45 + 22), 0), Vector3.new(0.5, 1.42, 0.08), Color3.fromRGB(228, 188, 42))
		end
		for _, side in { -1, 1 } do
			local husk = cob * CFrame.new(side * 0.24, -0.42, 0) * CFrame.Angles(0, 0, math.rad(side * 24))
			egg(m, "Husk", husk, Vector3.new(0.12, 1.2, 0.46), if side > 0 then COLORS.leaf else COLORS.leafDark)
		end
	end
	rod(m, "Twine", base * CFrame.new(0, 0.32, 0), 1.45, 0.16, TWINE)
	return { width = 1.5, height = 1.62, hold = 0.75 }
end

-- Three onions, their dry tops twisted together and tied.
function BUILDERS.Onion(m, base)
	local knot = Vector3.new(0, 1.1, 0.04)
	for i, at in { Vector3.new(-0.45, 0.36, 0.14), Vector3.new(0.45, 0.36, 0.14), Vector3.new(0, 0.38, -0.32) } do
		local bulb = base * CFrame.new(at)
		egg(m, "Bulb", bulb, Vector3.new(0.74, 0.66, 0.74), if i == 3 then Color3.fromRGB(196, 140, 78) else Color3.fromRGB(214, 160, 92))
		egg(m, "Roots", bulb * CFrame.new(0, -0.32, 0), Vector3.new(0.26, 0.1, 0.26), Color3.fromRGB(232, 216, 180))
		local neckFrom, neckTo = at + Vector3.new(0, 0.3, 0), knot
		local mid = (neckFrom + neckTo) / 2
		rod(m, "Neck", base * CFrame.lookAt(mid, neckTo) * CFrame.Angles(math.rad(90), 0, 0), 0.16, (neckTo - neckFrom).Magnitude + 0.1,
			Color3.fromRGB(200, 170, 110))
	end
	rod(m, "Twine", base * CFrame.new(knot), 0.34, 0.2, Color3.fromRGB(176, 120, 60))
	return { width = 1.65, height = 1.25, hold = 0.38 }
end

-- A green punnet heaped with strawberries.
function BUILDERS.Strawberry(m, base)
	part(m, "Punnet", base * CFrame.new(0, 0.25, 0), Vector3.new(1.3, 0.5, 0.95), Color3.fromRGB(64, 150, 74))
	part(m, "PunnetRim", base * CFrame.new(0, 0.52, 0), Vector3.new(1.42, 0.1, 1.07), Color3.fromRGB(46, 120, 56))
	local spots = {}
	for gx = -1, 1 do
		for gz = -1, 1, 2 do
			table.insert(spots, Vector3.new(gx * 0.36, 0.78, gz * 0.2))
		end
	end
	table.insert(spots, Vector3.new(-0.17, 1.0, 0))
	table.insert(spots, Vector3.new(0.19, 1.0, 0.02))
	for i, at in spots do
		local berry = base * CFrame.new(at) * CFrame.Angles(math.rad((i % 3 - 1) * 18), math.rad(i * 47), math.rad((i % 2) * 20 - 10))
		-- (broad shoulders narrowing to a point: two eggs overlapping)
		egg(m, "Berry", berry, Vector3.new(0.32, 0.3, 0.32), Color3.fromRGB(226, 40, 52))
		egg(m, "BerryTip", berry * CFrame.new(0, -0.11, 0), Vector3.new(0.22, 0.3, 0.22), Color3.fromRGB(220, 36, 48))
		for k = 0, 4 do
			part(m, "Cap", berry * CFrame.new(0, 0.14, 0) * CFrame.Angles(0, math.rad(k * 72), math.rad(78)) * CFrame.new(0, 0.08, 0),
				Vector3.new(0.04, 0.15, 0.07), COLORS.leafDark)
		end
	end
	return { width = 1.42, height = 1.15, hold = 0.3 }
end

-- A basket of tomatoes, green stars on top.
function BUILDERS.Tomato(m, base)
	local top = basket(m, base, 1.25, 0.75)
	for _, at in heap(base * CFrame.new(0, top, 0), 6, 0.34, 0.5) do
		ball(m, "Tomato", at, 0.5, Color3.fromRGB(222, 62, 46))
		rod(m, "Calyx", at * CFrame.new(0, 0.24, 0), 0.24, 0.05, COLORS.leaf)
	end
	return { width = 1.39, height = 1.5, hold = 0.45 }
end

-- One big bell pepper: four lobes, a shoulder and a green stem.
function BUILDERS.BellPepper(m, base)
	local yellow, shade = Color3.fromRGB(242, 200, 44), Color3.fromRGB(226, 182, 30)
	for i, at in { Vector3.new(0.22, 0, 0.22), Vector3.new(-0.22, 0, 0.22), Vector3.new(-0.22, 0, -0.22), Vector3.new(0.22, 0, -0.22) } do
		egg(m, "Lobe", base * CFrame.new(at + Vector3.new(0, 0.6, 0)), Vector3.new(0.66, 1.15, 0.66), if i % 2 == 0 then shade else yellow)
	end
	rod(m, "Calyx", base * CFrame.new(0, 1.12, 0), 0.4, 0.1, COLORS.leafDark)
	rod(m, "Stem", base * CFrame.new(0.02, 1.3, 0) * CFrame.Angles(0, 0, math.rad(-10)), 0.13, 0.3, COLORS.leaf)
	rod(m, "StemTip", base * CFrame.new(0.1, 1.48, 0) * CFrame.Angles(0, 0, math.rad(-45)), 0.11, 0.16, COLORS.leaf)
	return { width = 1.1, height = 1.55, hold = 0.55 }
end

-- A ribbed pumpkin (`body`, `shade`), a curly stem and a leaf.
local function pumpkin(m, base, width: number, height: number, body: Color3, shade: Color3, stem: Color3)
	local centre = base * CFrame.new(0, height / 2, 0)
	for i = 0, 3 do
		-- (four long eggs turned 45° apart: where they cross, the ribs dip in)
		egg(m, "Rib", centre * CFrame.Angles(0, math.rad(i * 45), 0), Vector3.new(width, height, width * 0.58), if i % 2 == 0 then body else shade)
	end
	rod(m, "Stem", centre * CFrame.new(0.05, height / 2 + 0.15, 0) * CFrame.Angles(0, 0, math.rad(-16)), 0.26, 0.5, stem)
	rod(m, "StemTop", centre * CFrame.new(0.2, height / 2 + 0.4, 0) * CFrame.Angles(0, 0, math.rad(-60)), 0.2, 0.26, stem)
	egg(m, "Leaf", centre * CFrame.new(-0.35, height / 2 + 0.02, 0.15) * CFrame.Angles(math.rad(8), math.rad(30), math.rad(14)), Vector3.new(0.75, 0.07, 0.5), COLORS.leaf)
	return centre
end

function BUILDERS.Pumpkin(m, base)
	pumpkin(m, base, 1.9, 1.25, Color3.fromRGB(240, 127, 30), Color3.fromRGB(226, 112, 24), Color3.fromRGB(104, 112, 52))
	return { width = 1.9, height = 1.75, hold = 0.55 }
end

-- A long melon with dark stripes running end to end.
local function melon(m, base, size: Vector3, body: Color3, stripe: Color3, extra)
	local centre = base * CFrame.new(0, size.Y / 2, 0)
	egg(m, "Melon", centre, size, body, extra)
	for i = 0, 4 do
		-- (thin eggs as long as the melon, turned round its length: each shows as two stripes)
		egg(m, "Stripe", centre * CFrame.Angles(math.rad(i * 36), 0, 0), Vector3.new(size.X + 0.05, size.Y + 0.1, 0.22), stripe)
	end
	return centre
end

function BUILDERS.Watermelon(m, base)
	melon(m, base, Vector3.new(2.0, 1.3, 1.3), Color3.fromRGB(104, 168, 78), Color3.fromRGB(40, 104, 50))
	return { width = 2.05, height = 1.4, hold = 0.6 }
end

-- A small basket of blueberries.
function BUILDERS.Blueberry(m, base)
	local top = basket(m, base, 1.1, 0.65)
	local blues = { Color3.fromRGB(72, 92, 204), Color3.fromRGB(58, 72, 176), Color3.fromRGB(92, 110, 214) }
	local n = 0
	for ring, r in { 0.38, 0.2, 0 } do
		local count = if r == 0 then 1 else math.floor(r * 22)
		for i = 1, count do
			n += 1
			local a = i / count * math.pi * 2 + ring
			ball(m, "Berry", base * CFrame.new(math.cos(a) * r, top + 0.1 + (ring - 1) * 0.13, math.sin(a) * r), 0.26, blues[n % 3 + 1])
		end
	end
	for _, side in { -1, 1 } do
		egg(m, "Leaf", base * CFrame.new(side * 0.32, top + 0.3, -0.2) * CFrame.Angles(math.rad(-20), 0, math.rad(side * 30)), Vector3.new(0.4, 0.06, 0.24), COLORS.leaf)
	end
	return { width = 1.24, height = 1.2, hold = 0.4 }
end

-- A pineapple: a studded golden body under a crown of spiky leaves.
function BUILDERS.Pineapple(m, base)
	local centre = base * CFrame.new(0, 0.7, 0)
	egg(m, "Fruit", centre, Vector3.new(1.0, 1.4, 1.0), Color3.fromRGB(232, 170, 52))
	for row = -2, 2 do
		local y = row * 0.24
		local r = 0.5 * math.sqrt(1 - (y / 0.7) ^ 2)
		for i = 0, 5 do
			local a = math.rad(i * 60 + row * 30)
			egg(m, "Eye", centre * CFrame.new(math.cos(a) * r, y, math.sin(a) * r) * CFrame.Angles(0, -a, 0), Vector3.new(0.08, 0.13, 0.13), Color3.fromRGB(128, 100, 40))
		end
	end
	for i = 0, 8 do
		local tall = i >= 6
		local leaf = base * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, math.rad(i * 40), math.rad(if tall then 8 else 32)) * CFrame.new(0, if tall then 0.55 else 0.4, 0)
		part(m, "Crown", leaf, Vector3.new(0.08, if tall then 1.1 else 0.8, 0.22), if i % 2 == 0 then COLORS.leafDark else COLORS.leaf)
	end
	return { width = 1.0, height = 2.4, hold = 0.65 }
end

-- A cocoa pod: long, ridged, orange-brown, a woody stem.
function BUILDERS.CocoaPod(m, base)
	local centre = base * CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.rad(8))
	egg(m, "Pod", centre, Vector3.new(0.86, 1.65, 0.86), Color3.fromRGB(196, 110, 46))
	for i = 0, 4 do
		egg(m, "Ridge", centre * CFrame.Angles(0, math.rad(i * 36), 0), Vector3.new(0.2, 1.55, 0.98), Color3.fromRGB(170, 92, 38))
	end
	rod(m, "Stem", centre * CFrame.new(0, 0.9, 0), 0.16, 0.34, STEM)
	return { width = 1.0, height = 1.85, hold = 0.8 }
end

-- A dragonfruit: magenta, with green-tipped scales.
function BUILDERS.Dragonfruit(m, base)
	local centre = base * CFrame.new(0, 0.66, 0)
	local pink = Color3.fromRGB(232, 62, 142)
	egg(m, "Fruit", centre, Vector3.new(1.1, 1.3, 1.1), pink)
	for row, y in { -0.38, -0.02, 0.32 } do
		local r = 0.55 * math.sqrt(1 - (y / 0.65) ^ 2) - 0.03
		for i = 0, 4 do
			local a = math.rad(i * 72 + row * 36)
			local scale = centre * CFrame.Angles(0, a, 0) * CFrame.new(0, y, r) * CFrame.Angles(math.rad(-18), 0, 0) -- (lying on the skin)
			egg(m, "Scale", scale * CFrame.new(0, 0.1, 0), Vector3.new(0.36, 0.38, 0.1), Color3.fromRGB(240, 92, 160))
			egg(m, "ScaleTip", scale * CFrame.new(0, 0.3, 0.04) * CFrame.Angles(math.rad(-30), 0, 0), Vector3.new(0.18, 0.2, 0.07), Color3.fromRGB(130, 190, 70))
		end
	end
	for i = 0, 2 do
		part(m, "Tuft", centre * CFrame.new(0, 0.62, 0) * CFrame.Angles(0, math.rad(i * 120), math.rad(25)) * CFrame.new(0, 0.18, 0), Vector3.new(0.07, 0.38, 0.18), COLORS.leaf)
	end
	return { width = 1.3, height = 1.55, hold = 0.6 }
end

-- A big bunch of grapes on its woody stem, a vine leaf behind.
function BUILDERS.GrapeVine(m, base)
	local purples = { Color3.fromRGB(124, 62, 164), Color3.fromRGB(106, 50, 146), Color3.fromRGB(140, 76, 180) }
	local layers = { { 1.3, 0.42, 7 }, { 1.0, 0.36, 6 }, { 0.72, 0.28, 5 }, { 0.46, 0.18, 3 }, { 0.22, 0, 1 } }
	local n = 0
	for _, layer in layers do
		local y, r, count = layer[1], layer[2], layer[3]
		for i = 1, count do
			n += 1
			local a = i / count * math.pi * 2 + y * 2
			ball(m, "Grape", base * CFrame.new(math.cos(a) * r, y, math.sin(a) * r), 0.38, purples[n % 3 + 1])
		end
		if r > 0.25 then
			ball(m, "Grape", base * CFrame.new(0, y, 0), 0.38, purples[(n + 1) % 3 + 1]) -- (filled in the middle)
		end
	end
	rod(m, "Stem", base * CFrame.new(0, 1.62, 0.05) * CFrame.Angles(math.rad(10), 0, 0), 0.14, 0.5, STEM)
	egg(m, "Leaf", base * CFrame.new(0.25, 1.62, 0.32) * CFrame.Angles(math.rad(-60), math.rad(20), 0), Vector3.new(0.95, 0.06, 0.8), COLORS.leaf)
	return { width = 1.25, height = 1.9, hold = 1.0 }
end

-- The Moonmelon: a glowing pale melon with silvery stripes.
function BUILDERS.Moonmelon(m, base)
	melon(m, base, Vector3.new(1.7, 1.45, 1.45), Color3.fromRGB(206, 224, 255), Color3.fromRGB(140, 160, 214), { Material = Enum.Material.Neon })
	for _, stripe in m:GetChildren() do
		if stripe.Name == "Stripe" then
			stripe.Material = Enum.Material.SmoothPlastic -- (bands on the glow)
		end
	end
	return { width = 1.75, height = 1.55, hold = 0.65 }
end

-- A starfruit: five glowing fins round its length, a star end on.
function BUILDERS.Starfruit(m, base)
	local centre = base * CFrame.new(0, 0.78, 0)
	for i = 0, 4 do
		egg(m, "Fin", centre * CFrame.Angles(0, math.rad(i * 72), 0) * CFrame.new(0, 0, 0.24), Vector3.new(0.28, 1.55, 1.05),
			if i % 2 == 0 then Color3.fromRGB(250, 220, 80) else Color3.fromRGB(240, 204, 60), { Reflectance = 0.1 })
	end
	rod(m, "Stem", centre * CFrame.new(0, 0.82, 0), 0.12, 0.28, STEM)
	return { width = 1.5, height = 1.7, hold = 0.75 }
end

-- A golden apple with a stem and a leaf.
function BUILDERS.GoldenApple(m, base)
	local centre = base * CFrame.new(0, 0.62, 0)
	egg(m, "Apple", centre, Vector3.new(1.3, 1.2, 1.3), Color3.fromRGB(236, 172, 22), { Reflectance = 0.15 }) -- (shiny gold)
	egg(m, "Dimple", centre * CFrame.new(0, 0.56, 0), Vector3.new(0.4, 0.12, 0.4), Color3.fromRGB(200, 150, 30))
	egg(m, "Shine", centre * CFrame.new(-0.3, 0.3, -0.4), Vector3.new(0.28, 0.2, 0.1), Color3.fromRGB(255, 248, 210), { Material = Enum.Material.Neon })
	rod(m, "Stem", centre * CFrame.new(0.04, 0.72, 0) * CFrame.Angles(0, 0, math.rad(-12)), 0.12, 0.38, STEM)
	egg(m, "Leaf", centre * CFrame.new(0.28, 0.76, 0) * CFrame.Angles(0, 0, math.rad(-28)), Vector3.new(0.5, 0.06, 0.26), COLORS.leaf)
	return { width = 1.35, height = 1.5, hold = 0.55 }
end

-- The Crystal Rose: crystal petals round a glowing bud, on a green stem.
function BUILDERS.CrystalRose(m, base)
	local crystal = Color3.fromRGB(150, 222, 255)
	rod(m, "Stem", base * CFrame.new(0, 0.6, 0), 0.14, 1.2, COLORS.leaf)
	for _, side in { -1, 1 } do
		egg(m, "Leaf", base * CFrame.new(side * 0.22, 0.45 + side * 0.15, 0) * CFrame.Angles(0, 0, math.rad(-side * 35)), Vector3.new(0.5, 0.06, 0.26), COLORS.leafDark)
	end
	local bloom = base * CFrame.new(0, 1.5, 0)
	egg(m, "Bud", bloom, Vector3.new(0.42, 0.55, 0.42), Color3.fromRGB(210, 244, 255), { Material = Enum.Material.Neon })
	for ring, petals in { { 5, 0.2, 18, Vector3.new(0.42, 0.6, 0.12) }, { 6, 0.36, 46, Vector3.new(0.58, 0.68, 0.12) } } do
		for i = 0, petals[1] - 1 do
			local petal = bloom * CFrame.Angles(0, math.rad(i * 360 / petals[1] + ring * 30), 0) * CFrame.new(0, -0.05, petals[2]) * CFrame.Angles(math.rad(petals[3]), 0, 0)
			egg(m, "Petal", petal, petals[4], crystal, { Reflectance = 0.25 })
		end
	end
	return { width = 1.35, height = 1.95, hold = 1.4 }
end

-- The Phoenix Pepper: a long chilli curling up at the tip, glowing, in flames.
function BUILDERS.PhoenixPepper(m, base)
	local fire = { Color3.fromRGB(206, 30, 24), Color3.fromRGB(214, 36, 24), Color3.fromRGB(226, 56, 22), Color3.fromRGB(238, 92, 24),
		Color3.fromRGB(248, 132, 30), Color3.fromRGB(252, 176, 44), Color3.fromRGB(255, 214, 70) }
	local at = base * CFrame.new(-0.95, 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)) -- (lying along +X, the stem end on the left)
	local diameters = { 0.72, 0.68, 0.62, 0.54, 0.44, 0.32, 0.2 }
	for i, d in diameters do
		rod(m, "Pepper", at * CFrame.new(0, -0.15, 0), d, 0.34, fire[i], { Reflectance = 0.15, Material = if i == #diameters then Enum.Material.Neon else Enum.Material.SmoothPlastic })
		at = at * CFrame.new(0, -0.3, 0) * CFrame.Angles(0, 0, math.rad(if i > 3 then 14 else 4)) -- (the tip curls up)
	end
	ball(m, "PepperTip", at * CFrame.new(0, -0.05, 0), 0.18, fire[#fire], { Material = Enum.Material.Neon })
	rod(m, "Calyx", base * CFrame.new(-1.0, 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)), 0.62, 0.12, COLORS.leafDark)
	rod(m, "Stem", base * CFrame.new(-1.2, 0.55, 0) * CFrame.Angles(0, 0, math.rad(50)), 0.14, 0.36, COLORS.leaf)
	return { width = 2.2, height = 1.1, hold = 0.42 }
end

function BUILDERS.DragonsEyePumpkin(m, base)
	local centre = pumpkin(m, base, 2.15, 1.4, Color3.fromRGB(156, 42, 124), Color3.fromRGB(132, 32, 104), Color3.fromRGB(56, 40, 44))
	local eye = centre * CFrame.new(0, 0.05, -2.15 / 2 + 0.06) -- (on the front rib's face)
	egg(m, "Eye", eye, Vector3.new(0.78, 0.5, 0.28), Color3.fromRGB(255, 214, 60), { Material = Enum.Material.Neon })
	egg(m, "Pupil", eye * CFrame.new(0, 0, -0.06), Vector3.new(0.13, 0.44, 0.24), COLORS.dark)
	return { width = 2.15, height = 1.95, hold = 0.6 }
end

-- Any crop without its own model: a round fruit in its colour.
local function plain(m, base, cropId: string)
	local FarmArt = require(script.Parent.FarmArt)
	ball(m, "Fruit", base * CFrame.new(0, 0.6, 0), 1.2, FarmArt.cropColor(cropId))
	return { width = 1.2, height = 1.2, hold = 0.6 }
end

-- Builds a crop's produce standing on `base`. Returns the model and its
-- Core part (Width, Height, HoldY attributes; the sparkles).
function ProduceArt.build(cropId: string, base: CFrame): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Produce"
	local info = (BUILDERS[cropId] or function(m, b)
		return plain(m, b, cropId)
	end)(model, base)
	local core = Parts.prop({ Name = "Core", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = base * CFrame.new(0, info.hold, 0), Transparency = 1, CastShadow = false }, model)
	core:SetAttribute("Width", info.width)
	core:SetAttribute("Height", info.height)
	core:SetAttribute("HoldY", info.hold)
	local rarity = Rarities.ById[Crops.ById[cropId].rarity]
	if rarity.order >= 3 then -- (Rare and up sparkle, like a ripe crop)
		local glow = rarity.color
		local spot = Instance.new("Attachment")
		spot.Position = Vector3.new(0, info.height / 2 - info.hold, 0)
		spot.Parent = core
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "Sparkle"
		sparkle.Texture = SPARKLE
		sparkle.Color = ColorSequence.new(glow)
		sparkle.LightEmission = 1
		sparkle.Rate = 1 + rarity.order
		sparkle.Lifetime = NumberRange.new(0.6, 1.1)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Parent = spot
	end
	if cropId == "PhoenixPepper" then
		local spot = Instance.new("Attachment")
		spot.Position = Vector3.new(0, 0.35 - info.hold, 0)
		spot.Parent = core
		local flame = Instance.new("ParticleEmitter")
		flame.Name = "Flame"
		flame.Texture = FIRE
		flame.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 80, 20))
		flame.LightEmission = 0.8
		flame.Rate = 18
		flame.Lifetime = NumberRange.new(0.35, 0.6)
		flame.Speed = NumberRange.new(1.5, 2.5)
		flame.Acceleration = Vector3.new(0, 3, 0)
		flame.SpreadAngle = Vector2.new(20, 20)
		flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.1) })
		flame.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		flame.Parent = spot
	end
	model.PrimaryPart = core
	return model, core
end

return ProduceArt
