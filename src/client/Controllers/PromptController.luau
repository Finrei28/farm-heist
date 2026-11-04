-- Prompts (docs/GameDesign.md §5.1): every ProximityPrompt in the world is
-- drawn in the Kraft & Crate look instead of Roblox's grey one: a little
-- wooden sign with a cream key cap ("E", the gamepad's button, or 👆 to tap
-- on a phone), what it is in small letters over what pressing does. Holding
-- fills the key cap with gold; the sign pops in and squashes when it fires.
-- Roblox still decides which prompt shows and handles the keys (its prompts
-- are just set to the Custom style); a tap or click on the sign holds it.
-- The sign is drawn on the screen over the thing it's for, above the HUD
-- (on a phone a sign in the world sat under the market ticker or the
-- HOME/TOWN signs, out of reach), and hides while a window is open.
--
-- Prompts with an OwnerId attribute (the land signs and obstacles,
-- LandService; the store's Fill) only show for that farm's owner: everyone
-- else's copy is switched off here, on their own screen.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.Parent.UI)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer

local PromptController = {}

local CAP = 40 -- the key cap, px
local HEIGHT = 52 -- the sign

local holder = make("ScreenGui", {
	Name = "Prompts",
	ResetOnSpawn = false,
	IgnoreGuiInset = true, -- (so the camera's viewport points land where they should)
	DisplayOrder = 5, -- (over the HUD)
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local function check(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Style = Enum.ProximityPromptStyle.Custom -- (drawn below)
	local owner = prompt:GetAttribute("OwnerId")
	if owner then
		prompt.Enabled = owner == player.UserId
	end
end

local function adorneeOf(prompt: ProximityPrompt): Instance?
	local parent = prompt.Parent
	if parent and parent:IsA("Model") then
		return parent.PrimaryPart
	end
	return parent
end

local INPUT = {
	[Enum.ProximityPromptInputType.Keyboard] = "Keyboard",
	[Enum.ProximityPromptInputType.Gamepad] = "Gamepad",
	[Enum.ProximityPromptInputType.Touch] = "Touch",
}

-- Draws one prompt while Roblox shows it; gone when it's hidden.
local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	local adornee = adorneeOf(prompt)
	if not adornee then
		return
	end
	local input = INPUT[inputType] or "Keyboard"
	if input == "Keyboard" and UI.inputKind() == "Touch" then
		input = "Touch"
	end
	local scale = if UI.compact then 0.85 else 1
	local gui = make("Frame", { -- (moved over its thing every frame: below)
		Name = "Prompt",
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
	})
	local pop = make("UIScale", { Scale = scale })
	local board = make("Frame", { -- the wooden sign (as wide as what's on it) ...
		Name = "Sign",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = gui,
	}, { pop, UI.corner(7), UI.stroke(UI.SEAM, 3) })
	UI.wood(board, 2, false)
	local sign = make("Frame", { -- ... and the row on it: the key cap, then the words
		Name = "Row",
		Size = UDim2.fromOffset(0, HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = board,
	}, {
		make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 14) }),
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local cap = UI.keycap({ size = CAP, zIndex = 2, parent = sign })
	cap.LayoutOrder = 1
	local face = cap.Face -- (held here: once the prompt hides, its parts are gone)
	local shown = UI.setKey(cap, input, prompt.KeyboardKeyCode, prompt.GamepadKeyCode, "👆")
	cap.Visible = shown
	local words = make("Frame", {
		Name = "Words", LayoutOrder = 2, Size = UDim2.fromOffset(0, HEIGHT - 8), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1, Parent = sign,
	}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder }) })
	local object = make("TextLabel", {
		Name = "Object", LayoutOrder = 1, Size = UDim2.fromOffset(0, 15), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
		Font = UI.HEAD, TextSize = 14, TextColor3 = Color3.fromRGB(240, 214, 160), TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2, Parent = words,
	})
	local action = make("TextLabel", {
		Name = "Action", LayoutOrder = 2, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
		Font = UI.HEAD, TextSize = 22, TextColor3 = C.cream, TextStrokeColor3 = UI.SEAM, TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, Parent = words,
	})
	local function texts()
		object.Text = prompt.ObjectText
		object.Visible = prompt.ObjectText ~= ""
		action.Text = if prompt.ActionText ~= "" then prompt.ActionText else "Use"
	end
	texts()
	-- a tap or a click holds it (Roblox handles the keys itself)
	local hit = make("TextButton", { Name = "Hit", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = board })
	local connections = {}
	local function on(signal, fn)
		table.insert(connections, signal:Connect(fn))
	end
	local pressed = false
	if prompt.ClickablePrompt then
		on(hit.InputBegan, function(io)
			if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
				pressed = true
				prompt:InputHoldBegin()
			end
		end)
		on(hit.InputEnded, function(io)
			if pressed and (io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1) then
				pressed = false
				prompt:InputHoldEnd()
			end
		end)
	end
	-- holding fills the key cap; letting go empties it
	local fill = face.Fill
	local filling: Tween? = nil
	on(prompt.PromptButtonHoldBegan, function()
		if filling then
			filling:Cancel()
		end
		face.Position = UDim2.fromOffset(0, 2)
		filling = TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
		filling:Play()
	end)
	on(prompt.PromptButtonHoldEnded, function()
		if filling then
			filling:Cancel()
		end
		face.Position = UDim2.new()
		fill.Size = UDim2.fromScale(1, 0)
	end)
	on(prompt.Triggered, function()
		face.BackgroundColor3 = C.gold
		if not UI.calm then
			pop.Scale = scale * 0.9
			TweenService:Create(pop, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = scale }):Play()
		end
		task.delay(0.2, function()
			face.BackgroundColor3 = C.cream
			if prompt.HoldDuration <= 0 then
				fill.Size = UDim2.fromScale(1, 0)
			end
		end)
	end)
	on(prompt:GetPropertyChangedSignal("ActionText"), texts)
	on(prompt:GetPropertyChangedSignal("ObjectText"), texts)
	-- in it pops
	if not UI.calm then
		pop.Scale = scale * 0.6
		TweenService:Create(pop, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = scale }):Play()
	end
	-- over its thing on the screen, every frame
	local camera = workspace.CurrentCamera
	local function place()
		local at = if adornee:IsA("Attachment") then adornee.WorldPosition elseif adornee:IsA("BasePart") then adornee.Position else nil
		if not at or not camera then
			gui.Visible = false
			return
		end
		local point, onScreen = camera:WorldToViewportPoint(at)
		gui.Visible = onScreen and point.Z > 0 and not UI.anyOpen()
		gui.Position = UDim2.fromOffset(math.round(point.X + prompt.UIOffset.X), math.round(point.Y + prompt.UIOffset.Y))
	end
	place()
	on(RunService.RenderStepped, place)
	gui.Parent = holder
	local hidden
	hidden = prompt.PromptHidden:Connect(function()
		hidden:Disconnect()
		for _, connection in connections do
			connection:Disconnect()
		end
		gui:Destroy()
	end)
	table.insert(connections, prompt.Destroying:Connect(function()
		gui:Destroy()
	end))
end

function PromptController.Start()
	workspace.DescendantAdded:Connect(check)
	for _, descendant in workspace:GetDescendants() do
		check(descendant)
	end
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			show(prompt, inputType)
		end
	end)
end

return PromptController
