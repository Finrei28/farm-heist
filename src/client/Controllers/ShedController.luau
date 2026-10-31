-- The Packing Shed bench (docs/GameDesign.md §4.6, §5.3): opens from the
-- bench's prompt. Each barn stack is a crate label with two choices, each
-- showing what it pays right now: 🚚 Truck (today's market price, locked
-- when the pickup leaves) or 🏪 Store (your price there). Picking one
-- opens the wash: hold the stamp, let go with the meter in the green for
-- grade A (+15%), and the crate is packed. A truck crate goes into your
-- arms (carry it to the dock); a store crate goes to your store's stockroom.
-- The server times the hold itself (WarehouseService); the meter here is
-- the same clock as near as lag allows.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BarnRules = require(Shared.BarnRules)
local CrateRules = require(Shared.CrateRules)
local Crops = require(Shared.Config.Crops)
local MarketPrice = require(Shared.MarketPrice)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local ShopRules = require(Shared.ShopRules)
local Store = require(Shared.Config.Store)
local StoreLayout = require(Shared.StoreLayout)
local TruckRules = require(Shared.TruckRules)
local Warehouse = require(Shared.Config.Warehouse)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer
local WarehouseAction = Remotes.func("WarehouseAction")

local ShedController = {}

local WALK_AWAY = 20 -- studs from the bench that close the window
local WASH = Warehouse.WASH

local panel = UI.panel("Packing Shed", { accent = C.red, toolbar = true, width = 600, height = 420 })
local listLayout = make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.list })

local function now(): number
	return workspace:GetServerTimeNow()
end

local function bench(): BasePart?
	local index = player:GetAttribute("Plot")
	local plot = index and workspace.World:FindFirstChild(`Plot{index}`)
	return plot and plot.PackingShed:FindFirstChild("Bench")
end

------------------------------------------------------------------------
-- The wash: crate picture, meter, the stamp to hold

local wash = make("Frame", {
	Name = "Wash",
	Size = panel.list.Size,
	Position = panel.list.Position,
	BackgroundColor3 = C.kraft,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 26,
	Parent = panel.frame,
})
panel.list:GetPropertyChangedSignal("Size"):Connect(function()
	wash.Size = panel.list.Size
end)

local crateBox = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.2, 0, 0.45, 0), Size = UDim2.fromOffset(120, 104), ZIndex = 27, Parent = wash,
}, { UI.corner(5), UI.stroke(UI.SEAM, 3) })
UI.wood(crateBox, 4, true)
local crateIcon = UI.label({
	Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromOffset(0, 6), Font = UI.HEAD, TextSize = 52,
	TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 28, Parent = crateBox,
})
local crateCount = UI.label({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 24),
	BackgroundTransparency = 0, BackgroundColor3 = C.cream, Font = UI.HEAD, TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 28, Parent = crateBox,
})
make("UICorner", { CornerRadius = UDim.new(0, 3), Parent = crateCount })
local destination = UI.label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.2, 0, 0.45, 62), Size = UDim2.fromOffset(170, 24),
	Font = UI.HAND, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 27, Parent = wash,
})

-- The meter: a tube that fills with water while you hold; the green band
-- is grade A.
local tube = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.45, 0), Size = UDim2.fromOffset(46, 190),
	BackgroundColor3 = C.cream, ClipsDescendants = true, ZIndex = 27, Parent = wash,
}, { UI.corner(10), UI.stroke(UI.SEAM, 3) })
make("Frame", {
	Name = "Green", AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1 - WASH.greenMin), Size = UDim2.fromScale(1, WASH.greenMax - WASH.greenMin),
	BackgroundColor3 = C.green, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 27, Parent = tube,
})
local water = make("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0),
	BackgroundColor3 = C.sky, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 28, Parent = tube,
})
UI.label({
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, 30, 0.45, -95 + 190 * (1 - (WASH.greenMin + WASH.greenMax) / 2)), -- (level with the band)
	Size = UDim2.fromOffset(60, 22), Font = UI.HAND, TextSize = 20, TextColor3 = C.green, Text = "◀ A", ZIndex = 27, Parent = wash,
})

local holdStamp, holdButton = UI.stamp({ text = "HOLD\nTO WASH", kind = "blue", diameter = 122, textSize = 20,
	anchor = Vector2.new(0.5, 0.5), position = UDim2.new(0.8, 0, 0.45, 0), zIndex = 27, parent = wash })
local hint = UI.label({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -20, 0, 26),
	Font = UI.HAND, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 27, Parent = wash,
	Text = "Hold the stamp, let go in the green: grade A sells for 15% more",
})
local _, back = UI.button({ text = "Back", kind = "cream", size = UDim2.fromOffset(80, 34), position = UDim2.fromOffset(6, 6), zIndex = 27, parent = wash })

