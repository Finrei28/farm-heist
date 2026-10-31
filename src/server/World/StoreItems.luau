-- The store's catalog as 3D models (docs/GameDesign.md §4.8, ArtDirection
-- §11 step 9): every display, checkout, decoration and wall item at the
-- 4-stud grid's scale, next to a 5-stud character (waist-high crates and
-- counters, head-high shelves, lamps above head height).
--
-- StoreItems.build(itemId) returns a Model whose pivot is the middle of its
-- footprint on the floor, facing −Z (its front, where shoppers stand). Wall
-- items' pivot is on the wall's face at the item's middle, facing out of
-- the wall. Displays carry invisible "Slot<n>" parts (and "Slot<n>_2"...,
-- more shelves of the same slot) marking where produce goes, and "Tag<n>"
-- cards for their price tags; StoreArt fills them. Every server builds the
-- catalog once into ReplicatedStorage.StoreCatalog, so clients can show the
-- same models in Decorate mode.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Store = require(ReplicatedStorage.Shared.Config.Store)
local Parts = require(script.Parent.Parts)

local COLORS = Parts.COLORS

local StoreItems = {}

local WOOD = COLORS.edging
local DARK_WOOD = COLORS.post
local LIGHT_WOOD = Color3.fromRGB(214, 176, 122)
local GLASS = Color3.fromRGB(190, 225, 240)
local WHITE = Color3.fromRGB(244, 244, 240)
local STEEL = Color3.fromRGB(120, 128, 138)
local GOLD = Color3.fromRGB(240, 190, 60)
local VELVET = Color3.fromRGB(150, 30, 50)
local TERRACOTTA = Color3.fromRGB(196, 104, 66)
local CHALK = Color3.fromRGB(45, 74, 58)
local STONE = Color3.fromRGB(206, 200, 186)

-- Parts in model space (y = 0 is the floor). solid: you bump into it;
-- deco: you don't.
local function solid(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, extra: { [string]: any }?)
	local props: { [string]: any } = { Name = name, Size = size, CFrame = cf, Color = color }
	for k, v in extra or {} do
		props[k] = v
	end
	return Parts.part(props, model)
end
local function deco(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, extra: { [string]: any }?)
	local p = solid(model, name, size, cf, color, extra)
	p.CanCollide = false
	p.CanTouch = false
	return p
end
local function ball(model: Model, name: string, at: Vector3, diameter: number, color: Color3, extra: { [string]: any }?)
	local p = deco(model, name, Vector3.new(diameter, diameter, diameter), CFrame.new(at), color, extra)
	p.Shape = Enum.PartType.Ball
	return p
end
-- An upright cylinder (Roblox cylinders lie along X).
local function upright(model: Model, name: string, at: Vector3, diameter: number, height: number, color: Color3, isSolid: boolean?)
	local make = if isSolid then solid else deco
	local p = make(model, name, Vector3.new(height, diameter, diameter), CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)), color)
	p.Shape = Enum.PartType.Cylinder
	return p
end
-- A cylinder lying along Z (wheels, clock faces on a wall).
local function facing(model: Model, name: string, at: Vector3, diameter: number, thickness: number, color: Color3)
	local p = deco(model, name, Vector3.new(thickness, diameter, diameter), CFrame.new(at) * CFrame.Angles(0, math.rad(90), 0), color)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Words painted on the front (−Z face) of a part.
