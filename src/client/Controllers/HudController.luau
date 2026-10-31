-- The always-on HUD (docs/GameDesign.md §5.2), in Kraft & Crate:
--   top:      a wooden sign hung on two ropes from the top of the screen
--             with your coins, a prize rosette with your Farm Level, the XP
--             rail, and the location chip under it (a price tag: green Your
--             Farm, gold Visiting, cream Town). (Top centre, not top left:
--             Roblox's chat window lives there.)
--   left:     the side bar, a stack of crates (Barn, ...)
--   bottom:   Home and Town signposts above the hotbar, with the 3 s
--             travel bar and their cooldowns
--   and the server's notes (UI.toast), the level-up rosette and the truck
--   receipt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlotLayout = require(Shared.PlotLayout)
local ProgressionRules = require(Shared.ProgressionRules)
local Remotes = require(Shared.Remotes)
local TravelRules = require(Shared.TravelRules)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer

local HudController = {}

HudController.HOTBAR_HEIGHT = 72 -- (HotbarController's packets; the signposts sit above them)

------------------------------------------------------------------------
-- Top: the coin sign, the level rosette, the XP rail, the location tag

local topLeft = make("Frame", {
	Name = "Purse",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, -16, 0, 10),
	Size = UDim2.fromOffset(224, 110),
	BackgroundTransparency = 1,
	Parent = UI.screen,
})
local coinSign = make("Frame", {
	Name = "Coins",
	Size = UDim2.fromOffset(190, 46),
	Parent = topLeft,
}, { UI.corner(6), UI.stroke(UI.SEAM, 3) })
UI.wood(coinSign, 2, false)
for _, x in { 26, 164 } do
	make("Frame", { -- the ropes it hangs from, up off the top of the screen
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, x, 0, 6), Size = UDim2.fromOffset(3, 60),
		BackgroundColor3 = Color3.fromRGB(206, 170, 112), BorderSizePixel = 0, ZIndex = 0, Parent = coinSign,
	})
end
UI.coin({ diameter = 24, anchor = Vector2.new(0, 0.5), position = UDim2.new(0, 18, 0.5, 0), zIndex = 2, parent = coinSign })
for _, x in { 10, 180 } do
	make("Frame", { -- nails
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, x, 0.5, 0), Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = Color3.fromRGB(200, 200, 190), Parent = coinSign,
	}, { UI.corner(3) })
end
local coinsLabel = UI.label({
	Position = UDim2.fromOffset(48, 0),
	Size = UDim2.new(1, -86, 1, 0),
	Font = UI.HEAD,
	TextSize = 24,
	TextColor3 = C.cream,
	TextStrokeColor3 = UI.SEAM,
	TextStrokeTransparency = 0,
	Text = "0",
	Parent = coinSign,
})
UI.fit(coinsLabel, 12)

local rosette, levelLabel = UI.rosette({ diameter = 62, color = C.red, text = "1", textSize = 20, position = UDim2.fromOffset(162, -8), zIndex = 2, parent = topLeft })
rosette.Name = "Level"
local lvTag = UI.label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 1), Size = UDim2.fromOffset(30, 12), Font = UI.HEAD,
	TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center, Text = "LV", ZIndex = 6, Parent = levelLabel,
})
lvTag.TextColor3 = C.red

local rail = make("Frame", {
	Name = "XP",
	Position = UDim2.fromOffset(20, 52),
	Size = UDim2.fromOffset(150, 10),
	BackgroundColor3 = C.cream,
	Parent = topLeft,
}, { UI.corner(5), UI.stroke(UI.SEAM, 2) })
local railFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.green, Parent = rail }, { UI.corner(5) })

local chip, chipLabel = UI.tag({ name = "Location", text = "Cloverdale", autoWidth = true, size = UDim2.fromOffset(0, 30),
	anchor = Vector2.new(0.5, 0), position = UDim2.new(0, 95, 0, 70), parent = topLeft })

local function updateState(state)
	coinsLabel.Text = UI.formatNumber(state.coins)
	local level, into, span = ProgressionRules.progress(state.xp)
	levelLabel.Text = tostring(level)
	railFill.Size = UDim2.fromScale(if span then math.clamp(into / span, 0, 1) else 1, 1)
end

