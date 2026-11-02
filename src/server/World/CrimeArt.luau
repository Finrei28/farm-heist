-- The things raids add to characters (docs/ArtDirection.md §9): the bat an
-- owner holds inside their own farm, and the stolen crop a thief holds up
-- over their head (World/ProduceArt), or drops when they're bonked. All made by the server
-- (CrimeService), so everyone sees the same thing; how arms hold them is
-- each client's (client/PoseController).
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

-- The bat: a Tool (CrimeService gives it while you're in your own farm and
-- takes it away when you step out). A taped grip with a knob, a long wooden
-- barrel with a rounded end. The barrel points up the handle's +Y.
function CrimeArt.bat(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Bat"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Bonk thieves in your farm"
	tool.Grip = CFrame.new(0, -0.55, 0)
	local handle = loose({ Name = "Handle", Size = Vector3.new(0.38, 1.9, 0.38), Color = TAPE }, tool)
	handle.Shape = Enum.PartType.Block
	local base = handle.CFrame
	local function rod(name: string, y: number, length: number, diameter: number, color: Color3)
		local p = loose({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, diameter, diameter),
			CFrame = base * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color }, tool)
		weld(handle, p)
		return p
	end
	local knob = loose({ Name = "Knob", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = base * CFrame.new(0, -1.0, 0), Color = WOOD_DARK }, tool)
	weld(handle, knob)
	rod("Neck", 1.2, 0.6, 0.5, WOOD)
	rod("Barrel", 2.4, 1.9, 0.78, WOOD)
	rod("Band", 1.85, 0.12, 0.8, WOOD_DARK)
	local tip = loose({ Name = "Tip", Shape = Enum.PartType.Ball, Size = Vector3.new(0.78, 0.78, 0.78), CFrame = base * CFrame.new(0, 3.35, 0), Color = WOOD }, tool)
	weld(handle, tip)
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
