-- The town's three other buildings (docs/ArtDirection.md §6, §11 step 6),
-- in parts like the Police Station and the Auction House:
--   * Barley's Seeds: a green general store with a tall false front and a
--     painted sign, its two windows full of seed packets, a striped awning
--     over the counter where Barley (straw hat, beard, a packet held out)
--     sells seeds; sacks, barrels and seedlings round the door, a chalk
--     board saying when the stock comes in.
--   * The Hiring Hall: a yellow meeting hall, its gable to the square with
--     the name in it, a porch with the job board (the Hire tab: WorkerService
--     puts its prompt on JobBoard) and Patty beside it with her clipboard.
--   * The Cloverdale Exchange: a stone trading hall whose front is the price
--     board (MarketController draws it on PriceBoard), the desk before it,
--     and behind, rising over the town, the grain elevator: a tall slate
--     crib with CLOVERDALE across its top, a gable roof and a cupola, two
--     concrete silos with conveyor galleries to them. The tallest building.
-- SeedCounter, JobBoard and ExchangeDesk sit straight in the Town folder:
-- the services look for them there.
--
-- Each building's frame (PlotLayout.buildingFrame): origin at the middle of
-- its front wall on the ground, +Z out toward the square, +X to the right
-- as you face it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
local Crops = require(ReplicatedStorage.Shared.Config.Crops)
local Parts = require(script.Parent.Parts)
local Meshes = require(script.Parent.Meshes)

local TownArt = {}

local COLORS = Parts.COLORS
local CREAM = COLORS.cream
local WHITE = Color3.fromRGB(246, 240, 226)
local GLASS = Color3.fromRGB(150, 196, 220)
local SLATE = Color3.fromRGB(98, 104, 116)
local INK = Color3.fromRGB(74, 50, 32)
local GOLD = Color3.fromRGB(240, 186, 64)
local SKIN = Color3.fromRGB(240, 196, 150)
local WINDOW_NIGHT = Color3.fromRGB(255, 206, 130)
local WALK = Color3.fromRGB(216, 200, 166)
local WALK_TOP = 0.3

TownArt.ELEVATOR_TOP = 75.5 -- the cupola's ridge: the tallest thing in town

------------------------------------------------------------------------
-- Helpers (in a building's frame)

local function box(name: string, frame: CFrame, x0, y0, z0, x1, y1, z1, color: Color3, parent: Instance, extra: { [string]: any }?)
	local props: { [string]: any } = { Color = color }
	for k, v in extra or {} do
		props[k] = v
	end
	return Parts.plotBox(name, frame, Vector3.new(math.min(x0, x1), y0, math.min(z0, z1)), Vector3.new(math.max(x0, x1), y1, math.max(z0, z1)), props, parent)
end
local function deco(name, frame, x0, y0, z0, x1, y1, z1, color, parent, extra)
	local p = box(name, frame, x0, y0, z0, x1, y1, z1, color, parent, extra)
	p.CanCollide = false
	p.CanTouch = false
	return p
end

-- A slab between two points in the frame's X-Y plane (a gable's edge, a
-- roof), `width` thick, between z0 and z1.
local function slab(name, frame: CFrame, xa, ya, xb, yb, z0, z1, width, color, parent, solid: boolean?)
	local dx, dy = xb - xa, yb - ya
	local length = math.sqrt(dx * dx + dy * dy)
	local cf = frame * CFrame.new((xa + xb) / 2, (ya + yb) / 2, (z0 + z1) / 2) * CFrame.Angles(0, 0, math.atan2(dy, dx))
	local props = { Name = name, Size = Vector3.new(length, width, math.abs(z1 - z0)), CFrame = cf, Color = color }
	return if solid then Parts.part(props, parent) else Parts.prop(props, parent)
end

-- A gable end: two wedges meeting at the middle (x = 0), from the wall top
-- y0 to the ridge y1, in the wall's plane z0..z1.
local function gable(frame: CFrame, z0: number, z1: number, halfWidth: number, y0: number, y1: number, color: Color3, parent: Instance)
	for _, side in { -1, 1 } do
		local inward = Vector3.new(-side, 0, 0)
		local across = Vector3.yAxis:Cross(inward)
		local centre = Vector3.new(side * halfWidth / 2, (y0 + y1) / 2, (z0 + z1) / 2)
		Parts.part({
			Name = "Gable", Shape = Enum.PartType.Wedge, Size = Vector3.new(math.abs(z1 - z0), y1 - y0, halfWidth),
			CFrame = frame * CFrame.fromMatrix(centre, across, Vector3.yAxis, inward), Color = color,
		}, parent)
	end
end

-- A gable roof over x -halfWidth..halfWidth from the eaves at `wall` to the
-- ridge at `ridge`, front z1 back z0, overhanging by `over`: two slopes and
-- a ridge cap.
local function roof(frame: CFrame, halfWidth: number, wall: number, ridge: number, z0: number, z1: number, over: number, color: Color3, parent: Instance)
	local eave = halfWidth + over
	local drop = (ridge - wall) * over / halfWidth
	for _, side in { -1, 1 } do
		slab("Roof", frame, side * eave, wall - drop + 0.45, 0, ridge + 0.45, z0 - over, z1 + over, 0.9, color, parent, true)
	end
	deco("RidgeCap", frame, -0.6, ridge + 0.3, z0 - over - 0.1, 0.6, ridge + 0.95, z1 + over + 0.1, color:Lerp(COLORS.dark, 0.3), parent)
end

