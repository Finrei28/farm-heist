-- The ⚙️ Settings window (docs/GameDesign.md §5.6; shared/SettingsRules,
-- server SettingsService), the last crate in the side bar:
--   Sound:          music, sound effects, ambience (switches);
--   Screen:         flashing effects (0–100%), reduced motion, text size
--                   (80–125%: the words in windows and notes);
--   Other players:  trade requests, Quiet mode;
--   Your farm:      drop the Sprout Shield early (while it's up), the Farm
--                   Guide's card shown or hidden.
-- A switch is drawn as a switch (green and ON, or grey and OFF); a tap
-- flips it at once on your screen and the server saves it. The screen
-- settings land on the UI kit's flags (UI.calm, UI.flashing, UI.quiet,
-- UI.setTextScale), which the other controllers read.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GuideRules = require(Shared.GuideRules)
local Remotes = require(Shared.Remotes)
local SettingsRules = require(Shared.SettingsRules)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)
local HudController = require(script.Parent.HudController)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer
local SettingsAction = Remotes.func("SettingsAction")
local DefenceAction = Remotes.func("DefenceAction")
local GuideAction = Remotes.func("GuideAction")

local SettingsController = {}

local GREY = Color3.fromRGB(150, 140, 125)

local panel = UI.panel("Settings", { accent = Color3.fromRGB(110, 96, 80), width = 560, height = 440 })
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.list })

local ROWS = {
	{ section = "Sound" },
	{ key = "music", icon = "🎵", title = "Music", detail = "A gentle banjo tune in town" },
	{ key = "sfx", icon = "🔊", title = "Sound effects", detail = "Harvest pops, coins, the alarm's siren, bonks, the auction bell" },
	{ key = "ambience", icon = "🐦", title = "Ambience", detail = "Birdsong by day, crickets at night, rain and thunder" },
	{ section = "Screen" },
	{ key = "flashing", icon = "⚡", title = "Flashing effects", detail = "The theft alarm's red edge, lightning, the TRESPASSING sign" },
	{ key = "reducedMotion", icon = "🌀", title = "Reduced motion", detail = "No bobbing markers, pulsing buttons, blur or confetti" },
	{ key = "textSize", icon = "🔤", title = "Text size", detail = "The words in windows and notes" },
	{ section = "Other players" },
	{ key = "trades", icon = "🤝", title = "Trade requests", detail = "Let other players ask you to trade (you can still ask them)" },
	{ key = "quiet", icon = "🤫", title = "Quiet mode", detail = "Hides news for everyone: Hot Crops, Barley's rare seeds, other players' auction wins. Notes about you and your farm still show" },
	{ section = "Your farm" },
	{ special = "shield" },
	{ special = "guide" },
}

local pending = {} -- [key] = value tapped but not saved yet (shown at once)
local confirmDrop = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function value(key: string): any
	if pending[key] ~= nil then
		return pending[key]
	end
	local state = PlayerState.current
	return SettingsRules.get(state and state.settings, key)
end

-- The screen settings onto the UI kit's flags (read by the controllers).
local function apply()
	UI.calm = value("reducedMotion") == true
	UI.flashing = value("flashing")
	UI.quiet = value("quiet") == true
	UI.setTextScale(value("textSize"))
end

local render

local function set(key: string, newValue: any)
	pending[key] = newValue
	apply()
	render()
	task.spawn(function()
		local arg = if type(newValue) == "boolean" then (if newValue then "1" else "0") else tostring(newValue)
		local ok, result = pcall(SettingsAction.InvokeServer, SettingsAction, "Set", `{key}={arg}`)
		if not (ok and result and result.ok) then
			pending[key] = nil -- (back to what's saved)
			apply()
			render()
			if not (result and result.reason == "Cooldown") then
				UI.toast(Reasons(result and result.reason) or "Couldn't change that setting right now.", "Error", 2.5)
			end
		end
	end)
end

------------------------------------------------------------------------
-- Drawing

local function card(order: number, height: number): Frame
	return make("Frame", {
		Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = C.cream, LayoutOrder = order, ZIndex = 22, Parent = panel.list,
	}, { UI.corner(4), UI.stroke(C.stitch, 1.5) })
end

-- The icon, the title and the line under it, leaving `right` px for the control.
local function words(box: Frame, row, right: number)
	UI.label({ Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 6, 0.5, -20), Text = row.icon, TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 23, Parent = box })
	UI.fit(UI.label({ Size = UDim2.new(1, -(54 + right), 0, 22), Position = UDim2.fromOffset(50, 6), Font = UI.HEAD, TextSize = 18,
		Text = row.title, ZIndex = 23, Parent = box }), 12)
	UI.fit(UI.label({ Size = UDim2.new(1, -(54 + right), 1, -32), Position = UDim2.fromOffset(50, 28), Font = UI.BODY, TextSize = 14,
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(105, 85, 62), Text = row.detail,
		ZIndex = 23, Parent = box }), 10)
end

-- A switch: a rounded track (green ON or grey OFF) with its knob at that end.
local function switch(box: Frame, key: string)
	local on = value(key) == true
	local track = make("TextButton", {
		Name = "Switch", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(82, 36),
		BackgroundColor3 = if on then C.green else GREY, Text = "", AutoButtonColor = false, ZIndex = 23, Parent = box,
	}, { UI.corner(18), UI.stroke(UI.SEAM, 2) })
	UI.label({ Size = UDim2.new(1, -36, 1, 0), Position = UDim2.fromOffset(if on then 8 else 30, 0), Font = UI.HEAD, TextSize = 16,
		Text = if on then "ON" else "OFF", TextColor3 = C.cream, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24, Parent = track })
	make("Frame", { Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(if on then 1 else 0, if on then -18 else 18, 0.5, 0),
		Size = UDim2.fromOffset(28, 28), BackgroundColor3 = C.cream, ZIndex = 24, Parent = track }, { UI.corner(14), UI.stroke(UI.SEAM, 1.5) })
	track.Activated:Connect(function()
		set(key, not on)
	end)
