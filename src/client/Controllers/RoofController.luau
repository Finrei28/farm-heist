-- See-through roofs (docs/GameDesign.md §4.8, ArtDirection §10). While your
-- character is inside a building that has one, its roof (with what stands
-- on it and the ceiling lamps) fades away on your screen only, so the
-- camera can rise over the walls and look down into the room instead of
-- being pushed up behind your head by the ceiling. A building opts in with
-- an invisible part named "Interior" (the room's box) beside its "Roof"
-- model: every store building now (World/StoreArt), the enclosed warehouses
-- from week 4. Nothing changes for anyone else, the lamps' lights keep
-- shining, and the light outside stays exactly as it is (an owner in the
-- store must still see a thief in the field). Decorate hides the roof its
-- own way, so this waits while it's on.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DecorateController = require(script.Parent.DecorateController)

local RoofController = {}

local FADE = 0.25 -- seconds to fade out (or back)
local ENTER, LEAVE = 0.3, 1 -- studs inside the walls before it fades out; outside them before it comes back (no flicker in the doorway)
-- The roof's shade (see shade()): how far toward the sun its stand-in goes.
-- Roblox drew the sun's shadow from 600 to 1,500 studs away in Studio and
-- not from 3,000; at 800 the stand-in is smaller than the sun's glare, so
-- it disappears into it even if you look straight at the sun.
local SHADE_DISTANCE = 800
local SHADE_COLOR = Color3.fromRGB(255, 252, 240) -- (glowing white, like the sun it sits in front of)

local player = Players.LocalPlayer
local rooms = {} -- [Interior part] = { alpha, inside, guis = { [gui] = true }, shade = Part? }
local shades = Instance.new("Folder")
shades.Name = "RoofShades" -- (this screen's only)

local function track(part: Instance)
	if part.Name == "Interior" and part:IsA("BasePart") then
		rooms[part] = { alpha = 0, inside = false, guis = {} }
	end
end

local function isInside(part: BasePart, position: Vector3, was: boolean): boolean
	local p = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2 + Vector3.one * (if was then LEAVE else -ENTER)
	return math.abs(p.X) < half.X and math.abs(p.Y) < half.Y and math.abs(p.Z) < half.Z
end

-- Fades the roof's parts to `alpha` (1 = gone; a part that's this see-through
-- doesn't stop the camera either) and switches its signs' words off past
-- halfway: a SurfaceGui still shows on an invisible part.
local function apply(roof: Instance, room, alpha: number)
	for _, p in roof:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = alpha
		elseif p:IsA("SurfaceGui") or p:IsA("BillboardGui") then
			if alpha > 0.5 and p.Enabled then
				p.Enabled = false
				room.guis[p] = true
			elseif alpha <= 0.5 and room.guis[p] then
				p.Enabled = true
				room.guis[p] = nil
			end
		end
	end
end

-- An invisible roof casts no shadow (not even 97% invisible), so with it
-- gone the sun would pour into the room and glare. Changing the light would
-- change it everywhere on your screen, the farm included. Instead, a
-- stand-in for the roof goes far along the line to the sun: the sun's rays
-- are parallel, so it casts the roof's own shadow on the room and nowhere
-- else, while it sits in the sky, lost in the sun's glare. It follows the
-- sun; at night there's nothing to shade. (The room still sees the sky, so
-- it's lit like shade outdoors.)
local function shade(part: BasePart, room, on: boolean)
	local sun = Lighting:GetSunDirection()
	if not on or sun.Y < 0.02 then
		if room.shade then
			room.shade:Destroy()
			room.shade = nil
		end
		return
	end
	if not room.shade then
		local p = Instance.new("Part")
		p.Name = "RoofShade"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.Neon
		p.Color = SHADE_COLOR
		p.Size = Vector3.new(part.Size.X + 3, 0.4, part.Size.Z + 3) -- (the room, its walls and a little more)
		p.Parent = shades
		room.shade = p
	end
	room.shade.CFrame = part.CFrame * CFrame.new(0, part.Size.Y / 2 + 0.5, 0) + sun * SHADE_DISTANCE
end

local decorating = false -- (Decorate was on last frame)

-- Fades each building's roof toward where it should be, with its shade.
local function update(dt: number)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for part, room in rooms do
		local roof = part.Parent and part.Parent:FindFirstChild("Roof")
		if not part:IsDescendantOf(workspace) then
			shade(part :: BasePart, room, false)
			rooms[part] = nil -- (the building was rebuilt bigger: its new Interior is tracked)
			continue
		elseif not roof then
			continue
		end
		room.inside = root ~= nil and isInside(part :: BasePart, root.Position, room.inside)
		local target = if room.inside then 1 else 0
		-- (Decorate puts the roof back when it closes: hide it again if you're still inside)
		if room.alpha ~= target or (decorating and room.alpha > 0) then
			room.alpha = math.clamp(room.alpha + (if target > room.alpha then dt else -dt) / FADE, 0, 1)
			apply(roof, room, room.alpha)
		end
		shade(part :: BasePart, room, room.alpha > 0)
	end
	decorating = false
end

local function step(dt: number)
	if not DecorateController.isActive() then
		update(dt)
		return
	end
	-- Decorate looks down into your own store with its roof off: shade that one
	decorating = true
	local own = workspace.World:FindFirstChild(`Plot{player:GetAttribute("Plot") or 0}`)
	local building = own and own:FindFirstChild("Store") and own.Store:FindFirstChild("Building")
	for part, room in rooms do
		shade(part :: BasePart, room, building ~= nil and part.Parent == building)
	end
end

function RoofController.Start()
	shades.Parent = workspace
	local world = workspace:WaitForChild("World")
	for _, descendant in world:GetDescendants() do
		track(descendant)
	end
	world.DescendantAdded:Connect(track)
	RunService.RenderStepped:Connect(step)
end

return RoofController
