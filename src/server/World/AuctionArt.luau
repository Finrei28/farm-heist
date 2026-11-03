-- The Cloverdale Auction House (docs/GameDesign.md §4.4, ArtDirection.md
-- §6): a red barn hall with white trim and a slate roof, its big doors
-- open to the square, the bell tower on its ridge (it rings when an auction
-- starts). Inside, the bidders' benches face a stage: the lot board on the
-- back wall between red velvet curtains, the lot's pedestal, and Goldie
-- Gavel (a golden hen in a red waistcoat) at her podium with her gavel.
-- You must be inside to bid (PlotLayout.insideBuilding; AuctionService).
-- The board, the lot over the pedestal and Goldie's calls are drawn by the
-- clients (AuctionController) from the auction's attributes.
--
-- The building's frame: origin at the middle of its front wall on the
-- ground, +Z out toward the square, +X to the right as you face it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
local Parts = require(script.Parent.Parts)

local AuctionArt = {}

local COLORS = Parts.COLORS
local RED = Color3.fromRGB(184, 58, 42)
local RED_DARK = Color3.fromRGB(150, 44, 34)
local WHITE = Color3.fromRGB(246, 240, 226)
local ROOF = Color3.fromRGB(98, 104, 116)
local FLOOR = Color3.fromRGB(176, 128, 82)
local FLOOR_DARK = Color3.fromRGB(150, 106, 66)
local WOOD = Color3.fromRGB(128, 86, 52)
local VELVET = Color3.fromRGB(150, 28, 40)
local GOLD = Color3.fromRGB(240, 186, 64)
local GLASS = Color3.fromRGB(150, 196, 220)

AuctionArt.WALL = 15 -- the walls' height (the ridge is at the building's 26)

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

-- Words on a part's +Z face (Back, in Roblox's names).
local function words(p: BasePart, text: string, color: Color3, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
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

-- A slab between two points in the frame's X-Y plane (a gable's edge, a
-- roof), `width` across, between z0 and z1.
local function slab(name, frame: CFrame, xa, ya, xb, yb, z0, z1, width, color, parent, solid: boolean?)
	local dx, dy = xb - xa, yb - ya
	local length = math.sqrt(dx * dx + dy * dy)
	local cf = frame * CFrame.new((xa + xb) / 2, (ya + yb) / 2, (z0 + z1) / 2) * CFrame.Angles(0, 0, math.atan2(dy, dx))
	local props = { Name = name, Size = Vector3.new(length, width, math.abs(z1 - z0)), CFrame = cf, Color = color }
	return if solid then Parts.part(props, parent) else Parts.prop(props, parent)
end

-- A gable end: two wedges meeting at the middle, from the wall top to the
-- ridge, in the wall's plane z0..z1.
local function gable(frame: CFrame, z0: number, z1: number, halfWidth: number, y0: number, y1: number, parent: Instance)
	for _, side in { -1, 1 } do
		-- (a wedge's tall face is its +Z: turned so it's at the middle)
		local inward = Vector3.new(-side, 0, 0)
		local across = Vector3.yAxis:Cross(inward)
		local centre = Vector3.new(side * halfWidth / 2, (y0 + y1) / 2, (z0 + z1) / 2)
		Parts.part({
			Name = "Gable", Shape = Enum.PartType.Wedge, Size = Vector3.new(math.abs(z1 - z0), y1 - y0, halfWidth),
			CFrame = frame * CFrame.fromMatrix(centre, across, Vector3.yAxis, inward), Color = RED,
		}, parent)
	end
end

