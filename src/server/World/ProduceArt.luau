-- A crop's produce as you'd carry it out of the field (docs/ArtDirection.md
-- §9): what a thief holds up over their head (CrimeArt.showCarried), so the
-- farmer sees at a glance which of their crops is walking off, and how much.
-- A thief takes a whole patch (the big ones one at a time), so it's as many
-- as the patch gave: carrots and corn tied in a bunch, onions on a string,
-- sheaves of wheat tied together, potatoes in a little crate, lettuces in a
-- shallow one, punnets of berries on a tray, tomatoes, peppers, cocoa pods,
-- dragonfruit, grapes, starfruit and golden apples in wicker baskets,
-- pineapples side by side, a pumpkin or a melon on its own. Rare crops and
-- up sparkle in their rarity's colour, like a ripe crop. They're the crops'
-- low-poly meshes (World/Meshes, laid out by tools/crop_art) once those
-- are imported, and part-built until then.
--
-- ProduceArt.build(cropId, base, count) builds `count` of it (default: the
-- crop's perPatch) standing on `base` (its bottom middle; it faces -Z) and
-- returns the model and its main part (Core) carrying Width (side to side),
-- Height, and HoldY (how high up the sides it's held).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crops = require(ReplicatedStorage.Shared.Config.Crops)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Meshes = require(script.Parent.Meshes)
local Parts = require(script.Parent.Parts)

local COLORS = Parts.COLORS

local ProduceArt = {}

local WICKER = Color3.fromRGB(196, 150, 84)
local WICKER_DARK = Color3.fromRGB(140, 98, 50)
local STEM = Color3.fromRGB(112, 86, 52)
local PUNNET = Color3.fromRGB(64, 150, 74)
local PUNNET_RIM = Color3.fromRGB(46, 120, 56)
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
	local staves = math.max(12, math.floor(d * 9))
	for i = 0, staves - 1 do
		local a = math.rad(i * 360 / staves)
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

-- Spots for `count` pieces `size` across heaped on `top`, within `width`
-- by `depth`: a ring round the bottom layer (and one in the middle if there's
-- room), then a smaller ring on top of that, and so on; each piece tumbled.
local function pile(top: CFrame, count: number, size: number, width: number, depth: number?): { CFrame }
	local spots = {}
	local layer = 0
	while #spots < count do
		local rx = math.max(0, width / 2 - size / 2 - layer * size * 0.45)
		local rz = math.max(0, (depth or width) / 2 - size / 2 - layer * size * 0.45)
		local mean = (rx + rz) / 2
		local ring = if mean < size * 0.4 then 1 else math.max(3, math.floor(math.pi * (rx + rz) / (size * 0.85)))
		local y = size * 0.42 + layer * size * 0.62
		for i = 1, ring do
			if #spots >= count then
				break
			end
			local a = (i / ring) * math.pi * 2 + layer * 0.6
			table.insert(spots, top * CFrame.new(math.cos(a) * rx, y, math.sin(a) * rz) * CFrame.Angles(a, i * 1.7, a * 0.5))
		end
		if mean >= size * 0.95 and #spots < count then -- (room for one in the middle too)
			table.insert(spots, top * CFrame.new(0, y + size * 0.1, 0) * CFrame.Angles(0.4, layer, 0.3))
		end
		layer += 1
	end
	return spots
end

-- How high a heap from `pile` reaches above `base`: its top piece's top.
local function heapTop(base: CFrame, spots: { CFrame }, size: number): number
	local high = 0
	for _, at in spots do
		high = math.max(high, base:PointToObjectSpace(at.Position).Y + size / 2)
	end
	return high
end

-- `count` laid out in a grid `cols` across, `step` apart (x, z), centred.
local function grid(base: CFrame, count: number, cols: number, step: Vector2): { CFrame }
	local rows = math.ceil(count / cols)
	local spots = {}
	for i = 0, count - 1 do
		local col, row = i % cols, i // cols
		local inRow = if row == rows - 1 then count - row * cols else cols -- (a short last row is centred)
		table.insert(spots, base * CFrame.new((col - (inRow - 1) / 2) * step.X, 0, (row - (rows - 1) / 2) * step.Y))
	end
	return spots
end

------------------------------------------------------------------------
-- One of each (on `base`, its bottom middle; `k` scales it)

local ONE = {}

-- A carrot hanging from `top` (where it's tied), three feathery fronds.
function ONE.Carrot(m, top: CFrame, i: number)
	taper(m, "Root", top, { 0.38, 0.33, 0.26, 0.18 }, 0.31, Color3.fromRGB(242, 140, 40))
	for k = 0, 2 do
		local frond = top * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, math.rad(i * 72 + k * 120), math.rad(14 + k * 13)) * CFrame.new(0, 0.62, 0)
		part(m, "Leaf", frond, Vector3.new(0.06, 1.25, 0.16), if (i + k) % 2 == 0 then COLORS.leafDark else COLORS.leaf)
	end
end

-- A sheaf: `stalks` golden stalks tied in the middle, splayed above and
-- below, with their ears at the top.
function ONE.Sheaf(m, base: CFrame, stalks: number, k: number)
	for i = 1, stalks do
		local a = i / stalks * math.pi * 2
		local r = (if i % 2 == 0 then 0.2 else 0.12) * k
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
	rod(m, "Twine", base * CFrame.new(0, 1.0, 0), 0.62 * k, 0.2, Color3.fromRGB(176, 120, 60))
end

-- A head of lettuce: a pale heart cupped in darker leaves (1.55 across at k = 1).
function ONE.Lettuce(m, base: CFrame, k: number)
	egg(m, "Heart", base * CFrame.new(0, 0.6 * k, 0), Vector3.new(1.1, 1.05, 1.1) * k, Color3.fromRGB(176, 224, 116))
	for i = 1, 7 do
		local a = math.rad(i * 360 / 7)
		local leaf = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.48 * k, 0.42 * k) * CFrame.Angles(math.rad(28), 0, 0)
		egg(m, "Leaf", leaf, Vector3.new(0.95, 0.85, 0.24) * k, if i % 2 == 0 then Color3.fromRGB(110, 182, 72) else Color3.fromRGB(128, 196, 84))
	end
end

-- A cob of corn, husks peeled back (1.5 long), standing on `base` (its bottom).
function ONE.Cob(m, base: CFrame)
	local cob = base * CFrame.new(0, 0.75, 0)
	egg(m, "Cob", cob, Vector3.new(0.44, 1.5, 0.44), Color3.fromRGB(245, 211, 61))
	for k = 0, 3 do -- (rows of kernels: four thin eggs turned round the cob, each two ridges)
		egg(m, "Kernels", cob * CFrame.Angles(0, math.rad(k * 45 + 22), 0), Vector3.new(0.5, 1.42, 0.08), Color3.fromRGB(228, 188, 42))
	end
	for _, side in { -1, 1 } do
		local husk = cob * CFrame.new(side * 0.24, -0.42, 0) * CFrame.Angles(0, 0, math.rad(side * 24))
		egg(m, "Husk", husk, Vector3.new(0.12, 1.2, 0.46), if side > 0 then COLORS.leaf else COLORS.leafDark)
	end
end

-- A green punnet heaped with strawberries (1.42 across at k = 1): the
-- berries broad at the shoulder narrowing to a point, a green star on each.
function ONE.StrawberryPunnet(m, base: CFrame, k: number, berries: number)
	part(m, "Punnet", base * CFrame.new(0, 0.25 * k, 0), Vector3.new(1.3, 0.5, 0.95) * k, PUNNET)
	part(m, "PunnetRim", base * CFrame.new(0, 0.52 * k, 0), Vector3.new(1.42, 0.1, 1.07) * k, PUNNET_RIM)
	local spots = {}
	for gx = -1, 1 do
		for gz = -1, 1, 2 do
			table.insert(spots, Vector3.new(gx * 0.36, 0.78, gz * 0.2))
		end
	end
	table.insert(spots, Vector3.new(-0.17, 1.0, 0))
	table.insert(spots, Vector3.new(0.19, 1.0, 0.02))
	for i = 1, math.min(berries, #spots) do
		local berry = base * CFrame.new(spots[i] * k) * CFrame.Angles(math.rad((i % 3 - 1) * 18), math.rad(i * 47), math.rad((i % 2) * 20 - 10))
		egg(m, "Berry", berry, Vector3.new(0.32, 0.3, 0.32) * k, Color3.fromRGB(226, 40, 52))
		egg(m, "BerryTip", berry * CFrame.new(0, -0.11 * k, 0), Vector3.new(0.22, 0.3, 0.22) * k, Color3.fromRGB(220, 36, 48))
		egg(m, "Cap", berry * CFrame.new(0, 0.14 * k, 0), Vector3.new(0.3, 0.06, 0.3) * k, COLORS.leafDark)
	end
end

-- A green punnet of blueberries (1.42 across at k = 1).
function ONE.BlueberryPunnet(m, base: CFrame, k: number)
	part(m, "Punnet", base * CFrame.new(0, 0.25 * k, 0), Vector3.new(1.3, 0.5, 0.95) * k, PUNNET)
	part(m, "PunnetRim", base * CFrame.new(0, 0.52 * k, 0), Vector3.new(1.42, 0.1, 1.07) * k, PUNNET_RIM)
	local blues = { Color3.fromRGB(72, 92, 204), Color3.fromRGB(58, 72, 176), Color3.fromRGB(92, 110, 214) }
	local n = 0
	for gx = -2, 2 do
		for gz = -1, 1, 2 do
			n += 1
			ball(m, "Berry", base * CFrame.new(Vector3.new(gx * 0.25, 0.68, gz * 0.2) * k), 0.27 * k, blues[n % 3 + 1])
		end
	end
	for _, at in { Vector3.new(-0.15, 0.86, 0), Vector3.new(0.14, 0.86, 0.03) } do
		n += 1
		ball(m, "Berry", base * CFrame.new(at * k), 0.27 * k, blues[n % 3 + 1])
	end
end

-- One big bell pepper (1.1 across at k = 1): four lobes, a shoulder, a stem.
function ONE.BellPepper(m, base: CFrame, k: number)
	local yellow, shade = Color3.fromRGB(242, 200, 44), Color3.fromRGB(226, 182, 30)
	for i, at in { Vector3.new(0.22, 0, 0.22), Vector3.new(-0.22, 0, 0.22), Vector3.new(-0.22, 0, -0.22), Vector3.new(0.22, 0, -0.22) } do
		egg(m, "Lobe", base * CFrame.new((at + Vector3.new(0, 0.6, 0)) * k), Vector3.new(0.66, 1.15, 0.66) * k, if i % 2 == 0 then shade else yellow)
	end
	rod(m, "Calyx", base * CFrame.new(0, 1.12 * k, 0), 0.4 * k, 0.1 * k, COLORS.leafDark)
	rod(m, "Stem", base * CFrame.new(0.02 * k, 1.3 * k, 0) * CFrame.Angles(0, 0, math.rad(-10)), 0.13 * k, 0.3 * k, COLORS.leaf)
	rod(m, "StemTip", base * CFrame.new(0.1 * k, 1.48 * k, 0) * CFrame.Angles(0, 0, math.rad(-45)), 0.11 * k, 0.16 * k, COLORS.leaf)
end

-- A ribbed pumpkin (`body`, `shade`), a curly stem and a leaf.
local function pumpkin(m, base, width: number, height: number, body: Color3, shade: Color3, stem: Color3)
	local centre = base * CFrame.new(0, height / 2, 0)
	for i = 0, 3 do
		-- (four long eggs turned 45° apart: where they cross, the ribs dip in)
		egg(m, "Rib", centre * CFrame.Angles(0, math.rad(i * 45), 0), Vector3.new(width, height, width * 0.58), if i % 2 == 0 then body else shade)
	end
	local s = width / 1.9
	rod(m, "Stem", centre * CFrame.new(0.05 * s, height / 2 + 0.15 * s, 0) * CFrame.Angles(0, 0, math.rad(-16)), 0.26 * s, 0.5 * s, stem)
	rod(m, "StemTop", centre * CFrame.new(0.2 * s, height / 2 + 0.4 * s, 0) * CFrame.Angles(0, 0, math.rad(-60)), 0.2 * s, 0.26 * s, stem)
	egg(m, "Leaf", centre * CFrame.new(-0.35 * s, height / 2 + 0.02, 0.15 * s) * CFrame.Angles(math.rad(8), math.rad(30), math.rad(14)), Vector3.new(0.75, 0.07, 0.5) * s, COLORS.leaf)
	return centre
end

-- A long melon with dark stripes running end to end.
local function melon(m, base, size: Vector3, body: Color3, stripe: Color3, extra)
	local centre = base * CFrame.new(0, size.Y / 2, 0)
	egg(m, "Melon", centre, size, body, extra)
	for i = 0, 4 do
		-- (thin eggs as long as the melon, turned round its length: each shows as two stripes)
		egg(m, "Stripe", centre * CFrame.Angles(math.rad(i * 36), 0, 0), Vector3.new(size.X + 0.05, size.Y + 0.1, 0.22 * size.Y / 1.3), stripe)
	end
	return centre
end

-- A pineapple (1.0 across at k = 1): a studded golden body under a crown of
-- spiky leaves. `rows` of eyes (5 alone; fewer in a crowd).
function ONE.Pineapple(m, base: CFrame, k: number, rows: number)
	local centre = base * CFrame.new(0, 0.7 * k, 0)
	egg(m, "Fruit", centre, Vector3.new(1.0, 1.4, 1.0) * k, Color3.fromRGB(232, 170, 52))
	for row = 1, rows do
		local y = (row - (rows + 1) / 2) * 0.24 * 5 / rows
		local r = 0.5 * math.sqrt(1 - (y / 0.7) ^ 2)
		for i = 0, 5 do
			local a = math.rad(i * 60 + row * 30)
			egg(m, "Eye", centre * CFrame.new(Vector3.new(math.cos(a) * r, y, math.sin(a) * r) * k) * CFrame.Angles(0, -a, 0), Vector3.new(0.08, 0.13, 0.13) * k,
				Color3.fromRGB(128, 100, 40))
		end
	end
	for i = 0, 8 do
		local tall = i >= 6
		local leaf = base * CFrame.new(0, 1.3 * k, 0) * CFrame.Angles(0, math.rad(i * 40), math.rad(if tall then 8 else 32)) * CFrame.new(0, (if tall then 0.55 else 0.4) * k, 0)
		part(m, "Crown", leaf, Vector3.new(0.08, if tall then 1.1 else 0.8, 0.22) * k, if i % 2 == 0 then COLORS.leafDark else COLORS.leaf)
	end
end

-- A cocoa pod (1.65 long at k = 1): long, ridged, orange-brown, a woody
-- stem; its middle at `centre`, its length along `centre`'s Y.
function ONE.CocoaPod(m, centre: CFrame, k: number)
	egg(m, "Pod", centre, Vector3.new(0.86, 1.65, 0.86) * k, Color3.fromRGB(196, 110, 46))
	for i = 0, 4 do
		egg(m, "Ridge", centre * CFrame.Angles(0, math.rad(i * 36), 0), Vector3.new(0.2, 1.55, 0.98) * k, Color3.fromRGB(170, 92, 38))
	end
	rod(m, "Stem", centre * CFrame.new(0, 0.9 * k, 0), 0.16 * k, 0.34 * k, STEM)
end

-- A dragonfruit (1.1 across at k = 1): magenta, green-tipped scales in
-- `rows` rings round it (3 alone; fewer in a basket).
function ONE.Dragonfruit(m, centre: CFrame, k: number, rows: number)
	local pink = Color3.fromRGB(232, 62, 142)
	egg(m, "Fruit", centre, Vector3.new(1.1, 1.3, 1.1) * k, pink)
	local ys = if rows >= 3 then { -0.38, -0.02, 0.32 } else { -0.24, 0.24 }
	for row, y in ys do
		local r = 0.55 * math.sqrt(1 - (y / 0.65) ^ 2) - 0.03
		for i = 0, 4 do
			local a = math.rad(i * 72 + row * 36)
			local scale = centre * CFrame.Angles(0, a, 0) * CFrame.new(Vector3.new(0, y, r) * k) * CFrame.Angles(math.rad(-18), 0, 0) -- (lying on the skin)
			egg(m, "Scale", scale * CFrame.new(0, 0.1 * k, 0), Vector3.new(0.36, 0.38, 0.1) * k, Color3.fromRGB(240, 92, 160))
			egg(m, "ScaleTip", scale * CFrame.new(0, 0.3 * k, 0.04 * k) * CFrame.Angles(math.rad(-30), 0, 0), Vector3.new(0.18, 0.2, 0.07) * k, Color3.fromRGB(130, 190, 70))
		end
	end
	for i = 0, 2 do
		part(m, "Tuft", centre * CFrame.new(0, 0.62 * k, 0) * CFrame.Angles(0, math.rad(i * 120), math.rad(25)) * CFrame.new(0, 0.18 * k, 0), Vector3.new(0.07, 0.38, 0.18) * k, COLORS.leaf)
	end
end

-- A bunch of grapes hanging from `base` (its bottom; 1.9 long at k = 1) on
-- its woody stem, a vine leaf behind. `full`: every layer of grapes.
function ONE.Grapes(m, base: CFrame, k: number, full: boolean)
	local purples = { Color3.fromRGB(124, 62, 164), Color3.fromRGB(106, 50, 146), Color3.fromRGB(140, 76, 180) }
	local layers = if full then { { 1.3, 0.42, 7 }, { 1.0, 0.36, 6 }, { 0.72, 0.28, 5 }, { 0.46, 0.18, 3 }, { 0.22, 0, 1 } }
		else { { 1.25, 0.4, 6 }, { 0.85, 0.3, 5 }, { 0.48, 0.17, 3 }, { 0.22, 0, 1 } }
	local n = 0
	for _, layer in layers do
		local y, r, count = layer[1], layer[2], layer[3]
		for i = 1, count do
			n += 1
			local a = i / count * math.pi * 2 + y * 2
			ball(m, "Grape", base * CFrame.new(Vector3.new(math.cos(a) * r, y, math.sin(a) * r) * k), 0.38 * k, purples[n % 3 + 1])
		end
		if full and r > 0.25 then
			ball(m, "Grape", base * CFrame.new(0, y * k, 0), 0.38 * k, purples[(n + 1) % 3 + 1]) -- (filled in the middle)
		end
	end
	rod(m, "Stem", base * CFrame.new(0, 1.62 * k, 0.05 * k) * CFrame.Angles(math.rad(10), 0, 0), 0.14 * k, 0.5 * k, STEM)
	egg(m, "Leaf", base * CFrame.new(Vector3.new(0.25, 1.62, 0.32) * k) * CFrame.Angles(math.rad(-60), math.rad(20), 0), Vector3.new(0.95, 0.06, 0.8) * k, COLORS.leaf)
end

-- A starfruit (1.55 long at k = 1): five glowing fins round its length.
function ONE.Starfruit(m, centre: CFrame, k: number)
	for i = 0, 4 do
		egg(m, "Fin", centre * CFrame.Angles(0, math.rad(i * 72), 0) * CFrame.new(0, 0, 0.24 * k), Vector3.new(0.28, 1.55, 1.05) * k,
			if i % 2 == 0 then Color3.fromRGB(250, 220, 80) else Color3.fromRGB(240, 204, 60), { Reflectance = 0.1 })
	end
	rod(m, "Stem", centre * CFrame.new(0, 0.82 * k, 0), 0.12 * k, 0.28 * k, STEM)
end

-- A golden apple (1.3 across at k = 1) with a stem and a leaf; its middle at `centre`.
function ONE.GoldenApple(m, centre: CFrame, k: number)
	egg(m, "Apple", centre, Vector3.new(1.3, 1.2, 1.3) * k, Color3.fromRGB(236, 172, 22), { Reflectance = 0.15 }) -- (shiny gold)
	egg(m, "Dimple", centre * CFrame.new(0, 0.56 * k, 0), Vector3.new(0.4, 0.12, 0.4) * k, Color3.fromRGB(200, 150, 30))
	egg(m, "Shine", centre * CFrame.new(Vector3.new(-0.3, 0.3, -0.4) * k), Vector3.new(0.28, 0.2, 0.1) * k, Color3.fromRGB(255, 248, 210), { Material = Enum.Material.Neon })
	rod(m, "Stem", centre * CFrame.new(0.04 * k, 0.72 * k, 0) * CFrame.Angles(0, 0, math.rad(-12)), 0.12 * k, 0.38 * k, STEM)
	egg(m, "Leaf", centre * CFrame.new(0.28 * k, 0.76 * k, 0) * CFrame.Angles(0, 0, math.rad(-28)), Vector3.new(0.5, 0.06, 0.26) * k, COLORS.leaf)
end

-- The Crystal Rose: crystal petals round a glowing bud, on a green stem.
function ONE.CrystalRose(m, base: CFrame)
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
end

-- The Phoenix Pepper: a long chilli lying along +X from `base`, curling up
-- at the tip, glowing.
function ONE.PhoenixPepper(m, base: CFrame)
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
end

-- The big ones, alone (on `base`): returns width, height, hold.
local BIG = {}

function BIG.Pumpkin(m, base)
	pumpkin(m, base, 1.9, 1.25, Color3.fromRGB(240, 127, 30), Color3.fromRGB(226, 112, 24), Color3.fromRGB(104, 112, 52))
	return 1.9, 1.75, 0.55
end

function BIG.Watermelon(m, base)
	melon(m, base, Vector3.new(2.0, 1.3, 1.3), Color3.fromRGB(104, 168, 78), Color3.fromRGB(40, 104, 50))
	return 2.05, 1.4, 0.6
end

-- The Moonmelon: a glowing pale melon with silvery stripes.
function BIG.Moonmelon(m, base)
	local before = #m:GetChildren()
	melon(m, base, Vector3.new(1.7, 1.45, 1.45), Color3.fromRGB(206, 224, 255), Color3.fromRGB(140, 160, 214), { Material = Enum.Material.Neon })
	for i, stripe in m:GetChildren() do
		if i > before and stripe.Name == "Stripe" then
			stripe.Material = Enum.Material.SmoothPlastic -- (bands on the glow)
		end
	end
	return 1.75, 1.55, 0.65
end

function BIG.DragonsEyePumpkin(m, base)
	local centre = pumpkin(m, base, 2.15, 1.4, Color3.fromRGB(156, 42, 124), Color3.fromRGB(132, 32, 104), Color3.fromRGB(56, 40, 44))
	local eye = centre * CFrame.new(0, 0.05, -2.15 / 2 + 0.06) -- (on the front rib's face)
	egg(m, "Eye", eye, Vector3.new(0.78, 0.5, 0.28), Color3.fromRGB(255, 214, 60), { Material = Enum.Material.Neon })
	egg(m, "Pupil", eye * CFrame.new(0, 0, -0.06), Vector3.new(0.13, 0.44, 0.24), COLORS.dark)
	return 2.15, 1.95, 0.6
end

------------------------------------------------------------------------
-- As many as a patch gives: each returns { width, height, hold }

local BUILDERS = {}

-- A bunch of carrots tied at the top, roots hanging, a spray of feathery
-- leaves above the tie: a ring of them (one in the middle from six).
function BUILDERS.Carrot(m, base, n)
	local ring = if n >= 6 then n - 1 else n
	local r = if n <= 2 then 0.12 elseif n <= 5 then 0.22 else 0.3
	local spots = {}
	for i = 1, ring do
		local a = (i / ring) * math.pi * 2 + 0.4
		table.insert(spots, { math.cos(a) * r, math.sin(a) * r })
	end
	if ring < n then
		table.insert(spots, { 0, 0 })
	end
	for i, s in spots do
		local tilt = CFrame.Angles(math.rad(s[2] * 15), 0, math.rad(-s[1] * 15)) -- (the tips lean in a little)
		ONE.Carrot(m, base * CFrame.new(s[1], 1.45, s[2]) * tilt, i)
	end
	rod(m, "Twine", base * CFrame.new(0, 1.47, 0), 2 * r + 0.42, 0.14, Color3.fromRGB(176, 120, 60))
	return { width = 2 * r + 0.62, height = 2.65, hold = 1.0 }
end

-- Sheaves of wheat: one alone; more stood together, leaning out a little,
-- tied round the middle.
function BUILDERS.Wheat(m, base, n)
	if n == 1 then
		ONE.Sheaf(m, base, 14, 1)
		return { width = 1.15, height = 2.75, hold = 0.72 }
	end
	local r = if n <= 3 then 0.36 else 0.5
	for i = 1, n do
		local a = i / n * math.pi * 2 + 0.3
		ONE.Sheaf(m, base * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r) * CFrame.Angles(math.sin(a) * 0.1, 0, -math.cos(a) * 0.1), 9, 0.75)
	end
	rod(m, "Twine", base * CFrame.new(0, 1.0, 0), 2 * r + 0.62, 0.22, Color3.fromRGB(176, 120, 60))
	return { width = 2 * r + 1.0, height = 2.75, hold = 0.72 }
end

-- Potatoes heaped in a little slatted crate.
function BUILDERS.Potato(m, base, n)
	local size = if n <= 6 then Vector3.new(1.45, 0.7, 1.05) elseif n <= 12 then Vector3.new(1.8, 0.75, 1.3) else Vector3.new(2.1, 0.8, 1.55)
	local top = crate(m, base, size)
	local tones = { Color3.fromRGB(176, 128, 80), Color3.fromRGB(158, 112, 68), Color3.fromRGB(186, 140, 90) }
	local spots = pile(base * CFrame.new(0, top - 0.12, 0), n, 0.5, size.X - 0.1, size.Z - 0.1)
	for i, at in spots do
		egg(m, "Potato", at, Vector3.new(0.58, 0.42, 0.45), tones[i % 3 + 1])
	end
	return { width = size.X + 0.08, height = math.max(top, heapTop(base, spots, 0.5)) + 0.05, hold = 0.4 }
end

-- A head of lettuce; more sitting in a shallow crate.
function BUILDERS.Lettuce(m, base, n)
	if n == 1 then
		ONE.Lettuce(m, base, 1)
		return { width = 1.55, height = 1.15, hold = 0.5 }
	end
	local cols = if n <= 4 then 2 else 3
	local rows = math.ceil(n / cols)
	local size = Vector3.new(cols * 1.0 + 0.12, 0.45, rows * 1.0 + 0.12)
	local top = crate(m, base, size)
	for _, at in grid(base * CFrame.new(0, top - 0.18, 0), n, cols, Vector2.new(1.0, 1.0)) do
		ONE.Lettuce(m, at, 0.66)
	end
	return { width = size.X + 0.08, height = top + 0.6, hold = 0.3 }
end

-- Cobs of corn tied at the bottom: a row in front, a row behind.
function BUILDERS.Corn(m, base, n)
	local front = math.ceil(n / 2)
	local back = n - front
	local i = 0
	for row, count in { front, back } do
		for c = 1, count do
			i += 1
			local x = (c - (count + 1) / 2) * 0.42
			local z = if row == 1 then -0.14 else 0.14
			ONE.Cob(m, base * CFrame.new(x, 0.1, z) * CFrame.Angles(0, 0, math.rad(-x * 22)))
		end
	end
	rod(m, "Twine", base * CFrame.new(0, 0.32, 0), front * 0.42 + 0.3, 0.16, Color3.fromRGB(176, 120, 60))
	return { width = front * 0.42 + 0.66, height = 1.72, hold = 0.75 }
end

-- Onions on a string: their dry tops twisted together and tied, the bulbs
-- hanging round the knot in two rings.
function BUILDERS.Onion(m, base, n)
	local knot = Vector3.new(0, 1.15, 0.04)
	local lower = if n <= 3 then n else math.ceil(n * 0.6)
	local spots = {}
	for i = 1, n do
		local upper = i > lower
		local count = if upper then n - lower else lower
		local j = if upper then i - lower else i
		local a = (j / count) * math.pi * 2 + (if upper then 0.6 else 0)
		local r = if upper then 0.3 elseif n <= 3 then 0.45 else 0.52
		table.insert(spots, Vector3.new(math.cos(a) * r, if upper then 0.72 else 0.36, math.sin(a) * r))
	end
	for i, at in spots do
		local bulb = base * CFrame.new(at)
		egg(m, "Bulb", bulb, Vector3.new(0.74, 0.66, 0.74), if i % 3 == 0 then Color3.fromRGB(196, 140, 78) else Color3.fromRGB(214, 160, 92))
		egg(m, "Roots", bulb * CFrame.new(0, -0.32, 0), Vector3.new(0.26, 0.1, 0.26), Color3.fromRGB(232, 216, 180))
		local neckFrom, neckTo = at + Vector3.new(0, 0.3, 0), knot
		local mid = (neckFrom + neckTo) / 2
		rod(m, "Neck", base * CFrame.lookAt(mid, neckTo) * CFrame.Angles(math.rad(90), 0, 0), 0.16, (neckTo - neckFrom).Magnitude + 0.1, Color3.fromRGB(200, 170, 110))
	end
	rod(m, "Twine", base * CFrame.new(knot), 0.34, 0.2, Color3.fromRGB(176, 120, 60))
	local r = if n <= 3 then 0.45 else 0.52
	return { width = 2 * r + 0.74, height = 1.3, hold = 0.38 }
end

-- A punnet of strawberries; more on a wooden tray, two across.
function BUILDERS.Strawberry(m, base, n)
	if n == 1 then
		ONE.StrawberryPunnet(m, base, 1, 8)
		return { width = 1.42, height = 1.15, hold = 0.3 }
	end
	local k = 0.8
	local cols = if n <= 4 then 2 else 3
	local rows = math.ceil(n / cols)
	local tray = Vector3.new(cols * 1.2 + 0.12, 0.12, rows * 0.92 + 0.12)
	part(m, "Tray", base * CFrame.new(0, 0.06, 0), tray, COLORS.edging)
	for _, at in grid(base * CFrame.new(0, 0.12, 0), n, cols, Vector2.new(1.2, 0.92)) do
		ONE.StrawberryPunnet(m, at, k, 6)
	end
	return { width = tray.X, height = 0.12 + 0.95 * k, hold = 0.25 }
end

-- Tomatoes heaped in a basket, green stars on top.
function BUILDERS.Tomato(m, base, n)
	local d = if n <= 6 then 1.25 elseif n <= 9 then 1.5 else 1.75
	local top = basket(m, base, d, 0.75)
	local spots = pile(base * CFrame.new(0, top, 0), n, 0.5, d)
	for _, at in spots do
		ball(m, "Tomato", at, 0.5, Color3.fromRGB(222, 62, 46))
		rod(m, "Calyx", at * CFrame.new(0, 0.24, 0), 0.24, 0.05, COLORS.leaf)
	end
	return { width = d + 0.14, height = heapTop(base, spots, 0.5) + 0.05, hold = 0.45 }
end

-- One big bell pepper; more in a basket.
function BUILDERS.BellPepper(m, base, n)
	if n == 1 then
		ONE.BellPepper(m, base, 1)
		return { width = 1.1, height = 1.55, hold = 0.55 }
	end
	-- (standing up, stems up, leaning out a little: a ring round the rim, the
	-- rest in the middle, raised)
	local d = if n <= 4 then 1.6 else 1.95
	local top = basket(m, base, d, 0.6)
	local ring = if n <= 4 then n - 1 else n - 2
	local high = top
	for i = 1, n do
		local inRing = i <= ring
		local a = (i / math.max(ring, 1)) * math.pi * 2 + 0.3
		local r = if inRing then d / 2 - 0.38 else (if n - ring > 1 then 0.18 else 0)
		local lift = if inRing then -0.3 else 0.05
		local at = base * CFrame.new(math.cos(a) * r, top + lift, math.sin(a) * r) * CFrame.Angles(math.sin(a) * (if inRing then 0.25 else 0), 0, -math.cos(a) * (if inRing then 0.25 else 0))
		ONE.BellPepper(m, at, 0.68)
		high = math.max(high, top + lift + 1.55 * 0.68)
	end
	return { width = d + 0.14, height = high, hold = 0.42 }
end

-- A pumpkin, a melon, the Moonmelon or the Dragon's Eye: one on its own (a
-- thief can only carry one); two side by side if it's ever more.
local function big(cropId: string)
	return function(m, base, n)
		if n == 1 then
			local width, height, hold = BIG[cropId](m, base)
			return { width = width, height = height, hold = hold }
		end
		local width, height, hold = 0, 0, 0
		for i = 1, n do
			local sub = Instance.new("Model")
			local w, h, y = BIG[cropId](sub, CFrame.new())
			width, height, hold = w, h, y
			for _, p in sub:GetChildren() do
				p.Size *= 0.8
				p.CFrame = base * CFrame.new((i - (n + 1) / 2) * w * 0.82, 0, 0) * CFrame.new(p.CFrame.Position * 0.8) * p.CFrame.Rotation
				p.Parent = m
			end
			sub:Destroy()
		end
		return { width = width * 0.82 * n, height = height * 0.8, hold = hold * 0.8 }
	end
end
BUILDERS.Pumpkin = big("Pumpkin")
BUILDERS.Watermelon = big("Watermelon")
BUILDERS.Moonmelon = big("Moonmelon")
BUILDERS.DragonsEyePumpkin = big("DragonsEyePumpkin")

-- Punnets of blueberries on a tray (one alone: a small basket heaped high).
function BUILDERS.Blueberry(m, base, n)
	if n == 1 then
		local top = basket(m, base, 1.1, 0.65)
		local blues = { Color3.fromRGB(72, 92, 204), Color3.fromRGB(58, 72, 176), Color3.fromRGB(92, 110, 214) }
		local count = 0
		for ring, r in { 0.38, 0.2, 0 } do
			local inRing = if r == 0 then 1 else math.floor(r * 22)
			for i = 1, inRing do
				count += 1
				local a = i / inRing * math.pi * 2 + ring
				ball(m, "Berry", base * CFrame.new(math.cos(a) * r, top + 0.1 + (ring - 1) * 0.13, math.sin(a) * r), 0.26, blues[count % 3 + 1])
			end
		end
		return { width = 1.24, height = 1.2, hold = 0.4 }
	end
	local k = 0.8
	local cols = if n <= 4 then 2 else 3
	local rows = math.ceil(n / cols)
	local tray = Vector3.new(cols * 1.2 + 0.12, 0.12, rows * 0.92 + 0.12)
	part(m, "Tray", base * CFrame.new(0, 0.06, 0), tray, COLORS.edging)
	for _, at in grid(base * CFrame.new(0, 0.12, 0), n, cols, Vector2.new(1.2, 0.92)) do
		ONE.BlueberryPunnet(m, at, k)
	end
	return { width = tray.X, height = 0.12 + 0.85 * k, hold = 0.25 }
end

-- Pineapples standing side by side.
function BUILDERS.Pineapple(m, base, n)
	for _, at in grid(base, n, n, Vector2.new(1.05, 0)) do
		ONE.Pineapple(m, at, 1, if n == 1 then 5 else 3)
	end
	return { width = n * 1.05, height = 2.4, hold = 0.65 }
end

-- A cocoa pod; more lying in a shallow basket like spokes.
function BUILDERS.CocoaPod(m, base, n)
	if n == 1 then
		ONE.CocoaPod(m, base * CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.rad(8)), 1)
		return { width = 1.0, height = 1.85, hold = 0.8 }
	end
	local d = if n <= 4 then 2.0 else 2.3
	local top = basket(m, base, d, 0.4)
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + 0.4
		ONE.CocoaPod(m, base * CFrame.new(math.cos(a) * 0.45, top + 0.28, math.sin(a) * 0.45) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(90 - (i % 2) * 12)), 0.75)
	end
	return { width = d + 0.14, height = top + 0.72, hold = 0.3 }