local function updateChip()
	local inFarm = player:GetAttribute("InFarm") or 0
	local inStore = player:GetAttribute("InStore") or 0
	local mine = player:GetAttribute("Plot")
	local text, color, textColor = "Cloverdale", C.cream, C.ink
	if inStore > 0 then
		-- a store is a public place on the road (§4.8): its own name
		local name = workspace.World[`Plot{inStore}`]:GetAttribute("StoreName") or "Store"
		text = if name == "FOR RENT" then `Farm {inStore}'s store: for rent` else `🏪 {name}`
		color, textColor = if inStore == mine then C.green else C.gold, if inStore == mine then C.cream else C.ink
	elseif inFarm > 0 and inFarm == mine then
		text, color, textColor = "Your Farm", C.green, C.cream
	elseif inFarm > 0 then
		local owner = workspace.World[`Plot{inFarm}`]:GetAttribute("OwnerName")
		text, color = if owner then `Visiting {owner}'s farm` else `Farm {inFarm}: for rent`, C.gold
	else
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and Vector2.new(root.Position.X, root.Position.Z).Magnitude < PlotLayout.RING_ROAD.radius then
			text = "Town"
		end
	end
	chipLabel.Text = text
	UI.setTagColor(chip, color, textColor)
end

------------------------------------------------------------------------
-- The side bar: a stack of crates

local sideBar = make("Frame", {
	Name = "SideBar",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.5, 0),
	Size = UDim2.fromOffset(72, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Parent = UI.screen,
})
-- One column on a computer; on phones two columns of smaller crates, so six
-- of them stay above the thumbstick (§5.2, play-test 2026-10-31).
local column = make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
local grid = make("UIGridLayout", { CellSize = UDim2.fromOffset(58, 52), CellPadding = UDim2.fromOffset(6, 6), FillDirection = Enum.FillDirection.Horizontal,
	FillDirectionMaxCells = 2, SortOrder = Enum.SortOrder.LayoutOrder })

local crates = {}

-- Phones get smaller crates, so the column stays above the thumbstick.
local function sizeCrate(crate: Frame)
	crate.Size = if UI.compact then UDim2.fromOffset(58, 52) else UDim2.fromOffset(72, 68)
	crate.Icon.TextSize = if UI.compact then 20 else 26
	crate.Icon.Size = UDim2.new(1, 0, 0, if UI.compact then 22 else 30)
	crate.Icon.Position = UDim2.fromOffset(0, if UI.compact then 5 else 7)
	crate.Label.Size = UDim2.new(1, -8, 0, if UI.compact then 15 else 18)
	local text = crate.Label:FindFirstChildOfClass("TextLabel")
	text.TextSize = if UI.compact then 11 else 13
	local fit = text:FindFirstChildOfClass("UITextSizeConstraint")
	if fit then
		fit.MaxTextSize = text.TextSize
	end
end

-- A crate in the side bar. Returns its button.
function HudController.sideButton(icon: string, name: string, order: number)
	local crate, button = UI.crate({ name = name, icon = icon, text = name, size = UDim2.fromOffset(72, 68), order = order, parent = sideBar })
	table.insert(crates, crate)
	sizeCrate(crate)
	return button
end

UI.onLayout(function()
	-- (phones: higher up and smaller, out of the thumbstick's way)
	sideBar.AnchorPoint = if UI.compact then Vector2.zero else Vector2.new(0, 0.5)
	sideBar.Position = if UI.compact then UDim2.fromOffset(14, 64) else UDim2.new(0, 14, 0.55, 0)
	sideBar.Size = UDim2.fromOffset(if UI.compact then 58 * 2 + 6 else 72, 0)
	column.Parent = if UI.compact then nil else sideBar
	grid.Parent = if UI.compact then sideBar else nil
	for _, crate in crates do
		sizeCrate(crate)
	end
end)

------------------------------------------------------------------------
-- Travel: Home and Town signposts

local travelRow = make("Frame", {
	Name = "Travel",
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(250, 38),
	BackgroundTransparency = 1,
	Parent = UI.screen,
})
UI.onLayout(function()
	travelRow.Position = UDim2.new(0.5, 0, 1, -(HudController.HOTBAR_HEIGHT + 22))
end)

-- A wooden signpost board with an arrow end, pointing left or right.
local function signpost(text: string, left: boolean)
	local holder = make("Frame", {
		Size = UDim2.fromOffset(112, 36),
		Position = if left then UDim2.fromOffset(6, 0) else UDim2.new(1, -118, 0, 0),
		BackgroundTransparency = 1,
		Parent = travelRow,
	})
	make("Frame", { -- the arrow's tip
		Name = "Tip", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(if left then 0 else 1, 0, 0.5, 0),
		Size = UDim2.fromOffset(25, 25), Rotation = 45, BackgroundColor3 = Color3.fromRGB(128, 88, 55), ZIndex = 1, Parent = holder,
	}, { UI.stroke(UI.SEAM, 3) })
	local board = make("TextButton", {
		Name = "Board", Size = UDim2.fromScale(1, 1), Text = "", AutoButtonColor = false, ZIndex = 2, Parent = holder,
	}, { UI.corner(4), UI.stroke(UI.SEAM, 3) })
	UI.wood(board, 2, false)
	local label = UI.label({
		Size = UDim2.fromScale(1, 1), Font = UI.HEAD, TextSize = 18, TextColor3 = C.cream, TextStrokeColor3 = UI.SEAM,
		TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center, Text = text, ZIndex = 3, Parent = board,
	})
	board.MouseButton1Down:Connect(function()
		holder.Rotation = if left then -3 else 3
	end)
	local function release()
		holder.Rotation = 0
	end
	board.MouseButton1Up:Connect(release)
	board.MouseLeave:Connect(release)
	return holder, board, label
end

local channelBar = make("Frame", {
	Name = "Channel",
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(250, 30),
	BackgroundColor3 = C.cream,
	Visible = false,
	Parent = UI.screen,
}, { UI.corner(4), UI.stroke(UI.SEAM, 2) })
local channelFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.sky, Parent = channelBar }, { UI.corner(4) })
local channelLabel = UI.label({
	Size = UDim2.fromScale(1, 1), Font = UI.HAND, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Center,
	Text = "", ZIndex = 2, Parent = channelBar,
})
UI.onLayout(function()
	channelBar.Position = UDim2.new(0.5, 0, 1, -(HudController.HOTBAR_HEIGHT + 68))
end)

