-- Trading (docs/GameDesign.md §4.13, §5.3; shared/TradeRules, server
-- TradeService): the Trade window is two crates side by side.
--   * the 🤝 Trade crate on the side bar lists the players near you to ask
--     (or press [T] standing by someone); a request comes in as a note with
--     Accept, for 30 s;
--   * in a trade: YOU GIVE on the left (up to 8 stacks from your barn and
--     seed bag, each with - + and X, "+ Add" to pick more, and coins), what
--     they give on the right, each side's value at today's prices under it,
--     a red bar when you'd give 3× or more what you get, then Ready → a 5 s
--     countdown → Confirm. Closing the window cancels the trade.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BarnRules = require(Shared.BarnRules)
local Crops = require(Shared.Config.Crops)
local Remotes = require(Shared.Remotes)
local TradeRules = require(Shared.TradeRules)

local CropNames = require(script.Parent.Parent.CropNames)
local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)
local HudController = require(script.Parent.HudController)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer
local TradeAction = Remotes.func("TradeAction")

local TradeController = {}

-- What the server's reasons mean here (Reasons covers the rest).
local MESSAGES = {
	TradeLocked = `Trading opens after an hour of play.`,
	TheyLocked = "They can't trade yet: trading opens after an hour of play.",
	Busy = "You're already in a trade.",
	TheyBusy = "They're trading with someone else right now.",
	TheyDisabled = "They've turned trade requests off.",
	TooFar = "Stand next to them to trade (trades are in person).",
	Cooldown = "You asked them a moment ago: give them a chance to answer.",
	Expired = "That request has run out: ask them again.",
	NotFound = "That's not in your barn any more.",
	NotEnough = "You don't have that many.",
	TooMany = "A trade holds 8 stacks a side.",
	InDebt = "You can't trade coins while you owe a debt (pay it at the Police Station).",
	NotEnoughCoins = "You don't have that many coins.",
	Gone = "Something in your offer isn't in your barn any more.",
	BarnFull = "Your barn hasn't room for what's coming: make room first.",
	Empty = "Put something in the trade first.",
	NotYet = nil,
	NoTrade = nil,
}

local current = nil -- the open trade, as the server sees it for us

local function send(action: string, arg: string?)
	task.spawn(function()
		local result = TradeAction:InvokeServer(action, arg)
		if not result.ok then
			local reason = result.reason
			local text = if MESSAGES[reason] ~= nil or reason == "NotYet" or reason == "NoTrade" then MESSAGES[reason] else Reasons(reason)
			if text then
				UI.toast(text, "Error", 3)
			end
		end
	end)
end

-- "🥕 Carrot", "💧 Wet Pumpkin", "🌱 Corn seeds"
local function lineName(kind: string, key: string): string
	if kind == "seed" then
		local crop = Crops.ById[key]
		return `🌱 {crop.name} seeds`
	end
	local cropId, mutation = BarnRules.parse(key)
	local crop = Crops.ById[cropId]
	return `{crop.icon or ""} {if mutation then mutation .. " " else ""}{crop.name}`
end

-- Its colour: a mutated crop's stands out.
local function lineColor(kind: string, key: string): Color3
	return if kind == "seed" then C.ink else CropNames.color(key) or C.ink
end

------------------------------------------------------------------------
-- The window

local panel = UI.panel("Trade", { accent = C.gold, width = 760, height = 480 })
panel.list.Visible = false
local body = make("Frame", {
	Name = "Body", Position = UDim2.fromOffset(16, panel.top + 4), Size = UDim2.new(1, -32, 1, -(panel.top + 16)),
	BackgroundTransparency = 1, ZIndex = 22, Parent = panel.frame,
})

-- Who's near: before a trade.
local nearView = make("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = C.soil,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22, Parent = body,
}, { make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }), make("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4) }) })

-- A trade: two crates, the values, the buttons.
local tradeView = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 22, Parent = body })