end

-- A dragonfruit; more in a basket, leaning out round its rim.
function BUILDERS.Dragonfruit(m, base, n)
	if n == 1 then
		ONE.Dragonfruit(m, base * CFrame.new(0, 0.66, 0), 1, 3)
		return { width = 1.3, height = 1.55, hold = 0.6 }
	end
	local d = if n <= 3 then 1.7 else 2.0
	local top = basket(m, base, d, 0.55)
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + 0.5
		local r = if n == 1 then 0 else 0.36
		ONE.Dragonfruit(m, base * CFrame.new(math.cos(a) * r, top + 0.32, math.sin(a) * r) * CFrame.Angles(math.sin(a) * 0.35, 0, -math.cos(a) * 0.35), 0.75, 2)
	end
	return { width = d + 0.14, height = top + 1.0, hold = 0.4 }
end

-- A bunch of grapes; more lying side by side in a shallow basket.
function BUILDERS.GrapeVine(m, base, n)
	if n == 1 then
		ONE.Grapes(m, base, 1, true)
		return { width = 1.25, height = 1.9, hold = 1.0 }
	end
	local d = math.max(1.8, n * 0.62 + 0.2)
	local top = basket(m, base, d, 0.4)
	for _, at in grid(base * CFrame.new(0, top + 0.28, -0.55), n, n, Vector2.new(0.62, 0)) do
		ONE.Grapes(m, at * CFrame.Angles(math.rad(80), 0, 0), 0.62, false) -- (lying down, the stems to the back)
	end
	return { width = d + 0.14, height = top + 0.75, hold = 0.3 }
