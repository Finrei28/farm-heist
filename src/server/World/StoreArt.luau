-- How your store looks (docs/GameDesign.md §4.8, ArtDirection §11 step 9):
-- the four buildings (Corner Store, Farm Shop, Market Hall, Supermarket),
-- the floor with the part not open yet taped off, the stockroom behind it
-- with a crate for every crate in it, the staff door, the front fence
-- beside it, scaffolding while a new building goes up, and the items laid
-- out on the floor (models from World/StoreItems) with produce and price
-- tags on the displays.
--
-- Everything lives in the plot's "Store" model: Building (rebuilt when the
-- level changes), Fence, Items, Stockroom, Construction. StoreService
-- decides what to show; positions come from shared/PlotLayout (the store's
-- grid) and Config/Store.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crops = require(ReplicatedStorage.Shared.Config.Crops)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Store = require(ReplicatedStorage.Shared.Config.Store)
local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
local StoreLayout = require(ReplicatedStorage.Shared.StoreLayout)
local Parts = require(script.Parent.Parts)
local FarmArt = require(script.Parent.FarmArt)
local YardArt = require(script.Parent.YardArt)

local COLORS = Parts.COLORS
local plotBox = Parts.plotBox

local StoreArt = {}

local S = PlotLayout.PLOT.store
local CELL = Store.CELL
local FLOOR = S.floor
local DOOR_TOP = 8

local GLASS = Color3.fromRGB(176, 214, 232)
local TAPE = Color3.fromRGB(245, 200, 40)
local CARDBOARD = Color3.fromRGB(200, 160, 110)
local CONCRETE = Color3.fromRGB(196, 192, 184)
local BRICK = Color3.fromRGB(176, 84, 62)
local SLATE_ROOF = Color3.fromRGB(88, 82, 80)
local WHITE = Color3.fromRGB(240, 240, 236)
local STEEL = Color3.fromRGB(120, 128, 138)
local GOLD = Color3.fromRGB(240, 190, 60)