local function crate(x: number, titleText: string)
	local frame = make("Frame", {
		Position = UDim2.new(x, if x > 0 then 6 else 0, 0, 0), Size = UDim2.new(0.5, -6, 1, -96), ZIndex = 22, Parent = tradeView,
	}, { UI.corner(6), UI.stroke(UI.SEAM, 3) })
	UI.wood(frame, 5, true)
	local title = UI.label({
		Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 26), Font = UI.HEAD, TextSize = 18, TextColor3 = C.cream,
		TextStrokeColor3 = UI.SEAM, TextStrokeTransparency = 0, Text = titleText, ZIndex = 24, Parent = frame,
	})
	local list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 32), Size = UDim2.new(1, -16, 1, -78), BackgroundColor3 = C.cream, BorderSizePixel = 0,
		ScrollBarThickness = 5, ScrollBarImageColor3 = C.soil, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 23, Parent = frame,
	}, {
		UI.corner(4),
		make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }),
	})
	local coins = make("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -8), Size = UDim2.new(1, -16, 0, 34), BackgroundColor3 = C.cream, ZIndex = 23, Parent = frame,
	}, { UI.corner(4), UI.stroke(C.soil, 1.5) })
	UI.coin({ diameter = 22, position = UDim2.fromOffset(8, 6), zIndex = 24, parent = coins })
	local status = make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0, 17), Size = UDim2.fromOffset(110, 26), BackgroundTransparency = 1,
		Font = UI.HEAD, TextSize = 16, TextColor3 = C.green, TextXAlignment = Enum.TextXAlignment.Right, Text = "", ZIndex = 26, Parent = frame,
	})
	return { frame = frame, title = title, list = list, coins = coins, status = status }
end

local mine = crate(0, "YOU GIVE")
local theirs = crate(0.5, "THEY GIVE")
mine.status.Parent, theirs.status.Parent = mine.title, theirs.title
mine.status.Position, theirs.status.Position = UDim2.new(1, 0, 0.5, 0), UDim2.new(1, 0, 0.5, 0)

local coinBox = make("TextBox", {
	Position = UDim2.fromOffset(36, 4), Size = UDim2.new(1, -44, 0, 26), BackgroundTransparency = 1, Font = UI.HEAD, TextSize = 18,
	TextColor3 = C.ink, PlaceholderText = "coins to give (tap to type)", PlaceholderColor3 = C.stitch, Text = "", ClearTextOnFocus = false,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24, Parent = mine.coins,
})
local theirCoins = UI.label({
	Position = UDim2.fromOffset(36, 4), Size = UDim2.new(1, -44, 0, 26), Font = UI.HEAD, TextSize = 18, TextColor3 = C.ink, Text = "0", ZIndex = 24, Parent = theirs.coins,
})

local values = UI.label({
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -58), Size = UDim2.new(1, 0, 0, 30), Font = UI.HAND, TextSize = 22, TextColor3 = C.ink,
	TextXAlignment = Enum.TextXAlignment.Center, Text = "", ZIndex = 23, Parent = tradeView,
})
local warning = make("TextLabel", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -58), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.alarm, Font = UI.HEAD,
	TextSize = 16, TextColor3 = C.cream, Text = "", Visible = false, ZIndex = 24, Parent = tradeView,
}, { UI.corner(4) })
local _, cancelButton = UI.button({ text = "Cancel", kind = "red", size = UDim2.fromOffset(130, 48), anchor = Vector2.new(0, 1),
	position = UDim2.new(0, 0, 1, 0), zIndex = 23, parent = tradeView })
local readyHolder, readyButton = UI.button({ text = "Ready", kind = "green", size = UDim2.fromOffset(200, 48), anchor = Vector2.new(1, 1),
	position = UDim2.new(1, 0, 1, 0), zIndex = 23, parent = tradeView })
local hint = UI.label({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -360, 0, 34), Font = UI.HAND, TextSize = 19,
	TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Text = "", ZIndex = 23, Parent = tradeView,
})