-- Goldie Gavel: a plump golden hen in a red waistcoat and black bow tie,
-- her gavel raised in one wing. `feet`: where she stands, facing +Z.
local function goldie(feet: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "GoldieGavel"
	local gold = Color3.fromRGB(236, 178, 62)
	local goldDark = Color3.fromRGB(196, 132, 40)
	local yellow = Color3.fromRGB(245, 196, 72)
	local red = Color3.fromRGB(214, 52, 40)
	for _, x in { -0.45, 0.45 } do
		Parts.prop({ Name = "Leg", Size = Vector3.new(0.25, 1.7, 0.25), CFrame = feet * CFrame.new(x, 0.85, 0), Color = yellow }, model)
		Parts.prop({ Name = "Foot", Size = Vector3.new(0.6, 0.15, 0.8), CFrame = feet * CFrame.new(x, 0.08, 0.2), Color = yellow }, model)
	end
	local body = feet * CFrame.new(0, 2.9, 0)
	Parts.prop({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.9, CFrame = body, Color = gold }, model)
	Parts.prop({ Name = "Chest", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2, CFrame = body * CFrame.new(0, 0.45, 0.8), Color = gold }, model)
	-- the waistcoat: a red band round her middle, two gold buttons
	Parts.prop({ Name = "Waistcoat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, 3.0, 3.0), CFrame = body * CFrame.new(0, -0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = red }, model)
	for i, y in { 0.15, -0.4 } do
		Parts.prop({ Name = "Button", Shape = Enum.PartType.Ball, Size = Vector3.one * (0.3 + i * 0.01), CFrame = body * CFrame.new(0, y, 1.5), Color = GOLD }, model)
	end
	for _, x in { -1.35, 1.35 } do
		Parts.prop({ Name = "Wing", Size = Vector3.new(0.5, 1.5, 1.9), CFrame = body * CFrame.new(x, 0.1, -0.1) * CFrame.Angles(math.rad(-15), 0, 0), Color = goldDark }, model)
	end
	for i, angle in { -28, 0, 28 } do
		Parts.prop({ Name = "TailFeather", Size = Vector3.new(0.35, 2.2, 0.7 + i * 0.12),
			CFrame = body * CFrame.new(0, 0.9, -1.3) * CFrame.Angles(math.rad(-32), 0, math.rad(angle)) * CFrame.new(0, 0.9, 0), Color = goldDark }, model)
	end
	local head = feet * CFrame.new(0, 5.1, 0.55)
	Parts.prop({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.7, CFrame = head, Color = gold }, model)
	Parts.prop({ Name = "Beak", Size = Vector3.new(0.45, 0.35, 0.8), CFrame = head * CFrame.new(0, -0.1, 0.95), Color = Color3.fromRGB(240, 150, 40) }, model)
	Parts.prop({ Name = "Wattle", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45, CFrame = head * CFrame.new(0, -0.6, 0.75), Color = red }, model)
	for _, x in { -0.42, 0.42 } do
		Parts.prop({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.3, CFrame = head * CFrame.new(x, 0.15, 0.74), Color = COLORS.dark }, model)
	end
	for i, z in { -0.35, 0, 0.35 } do
		Parts.prop({ Name = "Comb", Shape = Enum.PartType.Ball, Size = Vector3.one * (if i == 2 then 0.62 else 0.5), CFrame = head * CFrame.new(0, 0.95 + (if i == 2 then 0.08 else 0), z), Color = red }, model)
	end
	-- the bow tie under her beak
	for _, x in { -0.32, 0.32 } do
		Parts.prop({ Name = "BowTie", Size = Vector3.new(0.5, 0.42, 0.18), CFrame = head * CFrame.new(x, -0.95, 0.6) * CFrame.Angles(0, 0, math.rad(x * 50)), Color = COLORS.dark }, model)
	end
	Parts.prop({ Name = "BowKnot", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.26, CFrame = head * CFrame.new(0, -0.95, 0.66), Color = COLORS.dark }, model)
	-- the gavel, raised in her right wing
	local grip = body * CFrame.new(1.7, 0.9, 0.5) * CFrame.Angles(0, 0, math.rad(-25))
	Parts.prop({ Name = "GavelHandle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.8, 0.22, 0.22), CFrame = grip * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = WOOD }, model)
	Parts.prop({ Name = "GavelHead", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.1, 0.6, 0.6), CFrame = grip * CFrame.new(0, 1.55, 0) * CFrame.Angles(0, math.rad(90), 0), Color = WOOD }, model)
	for _, z in { -0.36, 0.36 } do -- (rings round the head, short of its ends)
		Parts.prop({ Name = "GavelBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.66, 0.66), CFrame = grip * CFrame.new(0, 1.55, z) * CFrame.Angles(0, math.rad(90), 0), Color = GOLD }, model)
	end
	model.Parent = parent
	return model
end

function AuctionArt.build(town: Instance): Model
	local building = PlotLayout.building("Auction")
	local W, H, D = building.size.X, building.size.Y, building.size.Z
	local WALL = AuctionArt.WALL
	local f = PlotLayout.buildingFrame("Auction")
	local model = Instance.new("Model")
	model.Name = "AuctionHouse"
	local walls = Instance.new("Model")
	walls.Name = "Walls"
	walls.Parent = model

	------------------------------------------------------------------
	-- The floor (with a threshold out past the doors, above the plaza's
	-- 0.4) and the walls round it

	local F = 0.6 -- the floor's top
	box("HallFloor", f, -W / 2, 0, -D, W / 2, F, 1.6, FLOOR, model)
	for x = -W / 2 + 2, W / 2 - 2, 2.5 do
		deco("FloorBoard", f, x - 0.05, F, -D + 1, x + 0.05, F + 0.04, -1, FLOOR_DARK, model)
	end
	-- back wall, and the front either side of the doorway and over it
	local DOOR, DOOR_TOP = 6, 11.6
	box("Wall", f, -W / 2, F, -D, W / 2, WALL, -D + 1, RED, walls)
	box("Wall", f, -W / 2, F, -1, -DOOR, WALL, 0, RED, walls)
	box("Wall", f, DOOR, F, -1, W / 2, WALL, 0, RED, walls)
	box("Wall", f, -DOOR, DOOR_TOP, -1, DOOR, WALL, 0, RED, walls)
	-- the side walls, each with three windows (real openings, glazed)
	local WIN_Z = { -8, -17, -26 }
	local SILL, HEAD = 6, 11
	for _, side in { -1, 1 } do
		local x0, x1 = if side < 0 then -W / 2 else W / 2 - 1, if side < 0 then -W / 2 + 1 else W / 2
		box("Wall", f, x0, F, -D + 1, x1, SILL, -1, RED, walls)
		box("Wall", f, x0, HEAD, -D + 1, x1, WALL, -1, RED, walls)
		local from = -D + 1
		for _, z in { -26, -17, -8 } do
			box("Wall", f, x0, SILL, from, x1, HEAD, z - 2, RED, walls)
			box("WindowGlass", f, x0 + 0.4, SILL, z - 2, x1 - 0.4, HEAD, z + 2, GLASS, model, { Transparency = 0.55, CastShadow = false })
			-- white frames outside: a head, a sill, two sides
			local out = if side < 0 then x0 - 0.3 else x1 + 0.3
			local face = if side < 0 then x0 else x1
			deco("WindowFrame", f, face, HEAD, z - 2.4, out, HEAD + 0.4, z + 2.4, WHITE, model)
			deco("WindowSill", f, face, SILL - 0.4, z - 2.6, out + side * 0.25, SILL, z + 2.6, WHITE, model)
			for _, dz in { -2.4, 2 } do
				deco("WindowFrame", f, face, SILL, z + dz, out, HEAD, z + dz + 0.4, WHITE, model)
			end
			deco("Mullion", f, face, SILL, z - 0.1, face + side * 0.15, HEAD, z + 0.1, WHITE, model)
			from = z + 2
		end
		box("Wall", f, x0, SILL, from, x1, HEAD, -1, RED, walls)
	end
	-- board battens up the outside (white trim at the corners)
	for _, side in { -1, 1 } do
		local face = side * W / 2
		for z = -D + 2, -2, 3 do
			local clear = true
			for _, wz in WIN_Z do
				if math.abs(z - wz) < 3 then
					clear = false
				end
			end
			if clear then
				deco("Batten", f, face, F, z - 0.15, face + side * 0.15, WALL, z + 0.15, RED_DARK, model)
			end
		end
	end
	for x = -W / 2 + 2, W / 2 - 2, 3 do
		if math.abs(x) > DOOR + 0.5 then
			deco("Batten", f, x - 0.15, F, 0, x + 0.15, WALL, 0.15, RED_DARK, model)
		end
		deco("Batten", f, x - 0.15, F, -D - 0.15, x + 0.15, WALL, -D, RED_DARK, model)
	end
	for _, x in { -W / 2, W / 2 } do
		for _, z in { 0, -D } do
			deco("Corner", f, x - 0.45, F, z - 0.45, x + 0.45, WALL + 0.2, z + 0.45, WHITE, model)
		end
	end

	-- inside: warm boards up to the windows' sills, a rail along their top
	-- (the door's gap left open)
	local LINE = Color3.fromRGB(196, 150, 104)
	local top = SILL - 0.4
	for _, side in { -1, 1 } do -- (the back wall's either side of the stage)
		deco("Lining", f, side * (W / 2 - 1), F, -D + 1, side * 15, top, -D + 1.2, LINE, model)
		deco("Rail", f, side * (W / 2 - 1), top, -D + 1, side * 15, top + 0.3, -D + 1.35, WOOD, model)
	end
	for _, side in { -1, 1 } do
		local inner = side * (W / 2 - 1)
		deco("Lining", f, inner, F, -D + 1.2, inner - side * 0.2, top, -1, LINE, model)
		deco("Rail", f, inner, top, -D + 1, inner - side * 0.35, top + 0.3, -1, WOOD, model)
		deco("Lining", f, side * (DOOR + 0.5), F, -1.2, side * (W / 2 - 1.2), top, -1, LINE, model)
		deco("Rail", f, side * (DOOR + 0.5), top, -1.35, side * (W / 2 - 1.35), top + 0.3, -1, WOOD, model)
	end

	------------------------------------------------------------------
	-- The roof: gables front and back, two slate slopes, a ridge cap, tie
	-- beams across inside

	-- (a plate along each side wall's top up into the roof: no strip of sky
	-- between them)
	for _, side in { -1, 1 } do
		box("WallPlate", f, side * (W / 2 - 1), WALL, -D, side * W / 2, WALL + 0.6, 0, RED, walls)
	end
	gable(f, -1, 0, W / 2, WALL, H, walls)
	gable(f, -D, -D + 1, W / 2, WALL, H, walls)
	local eave = W / 2 + 1.2
	local drop = (H - WALL) * 1.2 / (W / 2)
	for _, side in { -1, 1 } do
		-- (on top of the gables' slope, overhanging the walls and the gables)
		slab("Roof", f, side * eave, WALL - drop + 0.45, 0, H + 0.45, -D - 1, 1, 0.9, ROOF, model, true)
		-- the white edge along each gable, just proud of it
		slab("GableTrim", f, side * (W / 2 + 0.6), WALL - 0.4, 0, H - 0.05, 0, 0.35, 0.7, WHITE, model)
		slab("GableTrim", f, side * (W / 2 + 0.6), WALL - 0.4, 0, H - 0.05, -D - 0.35, -D, 0.7, WHITE, model)
	end
	deco("RidgeCap", f, -0.7, H + 0.35, -D - 1.1, 0.7, H + 1.05, 1.1, ROOF:Lerp(COLORS.dark, 0.3), model)
	for _, z in WIN_Z do
		deco("TieBeam", f, -W / 2 + 1, WALL - 1, z - 0.4, W / 2 - 1, WALL - 0.3, z + 0.4, WOOD, model)
	end

	------------------------------------------------------------------
	-- The front: the open doors, the sign in the gable, lanterns

	-- the doorway's white frame and the two red leaves swung open flat
	-- against the wall, X-braced
	deco("DoorFrame", f, -DOOR - 0.5, F, 0, -DOOR, DOOR_TOP + 0.5, 0.3, WHITE, model)
	deco("DoorFrame", f, DOOR, F, 0, DOOR + 0.5, DOOR_TOP + 0.5, 0.3, WHITE, model)
	deco("DoorFrame", f, -DOOR - 0.5, DOOR_TOP, 0, DOOR + 0.5, DOOR_TOP + 0.5, 0.3, WHITE, model)
	for _, side in { -1, 1 } do
		local x0, x1 = side * (DOOR + 0.6), side * (DOOR + 6.4)
		local lo, hi = math.min(x0, x1), math.max(x0, x1)
		deco("DoorLeaf", f, lo, F + 0.1, 0.3, hi, DOOR_TOP - 0.2, 0.6, RED, model)
		deco("DoorTrim", f, lo, F + 0.1, 0.6, hi, F + 0.6, 0.75, WHITE, model)
		deco("DoorTrim", f, lo, DOOR_TOP - 0.7, 0.6, hi, DOOR_TOP - 0.2, 0.75, WHITE, model)
		deco("DoorTrim", f, lo, F + 0.6, 0.6, lo + 0.5, DOOR_TOP - 0.7, 0.75, WHITE, model)
		deco("DoorTrim", f, hi - 0.5, F + 0.6, 0.6, hi, DOOR_TOP - 0.7, 0.75, WHITE, model)
		slab("DoorBrace", f, lo + 0.4, F + 0.8, hi - 0.4, DOOR_TOP - 0.9, 0.62, 0.72, 0.45, WHITE, model)
		slab("DoorBrace", f, lo + 0.4, DOOR_TOP - 0.9, hi - 0.4, F + 0.8, 0.64, 0.74, 0.45, WHITE, model)
	end
	-- the sign in the gable, and a board over the doors
	deco("SignBoard", f, -11, 16.2, 0, 11, 20.8, 0.3, WHITE, model)
	local sign = deco("Sign", f, -10.5, 16.6, 0.3, 10.5, 20.4, 0.45, RED_DARK, model)
	words(sign, "AUCTION HOUSE", WHITE)
	local times = deco("TimesBoard", f, -6, 12.3, 0, 6, 14.4, 0.3, Color3.fromRGB(44, 60, 50), model)
	words(times, "Live auctions every 8 minutes", Color3.fromRGB(240, 238, 226), Enum.Font.PatrickHand)
	-- lanterns either side of the doors (lit at night)
	for _, x in { -DOOR - 7.8, DOOR + 7.8 } do -- (past the open leaves, between battens)
		deco("LanternArm", f, x - 0.12, 9.4, 0, x + 0.12, 9.65, 0.9, COLORS.dark, model)
		local glass = deco("Lantern", f, x - 0.4, 8.4, 0.5, x + 0.4, 9.4, 1.3, Color3.fromRGB(255, 222, 140), model)
		glass:SetAttribute("NightColor", Color3.fromRGB(255, 200, 110))
		glass:AddTag("NightGlow")
		deco("LanternCap", f, x - 0.52, 9.4, 0.38, x + 0.52, 9.65, 1.42, COLORS.dark, model)
	end

	------------------------------------------------------------------
	-- The bell tower on the ridge, over the doors

	local tz0, tz1 = -8, -3
	box("TowerBase", f, -2.5, H - 3.5, tz0, 2.5, H + 2, tz1, RED, model)
	deco("TowerTrim", f, -2.75, H + 1.6, tz0 - 0.25, 2.75, H + 2.1, tz1 + 0.25, WHITE, model)
	for _, x in { -2.25, 2.25 } do
		for _, z in { tz0 + 0.25, tz1 - 0.25 } do
			deco("TowerPost", f, x - 0.3, H + 2.1, z - 0.3, x + 0.3, H + 5.6, z + 0.3, WHITE, model)
		end
	end
	deco("TowerRoof", f, -3.1, H + 5.6, tz0 - 0.6, 3.1, H + 6.2, tz1 + 0.6, ROOF, model)
	deco("TowerRoof", f, -2.2, H + 6.2, tz0 + 0.3, 2.2, H + 6.8, tz1 - 0.3, ROOF, model)
	deco("TowerRoof", f, -1.2, H + 6.8, tz0 + 1.3, 1.2, H + 7.3, tz1 - 1.3, ROOF, model)
	Parts.ball("Finial", f * CFrame.new(0, H + 7.7, (tz0 + tz1) / 2), 0.8, { Color = GOLD }, model)
	local bell = Instance.new("Model")
	bell.Name = "AuctionBell" -- (AuctionController swings it when an auction starts)
	deco("BellBeam", f, -2.2, H + 5.0, (tz0 + tz1) / 2 - 0.2, 2.2, H + 5.35, (tz0 + tz1) / 2 + 0.2, WOOD, bell)
	local hang = f * CFrame.new(0, H + 5.0, (tz0 + tz1) / 2)
	Parts.cylinder("BellCrown", hang * CFrame.new(0, -0.35, 0), 1.1, 0.7, { Color = GOLD }, bell)
	Parts.cylinder("BellBody", hang * CFrame.new(0, -1.35, 0), 1.9, 1.4, { Color = GOLD }, bell)
	Parts.cylinder("BellLip", hang * CFrame.new(0, -2.15, 0), 2.4, 0.3, { Color = GOLD }, bell)
	bell:SetAttribute("Pivot", hang.Position)
	bell.Parent = model

	------------------------------------------------------------------
	-- Inside: the stage at the back, the lot board, the pedestal, the
	-- podium and Goldie, the benches, the lamps

	local S0, S1, STAGE = -D + 1, -D + 10, F + 2.6
	box("Stage", f, -15, F, S0, 15, STAGE, S1, FLOOR, model)
	deco("StageSkirt", f, -15, F, S1, 15, STAGE - 0.3, S1 + 0.2, VELVET, model)
	deco("StageEdge", f, -15.2, STAGE - 0.3, S1 - 0.1, 15.2, STAGE + 0.05, S1 + 0.25, GOLD, model)
	for _, side in { -1, 1 } do
		box("StageStep", f, side * 15, F, S0 + 2, side * 17.4, F + 1.3, S0 + 6, FLOOR_DARK, model)
	end
	-- the lot board, framed in gold between red curtains
	deco("LotBoard", f, -9, 6.2, S0, 9, 12.8, S0 + 0.25, Color3.fromRGB(44, 60, 50), model) -- (AuctionController draws the lot, the bid and the clock on it)
	deco("BoardFrame", f, -9.5, 12.8, S0, 9.5, 13.3, S0 + 0.35, GOLD, model)
	deco("BoardFrame", f, -9.5, 5.7, S0, 9.5, 6.2, S0 + 0.35, GOLD, model)
	deco("BoardFrame", f, -9.5, 6.2, S0, -9, 12.8, S0 + 0.35, GOLD, model)
	deco("BoardFrame", f, 9, 6.2, S0, 9.5, 12.8, S0 + 0.35, GOLD, model)
	for _, side in { -1, 1 } do
		local x0, x1 = side * 10.2, side * 14.4
		local lo, hi = math.min(x0, x1), math.max(x0, x1)
		deco("Curtain", f, lo, STAGE, S0, hi, WALL - 0.2, S0 + 0.6, VELVET, model)
		-- (its folds: darker strips down it, so it reads as hanging cloth)
		for x = lo + 0.5, hi - 0.4, 0.8 do
			deco("CurtainFold", f, x - 0.14, STAGE, S0 + 0.6, x + 0.14, WALL - 1.4, S0 + 0.8, VELVET:Lerp(COLORS.dark, 0.35), model) -- (up into the pelmet)
		end
		deco("CurtainTie", f, lo - 0.05, 7.4, S0 + 0.6, hi + 0.05, 7.9, S0 + 0.95, GOLD, model)
	end
	deco("Pelmet", f, -14.6, WALL - 1.5, S0, 14.6, WALL - 0.2, S0 + 0.9, VELVET, model)
	deco("PelmetTrim", f, -14.7, WALL - 1.6, S0 + 0.9, 14.7, WALL - 1.3, S0 + 1.0, GOLD, model)
	-- the lot's pedestal at the stage's front edge: a plinth with a velvet
	-- top, the lot sitting on it (further back, from the benches it hid
	-- the board's bid)
	local pedestal = Parts.cylinder("Pedestal", f * CFrame.new(0, STAGE + 1.2, S0 + 7.4), 2.6, 2.4, { Color = WHITE }, model)
	pedestal.CanCollide = true
	Parts.cylinder("PedestalTop", f * CFrame.new(0, STAGE + 2.5, S0 + 7.4), 3.0, 0.3, { Color = VELVET }, model)
	-- the podium, Goldie behind it with her gavel up
	box("Podium", f, 7.2, STAGE, S0 + 5.6, 10.8, STAGE + 3.6, S0 + 7.4, WOOD, model)
	deco("PodiumTop", f, 7.0, STAGE + 3.6, S0 + 5.3, 11.0, STAGE + 3.95, S0 + 7.7, FLOOR, model)
	-- her name on the podium's plate (a floating name tag hid the lot board
	-- from the benches); AuctionController puts her calls in a bubble
	local plate = deco("PodiumPlate", f, 7.5, STAGE + 1.0, S0 + 7.4, 10.5, STAGE + 2.8, S0 + 7.5, GOLD, model)
	words(plate, "GOLDIE GAVEL\nauctioneer", WOOD)
	goldie(f * CFrame.new(9, STAGE, S0 + 3.8), model)
	-- the benches: three rows each side of the aisle, facing the stage
	for _, z in { S1 + 4, S1 + 9, S1 + 14 } do
		for _, side in { -1, 1 } do
			local x0, x1 = side * 3.2, side * 16.5
			local lo, hi = math.min(x0, x1), math.max(x0, x1)
			box("BenchSeat", f, lo, F + 1.6, z, hi, F + 2.0, z + 1.8, WOOD, model)
			deco("BenchBack", f, lo, F + 2.0, z + 1.8, hi, F + 3.8, z + 2.2, WOOD, model)
			for _, x in { lo + 0.6, (lo + hi) / 2, hi - 0.6 } do
				deco("BenchLeg", f, x - 0.2, F, z + 0.2, x + 0.2, F + 1.6, z + 1.6, FLOOR_DARK, model)
			end
		end
	end
	-- lamps hung from the tie beams, and a light on the stage (6 at most)
	for _, z in { -8, -17 } do
		for _, x in { -10, 10 } do
			deco("LampCord", f, x - 0.06, WALL - 3.6, z - 0.06, x + 0.06, WALL - 1, z + 0.06, COLORS.dark, model)
			local shade = deco("LampShade", f, x - 1, WALL - 4.2, z - 1, x + 1, WALL - 3.6, z + 1, Color3.fromRGB(60, 80, 64), model)
			local bulb = Parts.ball("LampBulb", f * CFrame.new(x, WALL - 4.35, z), 0.7, { Color = Color3.fromRGB(255, 228, 170), Material = Enum.Material.Neon }, model)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 226, 180)
			light.Range = 22
			light.Brightness = 0.45
			light.Shadows = false
			light.Parent = bulb
			shade.CastShadow = false
		end
	end
	-- (under the middle tie beam, tilted down at the board and the podium)
	local spotAt = f * Vector3.new(0, WALL - 1.6, -17)
	local spot = Parts.prop({ Name = "StageLight", Size = Vector3.new(1.2, 0.9, 1.4), Color = COLORS.dark,
		CFrame = CFrame.lookAt(spotAt, f * Vector3.new(0, STAGE + 4, S0 + 2)) }, model)
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front -- (−Z: where it looks)
	beam.Angle = 50
	beam.Range = 26
	beam.Brightness = 1.2
	beam.Color = Color3.fromRGB(255, 236, 200)
	beam.Shadows = false
	beam.Parent = spot

	model.Parent = town
	return model
end

return AuctionArt
