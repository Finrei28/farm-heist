-- The market, as the player sees it (docs/GameDesign.md §4.7, §5.3). All of
-- it is worked out here from shared/MarketPrice and the server clock, the
-- same numbers the server uses when a truck leaves:
--   the Market window (side bar, or the Exchange desk in town): a
--     chalkboard of crop prices with ▲/▼ over the last 10 minutes, a 3-hour
--     sparkline, this hour's Hot Crop and Glut, and your pickup with the
--     coins it would lock if you sent it now (Send it from here, anywhere)
--   the Exchange's flip-board on the building's face in town
--   the ticker under the purse: the events, then the crops you have
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BarnRules = require(Shared.BarnRules)
local Crops = require(Shared.Config.Crops)
local Market = require(Shared.Config.Market)
local MarketPrice = require(Shared.MarketPrice)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local TruckRules = require(Shared.TruckRules)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)
local HudController = require(script.Parent.HudController)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer
local TruckAction = Remotes.func("TruckAction")

local MarketController = {}

local TREND = 600 -- ▲/▼ compares with this many seconds ago
local SPARK_SPAN = 3 * 3600
local SPARK_BARS = 36
local UP = Color3.fromRGB(150, 230, 120) -- green chalk
local DOWN = Color3.fromRGB(255, 150, 160) -- pink chalk
local GOLD_CHALK = Color3.fromRGB(255, 214, 110)

local function now(): number
	return workspace:GetServerTimeNow()
end

-- "▲ 6%", its colour and the sign (1, −1, 0).
local function trend(cropId: string, t: number)
	local price, before = MarketPrice.price(cropId, t), MarketPrice.price(cropId, t - TREND)
	local change = (price - before) / math.max(1, before)
	if change > 0.005 then
		return `▲ {math.floor(change * 100 + 0.5)}%`, UP, 1
	elseif change < -0.005 then
		return `▼ {math.floor(-change * 100 + 0.5)}%`, DOWN, -1
	end
	return "▬ 0%", C.chalk, 0
end

-- The Hot Crop and the Glut as chalk lines: { text, color, live }. Once
-- this hour's is over, the next hour's (so there's always one to plan for).
local function eventLines(t: number)
	local thisHour, nextHour = MarketPrice.schedule(t), MarketPrice.schedule(t - t % 3600 + 3600)
	local lines = {}
	for _, entry in { { "hot", "🔥 Hot Crop", Market.HOT.mult, GOLD_CHALK }, { "glut", "📉 Glut", Market.GLUT.mult, DOWN } } do
		local kind, title, mult, color = entry[1], entry[2], entry[3], entry[4]
		local event = if t < thisHour[kind].endsAt then thisHour[kind] else nextHour[kind]
		local crop = Crops.ById[event.crop]
		if t >= event.startsAt and t < event.endsAt then
			table.insert(lines, { text = `{title}: {crop.icon or ""} {crop.name} ×{mult} · {UI.formatTime(event.endsAt - t)} left`, color = color, live = true })
		elseif t < event.startsAt then
			table.insert(lines, { text = `{title} next: {crop.icon or ""} {crop.name} ×{mult} in {UI.formatTime(event.startsAt - t)}`, color = C.chalk })
		end
	end
	return lines
end

------------------------------------------------------------------------
-- The Market window

local panel = UI.panel("Market", { tabs = { "Yours", "All" }, tabColors = { C.gold, C.sky }, accent = C.green, toolbar = true, width = 640, height = 440 })
panel.list.BackgroundTransparency = 0
panel.list.BackgroundColor3 = C.board
make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = panel.list })
make("UIStroke", { Color = Color3.fromRGB(150, 104, 64), Thickness = 4, Parent = panel.list })
local listLayout = make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.list })

local rows = {} -- [cropId] = { price, change }
local truckLine, truckButtonHolder, truckButton
local eventLabels = {}

local function chalk(props)
	props.Font = props.Font or UI.HAND
	props.TextColor3 = props.TextColor3 or C.chalk
	props.ZIndex = props.ZIndex or 23
	return UI.label(props)
end

