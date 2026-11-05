-- The things raids add to characters (docs/ArtDirection.md §9): the bat an
-- owner holds inside their own farm, and the stolen crop a thief holds up
-- over their head (World/ProduceArt), or drops when they're bonked. All made by the server
-- (CrimeService), so everyone sees the same thing; how arms hold them is
-- each client's (client/PoseController).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Config.Cosmetics)
local Meshes = require(script.Parent.Meshes)
local Parts = require(script.Parent.Parts)
local ProduceArt = require(script.Parent.ProduceArt)

local CrimeArt = {}

local WOOD = Color3.fromRGB(222, 176, 112)
local WOOD_DARK = Color3.fromRGB(184, 136, 80)
local TAPE = Color3.fromRGB(200, 69, 45) -- barn red grip tape
local CARRIED_SCALE = 1.2 -- stolen crops held up are this much bigger than in a crate

local function loose(props, parent: Instance): BasePart
	local p = Parts.part(props, parent)
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- An ellipsoid welded to the bat's handle (a block drawn as a sphere
-- stretched to its size).
local function egg(tool: Tool, handle: BasePart, name: string, at: CFrame, size: Vector3, color: Color3): BasePart
	local p = loose({ Name = name, Size = size, CFrame = at, Color = color }, tool)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	weld(handle, p)
	return p
end

-- A cylinder along the handle, its middle `y` up it.
local function rod(tool: Tool, handle: BasePart, name: string, y: number, length: number, diameter: number, color: Color3, material: Enum.Material?): BasePart
	local p = loose({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, diameter, diameter),
		CFrame = handle.CFrame * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = material }, tool)
	weld(handle, p)
	return p
end

-- The classic bat: a taped grip with a knob, a long wooden barrel with a
-- rounded end.
local function classicBat(tool: Tool, handle: BasePart)
	handle.Color = TAPE
	local base = handle.CFrame
	local knob = loose({ Name = "Knob", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = base * CFrame.new(0, -1.0, 0),
		Color = WOOD_DARK }, tool)
	weld(handle, knob)
	rod(tool, handle, "Neck", 1.2, 0.6, 0.5, WOOD)
	rod(tool, handle, "Barrel", 2.4, 1.9, 0.78, WOOD)
	rod(tool, handle, "Band", 1.85, 0.12, 0.88, WOOD_DARK) -- (0.05 proud of the barrel: no flicker)
	local tip = loose({ Name = "Tip", Shape = Enum.PartType.Ball, Size = Vector3.new(0.78, 0.78, 0.78), CFrame = base * CFrame.new(0, 3.35, 0),
		Color = WOOD }, tool)
	weld(handle, tip)
end

