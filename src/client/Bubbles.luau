-- Speech bubbles (Goldie's patter, a bidder's call, what shoppers say) are
-- drawn over everything, so a curtain or a wall behind the speaker never
-- cuts one off, and hidden while something solid stands between you and
-- the speaker, so none shows through a wall from outside.
--   Bubbles.set(gui, on)   say it, or stop. Use this for a bubble's
--                          BillboardGui instead of setting Enabled: whether
--                          it's in sight is decided here
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Bubbles = {}

local CHECK = 0.15 -- seconds between looks
local NEAR = 1.5 -- studs from the speaker: what stops a look there doesn't count

local shown = {} -- [BillboardGui] = true: bubbles saying something
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true -- (walls and shelves; not leaves, lamps or trim)

local function inSight(gui: BillboardGui): boolean
	local adornee = gui.Adornee
	local camera = workspace.CurrentCamera
	if not adornee or not adornee:IsA("BasePart") or not camera or not gui:IsDescendantOf(workspace) then
		return false
	end
	local eye = camera.CFrame.Position
	local spot = adornee.Position + Vector3.new(0, gui.StudsOffset.Y + gui.StudsOffsetWorldSpace.Y, 0)
	params.FilterDescendantsInstances = { camera, Players.LocalPlayer.Character, adornee.Parent }
	local hit = workspace:Raycast(eye, spot - eye, params)
	if not hit or (hit.Position - spot).Magnitude < NEAR then
		return true
	end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil -- (only someone standing in the way)
end

function Bubbles.set(gui: BillboardGui, on: boolean)
	if on == (shown[gui] == true) then
		return
	end
	shown[gui] = if on then true else nil
	gui.AlwaysOnTop = true
	gui.Enabled = on and inSight(gui)
end

local waited = 0
RunService.Heartbeat:Connect(function(dt)
	waited += dt
	if waited < CHECK then
		return
	end
	waited = 0
	for gui in shown do
		if gui.Parent then
			gui.Enabled = inSight(gui)
		else
			shown[gui] = nil -- (its speaker's gone)
		end
	end
end)

return Bubbles