end

-- A starfruit; more lying side by side in a basket.
function BUILDERS.Starfruit(m, base, n)
	if n == 1 then
		ONE.Starfruit(m, base * CFrame.new(0, 0.78, 0), 1)
		return { width = 1.5, height = 1.7, hold = 0.75 }
	end
	local d = math.max(1.6, n * 0.55 + 0.35)
	local top = basket(m, base, d, 0.55)
	for i, at in grid(base * CFrame.new(0, top + 0.22, 0), n, n, Vector2.new(0.55, 0)) do
		ONE.Starfruit(m, at * CFrame.Angles(math.rad(90), math.rad(i * 25), 0), 0.68)
	end
	return { width = d + 0.14, height = top + 0.75, hold = 0.42 }
end

-- A golden apple; more heaped in a basket.
function BUILDERS.GoldenApple(m, base, n)
	if n == 1 then
		ONE.GoldenApple(m, base * CFrame.new(0, 0.62, 0), 1)
		return { width = 1.35, height = 1.5, hold = 0.55 }
	end
	local d = if n <= 5 then 1.7 elseif n <= 8 then 2.0 else 2.3
	local top = basket(m, base, d, 0.6)
	local spots = pile(base * CFrame.new(0, top - 0.1, 0), n, 0.8, d)
	for _, at in spots do
		ONE.GoldenApple(m, at, 0.62)
	end
	return { width = d + 0.14, height = heapTop(base, spots, 1.0), hold = 0.42 }