-- The Golden Bat, the dearest skin, made like a king's sceptre: a crimson
-- grip bound in gold wire, a ruby in the pommel, a gold collar, a barrel
-- turned in three widening stages with rubies set round its head, and a
-- crown of gold points round a big ruby at the top. It glows: the gold is
-- Neon (the darker rings aren't, so its stages still show), a soft halo
-- pulses round its head, it lights what's near it and sparkles, and a swing
-- leaves a gold trail (a bonk's burst of gold is CrimeController's). All of
-- it is looks: it's the plain bat's length.
local RUBY = Color3.fromRGB(196, 18, 44)
local VELVET = Color3.fromRGB(150, 22, 44)
local function goldenBat(tool: Tool, handle: BasePart, look)
	local base = handle.CFrame
	local shine, deep = look.wood, look.dark
	local function gold(name: string, y: number, length: number, diameter: number, color: Color3): BasePart
		local p = rod(tool, handle, name, y, length, diameter, color)
		if color == shine then
			p.Material = Enum.Material.Neon
		end
		return p
	end
	-- a jewel: a cube stood on its corner
	local function ruby(name: string, at: CFrame, size: number)
		local p = loose({ Name = name, Size = Vector3.new(size, size, size), Color = RUBY, Material = Enum.Material.Neon,
			CFrame = at * CFrame.Angles(0, 0, math.rad(45)) * CFrame.Angles(math.rad(35.26), 0, 0) }, tool)
		weld(handle, p)
	end

	rod(tool, handle, "Grip", 0, 1.9, 0.46, VELVET)
	for _, y in { -0.62, -0.2, 0.22, 0.64 } do
		gold("Wire", y, 0.08, 0.52, shine)
	end
	gold("Pommel", -1.02, 0.16, 0.68, deep)
	ruby("PommelRuby", base * CFrame.new(0, -1.24, 0), 0.34)

	gold("Collar", 1.02, 0.14, 1.0, shine)
	gold("Shaft", 1.345, 0.51, 0.58, shine)
	gold("Ring", 1.65, 0.1, 0.76, deep)
	gold("Body", 1.975, 0.55, 0.72, shine)
	gold("Ring", 2.3, 0.1, 0.92, deep)
	local head = gold("BatHead", 2.725, 0.75, 0.9, shine)
	gold("CrownBand", 3.16, 0.12, 1.06, deep)
	for i = 0, 2 do
		ruby("Ruby", base * CFrame.new(0, 2.72, 0) * CFrame.Angles(0, math.rad(i * 120), 0) * CFrame.new(0, 0, -0.43), 0.17)
	end
	local dome = loose({ Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(0.86, 0.86, 0.86), CFrame = base * CFrame.new(0, 3.2, 0),
		Color = shine, Material = Enum.Material.Neon }, tool)
	weld(handle, dome)
	for i = 0, 5 do
		local round = base * CFrame.Angles(0, math.rad(i * 60), 0) * CFrame.new(0, 0, -0.44)
		local point = loose({ Name = "CrownPoint", Size = Vector3.new(0.16, 0.36, 0.1), CFrame = round * CFrame.new(0, 3.36, 0), Color = shine, Material = Enum.Material.Neon }, tool)
		weld(handle, point)
		local bead = loose({ Name = "CrownBead", Shape = Enum.PartType.Ball, Size = Vector3.new(0.22, 0.22, 0.22), CFrame = round * CFrame.new(0, 3.56, 0),
			Color = deep }, tool)
		weld(handle, bead)
	end
	ruby("CrownRuby", base * CFrame.new(0, 3.62, 0), 0.36)

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 226, 130))
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Lifetime = NumberRange.new(0.5, 0.9)
	sparkles.Rate = 14
	sparkles.Speed = NumberRange.new(0.4, 1.1)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.LightEmission = 0.7
	sparkles.Parent = head
	local halo = Instance.new("ParticleEmitter")
	halo.Name = "Halo"
	halo.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	halo.Color = ColorSequence.new(Color3.fromRGB(255, 206, 90))
	halo.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4), NumberSequenceKeypoint.new(0.5, 3.6), NumberSequenceKeypoint.new(1, 2.4) })
	halo.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) })
	halo.Lifetime = NumberRange.new(1.2, 1.2)
	halo.Rate = 3
	halo.Speed = NumberRange.new(0, 0)
	halo.RotSpeed = NumberRange.new(-20, 20)
	halo.Rotation = NumberRange.new(0, 360)
	halo.LockedToPart = true
	halo.LightEmission = 1
	halo.LightInfluence = 0
	halo.ZOffset = -1.5 -- (behind the bat: over it, it washes the gold out)
	halo.Parent = head
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = Color3.fromRGB(255, 200, 90)
	glow.Range = 8 -- (any more and it bleaches the grass and whatever's beside it)
	glow.Brightness = 0.8
	glow.Parent = head

	local from, to = Instance.new("Attachment"), Instance.new("Attachment")
	from.Name, to.Name = "TrailFrom", "TrailTo"
	from.Position, to.Position = Vector3.new(0, 1.3, 0), Vector3.new(0, 3.9, 0)
	from.Parent, to.Parent = handle, handle
	local trail = Instance.new("Trail")
	trail.Name = "GoldTrail"
	trail.Attachment0, trail.Attachment1 = from, to
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 226, 120), Color3.fromRGB(240, 150, 40))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = 0.22
	trail.MinLength = 0.15
	trail.LightEmission = 0.6
	trail.Parent = handle
end

-- The Baguette: a real loaf, no bat under it. A straight middle, a long
-- tapered end either side browned at the very tip, and three rows of
-- slanted slashes down it (a dark lip, the pale crumb in it), so some show
-- whichever way it's turned. They sit just under the crust's curve: only
-- their middles stand proud, so nothing sticks out of the loaf's outline.
local LOAF = 0.86
local LOAF_END = 2.7
local CRUMB = Color3.fromRGB(244, 222, 170)
local function baguette(tool: Tool, handle: BasePart, look)
	local base = handle.CFrame
	rod(tool, handle, "Loaf", 1.2, 2.4, LOAF, look.wood)
	for _, y in { 0, 2.4 } do
		egg(tool, handle, "LoafEnd", base * CFrame.new(0, y, 0), Vector3.new(LOAF, LOAF_END, LOAF), look.wood)
	end
	for _, y in { -0.96, 3.36 } do
		egg(tool, handle, "LoafTip", base * CFrame.new(0, y, 0), Vector3.new(0.62, 0.84, 0.62), look.dark)
	end
	for row = 0, 2 do
		for i, y in { 0.45, 1.1, 1.75, 2.4 } do
			local at = base * CFrame.new(0, y + row * 0.2, 0) * CFrame.Angles(0, math.rad(row * 120), 0)
				* CFrame.new(0, 0, -LOAF / 2 + 0.035) * CFrame.Angles(0, 0, math.rad(38))
			egg(tool, handle, "Crust", at, Vector3.new(0.34, 0.86, 0.08), look.dark)
			egg(tool, handle, "Score", at * CFrame.new(0, 0, -0.012), Vector3.new(0.22, 0.72, 0.08), CRUMB)
		end
	end