-- The picker: your barn and seed bag, to add from.
local picker = make("Frame", {
	Position = UDim2.fromScale(0, 0), Size = UDim2.new(0.5, -6, 1, -96), BackgroundColor3 = C.kraft, Visible = false, ZIndex = 30, Parent = tradeView,
}, { UI.corner(6), UI.stroke(UI.SEAM, 3) })
UI.label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -60, 0, 26), Font = UI.HEAD, TextSize = 17, TextColor3 = C.ink,
	Text = "Add from your barn", ZIndex = 31, Parent = picker })
local pickerClose = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 5), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = C.red, Font = UI.HEAD,
	Text = "X", TextSize = 14, TextColor3 = C.cream, AutoButtonColor = false, ZIndex = 32, Parent = picker,
}, { UI.corner(12) })
local pickerList = make("ScrollingFrame", {
	Position = UDim2.fromOffset(8, 34), Size = UDim2.new(1, -16, 1, -42), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
	ScrollBarImageColor3 = C.soil, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 31, Parent = picker,
}, { make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }), make("UIPadding", { PaddingRight = UDim.new(0, 8) }) })

local function smallButton(text: string, color: Color3, parent: Instance, x: UDim, width: number): TextButton
	return make("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(x, UDim.new(0.5, 0)), Size = UDim2.fromOffset(width, 26), BackgroundColor3 = color,
		Font = UI.HEAD, Text = text, TextSize = 14, TextColor3 = C.ink, AutoButtonColor = true, ZIndex = 34, Parent = parent,
	}, { UI.corner(5), UI.stroke(UI.SEAM, 1.2) })
end

local function lineCount(kind: string, key: string): number
	local line = current and TradeRules.findLine({ lines = current.you.lines }, kind, key)
	return if line then line.count else 0
end

local function setLine(kind: string, key: string, count: number)
	send("Set", `{kind}|{key}|{math.max(0, math.floor(count))}`)
end

local function drawPicker()
	UI.clear(pickerList)
	local state = PlayerState.current
	if not state then
		return
	end
	local entries = {}
	for key, count in state.inventory.crops do
		if count > 0 then
			table.insert(entries, { kind = "crop", key = key, count = count })
		end
	end
	for key, count in state.inventory.seeds do
		if count > 0 then
			table.insert(entries, { kind = "seed", key = key, count = count })
		end
	end
	table.sort(entries, function(a, b)
		if a.kind ~= b.kind then
			return a.kind == "crop"
		end
		return a.key < b.key
	end)
	if #entries == 0 then
		UI.label({ Size = UDim2.new(1, 0, 0, 50), Font = UI.HAND, TextSize = 20, TextColor3 = C.ink, TextWrapped = true,
			Text = "Your barn and seed bag are empty.", ZIndex = 32, Parent = pickerList })
	end
	for order, entry in entries do
		local left = entry.count - lineCount(entry.kind, entry.key)
		local row = make("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.cream, LayoutOrder = order, ZIndex = 32, Parent = pickerList },
			{ UI.corner(4), UI.stroke(C.stitch, 1) })
		UI.fit(UI.label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -170, 1, 0), Font = UI.BODY_BOLD, TextSize = 15, TextColor3 = lineColor(entry.kind, entry.key),
			Text = `{lineName(entry.kind, entry.key)} ×{UI.formatNumber(left)}`, ZIndex = 33, Parent = row }), 10)
		for i, step in { 1, 10, "All" } do
			local amount = if step == "All" then left else math.min(step :: number, left)
			local button = smallButton(if step == "All" then "All" else `+{step}`, if left > 0 then C.gold else C.kraft, row, UDim.new(1, -160 + (i - 1) * 52), 48)
			button.Activated:Connect(function()
				if amount > 0 then
					setLine(entry.kind, entry.key, lineCount(entry.kind, entry.key) + amount)
					picker.Visible = false -- (back to your crate, to see it there: - + to change it)
				end
			end)
		end
	end
