-- Running (docs/GameDesign.md §4.10): hold Left Shift (keyboard) or press the
-- left stick (gamepad); on touch screens a Run button above the jump button
-- (a wooden stamp with a boot) toggles it. Changing WalkSpeed here is enough: each client moves its own
-- character, and MovementService allows for running speed. Carrying a
-- stolen crop (the StolenCrop attribute, CrimeService) on a farm you only
-- walk, at 85%, and the boot greys out; the server's movement check holds you
-- to it. Off farmland nobody can stop you, so you can run (LootRules.slowed).
-- Defences slow you too (§4.11): the guard dog has you by the trousers
-- (Slow until SlowUntil, DefenceService), or you're in someone's mud
-- (GateController calls setMud).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage:WaitForChild("Shared").Config.Settings)
local LootRules = require(ReplicatedStorage:WaitForChild("Shared").LootRules)
local UI = require(script.Parent.Parent.UI)

local SprintController = {}

local player = Players.LocalPlayer
local running = false
local mud = 0
local GAP = 10 -- pixels between the Run button and the jump button

-- Whether the stolen crop in your hands slows you here.
local function burdened(): boolean
	return LootRules.slowed(player:GetAttribute("StolenCrop") ~= nil, player:GetAttribute("InFarm") or 0)
end

-- What slows you now (0–1 of your speed taken away, the dog and mud together).
local function slowed(): number
	local keep = 1 - mud
	if (player:GetAttribute("SlowUntil") or 0) > workspace:GetServerTimeNow() then
		keep *= 1 - (player:GetAttribute("Slow") or 0)
	end
	return 1 - keep
end

local function applySpeed()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local speed = if burdened() then LootRules.speed(Settings.WALK_SPEED, true)
			elseif running then Settings.RUN_SPEED
			else Settings.WALK_SPEED
		speed *= 1 - slowed()
		if math.abs(humanoid.WalkSpeed - speed) > 0.01 then
			humanoid.WalkSpeed = speed
		end
	end
end

function SprintController.setMud(slow: number)
	if slow ~= mud then
		mud = slow
		applySpeed()
	end
end

-- The touch button: a small wooden stamp with a boot on it.
local holder, button = UI.stamp({ name = "RunStamp", text = "👢", kind = "wood", diameter = 56, textSize = 24, anchor = Vector2.new(0.5, 1), parent = UI.screen })
holder.Visible = false

button.Activated:Connect(function()
	running = not running
	UI.setStampKind(holder, if running then "blue" else "wood")
	applySpeed()
end)

-- Above the jump button, centred on it (its size and place vary by phone).
local function place()
	local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
	local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
	local shown = UI.touch and jump ~= nil and jump:IsA("GuiObject") and jump.Visible and jump.AbsoluteSize.X > 0
	holder.Visible = shown
	if not shown then
		return
	end
	local size = math.clamp(math.round(jump.AbsoluteSize.X * 0.7), 44, 64)
	holder.Size = UDim2.fromOffset(size, size)
	local origin = UI.screen.AbsolutePosition
	holder.Position = UDim2.fromOffset(
		math.round(jump.AbsolutePosition.X + jump.AbsoluteSize.X / 2 - origin.X),
		math.round(jump.AbsolutePosition.Y - GAP - origin.Y)
	)
end

function SprintController.Start()
	ContextActionService:BindAction("Sprint", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			running = true
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			running = false
		end
		applySpeed()
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	task.spawn(function()
		while true do
			place()
			task.wait(1)
		end
	end)
	-- (the dog lets go when SlowUntil passes)
	task.spawn(function()
		while true do
			task.wait(0.25)
			applySpeed()
		end
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		applySpeed()
	end)
	local function cropChanged()
		holder.BackgroundTransparency = if burdened() then 0.5 else 0
		applySpeed()
	end
	player:GetAttributeChangedSignal("StolenCrop"):Connect(cropChanged)
	player:GetAttributeChangedSignal("InFarm"):Connect(cropChanged)
	applySpeed()
end

return SprintController