-- Bars for the last 3 hours, scaled between the lowest and highest.
local function sparkline(parent: Instance, cropId: string, t: number)
	local values, low, high = {}, math.huge, -math.huge
	for i = 1, SPARK_BARS do
		local value = MarketPrice.multiplier(cropId, t - SPARK_SPAN + SPARK_SPAN * i / SPARK_BARS)
		values[i] = value
		low, high = math.min(low, value), math.max(high, value)
	end
	local span = math.max(0.02, high - low)
	for i, value in values do
		make("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new((i - 1) / SPARK_BARS, 0, 1, 0),
			Size = UDim2.new(1 / SPARK_BARS, -1, 0.15 + 0.85 * (value - low) / span, 0),
			BackgroundColor3 = if i == SPARK_BARS then GOLD_CHALK else C.chalk,
			BackgroundTransparency = if i == SPARK_BARS then 0 else 0.45,
			BorderSizePixel = 0,
			ZIndex = 23,
			Parent = parent,
		})
	end
end

local function cropRow(order: number, crop, t: number)
	local frame = make("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 23, Parent = panel.list })
	make("Frame", { -- a chalk rule under each line
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, 0), Size = UDim2.new(1, -12, 0, 1),
		BackgroundColor3 = C.chalk, BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 23, Parent = frame,
	})
	chalk({ Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(34, 46), Font = UI.HEAD, TextSize = 26, Text = crop.icon or "🌱", Parent = frame })
	UI.fit(chalk({ Position = UDim2.fromOffset(48, 2), Size = UDim2.new(0.34, -50, 0, 24), TextSize = 22, Text = crop.name, Parent = frame }), 12)
	chalk({ Position = UDim2.fromOffset(48, 24), Size = UDim2.new(0.34, -50, 0, 18), TextSize = 16, TextTransparency = 0.25,
		Text = `usual {UI.formatNumber(crop.value)} · {crop.rarity}`, TextColor3 = Rarities.ById[crop.rarity].color:Lerp(C.chalk, 0.4), Parent = frame })
	local price = chalk({ Position = UDim2.new(0.34, 0, 0, 0), Size = UDim2.new(0.16, 0, 1, 0), Font = UI.HEAD, TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = frame })
	local change = chalk({ Position = UDim2.new(0.5, 12, 0, 0), Size = UDim2.new(0.14, 0, 1, 0), TextSize = 20, Text = "", Parent = frame })
	local spark = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0.3, -12, 0, 30),
		BackgroundTransparency = 1, ZIndex = 23, Parent = frame,
	})
	sparkline(spark, crop.id, t)
	rows[crop.id] = { price = price, change = change }
end

-- Crops you have somewhere: barn, truck bed, dock, stockroom, shelves, seeds.
local function yours(state)
	local set = {}
	for key, units in state.inventory.crops do
		if units > 0 then
			set[BarnRules.parse(key)] = true
		end
	end
	for cropId, count in state.inventory.seeds do
		if count > 0 then
			set[cropId] = true
		end
	end
	for _, list in { state.warehouse.bed, state.warehouse.dock, state.shop.stockroom } do
		for _, crate in list do
			set[crate.crop] = true
		end
	end
	for _, shelf in state.shop.shelves do
		set[shelf.crop] = true
	end
	return set
end

local function updateLive()
	local state = PlayerState.current
	if not state or not UI.isOpen(panel) then
		return
	end
	local t = now()
	for cropId, row in rows do
		row.price.Text = UI.formatNumber(MarketPrice.price(cropId, t))
		local text, color = trend(cropId, t)
		row.change.Text = text
		row.change.TextColor3 = color
	end
	local lines = eventLines(t)
	for i, label in eventLabels do
		label.Text = lines[i] and lines[i].text or ""
		label.TextColor3 = lines[i] and lines[i].color or C.chalk
	end
	if truckLine then
		local warehouse = state.warehouse
		local run = TruckRules.nextBack(warehouse, t)
		local tier = TruckRules.tier(warehouse)
		if run then
			truckLine.Text = if t < run.arriveAt
				then `🚚 On the road with {#run.crates} crate{if #run.crates == 1 then "" else "s"} ({UI.formatNumber(run.coins)} locked) · paid in {UI.formatTime(run.arriveAt - t)}`
				else `🚚 Sold in the City · home in {UI.formatTime(run.returnAt - t)}`
			truckButtonHolder.Visible = false
		elseif #warehouse.bed == 0 then
			truckLine.Text = `🚚 Pickup home, empty (0/{tier.truckCrates}). Pack crates at the Packing Shed.`
			truckButtonHolder.Visible = false
		else
			local total = TruckRules.quote(warehouse.bed, function(cropId)
				return MarketPrice.price(cropId, t)
			end)
			truckLine.Text = `🚚 Pickup {#warehouse.bed}/{tier.truckCrates} · sending now locks {UI.formatNumber(total)} coins`
			truckButtonHolder.Visible = true
		end
	end