end

local function lineRow(list: Instance, line, order: number, editable: boolean)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(255, 250, 238), LayoutOrder = order, ZIndex = 24, Parent = list },
		{ UI.corner(4), UI.stroke(C.stitch, 1) })
	UI.fit(UI.label({ Position = UDim2.fromOffset(8, 1), Size = UDim2.new(1, if editable then -140 else -16, 0, 19), Font = UI.BODY_BOLD, TextSize = 15,
		TextColor3 = lineColor(line.kind, line.key), Text = `{lineName(line.kind, line.key)} ×{UI.formatNumber(line.count)}`, ZIndex = 25, Parent = row }), 10)
	UI.label({ Position = UDim2.fromOffset(8, 18), Size = UDim2.new(1, -150, 0, 16), Font = UI.BODY, TextSize = 13, TextColor3 = C.soil,
		Text = `worth {UI.formatNumber(line.value)} coins`, ZIndex = 25, Parent = row })
	if editable then
		local minus = smallButton("-", C.cream, row, UDim.new(1, -132), 34)
		local plus = smallButton("+", C.cream, row, UDim.new(1, -94), 34)
		local remove = smallButton("X", C.red, row, UDim.new(1, -56), 34)
		remove.TextColor3 = C.cream
		minus.Activated:Connect(function()
			setLine(line.kind, line.key, line.count - 1)
		end)
		plus.Activated:Connect(function()
			setLine(line.kind, line.key, line.count + 1)
		end)
		remove.Activated:Connect(function()
			setLine(line.kind, line.key, 0)
		end)
	end
end

local function drawTrade()
	local trade = current
	if not trade then
		return
	end
	theirs.title.Text = `{string.upper(trade.them.name)} GIVES`
	for _, pair in { { mine, trade.you, true }, { theirs, trade.them, false } } do
		local crateView, half, editable = pair[1], pair[2], pair[3]
		UI.clear(crateView.list)
		for order, line in half.lines do
			lineRow(crateView.list, line, order, editable and trade.phase == "editing")
		end
		if editable and trade.phase == "editing" and #half.lines < TradeRules.MAX_LINES then
			local _, add = UI.button({ text = "+ Add from your barn", kind = "cream", size = UDim2.new(1, 0, 0, 34), order = 99, textSize = 15, zIndex = 24, parent = crateView.list })
			add.Activated:Connect(function()
				picker.Visible = true
				drawPicker()
			end)
		elseif not editable and #half.lines == 0 then
			UI.label({ Size = UDim2.new(1, 0, 0, 40), Font = UI.HAND, TextSize = 19, TextColor3 = C.soil, TextWrapped = true,
				Text = "Nothing yet...", ZIndex = 24, Parent = crateView.list })
		end
		crateView.status.Text = if half.confirmed then "✓ CONFIRMED" elseif half.ready then "✓ READY" else ""
	end
	if not coinBox:IsFocused() then
		coinBox.Text = if trade.you.coins > 0 then UI.formatNumber(trade.you.coins) else ""
	end
	coinBox.TextEditable = trade.phase == "editing"
	theirCoins.Text = UI.formatNumber(trade.them.coins)
	values.Text = `You give {UI.formatNumber(trade.you.value)} · You get {UI.formatNumber(trade.them.value)} (at today's prices)`
	local lopsided = TradeRules.lopsided(trade.you.value, trade.them.value)
	warning.Visible = lopsided
	warning.Text = `⚠ You're giving {math.floor(trade.you.value / math.max(trade.them.value, 1))}× what you get. Sure?`
	values.Visible = not lopsided
	if trade.phase == "editing" then
		readyButton.Text = if trade.you.ready then "Not ready" else "Ready"
		UI.setButtonKind(readyHolder, if trade.you.ready then "cream" else "green")
		hint.Text = if trade.you.ready then `Waiting for {trade.them.name} to be ready...` else "Add what you'll give, then press Ready."
	elseif trade.phase == "countdown" then
		readyButton.Text = "Not ready"
		UI.setButtonKind(readyHolder, "cream")
	else
		readyButton.Text = if trade.you.confirmed then "Waiting..." else "CONFIRM"
		UI.setButtonKind(readyHolder, if trade.you.confirmed then "cream" else "gold")
		hint.Text = if trade.you.confirmed then `Waiting for {trade.them.name} to confirm...` else "Last look: Confirm to swap."
	end