end

-- The Carrot Club: a giant carrot held by its root, the crop's own meshes
-- (World/Meshes), stretched so it's the bat's length, its leaves at the
-- swinging end. Until the meshes are imported, rings narrowing to the root.
local CARROT_CROWN = 2.9 -- up the handle
local CARROT_WIDTH, CARROT_LENGTH, CARROT_LEAVES = 1.3, 1.55, 0.52 -- × the crop's mesh
local CARROT_RINGS = { 1.14, 1.08, 1.0, 0.92, 0.84, 0.76, 0.68, 0.6, 0.52, 0.44, 0.36 }
local function carrot(tool: Tool, handle: BasePart, look)
	local crown = handle.CFrame * CFrame.new(0, CARROT_CROWN, 0)
	local root = Meshes.make("Carrot", crown, Vector3.new(CARROT_WIDTH, CARROT_LENGTH, CARROT_WIDTH), tool)
	local leaves = Meshes.make("CarrotTop", crown, CARROT_LEAVES, tool)
	if root and leaves then
		for _, p in { root, leaves } do
			p.Anchored = false
			p.Massless = true
			weld(handle, p)
		end
		return
	end
	local step = (CARROT_CROWN + 1.2) / #CARROT_RINGS
	for i, d in CARROT_RINGS do
		rod(tool, handle, "Root", CARROT_CROWN - (i - 0.5) * step, step + 0.02, d, if i % 2 == 0 then look.dark else look.wood)
	end
	for i = 1, 3 do
		local leaf = loose({ Name = `Leaf{i}`, Size = Vector3.new(0.14, 0.95, 0.42), Color = Color3.fromRGB(78, 159, 61),
			CFrame = crown * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, math.rad(i * 120), math.rad(18)) * CFrame.new(0, 0.3, 0) }, tool)
		weld(handle, leaf)
	end
end

local SHAPES = { golden = goldenBat, baguette = baguette, carrot = carrot }

-- The bat: a Tool (CrimeService gives it while you're in your own farm and
-- takes it away when you step out), pointing up its handle's +Y.
-- skin: a bat skin's id (Config/Cosmetics; nil: the plain bat). Every skin
-- is about the same length and swings the same: only its look changes. A
-- skin with a shape of its own has no bat under it: the handle's hidden
-- inside what it's drawn as.
function CrimeArt.bat(skin: string?): Tool
	local item = skin and Cosmetics.ById[skin]
	local look = item and item.kind == "bat" and item.look or {}
	local tool = Instance.new("Tool")
	tool.Name = "Bat"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = if item then `{item.name}: bonk thieves in your farm` else "Bonk thieves in your farm"
	tool.Grip = CFrame.new(0, -0.55, 0)
	tool:SetAttribute("Skin", skin)
	local handle = loose({ Name = "Handle", Size = Vector3.new(0.38, 1.9, 0.38) }, tool)
	handle.Shape = Enum.PartType.Block
	local shape = SHAPES[look.shape]
	if shape then
		handle.Transparency = 1
		shape(tool, handle, look)
	else
		classicBat(tool, handle)
	end
	return tool
end

-- How high a character's head reaches, in their torso's frame (from the
-- neck joint, so a walk's bob doesn't matter), and the top of any hat or
-- hair on it.
local function headTops(torso: BasePart, head: BasePart, character: Model): (number, number)
	local neck = head:FindFirstChild("Neck") or torso:FindFirstChild("Neck")
	local centre = if neck and neck:IsA("Motor6D") and neck.Part0 == torso
		then (neck.C0 * neck.C1:Inverse()).Position.Y
		else torso.CFrame:PointToObjectSpace(head.Position).Y
	local top = centre + head.Size.Y / 2
	local hats = top
	for _, accessory in character:GetChildren() do
		local handle = accessory:IsA("Accessory") and accessory:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			local up = torso.CFrame:PointToObjectSpace(handle.Position).Y + handle.Size.Y / 2
			if up > hats and up < top + 3 then
				hats = up
			end
		end
	end
	return top, hats