-- The prize: a rosette for grade A, a plain tag for B.
local resultHolder = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.8, 0, 0.42, 0), Size = UDim2.fromOffset(130, 170),
	BackgroundTransparency = 1, Visible = false, ZIndex = 30, Parent = wash,
})
local rosette, rosetteLabel = UI.rosette({ diameter = 110, color = C.gold, text = "A", textSize = 40, anchor = Vector2.new(0.5, 0),
	position = UDim2.new(0.5, 0, 0, 0), zIndex = 30, parent = resultHolder })
local gradeB = UI.tag({ text = "Grade B", size = UDim2.fromOffset(124, 36), anchor = Vector2.new(0.5, 0.5), position = UDim2.new(0.5, 0, 0.35, 0),
	textSize = 20, zIndex = 30, parent = resultHolder })

local chosen = nil -- { key, to } while the wash view is up
local holding = false
local pressedAt = 0
local busy = false

local function showList()
	wash.Visible = false
	chosen = nil
	holding = false
end

local function showWash(key: string, to: string)
	local cropId = BarnRules.parse(key)
	local crop = Crops.ById[cropId]
	local state = PlayerState.current
	local units = math.min(state and state.inventory.crops[key] or 0, CrateRules.size(cropId))
	chosen = { key = key, to = to }
	crateIcon.Text = crop.icon or "📦"
	crateCount.Text = `{crop.name} ×{units}`
	destination.Text = if to == "Truck" then "🚚 for the pickup" else "🏪 for your store"
	water.Size = UDim2.fromScale(1, 0)
	resultHolder.Visible = false
	holdStamp.Visible = true
	hint.Text = "Hold the stamp, let go in the green: grade A sells for 15% more"
	wash.Visible = true
end

local function finish(result)
	resultHolder.Visible = true
	holdStamp.Visible = false
	rosette.Visible = result.grade == "A"
	gradeB.Visible = result.grade ~= "A"
	rosetteLabel.Text = "A"
	if result.grade == "A" then
		rosette.Rotation = -25
		TweenService:Create(rosette, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Rotation = 0 }):Play()
	end
	hint.Text = if result.grade == "A" then "Grade A! +15%" else "Grade B. Let go in the green next time for A."
	task.wait(1.1)
	if result.to == "Truck" then
		panel.close()
		UI.toast("Crate in your arms: load it into the pickup at the dock 🚚", nil, 3)
	else
		UI.toast("Crate sent to your store's stockroom. Fill a display (hold E at it) to put it out!", "Good", 3)
		showList()
	end
end

local function release()
	if not holding then
		return
	end
	holding = false
	busy = true
	local result = WarehouseAction:InvokeServer("Pack")
	busy = false
	if result.ok then
		finish(result.result)
	else
		hint.Text = Reasons(result.reason) or "Hold it a little longer."
		water.Size = UDim2.fromScale(1, 0)
	end
end

holdButton.InputBegan:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and chosen and not holding and not busy then
		holding = true
		pressedAt = os.clock()
		task.spawn(function()
			local result = WarehouseAction:InvokeServer("Wash", `{chosen.key}|{chosen.to}`)
			if not result.ok then
				holding = false
				hint.Text = Reasons(result.reason) or "Couldn't start the wash."
				water.Size = UDim2.fromScale(1, 0)
			end
		end)
	end
end)
holdButton.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		task.spawn(release)
	end
end)
holdButton.MouseLeave:Connect(function()
	task.spawn(release)
end)
RunService.RenderStepped:Connect(function()
	if holding then
		local meter = CrateRules.meter(os.clock() - pressedAt)
		water.Size = UDim2.fromScale(1, meter)
		local green = meter >= WASH.greenMin and meter <= WASH.greenMax
		water.BackgroundColor3 = if green then C.green elseif meter > WASH.greenMax then C.alarm else C.sky
	end
end)
back.Activated:Connect(showList)

------------------------------------------------------------------------
-- The list: one crate label per barn stack

