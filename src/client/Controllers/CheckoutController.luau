-- Serving at your till (docs/GameDesign.md §4.8): a shopper who reaches a
-- till you serve at (the Shop Counter, a Register with no Cashier) waits
-- there for you. Step in by the staff door, behind the counter, and the
-- big context stamp becomes SCAN (one press, E or a tap, for each thing in
-- their basket) and then TAKE (their coins); a paper receipt by the stamp
-- ticks each line off. The server checks it all (StoreService's Serve
-- action) and tells the owner what's waiting ("Till" on ShopperEvent).
--
-- While someone waits and you're not behind the till, a 🛎️ bobs over it on
-- your screen. Everyone near hears the bell ring and the scanner beep, and
-- sees the till's drawer pop open when someone pays at it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared.Config.Crops)
local Format = require(Shared.Format)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local StoreLayout = require(Shared.StoreLayout)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local Sfx = require(script.Parent.Parent.Sfx)
local UI = require(script.Parent.Parent.UI)
local FieldController = require(script.Parent.FieldController)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer
local StoreAction = Remotes.func("StoreAction")

local CheckoutController = {}

local REACH = 0.8 -- cells from the spot behind a till (StoreService's SERVE_REACH)
local tills = {} -- [checkoutId] = { id, lines = { { crop, units, coins } }, scanned }: my tills with a shopper waiting

------------------------------------------------------------------------
-- Where things are

local function myPlot(): number?
	return player:GetAttribute("Plot")
end

local function itemModel(plot: number, checkout: string): Model?
	local farm = workspace:FindFirstChild("World") and workspace.World:FindFirstChild(`Plot{plot}`)
	local store = farm and farm:FindFirstChild("Store")
	local items = store and store:FindFirstChild("Items")
	return items and items:FindFirstChild(checkout)
end

-- The till you're standing behind with a shopper waiting at it, if any.
local function behindWhich(): string?
	local plot, state = myPlot(), PlayerState.current
	if not plot or not state or (player:GetAttribute("InStore") or 0) ~= plot then
		return nil
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local cx, cy = PlotLayout.storeCellAt(plot, root.Position)
	for checkout in tills do
		local entry = state.store.layout[checkout]
		for _, cell in if entry then StoreLayout.behind(entry) else {} do
			if math.abs(cx - cell[1]) <= REACH and math.abs(cy - cell[2]) <= REACH then
				return checkout
			end
		end
	end
	return nil
end

local function total(till): number
	local coins = 0
	for _, line in till.lines do
		coins += line.coins
	end
	return coins
end

------------------------------------------------------------------------
-- The receipt: a strip of till roll by the stamp, a line per thing in the
-- basket, ticked as you scan, the total at the bottom.

local ROLL = Color3.fromRGB(252, 250, 242)
local receipt = make("Frame", {
	Name = "Receipt", AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(212, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, Visible = false, Parent = UI.screen,
})
local paper = make("Frame", {
	Name = "Paper", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = ROLL, Parent = receipt,
}, {
	UI.corner(3), UI.stroke(UI.SEAM, 2),
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }),
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
})
UI.crimp(receipt, ROLL, 12, 8).Position = UDim2.new(0, 0, 1, -2) -- (torn off the roll at the bottom)
UI.label({ Name = "Heading", LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 20), Font = UI.HEAD, TextSize = 16,
	TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Center, Text = "🧾 RECEIPT", Parent = paper })
local rows = make("Frame", { Name = "Rows", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, Parent = paper }, { make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) }) })
make("Frame", { Name = "Rule", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.stitch, BorderSizePixel = 0, Parent = paper })
local totalLine = UI.label({ Name = "Total", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 24), Font = UI.HEAD, TextSize = 18,
	TextColor3 = C.ink, Text = "", Parent = paper })