local TravelAction = Remotes.func("TravelAction")
local signs = {}
local channelToken = 0

local function travel(kind: string, label: string)
	local result = TravelAction:InvokeServer(kind)
	if not result.ok then
		local text = Reasons(result.reason)
		if text then
			UI.toast(text, "Error")
		end
		return
	end
	channelToken += 1
	local token = channelToken
	channelBar.Visible = true
	channelLabel.Text = label
	channelFill.Size = UDim2.fromScale(0, 1)
	TweenService:Create(channelFill, TweenInfo.new(TravelRules.CHANNEL, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
	task.delay(TravelRules.CHANNEL + 0.3, function()
		if channelToken == token then
			channelBar.Visible = false
		end
	end)
end

for _, entry in { { "Home", "🏠 HOME", "Heading home... (stand still)", true }, { "Town", "TOWN 🏘️", "Heading to town... (stand still)", false } } do
	local kind = entry[1]
	local holder, board, label = signpost(entry[2], entry[4])
	holder.Name = kind
	signs[kind] = { label = label, text = entry[2] }
	board.Activated:Connect(function()
		travel(kind, entry[3])
	end)
end

-- A countdown on the sign while it's on cooldown.
local function updateCooldowns()
	local now = workspace:GetServerTimeNow()
	for kind, sign in signs do
		local left = (player:GetAttribute(`{kind}ReadyAt`) or 0) - now
		sign.label.Text = if left > 0 then `⏳ {UI.formatTime(left)}` else sign.text
		sign.label.TextTransparency = if left > 0 then 0.35 else 0
	end
end

------------------------------------------------------------------------
-- The level-up rosette

local card = make("Frame", {
	Name = "LevelUp",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 40),
	Size = UDim2.fromOffset(330, 260),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 30,
	Parent = UI.screen,
})
local bigRosette, bigLabel = UI.rosette({ diameter = 120, color = C.red, text = "", textSize = 30, anchor = Vector2.new(0.5, 0),
	position = UDim2.new(0.5, 0, 0, 0), zIndex = 31, parent = card })
bigRosette.Name = "Rosette"
local note = make("Frame", { -- (below the rosette's tails)
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 158), Size = UDim2.fromOffset(330, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.cream, Rotation = -1.5, ZIndex = 30, Parent = card,
}, { UI.corner(3), UI.stroke(C.stitch, 1.5), make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }) })
local noteLabel = UI.label({
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Font = UI.HAND, TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Center, Text = "", ZIndex = 31, Parent = note,
})
local cardToken = 0

local function showLevelUp(notice)
	cardToken += 1
	local token = cardToken
	bigLabel.Text = `Lv {notice.level}`
	local lines = { `Farm Level {notice.level}!` }
	if (notice.permits or 0) > 0 then
		table.insert(lines, "📜 Land Permit! Find the yellow \"Clear here\" signs on your field.")
	end
	noteLabel.Text = table.concat(lines, "\n")
	card.Visible = true
	bigRosette.Rotation = -20
	TweenService:Create(bigRosette, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Rotation = 0 }):Play()
	task.delay(5, function()
		if cardToken == token then
			card.Visible = false
		end
	end)
end