local function words(p: BasePart, text: string, color: Color3, font: Enum.Font?, light: boolean?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = if light then 0 else 0.6
	gui.Brightness = if light then 2 else 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label
	label.Parent = gui
	gui.Parent = p
	return label
end

-- Where produce goes (invisible): `size` sits on `bottom` (the shelf's top).
local function slot(model: Model, name: string, centreX: number, bottom: number, centreZ: number, size: Vector3)
	deco(model, name, size, CFrame.new(centreX, bottom + size.Y / 2, centreZ), WHITE, { Transparency = 1, CanQuery = false, CastShadow = false })
end
-- A price-tag card on a front edge, facing −Z.
local function tag(model: Model, name: string, at: Vector3)
	deco(model, name, Vector3.new(1.5, 0.75, 0.08), CFrame.new(at), COLORS.cream)
end

------------------------------------------------------------------------
-- Displays

local builders = {}

function builders.ProduceCrate(m: Model)
	for _, x in { -1.35, 1.35 } do
		for _, z in { -0.95, 0.95 } do
			solid(m, "Leg", Vector3.new(0.35, 1.3, 0.35), CFrame.new(x, 0.65, z), DARK_WOOD)
		end
	end
	solid(m, "Crate", Vector3.new(3.2, 1.5, 2.4), CFrame.new(0, 2.05, 0), WOOD)
	for _, y in { 1.6, 2.5 } do
		deco(m, "Slat", Vector3.new(3.3, 0.18, 2.5), CFrame.new(0, y, 0), DARK_WOOD)
	end
	deco(m, "Inside", Vector3.new(2.8, 0.1, 2.0), CFrame.new(0, 2.81, 0), Color3.fromRGB(120, 84, 52))
	slot(m, "Slot1", 0, 2.85, 0, Vector3.new(2.8, 0.9, 2.0))
	tag(m, "Tag1", Vector3.new(0, 2.05, -1.25))
end

function builders.WoodenShelf(m: Model)
	local z = 0.65 -- the unit stands toward the back of its cells
	solid(m, "Back", Vector3.new(7.4, 5.4, 0.2), CFrame.new(0, 2.7, z + 0.9), WOOD)
	for _, x in { -3.6, 3.6 } do
		solid(m, "Side", Vector3.new(0.25, 5.4, 2.0), CFrame.new(x, 2.7, z), DARK_WOOD)
	end
	for _, y in { 0.5, 2.3, 4.1 } do
		solid(m, "Board", Vector3.new(7.0, 0.2, 1.9), CFrame.new(0, y - 0.1, z), LIGHT_WOOD)
	end
	deco(m, "Kick", Vector3.new(7.0, 0.4, 0.15), CFrame.new(0, 0.2, z - 0.95), DARK_WOOD)
	solid(m, "Top", Vector3.new(7.7, 0.25, 2.2), CFrame.new(0, 5.5, z), DARK_WOOD)
	for i, x in { 1.75, -1.75 } do -- slot 1 on the model's +X side (on the left as you face it)
		slot(m, `Slot{i}`, x, 0.5, z, Vector3.new(3.1, 1.2, 1.5))
		slot(m, `Slot{i}_2`, x, 2.3, z, Vector3.new(3.1, 1.2, 1.5))
		slot(m, `Slot{i}_3`, x, 4.1, z, Vector3.new(3.1, 1.0, 1.5))
		tag(m, `Tag{i}`, Vector3.new(x, 2.05, z - 0.98))
	end
end

function builders.BulkBin(m: Model)
	solid(m, "Bin", Vector3.new(3.2, 2.6, 3.0), CFrame.new(0, 1.3, 0.2), WOOD)
	for _, x in { -1.6, 1.6 } do
		for _, zz in { -1.3, 1.7 } do
			deco(m, "Corner", Vector3.new(0.3, 2.7, 0.3), CFrame.new(x, 1.35, zz), DARK_WOOD)
		end
	end
	deco(m, "Band", Vector3.new(3.3, 0.2, 3.1), CFrame.new(0, 1.0, 0.2), DARK_WOOD)
	deco(m, "Inside", Vector3.new(2.8, 0.1, 2.6), CFrame.new(0, 2.61, 0.2), Color3.fromRGB(120, 84, 52))
	-- the lid, propped open at the back
	deco(m, "Lid", Vector3.new(3.2, 0.15, 1.4), CFrame.new(0, 3.2, 1.55) * CFrame.Angles(math.rad(-70), 0, 0), LIGHT_WOOD)
	slot(m, "Slot1", 0, 2.65, 0.2, Vector3.new(2.8, 1.1, 2.6))
	tag(m, "Tag1", Vector3.new(0, 1.7, -1.35))
end

function builders.TieredRack(m: Model)
	-- three steps rising toward the back, like bleachers
	local steps = { { top = 1.3, z0 = -1.4, z1 = -0.45 }, { top = 2.4, z0 = -0.45, z1 = 0.5 }, { top = 3.5, z0 = 0.5, z1 = 1.45 } }
	for i, s in steps do
		solid(m, "Step", Vector3.new(7.4, s.top, s.z1 - s.z0), CFrame.new(0, s.top / 2, (s.z0 + s.z1) / 2), if i % 2 == 1 then WOOD else LIGHT_WOOD)
		deco(m, "Lip", Vector3.new(7.5, 0.25, 0.15), CFrame.new(0, s.top + 0.05, s.z0), DARK_WOOD)
		slot(m, `Slot{i}`, 0, s.top, (s.z0 + s.z1) / 2 + 0.05, Vector3.new(6.8, 0.9, 0.85))
		tag(m, `Tag{i}`, Vector3.new(2.6, s.top - 0.45, s.z0 - 0.06))
	end
	for _, x in { -3.6, 3.6 } do
		deco(m, "Post", Vector3.new(0.3, 5.0, 0.3), CFrame.new(x, 2.5, 1.5), DARK_WOOD)
	end
	local board = deco(m, "Sign", Vector3.new(7.4, 1.0, 0.2), CFrame.new(0, 4.6, 1.5), COLORS.cream)
	words(board, "FRESH TODAY", COLORS.barnRed)
end

function builders.ChillerCabinet(m: Model)
	local z = 0.55
	solid(m, "Cabinet", Vector3.new(7.4, 0.8, 2.2), CFrame.new(0, 0.4, z), WHITE)
	deco(m, "Grille", Vector3.new(7.0, 0.4, 0.08), CFrame.new(0, 0.4, z - 1.12), STEEL)
	solid(m, "Back", Vector3.new(7.4, 5.0, 0.3), CFrame.new(0, 3.3, z + 0.95), WHITE)
	for _, x in { -3.55, 3.55 } do
		solid(m, "Side", Vector3.new(0.3, 4.6, 2.2), CFrame.new(x, 3.1, z), WHITE)
	end
	solid(m, "Canopy", Vector3.new(7.6, 0.6, 2.4), CFrame.new(0, 5.6, z), WHITE)
	deco(m, "Light", Vector3.new(6.6, 0.15, 0.3), CFrame.new(0, 5.28, z - 0.6), Color3.fromRGB(235, 250, 255), { Material = Enum.Material.Neon })
	deco(m, "Inside", Vector3.new(6.8, 4.4, 0.1), CFrame.new(0, 3.0, z + 0.78), Color3.fromRGB(200, 230, 245))
	for _, y in { 0.8, 2.7 } do
		solid(m, "Shelf", Vector3.new(6.8, 0.15, 1.6), CFrame.new(0, y + 0.07, z + 0.05), Color3.fromRGB(225, 232, 238))
	end
	-- glass doors, one per slot, each with a handle
	for i, x in { 1.75, -1.75 } do
		solid(m, "Door", Vector3.new(3.4, 4.4, 0.1), CFrame.new(x, 3.0, z - 1.05), GLASS, { Transparency = 0.6, Reflectance = 0.15 })
		deco(m, "Handle", Vector3.new(0.15, 1.6, 0.15), CFrame.new(x + (if i == 1 then -1.45 else 1.45), 3.0, z - 1.18), STEEL)
		slot(m, `Slot{i}`, x, 0.95, z + 0.05, Vector3.new(3.0, 1.4, 1.4))
		slot(m, `Slot{i}_2`, x, 2.85, z + 0.05, Vector3.new(3.0, 1.4, 1.4))
		tag(m, `Tag{i}`, Vector3.new(x, 0.55, z - 1.16))
	end
end

function builders.GlassShowcase(m: Model)
	solid(m, "Plinth", Vector3.new(2.8, 2.6, 2.4), CFrame.new(0, 1.3, 0.2), DARK_WOOD)
	deco(m, "Panel", Vector3.new(2.3, 1.8, 0.08), CFrame.new(0, 1.3, -1.02), WOOD)
	solid(m, "Glass", Vector3.new(2.6, 1.7, 2.2), CFrame.new(0, 3.45, 0.2), GLASS, { Transparency = 0.7, Reflectance = 0.2 })
	solid(m, "Cap", Vector3.new(2.85, 0.18, 2.45), CFrame.new(0, 4.39, 0.2), GOLD, { Reflectance = 0.25 })
	deco(m, "Cushion", Vector3.new(2.3, 0.15, 1.9), CFrame.new(0, 2.68, 0.2), VELVET)
	slot(m, "Slot1", 0, 2.75, 0.2, Vector3.new(2.0, 1.0, 1.6))
	tag(m, "Tag1", Vector3.new(0, 2.2, -1.06))
end

function builders.VelvetPedestal(m: Model)
	upright(m, "Foot", Vector3.new(0, 0.2, 0), 2.6, 0.4, STONE, true)
	upright(m, "Column", Vector3.new(0, 1.7, 0), 1.4, 2.6, STONE, true)
	upright(m, "Top", Vector3.new(0, 3.15, 0), 2.3, 0.3, VELVET, true)
	upright(m, "Rim", Vector3.new(0, 3.0, 0), 2.45, 0.12, GOLD)
	ball(m, "Dome", Vector3.new(0, 3.55, 0), 2.0, GLASS, { Transparency = 0.75, Reflectance = 0.2 })
	for i = 0, 3 do
		local a = math.rad(45 + 90 * i)
		ball(m, "Finial", Vector3.new(math.cos(a) * 1.15, 3.35, math.sin(a) * 1.15), 0.3, GOLD)
	end
	slot(m, "Slot1", 0, 3.3, 0, Vector3.new(1.2, 1.2, 1.2))
	tag(m, "Tag1", Vector3.new(0, 1.9, -0.74))
end

------------------------------------------------------------------------
-- Checkouts

function builders.HonourBox(m: Model)
	solid(m, "Foot", Vector3.new(1.8, 0.3, 1.8), CFrame.new(0, 0.15, 0.3), DARK_WOOD)
	solid(m, "Post", Vector3.new(0.5, 2.9, 0.5), CFrame.new(0, 1.75, 0.3), WOOD)
	solid(m, "Box", Vector3.new(2.0, 1.3, 1.4), CFrame.new(0, 3.85, 0.25), COLORS.hay)
	deco(m, "Slot", Vector3.new(1.0, 0.08, 0.25), CFrame.new(0, 4.52, 0.25), COLORS.dark)
	deco(m, "Lid", Vector3.new(2.1, 0.12, 1.5), CFrame.new(0, 4.5, 0.25), Color3.fromRGB(224, 160, 48))
	local sign = deco(m, "Sign", Vector3.new(2.4, 1.1, 0.15), CFrame.new(0, 5.35, 0.85), COLORS.cream)
	words(sign, "PAY HERE ♥", COLORS.barnRed)
	for _, x in { -1.1, 1.1 } do
		deco(m, "SignPost", Vector3.new(0.15, 1.2, 0.15), CFrame.new(x, 4.95, 0.92), DARK_WOOD)
	end
end

function builders.Register(m: Model)
	solid(m, "Counter", Vector3.new(7.2, 3.2, 2.2), CFrame.new(0, 1.6, 0.1), COLORS.cream)
	deco(m, "Stripe", Vector3.new(7.25, 0.5, 2.25), CFrame.new(0, 2.4, 0.1), COLORS.barnRed)
	deco(m, "Kick", Vector3.new(7.25, 0.4, 2.25), CFrame.new(0, 0.2, 0.1), DARK_WOOD)
	solid(m, "CounterTop", Vector3.new(7.6, 0.25, 2.6), CFrame.new(0, 3.32, 0.1), DARK_WOOD)
	deco(m, "Belt", Vector3.new(4.2, 0.12, 1.4), CFrame.new(-1.3, 3.5, 0), Color3.fromRGB(50, 50, 54))
	-- the till at the +X end (where the paying shopper stands)
	deco(m, "Till", Vector3.new(1.8, 0.7, 1.4), CFrame.new(2.2, 3.8, 0.35), STEEL)
	deco(m, "Keys", Vector3.new(1.2, 0.1, 0.8), CFrame.new(2.2, 4.12, 0.55) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(60, 62, 68))
	deco(m, "ScreenPost", Vector3.new(0.2, 0.9, 0.2), CFrame.new(2.2, 4.6, 0.05), STEEL)
	local screen = deco(m, "Screen", Vector3.new(1.3, 0.8, 0.12), CFrame.new(2.2, 5.2, 0), COLORS.dark)
	words(screen, "THANK YOU", Color3.fromRGB(120, 230, 140), Enum.Font.Code, true)
	-- a lane light on a pole at the back corner
	deco(m, "LanePole", Vector3.new(0.25, 3.2, 0.25), CFrame.new(3.4, 4.9, 1.0), STEEL)
	local light = deco(m, "LaneLight", Vector3.new(0.9, 0.9, 0.9), CFrame.new(3.4, 6.9, 1.0), Color3.fromRGB(120, 230, 140), { Material = Enum.Material.Neon })
	light.Shape = Enum.PartType.Ball
end

function builders.SelfCheckout(m: Model)
	solid(m, "Cabinet", Vector3.new(2.4, 2.9, 1.8), CFrame.new(0, 1.45, 0.4), WHITE)
	deco(m, "Band", Vector3.new(2.45, 0.35, 1.85), CFrame.new(0, 2.5, 0.4), COLORS.leaf)
	deco(m, "Scanner", Vector3.new(1.6, 0.1, 1.0), CFrame.new(0, 2.95, 0.2), COLORS.dark, { Reflectance = 0.3 })
	deco(m, "Bagging", Vector3.new(0.9, 0.15, 1.4), CFrame.new(-1.5, 2.6, 0.3), STEEL)
	deco(m, "ScreenPost", Vector3.new(0.2, 1.0, 0.2), CFrame.new(0.6, 3.4, 1.0), STEEL)
	local screen = deco(m, "Screen", Vector3.new(1.4, 1.0, 0.12), CFrame.new(0.6, 4.2, 0.85) * CFrame.Angles(math.rad(-15), 0, 0), COLORS.dark)
	words(screen, "SCAN ITEMS", Color3.fromRGB(150, 220, 255), Enum.Font.Code, true)
	deco(m, "LanePole", Vector3.new(0.2, 2.2, 0.2), CFrame.new(0.9, 4.0, 1.15), STEEL)
	local light = deco(m, "LaneLight", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0.9, 5.3, 1.15), Color3.fromRGB(120, 230, 140), { Material = Enum.Material.Neon })
	light.Shape = Enum.PartType.Ball
end

------------------------------------------------------------------------
-- Decor

function builders.PottedPlant(m: Model)
	upright(m, "Pot", Vector3.new(0, 0.75, 0), 1.7, 1.5, TERRACOTTA, true)
	upright(m, "PotRim", Vector3.new(0, 1.45, 0), 1.9, 0.25, TERRACOTTA)
	upright(m, "Soil", Vector3.new(0, 1.5, 0), 1.5, 0.12, COLORS.soil)
	for _, leaf in { { 0, 2.6, 0, 2.0 }, { 0.6, 2.2, 0.3, 1.5 }, { -0.55, 2.3, -0.3, 1.5 }, { 0.1, 3.3, -0.1, 1.3 } } do
		ball(m, "Leaves", Vector3.new(leaf[1], leaf[2], leaf[3]), leaf[4], if leaf[4] > 1.6 then COLORS.leaf else COLORS.leafDark)
	end
end

function builders.HayBaleSeat(m: Model)
	solid(m, "Bale", Vector3.new(3.0, 1.6, 1.8), CFrame.new(0, 0.8, 0), Color3.fromRGB(226, 190, 96))
	for _, x in { -0.8, 0.8 } do
		deco(m, "Twine", Vector3.new(0.12, 1.65, 1.85), CFrame.new(x, 0.8, 0), Color3.fromRGB(170, 120, 60))
	end
	deco(m, "Top", Vector3.new(2.9, 0.06, 1.7), CFrame.new(0, 1.62, 0), Color3.fromRGB(236, 204, 112))
end

function builders.FlowerBarrel(m: Model)
	upright(m, "Barrel", Vector3.new(0, 0.85, 0), 2.4, 1.7, WOOD, true)
	for _, y in { 0.35, 1.35 } do
		upright(m, "Hoop", Vector3.new(0, y, 0), 2.48, 0.15, STEEL)
	end
	upright(m, "Soil", Vector3.new(0, 1.71, 0), 2.1, 0.1, COLORS.soil)
	local colors = { Color3.fromRGB(240, 110, 160), COLORS.hay, WHITE, Color3.fromRGB(170, 120, 230) }
	for i = 0, 6 do
		local a = math.rad(i * 51)
		local r = if i == 0 then 0 else 0.7
		ball(m, "Leaves", Vector3.new(math.cos(a) * r, 2.1, math.sin(a) * r), 0.9, COLORS.leaf)
		ball(m, "Flower", Vector3.new(math.cos(a) * r, 2.6, math.sin(a) * r), 0.55, colors[i % #colors + 1])
	end
end

function builders.PumpkinPile(m: Model)
	local orange = Color3.fromRGB(236, 128, 40)
	for _, p in { { -0.75, 0.8, -0.3, 1.6 }, { 0.85, 0.85, 0.1, 1.7 }, { -0.1, 0.75, 0.9, 1.5 }, { 0.05, 2.0, 0.2, 1.4 } } do
		ball(m, "Pumpkin", Vector3.new(p[1], p[2], p[3]), p[4], orange)
		deco(m, "Stem", Vector3.new(0.18, 0.35, 0.18), CFrame.new(p[1], p[2] + p[4] / 2 + 0.1, p[3]), COLORS.leafDark)
	end
	solid(m, "Base", Vector3.new(2.8, 1.4, 2.6), CFrame.new(0, 0.7, 0.2), orange, { Transparency = 1 })
end

function builders.LampPost(m: Model)
	local green = Color3.fromRGB(46, 84, 60)
	solid(m, "Foot", Vector3.new(1.1, 0.6, 1.1), CFrame.new(0, 0.3, 0), green)
	solid(m, "Post", Vector3.new(0.4, 6.4, 0.4), CFrame.new(0, 3.5, 0), green)
	deco(m, "Cap", Vector3.new(1.3, 0.3, 1.3), CFrame.new(0, 8.25, 0), green)
	local lamp = deco(m, "Lamp", Vector3.new(0.9, 1.2, 0.9), CFrame.new(0, 7.5, 0), Color3.fromRGB(255, 226, 160), { Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 214, 150)
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = lamp
	deco(m, "Ring", Vector3.new(1.1, 0.15, 1.1), CFrame.new(0, 6.85, 0), green)
end

function builders.Rug(m: Model)
	deco(m, "Rug", Vector3.new(3.5, 0.06, 3.5), CFrame.new(0, 0.03, 0), COLORS.barnRed)
	deco(m, "Border", Vector3.new(2.9, 0.08, 2.9), CFrame.new(0, 0.04, 0), COLORS.cream)
	deco(m, "Middle", Vector3.new(2.3, 0.1, 2.3), CFrame.new(0, 0.05, 0), COLORS.barnRed)
	deco(m, "Diamond", Vector3.new(1.0, 0.12, 1.0), CFrame.new(0, 0.06, 0) * CFrame.Angles(0, math.rad(45), 0), COLORS.hay)
end

function builders.FruitCart(m: Model)
	solid(m, "Body", Vector3.new(5.6, 1.4, 2.6), CFrame.new(-0.4, 2.1, 0), WOOD)
	deco(m, "Rim", Vector3.new(5.8, 0.2, 2.8), CFrame.new(-0.4, 2.85, 0), DARK_WOOD)
	for _, z in { -1.45, 1.45 } do
		facing(m, "Wheel", Vector3.new(-0.4, 1.3, z), 2.5, 0.3, DARK_WOOD)
		facing(m, "Hub", Vector3.new(-0.4, 1.3, z), 0.6, 0.4, STEEL)
	end
	for _, z in { -0.8, 0.8 } do
		deco(m, "Handle", Vector3.new(1.6, 0.18, 0.18), CFrame.new(3.0, 2.3, z) * CFrame.Angles(0, 0, math.rad(-12)), DARK_WOOD)
	end
	solid(m, "Prop", Vector3.new(0.3, 1.5, 0.3), CFrame.new(2.0, 0.75, 0), DARK_WOOD)
	local colors = { Color3.fromRGB(220, 50, 50), Color3.fromRGB(245, 160, 40), Color3.fromRGB(120, 190, 60), COLORS.hay, Color3.fromRGB(140, 60, 170) }
	for i = 0, 9 do
		ball(m, "Fruit", Vector3.new(-2.6 + (i % 5) * 1.1, 3.25 + (i // 5) * 0.4, -0.5 + (i // 5) * 0.9), 0.95, colors[i % #colors + 1])
	end
	for _, x in { -3.0, 2.2 } do
		for _, z in { -1.2, 1.2 } do
			deco(m, "CanopyPost", Vector3.new(0.18, 3.2, 0.18), CFrame.new(x, 4.4, z), DARK_WOOD)
		end
	end
	for i = 0, 5 do
		deco(m, "Canopy", Vector3.new(5.6 / 6, 0.2, 3.2), CFrame.new(-3.1 + (i + 0.5) * 5.6 / 6, 6.1, 0) * CFrame.Angles(math.rad(-8), 0, 0),
			if i % 2 == 0 then COLORS.barnRed else COLORS.cream)
	end
end

function builders.Bench(m: Model)
	for _, x in { -2.9, 2.9 } do
		solid(m, "Leg", Vector3.new(0.4, 1.5, 1.4), CFrame.new(x, 0.75, 0), DARK_WOOD)
		deco(m, "Arm", Vector3.new(0.35, 0.25, 1.6), CFrame.new(x, 2.4, 0), DARK_WOOD)
		deco(m, "ArmPost", Vector3.new(0.3, 0.9, 0.3), CFrame.new(x, 1.95, -0.55), DARK_WOOD)
	end
	for i, z in { -0.45, 0.05, 0.55 } do
		solid(m, "Seat", Vector3.new(6.6, 0.22, 0.42), CFrame.new(0, 1.6, z), if i % 2 == 1 then LIGHT_WOOD else WOOD)
	end
	for i, y in { 2.3, 2.9 } do
		deco(m, "BackSlat", Vector3.new(6.6, 0.4, 0.15), CFrame.new(0, y, 0.85) * CFrame.Angles(math.rad(10), 0, 0), if i == 1 then WOOD else LIGHT_WOOD)
	end
	for _, x in { -2.6, 2.6 } do
		deco(m, "BackPost", Vector3.new(0.3, 1.8, 0.2), CFrame.new(x, 2.4, 0.8) * CFrame.Angles(math.rad(10), 0, 0), DARK_WOOD)
	end
end

function builders.Fountain(m: Model)
	upright(m, "Basin", Vector3.new(0, 0.7, 0), 7.2, 1.4, STONE, true)
	upright(m, "Water", Vector3.new(0, 1.28, 0), 6.5, 0.2, COLORS.water, false).Transparency = 0.25
	upright(m, "Lip", Vector3.new(0, 1.45, 0), 7.4, 0.12, Color3.fromRGB(226, 220, 206))
	upright(m, "Column", Vector3.new(0, 2.5, 0), 0.9, 2.6, STONE)
	upright(m, "Bowl", Vector3.new(0, 3.85, 0), 3.0, 0.5, STONE)
	upright(m, "BowlWater", Vector3.new(0, 4.11, 0), 2.6, 0.1, COLORS.water).Transparency = 0.25
	upright(m, "Jet", Vector3.new(0, 4.9, 0), 0.35, 1.6, Color3.fromRGB(200, 236, 255)).Transparency = 0.35
	ball(m, "Spray", Vector3.new(0, 5.7, 0), 0.8, Color3.fromRGB(220, 244, 255), { Transparency = 0.4 })
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(210, 240, 255))
	spray.Size = NumberSequence.new(0.25)
	spray.Lifetime = NumberRange.new(0.6, 0.9)
	spray.Rate = 14
	spray.Speed = NumberRange.new(4, 6)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Acceleration = Vector3.new(0, -18, 0)
	spray.Parent = m:FindFirstChild("Spray")
end

function builders.FlowerArch(m: Model)
	local trellis = Color3.fromRGB(250, 248, 240)
	for _, x in { -3.2, 3.2 } do
		solid(m, "Post", Vector3.new(0.5, 6.6, 0.5), CFrame.new(x, 3.3, 0), trellis)
		ball(m, "Vine", Vector3.new(x, 2.0, -0.2), 1.0, COLORS.leaf)
		ball(m, "Vine", Vector3.new(x, 4.0, 0.2), 1.0, COLORS.leafDark)
	end
	local colors = { Color3.fromRGB(240, 110, 160), WHITE, Color3.fromRGB(250, 170, 200), COLORS.hay }
	for i = 0, 10 do
		local a = math.rad(180 * i / 10)
		local at = Vector3.new(math.cos(a) * 3.2, 6.6 + math.sin(a) * 1.8, 0)
		ball(m, "Leaves", at, 1.2, if i % 2 == 0 then COLORS.leaf else COLORS.leafDark)
		ball(m, "Flower", at + Vector3.new(0, 0.3, -0.45), 0.55, colors[i % #colors + 1])
	end
	solid(m, "Base", Vector3.new(7.2, 0.2, 1.0), CFrame.new(0, 0.1, 0), STONE)
end

function builders.GoldenScarecrow(m: Model)
	local gold = { Reflectance = 0.3 }
	solid(m, "Plinth", Vector3.new(2.6, 0.7, 2.6), CFrame.new(0, 0.35, 0), Color3.fromRGB(70, 66, 62))
	solid(m, "Pole", Vector3.new(0.4, 5.6, 0.4), CFrame.new(0, 3.5, 0), GOLD, gold)
	deco(m, "Arms", Vector3.new(3.3, 0.4, 0.4), CFrame.new(0, 4.6, 0), GOLD, gold)
	deco(m, "Shirt", Vector3.new(1.8, 2.0, 0.9), CFrame.new(0, 4.0, 0), Color3.fromRGB(232, 180, 52), gold)
	ball(m, "Head", Vector3.new(0, 5.9, 0), 1.5, GOLD, gold)
	upright(m, "Brim", Vector3.new(0, 6.5, 0), 2.4, 0.15, Color3.fromRGB(226, 170, 40))
	upright(m, "Crown", Vector3.new(0, 6.95, 0), 1.2, 0.8, Color3.fromRGB(226, 170, 40))
	for _, x in { -1.7, 1.7 } do
		ball(m, "Hand", Vector3.new(x, 4.6, 0), 0.55, GOLD, gold)
	end
end

------------------------------------------------------------------------
-- On the walls (z = 0 is the wall's face; they stand out toward −Z)

function builders.PaintedSign(m: Model)
	local board = deco(m, "Board", Vector3.new(3.4, 1.7, 0.2), CFrame.new(0, 0, -0.1), COLORS.cream)
	deco(m, "Border", Vector3.new(3.6, 1.9, 0.15), CFrame.new(0, 0, -0.06), COLORS.barnRed)
	words(board, "FRESH PRODUCE", COLORS.barnRed)
end

function builders.ChalkBoard(m: Model)
	deco(m, "Frame", Vector3.new(3.0, 2.3, 0.15), CFrame.new(0, 0, -0.07), DARK_WOOD)
	local board = deco(m, "Board", Vector3.new(2.7, 2.0, 0.1), CFrame.new(0, 0, -0.15), CHALK)
	words(board, "Today's picks:\nfresh & local!", Color3.fromRGB(240, 240, 230), Enum.Font.PatrickHand)
end

function builders.Clock(m: Model)
	facing(m, "Rim", Vector3.new(0, 0, -0.12), 2.4, 0.24, DARK_WOOD)
	facing(m, "Face", Vector3.new(0, 0, -0.2), 2.1, 0.2, COLORS.cream)
	for i = 0, 11 do
		local a = math.rad(i * 30)
		deco(m, "Mark", Vector3.new(0.12, if i % 3 == 0 then 0.32 else 0.2, 0.05), CFrame.new(math.sin(a) * 0.85, math.cos(a) * 0.85, -0.32) * CFrame.Angles(0, 0, -a), COLORS.dark)
	end
	deco(m, "Hour", Vector3.new(0.14, 0.55, 0.05), CFrame.new(0.17, 0.17, -0.34) * CFrame.Angles(0, 0, math.rad(-45)), COLORS.dark)
	deco(m, "Minute", Vector3.new(0.1, 0.8, 0.05), CFrame.new(0, 0.35, -0.36), COLORS.dark)
	ball(m, "Pin", Vector3.new(0, 0, -0.36), 0.18, COLORS.barnRed)
end

function builders.FairyLights(m: Model)
	local colors = { Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 160, 170), Color3.fromRGB(170, 230, 255), Color3.fromRGB(200, 255, 170) }
	local last = nil
	for i = 0, 12 do
		local t = i / 12
		local at = Vector3.new(-1.8 + 3.6 * t, 0.6 - math.sin(math.pi * ((t * 2) % 1)) * 0.6, -0.15)
		if last then
			local mid = (last + at) / 2
			deco(m, "Wire", Vector3.new(0.05, 0.05, (at - last).Magnitude), CFrame.lookAt(mid, at), COLORS.dark)
		end
		ball(m, "Bulb", at + Vector3.new(0, -0.15, 0), 0.28, colors[i % #colors + 1], { Material = Enum.Material.Neon })
		last = at
	end
end

function builders.Mural(m: Model)
	-- a little painted farm: sky, a sun, two hills, a red barn
	deco(m, "Sky", Vector3.new(7.4, 3.6, 0.1), CFrame.new(0, 0, -0.05), Color3.fromRGB(150, 205, 240))
	facing(m, "Sun", Vector3.new(2.6, 1.0, -0.12), 1.1, 0.04, COLORS.hay)
	deco(m, "HillBack", Vector3.new(7.4, 1.4, 0.04), CFrame.new(0, -1.1, -0.13), Color3.fromRGB(120, 180, 90))
	deco(m, "Hill", Vector3.new(4.4, 1.8, 0.04), CFrame.new(-1.5, -0.9, -0.16) * CFrame.Angles(0, 0, math.rad(8)), Color3.fromRGB(100, 160, 70))
	deco(m, "Barn", Vector3.new(1.4, 1.1, 0.04), CFrame.new(0.9, -0.6, -0.19), COLORS.barnRed)
	deco(m, "Roof", Vector3.new(1.1, 1.1, 0.04), CFrame.new(0.9, -0.05, -0.2) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(150, 50, 36))
	deco(m, "Frame", Vector3.new(7.8, 4.0, 0.08), CFrame.new(0, 0, -0.02), DARK_WOOD)
end

function builders.NeonSign(m: Model)
	local board = deco(m, "Board", Vector3.new(3.2, 1.5, 0.15), CFrame.new(0, 0, -0.08), Color3.fromRGB(30, 26, 34))
	words(board, "OPEN", Color3.fromRGB(255, 90, 170), Enum.Font.FredokaOne, true)
	local pink = Color3.fromRGB(255, 110, 190)
	for _, piece in { { 0, 0.66, 3.0, 0.08 }, { 0, -0.66, 3.0, 0.08 }, { -1.46, 0, 0.08, 1.4 }, { 1.46, 0, 0.08, 1.4 } } do
		deco(m, "Tube", Vector3.new(piece[3], piece[4], 0.08), CFrame.new(piece[1], piece[2], -0.2), pink, { Material = Enum.Material.Neon })
	end
end

------------------------------------------------------------------------

-- The model for a catalog item (see the top of this file).
function StoreItems.build(itemId: string): Model
	local def = Store.ITEMS[itemId]
	local model = Instance.new("Model")
	model.Name = itemId
	builders[itemId](model)
	-- the footprint, for picking and pivoting (wall items: their width on the wall)
	local w, d = def.size[1] * Store.CELL, def.size[2] * Store.CELL
	local base = Parts.prop({
		Name = "Base",
		Size = if def.kind == "Wall" then Vector3.new(w - 0.4, 0.2, 0.2) else Vector3.new(w - 0.2, 0.2, d - 0.2),
		CFrame = CFrame.new(0, 0.1, if def.kind == "Wall" then -0.1 else 0),
		Transparency = 1,
		CanQuery = false,
		CastShadow = false,
	}, model)
	model.PrimaryPart = base
	model.WorldPivot = CFrame.new()
	return model
end

-- Builds every item once into ReplicatedStorage.StoreCatalog (for clients).
function StoreItems.buildCatalog()
	local old = ReplicatedStorage:FindFirstChild("StoreCatalog")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "StoreCatalog"
	for itemId in Store.ITEMS do
		StoreItems.build(itemId).Parent = folder
	end
	folder.Parent = ReplicatedStorage
	return folder
end

return StoreItems