UI.onLayout(function()
	-- over the stamp's chalkboard; on a touch screen against the right edge,
	-- over the jump button (the stamp's column sits in from the edge there,
	-- and up here it ran into the purse and the level rosette on a phone)
	local right = if UI.touch then 12 else 18
	local d = if UI.compact then 92 else 104
	receipt.Position = UDim2.new(1, -right, 1, -(d + 80))
	receipt.Size = UDim2.fromOffset(if UI.compact then 168 else 212, 0)
end)

local drawn = ""
local function drawReceipt(till)
	local key = `{till.id}|{till.scanned}|{#till.lines}`
	if key == drawn then
		return
	end
	drawn = key
	UI.clear(rows)
	for i, line in till.lines do
		local crop = Crops.ById[line.crop]
		local done = i <= till.scanned
		local row = make("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Parent = rows })
		UI.fit(UI.label({ Size = UDim2.new(1, -62, 1, 0), Font = UI.HAND, TextSize = 19, TextColor3 = if done then C.ink else C.soil,
			Text = `{if done then "✓" else "·"} {crop and crop.icon or ""} {crop and crop.name or line.crop} ×{line.units}`, Parent = row }), 12)
		UI.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 60, 1, 0), Font = UI.HAND, TextSize = 19,
			TextColor3 = if done then C.ink else C.soil, TextXAlignment = Enum.TextXAlignment.Right, Text = if done then Format.number(line.coins) else "", Parent = row })
	end
	local all = till.scanned >= #till.lines
	totalLine.Text = if all then `TOTAL   {Format.number(total(till))} coins` else `Scanned {till.scanned} of {#till.lines}`
	totalLine.TextColor3 = if all then C.green else C.ink
end

------------------------------------------------------------------------
-- The bell over a till someone's waiting at (your screen only)

local bells = {} -- [checkoutId] = BillboardGui

local function bellOver(checkout: string, model: Model)
	local gui = bells[checkout]
	if gui and gui.Parent then
		return gui
	end
	local part = model:FindFirstChild("Bell") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	gui = make("BillboardGui", {
		Name = "TillBell", Adornee = part, Size = UDim2.fromOffset(150, 64), StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0),
		AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 260, ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui"),
	})
	UI.chalkboard({ size = UDim2.fromOffset(0, 34), autoWidth = true, anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5), text = "🛎️ Serve me!", textSize = 22, parent = gui })
	bells[checkout] = gui
	return gui
end

local function dropBell(checkout: string)
	if bells[checkout] then
		bells[checkout]:Destroy()
		bells[checkout] = nil
	end
end

------------------------------------------------------------------------
-- Serving

local fillsOff = false
-- Your store's Fill prompts go quiet while you serve (E is for the till).
local function quietFills(off: boolean)
	if off == fillsOff then
		return
	end
	fillsOff = off
	local plot = myPlot()
	local farm = plot and workspace:FindFirstChild("World") and workspace.World:FindFirstChild(`Plot{plot}`)
	local items = farm and farm:FindFirstChild("Store") and farm.Store:FindFirstChild("Items")
	for _, prompt in if items then items:GetDescendants() else {} do
		if prompt:IsA("ProximityPrompt") and prompt.Name == "FillPrompt" then
			prompt.Enabled = not off
		end
	end
end

local busy = false
local function serve()
	local checkout = behindWhich()
	local till = checkout and tills[checkout]
	if busy or not till then
		return
	end
	busy = true
	local result = StoreAction:InvokeServer("Serve", checkout)
	busy = false
	if result.ok and result.result then
		if result.result.paid then
			Sfx.play("TillOpen")
			local at = receipt.AbsolutePosition + Vector2.new(receipt.AbsoluteSize.X / 2, 0) - UI.screen.AbsolutePosition
			UI.float(`+{Format.number(result.result.paid)}`, UDim2.fromOffset(at.X, at.Y - 10), C.gold)
		elseif result.result.scanned then
			till.scanned = math.max(till.scanned, result.result.scanned)
		end
	elseif result.reason ~= "Cooldown" then
		local text = Reasons(result.reason)
		if text then
			UI.toast(text, "Error", 2.5)
		end
	end
end

