-- The Police Station's front (docs/ArtDirection.md §6, §11 step 6): a blue
-- station with cream trim and a big gold sheriff's star over its sign, barred
-- windows upstairs (the cells), and a wooden porch under a roof. Arrested
-- players appear on the porch right in front of a height chart, as if for
-- their mugshot. Sheriff Clucks (a rooster in a cowboy hat with a star)
-- stands behind the police desk, where debts are paid (PayoutService puts
-- the prompt on PoliceDesk). A poster by the door says how arrests work.
--
-- The building's frame: origin at the middle of its front wall on the
-- ground, +Z out toward the square, +X to the right as you face it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
local Parts = require(script.Parent.Parts)

local PoliceArt = {}

local COLORS = Parts.COLORS
local BLUE = Color3.fromRGB(74, 120, 192)
local BLUE_DARK = Color3.fromRGB(40, 64, 112)
local NAVY = Color3.fromRGB(32, 46, 84)
local CREAM = COLORS.cream
local GOLD = Color3.fromRGB(245, 190, 60)
local DECK = Color3.fromRGB(176, 128, 82)
local DECK_DARK = Color3.fromRGB(140, 98, 60)
local GLASS = Color3.fromRGB(150, 196, 220)

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

-- Words on the face toward the square (+Z).
local function words(p: BasePart, text: string, color: Color3, font: Enum.Font?, scaled: boolean?, size: number?)
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
	label.TextScaled = scaled ~= false
	label.TextSize = size or 40
	label.TextWrapped = true
	label.TextColor3 = color
	label.Text = text
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label
	label.Parent = gui
	gui.Parent = p
	return label
end

-- A window on the front wall: glass, a cream frame and sill, bars for the cells.
local function window(frame: CFrame, x0, x1, y0, y1, parent: Instance, bars: boolean?)
	deco("Glass", frame, x0, y0, -0.05, x1, y1, 0.15, GLASS, parent, { Reflectance = 0.1 })
	deco("Frame", frame, x0 - 0.4, y1, 0, x1 + 0.4, y1 + 0.4, 0.3, CREAM, parent)
	deco("Frame", frame, x0 - 0.4, y0 - 0.1, 0, x0, y1, 0.3, CREAM, parent)
	deco("Frame", frame, x1, y0 - 0.1, 0, x1 + 0.4, y1, 0.3, CREAM, parent)
	deco("Sill", frame, x0 - 0.6, y0 - 0.5, 0, x1 + 0.6, y0, 0.55, CREAM, parent)
	if bars then
		local n = math.max(3, math.floor((x1 - x0) / 0.9))
		for i = 1, n - 1 do
			local x = x0 + (x1 - x0) * i / n
			deco("Bar", frame, x - 0.1, y0, 0.1, x + 0.1, y1, 0.3, Color3.fromRGB(70, 70, 78), parent)
		end
	else
		deco("Mullion", frame, (x0 + x1) / 2 - 0.12, y0, 0.05, (x0 + x1) / 2 + 0.12, y1, 0.2, CREAM, parent)
	end
end

