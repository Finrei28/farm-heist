-- A farm's defences and what goes with them (docs/GameDesign.md §4.11,
-- §5.4; docs/ArtDirection.md §11 step 11):
--
--   * the back fence: wooden slats with gaps, or the Tall Back Fence
--     (close-boarded, 11 studs) once it's bought;
--   * the gate: two white picket leaves, standing open against the yard,
--     swung shut with a padlock and a PRIVATE FARM sign when the Gate Lock
--     is on (they open for the owner and Trusted friends), and shut on a
--     Suspect by the Watchman. While the gate is shut for anyone there's a
--     GateBlocker: every client decides for itself whether it stops them
--     (client DefenceController), and DefenceService checks the crossings;
--   * what's set out (shared/DefenceRules): the scarecrow, the kennel and
--     its dog, mud patches on the yard spots round the field, glass
--     cloches over tiles, the security camera on the barn;
--   * the Watchman's gatehouse by the gate, with his bell and spotlight;
--   * the domes over the field: the Sprout Shield and arrival grace
--     (green), the raid cap's Neighbourhood Watch (blue), with a sign and a
--     timer (the clients count it down);
--   * the alarm light on the farmhouse's ridge and the gate's flag: the
--     clients spin and flash them while the plot's AlarmUntil is ahead.
--
-- Meshes (World/Meshes, from tools/crop_art) for the round and living
-- things: the scarecrow, the dog, the cloche, the camera, mud, the bell and
-- the spotlight; parts for the rest. Until the props are imported, plain
-- part-built stand-ins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Defences = require(ReplicatedStorage.Shared.Config.Defences)
local DefenceRules = require(ReplicatedStorage.Shared.DefenceRules)
local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
local Meshes = require(script.Parent.Meshes)
local Parts = require(script.Parent.Parts)

local COLORS = Parts.COLORS

local DefenceArt = {}

local BOARDS = { Color3.fromRGB(201, 158, 104), Color3.fromRGB(190, 146, 94), Color3.fromRGB(208, 166, 112) }
local RAIL = Color3.fromRGB(160, 116, 72)
local BRASS = Color3.fromRGB(214, 168, 64)
local IRON = Color3.fromRGB(58, 56, 54)
local KENNEL = Color3.fromRGB(176, 124, 80)
local SHINGLE = Color3.fromRGB(122, 84, 60)
local GLASS = Color3.fromRGB(214, 236, 244)
local DOME = {
	Shield = { color = Color3.fromRGB(122, 214, 96), title = "🌱 Sprout Shield" },
	Grace = { color = Color3.fromRGB(122, 214, 96), title = "🌱 Just arrived" },
	Watch = { color = Color3.fromRGB(96, 156, 232), title = "👮 Neighbourhood Watch" },
}