end

-- − 75% +
local function steps(box: Frame, key: string)
	local current = value(key)
	local setting = SettingsRules.BY_KEY[key]
	local holder = make("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 40),
		BackgroundTransparency = 1, ZIndex = 23, Parent = box })
	local low, high = current == setting.steps[1], current == setting.steps[#setting.steps]
	local _, minus = UI.button({ text = "−", kind = if low then "cream" else "wood", size = UDim2.fromOffset(42, 40), textSize = 24, zIndex = 23, parent = holder })
	local _, plus = UI.button({ text = "+", kind = if high then "cream" else "wood", size = UDim2.fromOffset(42, 40), anchor = Vector2.new(1, 0),
		position = UDim2.fromScale(1, 0), textSize = 24, zIndex = 23, parent = holder })
	UI.label({ Size = UDim2.new(1, -88, 1, -4), Position = UDim2.fromOffset(44, 0), Font = UI.HEAD, TextSize = 20,
		Text = `{math.round(current * 100)}%`, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 23, Parent = holder })
	minus.Activated:Connect(function()
		if not low then
			set(key, SettingsRules.step(key, current, -1))
		end
	end)
	plus.Activated:Connect(function()
		if not high then
			set(key, SettingsRules.step(key, current, 1))
		end
	end)
end

local function shieldRow(order: number)
	local t = now()
	local shield = (player:GetAttribute("ShieldUntil") or 0) - t
	local grace = (player:GetAttribute("GraceUntil") or 0) - t
	local left = math.max(shield, grace)
	if left <= 0 then
		return
	end
	local box = card(order, 64)
	words(box, { icon = "🌱", title = if shield > 0 then `Sprout Shield: {UI.formatTime(left)} left` else `Just arrived: safe for {UI.formatTime(left)}`,
		detail = "Nobody can steal from you, and you can't steal. Drop it to start raiding (your farm can be raided then too)" }, 146)
	local _, drop = UI.button({ text = if confirmDrop then "Tap to confirm" else "Drop it now", kind = if confirmDrop then "red" else "cream",
		size = UDim2.fromOffset(132, 40), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -10, 0.5, 0), textSize = 15, zIndex = 23, parent = box })
	drop.Activated:Connect(function()
		if confirmDrop then
			confirmDrop = false
			task.spawn(function()
				local ok, result = pcall(DefenceAction.InvokeServer, DefenceAction, "DropShield")
				if not (ok and result and result.ok) then
					UI.toast(Reasons(result and result.reason) or "Couldn't drop the shield right now.", "Error", 2.5)
				end
				render()
			end)
		else
			confirmDrop = true
			render()
			task.delay(4, function()
				confirmDrop = false
				render()
			end)
		end
	end)
end

local function guideRow(order: number)
	local state = PlayerState.current
	local guide = state and state.guide
	if not guide then
		return
	end
	local showing = GuideRules.visible(guide)
	local box = card(order, 64)
	words(box, { icon = "📋", title = "Farm Guide",
		detail = if guide.finished then "Done! Read the steps again any time" else "The getting-started card: planting, selling, your store and workers" }, 146)
	local _, button = UI.button({ text = if showing then "Hide it" elseif guide.finished then "Read again" else "Show it",
		kind = if showing then "cream" else "blue", size = UDim2.fromOffset(132, 40), anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -10, 0.5, 0), textSize = 15, zIndex = 23, parent = box })
	button.Activated:Connect(function()
		task.spawn(function()
			local ok, result = pcall(GuideAction.InvokeServer, GuideAction, if showing then "Hide" else "Show")
			if not (ok and result and result.ok) and not (result and result.reason == "Cooldown") then
				UI.toast(Reasons(result and result.reason) or "Couldn't change that right now.", "Error", 2.5)
			end
		end)
	end)
end

function render()
	if not UI.isOpen(panel) then
		return
	end
	local scroll = panel.list.CanvasPosition
	UI.clear(panel.list)
	for order, row in ROWS do
		if row.section then
			UI.label({ Size = UDim2.new(1, 0, 0, 26), Font = UI.HAND, TextSize = 22, Text = row.section, LayoutOrder = order, ZIndex = 22, Parent = panel.list })
		elseif row.special == "shield" then
			shieldRow(order)
		elseif row.special == "guide" then
			guideRow(order)
		else
			local box = card(order, 58)
			local kind = SettingsRules.BY_KEY[row.key].kind
			words(box, row, if kind == "switch" then 96 else 158)
			if kind == "switch" then
				switch(box, row.key)
			else
				steps(box, row.key)
			end
		end
	end
	panel.list.CanvasPosition = scroll
end

function SettingsController.Start()
	panel.onOpen = render
	PlayerState.observe(function(state)
		for key, tapped in pending do
			if SettingsRules.get(state.settings, key) == tapped then
				pending[key] = nil -- (the server's copy has caught up)
			end
		end
		apply()
		render()
	end)
	local button = HudController.topButton("⚙️", "Settings", 2)
	button.Activated:Connect(panel.toggle)
	-- the shield's countdown ticks while the window is open
	task.spawn(function()
		while true do
			task.wait(1)
			if UI.isOpen(panel) and ((player:GetAttribute("ShieldUntil") or 0) > now() or (player:GetAttribute("GraceUntil") or 0) > now()) then
				render()
			end
		end
	end)
end

return SettingsController