end

-- The Crystal Rose; two make a little bouquet, tied with a ribbon.
function BUILDERS.CrystalRose(m, base, n)
	for i = 1, n do
		local lean = if n == 1 then 0 else (i - (n + 1) / 2) * 0.32
		ONE.CrystalRose(m, base * CFrame.new(lean * 0.6, 0, 0) * CFrame.Angles(0, 0, -lean))
	end
	if n > 1 then
		rod(m, "Ribbon", base * CFrame.new(0, 0.42, 0), 0.5, 0.18, Color3.fromRGB(44, 92, 196))
	end
	return { width = 1.35 + (n - 1) * 0.8, height = 1.95, hold = 1.4 }
end

-- The Phoenix Pepper; more lying side by side.
function BUILDERS.PhoenixPepper(m, base, n)
	for _, at in grid(base, n, 1, Vector2.new(0, 0.75)) do
		ONE.PhoenixPepper(m, at)
	end
	return { width = 2.2, height = 1.1, hold = 0.42 }
end

-- Builds `count` of a crop (default: its perPatch) standing on `base`.
-- Returns the model and its Core part (Width, Height, HoldY attributes; the
-- sparkles).
function ProduceArt.build(cropId: string, base: CFrame, count: number?): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Produce"
	local n = math.max(1, math.floor(count or Crops.ById[cropId].perPatch))
	local info = Meshes.carried(cropId, n, base, model) or BUILDERS[cropId](model, base, n)
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
