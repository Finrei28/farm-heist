-- Ways in and out of farms on your own screen (docs/GameDesign.md §4.1,
-- §4.11). Your client moves your character, so whether a gateway stops you
-- is decided here, from what the server writes on each plot model:
--   * a gate's GateBlocker (it's there while the Gate Lock is on or the
--     Watchman has shut the gate): it stops you unless the farm is yours,
--     you're Trusted there, or you're walking out; a gate the Watchman shut
--     stops that farm's Suspects carrying a stolen crop both ways (shared/DefenceRules.gateBlocks;
--     DefenceService sends back anyone who slips through);
--   * a store's StaffDoorBlocker: only the owner and their Trusted friends
--     go through (StoreService swings the door open for everyone to see);
--   * mud: on someone else's mud patch (unless they trust you) you walk
--     slower (SprintController).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defences = require(Shared.Config.Defences)
local DefenceRules = require(Shared.DefenceRules)
local PlotLayout = require(Shared.PlotLayout)

local SprintController = require(script.Parent.SprintController)

local GateController = {}

local TICK = 0.1
local player = Players.LocalPlayer

local function now(): number
	return workspace:GetServerTimeNow()
end

-- This client's part in a farm: its own, Trusted there.
local function standing(model: Instance, index: number): (boolean, boolean)
	return (player:GetAttribute("Plot") or 0) == index, DefenceRules.inTrustedText(model:GetAttribute("Trusted"), player.UserId)
end

local function setCollide(part: Instance?, collide: boolean)
	if part and part:IsA("BasePart") and part.CanCollide ~= collide then
		part.CanCollide = collide
	end
end

local function update()
	local world = workspace:FindFirstChild("World")
	if not world then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local here = player:GetAttribute("InFarm") or 0
	local mud = 0
	for index = 1, PlotLayout.COUNT do
		local model = world:FindFirstChild(`Plot{index}`)
		if not model then
			continue
		end
		local mine, trusted = standing(model, index)
		-- the gate
		local blocker = model:FindFirstChild("GateBlocker")
		if blocker then
			setCollide(blocker, DefenceRules.gateBlocks({
				mine = mine, trusted = trusted, locked = model:GetAttribute("GateLocked") == true,
				shut = (model:GetAttribute("GateShutUntil") or 0) > now(), suspect = (player:GetAttribute("SuspectOf") or 0) == index,
				carrying = player:GetAttribute("StolenCrop") ~= nil, direction = if here == index then "Out" else "In",
			}))
		end
		-- the staff door
		local store = model:FindFirstChild("Store")
		local building = store and store:FindFirstChild("Building")
		local door = building and building:FindFirstChild("StaffDoor")
		setCollide(door and door:FindFirstChild("StaffDoorBlocker"), not mine and not trusted)
		-- mud
		local defences = model:FindFirstChild("Defences")
		if defences and root and not mine and not trusted then
			local p = PlotLayout.frame(index):PointToObjectSpace(root.Position)
			for _, holder in defences:GetChildren() do
				local spot = if holder.Name == "MudPatch" then holder:GetAttribute("Spot") else nil
				local _, n = DefenceRules.spotKind(spot or "")
				if n then
					local at = PlotLayout.yardSpot(n)
					if math.abs(p.X - at.X) <= PlotLayout.YARD_SPOT / 2 and math.abs(p.Z - at.Z) <= PlotLayout.YARD_SPOT / 2 and p.Y < 8 then
						mud = Defences.MUD_SLOW
					end
				end
			end
		end
	end
	SprintController.setMud(mud)
end

function GateController.Start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(update)
			if not ok then
				warn(`[GateController] {err}`)
			end
		end
	end)
end

return GateController
