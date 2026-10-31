-- How a farm's selling side looks at tier 0 (docs/ArtDirection.md §7): the
-- Packing Shed with its bench, the dock and dispatch lever, the pickup
-- truck and the striped truck gate, and the Farm Stand in the front fence.
-- WorldBuilder builds them empty; WarehouseService, TruckService and
-- ShopService call the rest to show crates, the bed, the shelves and their
-- price tags. Positions come from shared/PlotLayout.PLOT.
--
-- The pickup is a Model named "Truck" whose pivot is its parked spot (on
-- the ground, nose to the road). Clients drive it to the City and back from
-- its DepartAt / ArriveAt / ReturnAt attributes (TruckController); the
-- server never moves it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crops = require(ReplicatedStorage.Shared.Config.Crops)
local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
local Parts = require(script.Parent.Parts)
local FarmArt = require(script.Parent.FarmArt)

local COLORS = Parts.COLORS
local part, prop, plotBox, cylinder, ball = Parts.part, Parts.prop, Parts.plotBox, Parts.cylinder, Parts.ball

local YardArt = {}

local P = PlotLayout.PLOT
local CRATE = Vector3.new(3.2, 1.8, 3.2)
local WICKER = Color3.fromRGB(196, 150, 84)
local GLASS = Color3.fromRGB(170, 214, 236)
local TYRE = Color3.fromRGB(46, 42, 40)

-- A painted board with words on its front (the face toward -Z of `cframe`).
local function sign(name: string, text: string, cframe: CFrame, size: Vector3, parent: Instance, board: Color3?, ink: Color3?)
	local plank = part({ Name = name, Size = size, CFrame = cframe, Color = board or COLORS.cream }, parent)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.5
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = ink or Color3.fromRGB(74, 50, 32)
	label.Text = text
	label.Parent = gui
	gui.Parent = plank
	return plank
end

------------------------------------------------------------------------
-- Crates