-- Sheriff Clucks: a white rooster in a brown cowboy hat with a gold star.
local function sheriff(feet: CFrame, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "SheriffClucks"
	local white = Color3.fromRGB(248, 244, 236)
	local yellow = Color3.fromRGB(245, 186, 52)
	local red = Color3.fromRGB(214, 52, 40)
	local hat = Color3.fromRGB(128, 82, 46)
	for _, x in { -0.45, 0.45 } do
		Parts.prop({ Name = "Leg", Size = Vector3.new(0.25, 1.9, 0.25), CFrame = feet * CFrame.new(x, 0.95, 0), Color = yellow }, model)
		Parts.prop({ Name = "Foot", Size = Vector3.new(0.6, 0.15, 0.8), CFrame = feet * CFrame.new(x, 0.08, 0.2), Color = yellow }, model)
	end
	local body = feet * CFrame.new(0, 3.1, 0)
	Parts.prop({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(2.8, 2.8, 2.8), CFrame = body, Color = white }, model)
	Parts.prop({ Name = "Chest", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = body * CFrame.new(0, 0.5, 0.75), Color = white }, model)
	for _, x in { -1.35, 1.35 } do
		Parts.prop({ Name = "Wing", Size = Vector3.new(0.5, 1.6, 2), CFrame = body * CFrame.new(x, 0, -0.1) * CFrame.Angles(math.rad(-15), 0, 0), Color = Color3.fromRGB(232, 226, 214) }, model)
	end
	for i, angle in { -30, 0, 30 } do
		Parts.prop({ Name = "TailFeather", Size = Vector3.new(0.35, 2.6, 0.9),
			CFrame = body * CFrame.new(0, 1, -1.3) * CFrame.Angles(math.rad(-30), 0, math.rad(angle)) * CFrame.new(0, 1.1, 0),
			Color = if i == 2 then Color3.fromRGB(52, 90, 60) else Color3.fromRGB(70, 112, 70) }, model)
	end
	local head = feet * CFrame.new(0, 5.4, 0.55)
	Parts.prop({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.7, 1.7, 1.7), CFrame = head, Color = white }, model)
	Parts.prop({ Name = "Beak", Size = Vector3.new(0.45, 0.35, 0.8), CFrame = head * CFrame.new(0, -0.1, 0.95), Color = yellow }, model)
	Parts.prop({ Name = "Wattle", Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.45, 0.45), CFrame = head * CFrame.new(0, -0.6, 0.75), Color = red }, model)
	for _, x in { -0.42, 0.42 } do
		Parts.prop({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), CFrame = head * CFrame.new(x, 0.15, 0.74), Color = COLORS.dark }, model)
	end
	-- the hat: a wide brim and a dented crown, the gold star on its front
	Parts.cylinder("HatBrim", head * CFrame.new(0, 0.75, 0), 2.9, 0.2, { Color = hat }, model)
	Parts.cylinder("HatCrown", head * CFrame.new(0, 1.25, 0), 1.5, 0.9, { Color = hat }, model)
	-- the red comb pokes up through the top of the hat
	for i, z in { -0.35, 0, 0.35 } do
		Parts.prop({ Name = "Comb", Shape = Enum.PartType.Ball, Size = Vector3.one * (if i == 2 then 0.62 else 0.5), CFrame = head * CFrame.new(0, 1.85 + (if i == 2 then 0.08 else 0), z), Color = red }, model)
	end
	Parts.prop({ Name = "HatBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.18, 1.55, 1.55), CFrame = head * CFrame.new(0, 0.95, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = COLORS.dark }, model)
	local hatStar = Parts.prop({ Name = "HatStar", Size = Vector3.new(0.7, 0.7, 0.05), CFrame = head * CFrame.new(0, 1.25, 0.78), Color = hat, Transparency = 1 }, model)
	words(hatStar, "★", GOLD, Enum.Font.FredokaOne)
	local badge = Parts.prop({ Name = "Badge", Size = Vector3.new(0.9, 0.9, 0.05), CFrame = body * CFrame.new(0.5, 0.7, 1.82) * CFrame.Angles(math.rad(-18), 0, 0), Color = white, Transparency = 1 }, model)
	words(badge, "★", GOLD, Enum.Font.FredokaOne)
	model.Parent = parent
	return model
end

-- A floating name, like Barley's.
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

function PoliceArt.build(town: Instance)
	local building = PlotLayout.building("Police")
	local W, H, D = building.size.X, building.size.Y, building.size.Z
	local out = -PlotLayout.direction(building.angle) -- (toward the square)
	local origin = PlotLayout.polar(building.angle, building.radius - D / 2)
	local f = CFrame.fromMatrix(origin, Vector3.yAxis:Cross(out), Vector3.yAxis, out)
	local model = Instance.new("Model")
	model.Name = "PoliceStation"

	-- The body: blue walls with a darker base, a cream cornice and a flat roof
	-- behind a parapet.
	box("Police", f, -W / 2, 0, -D, W / 2, H, 0, BLUE, model)
	deco("BaseBand", f, -W / 2 - 0.1, 0, -D - 0.1, W / 2 + 0.1, 1.6, 0.12, BLUE_DARK, model)
	deco("Cornice", f, -W / 2 - 0.5, H - 0.6, -D - 0.5, W / 2 + 0.5, H, 0.5, CREAM, model)
	deco("StoreyBand", f, -W / 2 - 0.1, 11, -0.1, W / 2 + 0.1, 11.6, 0.25, CREAM, model)
	for _, x in { -W / 2, W / 2 } do
		deco("Corner", f, x - 0.5, 0, -0.5, x + 0.5, H - 0.6, 0.5, CREAM, model)
	end

	-- Upstairs: the cells, barred windows.
	for _, x in { -14, -6, 6, 14 } do
		window(f, x - 2.2, x + 2.2, 13, 16.6, model, true)
	end

	-- The sign across the top and the sheriff's star over the roof line.
	deco("SignFrame", f, -11.4, 17.2, 0, 11.4, 21.6, 0.5, CREAM, model)
	local sign = deco("Sign", f, -11, 17.6, 0.5, 11, 21.2, 0.7, NAVY, model)
	words(sign, "POLICE", CREAM)
	Parts.cylinder("StarBadge", f * CFrame.new(0, H + 2.6, 0.2) * CFrame.Angles(math.rad(90), 0, 0), 7.4, 0.5, { Color = NAVY }, model)
	Parts.cylinder("StarRim", f * CFrame.new(0, H + 2.6, 0.05) * CFrame.Angles(math.rad(90), 0, 0), 8.2, 0.4, { Color = GOLD }, model)
	local star = deco("Star", f, -3.6, H - 1, 0.5, 3.6, H + 6.2, 0.6, NAVY, model, { Transparency = 1 })
	words(star, "★", GOLD)

	-- The ground floor, left to right: the rules poster, the door, the height
	-- chart (where arrested players appear), the desk window.
	local door0, door1 = -12, -6.5
	deco("Door", f, door0, 0.8, -0.1, door1, 8.6, 0.3, NAVY, model)
	deco("DoorSplit", f, (door0 + door1) / 2 - 0.08, 0.8, 0.25, (door0 + door1) / 2 + 0.08, 8.6, 0.4, BLUE_DARK, model)
	for _, x in { door0 + 1.1, door1 - 1.1 } do
		deco("DoorWindow", f, x - 0.8, 5.4, 0.25, x + 0.8, 7.8, 0.4, GLASS, model)
	end
	deco("DoorFrame", f, door0 - 0.5, 8.6, 0, door1 + 0.5, 9.2, 0.4, CREAM, model)
	deco("DoorFrame", f, door0 - 0.5, 0.8, 0, door0, 8.6, 0.4, CREAM, model)
	deco("DoorFrame", f, door1, 0.8, 0, door1 + 0.5, 8.6, 0.4, CREAM, model)
	-- blue police lamps either side of the door
	for _, x in { door0 - 1.4, door1 + 1.4 } do
		deco("LampArm", f, x - 0.12, 7.7, 0, x + 0.12, 7.95, 0.8, COLORS.dark, model)
		deco("Lamp", f, x - 0.4, 7.95, 0.4, x + 0.4, 8.85, 1.2, Color3.fromRGB(40, 110, 240), model, { Material = Enum.Material.Neon })
		deco("LampCap", f, x - 0.52, 8.85, 0.28, x + 0.52, 9.1, 1.32, COLORS.dark, model)
	end

	-- the rules poster on a board, the bench under it
	-- (above the bench's back, which reaches 4.6)
	deco("PosterBoard", f, -18.6, 4.9, 0, -14, 10.5, 0.3, DECK_DARK, model)
	local poster = deco("Poster", f, -18.3, 5.2, 0.3, -14.3, 10.2, 0.4, Color3.fromRGB(246, 232, 196), model)
	words(poster, "WANTED:\ncrop thieves!\n\nBonk them with your bat, then ARREST them.\nTheir fine is yours!", COLORS.dark, Enum.Font.PatrickHand)
	deco("PosterPin", f, -16.45, 9.85, 0.4, -16.15, 10.15, 0.55, COLORS.barnRed, model)

	-- the height chart, right behind the spot arrested players land on
	local chart = deco("HeightChart", f, -4, 0.8, 0.02, 4, 9.6, 0.25, Color3.fromRGB(234, 230, 216), model)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0.5
	gui.Parent = chart
	local rows = 8
	for i = 1, rows do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0, 0.5)
		line.Position = UDim2.fromScale(0, 1 - i / (rows + 0.8))
		line.Size = UDim2.new(1, 0, 0, if i % 2 == 0 then 5 else 3)
		line.BackgroundColor3 = Color3.fromRGB(60, 56, 52)
		line.BorderSizePixel = 0
		line.Parent = gui
		if i % 2 == 0 then
			for _, side in { 0, 1 } do
				local number = Instance.new("TextLabel")
				number.AnchorPoint = Vector2.new(side, 1)
				number.Position = UDim2.new(side, if side == 0 then 6 else -6, 1 - i / (rows + 0.8), -4)
				number.Size = UDim2.fromOffset(40, 30)
				number.BackgroundTransparency = 1
				number.Font = Enum.Font.FredokaOne
				number.TextSize = 28
				number.TextColor3 = Color3.fromRGB(60, 56, 52)
				number.TextXAlignment = if side == 0 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
				number.Text = tostring(i)
				number.Parent = gui
			end
		end
	end
	deco("ChartFrame", f, -4.3, 9.6, 0, 4.3, 10, 0.3, CREAM, model)

	-- the desk window, and the desk on the porch with Sheriff Clucks behind it
	window(f, 8.5, 16.5, 3.4, 8.2, model, false)
	box("PoliceDesk", f, 8.6, 0.8, 3.7, 16.4, 4.2, 5.9, DECK_DARK, model)
	deco("DeskTop", f, 8.3, 4.2, 3.4, 16.7, 4.6, 6.3, DECK, model)
	local plate = deco("DeskSign", f, 10, 1.6, 5.9, 15, 3.6, 6.0, NAVY, model)
	words(plate, "POLICE DESK\npay debts here", CREAM)
	Parts.ball("Bell", f * CFrame.new(15.6, 4.85, 4.9), 0.5, { Color = GOLD }, model)
	local clucks = sheriff(f * CFrame.new(12.5, 0.8, 1.5), model)
	nameTag("Sheriff Clucks", clucks.Head, 3.4)

	-- The porch: a deck along the front with a step, posts and a roof.
	box("PolicePorch", f, -W / 2, 0, 0, W / 2, 0.8, 12, DECK, model)
	box("PorchStep", f, -8, 0, 12, 8, 0.6, 13.6, DECK_DARK, model) -- (above the plaza's top at 0.4: never level with it)
	for x = -W / 2 + 1.5, W / 2 - 1.5, 3 do
		deco("Board", f, x - 0.04, 0.8, 0, x + 0.04, 0.84, 12, DECK_DARK, model)
	end
	for _, x in { -W / 2 + 0.6, -5.4, 5.4, W / 2 - 0.6 } do
		box("PorchPost", f, x - 0.4, 0.8, 11, x + 0.4, 10.6, 11.8, CREAM, model)
	end
	deco("PorchBeam", f, -W / 2, 10.2, 10.9, W / 2, 10.9, 11.9, CREAM, model)
	-- the roof: blue and cream stripes like an awning, with a striped flap
	-- hanging along its front (from the square the roof itself is seen
	-- edge-on: the flap is what shows), a cream trim along its top
	local roofFrame = f * CFrame.new(0, 11.4, 6.2) * CFrame.Angles(math.rad(6), 0, 0)
	local strips = 12
	local stripWidth = (W + 0.8) / strips
	local edge = roofFrame * CFrame.new(0, 0, 6.5) -- (the roof's front edge, in the middle)
	for i = 0, strips - 1 do
		local x = -(W + 0.8) / 2 + stripWidth * (i + 0.5)
		local color = if i % 2 == 0 then BLUE else CREAM
		Parts.prop({ Name = "PorchRoof", Size = Vector3.new(stripWidth, 0.5, 13), CFrame = roofFrame * CFrame.new(x, 0, 0), Color = color }, model)
		Parts.prop({ Name = "Valance", Size = Vector3.new(stripWidth, 1.4, 0.2), CFrame = f * CFrame.new(x, edge.Position.Y - f.Position.Y - 0.6, 12.85), Color = color }, model)
	end
	Parts.prop({ Name = "ValanceTrim", Size = Vector3.new(W + 1, 0.3, 0.32), CFrame = f * CFrame.new(0, edge.Position.Y - f.Position.Y + 0.15, 12.85), Color = CREAM }, model)

	-- the bench under the poster
	deco("BenchSeat", f, -18.6, 2.6, 1, -13.6, 3, 2.8, DECK_DARK, model)
	deco("BenchBack", f, -18.6, 3, 0.4, -13.6, 4.6, 0.8, DECK_DARK, model)
	for _, x in { -18.2, -14 } do
		deco("BenchLeg", f, x - 0.2, 0.8, 1.2, x + 0.2, 2.6, 2.6, DECK_DARK, model)
	end

	model.Parent = town
	return model
end

return PoliceArt