end

-- Players near you, to ask.
local function drawNear()
	UI.clear(nearView)
	local state = PlayerState.current
	local unlocked = RunService:IsStudio() or (state and TradeRules.unlocked(state.playSeconds))
	if not unlocked then
		local left = TradeRules.MIN_PLAY_SECONDS - (if state then state.playSeconds else 0)
		UI.label({ Size = UDim2.new(1, 0, 0, 60), Font = UI.HAND, TextSize = 22, TextColor3 = C.ink, TextWrapped = true, LayoutOrder = 0, ZIndex = 23,
			Text = `Trading opens after an hour of play: {UI.formatTime(math.max(0, left))} to go.`, Parent = nearView })
		return
	end
	UI.label({ Size = UDim2.new(1, 0, 0, 52), Font = UI.HAND, TextSize = 20, TextColor3 = C.ink, TextWrapped = true, LayoutOrder = 0, ZIndex = 23,
		Text = `Trades are in person: stand next to someone and ask (or {if UI.touch then "tap Trade" else "press T"} by them). Crops, seeds and coins can be traded.`, Parent = nearView })
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local order = 0
	for _, other in Players:GetPlayers() do
		local theirRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if theirRoot and root then
			local offset = theirRoot.Position - root.Position
			local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			order += 1
			local near = distance <= TradeRules.NEAR_DISTANCE
			local row = make("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.cream, LayoutOrder = if near then order else 100 + order, ZIndex = 23, Parent = nearView },
				{ UI.corner(4), UI.stroke(C.stitch, 1.5) })
			UI.label({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -200, 1, 0), Font = UI.HEAD, TextSize = 18, TextColor3 = C.ink, ZIndex = 24,
				Text = `{other.DisplayName}  ·  {math.floor(distance)} studs away`, Parent = row })
			local _, ask = UI.button({ text = if near then "Ask to trade" else "Too far", kind = if near then "blue" else "cream", size = UDim2.fromOffset(160, 40),
				anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -8, 0.5, 2), textSize = 16, zIndex = 24, parent = row })
			ask.Activated:Connect(function()
				if near then
					send("Request", tostring(other.UserId))
					UI.toast(`Asked {other.DisplayName} to trade...`, nil, 3)
				else
					UI.toast(MESSAGES.TooFar, nil, 3)
				end
			end)
		end
	end
	if order == 0 then
		UI.label({ Size = UDim2.new(1, 0, 0, 40), Font = UI.HAND, TextSize = 20, TextColor3 = C.soil, LayoutOrder = 1, ZIndex = 23,
			Text = "Nobody else is here yet.", Parent = nearView })
	end
end

local function show()
	nearView.Visible = current == nil
	tradeView.Visible = current ~= nil
	if current then
		drawTrade()
		if picker.Visible then
			drawPicker()
		end
	else
		picker.Visible = false
		drawNear()
	end
end

------------------------------------------------------------------------
-- [T] by other players

