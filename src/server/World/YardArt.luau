-- How a farm's warehouse side looks (docs/ArtDirection.md §7, §11 step 10):
-- the building for its Warehouse Level (the Packing Shed with its bench, then
-- the Distribution Warehouse, the Big Warehouse and the Distribution Center,
-- each with its stations on a conveyor, a Cold Room and a wash table), the
-- docks with a lever per truck, the trucks (a pickup, a box truck, semis,
-- reefers) in the farm's colour, and a striped truck gate per lane. (Your
-- store is World/StoreArt.) WorldBuilder builds every farm at Level 1;
-- WarehouseService rebuilds it as the owner's level changes, and it and
-- TruckService call the rest to show crates. Positions: shared/PlotLayout.
--
-- Everything for a level is in the plot's "Warehouse" model:
--   Building     the shed or warehouse (Stage attribute); a warehouse has an
--                invisible "Interior" box beside its "Roof" model, so the
--                roof fades while you're inside (RoofController)
--   Bench        where you wash and pack by hand (WarehouseService's prompt)
--   Docks        the platform, LoadSpot<n> and LeverBase<n> for each truck
--   Rack         crates waiting for a truck: on the dock at the Packing
--                Shed, in the Cold Room after that
--   Stations     the warehouses' Intake, Sort, Pack and Load spots (where
--                workers stand, WorkerService)
--   Lanes        a paved lane per dock, its truck gate (Gate<n> with a Boom)
--                and the front fence on this side
--   Trucks       Truck<n>: pivot = its parked middle, nose to the road;
--                clients drive it to the City and back from its DepartAt /
--                ArriveAt / ReturnAt attributes (TruckController)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local PlotLayout = require(Shared.PlotLayout)
local Warehouse = require(Shared.Config.Warehouse)
local WarehouseRules = require(Shared.WarehouseRules)
local Parts = require(script.Parent.Parts)
local FarmArt = require(script.Parent.FarmArt)

local COLORS = Parts.COLORS
local part, prop, plotBox, cylinder, ball = Parts.part, Parts.prop, Parts.plotBox, Parts.cylinder, Parts.ball

local YardArt = {}

local P = PlotLayout.PLOT
local CRATE = Vector3.new(3.2, 1.8, 3.2)
local GLASS = Color3.fromRGB(170, 214, 236)
local TYRE = Color3.fromRGB(46, 42, 40)
local CONCRETE = Color3.fromRGB(184, 176, 164)
local LINING = Color3.fromRGB(204, 178, 136) -- warm boards inside (never cool: with the roof faded the room is lit by the open sky)
local BELT = Color3.fromRGB(54, 52, 52)
local STEEL = Color3.fromRGB(150, 156, 160)
local FROST = Color3.fromRGB(218, 234, 242)
local GOLD = Color3.fromRGB(232, 190, 80)
local GLOW = Color3.fromRGB(255, 244, 214)
local BAND = Color3.fromRGB(112, 122, 134) -- the warehouses' base band
local FLOOR = P.dock.height -- the warehouses' floor is level with the docks
local MAX_LIGHTS = 4
local SHOW_BED = 8 -- crates drawn in a closed truck (it holds up to 40: the back rows show through its open door)
local SHOW_HOLD = 24 -- crates drawn in the Cold Room (a sign says how many)

-- Each truck's length (studs, nose to tail) and its bed: where the first
-- crate sits (from the middle), how wide a row is.
YardArt.TRUCK_LENGTH = { Pickup = 20, BoxTruck = 26, Semi = 36, Reefer = 36 }

-- A painted board with words on its front (the face toward -Z of `cframe`).
local function sign(name: string, text: string, cframe: CFrame, size: Vector3, parent: Instance, board: Color3?, ink: Color3?)
	local plank = part({ Name = name, Size = size, CFrame = cframe, Color = board or COLORS.cream }, parent)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.5
	local label = Instance.new("TextLabel")
	label.Name = "Words"
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

local function pointLight(lamp: BasePart, range: number)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 236, 200)
	light.Range = range
	light.Brightness = 0.45
	light.Shadows = false
	light.Parent = lamp
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

local function warehouseModel(model: Model): Model
	return model:FindFirstChild("Warehouse") :: Model
end

local function frameOf(model: Model): CFrame
	return PlotLayout.frame(model:GetAttribute("PlotIndex") or 1)
end