-- A packed crate: slatted wood, the produce heaped on top in the crop's
-- colour, and a gold "A" sticker for grade A. Built at `cframe` (its base).
function YardArt.crate(crate, cframe: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Crate"
	local box = prop({ Name = "Box", Size = CRATE, CFrame = cframe * CFrame.new(0, CRATE.Y / 2, 0), Color = COLORS.edging }, model)
	for _, y in { 0.45, 1.35 } do
		prop({ Name = "Slat", Size = Vector3.new(CRATE.X + 0.1, 0.18, CRATE.Z + 0.1), CFrame = cframe * CFrame.new(0, y, 0), Color = COLORS.post }, model)
	end
	local color = FarmArt.cropColor(crate.crop)
	for i, offset in { Vector3.new(-0.7, 0, -0.6), Vector3.new(0.7, 0, -0.5), Vector3.new(0, 0, 0.7), Vector3.new(0, 0.5, 0) } do
		if i <= math.ceil(crate.units / 3) then -- (an empty crate has none)
			ball("Produce", cframe * CFrame.new(offset + Vector3.new(0, CRATE.Y + 0.15, 0)), 1.2, { Color = color }, model)
		end
	end
	if crate.grade == "A" then
		prop({ Name = "GradeA", Size = Vector3.new(1, 1, 0.1), CFrame = cframe * CFrame.new(0, 0.9, -CRATE.Z / 2 - 0.06), Color = COLORS.hay, Material = Enum.Material.Neon }, model)
	end
	model.PrimaryPart = box
	model.Parent = parent
	return model
end

-- Puts a crate in a character's arms (welded in front of their chest), or
-- takes it away (crate = nil).
function YardArt.carry(character: Model, crate)
	local old = character:FindFirstChild("CarriedCrate")
	if old then
		old:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not crate or not root then
		return
	end
	local model = YardArt.crate(crate, root.CFrame * CFrame.new(0, -0.6, -2.1), character)
	model.Name = "CarriedCrate"
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			child.Anchored = false
			child.Massless = true
			child.CanCollide = false
			child.CanQuery = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = child
			weld.Parent = child
		end
	end
end

------------------------------------------------------------------------
-- The Packing Shed, the dock, the warehouse site

local function buildShed(model: Model, frame: CFrame)
	local shed = Instance.new("Model")
	shed.Name = "PackingShed"
	shed.Parent = model
	local s = P.shed
	-- The warehouse site behind it: gravel waiting for the warehouse (T1).
	local site = P.warehouse
	plotBox("WarehouseSite", frame, site.min, Vector3.new(site.max.X, 0.3, site.max.Z), { Color = Color3.fromRGB(184, 174, 156) }, model)
	local siteSign = sign("SiteSign", "Distribution Warehouse\nFarm Level 5", frame * CFrame.new(60, 4.5, 82), Vector3.new(12, 4, 0.4), model)
	for _, x in { -5, 5 } do
		prop({ Name = "SignPost", Size = Vector3.new(0.6, 4.5, 0.6), CFrame = siteSign.CFrame * CFrame.new(x, -2.2, 0.4), Color = COLORS.post }, model)
	end

	plotBox("Floor", frame, Vector3.new(s.min.X, 0.3, s.min.Z), Vector3.new(s.max.X, 0.5, s.max.Z), { Color = COLORS.edging }, shed)
	for _, x in { s.min.X + 0.5, (s.min.X + s.max.X) / 2, s.max.X - 0.5 } do
		for _, z in { s.min.Z + 0.5, s.max.Z - 0.5 } do
			plotBox("Post", frame, Vector3.new(x - 0.5, 0.5, z - 0.5), Vector3.new(x + 0.5, 11, z + 0.5), { Color = COLORS.post }, shed)
		end
	end
	plotBox("BackWall", frame, Vector3.new(s.min.X, 0.5, s.max.Z - 1), Vector3.new(s.max.X, 10.5, s.max.Z), { Color = COLORS.cream }, shed)
	-- A gable roof in barn red, the ridge running across.
	local ridgeZ = (s.min.Z + s.max.Z) / 2
	local half = (s.max.Z - s.min.Z) / 2 + 1
	local rise = 3.5
	local slope = math.atan(rise / half)
	local length = math.sqrt(half * half + rise * rise)
	for _, side in { -1, 1 } do
		part({
			Name = "Roof", Size = Vector3.new(s.max.X - s.min.X + 2, 0.8, length),
			CFrame = frame * CFrame.new((s.min.X + s.max.X) / 2, 11 + rise / 2, ridgeZ + side * half / 2) * CFrame.Angles(side * slope, 0, 0),
			Color = COLORS.barnRed,
		}, shed)
	end
	sign("ShedSign", "PACKING SHED", frame * CFrame.new((s.min.X + s.max.X) / 2, 9.6, s.min.Z - 0.3), Vector3.new(16, 2.2, 0.4), shed)

	-- The bench: a wash tub at one end, a crate in the middle, tape at the other.
	local b = P.bench
	local top = part({ Name = "Bench", Size = Vector3.new(10, 0.6, 4), CFrame = frame * CFrame.new(b + Vector3.new(0, 3.5, 0)), Color = COLORS.stumpTop }, shed)
	for _, x in { -4.4, 4.4 } do
		for _, z in { -1.6, 1.6 } do
			prop({ Name = "Leg", Size = Vector3.new(0.5, 3, 0.5), CFrame = top.CFrame * CFrame.new(x, -1.8, z), Color = COLORS.post }, shed)
		end
	end
	prop({ Name = "Tub", Size = Vector3.new(3, 1.2, 3), CFrame = top.CFrame * CFrame.new(-3.2, 0.9, 0), Color = COLORS.metal }, shed)
	prop({ Name = "Water", Size = Vector3.new(2.6, 0.1, 2.6), CFrame = top.CFrame * CFrame.new(-3.2, 1.4, 0), Color = COLORS.water, Transparency = 0.2 }, shed)
	YardArt.crate({ crop = "Carrot", units = 0, grade = "B" }, top.CFrame * CFrame.new(0.4, 0.3, 0), shed).Name = "EmptyCrate"
	cylinder("Tape", top.CFrame * CFrame.new(3.6, 0.55, 0), 1, 0.5, { Color = Color3.fromRGB(210, 160, 90) }, shed)
	-- Empty crates stacked by the back wall, a hose reel.
	for i = 0, 2 do
		YardArt.crate({ crop = "Carrot", units = 0, grade = "B" }, frame * CFrame.new(s.min.X + 3, 0.5 + i * CRATE.Y, s.max.Z - 3.5) * CFrame.Angles(0, math.rad(i * 9), 0), shed)
	end
	cylinder("HoseReel", frame * CFrame.new(s.max.X - 3, 2, s.max.Z - 2) * CFrame.Angles(0, 0, math.rad(90)), 3, 1, { Color = COLORS.leaf }, shed)

	-- The dock: a low platform at the top of the driveway, the lever, the
	-- spot crates are loaded from, and where dropped crates wait.
	local d = P.dock
	plotBox("Dock", frame, d.min, d.max, { Color = COLORS.edging }, model)
	plotBox("DockBumper", frame, Vector3.new(d.min.X, 0.1, d.min.Z - 0.4), Vector3.new(d.max.X, 0.7, d.min.Z), { Color = COLORS.dark }, model)
	local load = prop({
		Name = "LoadSpot", Size = Vector3.new(12, 3, 1.5), CFrame = frame * CFrame.new(P.truck.X, d.max.Y + 1.5, d.min.Z + 1),
		Transparency = 1, CanQuery = false,
	}, model)
	load:SetAttribute("Dock", true)
	local leverAt = frame * CFrame.new(P.lever + Vector3.new(0, d.max.Y, 0))
	prop({ Name = "LeverBase", Size = Vector3.new(1.2, 2.6, 1.2), CFrame = leverAt * CFrame.new(0, 1.3, 0), Color = COLORS.slate }, model)
	local handle = prop({ Name = "Lever", Size = Vector3.new(0.3, 2.4, 0.3), CFrame = leverAt * CFrame.new(0, 3.3, 0) * CFrame.Angles(math.rad(-25), 0, 0), Color = COLORS.post }, model)
	ball("Knob", handle.CFrame * CFrame.new(0, 1.3, 0), 0.8, { Color = COLORS.barnRed }, model)
	local pile = Instance.new("Folder")
	pile.Name = "DockPile"
	pile.Parent = model
end

-- Shows `count` crates waiting at the dock (dropped on the way to the truck).
function YardArt.showDockPile(model: Model, crates)
	local pile = model:FindFirstChild("DockPile")
	if not pile then
		return
	end
	pile:ClearAllChildren()
	local frame = PlotLayout.frame(model:GetAttribute("PlotIndex"))
	for i, crate in crates do
		if i > 6 then
			break
		end
		local column, layer = (i - 1) % 2, (i - 1) // 2
		YardArt.crate(crate, frame * CFrame.new(P.dockPile + Vector3.new(column * 3.4 - 1.7, P.dock.max.Y + layer * CRATE.Y, 0)), pile)
	end
end

------------------------------------------------------------------------
-- The pickup and the truck gate

local function buildTruck(model: Model, frame: CFrame)
	local truck = Instance.new("Model")
	truck.Name = "Truck"
	local base = frame * CFrame.new(P.truck + Vector3.new(0, 0.35, 0)) -- on the driveway, nose toward the road (−Z)
	local function box(name, centre: Vector3, size: Vector3, color: Color3, extra)
		local props = { Name = name, Size = size, CFrame = base * CFrame.new(centre), Color = color }
		for key, value in extra or {} do
			props[key] = value
		end
		return prop(props, truck)
	end
	for _, x in { -3.9, 3.9 } do
		for _, z in { -6.5, 6 } do
			local wheel = prop({
				Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 3.2, 3.2),
				CFrame = base * CFrame.new(x, 1.6, z), Color = TYRE,
			}, truck)
			prop({ Name = "Hub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 1.4, 1.4), CFrame = wheel.CFrame, Color = COLORS.metal }, truck)
		end
	end
	box("Chassis", Vector3.new(0, 2.2, 0), Vector3.new(8.2, 1, 20), COLORS.dark)
	box("Hood", Vector3.new(0, 3.6, -7.7), Vector3.new(8.4, 2, 4.6), COLORS.barnRed)
	box("Cab", Vector3.new(0, 4.9, -3.4), Vector3.new(8.4, 4.6, 4.2), COLORS.barnRed)
	box("Windshield", Vector3.new(0, 5.6, -5.55), Vector3.new(7.4, 2.4, 0.15), GLASS, { Reflectance = 0.2 })
	for _, x in { -4.25, 4.25 } do
		box("Window", Vector3.new(x, 5.6, -3.4), Vector3.new(0.15, 2.2, 3), GLASS, { Reflectance = 0.2 })
	end
	box("Roof", Vector3.new(0, 7.3, -3.4), Vector3.new(8.6, 0.3, 4.4), COLORS.cream)
	box("Grille", Vector3.new(0, 3.4, -10.05), Vector3.new(5, 1.4, 0.15), COLORS.slate)
	for _, x in { -3.2, 3.2 } do
		box("Headlight", Vector3.new(x, 3.6, -10.05), Vector3.new(1.2, 0.8, 0.15), Color3.fromRGB(255, 240, 200), { Material = Enum.Material.Neon })
		box("Taillight", Vector3.new(x, 3.4, 10.05), Vector3.new(0.8, 0.6, 0.15), COLORS.barnRed, { Material = Enum.Material.Neon })
	end
	box("BedFloor", Vector3.new(0, 2.85, 4.2), Vector3.new(8.2, 0.3, 11.6), COLORS.edging)
	for _, x in { -3.95, 3.95 } do
		box("BedSide", Vector3.new(x, 3.9, 4.2), Vector3.new(0.4, 1.8, 11.6), COLORS.barnRed)
	end
	box("BedFront", Vector3.new(0, 3.9, -1.4), Vector3.new(8.2, 1.8, 0.4), COLORS.barnRed)
	box("Tailgate", Vector3.new(0, 3.9, 9.8), Vector3.new(8.2, 1.8, 0.4), COLORS.cream)
	local bed = Instance.new("Folder")
	bed.Name = "Bed"
	bed.Parent = truck
	truck.WorldPivot = base
	truck.Parent = model
	return truck
end

-- Lays the bed's crates in rows of two.
function YardArt.showBed(truck: Model, crates)
	local bed = truck:FindFirstChild("Bed")
	bed:ClearAllChildren()
	local base = truck:GetPivot()
	for i, crate in crates do
		local column, row = (i - 1) % 2, (i - 1) // 2
		YardArt.crate(crate, base * CFrame.new(column * 3.6 - 1.8, 3, 7.6 - row * 3.6), bed)
	end
end

-- The striped boom across the driveway at the front fence: only trucks pass
-- (the client lifts the boom for them; an invisible wall stays for people).
local function buildTruckGate(model: Model, frame: CFrame)
	local gate = Instance.new("Model")
	gate.Name = "TruckGate"
	local left, right = P.driveway.min.X, P.driveway.max.X
	for _, x in { left, right } do
		plotBox("GatePost", frame, Vector3.new(x - 0.6, 0, -1.1), Vector3.new(x + 0.6, 4.6, 0.1), { Color = COLORS.post }, gate)
	end
	local boom = Instance.new("Model")
	boom.Name = "Boom"
	local width = right - left - 1
	local segments = 6
	for i = 0, segments - 1 do
		prop({
			Name = "Stripe", Size = Vector3.new(width / segments, 0.6, 0.6),
			CFrame = frame * CFrame.new(left + 0.6 + (i + 0.5) * width / segments, 3.6, -0.5),
			Color = if i % 2 == 0 then COLORS.barnRed else COLORS.cream,
		}, boom)
	end
	boom.WorldPivot = frame * CFrame.new(left + 0.6, 3.6, -0.5) -- the hinge
	boom.Parent = gate
	gate.Parent = model
	plotBox("TruckGateBlocker", frame, Vector3.new(left, 0, -1), Vector3.new(right, PlotLayout.FENCE_BLOCK, 0),
		{ Transparency = 1, CanQuery = false, CanTouch = false }, model)
end

------------------------------------------------------------------------
-- The Farm Stand

local function buildStand(model: Model, frame: CFrame)
	local stand = Instance.new("Model")
	stand.Name = "FarmStand"
	stand.Parent = model
	local x0 = P.stand.across - P.stand.width / 2
	local x1 = P.stand.across + P.stand.width / 2
	plotBox("Counter", frame, Vector3.new(x0, 0, -0.5), Vector3.new(x1, 3.5, 3.5), { Color = COLORS.edging }, stand)
	plotBox("CounterTop", frame, Vector3.new(x0 - 0.4, 3.5, -1), Vector3.new(x1 + 0.4, 3.9, 4), { Color = COLORS.post }, stand)
	for _, x in { x0 + 0.4, x1 - 0.4 } do
		plotBox("Post", frame, Vector3.new(x - 0.4, 3.9, 3), Vector3.new(x + 0.4, 10.4, 3.8), { Color = COLORS.post }, stand)
	end
	-- A striped awning sloping toward the road.
	local stripes = 6
	for i = 0, stripes - 1 do
		local x = x0 - 0.6 + (i + 0.5) * (P.stand.width + 1.2) / stripes
		part({
			Name = "Awning", Size = Vector3.new((P.stand.width + 1.2) / stripes, 0.3, 6.4),
			CFrame = frame * CFrame.new(x, 9.6, 0.9) * CFrame.Angles(math.rad(-14), 0, 0),
			Color = if i % 2 == 0 then COLORS.barnRed else COLORS.cream,
		}, stand)
	end
	sign("StandSign", "FARM STAND", frame * CFrame.new(P.stand.across, 11.7, 3.4), Vector3.new(12, 2.4, 0.4), stand)
	-- Two baskets (the shelves) and the honour box between them.
	for i, x in { P.stand.across - 5.5, P.stand.across + 5.5 } do
		local basket = part({ Name = `Shelf{i}`, Size = Vector3.new(6, 1.4, 3.2), CFrame = frame * CFrame.new(x, 4.6, 1.5), Color = WICKER }, stand)
		basket:SetAttribute("Shelf", tostring(i))
		local gui = Instance.new("BillboardGui")
		gui.Name = "PriceTag"
		gui.Size = UDim2.fromScale(5, 1.6)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 70
		gui.Adornee = basket
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = COLORS.cream
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(58, 42, 28)
		label.Text = "Empty"
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = label
		label.Parent = gui
		gui.Parent = basket
		local produce = Instance.new("Folder")
		produce.Name = "Produce"
		produce.Parent = basket
	end
	local box = part({ Name = "HonourBox", Size = Vector3.new(2.4, 2, 2), CFrame = frame * CFrame.new(P.stand.across, 4.9, 1.8), Color = COLORS.hay }, stand)
	prop({ Name = "Slot", Size = Vector3.new(1.2, 0.1, 0.3), CFrame = box.CFrame * CFrame.new(0, 1.02, 0), Color = COLORS.dark }, stand)
	-- Nobody climbs over the counter into the yard.
	plotBox("StandBlocker", frame, Vector3.new(x0, 0, -0.5), Vector3.new(x1, PlotLayout.FENCE_BLOCK, 3.5),
		{ Transparency = 1, CanQuery = false, CanTouch = false }, model)
end

-- Fills a shelf's basket in its crop's colour (fuller with more units) and
-- writes its price tag ("🥕 24"), or empties it.
function YardArt.showShelf(model: Model, key: string, shelf, price: number?)
	local stand = model:FindFirstChild("FarmStand")
	local basket = stand and stand:FindFirstChild(`Shelf{key}`)
	if not basket then
		return
	end
	basket.Produce:ClearAllChildren()
	local label = basket.PriceTag.Text
	if not shelf or shelf.units <= 0 then
		label.Text = "Empty"
		return
	end
	local crop = Crops.ById[shelf.crop]
	label.Text = `{crop.icon or ""} {price or "?"}`
	local balls = math.clamp(math.ceil(shelf.units / 3), 1, 7)
	for i = 1, balls do
		local x = ((i - 1) % 4 - 1.5) * 1.3
		local z = if (i - 1) // 4 == 0 then -0.5 else 0.6
		ball("Produce", basket.CFrame * CFrame.new(x, 0.9, z), 1.3, { Color = FarmArt.cropColor(shelf.crop) }, basket.Produce)
	end
end

------------------------------------------------------------------------

-- Builds the tier-0 selling side of a farm.
function YardArt.build(model: Model, frame: CFrame)
	buildShed(model, frame)
	buildTruck(model, frame)
	buildTruckGate(model, frame)
	buildStand(model, frame)
end

return YardArt
