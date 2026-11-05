-- Washing and packing by hand (docs/GameDesign.md §4.6, §5.3): the Packing
-- Shed's bench, or the warehouses' wash table, from its prompt. Each barn
-- stack is a crate label with what it pays right now by 🚚 truck (today's
-- market price, locked when the truck leaves) and in your 🏪 store (your
-- price there), and one Pack button: hold the stamp, let go with the meter in
-- the green for grade A (+15%), and the crate joins your packed crates, for
-- whichever you choose later (shared/PackRules): load it at the dock (client
-- DockController) or put it out at a display.
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
local PackRules = require(Shared.PackRules)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local ShopRules = require(Shared.ShopRules)
local Store = require(Shared.Config.Store)
local StoreLayout = require(Shared.StoreLayout)
local TruckRules = require(Shared.TruckRules)
local Warehouse = require(Shared.Config.Warehouse)
local WarehouseRules = require(Shared.WarehouseRules)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)
local Sfx = require(script.Parent.Parent.Sfx)

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
	local warehouse = plot and plot:FindFirstChild("Warehouse")
	return warehouse and warehouse.Building:FindFirstChild("Bench") :: BasePart?
end

-- The trucks' name, whether this is still the Packing Shed, and the level's
-- info.
local function trucks(state)
	local info = WarehouseRules.level(state.warehouse.level)
	return Warehouse.TRUCK_NAMES[info.truck], info.stage == 1, info
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
local crateCount = UI.fit(UI.label({ -- (a long name shrinks to stay on its label: "Shocked Tomato ×6" ran off it)
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -12, 0, 26),
	BackgroundTransparency = 0, BackgroundColor3 = C.cream, Font = UI.HEAD, TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 28, Parent = crateBox,
}), 9)
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

local chosen = nil -- { key } while the wash view is up
local holding = false
local pressedAt = 0
local busy = false

local function showList()
	wash.Visible = false
	chosen = nil
	holding = false
end

local function showWash(key: string)
	local cropId = BarnRules.parse(key)
	local crop = Crops.ById[cropId]
	local state = PlayerState.current
	local units = math.min(state and state.inventory.crops[key] or 0, CrateRules.size(cropId))
	chosen = { key = key }
	local _, mutation, giant = BarnRules.parse(key)
	crateIcon.Text = crop.icon or "📦"
	crateCount.Text = `{if giant then "Giant " else ""}{if mutation then mutation .. " " else ""}{crop.name} ×{units}`
	destination.Text = if CrateRules.storeable(key) then "📦 for your truck or store" else "🚚 for your truck only"
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
	UI.toast("Packed! Load it onto the truck at the dock, or press E at a display to put it out.", "Good", 3.5)
	showList()
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
		Sfx.play("Tape")
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
			local result = WarehouseAction:InvokeServer("Wash", chosen.key)
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
	local bonus = CrateRules.mutationValue({ key = key }) -- (a mutated crop: the truck pays this many times more)
	local truckPrice = math.floor(MarketPrice.price(cropId, t) * bonus + 0.5)
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
	local full = PackRules.room(state) <= 0
	local frame = make("Frame", {
		Size = UDim2.new(1, 0, 0, 76), BackgroundColor3 = C.cream, LayoutOrder = order, ZIndex = 22, Parent = panel.list,
	}, { UI.corner(3), UI.stroke(UI.SEAM, 2) })
	make("Frame", { Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = Rarities.ById[crop.rarity].color, BorderSizePixel = 0, ZIndex = 23, Parent = frame })
	UI.label({ Position = UDim2.fromOffset(14, 18), Size = UDim2.fromOffset(40, 40), Font = UI.HEAD, Text = crop.icon or "🌱", TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 23, Parent = frame })
	local name = `{if giant then "Giant " else ""}{if mutation then mutation .. " " else ""}{crop.name}`
	UI.fit(UI.label({ Position = UDim2.fromOffset(58, 5), Size = UDim2.new(1, -200, 0, 22), Font = UI.HEAD, TextSize = 17, Text = string.upper(name), ZIndex = 23, Parent = frame }), 11)
	UI.fit(UI.label({ Position = UDim2.fromOffset(58, 27), Size = UDim2.new(1, -200, 0, 20), Font = UI.HAND, TextSize = 18,
		Text = `×{units} in the barn · {CrateRules.size(cropId)} a crate`, ZIndex = 23, Parent = frame }), 11)
	local truckText = UI.formatNumber(truckPrice)
	UI.fit(UI.label({ Position = UDim2.fromOffset(58, 48), Size = UDim2.new(1, -200, 0, 20), Font = UI.HAND, TextSize = 18, ZIndex = 23, Parent = frame,
		Text = if not CrateRules.storeable(key) then `🚚 {truckText} coins each (✨ ×{bonus}, truck only)`
			elseif not holdable then `🚚 {truckText} coins each · 🏪 from Store Level {needs}`
			else `🚚 {truckText} · 🏪 {UI.formatNumber(storePrice)} coins each` }), 11)
	local _, packButton = UI.button({ text = if full then "📦 Full" else "📦 Pack", kind = if full then "cream" else "blue", size = UDim2.fromOffset(122, 46),
		anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -10, 0.5, 0), textSize = 18, zIndex = 23, parent = frame })
	packButton.Activated:Connect(function()
		if full then
			UI.toast("Your packed crates are full: load a truck or fill your displays to make room.", "Error", 4)
		else
			showWash(key)
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
	local name, shed, info = trucks(state)
	panel.frame.Sign.Title.Text = if shed then "Packing Shed" else "Wash Table"
	local truckText
	if info.trucks == 1 then
		truckText = if TruckRules.isHome(warehouse, 1, t) then `{#(warehouse.beds[1] or {})}/{info.truckCrates} crates` else "on the road"
	else
		truckText = `{TruckRules.home(warehouse, t)} of {info.trucks} home`
	end
	panel.toolbar.Text = `🚚 {name} {truckText}  ·  📦 Packed crates {#state.store.stockroom}/{PackRules.size(state)}`
	-- (prices move every few seconds: the rows redraw with them, but only when one changes)
	local prices = {}
	for key in state.inventory.crops do
		local cropId = BarnRules.parse(key)
		if Crops.ById[cropId] then
			prices[cropId] = MarketPrice.price(cropId, t)
		end
	end
	local signature = HttpService:JSONEncode({ state.inventory.crops, state.store.prices, state.store.level, warehouse.level, #state.store.stockroom, prices })
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