-- Shows the crates waiting for a truck: on the dock rack at the Packing
-- Shed (up to 12), in stacks in the Cold Room after that, with a sign.
function YardArt.showHold(model: Model, crates)
	local warehouse = warehouseModel(model)
	local rack = warehouse and warehouse:FindFirstChild("Rack")
	if not rack then
		return
	end
	rack:ClearAllChildren()
	local frame = frameOf(model)
	local stage = warehouse:GetAttribute("Stage") or 1
	if stage == 1 then
		local at = PlotLayout.rackLocal()
		for i, crate in crates do
			if i > 12 then
				break
			end
			local spot = (i - 1) % 4
			local layer = (i - 1) // 4
			local offset = Vector3.new((spot % 2) * 3.4 - 1.7, P.dock.height + layer * CRATE.Y, (spot // 2) * -3.4 + 1.2)
			YardArt.crate(crate, frame * CFrame.new(at + offset), rack)
		end
		return
	end
	local room = PlotLayout.WAREHOUSES[stage].coldRoom
	local columns = math.max(1, math.floor((room.max.X - room.min.X - 2) / 3.6))
	for i, crate in crates do
		if i > SHOW_HOLD then
			break
		end
		local stack = (i - 1) // 3
		local layer = (i - 1) % 3
		local x = room.min.X + 2.6 + (stack % columns) * 3.6
		local z = room.max.Z - 2.6 - (stack // columns) * 3.6
		YardArt.crate(crate, frame * CFrame.new(x, FLOOR + layer * CRATE.Y, z), rack)
	end
	local count = warehouse:FindFirstChild("ColdRoomCount", true)
	local words = count and count:FindFirstChild("Words", true) -- (the label in the sign's SurfaceGui)
	if words then
		words.Text = `{#crates} / {WarehouseRules.level(warehouse:GetAttribute("Level") or 1).hold}`
	end
end

------------------------------------------------------------------------
-- The trucks

-- A wheel pair across an axle at z (dual: the wider rear wheels of a big truck).
local function axle(truck: Model, base: CFrame, z: number, half: number, size: number, dual: boolean?)
	for _, side in { -1, 1 } do
		local wheel = prop({
			Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(if dual then 2.2 else 1.4, size, size),
			CFrame = base * CFrame.new(side * half, size / 2, z), Color = TYRE,
		}, truck)
		prop({ Name = "Hub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(wheel.Size.X + 0.1, size * 0.42, size * 0.42), CFrame = wheel.CFrame, Color = COLORS.metal }, truck)
	end
end

-- A big truck's cab (box trucks, semis): hood, cab, windscreen and side
-- windows, grille, lights and a bumper, from z0 (its nose) back.
local function cab(truck: Model, base: CFrame, z0: number, hood: number, depth: number, height: number, paint: Color3, sleeper: boolean?)
	local function box(name, centre: Vector3, size: Vector3, color: Color3, extra)
		local props = { Name = name, Size = size, CFrame = base * CFrame.new(centre), Color = color }
		for key, value in extra or {} do
			props[key] = value
		end
		return prop(props, truck)
	end
	box("Bumper", Vector3.new(0, 2.6, z0 + 0.3), Vector3.new(8.8, 1, 0.6), COLORS.metal, { Reflectance = 0.2 })
	box("Hood", Vector3.new(0, 4, z0 + 0.6 + hood / 2), Vector3.new(8.4, 3, hood), paint)
	box("Grille", Vector3.new(0, 4.2, z0 + 0.55), Vector3.new(4.6, 2.4, 0.15), COLORS.metal, { Reflectance = 0.2 })
	for _, x in { -3.3, 3.3 } do
		box("Headlight", Vector3.new(x, 4, z0 + 0.55), Vector3.new(1.2, 0.8, 0.15), Color3.fromRGB(255, 240, 200), { Material = Enum.Material.Neon })
	end
	local c0 = z0 + 0.6 + hood
	box("Cab", Vector3.new(0, 2.5 + height / 2, c0 + depth / 2), Vector3.new(8.6, height, depth), paint)
	box("Windshield", Vector3.new(0, 2.5 + height - 2, c0 - 0.05), Vector3.new(7.6, 2.6, 0.15), GLASS, { Reflectance = 0.2 })
	for _, x in { -4.35, 4.35 } do
		box("Window", Vector3.new(x, 2.5 + height - 2, c0 + 1.6), Vector3.new(0.15, 2.4, 2.6), GLASS, { Reflectance = 0.2 })
		box("Mirror", Vector3.new(x * 1.12, 2.5 + height - 2.4, c0 + 0.3), Vector3.new(0.3, 1.4, 0.3), COLORS.dark)
		box("Step", Vector3.new(x * 0.98, 1.6, c0 + 1.8), Vector3.new(0.6, 0.3, 1.6), COLORS.metal)
	end
	box("CabTop", Vector3.new(0, 2.5 + height + 0.15, c0 + depth / 2), Vector3.new(8.8, 0.3, depth + 0.2), COLORS.cream)
	if sleeper then
		box("Spoiler", Vector3.new(0, 2.5 + height + 1, c0 + depth - 1.4), Vector3.new(8.2, 1.6, 2.6), paint)
		for _, x in { -3.9, 3.9 } do
			cylinder("Exhaust", base * CFrame.new(x, 2.5 + height / 2 + 1.5, c0 + depth + 0.4), 0.6, height + 3, { Color = COLORS.metal, Reflectance = 0.25 }, truck)
			prop({ Name = "FuelTank", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 1.6, 1.6),
				CFrame = base * CFrame.new(x * 1.02, 2.2, c0 + depth / 2) * CFrame.Angles(0, math.rad(90), 0), Color = COLORS.metal, Reflectance = 0.2 }, truck)
		end
	end
	return c0 + depth
end

-- A closed box (a box truck's body, a trailer) from z0 to z1 with its
-- roller door rolled up at the back, a band of the farm's colour, and the
-- farm's words on both sides.
local function body(truck: Model, base: CFrame, z0: number, z1: number, floor: number, height: number, skin: Color3, band: Color3, words: string)
	local length = z1 - z0
	local mid = (z0 + z1) / 2
	local function box(name, centre: Vector3, size: Vector3, color: Color3, extra)
		local props = { Name = name, Size = size, CFrame = base * CFrame.new(centre), Color = color }
		for key, value in extra or {} do
			props[key] = value
		end
		return prop(props, truck)
	end
	box("BedFloor", Vector3.new(0, floor - 0.2, mid), Vector3.new(8.8, 0.4, length), COLORS.edging)
	for _, x in { -4.3, 4.3 } do
		box("BoxSide", Vector3.new(x, floor + height / 2, mid), Vector3.new(0.3, height, length), skin)
		box("Band", Vector3.new(x * 1.01, floor + height * 0.72, mid), Vector3.new(0.12, 1.2, length - 1), band)
		box("Skirt", Vector3.new(x * 0.98, floor - 0.9, mid), Vector3.new(0.2, 1.2, length - 4), band)
	end
	box("BoxFront", Vector3.new(0, floor + height / 2, z0 + 0.15), Vector3.new(8.8, height, 0.3), skin)
	box("BoxRoof", Vector3.new(0, floor + height + 0.1, mid), Vector3.new(8.9, 0.2, length + 0.1), skin)
	box("DoorRoll", Vector3.new(0, floor + height - 0.6, z1 - 0.5), Vector3.new(8.2, 1, 1), band)
	for _, x in { -4.3, 4.3 } do
		box("DoorFrame", Vector3.new(x, floor + height / 2, z1), Vector3.new(0.5, height, 0.4), COLORS.metal)
		box("Taillight", Vector3.new(x, floor - 0.6, z1 + 0.05), Vector3.new(0.6, 0.6, 0.15), COLORS.barnRed, { Material = Enum.Material.Neon })
	end
	box("RearBumper", Vector3.new(0, floor - 1, z1), Vector3.new(8, 0.5, 0.4), COLORS.dark)
	for _, side in { -1, 1 } do
		local face = sign("Words", words, base * CFrame.new(side * 4.47, floor + height * 0.42, mid) * CFrame.Angles(0, math.rad(90 * side), 0),
			Vector3.new(math.min(length - 4, 16), 2.6, 0.05), truck, skin, band)
		face.CanCollide = false
		face.CanTouch = false
	end
end

-- Builds a truck model of a kind (Config/Warehouse.BUILDINGS truck) in the
-- farm's colour, parked at `parked` (its middle on the ground, nose -Z).
local function buildTruck(kind: string, paint: Color3, parked: CFrame, name: string, parent: Instance): Model
	local truck = Instance.new("Model")
	truck.Name = name
	-- (always whole on every client: clients drive it round the valley, and a
	-- part streaming in late would land at the parked spot, out of step)
	truck.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	truck:SetAttribute("Kind", kind)
	truck:SetAttribute("Length", YardArt.TRUCK_LENGTH[kind])
	local base = parked * CFrame.new(0, 0.35, 0)
	local half = YardArt.TRUCK_LENGTH[kind] / 2
	local bed = Instance.new("Folder")
	bed.Name = "Bed"
	if kind == "Pickup" then
		local function box(name, centre: Vector3, size: Vector3, color: Color3, extra)
			local props = { Name = name, Size = size, CFrame = base * CFrame.new(centre), Color = color }
			for key, value in extra or {} do
				props[key] = value
			end
			return prop(props, truck)
		end
		for _, z in { -6.5, 6 } do
			axle(truck, base, z, 3.9, 3.2)
		end
		box("Chassis", Vector3.new(0, 2.2, 0), Vector3.new(8.2, 1, 20), COLORS.dark)
		box("Hood", Vector3.new(0, 3.6, -7.7), Vector3.new(8.4, 2, 4.6), paint)
		box("Cab", Vector3.new(0, 4.9, -3.4), Vector3.new(8.4, 4.6, 4.2), paint)
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
			box("BedSide", Vector3.new(x, 3.9, 4.2), Vector3.new(0.4, 1.8, 11.6), paint)
		end
		box("BedFront", Vector3.new(0, 3.9, -1.4), Vector3.new(8.2, 1.8, 0.4), paint)
		box("Tailgate", Vector3.new(0, 3.9, 9.8), Vector3.new(8.2, 1.8, 0.4), COLORS.cream)
		bed:SetAttribute("Floor", 3)
		bed:SetAttribute("Back", 7.6)
	elseif kind == "BoxTruck" then
		axle(truck, base, -half + 4, 3.95, 3.4)
		axle(truck, base, half - 5.5, 3.7, 3.4, true)
		axle(truck, base, half - 2.3, 3.7, 3.4, true)
		prop({ Name = "Chassis", Size = Vector3.new(7.6, 1, half * 2 - 1), CFrame = base * CFrame.new(0, 2.2, 0), Color = COLORS.dark }, truck)
		local back = cab(truck, base, -half, 3.6, 4.6, 6.4, paint)
		body(truck, base, back + 0.4, half, 3.2, 9, COLORS.cream, paint, "FARM FRESH")
		bed:SetAttribute("Floor", 3.2)
		bed:SetAttribute("Back", half - 2.2)
	else -- a semi: tractor and trailer (the reefer's is white, with its cooling unit)
		local reefer = kind == "Reefer"
		axle(truck, base, -half + 3.6, 3.95, 3.6)
		axle(truck, base, -half + 10.6, 3.7, 3.6, true)
		axle(truck, base, half - 5.4, 3.7, 3.6, true)
		axle(truck, base, half - 2, 3.7, 3.6, true)
		prop({ Name = "Chassis", Size = Vector3.new(7, 1, half * 2 - 1), CFrame = base * CFrame.new(0, 2.3, 0), Color = COLORS.dark }, truck)
		local back = cab(truck, base, -half, 4.4, 6.2, 7.4, paint, true)
		local skin = if reefer then Color3.fromRGB(240, 244, 246) else Color3.fromRGB(196, 202, 208)
		local trailerFront = back + 1.6
		body(truck, base, trailerFront, half, 3.8, 10, skin, paint, if reefer then "❄ FARM FRESH" else "FARM FRESH")
		prop({ Name = "LandingGear", Size = Vector3.new(6, 2.4, 0.5), CFrame = base * CFrame.new(0, 2.6, trailerFront + 3), Color = COLORS.dark }, truck)
		if reefer then
			prop({ Name = "Cooler", Size = Vector3.new(6.4, 4.4, 1.4), CFrame = base * CFrame.new(0, 3.8 + 10 - 3, trailerFront - 0.6), Color = Color3.fromRGB(226, 230, 234) }, truck)
			prop({ Name = "CoolerGrille", Size = Vector3.new(5.2, 3, 0.1), CFrame = base * CFrame.new(0, 3.8 + 10 - 3, trailerFront - 1.35), Color = COLORS.slate }, truck)
		end
		bed:SetAttribute("Floor", 3.8)
		bed:SetAttribute("Back", half - 2.2)
	end
	bed.Parent = truck
	truck.WorldPivot = parked
	truck.Parent = parent
	return truck
end

-- Lays a truck's crates in rows of two from the back (a closed truck shows
-- only its last few rows, through the open door).
function YardArt.showBed(truck: Model, crates)
	local bed = truck:FindFirstChild("Bed")
	bed:ClearAllChildren()
	local base = truck:GetPivot()
	local floor = bed:GetAttribute("Floor") or 3
	local back = bed:GetAttribute("Back") or 7.6
	local open = truck:GetAttribute("Kind") == "Pickup"
	for i, crate in crates do
		if not open and i > SHOW_BED then
			break
		end
		local column, row = (i - 1) % 2, (i - 1) // 2
		local layer = if open then 0 else row // 2
		local depth = if open then row else row % 2
		YardArt.crate(crate, base * CFrame.new(column * 3.6 - 1.8, floor + layer * CRATE.Y, back - depth * 3.6), bed)
	end
end

------------------------------------------------------------------------
-- The Packing Shed (Level 1–4)

local function buildShed(warehouse: Model, frame: CFrame)
	local shed = Instance.new("Model")
	shed.Name = "Building"
	shed:SetAttribute("Stage", 1)
	shed.Parent = warehouse
	local s = PlotLayout.WAREHOUSES[1]
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
	local top = part({ Name = "Bench", Size = Vector3.new(10, 0.6, 4), CFrame = frame * CFrame.new(s.bench + Vector3.new(0, 3.5, 0)), Color = COLORS.stumpTop }, shed)
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
	-- The rack on the dock for crates waiting while the pickup is out.
	local rackAt = PlotLayout.rackLocal()
	plotBox("RackBase", frame, rackAt + Vector3.new(-3.6, P.dock.height, -2.4), rackAt + Vector3.new(3.6, P.dock.height + 0.2, 4.8), { Color = COLORS.post }, shed)
end

------------------------------------------------------------------------
-- The warehouses (Level 5 and up)

-- A wall along `axis` ("X": across, at z c0..c1; "Z": front to back, at x
-- c0..c1) from `from` to `to`, `height` tall, with holes { a, b, bottom,
-- top, glass? } along it: an outer skin and a warm lining inside (`inward`:
-- which side of c0..c1 is inside, -1 or 1).
local function wall(frame: CFrame, parent: Instance, axis: string, c0: number, c1: number, from: number, to: number, height: number,
	holes, skin: Color3, inward: number)
	local function point(u: number, y: number, c: number): Vector3
		return if axis == "X" then Vector3.new(u, y, c) else Vector3.new(c, y, u)
	end
	local mid = (c0 + c1) / 2
	local layers = if inward > 0 then { { c0, mid + 0.2, skin }, { mid + 0.2, c1, LINING } } else { { mid - 0.2, c1, skin }, { c0, mid - 0.2, LINING } }
	table.sort(holes, function(a, b)
		return a.a < b.a
	end)
	for _, layer in layers do
		local l0, l1, color = layer[1], layer[2], layer[3]
		local u = from
		for _, hole in holes do
			if hole.a > u then
				plotBox("Wall", frame, point(u, FLOOR, l0), point(hole.a, height, l1), { Color = color }, parent)
			end
			if hole.bottom > FLOOR then
				plotBox("Sill", frame, point(hole.a, FLOOR, l0), point(hole.b, hole.bottom, l1), { Color = color }, parent)
			end
			if hole.top < height then
				plotBox("Header", frame, point(hole.a, hole.top, l0), point(hole.b, height, l1), { Color = color }, parent)
			end
			u = hole.b
		end
		if u < to then
			plotBox("Wall", frame, point(u, FLOOR, l0), point(to, height, l1), { Color = color }, parent)
		end
	end
	for _, hole in holes do
		if hole.glass then
			plotBox("Window", frame, point(hole.a, hole.bottom, mid - 0.1), point(hole.b, hole.top, mid + 0.1),
				{ Color = GLASS, Transparency = 0.45, Reflectance = 0.15, CastShadow = false }, parent)
		end
	end
	-- A darker band along the bottom outside (long metal walls need a line
	-- to sit on), stopping at doorways.
	local o0, o1 = if inward > 0 then c0 - 0.15 else c1 - 0.05, if inward > 0 then c0 + 0.05 else c1 + 0.15
	local u = from
	for _, hole in holes do
		if hole.bottom <= FLOOR + 0.01 then
			if hole.a > u then
				plotBox("BaseBand", frame, point(u, FLOOR, o0), point(hole.a, FLOOR + 1.6, o1), { Color = BAND }, parent)
			end
			u = hole.b
		end
	end
	if u < to then
		plotBox("BaseBand", frame, point(u, FLOOR, o0), point(to, FLOOR + 1.6, o1), { Color = BAND }, parent)
	end
end

-- Windows every `step` studs along a wall, from `from` to `to`, `width` wide,
-- skipping the ranges in `keep` (doors).
local function windows(from: number, to: number, step: number, width: number, bottom: number, top: number, keep)
	local list = {}
	local u = from
	while u + width <= to do
		local clear = true
		for _, range in keep do
			if u + width > range[1] - 1.5 and u < range[2] + 1.5 then
				clear = false
			end
		end
		if clear then
			table.insert(list, { a = u, b = u + width, bottom = bottom, top = top, glass = true })
		end
		u += step
	end
	return list
end

-- A rolled-up door's drum over an opening (along `axis` at c), in a colour.
local function drum(frame: CFrame, parent: Instance, axis: string, c: number, a: number, b: number, top: number, color: Color3)
	local length = b - a
	local centre = if axis == "X" then Vector3.new((a + b) / 2, top + 0.7, c) else Vector3.new(c, top + 0.7, (a + b) / 2)
	local turn = if axis == "X" then CFrame.identity else CFrame.Angles(0, math.rad(90), 0)
	prop({ Name = "DoorDrum", Shape = Enum.PartType.Cylinder, Size = Vector3.new(length + 0.6, 1.4, 1.4), CFrame = frame * CFrame.new(centre) * turn, Color = color }, parent)
end

-- The conveyor from the intake at the back to the loading end by the docks,
-- with its stations: the intake hopper, the wash arch over the Sort table,
-- the packing table, pallets at the loading end.
local function buildLine(frame: CFrame, parent: Instance, stage: number, paint: Color3)
	local layout = PlotLayout.WAREHOUSES[stage]
	local s = layout.stations
	local stations = Instance.new("Folder")
	stations.Name = "Stations"
	stations.Parent = parent
	local x = s.Sort.X + 6 -- the belt, beyond the stations' tables (each worker stands at their spot, the table between them and the belt)
	local z0, z1 = s.Load.Z + 2, s.Intake.Z
	local height = FLOOR + 3
	plotBox("Belt", frame, Vector3.new(x - 1.6, height - 0.4, z0), Vector3.new(x + 1.6, height, z1), { Color = BELT }, parent)
	for _, side in { -1, 1 } do
		plotBox("BeltRail", frame, Vector3.new(x + side * 1.9 - 0.3, height - 0.7, z0), Vector3.new(x + side * 1.9 + 0.3, height + 0.35, z1), { Color = paint }, parent)
	end
	for z = z0 + 2, z1 - 1, 6 do
		for _, side in { -1, 1 } do
			plotBox("BeltLeg", frame, Vector3.new(x + side * 1.6 - 0.25, FLOOR, z - 0.25), Vector3.new(x + side * 1.6 + 0.25, height - 0.7, z + 0.25), { Color = STEEL }, parent)
		end
	end
	-- A branch across to the Cold Room's door.
	local room = layout.coldRoom
	local branchZ = (room.min.Z + room.max.Z) / 2
	if room.min.X > x + 2 then
		plotBox("Belt", frame, Vector3.new(x + 1.6, height - 0.4, branchZ - 1.6), Vector3.new(room.min.X - 0.6, height, branchZ + 1.6), { Color = BELT }, parent)
		plotBox("BeltRail", frame, Vector3.new(x + 1.6, height - 0.7, branchZ - 1.9), Vector3.new(room.min.X - 0.6, height + 0.35, branchZ - 1.3), { Color = paint }, parent)
		plotBox("BeltRail", frame, Vector3.new(x + 1.6, height - 0.7, branchZ + 1.3), Vector3.new(room.min.X - 0.6, height + 0.35, branchZ + 1.9), { Color = paint }, parent)
	end
	-- Each station: a spot for its worker (a part on the floor, named for it)
	-- and its look.
	for id, at in s do
		local spot = prop({ Name = id, Size = Vector3.new(3, 0.1, 3), CFrame = frame * CFrame.new(at + Vector3.new(0, FLOOR + 0.05, 0)), Transparency = 1, CastShadow = false }, stations)
		spot.CanQuery = false
	end
	-- Intake: a hopper in the farm's colour under the back door.
	local intake = s.Intake
	plotBox("Hopper", frame, Vector3.new(x - 3, FLOOR, intake.Z - 2), Vector3.new(x + 3, FLOOR + 4.5, intake.Z + 3), { Color = paint }, parent)
	plotBox("HopperRim", frame, Vector3.new(x - 3.3, FLOOR + 4.5, intake.Z - 2.3), Vector3.new(x + 3.3, FLOOR + 5, intake.Z + 3.3), { Color = STEEL }, parent)
	sign("IntakeSign", "INTAKE", frame * CFrame.new(x, FLOOR + 6.6, intake.Z - 2.2), Vector3.new(5, 1.4, 0.2), parent, paint, COLORS.cream)
	-- Wash & Sort: a table with a spray arch over the belt.
	local sort = s.Sort
	plotBox("SortTable", frame, Vector3.new(sort.X + 1, FLOOR, sort.Z - 3), Vector3.new(sort.X + 4.2, FLOOR + 3, sort.Z + 3), { Color = STEEL }, parent)
	local arch = sort.Z + 3.8 -- (just past the table)
	for _, side in { -1, 1 } do
		plotBox("SprayPost", frame, Vector3.new(x + side * 2.4 - 0.25, FLOOR, arch - 0.25), Vector3.new(x + side * 2.4 + 0.25, height + 3, arch + 0.25), { Color = COLORS.water }, parent)
	end
	plotBox("SprayBar", frame, Vector3.new(x - 2.65, height + 2.6, arch - 0.3), Vector3.new(x + 2.65, height + 3.1, arch + 0.3), { Color = COLORS.water }, parent)
	-- Pack: a table with empty crates and the tape.
	local pack = s.Pack
	local packTop = plotBox("PackTable", frame, Vector3.new(pack.X + 1, FLOOR, pack.Z - 3), Vector3.new(pack.X + 4.2, FLOOR + 3, pack.Z + 3), { Color = COLORS.stumpTop }, parent)
	YardArt.crate({ crop = "Carrot", units = 0, grade = "B" }, packTop.CFrame * CFrame.new(0, 1.5, 0), parent).Name = "EmptyCrate"
	cylinder("Tape", packTop.CFrame * CFrame.new(0.4, 1.8, 2.2), 1, 0.5, { Color = Color3.fromRGB(210, 160, 90) }, parent)
	for i = 0, 2 do
		YardArt.crate({ crop = "Carrot", units = 0, grade = "B" }, frame * CFrame.new(pack.X - 2.5, FLOOR + i * CRATE.Y, pack.Z + 5) * CFrame.Angles(0, math.rad(i * 9), 0), parent)
	end
	-- A sign over each station, so you can tell them apart.
	for _, entry in { { "Sort", "WASH & SORT" }, { "Pack", "PACK" }, { "Load", "LOAD THE TRUCKS" } } do
		local at = s[entry[1]]
		local board = sign(`{entry[1]}Sign`, entry[2], frame * CFrame.new(at.X + 2.6, FLOOR + 7.4, at.Z) * CFrame.Angles(0, math.rad(90), 0),
			Vector3.new(6, 1.4, 0.2), parent, paint, COLORS.cream)
		board.CanCollide = false
		prop({ Name = "SignCord", Size = Vector3.new(0.12, 2.6, 0.12), CFrame = board.CFrame * CFrame.new(0, 2, 0), Color = COLORS.dark }, parent)
	end
	-- Load: pallets at the end of the belt.
	local load = s.Load
	for i = 0, 1 do
		plotBox("Pallet", frame, Vector3.new(load.X - 3 - i * 5.5, FLOOR, load.Z + 2), Vector3.new(load.X + 1.5 - i * 5.5, FLOOR + 0.6, load.Z + 6.5), { Color = COLORS.edging }, parent)
	end
end

-- The Cold Room: insulated walls with a doorway toward the belt, a sign,
-- and the rack the crates stack on.
local function buildColdRoom(frame: CFrame, parent: Instance, stage: number, warehouse: Model)
	local room = PlotLayout.WAREHOUSES[stage].coldRoom
	local min, max = room.min, room.max
	local t = 0.8
	local doorZ = (min.Z + max.Z) / 2
	-- the wall facing the belt has the doorway; the front and back walls are
	-- solid; the outer side is the building's own wall
	plotBox("ColdWall", frame, Vector3.new(min.X, FLOOR, min.Z), Vector3.new(min.X + t, max.Y, doorZ - 3), { Color = FROST }, parent)
	plotBox("ColdWall", frame, Vector3.new(min.X, FLOOR, doorZ + 3), Vector3.new(min.X + t, max.Y, max.Z), { Color = FROST }, parent)
	plotBox("ColdWall", frame, Vector3.new(min.X, 8, doorZ - 3), Vector3.new(min.X + t, max.Y, doorZ + 3), { Color = FROST }, parent)
	plotBox("ColdWall", frame, Vector3.new(min.X, FLOOR, min.Z), Vector3.new(max.X, max.Y, min.Z + t), { Color = FROST }, parent)
	plotBox("ColdWall", frame, Vector3.new(min.X, FLOOR, max.Z - t), Vector3.new(max.X, max.Y, max.Z), { Color = FROST }, parent)
	-- a blue trim along the tops of its walls (open above: with the roof
	-- faded you see the crates inside)
	plotBox("ColdTrim", frame, Vector3.new(min.X - 0.1, max.Y, min.Z - 0.1), Vector3.new(min.X + t + 0.1, max.Y + 0.4, max.Z + 0.1), { Color = COLORS.water }, parent)
	for _, z in { min.Z, max.Z - t } do
		plotBox("ColdTrim", frame, Vector3.new(min.X - 0.1, max.Y, z - 0.1), Vector3.new(max.X, max.Y + 0.4, z + t + 0.1), { Color = COLORS.water }, parent)
	end
	-- strip curtains in the doorway
	for i = 0, 4 do
		local z = doorZ - 2.4 + i * 1.2
		prop({ Name = "Curtain", Size = Vector3.new(0.1, 7, 1), CFrame = frame * CFrame.new(min.X - 0.1, FLOOR + 3.6, z), Color = FROST, Transparency = 0.5, CastShadow = false }, parent)
	end
	local board = sign("ColdRoomSign", "❄ COLD ROOM", frame * CFrame.new(min.X - 0.2, max.Y - 1.4, doorZ) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(8, 1.8, 0.2), parent, COLORS.water, COLORS.cream)
	board.CanCollide = false
	local count = sign("ColdRoomCount", "0", frame * CFrame.new(min.X - 0.2, max.Y - 3.2, doorZ) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(4, 1.2, 0.2), parent, COLORS.cream, COLORS.dark)
	count.CanCollide = false
	local rack = Instance.new("Folder")
	rack.Name = "Rack"
	rack.Parent = warehouse
end

-- Ceiling lamps: a row along the middle under the roof (a few light up).
local function warehouseLamps(frame: CFrame, roof: Instance, min: Vector3, max: Vector3, height: number)
	local across = math.max(1, math.round((max.X - min.X) / 26))
	local along = math.max(2, math.round((max.Z - min.Z) / 18))
	local lit = 0
	for i = 1, across do
		local x = min.X + (max.X - min.X) * (i - 0.5) / across
		for j = 1, along do
			local z = min.Z + (max.Z - min.Z) * (j - 0.5) / along
			prop({ Name = "LampCord", Size = Vector3.new(0.15, 1.6, 0.15), CFrame = frame * CFrame.new(x, height - 0.8, z), Color = COLORS.dark }, roof)
			local shade = prop({ Name = "LampShade", Size = Vector3.new(2.2, 0.6, 2.2), CFrame = frame * CFrame.new(x, height - 1.8, z), Color = STEEL }, roof)
			local bulb = prop({ Name = "Lamp", Size = Vector3.new(1.4, 0.3, 1.4), CFrame = shade.CFrame * CFrame.new(0, -0.4, 0), Color = GLOW, Material = Enum.Material.Neon, CastShadow = false }, roof)
			if lit < MAX_LIGHTS and (j - 1) % 2 == 0 then
				lit += 1
				pointLight(bulb, 26)
			end
		end
	end
end

-- A warehouse (stage 2–4): walls with dock doors at the front, a staff door
-- on the gate side, the intake door at the back toward the field and windows
-- all round; a low metal roof (in the Roof model, with the lamps, so it
-- fades while you're inside); the stations and the Cold Room inside.
local function buildWarehouse(warehouse: Model, frame: CFrame, stage: number, info, paint: Color3)
	local layout = PlotLayout.WAREHOUSES[stage]
	local min, max = layout.min, layout.max
	local h = max.Y
	local trim = if info.goldTrim then GOLD else paint
	local skin = COLORS.metal
	local building = Instance.new("Model")
	building.Name = "Building"
	building:SetAttribute("Stage", stage)
	building.Parent = warehouse
	local roof = Instance.new("Model")
	roof.Name = "Roof"

	plotBox("Slab", frame, Vector3.new(min.X, 0, min.Z), Vector3.new(max.X, FLOOR, max.Z), { Color = CONCRETE }, building)
	-- floor markings: a yellow walkway line along the gate-side wall
	plotBox("FloorLine", frame, Vector3.new(min.X + 3, FLOOR, min.Z + 2), Vector3.new(min.X + 3.4, FLOOR + 0.02, max.Z - 2), { Color = COLORS.hay, CastShadow = false }, building)

	-- The front: a dock door per dock (rolled up), the name over them.
	local front = {}
	for _, across in layout.docks do
		table.insert(front, { a = across - 6, b = across + 6, bottom = FLOOR, top = 11 })
	end
	wall(frame, building, "X", min.Z, min.Z + 1, min.X, max.X, h, front, skin, 1)
	for _, across in layout.docks do
		drum(frame, building, "X", min.Z - 0.4, across - 6, across + 6, 11, trim)
		for _, side in { -1, 1 } do
			plotBox("DoorPost", frame, Vector3.new(across + side * 6 - 0.4, FLOOR, min.Z - 0.5), Vector3.new(across + side * 6 + 0.4, 11, min.Z), { Color = trim }, building)
		end
	end
	sign("NameSign", string.upper(info.building.name), frame * CFrame.new((min.X + max.X) / 2, h - 2, min.Z - 0.3),
		Vector3.new(math.min(max.X - min.X - 8, 40), 3, 0.3), building, trim, if info.goldTrim then COLORS.dark else COLORS.cream)

	-- The gate side: a staff door near the front, windows along it.
	local doorZ = min.Z + 10
	local side = windows(min.Z + 16, max.Z - 4, 12, 6, FLOOR + 4, FLOOR + 8.5, {})
	table.insert(side, { a = doorZ - 2.5, b = doorZ + 2.5, bottom = FLOOR, top = FLOOR + 7.5 })
	wall(frame, building, "Z", min.X, min.X + 1, min.Z + 1, max.Z - 1, h, side, skin, 1)
	plotBox("DoorFrame", frame, Vector3.new(min.X - 0.3, FLOOR, doorZ - 2.9), Vector3.new(min.X, FLOOR + 7.9, doorZ - 2.5), { Color = trim }, building)
	plotBox("DoorFrame", frame, Vector3.new(min.X - 0.3, FLOOR, doorZ + 2.5), Vector3.new(min.X, FLOOR + 7.9, doorZ + 2.9), { Color = trim }, building)
	plotBox("DoorFrame", frame, Vector3.new(min.X - 0.3, FLOOR + 7.5, doorZ - 2.9), Vector3.new(min.X, FLOOR + 7.9, doorZ + 2.9), { Color = trim }, building)
	plotBox("Awning", frame, Vector3.new(min.X - 2.4, FLOOR + 8.4, doorZ - 3.4), Vector3.new(min.X, FLOOR + 8.8, doorZ + 3.4), { Color = trim }, building)
	plotBox("Step", frame, Vector3.new(min.X - 2, 0, doorZ - 2.5), Vector3.new(min.X, FLOOR - 0.4, doorZ + 2.5), { Color = CONCRETE }, building)

	-- The back: the intake door toward the field, windows either side.
	local intake = layout.stations.Intake.X + 6 -- (over the belt's end)
	local back = windows(min.X + 4, max.X - 4, 12, 6, FLOOR + 4, FLOOR + 8.5, { { intake - 7, intake + 7 } })
	table.insert(back, { a = intake - 7, b = intake + 7, bottom = FLOOR, top = 11 })
	wall(frame, building, "X", max.Z - 1, max.Z, min.X, max.X, h, back, skin, -1)
	drum(frame, building, "X", max.Z + 0.4, intake - 7, intake + 7, 11, trim)
	-- The far side (toward the hedge): windows.
	wall(frame, building, "Z", max.X - 1, max.X, min.Z + 1, max.Z - 1, h,
		windows(min.Z + 8, max.Z - 4, 12, 6, FLOOR + 4, FLOOR + 8.5, { { layout.coldRoom.min.Z, layout.coldRoom.max.Z } }), skin, -1)
	-- The trim along the top of every wall.
	for _, z in { min.Z - 0.15, max.Z + 0.15 } do
		plotBox("Fascia", frame, Vector3.new(min.X - 0.2, h - 0.8, z - 0.15), Vector3.new(max.X + 0.2, h, z + 0.15), { Color = trim }, building)
	end
	for _, x in { min.X - 0.15, max.X + 0.15 } do
		plotBox("Fascia", frame, Vector3.new(x - 0.15, h - 0.8, min.Z - 0.2), Vector3.new(x + 0.15, h, max.Z + 0.2), { Color = trim }, building)
	end

	-- The roof: two low slopes, the ridge front to back, gable ends in the
	-- wall's metal; the Distribution Center's is flat, with skylights and air
	-- units. All of it fades while you're inside.
	local midX = (min.X + max.X) / 2
	local halfW = (max.X - min.X) / 2 + 1
	if stage < 4 then
		local rise = if stage == 2 then 4 else 5
		local slope = math.atan(rise / halfW)
		local run = math.sqrt(halfW * halfW + rise * rise)
		for _, side in { -1, 1 } do
			part({
				Name = "RoofSlope", Size = Vector3.new(run, 0.8, max.Z - min.Z + 2),
				CFrame = frame * CFrame.new(midX + side * halfW / 2, h + rise / 2 + 0.4, (min.Z + max.Z) / 2) * CFrame.Angles(0, 0, -side * slope),
				Color = COLORS.slate,
			}, roof)
			for _, z in { min.Z + 0.5, max.Z - 0.5 } do
				local wedge = Instance.new("WedgePart")
				wedge.Name = "Gable"
				wedge.Anchored = true
				wedge.Material = Enum.Material.SmoothPlastic
				wedge.Color = skin
				wedge.Size = Vector3.new(1, rise, halfW - 1)
				wedge.CFrame = frame * CFrame.new(midX + side * (halfW - 1) / 2, h + rise / 2, z) * CFrame.Angles(0, math.rad(-90 * side), 0)
				wedge.Parent = roof
			end
		end
		part({ Name = "Ridge", Size = Vector3.new(1.2, 0.6, max.Z - min.Z + 2.4), CFrame = frame * CFrame.new(midX, h + rise + 0.6, (min.Z + max.Z) / 2), Color = trim }, roof)
	else
		plotBox("RoofDeck", frame, Vector3.new(min.X - 0.5, h, min.Z - 0.5), Vector3.new(max.X + 0.5, h + 0.8, max.Z + 0.5), { Color = COLORS.slate }, roof)
		for _, z in { min.Z - 0.5, max.Z - 0.1 } do
			plotBox("Parapet", frame, Vector3.new(min.X - 0.5, h + 0.8, z), Vector3.new(max.X + 0.5, h + 2, z + 0.6), { Color = trim }, roof)
		end
		for _, x in { min.X - 0.5, max.X - 0.1 } do
			plotBox("Parapet", frame, Vector3.new(x, h + 0.8, min.Z - 0.5), Vector3.new(x + 0.6, h + 2, max.Z + 0.5), { Color = trim }, roof)
		end
		for i = 1, 3 do
			local x = min.X + (max.X - min.X) * i / 4
			plotBox("Skylight", frame, Vector3.new(x - 2, h + 0.8, min.Z + 10), Vector3.new(x + 2, h + 1.6, max.Z - 10), { Color = GLASS, Transparency = 0.3, Reflectance = 0.2 }, roof)
		end
		for _, z in { min.Z + 18, (min.Z + max.Z) / 2, max.Z - 18 } do
			local unit = plotBox("AirUnit", frame, Vector3.new(max.X - 16, h + 0.8, z - 3), Vector3.new(max.X - 8, h + 4, z + 3), { Color = Color3.fromRGB(206, 210, 214) }, roof)
			cylinder("Fan", unit.CFrame * CFrame.new(0, 1.65, 0), 4, 0.2, { Color = COLORS.dark }, roof)
		end
	end
	warehouseLamps(frame, roof, min, max, h)
	roof.Parent = building

	-- The room the roof fades over (RoofController).
	plotBox("Interior", frame, Vector3.new(min.X, FLOOR, min.Z), Vector3.new(max.X, h, max.Z),
		{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }, building)

	-- The wash table: where you wash and pack by hand (the bench's prompt).
	local b = layout.bench
	local top = part({ Name = "Bench", Size = Vector3.new(8, 0.6, 4), CFrame = frame * CFrame.new(b + Vector3.new(0, FLOOR + 3.3, 0)), Color = STEEL }, building)
	for _, x in { -3.6, 3.6 } do
		for _, z in { -1.6, 1.6 } do
			prop({ Name = "Leg", Size = Vector3.new(0.5, 3, 0.5), CFrame = top.CFrame * CFrame.new(x, -1.8, z), Color = STEEL }, building)
		end
	end
	prop({ Name = "Sink", Size = Vector3.new(3, 1, 3), CFrame = top.CFrame * CFrame.new(-2.2, 0.6, 0), Color = COLORS.metal }, building)
	prop({ Name = "Water", Size = Vector3.new(2.6, 0.1, 2.6), CFrame = top.CFrame * CFrame.new(-2.2, 1, 0), Color = COLORS.water, Transparency = 0.2 }, building)
	YardArt.crate({ crop = "Carrot", units = 0, grade = "B" }, top.CFrame * CFrame.new(1.8, 0.3, 0), building).Name = "EmptyCrate"
	sign("WashSign", "WASH & PACK BY HAND", frame * CFrame.new(b + Vector3.new(0, FLOOR + 7.2, 2.2)), Vector3.new(7, 1.3, 0.2), building, trim, COLORS.cream).CanCollide = false

	buildLine(frame, building, stage, trim)
	buildColdRoom(frame, building, stage, warehouse)
end

------------------------------------------------------------------------
-- Docks, lanes, gates and trucks

local function buildDocks(warehouse: Model, frame: CFrame, stage: number, trucks: number, paint: Color3)
	local docks = Instance.new("Model")
	docks.Name = "Docks"
	docks.Parent = warehouse
	local box = PlotLayout.dockBox(stage)
	plotBox("Dock", frame, box.min, box.max, { Color = if stage == 1 then COLORS.edging else CONCRETE }, docks)
	plotBox("DockEdge", frame, Vector3.new(box.min.X, box.max.Y - 0.05, box.min.Z), Vector3.new(box.max.X, box.max.Y + 0.02, box.min.Z + 0.6), { Color = COLORS.hay, CastShadow = false }, docks)
	for i, across in PlotLayout.WAREHOUSES[stage].docks do
		for _, side in { -1, 1 } do
			plotBox("Bumper", frame, Vector3.new(across + side * 4.6 - 0.6, 0.1, box.min.Z - 0.5), Vector3.new(across + side * 4.6 + 0.6, box.max.Y + 0.3, box.min.Z), { Color = COLORS.dark }, docks)
		end
		if i <= trucks then
			local load = prop({
				Name = `LoadSpot{i}`, Size = Vector3.new(12, 3, 1.5), CFrame = frame * CFrame.new(PlotLayout.loadLocal(across) + Vector3.new(0, box.max.Y + 1.5, 0)),
				Transparency = 1, CanQuery = false,
			}, docks)
			load:SetAttribute("Dock", i)
			local leverAt = frame * CFrame.new(PlotLayout.leverLocal(across) + Vector3.new(0, box.max.Y, 0))
			prop({ Name = `LeverBase{i}`, Size = Vector3.new(1.2, 2.6, 1.2), CFrame = leverAt * CFrame.new(0, 1.3, 0), Color = COLORS.slate }, docks)
			local handle = prop({ Name = "Lever", Size = Vector3.new(0.3, 2.4, 0.3), CFrame = leverAt * CFrame.new(0, 3.3, 0) * CFrame.Angles(math.rad(-25), 0, 0), Color = COLORS.post }, docks)
			ball("Knob", handle.CFrame * CFrame.new(0, 1.3, 0), 0.8, { Color = paint }, docks)
			if #PlotLayout.WAREHOUSES[stage].docks > 1 then
				sign("DockNumber", `{i}`, frame * CFrame.new(across, 13.4, P.warehouse.min.Z - 0.35), Vector3.new(2.4, 2.4, 0.2), docks, paint, COLORS.cream).CanCollide = false
			end
		else
			sign("DockWaiting", `Truck {i}: Warehouse Level {#Warehouse.LEVELS}`, frame * CFrame.new(across, box.max.Y + 2.2, box.min.Z + 2.5),
				Vector3.new(8, 1.6, 0.3), docks, COLORS.cream, COLORS.dark)
		end
	end
	if stage == 1 then
		local rack = Instance.new("Folder")
		rack.Name = "Rack"
		rack.Parent = warehouse
	end
end

-- The lanes from the front fence to each dock, a striped boom across each
-- (only trucks pass: the client lifts it for them; an invisible wall stays
-- for people), and the picket fence on this side between them.
local function buildLanes(warehouse: Model, frame: CFrame, stage: number)
	local lanes = Instance.new("Model")
	lanes.Name = "Lanes"
	lanes.Parent = warehouse
	local fenceFrom = P.driveway.max.X
	for i, across in PlotLayout.WAREHOUSES[stage].docks do
		local lane = PlotLayout.lane(across)
		plotBox(if i == 1 then "Driveway" else "Lane", frame, lane.min + Vector3.new(0, 0.2, 0), lane.max + Vector3.new(0, 0.15, 0), { Color = COLORS.road }, lanes)
		local left, right = lane.min.X, lane.max.X
		if i > 1 then
			Parts.picketFence(frame, Vector3.new(fenceFrom, 0, -1), Vector3.new(left, 0, 0), lanes, "FrontFenceFar", PlotLayout.FENCE_HEIGHT, PlotLayout.FENCE_BLOCK)
		end
		fenceFrom = right
		local gate = Instance.new("Model")
		gate.Name = `Gate{i}`
		gate.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- (the boom swings as one piece on the client)
		for _, x in { left, right } do
			plotBox("GatePost", frame, Vector3.new(x - 0.6, 0, -1.1), Vector3.new(x + 0.6, 4.6, 0.1), { Color = COLORS.post }, gate)
		end
		local boom = Instance.new("Model")
		boom.Name = "Boom"
		local width = right - left - 1
		local segments = 6
		for j = 0, segments - 1 do
			prop({
				Name = "Stripe", Size = Vector3.new(width / segments, 0.6, 0.6),
				CFrame = frame * CFrame.new(left + 0.6 + (j + 0.5) * width / segments, 3.6, -0.5),
				Color = if j % 2 == 0 then COLORS.barnRed else COLORS.cream,
			}, boom)
		end
		boom.WorldPivot = frame * CFrame.new(left + 0.6, 3.6, -0.5) -- the hinge
		boom.Parent = gate
		gate:SetAttribute("Across", across)
		gate.Parent = lanes
		plotBox("TruckGateBlocker", frame, Vector3.new(left, 0, -1), Vector3.new(right, PlotLayout.FENCE_BLOCK, 0),
			{ Transparency = 1, CanQuery = false, CanTouch = false }, lanes)
	end
	Parts.picketFence(frame, Vector3.new(fenceFrom, 0, -1), Vector3.new(PlotLayout.WIDTH / 2, 0, 0), lanes, "FrontFenceFar", PlotLayout.FENCE_HEIGHT, PlotLayout.FENCE_BLOCK)
end

------------------------------------------------------------------------

-- (Re)builds a farm's warehouse side for a Warehouse Level: the building,
-- docks, lanes and trucks (empty: the services draw crates). paint: the
-- farm's colour.
function YardArt.setLevel(model: Model, level: number)
	local old = model:FindFirstChild("Warehouse")
	if old then
		old:Destroy()
	end
	local index = model:GetAttribute("PlotIndex") or 1
	local frame = PlotLayout.frame(index)
	local paint = Parts.farmColor(index)
	local info = WarehouseRules.level(level)
	local stage = info.stage
	local warehouse = Instance.new("Model")
	warehouse.Name = "Warehouse"
	warehouse:SetAttribute("Stage", stage)
	warehouse:SetAttribute("Level", level)
	if stage == 1 then
		buildShed(warehouse, frame)
	else
		buildWarehouse(warehouse, frame, stage, info, paint)
	end
	buildDocks(warehouse, frame, stage, info.trucks, paint)
	buildLanes(warehouse, frame, stage)
	local trucks = Instance.new("Folder")
	trucks.Name = "Trucks"
	trucks.Parent = warehouse
	local length = YardArt.TRUCK_LENGTH[info.truck]
	for i = 1, info.trucks do
		local across = PlotLayout.WAREHOUSES[stage].docks[i]
		buildTruck(info.truck, paint, frame * CFrame.new(PlotLayout.truckParked(across, length)), `Truck{i}`, trucks):SetAttribute("Dock", i)
	end
	-- the site's sign, while there's only the shed
	if stage == 1 then
		local siteSign = sign("SiteSign", `{Warehouse.BUILDINGS[2].name}\nWarehouse Level {Warehouse.BUILDINGS[2].from}`, frame * CFrame.new(64, 4.5, 90),
			Vector3.new(14, 4, 0.4), warehouse)
		for _, x in { -6, 6 } do
			prop({ Name = "SignPost", Size = Vector3.new(0.6, 4.5, 0.6), CFrame = siteSign.CFrame * CFrame.new(x, -2.2, 0.4), Color = COLORS.post }, warehouse)
		end
	end
	warehouse.Parent = model
	return warehouse
end

-- Scaffolding round the next building while it goes up, with a sign by the
-- truck gate counting down; nil takes it down.
function YardArt.showConstruction(model: Model, toLevel: number?, secondsLeft: number?)
	local old = model:FindFirstChild("WarehouseConstruction")
	if not toLevel then
		if old then
			old:Destroy()
		end
		return
	end
	local info = WarehouseRules.level(toLevel)
	local text = `{info.building.name}: {string.format("%d:%02d", (secondsLeft or 0) // 60, (secondsLeft or 0) % 60)}`
	if old and old:GetAttribute("To") == info.stage then
		old.Sign.SurfaceGui.Words.Text = text
		return
	end
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Model")
	folder.Name = "WarehouseConstruction"
	folder:SetAttribute("To", info.stage)
	local frame = frameOf(model)
	local layout = PlotLayout.WAREHOUSES[info.stage]
	local before = PlotLayout.WAREHOUSES[info.stage - 1]
	local min, max = layout.min, layout.max
	local pole = Color3.fromRGB(150, 156, 164)
	local plank = Color3.fromRGB(196, 160, 110)
	local h = max.Y
	-- poles round the new walls that aren't the old building's
	local outline = {}
	for x = before.max.X + 2, max.X + 1, 6 do
		table.insert(outline, Vector3.new(x, 0, min.Z + 1))
		table.insert(outline, Vector3.new(x, 0, max.Z + 1.5))
	end
	for z = min.Z + 4, max.Z + 1.5, 6 do
		table.insert(outline, Vector3.new(max.X + 1.5, 0, z))
		if z > before.max.Z then
			table.insert(outline, Vector3.new(min.X - 1.5, 0, z))
		end
	end
	for x = min.X - 1.5, before.max.X, 6 do
		table.insert(outline, Vector3.new(x, 0, max.Z + 1.5))
	end
	for _, at in outline do
		plotBox("Pole", frame, at + Vector3.new(-0.25, 0, -0.25), at + Vector3.new(0.25, h + 2, 0.25), { Color = pole }, folder)
	end
	for _, y in { 4, 9, h } do
		plotBox("Plank", frame, Vector3.new(max.X + 0.6, y, min.Z + 2), Vector3.new(max.X + 2.4, y + 0.35, max.Z + 2.4), { Color = plank }, folder)
		plotBox("Plank", frame, Vector3.new(min.X - 2.4, y, max.Z + 0.6), Vector3.new(max.X + 2.4, y + 0.35, max.Z + 2.4), { Color = plank }, folder)
	end
	-- the sign, by the gatehouse, facing the road
	local signAt = frame * CFrame.new(P.gatehouse.max.X + 3, 0, P.gatehouse.min.Z) * CFrame.Angles(0, math.pi, 0)
	for _, x in { -3, 3 } do
		part({ Name = "SignPost", Size = Vector3.new(0.4, 9, 0.4), CFrame = signAt * CFrame.new(x, 4.5, 0.3), Color = COLORS.post }, folder)
	end
	sign("Sign", text, signAt * CFrame.new(0, 8, 0) * CFrame.Angles(0, math.pi, 0), Vector3.new(7.4, 2.6, 0.2), folder, COLORS.hay, COLORS.dark)
	folder.Parent = model
end

-- Builds a farm's warehouse side at Level 1 (WorldBuilder): the gravel site
-- the warehouses will stand on, and the Packing Shed with its dock, lane and pickup.
function YardArt.build(model: Model, frame: CFrame)
	local site = P.warehouse
	plotBox("WarehouseSite", frame, site.min, Vector3.new(site.max.X, 0.3, site.max.Z), { Color = Color3.fromRGB(184, 174, 156) }, model)
	YardArt.setLevel(model, 1)
end

return YardArt