end

local shown = ""
local function render(force: boolean?)
	local state = PlayerState.current
	if not state or not UI.isOpen(panel) then
		return
	end
	local mine = yours(state)
	local signature = HttpService:JSONEncode({ panel.tab, mine, math.floor(now() / 60) })
	if signature == shown and not force then
		updateLive()
		return
	end
	shown = signature
	UI.clear(panel.list)
	listLayout.Parent = panel.list
	table.clear(rows)
	table.clear(eventLabels)
	panel.toolbar.Text = "Trucks sell at these prices: they lock the moment your truck leaves."

	local top = make("Frame", { Size = UDim2.new(1, 0, 0, 104), BackgroundTransparency = 1, LayoutOrder = 0, ZIndex = 23, Parent = panel.list })
	truckLine = chalk({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -150, 0, 40), TextSize = 21, TextWrapped = true, Text = "", Parent = top })
	truckButtonHolder, truckButton = UI.button({ text = "SEND NOW", kind = "gold", size = UDim2.fromOffset(120, 40), anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -12, 0, 4), zIndex = 24, parent = top })
	truckButton.Activated:Connect(function()
		local result = TruckAction:InvokeServer("Dispatch")
		if not result.ok then
			local text = Reasons(result.reason)
			if text then
				UI.toast(text, "Error", 3)
			end
		end
	end)
	for i = 1, 2 do
		eventLabels[i] = chalk({ Position = UDim2.fromOffset(12, 30 + i * 24), Size = UDim2.new(1, -24, 0, 24), TextSize = 20, Text = "", Parent = top })
	end

	local list = {}
	for _, crop in Crops.List do
		if panel.tab == "All" or mine[crop.id] then
			table.insert(list, crop)
		end
	end
	if #list == 0 then
		chalk({ Size = UDim2.new(1, 0, 0, 40), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1,
			Text = "Nothing of yours yet: the All tab has every crop.", Parent = panel.list })
	end
	local t = now()
	for i, crop in list do
		cropRow(i, crop, t)
	end
	updateLive()
end

------------------------------------------------------------------------
-- The Exchange's flip-board (on the building's face in town)

local boardCells = {} -- [cropId] = { price, arrow }
local boardEvents

local function buildBoard()
	local exchange = workspace:WaitForChild("World"):WaitForChild("Town"):WaitForChild("Exchange")
	local gui = make("SurfaceGui", {
		Name = "ExchangeBoard", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 20, LightInfluence = 0.3, MaxDistance = 400, ResetOnSpawn = false, Parent = exchange,
	})
	local back = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(30, 34, 32), BorderSizePixel = 0, Parent = gui })
	local header = make("Frame", { Size = UDim2.new(1, 0, 0, 110), BorderSizePixel = 0, Parent = back })
	UI.wood(header, 2, false)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1, Font = UI.HEAD, Text = "CLOVERDALE EXCHANGE", TextSize = 56,
		TextColor3 = C.cream, TextStrokeColor3 = UI.SEAM, TextStrokeTransparency = 0, Parent = header,
	})
	boardEvents = make("TextLabel", {
		Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Font = UI.HEAD, Text = "",
		TextSize = 30, TextColor3 = GOLD_CHALK, Parent = header,
	})
	local perColumn = math.ceil(#Crops.List / 2)
	local rowHeight = (800 - 130) / perColumn
	for i, crop in Crops.List do
		local column, rowIndex = (i - 1) // perColumn, (i - 1) % perColumn
		local cell = make("Frame", {
			Position = UDim2.fromOffset(16 + column * 392, 122 + rowIndex * rowHeight), Size = UDim2.fromOffset(376, rowHeight - 6),
			BackgroundColor3 = Color3.fromRGB(46, 50, 48), BorderSizePixel = 0, Parent = back,
		}, { UI.corner(4) })
		make("TextLabel", {
			Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.6, -8, 1, 0), BackgroundTransparency = 1, Font = UI.HEAD,
			Text = `{crop.icon or ""} {string.upper(crop.name)}`, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.cream, Parent = cell,
		}, { make("UITextSizeConstraint", { MaxTextSize = 28 }) })
		-- the split-flap price: dark tiles with a hinge line across
		local flap = make("Frame", {
			Position = UDim2.new(0.6, 0, 0, 4), Size = UDim2.new(0.28, 0, 1, -8), BackgroundColor3 = Color3.fromRGB(20, 22, 22), BorderSizePixel = 0, Parent = cell,
		}, { UI.corner(3) })
		make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.fromRGB(70, 72, 70), BorderSizePixel = 0, ZIndex = 3, Parent = flap })
		local price = make("TextLabel", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = UI.HEAD, Text = "", TextScaled = true, TextColor3 = GOLD_CHALK, ZIndex = 2, Parent = flap,
		}, { make("UITextSizeConstraint", { MaxTextSize = 32 }) })
		local arrow = make("TextLabel", {
			Position = UDim2.new(0.88, 0, 0, 0), Size = UDim2.new(0.12, 0, 1, 0), BackgroundTransparency = 1, Font = UI.HEAD, Text = "", TextSize = 26,
			TextColor3 = UP, Parent = cell,
		})
		boardCells[crop.id] = { price = price, arrow = arrow }
	end