-- Each building's look: wall height, colours, floor tiles.
-- (inner: the walls' inside colour, when it isn't the outside's; gable: the
-- roof's rise, for a building without a flat ceiling)
-- Inside, nothing is near-white (under the lamps a white wall or floor
-- glares) and nothing cool: while you're in, the roof is faded and the room
-- is lit by the open sky (RoofController shades it from the sun), which
-- turns greys and sage blue. Warm colours look the same with the roof on
-- or off.
local PLASTER = Color3.fromRGB(230, 212, 182) -- warm plaster
local LOOK = {
	CornerStore = { height = 10, wall = COLORS.cream, inner = Color3.fromRGB(228, 206, 168), trim = COLORS.post, tiles = { Color3.fromRGB(196, 150, 100), Color3.fromRGB(178, 132, 86) } },
	FarmShop = { height = 12, wall = COLORS.barnRed, inner = PLASTER, gable = 9.5, trim = COLORS.cream, tiles = { Color3.fromRGB(190, 146, 98), Color3.fromRGB(170, 126, 82) } },
	MarketHall = { height = 15, wall = BRICK, inner = PLASTER, trim = COLORS.cream, tiles = { Color3.fromRGB(210, 190, 154), Color3.fromRGB(178, 98, 68) } },
	Supermarket = { height = 18, wall = WHITE, inner = Color3.fromRGB(190, 190, 166), trim = STEEL, tiles = { Color3.fromRGB(178, 170, 152), Color3.fromRGB(146, 142, 130) } },
}

------------------------------------------------------------------------
-- Helpers. `sf` is the store's frame: the plot frame moved to the floor's
-- front corner at the gate end, so the floor runs from x = −width to 0 and
-- z = 0 to depth (cells go −x and +z).

local function storeFrame(index: number): CFrame
	return PlotLayout.frame(index) * CFrame.new(S.right, 0, 0)
end

local function box(name: string, frame: CFrame, x0, y0, z0, x1, y1, z1, color: Color3, parent: Instance, extra: { [string]: any }?)
	local props: { [string]: any } = { Color = color }
	for k, v in extra or {} do
		props[k] = v
	end
	return plotBox(name, frame, Vector3.new(math.min(x0, x1), y0, math.min(z0, z1)), Vector3.new(math.max(x0, x1), y1, math.max(z0, z1)), props, parent)
end
local function decoBox(name, frame, x0, y0, z0, x1, y1, z1, color, parent, extra)
	local p = box(name, frame, x0, y0, z0, x1, y1, z1, color, parent, extra)
	p.CanCollide = false
	p.CanTouch = false
	return p
end

-- Words on the −Z face of a part.
local function words(p: BasePart, text: string, color: Color3, font: Enum.Font?, name: string?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0.5
	local label = Instance.new("TextLabel")
	label.Name = name or "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.FredokaOne
	label.TextScaled = true
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

-- A wall's frame: its outer face at z = 0, the wall going in toward +z,
-- running along x. Which wall: "front", "hedge", "gate" or "back".
local function wallFrame(sf: CFrame, side: string, cells): CFrame
	local w, d = cells[1] * CELL, cells[2] * CELL
	if side == "front" then
		return sf * CFrame.new(0, 0, -S.wall)
	elseif side == "hedge" then
		return sf * CFrame.new(-w - S.wall, 0, 0) * CFrame.Angles(0, math.rad(90), 0) -- x along the wall = −z
	elseif side == "gate" then
		return sf * CFrame.new(S.wall, 0, 0) * CFrame.Angles(0, math.rad(-90), 0) -- x along the wall = z
	end
	return sf * CFrame.new(0, 0, d + S.wall) * CFrame.Angles(0, math.rad(180), 0) -- x along the wall = −x
end

-- A wall from a0 to a1 along its frame's x, y0 to y1, with rectangular
-- holes { { a0, a1, y0, y1 } } (doors and windows).
-- (inner: the inside face's colour, a thin layer, when it isn't `color`)
local function wall(wf: CFrame, a0: number, a1: number, y0: number, y1: number, holes, color: Color3, parent: Instance, inner: Color3?)
	holes = table.clone(holes) -- (sorted here; the caller's list stays in its order)
	table.sort(holes, function(p, q)
		return p[1] < q[1]
	end)
	local split = if inner and inner ~= color then S.wall - 0.15 else S.wall
	local function piece(x0, py0, x1, py1)
		box("Wall", wf, x0, py0, 0, x1, py1, split, color, parent)
		if split < S.wall then
			box("WallInside", wf, x0, py0, split, x1, py1, S.wall, inner :: Color3, parent)
		end
	end
	local cursor = a0
	for _, h in holes do
		if h[1] > cursor then
			piece(cursor, y0, h[1], y1)
		end
		if h[3] > y0 then
			piece(h[1], y0, h[2], h[3])
		end
		if h[4] < y1 then
			piece(h[1], h[4], h[2], y1)
		end
		cursor = h[2]
	end
	if cursor < a1 then
		piece(cursor, y0, a1, y1)
	end
end

-- Glass in a hole, with a frame and sill on the outside and `panes` panes.
local function window(wf: CFrame, h, trim: Color3, parent: Instance, panes: number?)
	local a0, a1, y0, y1 = h[1], h[2], h[3], h[4]
	box("Glass", wf, a0, y0, S.wall / 2 - 0.1, a1, y1, S.wall / 2 + 0.1, GLASS, parent, { Transparency = 0.5, Reflectance = 0.15 })
	decoBox("Frame", wf, a0 - 0.35, y1, -0.15, a1 + 0.35, y1 + 0.35, 0, trim, parent)
	decoBox("Frame", wf, a0 - 0.35, y0 - 0.35, -0.15, a0, y1, 0, trim, parent)
	decoBox("Frame", wf, a1, y0 - 0.35, -0.15, a1 + 0.35, y1, 0, trim, parent)
	decoBox("Sill", wf, a0 - 0.5, y0 - 0.45, -0.45, a1 + 0.5, y0, 0, trim, parent)
	local n = panes or math.max(1, math.floor((a1 - a0) / 3 + 0.5))
	for i = 1, n - 1 do
		local x = a0 + (a1 - a0) * i / n
		decoBox("Mullion", wf, x - 0.12, y0, S.wall / 2 - 0.2, x + 0.12, y1, S.wall / 2 + 0.2, trim, parent)
	end
end

-- The door's span along the front wall, and the staff door's along the gate wall.
local function doorSpan(): (number, number)
	return -Store.DOOR_X * CELL, -(Store.DOOR_X - 1) * CELL
end
local function staffSpan(): (number, number)
	return (Store.STAFF_Y - 1) * CELL, Store.STAFF_Y * CELL
end

------------------------------------------------------------------------
-- The floor: tiles on open cells, bare concrete taped off where the next
-- levels open, and a stack of "Next level!" boxes there.

local function buildFloor(sf: CFrame, building, look, level, parent: Instance)
	local cells = building.cells
	local w, d = cells[1] * CELL, cells[2] * CELL
	box("FloorSlab", sf, -w - S.wall, 0.2, -S.wall, S.wall, FLOOR - 0.1, d + S.wall, Color3.fromRGB(110, 90, 70), parent)
	local open = function(x, y)
		return x <= level.floor[1] and y <= level.floor[2]
	end
	local closed = {}
	for y = 1, cells[2] do
		for x = 1, cells[1] do
			local c = PlotLayout.storeLocal(x, y) - Vector3.new(S.right, 0, 0)
			local color = if open(x, y) then look.tiles[((x + y) % 2) + 1] else CONCRETE
			box("Tile", sf, c.X - CELL / 2 + 0.04, FLOOR - 0.1, c.Z - CELL / 2 + 0.04, c.X + CELL / 2 - 0.04, FLOOR, c.Z + CELL / 2 - 0.04, color, parent)
			if not open(x, y) then
				table.insert(closed, { x, y })
			end
		end
	end
	-- tape along the edge of the open floor (on the closed side), yellow and black
	for _, cell in closed do
		local x, y = cell[1], cell[2]
		local c = PlotLayout.storeLocal(x, y) - Vector3.new(S.right, 0, 0)
		local edges = {}
		if x - 1 >= 1 and open(x - 1, y) then
			table.insert(edges, { c.X + CELL / 2 - 0.45, c.Z, true }) -- (the edge toward the gate)
		end
		if y - 1 >= 1 and open(x, y - 1) then
			table.insert(edges, { c.X, c.Z - CELL / 2 + 0.45, false })
		end
		for _, e in edges do
			for i = 0, 3 do
				local t = -1.5 + i
				local color = if i % 2 == 0 then TAPE else COLORS.dark
				if e[3] then
					decoBox("Tape", sf, e[1] - 0.2, FLOOR, e[2] + t - 0.5, e[1] + 0.2, FLOOR + 0.05, e[2] + t + 0.5, color, parent)
				else
					decoBox("Tape", sf, e[1] + t - 0.5, FLOOR, e[2] - 0.2, e[1] + t + 0.5, FLOOR + 0.05, e[2] + 0.2, color, parent)
				end
			end
		end
	end
	-- boxes in the closed corner farthest from the door
	if #closed > 0 then
		table.sort(closed, function(a, b)
			return a[1] + a[2] * 1.01 > b[1] + b[2] * 1.01
		end)
		local c = PlotLayout.storeLocal(closed[1][1], closed[1][2]) - Vector3.new(S.right, 0, 0)
		local base = sf * CFrame.new(c.X, FLOOR, c.Z)
		local lower = Parts.part({ Name = "NextLevelBox", Size = Vector3.new(2.6, 2.2, 2.4), CFrame = base * CFrame.new(0, 1.1, 0), Color = CARDBOARD }, parent)
		Parts.part({ Name = "NextLevelBox", Size = Vector3.new(2.0, 1.6, 1.9), CFrame = base * CFrame.new(0.2, 3.0, 0.1) * CFrame.Angles(0, math.rad(18), 0), Color = CARDBOARD }, parent)
		Parts.prop({ Name = "BoxTape", Size = Vector3.new(0.5, 0.06, 2.45), CFrame = base * CFrame.new(0, 2.22, 0), Color = Color3.fromRGB(170, 130, 86) }, parent)
		local label = Parts.prop({ Name = "NextLevelLabel", Size = Vector3.new(2.2, 1.2, 0.05), CFrame = base * CFrame.new(0, 1.2, -1.23), Color = CARDBOARD }, parent)
		words(label, "NEXT LEVEL!", COLORS.dark)
	end
end

------------------------------------------------------------------------
-- The staff door (owner only): a leaf that swings open, and an invisible
-- blocker that stops everyone but the owner (their own client lets them
-- through: StoreController).

local function buildStaffDoor(sf: CFrame, parent: Instance)
	local s0, s1 = staffSpan()
	local door = Instance.new("Model")
	door.Name = "StaffDoor"
	local wf = sf * CFrame.new(S.wall, 0, 0) * CFrame.Angles(0, math.rad(-90), 0)
	local leaf = box("Leaf", wf, s0 + 0.1, FLOOR, 0.35, s1 - 0.1, DOOR_TOP - 0.1, 0.65, COLORS.cream, door)
	leaf.CanCollide = false
	-- the sign faces into the store (the wall frame's +z)
	local plate = Parts.prop({ Name = "Plate", Size = Vector3.new(2.2, 0.7, 0.06), CFrame = leaf.CFrame * CFrame.new(0, 1.2, 0.18) * CFrame.Angles(0, math.pi, 0), Color = COLORS.barnRed }, door)
	words(plate, "STAFF ONLY", COLORS.cream)
	for _, z in { -0.2, 0.2 } do
		Parts.prop({ Name = "Knob", Size = Vector3.new(0.3, 0.3, 0.3), Shape = Enum.PartType.Ball, CFrame = leaf.CFrame * CFrame.new(1.4, -0.6, z), Color = GOLD }, door)
	end
	door.WorldPivot = wf * CFrame.new(s0 + 0.1, FLOOR, 0.5) -- the hinge
	local blocker = box("StaffDoorBlocker", wf, s0, FLOOR, 0, s1, PlotLayout.FENCE_BLOCK, S.wall, COLORS.cream, door,
		{ Transparency = 1, CanQuery = false, CanTouch = false })
	blocker:SetAttribute("StaffDoor", true)
	door.Parent = parent
	-- frame
	decoBox("DoorFrame", wf, s0 - 0.35, DOOR_TOP, -0.15, s1 + 0.35, DOOR_TOP + 0.4, 0, COLORS.post, parent)
end

-- Swings the staff door open (for the owner) or shut.
function StoreArt.setStaffDoor(model: Model, open: boolean)
	local door = model:FindFirstChild("Store") and model.Store:FindFirstChild("Building") and model.Store.Building:FindFirstChild("StaffDoor")
	if not door or door:GetAttribute("Open") == open then
		return
	end
	door:SetAttribute("Open", open)
	local hinge = door.WorldPivot
	local angle = if open then math.rad(100) else 0 -- (out into the yard)
	for _, part in door:GetChildren() do
		if not part:IsA("BasePart") or part.Name == "StaffDoorBlocker" then
			continue
		end
		local rest = part:GetAttribute("Rest")
		if not rest then
			rest = hinge:ToObjectSpace(part.CFrame)
			part:SetAttribute("Rest", rest)
		end
		part.CFrame = hinge * CFrame.Angles(0, angle, 0) * rest
	end
end

------------------------------------------------------------------------
-- The buildings

-- The stockroom: a lean-to behind the back wall, open to the yard.
local function buildStockroom(sf: CFrame, building, look, parent: Instance)
	local w, d = building.cells[1] * CELL, building.cells[2] * CELL
	local z0, z1 = d + S.wall, d + S.wall + S.backRoom
	local high, low = look.height - 1.5, math.max(8, look.height - 8)
	box("StockroomFloor", sf, -w - S.wall, 0.2, z0, S.wall, FLOOR - 0.1, z1 + S.wall, CONCRETE, parent)
	local rise, run = high - low, S.backRoom + S.wall
	for _, x in { -w - S.wall, 0 } do
		box("Wall", sf, x, FLOOR - 0.1, z0, x + S.wall, low, z1 + S.wall, look.wall, parent)
		-- the triangle up to the sloping roof
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Wall"
		wedge.Anchored = true
		wedge.Material = Enum.Material.SmoothPlastic
		wedge.Color = look.wall
		wedge.Size = Vector3.new(S.wall, rise, run)
		wedge.CFrame = sf * CFrame.new(x + S.wall / 2, low + rise / 2, z0 + run / 2) * CFrame.Angles(0, math.pi, 0) -- (tall side against the back wall)
		wedge.Parent = parent
	end
	-- the yard side: open, with posts holding the lintel
	local posts = math.max(1, math.round(w / 16) - 1) -- (about 16 studs apart)
	for i = 1, posts do
		local x = -w * i / (posts + 1)
		box("Post", sf, x - 0.5, FLOOR - 0.1, z1, x + 0.5, low - 1, z1 + S.wall, look.trim, parent)
	end
	decoBox("Lintel", sf, -w, low - 1, z1, 0, low, z1 + S.wall, look.trim, parent)
	local length = math.sqrt(rise * rise + run * run)
	local roof = Parts.part({
		Name = "StockroomRoof",
		Size = Vector3.new(w + S.wall * 2 + 1, 0.5, length + 0.6),
		CFrame = sf * CFrame.new(-w / 2, (high + low) / 2 + 0.25, (z0 + z1 + S.wall) / 2) * CFrame.Angles(math.atan2(rise, run), 0, 0),
		Color = SLATE_ROOF,
	}, parent)
	roof.Parent = parent
	local sign = decoBox("StockroomSign", sf, -w / 2 - 4, low - 0.95, z1 + S.wall + 0.05, -w / 2 + 4, low - 0.05, z1 + S.wall + 0.15, COLORS.cream, parent)
	-- (the sign faces the yard: +z)
	sign.CFrame = sign.CFrame * CFrame.Angles(0, math.pi, 0)
	words(sign, "STOCKROOM", COLORS.dark)
	local crates = Instance.new("Folder")
	crates.Name = "StockroomCrates"
	crates.Parent = parent
end

-- A hanging sign with the store's name (StoreArt.setName changes it).
local function nameSign(cf: CFrame, size: Vector3, board: Color3, ink: Color3, frameColor: Color3, parent: Instance)
	Parts.prop({ Name = "SignFrame", Size = size + Vector3.new(0.6, 0.6, -0.1), CFrame = cf * CFrame.new(0, 0, 0.1), Color = frameColor }, parent)
	local p = Parts.prop({ Name = "SignBoard", Size = size, CFrame = cf, Color = board }, parent)
	words(p, "", ink, Enum.Font.FredokaOne, "StoreName")
	return p
end

local MAX_LIGHTS = 6 -- PointLights in one store (the rest of the lamps just glow: phones drop extra lights)

local function pointLight(lamp: BasePart, range: number)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 236, 200)
	light.Range = range
	light.Brightness = 0.45 -- (several overlap in a room: brighter washes the walls out)
	light.Shadows = false
	light.Parent = lamp
end

-- Ceiling lamps in a grid about 16 studs apart (on cords under a gable
-- roof); the Supermarket has long light strips across its ceiling instead.
local function lamps(sf: CFrame, building, look, parent: Instance)
	local w, d = building.cells[1] * CELL, building.cells[2] * CELL
	local height = look.height
	local glow = Color3.fromRGB(255, 244, 214)
	if building.id == "Supermarket" then
		local strips = math.max(2, math.round(w / 12))
		for i = 1, strips do
			local x = -w * (i - 0.5) / strips
			local strip = Parts.prop({ Name = "LightStrip", Size = Vector3.new(0.7, 0.25, d - 8), CFrame = sf * CFrame.new(x, height - 0.3, d / 2),
				Color = glow, Material = Enum.Material.Neon }, parent)
			Parts.prop({ Name = "StripHousing", Size = Vector3.new(1.1, 0.2, d - 7.6), CFrame = sf * CFrame.new(x, height - 0.1, d / 2), Color = STEEL }, parent)
			if (i - 1) % math.ceil(strips / MAX_LIGHTS) == 0 then
				pointLight(strip, 30)
			end
		end
		return
	end
	local across, deep = math.max(2, math.round(w / 16)), math.max(1, math.round(d / 16))
	local every = math.ceil(across * deep / MAX_LIGHTS)
	local n = 0
	for i = 1, across do
		for j = 1, deep do
			local x, z = -w * (i - 0.5) / across, d * (j - 0.5) / deep
			local lamp = Parts.prop({ Name = "CeilingLamp", Size = Vector3.new(2.4, 0.3, 1.2), CFrame = sf * CFrame.new(x, height - 0.35, z),
				Color = glow, Material = Enum.Material.Neon }, parent)
			if look.gable then
				-- (no flat ceiling: it hangs on a cord from the roof, which rises toward the ridge)
				local half = w / 2 + S.wall + 0.8
				local roof = height + look.gable * (1 - math.abs(x + w / 2) / half) - 0.3
				local cord = roof - (height - 0.2)
				Parts.prop({ Name = "LampCord", Size = Vector3.new(0.1, cord, 0.1), CFrame = sf * CFrame.new(x, height - 0.2 + cord / 2, z), Color = COLORS.dark }, parent)
				Parts.prop({ Name = "LampShade", Size = Vector3.new(2.7, 0.35, 1.5), CFrame = sf * CFrame.new(x, height - 0.05, z), Color = COLORS.leafDark }, parent)
			end
			if n % every == 0 then
				pointLight(lamp, 20 + 4 * (every - 1))
			end
			n += 1
		end
	end
end

-- The Corner Store: cream timber, a false front with the hand-painted name,
-- a striped awning in the farm colour.
local function cornerStore(sf, building, look, color, roof, parent)
	local w, d, h = building.cells[1] * CELL, building.cells[2] * CELL, look.height
	local front = wallFrame(sf, "front", building.cells)
	local d0, d1 = doorSpan()
	local holes = { { d0, d1, FLOOR, DOOR_TOP }, { -6.6, -1.4, 3, 7.4 }, { -w + 0.8, d0 - 1, 3, 7.4 } }
	wall(front, -w - S.wall, S.wall, FLOOR - 0.1, h, holes, look.wall, parent, look.inner)
	window(front, holes[2], look.trim, parent, 2)
	window(front, holes[3], look.trim, parent)
	-- corner posts
	for _, x in { -w - S.wall - 0.2, S.wall + 0.2 } do
		for _, z in { -S.wall - 0.2, d + S.wall + 0.2 } do
			box("CornerPost", sf, x - 0.6, FLOOR - 0.1, z - 0.6, x + 0.6, h + 0.3, z + 0.6, look.trim, parent)
		end
	end
	-- the false front, its cornice, and the sign
	box("FalseFront", sf, -w - S.wall, h, -S.wall, S.wall, h + 4, -S.wall + 0.6, look.wall, roof)
	box("Cornice", sf, -w - S.wall - 0.4, h + 4, -S.wall - 0.4, S.wall + 0.4, h + 4.5, -S.wall + 0.8, look.trim, roof)
	nameSign(sf * CFrame.new(-w / 2, h + 2, -S.wall - 0.2), Vector3.new(w - 6, 2.6, 0.2), Color3.fromRGB(236, 214, 170), COLORS.barnRed, color, roof)
	-- the awning: stripes in the farm colour and cream, sloping toward the road
	local stripes = math.floor(w / 2)
	for i = 0, stripes - 1 do
		local x = -w + (i + 0.5) * (w + S.wall) / stripes - S.wall / 2
		Parts.prop({
			Name = "Awning", Size = Vector3.new((w + S.wall) / stripes, 0.25, 4.4),
			CFrame = sf * CFrame.new(x, 8.6, -S.wall - 2.1) * CFrame.Angles(math.rad(-20), 0, 0),
			Color = if i % 2 == 0 then color else COLORS.cream,
		}, parent)
		Parts.prop({ Name = "Valance", Size = Vector3.new((w + S.wall) / stripes, 0.7, 0.15), CFrame = sf * CFrame.new(x, 7.55, -S.wall - 4.2),
			Color = if i % 2 == 0 then color else COLORS.cream }, parent)
	end
	-- the roof (flat, a little overhang)
	box("Roof", sf, -w - S.wall - 0.6, h, -S.wall + 0.6, S.wall + 0.6, h + 0.6, d + S.wall + 0.6, SLATE_ROOF, roof)
	-- a bench-height planter under the big window
	box("Planter", sf, -w + 1, 0, -S.wall - 1.3, d0 - 1.5, 1.2, -S.wall, COLORS.post, parent)
	local blooms = math.max(4, math.floor((d0 - 2.5 + w - 2) / 3.5))
	for i = 0, blooms do
		local x = -w + 2 + i * ((d0 - 2.5) - (-w + 2)) / blooms
		Parts.ball("Flowers", sf * CFrame.new(x, 1.5, -S.wall - 0.65), 1.0, { Color = if i % 2 == 0 then color else COLORS.leaf }, parent)
	end
end

-- The Farm Shop: a red barn with white trim, a big window and a gable roof.
local function farmShop(sf, building, look, color, roof, parent)
	local w, d, h = building.cells[1] * CELL, building.cells[2] * CELL, look.height
	local front = wallFrame(sf, "front", building.cells)
	local d0, d1 = doorSpan()
	-- two big windows between the door and the hedge end, a pier between them
	local a0, a1 = -w + 1.5, d0 - 1.5
	local mid = (a0 + a1) / 2
	local holes = { { d0, d1, FLOOR, DOOR_TOP }, { a0, mid - 1.5, 2.5, 7.8 }, { mid + 1.5, a1, 2.5, 7.8 } }
	wall(front, -w - S.wall, S.wall, FLOOR - 0.1, h, holes, look.wall, parent, look.inner)
	window(front, holes[2], look.trim, parent)
	window(front, holes[3], look.trim, parent)
	-- the barn door slid open beside the doorway, X-braced in white
	local dw = d1 - d0
	local doorHeight = DOOR_TOP - FLOOR
	box("BarnDoor", front, d1 + 0.2, FLOOR, -0.4, d1 + 0.2 + dw, DOOR_TOP, -0.1, look.wall, parent).CanCollide = false
	for _, slant in { 1, -1 } do
		Parts.prop({
			Name = "Brace", Size = Vector3.new(math.sqrt(dw * dw + doorHeight * doorHeight) - 0.6, 0.35, 0.1),
			CFrame = front * CFrame.new(d1 + 0.2 + dw / 2, FLOOR + doorHeight / 2, -0.45) * CFrame.Angles(0, 0, math.atan2(doorHeight, dw) * slant),
			Color = look.trim,
		}, parent)
	end
	decoBox("Track", front, d0 - 0.3, DOOR_TOP + 0.1, -0.3, d1 + dw + 0.6, DOOR_TOP + 0.45, 0, COLORS.dark, parent)
	-- corner boards and the eave band
	for _, x in { -w - S.wall - 0.15, S.wall + 0.15 } do
		for _, z in { -S.wall - 0.15, d + S.wall + 0.15 } do
			box("CornerBoard", sf, x - 0.55, FLOOR - 0.1, z - 0.55, x + 0.55, h, z + 0.55, look.trim, parent)
		end
	end
	decoBox("EaveBand", sf, -w - S.wall - 0.2, h - 0.5, -S.wall - 0.15, S.wall + 0.2, h, -S.wall, look.trim, parent)
	-- the gable roof, ridge front to back
	local half = w / 2 + S.wall + 0.8
	local rise = look.gable
	local slope = math.atan2(rise, half)
	local length = math.sqrt(half * half + rise * rise)
	for _, side in { -1, 1 } do
		Parts.part({
			Name = "Roof", Size = Vector3.new(length, 0.6, d + S.wall * 2 + 1.6),
			CFrame = sf * CFrame.new(-w / 2 + side * half / 2, h + rise / 2 + 0.3, d / 2) * CFrame.Angles(0, 0, -side * slope),
			Color = SLATE_ROOF,
		}, roof)
	end
	-- the gables, front and back: two wedges each, in the wall colour
	for _, z in { -S.wall, d } do
		for _, side in { -1, 1 } do
			local wedge = Instance.new("WedgePart")
			wedge.Name = "Gable"
			wedge.Anchored = true
			wedge.Material = Enum.Material.SmoothPlastic
			wedge.Color = look.wall
			wedge.Size = Vector3.new(S.wall, rise, w / 2 + S.wall)
			-- (a wedge's slope runs from its top-back edge down to its front-bottom; turned so it rises toward the ridge)
			wedge.CFrame = sf * CFrame.new(-w / 2 + side * (w / 2 + S.wall) / 2, h + rise / 2, z + S.wall / 2) * CFrame.Angles(0, math.rad(-90 * side), 0)
			wedge.Parent = roof
		end
	end
	-- a hayloft door on the front gable, and the name sign under it
	decoBox("Hayloft", sf, -w / 2 - 2, h + 0.6, -S.wall - 0.15, -w / 2 + 2, h + 4.6, -S.wall, look.trim, roof)
	decoBox("HayloftDoor", sf, -w / 2 - 1.6, h + 0.9, -S.wall - 0.25, -w / 2 + 1.6, h + 4.3, -S.wall - 0.1, look.wall, roof)
	-- the name over the windows (clear of the door's awning)
	nameSign(sf * CFrame.new(mid, 9.7, -S.wall - 0.25), Vector3.new(math.min(a1 - a0 - 4, 26), 2.2, 0.2), COLORS.cream, COLORS.barnRed, color, parent)
	-- a little awning over the door in the farm colour
	for i = 0, 2 do
		Parts.prop({ Name = "Awning", Size = Vector3.new((dw + 2) / 3, 0.25, 2.6),
			CFrame = sf * CFrame.new(d1 + 1 - (i + 0.5) * (dw + 2) / 3, DOOR_TOP + 0.9, -S.wall - 1.2) * CFrame.Angles(math.rad(-18), 0, 0),
			Color = if i % 2 == 0 then color else COLORS.cream }, parent)
	end
end

-- The Market Hall: brick below, timber above, arched windows, a clock.
local function marketHall(sf, building, look, color, roof, parent)
	local w, d, h = building.cells[1] * CELL, building.cells[2] * CELL, look.height
	local front = wallFrame(sf, "front", building.cells)
	local d0, d1 = doorSpan()
	local holes = { { d0, d1, FLOOR, DOOR_TOP }, { -6, -2, 3, 8 } }
	-- arched windows spread evenly from the door to the hedge end
	local span0, span1 = -w + 2, d0 - 2
	local count = math.max(1, math.floor((span1 - span0 + 4) / 10))
	local arched = {}
	for i = 1, count do
		local x = span1 - (span1 - span0) * (i - 0.5) / count
		table.insert(arched, x)
		table.insert(holes, { x - 3, x + 3, 3, 8 })
	end
	wall(front, -w - S.wall, S.wall, FLOOR - 0.1, 9, holes, look.wall, parent, look.inner)
	-- the timber storey above: the name in the middle, a little window in
	-- each bay either side of it
	local signWidth = math.min(w - 24, 30)
	local bays = math.floor(w / 6)
	local upper = {}
	for i = 0, bays - 1 do
		local x = -w + (i + 0.5) * w / bays
		if math.abs(x + w / 2) > signWidth / 2 + 3 then
			table.insert(upper, { x - 1.1, x + 1.1, 11, 13.4 })
		end
	end
	wall(front, -w - S.wall, S.wall, 9, h, upper, COLORS.cream, parent, look.inner)
	for _, hole in upper do
		window(front, hole, COLORS.post, parent, 1)
	end
	for i = 0, bays do
		local x = -w + i * w / bays
		decoBox("Timber", front, x - 0.3, 9, -0.12, x + 0.3, h, 0, COLORS.post, parent)
	end
	decoBox("Beam", front, -w - S.wall, 9, -0.15, S.wall, 9.5, 0, COLORS.post, parent)
	for i, h2 in holes do
		if i > 1 then
			window(front, h2, look.trim, parent, 2)
			-- an arch of stones over the window, a cream keystone at the top
			local mid, radius = (h2[1] + h2[2]) / 2, (h2[2] - h2[1]) / 2 + 0.5
			for k = 0, 6 do
				local a = math.pi * k / 6
				Parts.prop({
					Name = "ArchStone", Size = Vector3.new(if k == 3 then 0.9 else 0.7, 0.55, 0.3),
					CFrame = front * CFrame.new(mid + math.cos(a) * radius, h2[4] + 0.4 + math.sin(a) * radius * 0.45, -0.2) * CFrame.Angles(0, 0, a - math.pi / 2),
					Color = if k == 3 then COLORS.cream else Color3.fromRGB(140, 62, 46),
				}, parent)
			end
		end
	end
	-- double doors swung open
	for _, side in { -1, 1 } do
		local hinge = if side < 0 then d0 else d1
		box("Door", front, hinge, FLOOR, 0, hinge - side * 0.3, DOOR_TOP - 0.2, 2, COLORS.post, parent).CanCollide = false
	end
	box("Roof", sf, -w - S.wall - 0.5, h, -S.wall, S.wall + 0.5, h + 0.6, d + S.wall + 0.5, SLATE_ROOF, roof)
	box("Cornice", sf, -w - S.wall - 0.6, h - 0.5, -S.wall - 0.6, S.wall + 0.6, h + 0.2, -S.wall + 0.2, COLORS.post, roof)
	-- the raised middle of the front with the clock
	local raised = signWidth / 2 - 4
	box("Parapet", sf, -w / 2 - raised, h, -S.wall, -w / 2 + raised, h + 4.5, -S.wall + 0.8, look.wall, roof)
	box("ParapetCap", sf, -w / 2 - raised - 0.4, h + 4.5, -S.wall - 0.3, -w / 2 + raised + 0.4, h + 5, -S.wall + 1.1, COLORS.cream, roof)
	local clock = Parts.prop({ Name = "ClockFace", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.4, 3.4),
		CFrame = sf * CFrame.new(-w / 2, h + 2.3, -S.wall - 0.1) * CFrame.Angles(0, math.rad(90), 0), Color = COLORS.cream }, roof)
	Parts.prop({ Name = "ClockRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 3.9, 3.9),
		CFrame = clock.CFrame * CFrame.new(0.1, 0, 0), Color = COLORS.post }, roof)
	Parts.prop({ Name = "Hand", Size = Vector3.new(0.2, 1.3, 0.1), CFrame = sf * CFrame.new(-w / 2, h + 2.85, -S.wall - 0.3), Color = COLORS.dark }, roof)
	Parts.prop({ Name = "Hand", Size = Vector3.new(0.2, 1.0, 0.1), CFrame = sf * CFrame.new(-w / 2 + 0.35, h + 2.15, -S.wall - 0.32) * CFrame.Angles(0, 0, math.rad(-100)), Color = COLORS.dark }, roof)
	nameSign(sf * CFrame.new(-w / 2, 12, -S.wall - 0.2), Vector3.new(signWidth, 3, 0.2), COLORS.cream, COLORS.barnRed, color, parent)
	-- window boxes of flowers in the farm colour under the arched windows
	for _, x in arched do
		Parts.prop({ Name = "WindowBox", Size = Vector3.new(6.2, 0.9, 1.0), CFrame = sf * CFrame.new(x, 2.1, -S.wall - 0.95), Color = color }, parent)
		for j = 0, 4 do
			Parts.ball("Flowers", sf * CFrame.new(x - 2.4 + j * 1.2, 2.75, -S.wall - 0.95), 0.9,
				{ Color = if j % 2 == 0 then COLORS.leaf else COLORS.cream }, parent)
		end
	end
end

-- The Supermarket: a tall glass front, a deep band in the farm colour with
-- the name, a canopy over the entrance, a trolley bay by the road, and a
-- billboard on the roof facing it.
local function supermarket(sf, building, look, color, roof, parent, level)
	local w, d, h = building.cells[1] * CELL, building.cells[2] * CELL, look.height
	local front = wallFrame(sf, "front", building.cells)
	local d0, d1 = doorSpan()
	local glassTop = 12
	-- the glass front: panels from the plinth to 12, the door open in it (the
	-- plinth stops either side of it: across the doorway it was a ledge
	-- characters stalled at)
	box("Plinth", front, -w - S.wall, FLOOR - 0.1, 0, d0, 1.2, S.wall, Color3.fromRGB(90, 96, 104), parent)
	box("Plinth", front, d1, FLOOR - 0.1, 0, S.wall, 1.2, S.wall, Color3.fromRGB(90, 96, 104), parent)
	wall(front, -w - S.wall, S.wall, glassTop, h, {}, look.wall, parent, look.inner)
	local glass = { Transparency = 0.45, Reflectance = 0.2 }
	for x = -w, -CELL, CELL do
		if x + CELL <= d0 or x >= d1 then
			box("Glass", front, x, 1.2, S.wall / 2 - 0.1, x + CELL, glassTop, S.wall / 2 + 0.1, GLASS, parent, glass)
		end
	end
	box("Glass", front, -w - S.wall, 1.2, S.wall / 2 - 0.1, -w, glassTop, S.wall / 2 + 0.1, GLASS, parent, glass)
	box("Glass", front, 0, 1.2, S.wall / 2 - 0.1, S.wall, glassTop, S.wall / 2 + 0.1, GLASS, parent, glass)
	box("Transom", front, d0, DOOR_TOP, S.wall / 2 - 0.1, d1, glassTop, S.wall / 2 + 0.1, GLASS, parent, { Transparency = 0.45 })
	for x = -w, 0, CELL do
		if x ~= d0 + CELL and x ~= d0 then -- (none across the doorway)
			decoBox("Mullion", front, x - 0.15, 1.2, -0.1, x + 0.15, glassTop, 0, STEEL, parent)
		end
	end
	decoBox("GlassRail", front, -w - S.wall, glassTop - 0.3, -0.12, S.wall, glassTop, 0, STEEL, parent)
	-- the sliding doors, open
	for _, side in { -1, 1 } do
		local x = if side < 0 then d0 - 1.9 else d1 + 0.1
		decoBox("SlidingDoor", front, x, 1.2, -0.35, x + 1.8, DOOR_TOP, -0.15, GLASS, parent, { Transparency = 0.4 })
	end
	-- the band with the name
	box("Fascia", sf, -w - S.wall - 0.3, glassTop, -S.wall - 0.4, S.wall + 0.3, h, -S.wall, color, parent)
	local band = Parts.prop({ Name = "SignBoard", Size = Vector3.new(w - 12, 4.2, 0.1), CFrame = sf * CFrame.new(-w / 2, (glassTop + h) / 2, -S.wall - 0.46), Color = color }, parent)
	words(band, "", COLORS.cream, Enum.Font.FredokaOne, "StoreName")
	decoBox("FasciaTrim", sf, -w - S.wall - 0.4, glassTop - 0.2, -S.wall - 0.55, S.wall + 0.4, glassTop + 0.2, -S.wall, WHITE, parent)
	-- the canopy over the entrance, hung from the band on tie rods (the
	-- sidewalk runs right under it: no posts)
	local c0, c1 = d0 - 6, d1 + 5
	local reach = 3.2
	decoBox("Canopy", sf, c0, 9.6, -S.wall - reach, c1, 10.1, -S.wall, WHITE, parent)
	decoBox("CanopyEdge", sf, c0 - 0.1, 9.2, -S.wall - reach - 0.1, c1 + 0.1, 10.2, -S.wall - reach + 0.1, color, parent)
	for _, x in { c0 + 1, c1 - 1 } do
		local from = sf * Vector3.new(x, glassTop + 0.7, -S.wall - 0.5) -- (just above the band's trim, under the name)
		local to = sf * Vector3.new(x, 10.1, -S.wall - reach + 0.3)
		Parts.prop({ Name = "TieRod", Size = Vector3.new(0.15, 0.15, (to - from).Magnitude), CFrame = CFrame.lookAt((from + to) / 2, to), Color = STEEL }, parent)
	end
	-- a trolley bay on the verge at the hedge end (where the verge is widest)
	local bay = Instance.new("Model")
	bay.Name = "TrolleyBay"
	local bx = -w + 6
	box("BayRail", sf, bx - 4, 2.2, -S.wall - 4.6, bx + 4, 2.5, -S.wall - 4.3, STEEL, bay)
	for _, x in { bx - 4, bx + 4 } do
		box("BayPost", sf, x - 0.2, 0, -S.wall - 4.6, x + 0.2, 2.5, -S.wall - 4.3, STEEL, bay)
	end
	for i = 0, 3 do
		local tx = bx - 3 + i * 2
		decoBox("Trolley", sf, tx - 0.8, 1.0, -S.wall - 4.0, tx + 0.8, 2.6, -S.wall - 1.6, Color3.fromRGB(150, 158, 168), bay, { Transparency = 0.3 })
		decoBox("TrolleyHandle", sf, tx - 0.85, 2.6, -S.wall - 4.15, tx + 0.85, 2.85, -S.wall - 3.95, color, bay)
		for _, z in { -S.wall - 3.7, -S.wall - 1.9 } do
			decoBox("Wheel", sf, tx - 0.6, 0, z - 0.15, tx + 0.6, 0.3, z + 0.15, COLORS.dark, bay)
		end
	end
	bay.Parent = parent
	box("Roof", sf, -w - S.wall - 0.3, h, -S.wall, S.wall + 0.3, h + 0.5, d + S.wall + 0.3, Color3.fromRGB(150, 150, 150), roof)
	box("Coping", sf, -w - S.wall - 0.4, h + 0.5, -S.wall - 0.4, S.wall + 0.4, h + 1, -S.wall + 0.6, WHITE, roof)
	-- rooftop units along the back
	for i = 1, 3 do
		local x = -w * i / 4
		box("AirUnit", sf, x - 2.5, h + 0.5, d - 9, x + 2.5, h + 3, d - 4, Color3.fromRGB(180, 184, 188), roof)
		decoBox("Fan", sf, x - 1.5, h + 3, d - 7.5, x + 1.5, h + 3.15, d - 5.5, COLORS.dark, roof)
	end
	-- the billboard
	local bz = d * 0.45
	for _, x in { -w / 2 - 10, -w / 2 + 10 } do
		box("BillboardPost", sf, x - 0.5, h + 0.5, bz - 0.5, x + 0.5, h + 9, bz + 0.5, STEEL, roof)
	end
	box("BillboardFrame", sf, -w / 2 - 16, h + 8.5, bz - 0.5, -w / 2 + 16, h + 17, bz, COLORS.post, roof)
	local board = Parts.prop({ Name = "Billboard", Size = Vector3.new(31, 7.5, 0.1), CFrame = sf * CFrame.new(-w / 2, h + 12.75, bz - 0.55), Color = COLORS.cream }, roof)
	words(board, "", color, Enum.Font.FredokaOne, "StoreName")
	if level.goldStar then
		local star = Parts.prop({ Name = "GoldStar", Size = Vector3.new(10, 10, 0.2), CFrame = sf * CFrame.new(-w / 2, h + 22, bz - 0.4),
			Transparency = 1 }, roof)
		local label = words(star, "★", GOLD)
		label.TextStrokeColor3 = Color3.fromRGB(150, 100, 22)
		label.TextStrokeTransparency = 0
	end
end

local BUILDERS = { CornerStore = cornerStore, FarmShop = farmShop, MarketHall = marketHall, Supermarket = supermarket }

-- The side and back walls every building shares: a window on the hedge
-- side, the staff door on the gate side.
local function sideWalls(sf, building, look, parent)
	local d = building.cells[2] * CELL
	local hedge = wallFrame(sf, "hedge", building.cells)
	local windowSpan = { -(d * 0.75), -(d * 0.35), 3.2, 7.6 }
	wall(hedge, -d, 0, FLOOR - 0.1, look.height, { windowSpan }, look.wall, parent, look.inner)
	window(hedge, windowSpan, look.trim, parent)
	local gate = wallFrame(sf, "gate", building.cells)
	local s0, s1 = staffSpan()
	wall(gate, 0, d, FLOOR - 0.1, look.height, { { s0, s1, FLOOR, DOOR_TOP } }, look.wall, parent, look.inner)
	decoBox("DoorFrame", gate, s0 - 0.35, FLOOR, -0.15, s0, DOOR_TOP, 0, look.trim, parent)
	decoBox("DoorFrame", gate, s1, FLOOR, -0.15, s1 + 0.35, DOOR_TOP, 0, look.trim, parent)
	local back = wallFrame(sf, "back", building.cells)
	wall(back, -S.wall, building.cells[1] * CELL + S.wall, FLOOR - 0.1, look.height, {}, look.wall, parent, look.inner)
	-- the front door's frame and a step up from the sidewalk
	local front = wallFrame(sf, "front", building.cells)
	local d0, d1 = doorSpan()
	decoBox("DoorFrame", front, d0 - 0.4, FLOOR, -0.2, d0, DOOR_TOP + 0.4, 0, look.trim, parent)
	decoBox("DoorFrame", front, d1, FLOOR, -0.2, d1 + 0.4, DOOR_TOP + 0.4, 0, look.trim, parent)
	decoBox("DoorFrame", front, d0 - 0.4, DOOR_TOP, -0.2, d1 + 0.4, DOOR_TOP + 0.4, 0, look.trim, parent)
	box("Step", front, d0 - 0.5, 0, -1.6, d1 + 0.5, FLOOR - 0.25, 0, CONCRETE, parent)
end

-- Invisible walls on the building's outline (not the front door), as tall as
-- the fences' (PlotLayout.FENCE_BLOCK): the store is never a way into the farm.
local function blockers(sf, building, parent)
	local w, d = building.cells[1] * CELL, building.cells[2] * CELL
	local d0, d1 = doorSpan()
	local props = { Transparency = 1, CanQuery = false, CanTouch = false }
	local top = PlotLayout.FENCE_BLOCK
	box("StoreFrontBlocker", sf, -w - S.wall, 0, -S.wall, d0, top, 0, COLORS.cream, parent, props)
	box("StoreFrontBlocker", sf, d1, 0, -S.wall, S.wall, top, 0, COLORS.cream, parent, props)
	box("StoreSideBlocker", sf, -w - S.wall, 0, 0, -w, top, d + S.wall, COLORS.cream, parent, props)
	box("StoreBackBlocker", sf, -w - S.wall, 0, d, S.wall, top, d + S.wall, COLORS.cream, parent, props)
	local s0, s1 = staffSpan()
	box("StoreSideBlocker", sf, 0, 0, 0, S.wall, top, s0, COLORS.cream, parent, props)
	box("StoreSideBlocker", sf, 0, 0, s1, S.wall, top, d, COLORS.cream, parent, props)
end

------------------------------------------------------------------------
-- The fence from the hedge to the store (the rest of the front is
-- WorldBuilder's): it gets shorter as the store gets wider.

local function buildFence(model: Model, index: number, building)
	local old = model.Store:FindFirstChild("Fence")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Model")
	folder.Name = "Fence"
	local storeEdge = S.right - building.cells[1] * CELL - S.wall
	local hedge = -PlotLayout.WIDTH / 2
	local frame = PlotLayout.frame(index)
	if storeEdge - hedge >= 3 then
		Parts.picketFence(frame, Vector3.new(hedge, 0, -1), Vector3.new(storeEdge, 0, 0), folder, "FrontFenceShopSide")
	else
		-- (the Supermarket reaches the hedge: a post closes the last stud)
		plotBox("FenceEndPost", frame, Vector3.new(hedge, 0, -1.2), Vector3.new(storeEdge, PlotLayout.FENCE_HEIGHT + 0.3, 0.2), { Color = COLORS.fence }, folder)
		plotBox("FrontFenceShopSideBlocker", frame, Vector3.new(hedge, 0, -1), Vector3.new(storeEdge, PlotLayout.FENCE_BLOCK, 0),
			{ Transparency = 1, CanQuery = false, CanTouch = false }, folder)
	end
	folder.Parent = model.Store
end

------------------------------------------------------------------------
-- Building it all

local function storeModel(model: Model): Model
	local store = model:FindFirstChild("Store")
	if not store then
		store = Instance.new("Model")
		store.Name = "Store"
		store.Parent = model
		local items = Instance.new("Folder")
		items.Name = "Items"
		items.Parent = store
	end
	return store
end

-- Builds (or rebuilds) the building for a Store Level: the floor as open as
-- that level, the walls, roof and stockroom of its building, the fence
-- beside it. `name` is the sign's text.
function StoreArt.buildBuilding(model: Model, levelNumber: number, name: string)
	local index = model:GetAttribute("PlotIndex")
	local store = storeModel(model)
	local old = store:FindFirstChild("Building")
	if old then
		old:Destroy()
	end
	local level = StoreLayout.level(levelNumber)
	local building = level.building
	local look = LOOK[building.id]
	local color = Parts.farmColor(index)
	local sf = storeFrame(index)
	local folder = Instance.new("Model")
	folder.Name = "Building"
	-- The roof, what stands on it and the ceiling lamps: hidden on your own
	-- screen while you decorate (DecorateController) or while you're inside,
	-- the room's box being the "Interior" part (RoofController)
	local roof = Instance.new("Model")
	roof.Name = "Roof"
	roof.Parent = folder
	local w, d = building.cells[1] * CELL, building.cells[2] * CELL
	box("Interior", sf, -w, FLOOR, 0, 0, look.height, d, COLORS.cream, folder,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	buildFloor(sf, building, look, level, folder)
	sideWalls(sf, building, look, folder)
	BUILDERS[building.id](sf, building, look, color, roof, folder, level)
	buildStockroom(sf, building, look, folder)
	buildStaffDoor(sf, folder)
	blockers(sf, building, folder)
	lamps(sf, building, look, roof) -- (their lights keep shining with the roof hidden)
	folder:SetAttribute("Stage", level.stage)
	folder:SetAttribute("Level", level.number)
	folder.Parent = store
	model:SetAttribute("StoreStage", level.stage)
	buildFence(model, index, building)
	StoreArt.setName(model, name)
end

-- The name on the store's signs.
function StoreArt.setName(model: Model, name: string)
	model:SetAttribute("StoreName", name)
	local store = model:FindFirstChild("Store")
	for _, label in (store and store:GetDescendants()) or {} do
		if label:IsA("TextLabel") and label.Name == "StoreName" then
			label.Text = name
		end
	end
end

------------------------------------------------------------------------
-- Items on the floor

-- Lays out every item (removing what's no longer there). Returns the Items folder.
function StoreArt.placeItems(model: Model, layout, stage: number)
	local index = model:GetAttribute("PlotIndex")
	local items = storeModel(model).Items
	local catalog = ReplicatedStorage:FindFirstChild("StoreCatalog")
	for _, child in items:GetChildren() do
		local entry = layout[child.Name]
		if not entry or child:GetAttribute("Item") ~= entry.item then
			child:Destroy()
		end
	end
	for id, entry in layout do
		local item = items:FindFirstChild(id)
		if not item then
			item = catalog[entry.item]:Clone()
			item.Name = id
			item:SetAttribute("Item", entry.item)
			item.Parent = items
		end
		item:PivotTo(PlotLayout.storeItemFrame(index, entry, stage))
	end
	return items
end

-- The size of one piece of produce for a crop: bigger for rarer crops.
local function produceSize(cropId: string): number
	local order = Rarities.ById[Crops.ById[cropId].rarity].order
	return ({ 0.85, 1.0, 1.25, 1.35, 1.45, 1.6 })[order]
end

-- Heaps a slot's produce into its regions ("Slot<n>", "Slot<n>_2", ...),
-- the lowest shelf first, fuller with more units.
local function fillSlot(item: Model, n: number, slot, capacity: number)
	local regions = {}
	for _, child in item:GetChildren() do
		if child.Name == `Slot{n}` or string.match(child.Name, `^Slot{n}_%d+$`) then
			table.insert(regions, child)
			child:ClearAllChildren()
		end
	end
	table.sort(regions, function(a, b)
		return a.Name < b.Name
	end)
	if not slot or not slot.crop or slot.units <= 0 then
		return
	end
	local size = produceSize(slot.crop)
	local color = FarmArt.cropColor(slot.crop)
	local spots = {}
	for _, region in regions do
		local cols = math.max(1, math.floor(region.Size.X / size))
		local rows = math.max(1, math.floor(region.Size.Z / size))
		local layers = math.max(1, math.floor(region.Size.Y / (size * 0.8)))
		for layer = 0, layers - 1 do
			for row = rows - 1, 0, -1 do -- (back to front)
				for col = 0, cols - 1 do
					local x = (col - (cols - 1) / 2) * region.Size.X / cols
					local z = (row - (rows - 1) / 2) * region.Size.Z / rows
					local y = -region.Size.Y / 2 + size / 2 + layer * size * 0.75
					local jitter = ((col * 7 + row * 13 + layer * 5) % 5 - 2) * 0.05
					table.insert(spots, { region = region, offset = Vector3.new(x + jitter, y, z - jitter) })
				end
			end
		end
	end
	local count = math.clamp(math.ceil(slot.units / capacity * #spots), 1, #spots)
	for i = 1, count do
		local spot = spots[i]
		Parts.ball("Produce", spot.region.CFrame * CFrame.new(spot.offset), size, { Color = color }, spot.region)
	end
end

-- Shows a display's produce and price tags ("🥕 24"; "Empty").
function StoreArt.showDisplay(model: Model, id: string, entry, prices)
	local item = model:FindFirstChild("Store") and model.Store.Items:FindFirstChild(id)
	local def = Store.ITEMS[entry.item]
	if not item or def.kind ~= "Display" then
		return
	end
	for n = 1, def.slots do
		local slot = entry.slots and entry.slots[n]
		fillSlot(item, n, slot, def.units)
		local card = item:FindFirstChild(`Tag{n}`)
		if card then
			local gui = card:FindFirstChildOfClass("SurfaceGui")
			if not gui then
				gui = Instance.new("SurfaceGui")
				gui.Face = Enum.NormalId.Front
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 60
				gui.LightInfluence = 0.3
				local label = Instance.new("TextLabel")
				label.Name = "Text"
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.FredokaOne
				label.TextScaled = true
				label.TextColor3 = COLORS.dark
				label.Parent = gui
				gui.Parent = card
			end
			local crop = slot and slot.crop and Crops.ById[slot.crop]
			gui.Text.Text = if crop and slot.units > 0 then `{crop.icon or ""} {prices[slot.crop] or "?"}`
				elseif crop then `{crop.icon or ""} sold out` else "Empty"
		end
	end
end

------------------------------------------------------------------------
-- The stockroom's crates, stacked up to 4 high along the room.

function StoreArt.showStockroom(model: Model, crates, stage: number)
	local building = model:FindFirstChild("Store") and model.Store:FindFirstChild("Building")
	local folder = building and building:FindFirstChild("StockroomCrates")
	if not folder then
		return
	end
	folder:ClearAllChildren()
	local cells = Store.BUILDINGS[stage].cells
	local w = cells[1] * CELL
	local sf = storeFrame(model:GetAttribute("PlotIndex"))
	local z = cells[2] * CELL + S.wall + 2.0
	local columns = math.floor((w - 2) / 3.6)
	for i, crate in crates do
		local column, layer = (i - 1) % columns, (i - 1) // columns
		if layer >= 4 then
			break
		end
		YardArt.crate(crate, sf * CFrame.new(-2.2 - column * 3.6, FLOOR - 0.1 + layer * 1.8, z) * CFrame.Angles(0, math.pi, 0), folder)
	end
end

------------------------------------------------------------------------
-- "Back soon!" hung in the doorway while you decorate.

function StoreArt.setBackSoon(model: Model, on: boolean)
	local store = storeModel(model)
	local sign = store:FindFirstChild("BackSoon")
	if not on then
		if sign then
			sign:Destroy()
		end
		return
	end
	if sign then
		return
	end
	local sf = storeFrame(model:GetAttribute("PlotIndex"))
	local d0, d1 = doorSpan()
	local holder = Instance.new("Model")
	holder.Name = "BackSoon"
	local board = Parts.prop({ Name = "Board", Size = Vector3.new(3.4, 1.3, 0.15), CFrame = sf * CFrame.new((d0 + d1) / 2, 6.4, -S.wall - 0.35),
		Color = COLORS.cream }, holder)
	words(board, "BACK SOON!", COLORS.barnRed)
	for _, x in { -1.2, 1.2 } do
		Parts.prop({ Name = "String", Size = Vector3.new(0.06, 1.3, 0.06), CFrame = board.CFrame * CFrame.new(x, 1.3, 0), Color = COLORS.dark }, holder)
	end
	holder.Parent = store
end

------------------------------------------------------------------------
-- Scaffolding round the next building while it goes up.

function StoreArt.showConstruction(model: Model, toLevel: number?, secondsLeft: number?)
	local store = storeModel(model)
	local old = store:FindFirstChild("Construction")
	if not toLevel then
		if old then
			old:Destroy()
		end
		return
	end
	local building = StoreLayout.level(toLevel).building
	if old and old:GetAttribute("To") == building.id then
		local timer = old.Sign:FindFirstChild("Timer", true) -- (the label is in the sign's SurfaceGui)
		if timer then
			timer.Text = `{building.name}: {string.format("%d:%02d", (secondsLeft or 0) // 60, (secondsLeft or 0) % 60)}`
		end
		return
	end
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Model")
	folder.Name = "Construction"
	folder:SetAttribute("To", building.id)
	local sf = storeFrame(model:GetAttribute("PlotIndex"))
	local w, d = building.cells[1] * CELL, building.cells[2] * CELL
	local h = LOOK[building.id].height
	local pole = Color3.fromRGB(150, 156, 164)
	local plank = Color3.fromRGB(196, 160, 110)
	local outline = {}
	for x = 0, w, 4 do
		table.insert(outline, Vector3.new(-x - S.wall - 1, 0, d + S.wall + S.backRoom + 2.5))
	end
	for z = 0, d + S.backRoom, 4 do
		table.insert(outline, Vector3.new(-w - S.wall - 1.5, 0, z))
	end
	for _, at in outline do
		box("Pole", sf, at.X - 0.25, 0, at.Z - 0.25, at.X + 0.25, h + 2, at.Z + 0.25, pole, folder)
	end
	-- walkways at three heights, and a cross-brace in every other bay
	for _, y in { 3.5, 7, h } do
		box("Plank", sf, -w - S.wall - 2.4, y, 0.5, -w - S.wall - 0.6, y + 0.35, d + S.backRoom + 3, plank, folder)
		box("Plank", sf, -w - S.wall - 2.4, y, d + S.wall + S.backRoom + 1.7, S.wall, y + 0.35, d + S.wall + S.backRoom + 3.3, plank, folder)
	end
	for i = 1, #outline - 1, 2 do
		local a, b = outline[i], outline[i + 1]
		if (a - b).Magnitude < 5 then
			for _, rise in { { 0.5, 7 }, { 7, 0.5 } } do
				local from = sf * Vector3.new(a.X, rise[1], a.Z)
				local to = sf * Vector3.new(b.X, rise[2], b.Z)
				Parts.prop({ Name = "Brace", Size = Vector3.new(0.2, 0.2, (to - from).Magnitude), CFrame = CFrame.lookAt((from + to) / 2, to), Color = pole }, folder)
			end
		end
	end
	-- the sign on two tall posts in the strip of yard by the gate (never
	-- built on), over the fence, facing the road
	local signAt = sf * CFrame.new(S.wall + 3.5, 0, 3)
	for _, x in { -2.6, 2.6 } do
		Parts.part({ Name = "SignPost", Size = Vector3.new(0.4, 10.6, 0.4), CFrame = signAt * CFrame.new(x, 5.3, 0.3), Color = COLORS.post }, folder)
	end
	local sign = Parts.prop({ Name = "Sign", Size = Vector3.new(6, 2.8, 0.2), CFrame = signAt * CFrame.new(0, 9.6, 0), Color = COLORS.hay }, folder)
	words(sign, `{building.name}: building`, COLORS.dark, Enum.Font.FredokaOne, "Timer")
	folder.Parent = store
end

------------------------------------------------------------------------

-- A plot's store before anyone has it: an empty Corner Store, "For rent".
function StoreArt.build(model: Model)
	StoreArt.buildBuilding(model, 1, "FOR RENT")
end

return StoreArt