local function signGui(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?, ppu: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppu or 24
	gui.LightInfluence = 0.5
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.Parent = label
	label.Parent = gui
	gui.Parent = part
	return gui
end

------------------------------------------------------------------------
-- The back fence

-- The back fence across the plot at z DEPTH..DEPTH+1: wooden slats with gaps
-- on two rails (thieves see the crops from the trail; you climb it), or
-- `tall`: the Tall Back Fence, boards edge to edge, alternately set back a
-- little (board-on-board), on three rails, with a capping rail. Either way
-- an invisible wall up to FENCE_BLOCK (characters climb rails like a ladder).
function DefenceArt.backFence(model: Model, frame: CFrame, tall: boolean)
	local old = model:FindFirstChild("BackFence")
	if old then
		old:Destroy()
	end
	local fence = Instance.new("Model")
	fence.Name = "BackFence"
	fence:SetAttribute("Tall", tall)
	local W, D = PlotLayout.WIDTH, PlotLayout.DEPTH
	local min, max = Vector3.new(-W / 2, 0, D), Vector3.new(W / 2, 0, D + 1)
	local height = if tall then PlotLayout.TALL_FENCE_HEIGHT else PlotLayout.FENCE_HEIGHT
	local plotBox = Parts.plotBox
	if tall then
		local board, step = 2.5, 2.4
		local x, i = min.X + 0.2, 0
		while x + board <= max.X - 0.2 do
			i += 1
			local back = if i % 2 == 0 then 0.2 else 0 -- (every other one set back: board-on-board)
			local top = height - 0.6 + (i * 7 % 5) * 0.06
			plotBox("Board", frame, Vector3.new(x, 0, max.Z - 0.4 + back), Vector3.new(x + board, top, max.Z + back), { Color = BOARDS[i % 3 + 1] }, fence)
			x += step
		end
		for _, y in { 1.2, height / 2 - 0.3, height - 2.0 } do
			plotBox("Rail", frame, Vector3.new(min.X, y, min.Z), Vector3.new(max.X, y + 0.8, max.Z - 0.45), { Color = RAIL }, fence)
		end
		plotBox("Capping", frame, Vector3.new(min.X, height - 0.15, max.Z - 0.6), Vector3.new(max.X, height + 0.25, max.Z + 0.35), { Color = RAIL }, fence)
	else
		local slat, gap = 1.1, 0.7
		local x, i = min.X + 0.3, 0
		while x + slat <= max.X - 0.3 do
			i += 1
			local top = height - 0.35 + (i * 7 % 5) * 0.08 -- (hand-cut: not quite level)
			plotBox("Slat", frame, Vector3.new(x, 0, max.Z - 0.35), Vector3.new(x + slat, top, max.Z), { Color = BOARDS[i % 3 + 1] }, fence)
			x += slat + gap
		end
		for _, y in { 1.4, height - 1.8 } do
			plotBox("Rail", frame, Vector3.new(min.X, y, min.Z), Vector3.new(max.X, y + 0.7, max.Z - 0.35), { Color = RAIL }, fence)
		end
	end
	local posts = math.max(1, math.round((max.X - min.X) / 12))
	for p = 0, posts do
		local px = min.X + (max.X - min.X) * p / posts
		-- (posts stand a little above the boards: level tops would flicker;
		-- a little behind the rails' face: flush, it flickered through the gaps)
		plotBox("Post", frame, Vector3.new(px - 0.5, 0, min.Z - 0.3), Vector3.new(px + 0.5, height + 0.5, max.Z - 0.5), { Color = COLORS.post }, fence)
	end
	plotBox("BackFenceBlocker", frame, min, Vector3.new(max.X, PlotLayout.FENCE_BLOCK, max.Z),
		{ Transparency = 1, CanQuery = false, CanTouch = false }, fence)
	-- a painted sign on the trail side (it tells a thief more than it stops one)
	local sign = Parts.prop({ Name = "BackFenceSign", Size = Vector3.new(7, 2.6, 0.25),
		CFrame = frame * CFrame.new(0, if tall then 6 else 4.6, D + 1.15 + (if tall then 0.25 else 0)) * CFrame.Angles(0, 0, math.rad(-3)), Color = COLORS.cream }, fence)
	signGui(sign, Enum.NormalId.Back, if tall then "PRIVATE FARM\nKeep out!" else "PRIVATE FARM\nNo climbing!", COLORS.barnRed, Enum.Font.PatrickHand)
	fence.Parent = model
	return fence
end

------------------------------------------------------------------------
-- The gate

-- One picket leaf, built shut in plot space, hung on the gate post at
-- `hingeX` and reaching `width` toward `toward` (+1/−1) from half a stud off
-- the post, white like the front fence: a frame of two stiles, three rails
-- and a brace, pickets, iron straps to the post. It swings on the post's
-- yard side (z HINGE_Z), so opening it inward clears the posts.
local HINGE_Z = 0.35
local function gateLeaf(name: string, frame: CFrame, hingeX: number, toward: number, width: number, parent: Instance): Model
	local leaf = Instance.new("Model")
	leaf.Name = name
	local z = -0.5
	local top = PlotLayout.FENCE_HEIGHT
	local near, far = hingeX + toward * 0.5, hingeX + toward * (0.5 + width)
	local x0, x1 = math.min(near, far), math.max(near, far)
	local function box(n, a, y0, b, y1, zf, zb, color)
		return Parts.plotBox(n, frame, Vector3.new(a, y0, zf), Vector3.new(b, y1, zb), { Color = color, CanCollide = false, CanTouch = false }, leaf)
	end
	-- stiles at both ends, rails across (behind the pickets: the yard side)
	box("Stile", x0 + 0.05, 0.3, x0 + 0.65, top - 0.2, z + 0.05, z + 0.55, COLORS.fence)
	box("Stile", x1 - 0.65, 0.3, x1 - 0.05, top - 0.2, z + 0.05, z + 0.55, COLORS.fence)
	for _, y in { 0.9, top / 2 - 0.25, top - 1.6 } do
		box("Rail", x0 + 0.65, y, x1 - 0.65, y + 0.5, z + 0.1, z + 0.5, COLORS.fence)
	end
	-- the brace, from the hinge's foot to the far top (it holds the leaf up)
	local foot = frame * CFrame.new(near + toward * 0.9, 1.4, z + 0.3)
	local head = frame * CFrame.new(far - toward * 0.9, top - 1.85, z + 0.3)
	local along = head.Position - foot.Position
	Parts.prop({ Name = "Brace", Size = Vector3.new(0.45, along.Magnitude, 0.3), Color = COLORS.fence,
		CFrame = CFrame.fromMatrix((foot.Position + head.Position) / 2, frame.ZVector:Cross(along.Unit), along.Unit) }, leaf)
	-- pickets on the road side, pointed
	local count = math.floor((width - 1.4) / 1.5)
	local step = (width - 1.4) / count
	for i = 0, count - 1 do
		local x = x0 + 0.7 + (i + 0.5) * step
		local h = top - 0.9
		Parts.prop({ Name = "Picket", Size = Vector3.new(0.75, h, 0.25), CFrame = frame * CFrame.new(x, 0.25 + h / 2, z - 0.1), Color = COLORS.fence }, leaf)
		Parts.prop({ Name = "PicketTip", Size = Vector3.new(0.53, 0.53, 0.21), CFrame = frame * CFrame.new(x, 0.25 + h, z - 0.1) * CFrame.Angles(0, 0, math.rad(45)),
			Color = COLORS.fence }, leaf)
	end
	-- iron hinge straps on the yard side, from the post across the stile
	for _, y in { 1.1, top - 1.4 } do
		local a, b = hingeX + toward * 0.1, hingeX + toward * 2.6
		box("Strap", math.min(a, b), y, math.max(a, b), y + 0.3, z + 0.55, z + 0.65, IRON)
	end
	leaf.WorldPivot = frame * CFrame.new(hingeX, 0, HINGE_Z)
	leaf.Parent = parent
	return leaf
end

-- The gate: two leaves standing open against the yard, the chain and
-- padlock and the PRIVATE FARM sign (shown while locked), and its flag.
local function buildGate(model: Model, frame: CFrame)
	local P = PlotLayout.PLOT
	local gate = Instance.new("Model")
	gate.Name = "GateLeaves"
	local left = P.gate.across - P.gate.width / 2
	local right = P.gate.across + P.gate.width / 2
	local half = P.gate.width / 2
	local leafL = gateLeaf("LeafLeft", frame, left, 1, half - 0.55, gate)
	local leafR = gateLeaf("LeafRight", frame, right, -1, half - 0.55, gate)
	leafL:SetAttribute("OpenAngle", -90)
	leafR:SetAttribute("OpenAngle", 90)
	-- the lock: a chain round the two middle stiles and a brass padlock, on
	-- the right leaf (it swings with it); hidden until the Gate Lock is on
	local lock = Instance.new("Model")
	lock.Name = "Lock"
	local mid = P.gate.across
	for i, y in { 3.6, 4.05 } do
		Parts.prop({ Name = "Chain", Size = Vector3.new(1.7, 0.16, 0.16), CFrame = frame * CFrame.new(mid, y, -0.95 - i * 0.02) * CFrame.Angles(0, 0, math.rad(if i == 1 then 8 else -6)),
			Color = IRON, CastShadow = false }, lock)
	end
	local body = Parts.prop({ Name = "Padlock", Size = Vector3.new(0.75, 0.85, 0.35), CFrame = frame * CFrame.new(mid + 0.35, 3.1, -1.2), Color = BRASS, CastShadow = false }, lock)
	Parts.prop({ Name = "Keyhole", Size = Vector3.new(0.14, 0.3, 0.1), CFrame = body.CFrame * CFrame.new(0, -0.08, -0.18), Color = IRON, CastShadow = false }, lock)
	for _, x in { -0.25, 0.25 } do
		Parts.prop({ Name = "Shackle", Size = Vector3.new(0.12, 0.5, 0.12), CFrame = body.CFrame * CFrame.new(x, 0.62, 0), Color = Color3.fromRGB(176, 180, 186), CastShadow = false }, lock)
	end
	Parts.prop({ Name = "Shackle", Size = Vector3.new(0.62, 0.12, 0.12), CFrame = body.CFrame * CFrame.new(0, 0.86, 0), Color = Color3.fromRGB(176, 180, 186), CastShadow = false }, lock)
	local sign = Parts.prop({ Name = "PrivateSign", Size = Vector3.new(5.2, 2.2, 0.2), CFrame = frame * CFrame.new(right - 4.6, 5.6, -0.95) * CFrame.Angles(0, 0, math.rad(2)),
		Color = COLORS.cream }, lock)
	Parts.prop({ Name = "PrivateSignEdge", Size = Vector3.new(5.5, 2.5, 0.12), CFrame = sign.CFrame * CFrame.new(0, 0, 0.16), Color = COLORS.barnRed }, lock)
	signGui(sign, Enum.NormalId.Front, "PRIVATE FARM\nTrusted friends only", COLORS.barnRed, Enum.Font.FredokaOne, 30)
	lock.Parent = leafR
	gate.Parent = model
	return gate
end

-- Swings the gate's leaves open or shut, and shows the lock while `locked`.
function DefenceArt.setGate(model: Model, open: boolean, locked: boolean?)
	local gate = model:FindFirstChild("GateLeaves")
	if not gate then
		return
	end
	local lock = gate:FindFirstChild("LeafRight") and gate.LeafRight:FindFirstChild("Lock")
	if lock and (lock:GetAttribute("Shown") ~= (locked == true)) then
		lock:SetAttribute("Shown", locked == true)
		for _, part in lock:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = if locked then 0 else 1
			elseif part:IsA("SurfaceGui") then
				part.Enabled = locked == true
			end
		end
	end
	if gate:GetAttribute("Open") == open then
		return
	end
	gate:SetAttribute("Open", open)
	for _, leaf in gate:GetChildren() do
		if not leaf:IsA("Model") then
			continue
		end
		local hinge = leaf:GetAttribute("Hinge") :: CFrame?
		if not hinge then
			hinge = leaf.WorldPivot
			leaf:SetAttribute("Hinge", hinge)
		end
		local angle = if open then math.rad(leaf:GetAttribute("OpenAngle") or 0) else 0
		for _, part in leaf:GetDescendants() do
			if part:IsA("BasePart") then
				local rest = part:GetAttribute("Rest")
				if not rest then
					rest = (hinge :: CFrame):ToObjectSpace(part.CFrame)
					part:SetAttribute("Rest", rest)
				end
				part.CFrame = (hinge :: CFrame) * CFrame.Angles(0, angle, 0) * rest
			end
		end
	end
end

-- The invisible wall in the gateway while the gate is shut for anyone (the
-- Gate Lock, or the Watchman shutting it on a Suspect). Each client lets
-- itself through or not (client DefenceController).
function DefenceArt.setGateBlocker(model: Model, frame: CFrame, on: boolean)
	local blocker = model:FindFirstChild("GateBlocker")
	if on and not blocker then
		local P = PlotLayout.PLOT
		Parts.plotBox("GateBlocker", frame, Vector3.new(P.gate.across - P.gate.width / 2, 0, -1.2), Vector3.new(P.gate.across + P.gate.width / 2, PlotLayout.FENCE_BLOCK, 0.2),
			{ Transparency = 1, CanQuery = false, CanTouch = false }, model)
	elseif not on and blocker then
		blocker:Destroy()
	end
end

------------------------------------------------------------------------
-- The alarm light

-- A red beacon on the farmhouse's ridge, at the field end: dark until a
-- theft alarm (the clients spin it while the plot's AlarmUntil is ahead).
local function buildBeacon(model: Model, frame: CFrame)
	local beacon = Instance.new("Model")
	beacon.Name = "AlarmBeacon"
	local at = frame * CFrame.new(-43.5, 18.7, 103.5)
	Parts.cylinder("BeaconBase", at * CFrame.new(0, 0.2, 0), 1.3, 0.4, { Color = IRON }, beacon)
	local glass = Parts.cylinder("BeaconGlass", at * CFrame.new(0, 0.85, 0), 1.0, 0.9, { Color = Color3.fromRGB(150, 34, 30), Transparency = 0.15, Material = Enum.Material.Glass }, beacon)
	Parts.ball("BeaconCap", at * CFrame.new(0, 1.3, 0), 1.0, { Color = Color3.fromRGB(150, 34, 30), Transparency = 0.15, Material = Enum.Material.Glass }, beacon)
	local light = Instance.new("SpotLight")
	light.Name = "Beam"
	light.Color = Color3.fromRGB(255, 60, 40)
	light.Range = 40
	light.Angle = 45
	light.Brightness = 0
	light.Face = Enum.NormalId.Top -- (the cylinder lies along X: its Top face points sideways, round the farm as it spins)
	light.Parent = glass
	beacon.Parent = model
end

------------------------------------------------------------------------
-- What's set out

-- A mesh, or a stand-in block when the props aren't imported.
local function meshOr(name: string, at: CFrame, scale: number, parent: Instance, fallback: () -> ()): BasePart?
	local mesh = Meshes.make(name, at, scale, parent)
	if not mesh then
		fallback()
	end
	return mesh
end

-- The scarecrow on a yard spot, looking out from the field.
local function scarecrow(parent: Instance, at: CFrame)
	meshOr("Scarecrow", at, 1, parent, function()
		Parts.cylinder("ScarecrowPost", at * CFrame.new(0, 3.5, 0), 0.5, 7, { Color = COLORS.post }, parent)
		Parts.prop({ Name = "ScarecrowArms", Size = Vector3.new(5, 0.4, 0.4), CFrame = at * CFrame.new(0, 5, 0), Color = COLORS.post }, parent)
		Parts.prop({ Name = "ScarecrowShirt", Size = Vector3.new(2.2, 2.4, 1), CFrame = at * CFrame.new(0, 4.6, 0), Color = Color3.fromRGB(176, 72, 52) }, parent)
		Parts.ball("ScarecrowHead", at * CFrame.new(0, 6.6, 0), 1.5, { Color = Color3.fromRGB(214, 186, 132) }, parent)
		Parts.cylinder("ScarecrowHat", at * CFrame.new(0, 7.4, 0), 2.4, 0.3, { Color = Color3.fromRGB(150, 110, 60) }, parent)
	end)
	Parts.plotBox("ScarecrowSolid", at, Vector3.new(-0.5, 0, -0.5), Vector3.new(0.5, 7, 0.5), { Transparency = 1, CanQuery = false, CanTouch = false }, parent)
end

-- The kennel on a yard spot, its door toward the field, and the dog lying
-- in front of it (a Model the clients move: client DogController).
local function kennel(parent: Instance, at: CFrame, index: number)
	local k = Instance.new("Model")
	k.Name = "Kennel"
	local function box(name, x0, y0, z0, x1, y1, z1, color, solid)
		local props = { Color = color }
		if not solid then
			props.CanCollide = false
		end
		return Parts.plotBox(name, at, Vector3.new(x0, y0, z0), Vector3.new(x1, y1, z1), props, k)
	end
	-- (in the spot's frame: −Z is the door side, toward the field)
	local w, d, wall, ridge = 5.6, 5.2, 3.8, 5.6
	local z0, z1 = -0.6, -0.6 + d
	box("KennelFloor", -w / 2 - 0.2, 0, z0 - 0.2, w / 2 + 0.2, 0.4, z1 + 0.2, SHINGLE, true)
	box("KennelBack", -w / 2, 0.4, z1 - 0.4, w / 2, wall, z1, KENNEL, true)
	box("KennelSide", -w / 2, 0.4, z0, -w / 2 + 0.4, wall, z1 - 0.4, KENNEL, true)
	box("KennelSide", w / 2 - 0.4, 0.4, z0, w / 2, wall, z1 - 0.4, KENNEL, true)
	box("KennelFront", -w / 2 + 0.4, 0.4, z0, -1.1, wall, z0 + 0.4, KENNEL, true)
	box("KennelFront", 1.1, 0.4, z0, w / 2 - 0.4, wall, z0 + 0.4, KENNEL, true)
	box("KennelLintel", -1.1, 2.9, z0, 1.1, wall, z0 + 0.4, KENNEL, true)
	box("KennelDoorway", -1.1, 0.4, z0 + 0.1, 1.1, 2.9, z1 - 0.5, Color3.fromRGB(46, 32, 24))
	-- the gables and the roof: two shingled slopes meeting at a ridge
	for _, z in { z0, z1 - 0.4 } do
		for _, side in { -1, 1 } do
			local gable = Parts.prop({ Name = "KennelGable", Size = Vector3.new(0.4, ridge - wall, w / 2), Color = KENNEL,
				CFrame = at * CFrame.new(side * w / 4, wall + (ridge - wall) / 2, z + 0.2) * CFrame.Angles(0, math.rad(-side * 90), 0) }, k)
			gable.Shape = Enum.PartType.Wedge
		end
	end
	local run = w / 2 + 0.5
	local rise = ridge - wall + 0.3
	local slope = math.sqrt(run * run + rise * rise)
	for _, side in { -1, 1 } do
		local angle = math.atan2(rise, run)
		Parts.prop({ Name = "KennelRoof", Size = Vector3.new(slope + 0.1, 0.35, d + 0.8), Color = SHINGLE,
			CFrame = at * CFrame.new(side * run / 2, wall - 0.3 + rise / 2 + 0.2, (z0 + z1) / 2) * CFrame.Angles(0, 0, side * -angle) }, k)
	end
	box("KennelRidge", -0.3, ridge + 0.25, z0 - 0.45, 0.3, ridge + 0.6, z1 + 0.45, SHINGLE)
	-- the name over the door
	local plate = Parts.prop({ Name = "KennelPlate", Size = Vector3.new(2.6, 0.75, 0.12), CFrame = at * CFrame.new(0, 3.35, z0 - 0.08), Color = COLORS.cream }, k)
	local names = { "REX", "BUSTER", "MAX", "DUKE", "BELLA", "SCOUT", "ROSIE", "BRUNO" }
	signGui(plate, Enum.NormalId.Front, names[(index - 1) % #names + 1], COLORS.barnRed)
	-- a bowl
	Parts.cylinder("Bowl", at * CFrame.new(2.4, 0.25, z0 - 1.6), 1.1, 0.5, { Color = COLORS.barnRed }, k)
	k.Parent = parent

	-- the dog, lying by the door (the clients run it at thieves)
	local dog = Instance.new("Model")
	dog.Name = "Dog"
	local rest = at * CFrame.new(-0.8, 0, z0 - 2.2) * CFrame.Angles(0, math.rad(-25), 0) -- (looking out at the field)
	dog:SetAttribute("Home", rest)
	local body = meshOr("GuardDog", rest, 1, dog, function()
		Parts.prop({ Name = "GuardDog", Size = Vector3.new(1.2, 1.3, 3), CFrame = rest * CFrame.new(0, 1.5, 0), Color = Color3.fromRGB(150, 100, 60) }, dog)
		Parts.prop({ Name = "DogHead", Size = Vector3.new(1, 1, 1.3), CFrame = rest * CFrame.new(0, 2.3, -1.7), Color = Color3.fromRGB(150, 100, 60) }, dog)
	end)
	if body then
		Meshes.dogLegs(rest, dog)
	end
	dog.Parent = parent
end

local function mudPatch(parent: Instance, at: CFrame)
	meshOr("MudPatch", at, 1, parent, function()
		Parts.prop({ Name = "MudPatch", Size = Vector3.new(11.4, 0.12, 11.4), CFrame = at * CFrame.new(0, 0.26, 0), Color = Color3.fromRGB(92, 64, 42), CastShadow = false }, parent)
	end)
end

-- A glass cloche over a tile (its top's middle: `at`).
local function cloche(parent: Instance, at: CFrame)
	local mesh = meshOr("Cloche", at, 1, parent, function()
		local glass = Parts.ball("Cloche", at * CFrame.new(0, 0, 0), 11.2, { Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.7 }, parent)
		glass.CastShadow = false
	end)
	if mesh then
		mesh.Material = Enum.Material.Glass
		mesh.Color = GLASS
		mesh.Transparency = 0.62
		mesh.CastShadow = false
	end
end

-- The security camera on its bracket on the barn's back corner, aimed at
-- the middle of the field.
local function camera(parent: Instance, frame: CFrame)
	local P = PlotLayout.PLOT
	local field = P.field
	local middle = Vector3.new(field.across + field.size * field.tile / 2, 0, field.depth + field.size * field.tile / 2)
	local mount = frame * CFrame.new(P.camera)
	Parts.prop({ Name = "CameraPlate", Size = Vector3.new(1.2, 1.5, 0.2), CFrame = mount * CFrame.new(0, 0, -0.42), Color = IRON }, parent)
	Parts.prop({ Name = "CameraArm", Size = Vector3.new(0.3, 0.3, 1.3), CFrame = mount * CFrame.new(0, 0, 0.15), Color = IRON }, parent)
	local look = CFrame.lookAt(mount.Position + mount.ZVector * 0.9, frame:PointToWorldSpace(middle))
	meshOr("SecurityCamera", look, 1.6, parent, function()
		Parts.prop({ Name = "SecurityCamera", Size = Vector3.new(0.8, 0.8, 1.8), CFrame = look * CFrame.new(0, 0, -0.6), Color = Color3.fromRGB(236, 236, 230) }, parent)
	end)
end

-- Floodlights (§4.11, week 7): a lamp post just off each corner of the
-- field, its lamp head on an arm tilted down at the field's middle. By day
-- the lens is pale glass; at night (SkyController: "NightGlow" and
-- "NightLight") it glows and a spotlight floods the field.
local POST = Color3.fromRGB(62, 74, 66) -- (a dark green iron)
local LENS = Color3.fromRGB(226, 224, 210)
local function floodlights(parent: Instance, frame: CFrame)
	local field = PlotLayout.PLOT.field
	local x0, z0 = field.across, field.depth
	local x1, z1 = x0 + field.size * field.tile, z0 + field.size * field.tile
	local middle = frame:PointToWorldSpace(Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2))
	local TOP = 16
	for _, corner in { { x0, z0, -1, -1 }, { x1, z0, 1, -1 }, { x0, z1, -1, 1 }, { x1, z1, 1, 1 } } do
		local base = frame * CFrame.new(corner[1] + corner[3] * 1.6, 0, corner[2] + corner[4] * 1.6)
		Parts.part({ Name = "FloodPlinth", Size = Vector3.new(1.6, 0.6, 1.6), CFrame = base * CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(150, 146, 140) }, parent)
		Parts.part({ Name = "FloodPost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(TOP - 0.3, 0.55, 0.55),
			CFrame = base * CFrame.new(0, 0.3 + (TOP - 0.3) / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = POST }, parent)
		Parts.ball("FloodCap", base * CFrame.new(0, TOP, 0), 0.75, { Color = POST }, parent)
		-- the arm out toward the field, and the head on it looking down at the middle
		local toward = Vector3.new(middle.X - base.Position.X, 0, middle.Z - base.Position.Z).Unit
		local headAt = base.Position + Vector3.new(0, TOP - 0.7, 0) + toward * 1.5
		Parts.prop({ Name = "FloodArm", Size = Vector3.new(0.3, 0.3, 1.6), CFrame = CFrame.lookAt(base.Position + Vector3.new(0, TOP - 0.7, 0) + toward * 0.55, headAt), Color = POST }, parent)
		local head = CFrame.lookAt(headAt, middle)
		Parts.prop({ Name = "FloodHead", Size = Vector3.new(2.2, 0.9, 1.3), CFrame = head * CFrame.new(0, 0, 0.35), Color = IRON }, parent)
		local lens = Parts.prop({ Name = "FloodLens", Size = Vector3.new(1.9, 0.68, 0.1), CFrame = head * CFrame.new(0, 0, -0.36), Color = LENS,
			Material = Enum.Material.Glass, CastShadow = false }, parent)
		lens:SetAttribute("NightColor", Color3.fromRGB(255, 246, 220))
		lens:AddTag("NightGlow")
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Angle = 80
		light.Range = 60
		light.Brightness = 2.5
		light.Color = Color3.fromRGB(255, 244, 222)
		light.Shadows = false
		light.Enabled = false
		light.Parent = lens
		light:AddTag("NightLight")
	end
end

-- Redraws everything set out on a farm (shared/DefenceRules), and the back
-- fence and the gate's lock to match. index: the plot (the farm's colour).
function DefenceArt.show(model: Model, frame: CFrame, index: number, defences)
	local old = model:FindFirstChild("Defences")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Model")
	folder.Name = "Defences"
	for spot, itemId in defences.placed do
		local kind, n = DefenceRules.spotKind(spot)
		if kind == "yard" then
			local p = PlotLayout.yardSpot(n :: number)
			-- (facing away from the field: −Z of the spot's frame is the field side)
			local field = PlotLayout.PLOT.field
			local middle = Vector3.new(field.across + field.size * field.tile / 2, 0, field.depth + field.size * field.tile / 2)
			local away = Vector3.new(p.X - middle.X, 0, p.Z - middle.Z)
			local facing = if math.abs(away.X) > math.abs(away.Z) then Vector3.new(math.sign(away.X), 0, 0) else Vector3.new(0, 0, math.sign(away.Z))
			local at = frame * CFrame.lookAt(p + Vector3.new(0, 0.2, 0), p + Vector3.new(0, 0.2, 0) + facing)
			-- (lookAt faces −Z along `facing`: turn round so −Z points at the field)
			at *= CFrame.Angles(0, math.pi, 0)
			local holder = Instance.new("Model")
			holder.Name = itemId
			holder:SetAttribute("Spot", spot)
			if itemId == "Scarecrow" then
				scarecrow(holder, at)
			elseif itemId == "GuardDog" then
				kennel(holder, at, index)
			elseif itemId == "MudPatch" then
				mudPatch(holder, at)
			end
			holder.Parent = folder
		elseif kind == "tile" and itemId == "Cloche" then
			local tile = model:FindFirstChild("Field") and model.Field:FindFirstChild(`Tile{n}`)
			local top = if tile then tile.CFrame * CFrame.new(0, tile.Size.Y / 2, 0) else frame * CFrame.new(PlotLayout.tileLocal(n :: number) + Vector3.new(0, 0.6, 0))
			local holder = Instance.new("Model")
			holder.Name = "Cloche"
			holder:SetAttribute("Spot", spot)
			cloche(holder, top)
			holder.Parent = folder
		elseif kind == "camera" then
			local holder = Instance.new("Model")
			holder.Name = "Camera"
			camera(holder, frame)
			holder.Parent = folder
		elseif kind == "floods" then
			local holder = Instance.new("Model")
			holder.Name = "Floodlights"
			floodlights(holder, frame)
			holder.Parent = folder
		end
	end
	folder.Parent = model
	-- (the clients: name tags show from afar on this farm at night)
	model:SetAttribute("Floodlights", defences.placed.floods == "Floodlights" or nil)
	local fence = model:FindFirstChild("BackFence")
	local tall = defences.placed.fence == "TallFence"
	if not fence or fence:GetAttribute("Tall") ~= tall then
		DefenceArt.backFence(model, frame, tall)
	end
end

------------------------------------------------------------------------
-- The Watchman's gatehouse

-- A wooden sentry hut inside the gate: walls round an open room (the
-- Watchman stands at its window), a pitched roof, a bell on a bracket
-- and a spotlight on the roof (the clients aim it at thieves).
function DefenceArt.gatehouse(model: Model, frame: CFrame, index: number, on: boolean)
	local old = model:FindFirstChild("Gatehouse")
	if old then
		old:Destroy()
	end
	if not on then
		return
	end
	local P = PlotLayout.PLOT
	local g = P.gatehouse
	local hut = Instance.new("Model")
	hut.Name = "Gatehouse"
	local x0, x1, z0, z1 = g.min.X, g.max.X, g.min.Z, g.max.Z
	local wall, ridge = 7.2, 9.4
	-- a box between plot-space corners (x0, y0, z0) and (x1, y1, z1)
	local function box(name, ax, ay, az, bx, by, bz, color, solid)
		local props = { Color = color }
		if not solid then
			props.CanCollide = false
		end
		return Parts.plotBox(name, frame, Vector3.new(ax, ay, az), Vector3.new(bx, by, bz), props, hut)
	end
	local paint = Parts.farmColor(index)
	box("GatehouseFloor", x0 - 0.15, 0, z0 - 0.15, x1 + 0.15, 0.5, z1 + 0.15, Color3.fromRGB(150, 146, 140), true) -- (proud of the walls: flush, it flickered)
	-- walls: the back and the far side whole, the gate side and the front
	-- with a counter window, the door on the yard side
	box("GatehouseWall", x0, 0.5, z1 - 0.5, x1, wall, z1, COLORS.cream, true)
	box("GatehouseWall", x1 - 0.5, 0.5, z0, x1, wall, z1 - 0.5, COLORS.cream, true)
	box("GatehouseWall", x0, 0.5, z0, x0 + 0.5, 3.2, z1 - 0.5, COLORS.cream, true) -- (gate side, under the window)
	box("GatehouseWall", x0, 6.2, z0, x0 + 0.5, wall, z1 - 0.5, COLORS.cream, true)
	box("GatehouseWall", x0 + 0.5, 0.5, z0, x0 + 3.0, wall, z0 + 0.5, COLORS.cream, true) -- (front, by the road)
	box("GatehouseWall", x0 + 3.0, 0.5, z0, x1 - 0.5, 3.2, z0 + 0.5, COLORS.cream, true)
	box("GatehouseWall", x0 + 3.0, 6.2, z0, x1 - 0.5, wall, z0 + 0.5, COLORS.cream, true)
	box("GatehouseWall", x0, 3.2, z1 - 3.4, x0 + 0.5, 6.2, z1 - 0.5, COLORS.cream, true) -- (between the window and the back)
	-- the counters under the windows, in the farm's colour, and corner trim
	box("Counter", x0 - 0.25, 3.25, z0 + 0.6, x0 + 0.85, 3.6, z1 - 3.5, paint)
	box("Counter", x0 + 3.1, 3.25, z0 - 0.25, x1 - 0.6, 3.6, z0 + 0.85, paint)
	for _, c in { { x0, z0 }, { x1, z0 }, { x0, z1 }, { x1, z1 } } do
		box("Corner", c[1] - 0.25, 0.45, c[2] - 0.25, c[1] + 0.25, wall + 0.05, c[2] + 0.25, COLORS.post)
	end
	-- his door, on the yard side, in the farm's colour
	box("GatehouseDoor", x0 + 4.2, 0.5, z1 + 0.06, x0 + 6.6, 6.0, z1 + 0.22, paint)
	box("DoorKnob", x0 + 6.1, 3.0, z1 + 0.22, x0 + 6.35, 3.25, z1 + 0.42, COLORS.hay)
	-- the roof: two slopes over the gate side and the far side, gables
	local run = (x1 - x0) / 2 + 0.6
	local rise = ridge - wall
	local slope = math.sqrt(run * run + rise * rise)
	local angle = math.atan2(rise, run)
	for _, side in { -1, 1 } do
		Parts.part({ Name = "GatehouseRoof", Size = Vector3.new(slope + 0.1, 0.4, z1 - z0 + 1.2), Color = COLORS.barnRed,
			CFrame = frame * CFrame.new((x0 + x1) / 2 + side * run / 2, wall + rise / 2 + 0.2, (z0 + z1) / 2) * CFrame.Angles(0, 0, side * -angle) }, hut)
	end
	for _, z in { z0 + 0.25, z1 - 0.25 } do
		for _, side in { -1, 1 } do
			local gable = Parts.prop({ Name = "GatehouseGable", Size = Vector3.new(0.5, rise, (x1 - x0) / 2), Color = COLORS.cream,
				CFrame = frame * CFrame.new((x0 + x1) / 2 + side * (x1 - x0) / 4, wall + rise / 2, z) * CFrame.Angles(0, math.rad(-side * 90), 0) }, hut)
			gable.Shape = Enum.PartType.Wedge
		end
	end
	box("GatehouseRidge", (x0 + x1) / 2 - 0.3, ridge + 0.35, z0 - 0.6, (x0 + x1) / 2 + 0.3, ridge + 0.7, z1 + 0.6, COLORS.barnRed)
	-- a WATCH sign over the gate-side window
	local sign = Parts.prop({ Name = "WatchSign", Size = Vector3.new(0.15, 0.9, 4.2), CFrame = frame * CFrame.new(x0 - 0.1, 6.65, (z0 + z1 - 2.9) / 2), Color = COLORS.cream }, hut)
	signGui(sign, Enum.NormalId.Left, "WATCHMAN", COLORS.barnRed)
	-- the bell on a bracket by the road window, and the spotlight on the roof
	local bellAt = frame * CFrame.new(x0 + 1.5, 6.2, z0 - 1.2)
	box("BellBracket", x0 + 1.35, 7.2, z0 - 1.35, x0 + 1.65, 7.5, z0 + 0.25, IRON)
	local bell = meshOr("AlarmBell", bellAt, 1, hut, function()
		Parts.cylinder("AlarmBell", bellAt * CFrame.new(0, 0.5, 0), 1.0, 1.0, { Color = BRASS }, hut)
	end)
	if bell then
		bell.Name = "AlarmBell"
	end
	local lampAt = frame * CFrame.new((x0 + x1) / 2, ridge + 0.7, z0 + 1.2)
	local lamp = meshOr("Spotlight", lampAt, 1, hut, function()
		Parts.cylinder("Spotlight", lampAt * CFrame.new(0, 0.6, 0), 1.2, 1.2, { Color = IRON }, hut)
	end)
	if lamp then
		lamp.Name = "Spotlight"
	end
	-- (the light itself: the clients turn this and the lamp to the thief)
	local beam = Parts.prop({ Name = "SpotBeam", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = lampAt * CFrame.new(0, 0.6, 0), CastShadow = false }, hut)
	beam.CanQuery = false
	local light = Instance.new("SpotLight")
	light.Name = "Beam"
	light.Color = Color3.fromRGB(255, 246, 214)
	light.Range = 60
	light.Angle = 30
	light.Brightness = 0
	light.Face = Enum.NormalId.Front
	light.Shadows = true
	light.Parent = beam
	hut.Parent = model
end

------------------------------------------------------------------------
-- Domes over the field

-- The dome over a farm's field (kind "Shield" · "Grace" · "Watch", or nil
-- for none), with a sign over it counting down to `ends` (server time; the
-- clients show the time left).
function DefenceArt.dome(model: Model, frame: CFrame, kind: string?, ends: number?)
	local old = model:FindFirstChild("Dome")
	if old and (old:GetAttribute("Kind") ~= kind) then
		old:Destroy()
		old = nil
	end
	if not kind then
		return
	end
	if old then
		old:SetAttribute("Ends", ends)
		return
	end
	local look = DOME[kind]
	local field = PlotLayout.PLOT.field
	local side = field.size * field.tile
	local centre = Vector3.new(field.across + side / 2, 0, field.depth + side / 2)
	local dome = Parts.prop({ Name = "Dome", Size = Vector3.new(4, 4, 4), CFrame = frame * CFrame.new(centre), Color = look.color,
		Material = Enum.Material.ForceField, Transparency = 0, CastShadow = false }, nil)
	dome.CanQuery = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(side * 1.34, 52, side * 1.34) / 4 -- (a low dome, inside the fences: the half under the ground doesn't show)
	mesh.Parent = dome
	dome:SetAttribute("Kind", kind)
	dome:SetAttribute("Ends", ends)
	dome:SetAttribute("Title", look.title)
	local gui = Instance.new("BillboardGui")
	gui.Name = "DomeSign"
	gui.Size = UDim2.fromOffset(260, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 30, 0)
	gui.MaxDistance = 400
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 252, 240)
	label.TextStrokeColor3 = Color3.fromRGB(46, 34, 24)
	label.TextStrokeTransparency = 0
	label.Text = look.title
	label.Parent = gui
	gui.Parent = dome
	dome.Parent = model
end

------------------------------------------------------------------------

-- The parts every farm has: the back fence, the gate's leaves, the alarm
-- light (World/WorldBuilder).
function DefenceArt.build(model: Model, frame: CFrame)
	DefenceArt.backFence(model, frame, false)
	buildGate(model, frame)
	DefenceArt.setGate(model, true, false)
	buildBeacon(model, frame)
end

return DefenceArt