end

local function updateBoard()
	local t = now()
	for cropId, cell in boardCells do
		cell.price.Text = UI.formatNumber(MarketPrice.price(cropId, t))
		local _, color, sign = trend(cropId, t)
		cell.arrow.Text = if sign > 0 then "▲" elseif sign < 0 then "▼" else "▬"
		cell.arrow.TextColor3 = color
	end
	if boardEvents then
		local parts = {}
		for _, line in eventLines(t) do
			if line.live then
				table.insert(parts, line.text)
			end
		end
		boardEvents.Text = if #parts > 0 then table.concat(parts, "   ") else "Prices lock when your truck leaves"
	end
end

------------------------------------------------------------------------
-- The ticker under the purse

local tickerBoard, tickerLabel = UI.chalkboard({ name = "Ticker", size = UDim2.fromOffset(270, 26), anchor = Vector2.new(0.5, 0),
	position = UDim2.new(0.5, -16, 0, 116), textSize = 18, parent = UI.screen })
local tickerIndex = 0

local function updateTicker()
	local state = PlayerState.current
	if not state then
		tickerBoard.Visible = false
		return
	end
	local t = now()
	local items = {}
	for _, line in eventLines(t) do
		if line.live then
			table.insert(items, line.text)
		end
	end
	local mine = {}
	for key, units in state.inventory.crops do
		local cropId = BarnRules.parse(key)
		if units > 0 and Crops.ById[cropId] and not table.find(mine, cropId) then
			table.insert(mine, cropId)
		end
	end
	table.sort(mine)
	for _, cropId in mine do
		local crop = Crops.ById[cropId]
		local text = trend(cropId, t)
		table.insert(items, `{crop.icon or ""} {crop.name} {MarketPrice.price(cropId, t)}  {text}`)
	end
	tickerBoard.Visible = #items > 0
	if #items > 0 then
		tickerIndex = tickerIndex % #items + 1
		tickerLabel.Text = items[tickerIndex]
	end
end

------------------------------------------------------------------------

function MarketController.Start()
	local button = HudController.sideButton("📈", "Market", 3)
	button.Activated:Connect(panel.toggle)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Opens") == "Market" then
			panel.open()
		end
	end)
	panel.onOpen = function()
		render(true)
	end
	panel.onTab(function()
		render(true)
	end)
	PlayerState.changed:Connect(function()
		render()
	end)
	task.spawn(function()
		local ok, err = pcall(buildBoard)
		if not ok then
			warn(`[MarketController] no Exchange board: {err}`)
		end
	end)
	task.spawn(function()
		local beat = 0
		while true do
			task.wait(1)
			beat += 1
			render()
			updateBoard()
			if beat % 4 == 0 then
				updateTicker()
			end
		end
	end)
	updateTicker()
end

return MarketController
