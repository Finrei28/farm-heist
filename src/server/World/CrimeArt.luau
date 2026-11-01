-- The things raids add to characters (docs/ArtDirection.md §9): the bat an
-- owner holds inside their own farm, and the Loot Sack on a thief's back,
-- bigger than a head, with the top of the last crop taken sticking out. Both
-- are made by the server (CrimeService), so everyone sees the same thing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Parts = require(script.Parent.Parts)
local FarmArt = require(script.Parent.FarmArt)
local Crime = require(ReplicatedStorage.Shared.Config.Crime)

local CrimeArt = {}

local WOOD = Color3.fromRGB(222, 176, 112)
local WOOD_DARK = Color3.fromRGB(184, 136, 80)
local TAPE = Color3.fromRGB(200, 69, 45) -- barn red grip tape
local BURLAP = Color3.fromRGB(190, 148, 96)
local BURLAP_DARK = Color3.fromRGB(150, 110, 66)
local ROPE = Color3.fromRGB(226, 204, 158)

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

-- The Loot Sack on a character's back (replaced whenever what's in it
-- changes): a burlap bag that fills out with the weight, tied at the neck
-- with the last crop's top sticking out, on a rope strap across the chest.
function CrimeArt.showSack(character: Model, weight: number, topCrop: string?)
	local old = character:FindFirstChild("LootSack")
	if old then
		old:Destroy()
	end
	if weight <= 0 then
		return
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "LootSack"
	local fill = math.clamp(weight / Crime.SACK_CAPACITY, 0, 1)
	local d = 1.7 + 0.6 * fill -- (a head is about 1.2: even a light sack is bigger)
	-- (snug on the back, a little high, leaning out over the shoulders)
	local back = torso.CFrame * CFrame.new(0, 0.3, torso.Size.Z / 2 + d * 0.36) * CFrame.Angles(math.rad(-12), 0, 0)
	local bag = loose({ Name = "Bag", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d * 1.05, d * 0.9), CFrame = back, Color = BURLAP }, model)
	local parts = { bag }
	table.insert(parts, loose({ Name = "Patch", Size = Vector3.new(d * 0.32, d * 0.3, 0.12), CFrame = back * CFrame.new(-d * 0.18, -d * 0.12, d * 0.43) * CFrame.Angles(0, 0, math.rad(12)),
		Color = BURLAP_DARK }, model))
	local neck = back * CFrame.new(0, d * 0.5, 0)
	table.insert(parts, loose({ Name = "Neck", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, d * 0.42, d * 0.42),
		CFrame = neck * CFrame.Angles(0, 0, math.rad(90)), Color = BURLAP_DARK }, model))
	table.insert(parts, loose({ Name = "Tie", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.16, d * 0.46, d * 0.46),
		CFrame = neck * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = ROPE }, model))
	if topCrop then
		local color = FarmArt.cropColor(topCrop)
		table.insert(parts, loose({ Name = "CropTop", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.8, 0.9),
			CFrame = neck * CFrame.new(0, 0.55, 0), Color = color }, model))
		for i = 0, 2 do
			table.insert(parts, loose({ Name = "Leaf", Size = Vector3.new(0.18, 0.75, 0.32),
				CFrame = neck * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, math.rad(i * 120), math.rad(22)) * CFrame.new(0, 0.1, 0.12),
				Color = Parts.COLORS.leaf }, model))
		end
	end
	-- the strap: from the bag's neck over the shoulder, down across the chest
	local strap = loose({ Name = "Strap", Size = Vector3.new(0.22, torso.Size.Y * 1.25, 0.14),
		CFrame = torso.CFrame * CFrame.new(0, 0.05, -torso.Size.Z / 2 - 0.08) * CFrame.Angles(0, 0, math.rad(38)), Color = ROPE }, model)
	table.insert(parts, strap)
	for _, p in parts do
		weld(torso :: BasePart, p)
	end
	model.Parent = character
end

return CrimeArt