local function addPrompt(other: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or root:FindFirstChild("TradePrompt") then
		return
	end
	make("ProximityPrompt", {
		Name = "TradePrompt", ActionText = "Trade", ObjectText = other.DisplayName, KeyboardKeyCode = Enum.KeyCode.T,
		GamepadKeyCode = Enum.KeyCode.ButtonY, HoldDuration = 0, MaxActivationDistance = 12, RequiresLineOfSight = false,
		Exclusivity = Enum.ProximityPromptExclusivity.OneGlobally, Parent = root,
	}).Triggered:Connect(function()
		if not current then
			send("Request", tostring(other.UserId))
			UI.toast(`Asked {other.DisplayName} to trade...`, nil, 3)
		end
	end)
end

local function watch(other: Player)
	if other == player then
		return
	end
	other.CharacterAdded:Connect(function(character)
		addPrompt(other, character)
	end)
	if other.Character then
		task.spawn(addPrompt, other, other.Character)
	end
end

-- (no Trade prompt on a Suspect, or before you can trade, or in a trade)
local function updatePrompts()
	local state = PlayerState.current
	local unlocked = RunService:IsStudio() or (state ~= nil and TradeRules.unlocked(state.playSeconds))
	for _, other in Players:GetPlayers() do
		local root = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		local prompt = root and root:FindFirstChild("TradePrompt")
		if prompt then
			prompt.Enabled = unlocked and current == nil and other:GetAttribute("SuspectOf") == nil and player:GetAttribute("SuspectOf") == nil
		end
	end
end

------------------------------------------------------------------------

function TradeController.Start()
	local button = HudController.sideButton("🤝", "Trade", 8)
	button.Activated:Connect(function()
		if UI.isOpen(panel) and not current then
			panel.close()
		else
			panel.open()
			show()
		end
	end)
	panel.onClose = function()
		if current then
			send("Cancel")
		end
	end
	pickerClose.Activated:Connect(function()
		picker.Visible = false
	end)
	cancelButton.Activated:Connect(function()
		send("Cancel")
	end)
	readyButton.Activated:Connect(function()
		if not current then
			return
		end
		if current.phase == "confirm" then
			if not current.you.confirmed then
				send("Confirm")
			end
		else
			send("Ready", if current.you.ready then "0" else "1")
		end
	end)
	coinBox.FocusLost:Connect(function()
		if not current then
			return
		end
		local digits = string.gsub(coinBox.Text, "[^%d]", "")
		local amount = tonumber(digits) or 0
		if amount ~= current.you.coins then
			send("Coins", tostring(amount))
		end
	end)

	Remotes.event("TradeEvent").OnClientEvent:Connect(function(event)
		if event.kind == "invite" then
			UI.toast(`🤝 {event.name} wants to trade with you.`, nil, event.seconds, {
				text = "Trade",
				press = function()
					send("Accept", tostring(event.userId))
				end,
			})
		elseif event.kind == "declined" then
			UI.toast(`{event.name} said no thanks to a trade.`, nil, 3)
		elseif event.kind == "problem" then
			UI.toast(event.text, "Error", 4)
		elseif event.kind == "state" then
			local first = current == nil
			current = event.trade
			if first then
				picker.Visible = false
				panel.open()
			end
			show()
		elseif event.kind == "closed" then
			current = nil
			picker.Visible = false
			if UI.isOpen(panel) then
				panel.close()
			end
			if event.done then
				local parts = {}
				for _, line in event.lines do
					table.insert(parts, `{lineName(line.kind, line.key)} ×{UI.formatNumber(line.count)}`)
				end
				if event.coins > 0 then
					table.insert(parts, `{UI.formatNumber(event.coins)} coins`)
				end
				UI.toast(`🤝 Traded with {event.with}! You got {if #parts > 0 then table.concat(parts, ", ") else "nothing"}.`, "Good", 6)
			elseif event.reason then
				UI.toast(event.reason, nil, 4)
			end
		end
	end)

	for _, other in Players:GetPlayers() do
		watch(other)
	end
	Players.PlayerAdded:Connect(watch)
	PlayerState.observe(function()
		if UI.isOpen(panel) then
			show()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			updatePrompts()
			if UI.isOpen(panel) then
				if current and current.phase == "countdown" then
					local left = math.max(0, math.ceil((current.endsAt or 0) - workspace:GetServerTimeNow()))
					hint.Text = `Both ready! Confirm opens in {left}...`
				elseif not current then
					drawNear()
				end
			end
		end
	end)
end

return TradeController