------------------------------------------------------------------------
-- The truck receipt: a paper slip with a torn bottom edge, listing each
-- crate and the price it locked, slid in from the right.

local receipt = make("Frame", {
	Name = "Receipt",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(1, 20, 0.5, 0),
	Size = UDim2.fromOffset(270, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = C.white,
	Rotation = 1.5,
	Visible = false,
	ZIndex = 32,
	Parent = UI.screen,
}, { UI.stroke(C.stitch, 1.5), make("UIPadding", { PaddingTop = UDim.new(0, 12) }),
	make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
local tear = make("Frame", { -- the torn edge: the last line, with teeth hanging off the paper's bottom
	Name = "Tear", Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
	LayoutOrder = 1000, ZIndex = 32, Parent = receipt,
})
for i = 1, 18 do
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new((i - 0.5) / 18, 0, 1, 0), Size = UDim2.fromOffset(11, 11),
		Rotation = 45, BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 32, Parent = tear,
	})
end
local receiptToken = 0

local function receiptLine(order: number, left: string, right: string?, props)
	local holder = make("Frame", { Size = UDim2.new(1, -28, 0, props.height or 22), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 33, Parent = receipt })
	UI.fit(UI.label({ Size = UDim2.new(1, if right then -64 else 0, 1, 0), Font = props.font or UI.HAND, TextSize = props.size or 19,
		TextXAlignment = props.align or Enum.TextXAlignment.Left, TextWrapped = props.wrap, Text = left, ZIndex = 33, Parent = holder }), 10)
	if right then
		UI.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 64, 1, 0), Font = props.font or UI.HEAD,
			TextSize = props.size or 17, TextXAlignment = Enum.TextXAlignment.Right, Text = right, ZIndex = 33, Parent = holder })
	end
end

local function rule(order: number)
	UI.label({ Size = UDim2.new(1, -28, 0, 10), Font = UI.BODY, TextSize = 12, TextColor3 = C.stitch, TextXAlignment = Enum.TextXAlignment.Center,
		Text = string.rep("- ", 30), LayoutOrder = order, ZIndex = 33, Parent = receipt })
end

local function showReceipt(notice)
	receiptToken += 1
	local token = receiptToken
	for _, child in receipt:GetChildren() do
		if child:IsA("Frame") and child ~= tear or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	receiptLine(1, "CLOVERDALE EXCHANGE", nil, { font = UI.HEAD, size = 18, align = Enum.TextXAlignment.Center })
	receiptLine(2, notice.text, nil, { size = 18, align = Enum.TextXAlignment.Center })
	rule(3)
	for i, line in notice.lines or {} do
		receiptLine(3 + i, line.text, UI.formatNumber(line.coins), {})
	end
	rule(50)
	receiptLine(51, "TOTAL", UI.formatNumber(notice.total or 0), { font = UI.HEAD, size = 20, height = 26 })
	receiptLine(52, notice.footer or "", nil, { size = 16, height = 38, wrap = true })
	receipt.Visible = true
	receipt.Position = UDim2.new(1, 20, 0.5, 0)
	TweenService:Create(receipt, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(1, -290, 0.5, 0) }):Play()
	task.delay(6.5, function()
		if receiptToken == token then
			TweenService:Create(receipt, TweenInfo.new(0.3), { Position = UDim2.new(1, 20, 0.5, 0) }):Play()
			task.wait(0.3)
			if receiptToken == token then
				receipt.Visible = false
			end
		end
	end)
end

------------------------------------------------------------------------

function HudController.Start()
	PlayerState.observe(updateState)
	player:GetAttributeChangedSignal("InFarm"):Connect(updateChip)
	player:GetAttributeChangedSignal("InStore"):Connect(updateChip)
	player:GetAttributeChangedSignal("Plot"):Connect(updateChip)
	task.spawn(function()
		while true do
			updateChip()
			updateCooldowns()
			task.wait(0.5)
		end
	end)
	Remotes.event("Notify").OnClientEvent:Connect(function(notice)
		if notice.kind == "LevelUp" then
			showLevelUp(notice)
		elseif notice.kind == "Receipt" then
			showReceipt(notice)
		elseif notice.kind == "Welcome" then
			return -- (WorkersController's Welcome back card)
		else
			UI.toast(notice.text, notice.kind)
		end
	end)
	-- Walking off cancels the travel channel (the server would anyway).
	RunService.Heartbeat:Connect(function()
		if channelBar.Visible then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
				channelToken += 1
				channelBar.Visible = false
				task.spawn(TravelAction.InvokeServer, TravelAction, "Cancel")
				UI.toast("Travel cancelled: you moved.")
			end
		end
	end)
end

return HudController