local function row(order: number, key: string, units: number, state)
	local cropId, mutation, giant = BarnRules.parse(key)
	local crop = Crops.ById[cropId]
	local t = now()
	local truckPrice = MarketPrice.price(cropId, t)
	local storePrice = state.store.prices[cropId] or math.floor(ShopRules.reference(cropId, truckPrice) + 0.5)
	-- (can any display your store has unlocked hold it? is there room in the stockroom?)
	local holdable, needs = false, nil
	for itemId, def in Store.ITEMS do
		if def.kind == "Display" and StoreLayout.holds(itemId, crop.rarity) then
			if def.level <= state.store.level then
				holdable = true
			elseif not needs or def.level < needs then
				needs = def.level
			end
		end
	end
	local full = ShopRules.stockroomRoom(state.store) <= 0
	local frame = make("Frame", {
		Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = C.cream, LayoutOrder = order, ZIndex = 22, Parent = panel.list,
	}, { UI.corner(3), UI.stroke(UI.SEAM, 2) })
	make("Frame", { Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = Rarities.ById[crop.rarity].color, BorderSizePixel = 0, ZIndex = 23, Parent = frame })
	UI.label({ Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(40, 40), Font = UI.HEAD, Text = crop.icon or "🌱", TextSize = 28, ZIndex = 23, Parent = frame })
	local name = `{if giant then "Giant " else ""}{if mutation then mutation .. " " else ""}{crop.name}`
	UI.fit(UI.label({ Position = UDim2.fromOffset(58, 5), Size = UDim2.new(1, -330, 0, 22), Font = UI.HEAD, TextSize = 17, Text = string.upper(name), ZIndex = 23, Parent = frame }), 11)
	UI.fit(UI.label({ Position = UDim2.fromOffset(58, 28), Size = UDim2.new(1, -330, 0, 20), Font = UI.HAND, TextSize = 18,
		Text = `×{units} in the barn · {CrateRules.size(cropId)} a crate`, ZIndex = 23, Parent = frame }), 11)
	local carrying = player:GetAttribute("Carrying") ~= nil
	local truckHolder, truckButton = UI.button({ text = `🚚 Truck {truckPrice}`, kind = if carrying then "cream" else "blue", size = UDim2.fromOffset(122, 42),
		anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -140, 0.5, 2), textSize = 17, zIndex = 23, parent = frame })
	truckHolder.Name = "Truck"
	local storeText = if not holdable then `🏪 Store Lv {needs}` elseif full then "🏪 Full" else `🏪 Store {storePrice}`
	local _, storeButton = UI.button({ text = storeText, kind = if holdable and not full then "green" else "cream", size = UDim2.fromOffset(122, 42),
		anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -10, 0.5, 2), textSize = 17, zIndex = 23, parent = frame })
	truckButton.Activated:Connect(function()
		if player:GetAttribute("Carrying") then
			UI.toast("Load the crate you're carrying into the pickup first.", "Error", 3)
		else
			showWash(key, "Truck")
		end
	end)
	storeButton.Activated:Connect(function()
		if not holdable then
			UI.toast(`Your store can't show {crop.rarity} crops yet: that comes with Store Level {needs}. Send them by truck.`, "Error", 4)
		elseif full then
			UI.toast("Your store's stockroom is full: Fill your displays, or level your store up for more room.", "Error", 4)
		else
			showWash(key, "Store")
		end
	end)
end

local shown = ""
local function render(force: boolean?)
	local state = PlayerState.current
	if not state or not UI.isOpen(panel) then
		return
	end
	local t = now()
	local warehouse = state.warehouse
	local tier = TruckRules.tier(warehouse)
	local away = TruckRules.home(warehouse, t) < 1
	local pickup = if away then "on the road" else `{#warehouse.bed}/{tier.truckCrates} crates`
	local arms = if player:GetAttribute("Carrying") then "  ·  carrying a crate" else ""
	panel.toolbar.Text = `🚚 Pickup {pickup}  ·  🏪 Stockroom {#state.store.stockroom}/{ShopRules.stockroomSize(state.store)} crates{arms}`
	-- (prices move every few seconds: the rows redraw with them, but only when one changes)
	local prices = {}
	for key in state.inventory.crops do
		local cropId = BarnRules.parse(key)
		if Crops.ById[cropId] then
			prices[cropId] = MarketPrice.price(cropId, t)
		end
	end
	local signature = HttpService:JSONEncode({ state.inventory.crops, state.store.prices, state.store.level, #state.store.stockroom, prices, player:GetAttribute("Carrying") or "" })
	if signature == shown and not force then
		return
	end
	shown = signature
	UI.clear(panel.list)
	listLayout.Parent = panel.list
	local keys = {}
	for key, units in state.inventory.crops do
		if units > 0 and Crops.ById[BarnRules.parse(key)] then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a, b)
		local ca, cb = Crops.ById[BarnRules.parse(a)], Crops.ById[BarnRules.parse(b)]
		if ca.value ~= cb.value then
			return ca.value > cb.value
		end
		return a < b
	end)
	if #keys == 0 then
		local note = make("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = C.cream, ZIndex = 22, Parent = panel.list }, { UI.corner(3), UI.stroke(UI.SEAM, 2) })
		UI.label({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), Font = UI.HAND, TextSize = 20, TextWrapped = true, ZIndex = 23, Parent = note,
			Text = "Your barn is empty. Harvest ripe crops, then pack them here." })
		return
	end
	for i, key in keys do
		row(i, key, state.inventory.crops[key], state)
	end
end

function ShedController.Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Opens") == "Bench" then
			showList()
			panel.open()
		end
	end)
	panel.onOpen = function()
		render(true)
	end
	panel.onClose = showList
	PlayerState.changed:Connect(function()
		render()
	end)
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		render()
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if UI.isOpen(panel) then
				if not wash.Visible then
					render()
				end
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local b = bench()
				if root and b and (root.Position - b.Position).Magnitude > WALK_AWAY then
					panel.close()
				end
			end
		end
	end)
end

return ShedController