local function update()
	local plot = myPlot()
	-- bells over tills with nobody behind them
	local here = behindWhich()
	for checkout in tills do
		local model = plot and itemModel(plot, checkout)
		if model and checkout ~= here then
			bellOver(checkout, model)
		else
			dropBell(checkout)
		end
	end
	for checkout in bells do
		if not tills[checkout] then
			dropBell(checkout)
		end
	end
	for _, gui in bells do
		local board = gui:FindFirstChildWhichIsA("Frame")
		if board and not UI.calm then
			board.Position = UDim2.fromScale(0.5, 0.5 + math.sin(os.clock() * 4) * 0.08)
		end
	end
	-- the stamp and the receipt while you're behind a till with a shopper
	local till = here and tills[here]
	if not till then
		FieldController.withdraw("Till")
		receipt.Visible = false
		quietFills(false)
		return
	end
	quietFills(true)
	receipt.Visible = true
	drawReceipt(till)
	local n = #till.lines
	if till.scanned < n then
		local line = till.lines[till.scanned + 1]
		local crop = Crops.ById[line.crop]
		FieldController.offer("Till", { priority = 30, text = "SCAN\n ", sub = `{crop and crop.icon or ""} ×{line.units}`, kind = "green",
			info = `🧾 Scan their basket: {till.scanned + 1} of {n}`, press = serve })
	else
		FieldController.offer("Till", { priority = 30, text = "TAKE\n ", sub = `{Format.number(total(till))} coins`, kind = "gold",
			info = "🧾 All scanned: take their coins", press = serve })
	end
end

------------------------------------------------------------------------
-- Everyone: the bell, the beep, the drawer

local function flash(model: Model)
	local glass = model:FindFirstChild("ScanGlass")
	if glass and glass:IsA("BasePart") then
		local before = glass.Color
		glass.Color = Color3.fromRGB(255, 220, 210)
		task.delay(0.12, function()
			glass.Color = before
		end)
	end
end

local function popDrawer(model: Model)
	local drawer, handle = model:FindFirstChild("Drawer"), model:FindFirstChild("Handle")
	if not drawer or not drawer:IsA("BasePart") or drawer:GetAttribute("Open") then
		return
	end
	drawer:SetAttribute("Open", true)
	local out = model:GetPivot().LookVector * -0.5 -- (toward whoever serves: the model's back)
	for _, part in { drawer, handle } do
		if part and part:IsA("BasePart") then
			local home = part.CFrame
			if UI.calm then
				part.CFrame = home + out
			else
				TweenService:Create(part, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = home + out }):Play()
			end
			task.delay(1.1, function()
				TweenService:Create(part, TweenInfo.new(0.25), { CFrame = home }):Play()
			end)
		end
	end
	task.delay(1.4, function()
		drawer:SetAttribute("Open", nil)
	end)
end

function CheckoutController.Start()
	Remotes.event("ShopperEvent").OnClientEvent:Connect(function(kind, event)
		if kind == "Till" then
			if event.plot ~= myPlot() then
				return
			end
			if event.done then
				tills[event.checkout] = nil
			else
				local till = tills[event.checkout]
				if till and till.id == event.id then
					till.lines = event.lines
					till.scanned = math.max(till.scanned, event.scanned)
				else
					tills[event.checkout] = { id = event.id, lines = event.lines, scanned = event.scanned }
				end
			end
		elseif kind == "Bell" or kind == "Scan" or kind == "Paid" then
			local model = event.checkout and itemModel(event.plot, event.checkout)
			if not model then
				return
			end
			if kind == "Bell" then
				Sfx.play("ShopBell", model:FindFirstChild("Bell") or model.PrimaryPart)
			elseif kind == "Scan" then
				Sfx.play("Scan", model:FindFirstChild("ScanGlass") or model.PrimaryPart, 0.97 + math.random() * 0.06)
				flash(model)
			elseif model:FindFirstChild("Drawer") then
				popDrawer(model)
			end
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.1 then
			elapsed = 0
			update()
		end
	end)
end

return CheckoutController