end

-- How far a character's arm reaches from its shoulder joint (R15: the three
-- arm joints; otherwise a guess), and where that joint is in the torso.
local function armReach(character: Model, side: string): (number, Vector3?)
	local upper = character:FindFirstChild(`{side}UpperArm`)
	local lower = character:FindFirstChild(`{side}LowerArm`)
	local hand = character:FindFirstChild(`{side}Hand`)
	local shoulder = upper and upper:FindFirstChild(`{side}Shoulder`)
	local elbow = lower and lower:FindFirstChild(`{side}Elbow`)
	local wrist = hand and hand:FindFirstChild(`{side}Wrist`)
	if not (shoulder and elbow and wrist) then
		return 2.2, nil
	end
	local reach = (shoulder.C1.Position - elbow.C0.Position).Magnitude + (elbow.C1.Position - wrist.C0.Position).Magnitude + wrist.C1.Position.Magnitude
	return reach, shoulder.C0.Position
end

-- The stolen crops a thief carries, `count` of them (a whole patch: a bunch
-- of carrots, a basket of tomatoes, a pumpkin), held up over their head in
-- both hands (CrimeService; nil takes them away). They rest just over their
-- head (or their hat), welded to their torso; LeftHold and RightHold
-- attachments on the sides are where each client's PoseController puts the
-- hands, placed low enough for this character's arms to reach.
function CrimeArt.showCarried(character: Model, cropId: string?, count: number?)
	local old = character:FindFirstChild("CarriedCrop")
	if old then
		old:Destroy()
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local head = character:FindFirstChild("Head")
	if not cropId or not torso or not torso:IsA("BasePart") or not head or not head:IsA("BasePart") then
		return
	end
	local model, core = ProduceArt.build(cropId, CFrame.new(), count)
	model.Name = "CarriedCrop"
	-- a little bigger than life, to be seen across a farm
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Size *= CARRIED_SCALE
			p.CFrame = CFrame.new(p.Position * CARRIED_SCALE) * p.CFrame.Rotation
		elseif p:IsA("Attachment") then
			p.Position *= CARRIED_SCALE
		end
	end
	for _, name in { "Width", "Height", "HoldY" } do
		core:SetAttribute(name, core:GetAttribute(name) * CARRIED_SCALE)
	end
	local headTop, hatTop = headTops(torso, head, character)
	local bottom = math.clamp(hatTop - 0.25, headTop + 0.12, headTop + 0.6) -- (a tall hat pokes into it a little)
	local width, holdY = core:GetAttribute("Width"), core:GetAttribute("HoldY")
	local reach, shoulder = armReach(character, "Right")
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local side = width / 2 + (if hand and hand:IsA("BasePart") then hand.Size.X * 0.3 else 0.15) -- (palms on its sides, not sunk in)
	if shoulder then
		local y = holdY
		while y > 0.1 and (Vector3.new(side, bottom + y, 0) - shoulder).Magnitude > reach * 0.8 do -- (IK gives up near full stretch)
			y -= 0.05
		end
		holdY = y
	end
	for _, name in { "LeftHold", "RightHold" } do
		local spot = Instance.new("Attachment")
		spot.Name = name
		spot.Position = Vector3.new(if name == "LeftHold" then -side else side, holdY - core:GetAttribute("HoldY"), 0)
		spot.Parent = core
	end
	local at = torso.CFrame * CFrame.new(0, bottom, -0.05)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame = at * p.CFrame
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			weld(torso, p)
		end
	end
	model.Parent = character
end

-- A stolen crop a bonked thief dropped (CrimeService), `count` of it,
-- standing on the ground at `base` as big as when it was held up. Nothing
-- bumps into it or rays hit it; client CrimeController adds its label.
function CrimeArt.dropped(cropId: string, count: number, base: CFrame): Model
	local model = ProduceArt.build(cropId, CFrame.new(), count)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Size *= CARRIED_SCALE
			p.CFrame = base * (CFrame.new(p.Position * CARRIED_SCALE) * p.CFrame.Rotation)
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		elseif p:IsA("Attachment") then
			p.Position *= CARRIED_SCALE
		end
	end
	local core = model:FindFirstChild("Core")
	if core and core:IsA("BasePart") then
		model.PrimaryPart = core
		for _, name in { "Width", "Height", "HoldY" } do
			core:SetAttribute(name, (core:GetAttribute(name) or 0) * CARRIED_SCALE)
		end
	end
	return model
end

return CrimeArt