-- Words on the face toward +Z (the square).
local function words(p: BasePart, text: string, color: Color3, font: Enum.Font?, pixels: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixels or 24
	gui.LightInfluence = 0.5
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color
	label.Text = text
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = label
	label.Parent = gui
	gui.Parent = p
	return label
end

-- A window on the front wall (z = 0): glass (warm at night), a frame and
-- sill in `trim`, a mullion and a transom bar.
local function window(frame: CFrame, x0, x1, y0, y1, trim: Color3, parent: Instance)
	local glass = deco("Glass", frame, x0, y0, -0.05, x1, y1, 0.12, GLASS, parent, { Reflectance = 0.1 })
	glass:SetAttribute("NightColor", WINDOW_NIGHT)
	glass:AddTag("NightGlow")
	deco("Frame", frame, x0 - 0.4, y1, 0, x1 + 0.4, y1 + 0.45, 0.3, trim, parent)
	deco("Frame", frame, x0 - 0.4, y0 - 0.1, 0, x0, y1, 0.3, trim, parent)
	deco("Frame", frame, x1, y0 - 0.1, 0, x1 + 0.4, y1, 0.3, trim, parent)
	deco("Sill", frame, x0 - 0.6, y0 - 0.5, 0, x1 + 0.6, y0, 0.55, trim, parent)
	deco("Mullion", frame, (x0 + x1) / 2 - 0.12, y0, 0.05, (x0 + x1) / 2 + 0.12, y1, 0.22, trim, parent)
	return glass
end

-- A floating name over a townsperson, like Sheriff Clucks'.
local function nameTag(text: string, adornee: BasePart, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(10, 1.3)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 90
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	gui.Parent = adornee
end

-- A townsperson, as blocky as the workers on the farms (WorkerController):
-- standing on `feet`, looking along its look vector. `look`: shirt, legs,
-- and arm angles forward (degrees) for the left and right arm.
local function person(name: string, feet: CFrame, look, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	local function piece(partName, size, cf, color, shape)
		return Parts.prop({ Name = partName, Size = size, CFrame = feet * cf, Color = color, Shape = shape or Enum.PartType.Block }, model)
	end
	for _, x in { -0.5, 0.5 } do
		piece("Leg", Vector3.new(0.9, 2.0, 0.9), CFrame.new(x, 1.2, 0), look.legs) -- (its foot inside the shoe)
		piece("Shoe", Vector3.new(1.05, 0.4, 1.15), CFrame.new(x, 0.2, -0.2), look.shoes or COLORS.dark)
	end
	piece("Body", Vector3.new(2.1, 2.3, 1.1), CFrame.new(0, 3.35, 0), look.shirt)
	for i, x in { -1.45, 1.45 } do
		local raise = math.rad(look.arms[i])
		local arm = CFrame.new(x, 4.45, 0) * CFrame.Angles(raise, 0, 0)
		piece("Arm", Vector3.new(0.7, 2.1, 0.7), arm * CFrame.new(0, -1.05, 0), look.sleeves or look.shirt)
		piece("Hand", Vector3.new(0.6, 0.5, 0.6), arm * CFrame.new(0, -2.3, 0), SKIN)
	end
	piece("Head", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 5.3, 0), SKIN, Enum.PartType.Ball)
	for _, x in { -0.32, 0.32 } do
		piece("Eye", Vector3.new(0.22, 0.22, 0.22), CFrame.new(x, 5.42, -0.72), COLORS.dark, Enum.PartType.Ball)
	end
	model.Parent = parent
	return model
end

------------------------------------------------------------------------
-- Barley's Seeds

local GREEN = Color3.fromRGB(84, 150, 76)
local GREEN_DARK = Color3.fromRGB(56, 108, 56)
local STRAW = Color3.fromRGB(240, 204, 116)
local BURLAP = Color3.fromRGB(196, 164, 112)
local BARREL = Color3.fromRGB(150, 104, 62)
local TERRACOTTA = Color3.fromRGB(196, 110, 70)

-- A window full of seed packets on shelves (each packet a colour with its
-- crop's picture): the "wall of seed packets" seen from the square.
local function packets(glass: BasePart, seed: number)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0.6
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(150, 110, 70)
	back.BorderSizePixel = 0
	back.Parent = gui
	local colors = { Color3.fromRGB(232, 83, 63), Color3.fromRGB(245, 200, 66), Color3.fromRGB(92, 191, 74), Color3.fromRGB(76, 155, 232),
		Color3.fromRGB(242, 145, 61), Color3.fromRGB(139, 108, 217), Color3.fromRGB(232, 106, 168), Color3.fromRGB(47, 181, 168) }
	local rows, cols = 3, 4
	for r = 0, rows - 1 do
		local shelf = Instance.new("Frame")
		shelf.Position = UDim2.fromScale(0, (r + 1) / rows - 0.04)
		shelf.Size = UDim2.fromScale(1, 0.04)
		shelf.BackgroundColor3 = Color3.fromRGB(110, 76, 46)
		shelf.BorderSizePixel = 0
		shelf.ZIndex = 2
		shelf.Parent = back
		for c = 0, cols - 1 do
			local n = seed + r * cols + c
			local crop = Crops.List[n % #Crops.List + 1]
			local packet = Instance.new("Frame")
			packet.AnchorPoint = Vector2.new(0.5, 1)
			packet.Position = UDim2.fromScale((c + 0.5) / cols, (r + 1) / rows - 0.045)
			packet.Size = UDim2.fromScale(0.78 / cols, 0.78 / rows)
			packet.Rotation = (n * 37) % 9 - 4
			packet.BackgroundColor3 = colors[n % #colors + 1]
			packet.BorderSizePixel = 0
			packet.Parent = back
			local label = Instance.new("Frame")
			label.Position = UDim2.fromScale(0.1, 0.12)
			label.Size = UDim2.fromScale(0.8, 0.62)
			label.BackgroundColor3 = Color3.fromRGB(255, 248, 230)
			label.BorderSizePixel = 0
			label.Parent = packet
			local icon = Instance.new("TextLabel")
			icon.Size = UDim2.fromScale(1, 1)
			icon.BackgroundTransparency = 1
			icon.TextScaled = true
			icon.Text = crop.icon or "🌱"
			icon.Parent = label
		end
	end
	gui.Parent = glass
end

local function barley(feet: CFrame, parent: Instance)
	local model = person("Barley", feet, {
		shirt = Color3.fromRGB(196, 72, 52), legs = Color3.fromRGB(70, 102, 156), shoes = Color3.fromRGB(96, 66, 42),
		arms = { 0, 75 }, -- (his right hand holds a packet out over the counter)
	}, parent)
	local function piece(partName, size, cf, color, shape)
		return Parts.prop({ Name = partName, Size = size, CFrame = feet * cf, Color = color, Shape = shape or Enum.PartType.Block }, model)
	end
	-- denim overalls: the bib and straps over his red shirt
	piece("Bib", Vector3.new(1.5, 1.3, 0.14), CFrame.new(0, 3.55, -0.6), Color3.fromRGB(70, 102, 156))
	for _, x in { -0.62, 0.62 } do
		piece("Strap", Vector3.new(0.3, 0.9, 1.22), CFrame.new(x, 4.2, 0), Color3.fromRGB(70, 102, 156))
	end
	-- a white beard and moustache, a straw hat with a green band
	-- (under his nose and chin, clear of his eyes: higher, it read as a mask)
	piece("Beard", Vector3.new(1.2, 0.9, 0.45), CFrame.new(0, 4.3, -0.7), Color3.fromRGB(244, 240, 232))
	piece("BeardTip", Vector3.new(0.7, 0.45, 0.4), CFrame.new(0, 3.75, -0.72), Color3.fromRGB(244, 240, 232))
	piece("Moustache", Vector3.new(0.9, 0.22, 0.25), CFrame.new(0, 4.92, -0.82), Color3.fromRGB(244, 240, 232))
	Parts.cylinder("HatBrim", feet * CFrame.new(0, 6.0, 0), 3.4, 0.22, { Color = STRAW }, model)
	Parts.cylinder("HatCrown", feet * CFrame.new(0, 6.5, 0), 1.75, 1.0, { Color = STRAW }, model)
	Parts.cylinder("HatBand", feet * CFrame.new(0, 6.2, 0), 1.8, 0.28, { Color = GREEN_DARK }, model)
	-- the packet standing in his right hand
	piece("SeedPacket", Vector3.new(0.9, 1.2, 0.08), CFrame.new(1.45, 4.55, -2.42), Color3.fromRGB(242, 145, 61))
	piece("PacketLabel", Vector3.new(0.6, 0.5, 0.04), CFrame.new(1.45, 4.65, -2.5), Color3.fromRGB(255, 248, 230))
	model.Parent = parent
	nameTag("Barley", model.Head, 3.2)
	return model
end

local function seedShop(town: Instance)
	local building = PlotLayout.building("Seeds")
	local W, D = building.size.X, building.size.Z
	local f = PlotLayout.buildingFrame("Seeds")
	local model = Instance.new("Model")
	model.Name = "SeedShop"
	local WALL, RIDGE = 14, 20

	-- the shop: green clapboard on a darker base, cream corner boards
	box("SeedShop", f, -W / 2, 0, -D, W / 2, WALL, 0, GREEN, model)
	deco("BaseBand", f, -W / 2 - 0.1, 0, -D - 0.1, W / 2 + 0.1, 1.2, 0.12, GREEN_DARK, model)
	for _, side in { -1, 1 } do
		for _, z in { 0, -D } do
			deco("Corner", f, side * W / 2 - 0.5, 1.2, z - 0.5, side * W / 2 + 0.5, WALL, z + 0.5, CREAM, model)
		end
		for y = 2.7, WALL - 1, 1.5 do -- (clapboard lines down the side)
			deco("Board", f, side * (W / 2 + 0.06), y - 0.07, -D + 0.6, side * W / 2, y + 0.07, -0.6, GREEN_DARK, model)
		end
	end
	-- the roof behind the false front, gable to the back
	gable(f, -D, -D + 1, W / 2, WALL, RIDGE, GREEN, model)
	roof(f, W / 2, WALL, RIDGE, -D, -2, 1.2, Color3.fromRGB(78, 92, 74), model) -- (its front end inside the false front)

	-- the false front: a tall flat face with a stepped top and cream caps
	box("FalseFront", f, -W / 2, WALL, -1, W / 2, WALL + 7, 0, GREEN, model)
	box("FalseFront", f, -10, WALL + 7, -1, 10, WALL + 10, 0, GREEN, model)
	deco("Cap", f, -W / 2 - 0.4, WALL + 7, -1.2, -10, WALL + 7.6, 0.3, CREAM, model)
	deco("Cap", f, 10, WALL + 7, -1.2, W / 2 + 0.4, WALL + 7.6, 0.3, CREAM, model)
	deco("Cap", f, -10.4, WALL + 10, -1.2, 10.4, WALL + 10.6, 0.3, CREAM, model)
	for _, side in { -1, 1 } do
		deco("Cap", f, side * 10 - 0.4, WALL + 7.6, -1.2, side * 10 + 0.4, WALL + 10, 0.3, CREAM, model)
		deco("Corner", f, side * W / 2 - 0.5, WALL, -1.1, side * W / 2 + 0.5, WALL + 7, 0.5, CREAM, model)
	end
	-- the painted sign, and a line about what's sold over it
	deco("SignFrame", f, -13.4, WALL + 0.6, 0, 13.4, WALL + 6.6, 0.25, GREEN_DARK, model)
	local sign = deco("Sign", f, -13, WALL + 1, 0.25, 13, WALL + 6.2, 0.45, CREAM, model)
	words(sign, "BARLEY'S SEEDS", GREEN_DARK)
	local motto = deco("Motto", f, -8, WALL + 7.7, 0, 8, WALL + 9.7, 0.1, GREEN, model, { Transparency = 1 })
	words(motto, "seeds · saplings · since 1887", CREAM, Enum.Font.FredokaOne)

	-- the counter's hatch in the middle (Barley stands in front of it), a
	-- window full of seed packets either side
	local H0, H1 = 3.2, 10.2
	deco("Hatch", f, -6, H0, -0.05, 6, H1, 0.1, Color3.fromRGB(120, 86, 56), model)
	packets(deco("HatchShelves", f, -5.6, H0 + 0.4, 0.1, 5.6, H1 - 0.4, 0.18, Color3.fromRGB(150, 110, 70), model), 3)
	deco("HatchFrame", f, -6.5, H1, 0, 6.5, H1 + 0.5, 0.35, CREAM, model)
	deco("HatchFrame", f, -6.5, H0 - 0.4, 0, -6, H1, 0.35, CREAM, model)
	deco("HatchFrame", f, 6, H0 - 0.4, 0, 6.5, H1, 0.35, CREAM, model)
	for i, x in { -12, 12 } do
		local glass = window(f, x - 3.2, x + 3.2, 3.6, 10, CREAM, model)
		packets(glass, i * 7)
		-- a window box of flowers under it
		deco("WindowBox", f, x - 3.4, 2.1, 0.2, x + 3.4, 3.0, 1.4, GREEN_DARK, model)
		for j = 0, 5 do
			Parts.ball("Flower", f * CFrame.new(x - 2.7 + j * 1.08, 3.25, 0.8), 0.75, { Color = if j % 2 == 0 then Color3.fromRGB(222, 52, 52) else STRAW }, model)
		end
	end

	-- the awning over the counter: green and cream stripes, sloping out
	-- over Barley, a striped flap hanging from its front edge
	local strips = 10
	local width = 32 / strips
	local slope = CFrame.new(0, WALL - 2.4, 3) * CFrame.Angles(math.rad(14), 0, 0)
	for i = 0, strips - 1 do
		local x = -16 + width * (i + 0.5)
		local color = if i % 2 == 0 then GREEN else CREAM
		Parts.prop({ Name = "Awning", Size = Vector3.new(width, 0.3, 6.4), CFrame = f * slope * CFrame.new(x, 0, 0), Color = color }, model)
		Parts.prop({ Name = "Valance", Size = Vector3.new(width, 1.2, 0.2), CFrame = f * CFrame.new(x, WALL - 3.75, 6.2), Color = color }, model)
	end
	Parts.prop({ Name = "ValanceTrim", Size = Vector3.new(32.4, 0.3, 0.3), CFrame = f * CFrame.new(0, WALL - 3.05, 6.2), Color = GREEN_DARK }, model)

	-- the paved front, the counter and Barley behind it
	box("Forecourt", f, -W / 2, 0, -0.2, W / 2, WALK_TOP, 9, WALK, model)
	local counterAt = PlotLayout.frontOf("Seeds", 4) + Vector3.new(0, 1.75, 0)
	local facing = CFrame.lookAt(counterAt, Vector3.new(0, counterAt.Y, 0))
	Parts.part({ Name = "SeedCounter", Size = Vector3.new(12, 3.5, 3), CFrame = facing, Color = COLORS.kraft }, town)
	Parts.prop({ Name = "CounterTop", Size = Vector3.new(12.6, 0.4, 3.6), CFrame = facing * CFrame.new(0, 1.95, 0), Color = COLORS.post }, model)
	Parts.prop({ Name = "CounterFront", Size = Vector3.new(11, 2.2, 0.1), CFrame = facing * CFrame.new(0, 0, -1.55), Color = GREEN }, model)
	local front = Parts.prop({ Name = "CounterSign", Size = Vector3.new(7, 1.4, 0.05), CFrame = facing * CFrame.new(0, 0.1, -1.62) * CFrame.Angles(0, math.rad(180), 0),
		Color = GREEN, Transparency = 1 }, model)
	words(front, "SEED RACK", CREAM)
	barley(f * CFrame.new(0, WALK_TOP, 1.3) * CFrame.Angles(0, math.rad(180), 0), model)

	-- sacks, barrels and seedlings by the counter, the barrow, the chalk board
	for i, x in { -9.2, -10.8, 9.6 } do
		local sack = f * CFrame.new(x, WALK_TOP, 3 + (i % 2) * 1.3) * CFrame.Angles(0, math.rad(i * 23), 0)
		Parts.prop({ Name = "Sack", Size = Vector3.new(1.6, 2.2, 1.2), CFrame = sack * CFrame.new(0, 1.1, 0), Color = BURLAP }, model)
		Parts.prop({ Name = "SackTop", Size = Vector3.new(1.1, 0.4, 0.8), CFrame = sack * CFrame.new(0, 2.4, 0), Color = BURLAP:Lerp(COLORS.dark, 0.15) }, model)
		Parts.prop({ Name = "SackTie", Size = Vector3.new(0.9, 0.18, 0.7), CFrame = sack * CFrame.new(0, 2.18, 0), Color = Color3.fromRGB(118, 78, 40) }, model)
	end
	for i, x in { 12.5, 14.6 } do
		local barrel = f * CFrame.new(x, WALK_TOP, 2.6 + i * 0.4)
		Parts.cylinder("Barrel", barrel * CFrame.new(0, 1.3, 0), 2.1, 2.6, { Color = BARREL }, model)
		Parts.cylinder("Hoop", barrel * CFrame.new(0, 0.55, 0), 2.18, 0.2, { Color = COLORS.dark }, model)
		Parts.cylinder("Hoop", barrel * CFrame.new(0, 2.05, 0), 2.18, 0.2, { Color = COLORS.dark }, model)
		Parts.cylinder("Seeds", barrel * CFrame.new(0, 2.62, 0), 1.85, 0.1, { Color = if i == 1 then COLORS.hay else Color3.fromRGB(150, 104, 60) }, model)
	end
	for i = 0, 3 do -- seedlings in pots on a low plank
		local pot = f * CFrame.new(-15.6 + i * 0.05, WALK_TOP + 0.9, 1.4 + i * 1.5)
		Parts.cylinder("Pot", pot * CFrame.new(0, 0.45, 0), 0.9, 0.9, { Color = TERRACOTTA }, model)
		Parts.ball("Seedling", pot * CFrame.new(0, 1.15, 0), 0.8, { Color = COLORS.leaf }, model)
	end
	deco("PotShelf", f, -16.4, WALK_TOP + 0.75, 0.7, -14.8, WALK_TOP + 0.9, 7.2, COLORS.post, model)
	for _, z in { 1.0, 6.9 } do
		deco("PotShelfLeg", f, -15.8, WALK_TOP, z - 0.2, -15.4, WALK_TOP + 0.75, z + 0.2, COLORS.post, model)
	end
	local barrow = f * CFrame.new(-12, WALK_TOP, 6.6) * CFrame.Angles(0, math.rad(200), 0)
	if not Meshes.make("Wheelbarrow", barrow, 1.2, model) then
		Parts.prop({ Name = "Barrow", Size = Vector3.new(2.2, 1.2, 3.4), CFrame = barrow * CFrame.new(0, 1.2, 0), Color = COLORS.barnRed }, model)
	end
	-- the chalk board on its easel: when new stock comes (SeedShop: every 5 minutes)
	local easel = f * CFrame.new(9.4, WALK_TOP, 7.4) * CFrame.Angles(0, math.rad(-15), 0)
	for _, x in { -1.2, 1.2 } do
		Parts.prop({ Name = "EaselLeg", Size = Vector3.new(0.2, 4.4, 0.2), CFrame = easel * CFrame.new(x, 2.1, 0) * CFrame.Angles(math.rad(-10), 0, 0), Color = COLORS.post }, model)
	end
	local board = Parts.prop({ Name = "ChalkBoard", Size = Vector3.new(2.6, 2.4, 0.15), CFrame = easel * CFrame.new(0, 2.8, 0.15) * CFrame.Angles(math.rad(-10), 0, 0),
		Color = Color3.fromRGB(46, 62, 52) }, model)
	words(board, "FRESH SEEDS\nnew stock every 5 min", CREAM, Enum.Font.PatrickHand)

	model.Parent = town
	return model
end

------------------------------------------------------------------------
-- The Hiring Hall

local YELLOW = Color3.fromRGB(244, 204, 96)
local YELLOW_DARK = Color3.fromRGB(214, 166, 62)
local TEAL = Color3.fromRGB(52, 112, 124)
local DECK = Color3.fromRGB(176, 128, 82)
local DECK_DARK = Color3.fromRGB(140, 98, 60)

local function patty(feet: CFrame, parent: Instance)
	local model = person("Patty", feet, {
		shirt = TEAL, sleeves = TEAL, legs = Color3.fromRGB(58, 72, 110), shoes = Color3.fromRGB(120, 52, 44),
		arms = { 50, 50 }, -- (her clipboard held up in both hands)
	}, parent)
	local function piece(partName, size, cf, color, shape)
		return Parts.prop({ Name = partName, Size = size, CFrame = feet * cf, Color = color, Shape = shape or Enum.PartType.Block }, model)
	end
	-- a white blouse's collar at the cardigan's neck, buttons down it
	piece("Collar", Vector3.new(1.0, 0.45, 0.2), CFrame.new(0, 4.35, -0.55), WHITE)
	for i = 0, 2 do
		piece("Button", Vector3.new(0.18, 0.18, 0.1), CFrame.new(0, 3.85 - i * 0.55, -0.6), GOLD)
	end
	-- auburn hair: a cap of it, a fringe and a bun at the back
	local hair = Color3.fromRGB(150, 70, 40)
	piece("Hair", Vector3.new(1.72, 1.0, 1.72), CFrame.new(0, 5.75, 0.05), hair, Enum.PartType.Ball)
	piece("Fringe", Vector3.new(1.4, 0.35, 0.3), CFrame.new(0, 5.95, -0.68), hair)
	piece("Bun", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 6.2, 0.75), hair, Enum.PartType.Ball)
	-- the clipboard, the list of jobs clipped to it
	local held = CFrame.new(0, 3.6, -1.55) * CFrame.Angles(math.rad(-25), 0, 0)
	piece("Clipboard", Vector3.new(1.5, 1.9, 0.12), held, Color3.fromRGB(150, 104, 62))
	piece("Paper", Vector3.new(1.3, 1.6, 0.06), held * CFrame.new(0, -0.08, -0.08), WHITE)
	piece("Clip", Vector3.new(0.7, 0.25, 0.14), held * CFrame.new(0, 0.85, -0.1), Color3.fromRGB(180, 186, 192))
	for i = 0, 2 do
		piece("Line", Vector3.new(1.0, 0.07, 0.04), held * CFrame.new(-0.05, 0.35 - i * 0.4, -0.15), Color3.fromRGB(90, 96, 110))
	end
	model.Parent = parent
	nameTag("Patty", model.Head, 3.4)
	return model
end

local function hiringHall(town: Instance)
	local building = PlotLayout.building("HiringHall")
	local W, D = building.size.X, building.size.Z
	local f = PlotLayout.buildingFrame("HiringHall")
	local model = Instance.new("Model")
	model.Name = "HiringHall"
	local WALL, RIDGE, F = 12, 20, 0.8

	-- the hall: yellow boards, white trim, a slate roof with its gable to
	-- the square
	box("Hall", f, -W / 2, 0, -D, W / 2, WALL, 0, YELLOW, model)
	deco("BaseBand", f, -W / 2 - 0.1, 0, -D - 0.1, W / 2 + 0.1, 1.0, 0.12, YELLOW_DARK, model)
	for _, side in { -1, 1 } do
		for _, z in { 0, -D } do
			deco("Corner", f, side * W / 2 - 0.5, 1.0, z - 0.5, side * W / 2 + 0.5, WALL, z + 0.5, WHITE, model)
		end
		for y = 2.5, WALL - 1, 1.5 do
			deco("Board", f, side * (W / 2 + 0.06), y - 0.07, -D + 0.6, side * W / 2, y + 0.07, -0.6, YELLOW_DARK, model)
		end
		-- side windows
		for _, z in { -8, -19 } do
			local glass = deco("Glass", f, side * W / 2 - 0.12 * side, 4, z - 2.5, side * (W / 2 + 0.05), 9, z + 2.5, GLASS, model)
			glass:SetAttribute("NightColor", WINDOW_NIGHT)
			glass:AddTag("NightGlow")
			deco("Shutter", f, side * (W / 2 + 0.1), 4, z - 4.1, side * (W / 2 + 0.3), 9, z - 2.6, TEAL, model)
			deco("Shutter", f, side * (W / 2 + 0.1), 4, z + 2.6, side * (W / 2 + 0.3), 9, z + 4.1, TEAL, model)
		end
	end
	gable(f, -1, 0, W / 2, WALL, RIDGE, YELLOW, model)
	gable(f, -D, -D + 1, W / 2, WALL, RIDGE, YELLOW, model)
	roof(f, W / 2, WALL, RIDGE, -D, 0, 1.2, SLATE, model)
	for _, z in { 0.05, -D - 0.35 } do
		for _, side in { -1, 1 } do
			slab("GableTrim", f, side * (W / 2 + 0.6), WALL - 0.4, 0, RIDGE - 0.05, z, z + 0.3, 0.7, WHITE, model)
		end
	end
	-- the name in the gable on a white board, a round vent over it
	deco("GableSignFrame", f, -8, WALL + 0.5, 0, 8, WALL + 3.6, 0.2, TEAL, model)
	local sign = deco("GableSign", f, -7.6, WALL + 0.9, 0.2, 7.6, WALL + 3.2, 0.4, WHITE, model)
	words(sign, "HIRING HALL", TEAL)
	Parts.prop({ Name = "Vent", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.2, 2.2), CFrame = f * CFrame.new(0, WALL + 5.9, 0.15) * CFrame.Angles(0, math.rad(90), 0),
		Color = WHITE }, model)
	Parts.prop({ Name = "VentSlats", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.6, 1.6), CFrame = f * CFrame.new(0, WALL + 5.9, 0.25) * CFrame.Angles(0, math.rad(90), 0),
		Color = TEAL }, model)

	-- the porch: a deck along the front, steps, white posts and a roof (the
	-- middle posts frame the door, clear of the job board and the window)
	box("HallPorch", f, -W / 2, 0, 0, W / 2, F, 8, DECK, model)
	box("PorchStep", f, -3.6, 0, 8, 3.6, F - 0.35, 9.4, DECK_DARK, model)
	for x = -W / 2 + 1.5, W / 2 - 1.5, 3 do
		deco("PorchBoard", f, x - 0.04, F, 0.2, x + 0.04, F + 0.04, 8, DECK_DARK, model)
	end
	for _, x in { -W / 2 + 0.6, -3.5, 3.5, W / 2 - 0.6 } do
		box("PorchPost", f, x - 0.4, F, 7, x + 0.4, 10, 7.8, WHITE, model)
	end
	deco("PorchBeam", f, -W / 2, 9.6, 6.9, W / 2, 10.3, 7.9, WHITE, model)
	local porchRoof = f * CFrame.new(0, 10.9, 4.2) * CFrame.Angles(math.rad(8), 0, 0)
	Parts.part({ Name = "PorchRoof", Size = Vector3.new(W + 1.4, 0.5, 9.2), CFrame = porchRoof, Color = SLATE }, model)
	deco("PorchFascia", f, -W / 2 - 0.5, 9.75, 8.75, W / 2 + 0.5, 10.6, 8.95, WHITE, model)
	-- a rail along the porch's ends
	for _, side in { -1, 1 } do
		deco("PorchRail", f, side * (W / 2 - 0.3) - 0.15, F + 2.6, 0.5, side * (W / 2 - 0.3) + 0.15, F + 2.9, 7, WHITE, model)
		deco("PorchRail", f, side * 3.9, F + 2.6, 7.2, side * (W / 2 - 0.6), F + 2.9, 7.5, WHITE, model)
		for x = 5, W / 2 - 2, 2 do
			deco("Baluster", f, side * x - 0.1, F, 7.25, side * x + 0.1, F + 2.6, 7.45, WHITE, model)
		end
	end

	-- the front: the door in the middle, the job board on the wall left of it
	-- (Patty beside it), a window right of it, the waiting bench
	deco("Door", f, -2.4, F, -0.05, 2.4, F + 7.6, 0.2, TEAL, model)
	deco("DoorSplit", f, -0.08, F, 0.2, 0.08, F + 7.6, 0.3, Color3.fromRGB(36, 84, 94), model)
	for _, x in { -1.2, 1.2 } do
		local pane = deco("DoorWindow", f, x - 0.75, F + 4.4, 0.2, x + 0.75, F + 6.8, 0.3, GLASS, model)
		pane:SetAttribute("NightColor", WINDOW_NIGHT)
		pane:AddTag("NightGlow")
	end
	deco("DoorFrame", f, -2.9, F + 7.6, 0, 2.9, F + 8.2, 0.35, WHITE, model)
	deco("DoorFrame", f, -2.9, F, 0, -2.4, F + 7.6, 0.35, WHITE, model)
	deco("DoorFrame", f, 2.4, F, 0, 2.9, F + 7.6, 0.35, WHITE, model)
	local open = deco("OpenSign", f, -1.3, F + 2.6, 0.3, 1.3, F + 3.6, 0.36, WHITE, model)
	words(open, "OPEN", TEAL)
	window(f, 6.5, 13.5, F + 3, F + 8, WHITE, model)
	for _, x in { 5.4, 14.6 } do
		deco("Shutter", f, x - 0.75, F + 3, 0.2, x + 0.75, F + 8, 0.4, TEAL, model)
	end

	-- the job board: today's candidates pinned up (WorkerService opens the
	-- Hire tab from it), HELP WANTED painted over it
	local board = box("JobBoard", f, -15, F + 1.8, 0, -4.4, F + 7.4, 0.5, COLORS.kraft, town)
	deco("BoardFrame", f, -15.4, F + 7.4, 0, -4, F + 7.9, 0.7, DECK_DARK, model)
	deco("BoardFrame", f, -15.4, F + 1.4, 0, -4, F + 1.8, 0.7, DECK_DARK, model)
	deco("BoardFrame", f, -15.4, F + 1.8, 0, -15, F + 7.4, 0.7, DECK_DARK, model)
	deco("BoardFrame", f, -4.4, F + 1.8, 0, -4, F + 7.4, 0.7, DECK_DARK, model)
	for i, color in { CREAM, COLORS.hay, CREAM, COLORS.water, CREAM, COLORS.leaf, COLORS.hay, CREAM } do
		local x = -13.6 + ((i - 1) % 4) * 2.75
		local y = if i <= 4 then F + 5.9 else F + 3.4
		Parts.prop({ Name = "Notice", Size = Vector3.new(2.2, 1.9, 0.1), CFrame = f * CFrame.new(x, y, 0.56) * CFrame.Angles(0, 0, math.rad((i * 37) % 9 - 4)),
			Color = color }, model)
		Parts.ball("Pin", f * CFrame.new(x, y + 0.7, 0.66), 0.25, { Color = COLORS.barnRed }, model)
	end
	local header = deco("BoardHeader", f, -15, F + 8.1, 0, -4.4, F + 9.5, 0.3, WHITE, model)
	words(header, "HELP WANTED · first hire free!", TEAL)
	patty(f * CFrame.new(-16.2, F, 3.2) * CFrame.Angles(0, math.rad(200), 0), model)

	-- the waiting bench for candidates, a crate, a potted plant
	deco("BenchSeat", f, 7.5, F + 1.7, 1.0, 13.5, F + 2.0, 2.6, DECK_DARK, model)
	deco("BenchBack", f, 7.5, F + 2.0, 0.4, 13.5, F + 3.1, 0.7, DECK_DARK, model)
	for _, x in { 7.9, 13.1 } do
		deco("BenchLeg", f, x - 0.2, F, 1.2, x + 0.2, F + 1.7, 2.4, DECK_DARK, model)
	end
	box("Crate", f, 15, F, 1.2, 17, F + 1.8, 3.2, COLORS.kraft, model)
	Parts.cylinder("Pot", f * CFrame.new(-17, F + 0.6, 6), 1.4, 1.2, { Color = TERRACOTTA }, model)
	Parts.ball("Plant", f * CFrame.new(-17, F + 1.9, 6), 1.8, { Color = COLORS.leaf }, model)

	model.Parent = town
	return model
end

------------------------------------------------------------------------
-- The Cloverdale Exchange and its grain elevator

local HALL = Color3.fromRGB(232, 222, 198)
local HALL_DARK = Color3.fromRGB(198, 184, 156)
local CRIB = Color3.fromRGB(112, 128, 150)
local CRIB_DARK = Color3.fromRGB(88, 102, 124)
local CONCRETE = Color3.fromRGB(206, 200, 188)
local CONCRETE_DARK = Color3.fromRGB(170, 164, 152)

TownArt.BOARD = Vector3.new(34, 24, 0.3) -- the price board on the hall's front (MarketController fits its grid to it)

local function exchange(town: Instance)
	local building = PlotLayout.building("Exchange")
	local W, D = building.size.X, building.size.Z
	local f = PlotLayout.buildingFrame("Exchange")
	local model = Instance.new("Model")
	model.Name = "Exchange"
	local HALL_H, HALL_D = 30, 12

	-- the trading hall: stone, a darker base, pilasters, a gold cornice
	box("ExchangeHall", f, -W / 2, 0, -HALL_D, W / 2, HALL_H, 0, HALL, model)
	deco("BaseBand", f, -W / 2 - 0.12, 0, -HALL_D - 0.12, W / 2 + 0.12, 1.6, 0.12, HALL_DARK, model)
	for _, x in { -W / 2, W / 2 } do
		deco("Pilaster", f, x - 0.6, 1.6, -0.6, x + 0.6, HALL_H, 0.6, HALL_DARK, model)
	end
	deco("Cornice", f, -W / 2 - 0.6, HALL_H, -HALL_D - 0.6, W / 2 + 0.6, HALL_H + 1, 0.6, HALL_DARK, model)
	deco("CorniceGold", f, -W / 2 - 0.7, HALL_H - 0.35, -HALL_D - 0.7, W / 2 + 0.7, HALL_H, 0.7, GOLD, model)
	box("Parapet", f, -12, HALL_H + 1, -1.2, 12, HALL_H + 4, 0, HALL, model)
	deco("ParapetCap", f, -12.4, HALL_H + 4, -1.4, 12.4, HALL_H + 4.5, 0.3, HALL_DARK, model)
	local emblem = deco("Emblem", f, -10, HALL_H + 1.2, 0, 10, HALL_H + 3.8, 0.1, HALL, model, { Transparency = 1 })
	words(emblem, "🌾 GRAIN · PRODUCE · PRICES 🌾", INK)
	-- the price board in a wooden frame (MarketController draws on PriceBoard)
	local B = TownArt.BOARD
	local y0 = 4.2
	box("PriceBoard", f, -B.X / 2, y0, 0, B.X / 2, y0 + B.Y, B.Z, Color3.fromRGB(30, 34, 32), model)
	deco("BoardFrame", f, -B.X / 2 - 0.6, y0 + B.Y, -0.05, B.X / 2 + 0.6, y0 + B.Y + 0.6, 0.55, COLORS.post, model)
	deco("BoardFrame", f, -B.X / 2 - 0.6, y0 - 0.6, -0.05, B.X / 2 + 0.6, y0, 0.55, COLORS.post, model)
	deco("BoardFrame", f, -B.X / 2 - 0.6, y0, -0.05, -B.X / 2, y0 + B.Y, 0.55, COLORS.post, model)
	deco("BoardFrame", f, B.X / 2, y0, -0.05, B.X / 2 + 0.6, y0 + B.Y, 0.55, COLORS.post, model)
	-- a step along the front, the desk on it (MarketService's prompt)
	box("HallStep", f, -W / 2, 0, 0, W / 2, 0.6, 2, HALL_DARK, model)
	local deskAt = PlotLayout.frontOf("Exchange", 4) + Vector3.new(0, 1.75, 0)
	local desk = CFrame.lookAt(deskAt, Vector3.new(0, deskAt.Y, 0))
	Parts.part({ Name = "ExchangeDesk", Size = Vector3.new(12, 3.5, 3), CFrame = desk, Color = COLORS.slate }, town)
	Parts.prop({ Name = "DeskTop", Size = Vector3.new(12.6, 0.4, 3.6), CFrame = desk * CFrame.new(0, 1.95, 0), Color = COLORS.post }, model)
	local plate = Parts.prop({ Name = "DeskSign", Size = Vector3.new(7, 1.4, 0.05), CFrame = desk * CFrame.new(0, 0.2, -1.53) * CFrame.Angles(0, math.rad(180), 0),
		Color = COLORS.slate, Transparency = 1 }, model)
	words(plate, "MARKET PRICES", CREAM)
	-- side windows down the hall
	for _, side in { -1, 1 } do
		for _, z in { -3.5, -8.5 } do
			local glass = deco("Glass", f, side * W / 2 - 0.12 * side, 8, z - 1.6, side * (W / 2 + 0.05), 20, z + 1.6, GLASS, model)
			glass:SetAttribute("NightColor", WINDOW_NIGHT)
			glass:AddTag("NightGlow")
			deco("WindowHead", f, side * W / 2, 20, z - 2, side * (W / 2 + 0.3), 20.6, z + 2, HALL_DARK, model)
		end
	end

	-- the grain elevator behind: the crib (slate boards, white corners,
	-- battens), CLOVERDALE across its top, a gable roof, the cupola
	local CW, Z0, Z1, TOP, RIDGE = 11, -D + 1, -HALL_D - 1, 61, 67
	box("Elevator", f, -CW, 0, Z0, CW, TOP, Z1, CRIB, model)
	for _, x in { -CW, CW } do
		for _, z in { Z0, Z1 } do
			deco("Corner", f, x - 0.5, HALL_H - 2, z - 0.5, x + 0.5, TOP, z + 0.5, WHITE, model)
		end
	end
	for x = -CW + 2, CW - 2, 2 do
		deco("Batten", f, x - 0.12, HALL_H + 4.5, Z1, x + 0.12, TOP - 6.5, Z1 + 0.15, CRIB_DARK, model)
	end
	local band = deco("NameBand", f, -CW, TOP - 6.5, Z1, CW, TOP - 0.5, Z1 + 0.2, WHITE, model)
	words(band, "CLOVERDALE", CRIB_DARK, Enum.Font.FredokaOne, 16)
	gable(f, Z1 - 1, Z1, CW, TOP, RIDGE, CRIB, model)
	gable(f, Z0, Z0 + 1, CW, TOP, RIDGE, CRIB, model)
	roof(f, CW, TOP, RIDGE, Z0, Z1, 1, SLATE, model)
	-- the cupola on the ridge (the headhouse): its own gable roof, a window
	local C0, C1 = -21.5, -15.5
	box("Cupola", f, -4, RIDGE - 2, C0, 4, RIDGE + 5.5, C1, CRIB, model)
	gable(f, C1 - 0.6, C1, 4, RIDGE + 5.5, RIDGE + 8.5, CRIB, model)
	gable(f, C0, C0 + 0.6, 4, RIDGE + 5.5, RIDGE + 8.5, CRIB, model)
	roof(f, 4, RIDGE + 5.5, RIDGE + 8.5, C0, C1, 0.8, SLATE, model)
	deco("CupolaWindow", f, -1.4, RIDGE + 1.2, C1, 1.4, RIDGE + 4.2, C1 + 0.15, Color3.fromRGB(52, 58, 70), model)
	deco("CupolaFrame", f, -1.8, RIDGE + 4.2, C1, 1.8, RIDGE + 4.6, C1 + 0.3, WHITE, model)

	-- two silos either side, cone caps, galleries from the cupola to them
	for _, side in { -1, 1 } do
		local at = f * CFrame.new(side * 15.5, 0, -22)
		local silo = Parts.cylinder("Silo", at * CFrame.new(0, 24, 0), 9.6, 48, { Color = CONCRETE }, model)
		silo.CanCollide = true
		for _, y in { 16, 32, 47.6 } do
			Parts.cylinder("SiloBand", at * CFrame.new(0, y, 0), 9.8, 0.5, { Color = CONCRETE_DARK }, model)
		end
		local cap = Meshes.make("Cone", at * CFrame.new(0, 48, 0), Vector3.new(10.2, 4.2, 10.2), model)
		if cap then
			cap.Color = SLATE
			cap.Name = "SiloCap"
		else
			Parts.cylinder("SiloCap", at * CFrame.new(0, 49, 0), 7, 2, { Color = SLATE }, model)
		end
		-- the conveyor gallery: a covered box sloping down from the cupola
		slab("Gallery", f, side * 4, RIDGE + 2.2, side * 15.5, 50.6, -19.2, -17.6, 1.8, CRIB_DARK, model)
	end

	model.Parent = town
	return model
end

------------------------------------------------------------------------

function TownArt.build(town: Instance)
	seedShop(town)
	hiringHall(town)
	exchange(town)
end

return TownArt
