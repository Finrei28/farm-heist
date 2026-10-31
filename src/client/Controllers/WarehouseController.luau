-- The Warehouse window (docs/GameDesign.md §4.6, §5.3), from the side bar:
-- a clipboard with three tabs.
--   Pipeline: each station from the barn to the trucks, its crew ("2/3",
--             greyed slots saying what opens them) and how many crates a
--             minute it manages; the slowest is marked orange with a tip.
--             Each truck with its load, Send (and the price it would lock),
--             and the Drivers' rule.
--   Routes:   where each crop's crates go: 🚚 Truck, 🏪 Store or ✋ Keep (the
--             crew leaves it in the barn), or a split from Warehouse Level 5.
--   Upgrade:  the next Warehouse Level on blueprint paper, and the ladder.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BarnRules = require(Shared.BarnRules)
local CrateRules = require(Shared.CrateRules)
local Crops = require(Shared.Config.Crops)
local LandRules = require(Shared.LandRules)
local MarketPrice = require(Shared.MarketPrice)
local Remotes = require(Shared.Remotes)
local TruckRules = require(Shared.TruckRules)
local Warehouse = require(Shared.Config.Warehouse)
local WarehouseRules = require(Shared.WarehouseRules)
local WorkerRules = require(Shared.WorkerRules)
local Workers = require(Shared.Config.Workers)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)
local HudController = require(script.Parent.HudController)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer
local WarehouseAction = Remotes.func("WarehouseAction")
local TruckAction = Remotes.func("TruckAction")

local WarehouseController = {}

local BLUEPRINT = Color3.fromRGB(44, 84, 132)
local ORANGE = Color3.fromRGB(240, 140, 40)
local DRIVER_RULES = { 0, 0.9, 1, 1.1, 1.2, 1.3 } -- (WarehouseService.DRIVER_RULES)

local panel = UI.panel("Warehouse", { tabs = { "Pipeline", "Routes", "Upgrade" }, tabColors = { ORANGE, C.green, C.sky }, accent = C.red,
	toolbar = true, width = 660, height = 470 })
local listLayout = make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.list })

local function now(): number
	return workspace:GetServerTimeNow()
end

local function send(remote: RemoteFunction, action: string, arg: string?)
	task.spawn(function()
		local result = remote:InvokeServer(action, arg)
		if not result.ok then
			local text = Reasons(result.reason)
			if text then
				UI.toast(text, "Error", 3)
			end
		end
	end)
end

-- A crate-label row: colour band, icon, stencilled name, a handwritten line
-- (the left part when the row has things on the right).
local function labelRow(order: number, height: number, icon: string, title: string, detail: string, color: Color3?, rightWidth: number?)
	local frame = make("Frame", {
		Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = C.cream, LayoutOrder = order, ZIndex = 22, Parent = panel.list,
	}, { UI.corner(3), UI.stroke(UI.SEAM, 2) })
	make("Frame", { Name = "Band", Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = color or C.soil, BorderSizePixel = 0, ZIndex = 23, Parent = frame })
	UI.label({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0, 40, 0, math.min(height, 56)), Font = UI.HEAD, Text = icon, TextSize = 28, ZIndex = 23, Parent = frame })
	local width = UDim2.new(1, -(70 + (rightWidth or 0)), 0, 0)
	UI.fit(UI.label({ Position = UDim2.fromOffset(58, 5), Size = width + UDim2.fromOffset(0, 22), Font = UI.HEAD, TextSize = 17, Text = string.upper(title), ZIndex = 23, Parent = frame }), 11)
	local line = UI.label({ Position = UDim2.fromOffset(58, 27), Size = width + UDim2.fromOffset(0, height - 30), Font = UI.HAND, TextSize = 17, TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, Text = detail, ZIndex = 23, Parent = frame })
	UI.fit(line, 11)
	return frame, line
end

-- The figure on the right of a station: a big number and a small unit.
local function figure(frame: Frame, big: string, small: string, color: Color3?)
	UI.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 6), Size = UDim2.fromOffset(110, 28), Font = UI.HEAD, TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = color or C.ink, Text = big, ZIndex = 23, Parent = frame })
	UI.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 32), Size = UDim2.fromOffset(130, 18), Font = UI.HAND, TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right, Text = small, ZIndex = 23, Parent = frame })
end

local function context(state)
	local info = WarehouseRules.level(state.warehouse.level)
	local registers = 0
	for _, entry in state.store.layout do
		if entry.item == "Register" then
			registers += 1
		end
	end
	return { warehouseLevel = state.warehouse.level, storeLevel = state.store.level, openTiles = LandRules.openTiles(state.land),
		registers = registers, trucks = info.trucks }
end

-- "1 of 2 Sorters · more at Warehouse Level 8".
local function slotsText(state, typeName: string): string
	local ctx = context(state)
	local have = 0
	for _, worker in state.workers do
		if worker.type == typeName then
			have += 1
		end
	end
	local slots = WorkerRules.slots(typeName, ctx)
	local nextSlot = WorkerRules.nextSlot(typeName, ctx)
	return `{have} of {slots} {Workers.TYPES[typeName].name}s{if nextSlot then ` · more at {nextSlot}` else ""}`
end

------------------------------------------------------------------------
-- Pipeline

local function crewSpeed(state, typeName: string, info): number
	local total = 0
	for _, worker in state.workers do
		if worker.type == typeName then
			total += WorkerRules.speed(worker, { conveyors = info.conveyors })
		end
	end
	return if state.crew.strike then 0 else total
end

local function rate(n: number): string
	return if n >= 10 then tostring(math.floor(n + 0.5)) else string.format("%.1f", n)
end

local function pipelineTab(state)
	local warehouse = state.warehouse
	local info = WarehouseRules.level(warehouse.level)
	local t = now()
	-- what's waiting in the barn for the crew (routed crops), as crates
	local waiting, crates, sizes, count = 0, 0, 0, 0
	for key, units in state.inventory.crops do
		local cropId = BarnRules.parse(key)
		if Crops.ById[cropId] and WarehouseRules.route(warehouse, cropId) then
			waiting += units
			crates += units / CrateRules.size(cropId)
			sizes += CrateRules.size(cropId)
			count += 1
		end
	end
	local avgCrate = if count > 0 then sizes / count else 12
	local stations = {}
	if info.stage == 1 then
		table.insert(stations, { id = "ShedHand", icon = "📦", title = "Bench: wash, pack, load", rate = crewSpeed(state, "ShedHand", info), unit = "crates a minute",
			detail = `{slotsText(state, "ShedHand")} · barn: enough for {math.floor(crates)} crates · rack {#warehouse.dock}/{info.hold}` })
	else
		table.insert(stations, { id = "Sorter", icon = "💦", title = "Wash & Sort", rate = crewSpeed(state, "Sorter", info) / avgCrate, unit = "crates a minute",
			detail = `{slotsText(state, "Sorter")} · {waiting} crops waiting in the barn` })
		table.insert(stations, { id = "Packer", icon = "📦", title = "Pack", rate = crewSpeed(state, "Packer", info), unit = "crates a minute",
			detail = `{slotsText(state, "Packer")} · {#warehouse.sorted} washed batches waiting` })
		table.insert(stations, { id = "Loader", icon = "🛒", title = "Load", rate = crewSpeed(state, "Loader", info), unit = "crates a minute",
			detail = `{slotsText(state, "Loader")} · ❄ Cold Room {#warehouse.dock}/{info.hold}` })
	end
	local drivers = 0
	for _, worker in state.workers do
		if worker.type == "Driver" then
			drivers += 1
		end
	end
	local truckRate = math.min(drivers, info.trucks) * info.truckCrates * 60 / info.roundTrip
	if info.stage > 1 then
		table.insert(stations, { id = "Driver", icon = "🚚", title = "Trucks", rate = if state.crew.strike then 0 else truckRate, unit = "crates a minute",
			detail = `{slotsText(state, "Driver")} · {info.trucks} {Warehouse.TRUCK_NAMES[info.truck]}{if info.trucks > 1 then "s" else ""}, {info.truckCrates} crates each, {info.roundTrip} s trips` })
	end
	-- the bottleneck: the slowest station, once anyone works here (and
	-- there's more than one to compare: at the Packing Shed there's only the bench)
	local anyone, slowest = false, nil
	for _, station in stations do
		anyone = anyone or station.rate > 0
		if not slowest or station.rate < slowest.rate then
			slowest = station
		end
	end
	local farmhands = crewSpeed(state, "Farmhand", info)
	labelRow(0, 46, "➡️", "From the field to the trucks",
		"Crops go through each step below, top to bottom. Your crew does it for you, even while you're away; the slowest step (orange) sets the pace.", C.sky)
	local replant = if state.crew.replant == "cheapest" then "they replant the cheapest seed" elseif state.crew.replant == "none" then "they don't replant"
		else "they replant the same seed"
	local field = labelRow(1, 56, "🧑‍🌾", "Field: harvest", `{slotsText(state, "Farmhand")} · {replant}`, C.green, 140)
	figure(field, rate(farmhands), "crops a minute")
	for i, station in stations do
		local bottleneck = anyone and #stations > 1 and station == slowest
		local frame = labelRow(1 + i, if bottleneck then 78 else 56, station.icon, station.title, station.detail, if bottleneck then ORANGE else C.kraft, 140)
		figure(frame, rate(station.rate), station.unit, if bottleneck then ORANGE else nil)
		if bottleneck then
			local job = Workers.TYPES[station.id].name
			local tip = if station.rate <= 0 then `🐢 Nobody does this yet: hire a {job} (👷 Workers, or the Hiring Hall in town).`
				else `🐢 Slowest step: hire another {job}, or train yours to speed it up.`
			UI.label({ Position = UDim2.fromOffset(58, 54), Size = UDim2.new(1, -210, 0, 20), Font = UI.HAND, TextSize = 16, TextColor3 = Color3.fromRGB(176, 88, 16),
				Text = tip, ZIndex = 23, Parent = frame })
		end
	end
	if not anyone then
		labelRow(20, 50, "👷", "No crew yet", "You wash, pack and load by hand. Workers do it for you, even while you're away: hire them at the Hiring Hall in town or in the Workers window.", C.sky)
	end
	-- the trucks
	local name = Warehouse.TRUCK_NAMES[info.truck]
	for truck = 1, info.trucks do
		local bed = warehouse.beds[truck] or {}
		local run = TruckRules.runOf(warehouse, truck, t)
		local status = if run then (if t < run.arriveAt then `on the road · paid in {UI.formatTime(run.arriveAt - t)}` else `sold · home in {UI.formatTime(run.returnAt - t)}`)
			else `home · {#bed}/{info.truckCrates} crates`
		local frame = labelRow(30 + truck, 56, "🚚", `{name}{if info.trucks > 1 then ` {truck}` else ""}`, status, C.red, 170)
		-- the fill bar
		local bar = make("Frame", { Position = UDim2.new(0, 58, 1, -12), Size = UDim2.new(1, -240, 0, 6), BackgroundColor3 = C.kraft, ZIndex = 23, Parent = frame }, { UI.corner(3) })
		make("Frame", { Size = UDim2.fromScale(math.clamp(#bed / info.truckCrates, 0, 1), 1), BackgroundColor3 = C.green, ZIndex = 24, Parent = bar }, { UI.corner(3) })
		if not run and #bed > 0 then
			local total = TruckRules.quote(bed, function(cropId)
				return MarketPrice.price(cropId, t)
			end, info.premium)
			local _, button = UI.button({ text = `Send · {UI.formatNumber(total)}`, kind = "gold", size = UDim2.fromOffset(156, 40), anchor = Vector2.new(1, 0.5),
				position = UDim2.new(1, -10, 0.5, 0), textSize = 16, zIndex = 23, parent = frame })
			button.Activated:Connect(function()
				send(TruckAction, "Dispatch", tostring(truck))
			end)
		end
	end
	if info.stage > 1 then
		-- the Drivers' rule: every choice on show, the current one green
		local rule = warehouse.driverRule or 0
		local text = if rule <= 0 then "as soon as it's full" else `once it's full and prices are at least {math.floor(rule * 100 + 0.5)}% of normal`
		local frame = labelRow(40, 92, "🧢", "When Drivers send a truck", `Now: {text}. Waiting for good prices earns more, but the Cold Room fills meanwhile.`, C.soil)
		local options = make("Frame", { Position = UDim2.new(0, 58, 1, -42), Size = UDim2.new(1, -68, 0, 36), BackgroundTransparency = 1, ZIndex = 23, Parent = frame },
			{ make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
		for i, choice in DRIVER_RULES do
			local holder, button = UI.button({ text = if choice <= 0 then "When full" else `{math.floor(choice * 100 + 0.5)}%+`,
				kind = if choice == rule then "green" else "cream", size = UDim2.fromOffset(if choice <= 0 then 92 else 62, 34), textSize = 14, zIndex = 24, parent = options })
			holder.LayoutOrder = i
			button.Activated:Connect(function()
				send(WarehouseAction, "DriverRule", tostring(choice))
			end)
		end
	end
end

------------------------------------------------------------------------
-- Routes

local function routesTab(state)
	local warehouse = state.warehouse
	local info = WarehouseRules.level(warehouse.level)
	local crops = {}
	for key, units in state.inventory.crops do
		local cropId = BarnRules.parse(key)
		if Crops.ById[cropId] and units > 0 then
			crops[cropId] = true
		end
	end
	for cropId, count in state.inventory.seeds do
		if count > 0 and Crops.ById[cropId] then
			crops[cropId] = true
		end
	end
	for cropId in warehouse.routes do
		crops[cropId] = true
	end
	local list = {}
	for cropId in crops do
		table.insert(list, cropId)
	end
	table.sort(list, function(a, b)
		local ca, cb = Crops.ById[a], Crops.ById[b]
		if ca.value ~= cb.value then
			return ca.value < cb.value
		end
		return a < b
	end)
	labelRow(0, 50, "🧭", "Where your crew sends each crop",
		if info.splits then "🚚 by truck, 🏪 to your store, or ✋ keep it in the barn for you. − and + split a crop between truck and store." else "🚚 by truck, 🏪 to your store, or ✋ keep it in the barn for you. Splitting a crop comes with Warehouse Level 5.", C.sky)
	for i, cropId in list do
		local crop = Crops.ById[cropId]
		local route = warehouse.routes[cropId]
		local share = if route == "Keep" then nil elseif type(route) == "number" then route else 1
		local detail = if share == nil then "✋ kept in the barn" elseif share >= 1 then "🚚 all by truck" elseif share <= 0 then "🏪 all to your store"
			else `🚚 {math.floor(share * 100 + 0.5)}% · 🏪 {math.floor((1 - share) * 100 + 0.5)}%`
		local frame = labelRow(i, 56, crop.icon or "🌱", crop.name, detail, C.kraft, if info.splits then 360 else 290)
		local choices = { { "🚚 Truck", "Truck", share ~= nil and share >= 1 }, { "🏪 Store", "Store", share ~= nil and share <= 0 }, { "✋ Keep", "Keep", share == nil } }
		for j, choice in choices do
			local _, button = UI.button({ text = choice[1], kind = if choice[3] then "green" else "cream", size = UDim2.fromOffset(84, 38), anchor = Vector2.new(1, 0.5),
				position = UDim2.new(1, -10 - (3 - j) * 90, 0.5, 0), textSize = 15, zIndex = 23, parent = frame })
			button.Activated:Connect(function()
				send(WarehouseAction, "Route", `{cropId}|{choice[2]}`)
			end)
		end
		if info.splits then
			for j, step in { -0.1, 0.1 } do
				local _, button = UI.button({ text = if step < 0 then "−" else "+", kind = "cream", size = UDim2.fromOffset(32, 38), anchor = Vector2.new(1, 0.5),
					position = UDim2.new(1, -286 - (2 - j) * 38, 0.5, 0), textSize = 20, zIndex = 23, parent = frame })
				button.Activated:Connect(function()
					local from = share or 1
					send(WarehouseAction, "Route", `{cropId}|{math.clamp(math.round((from + step) * 10) / 10, 0, 1)}`)
				end)
			end
		end
	end
end

------------------------------------------------------------------------
-- Upgrade

local function blueprintCard(order: number, height: number)
	return make("Frame", {
		Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = BLUEPRINT, LayoutOrder = order, ZIndex = 22, Parent = panel.list,
	}, { UI.corner(4), UI.stroke(Color3.fromRGB(200, 224, 250), 2, 0.2) })
end

local function upgradeTab(state)
	local warehouse = state.warehouse
	local level = warehouse.level
	local white = Color3.fromRGB(236, 244, 255)
	if warehouse.build then
		local to = WarehouseRules.level(warehouse.build.to)
		local card = blueprintCard(1, 70)
		UI.label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 26), Font = UI.HEAD, TextSize = 20, TextColor3 = white,
			Text = `🏗 Building your {to.building.name}: {UI.formatTime(math.ceil(warehouse.build.left))} left`, ZIndex = 23, Parent = card })
		UI.label({ Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -32, 0, 26), Font = UI.HAND, TextSize = 18, TextColor3 = white,
			Text = "The old building keeps working meanwhile. While you're away the builders work a quarter as fast.", ZIndex = 23, Parent = card })
	elseif level >= WarehouseRules.MAX_LEVEL then
		local card = blueprintCard(1, 60)
		UI.label({ Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0), Font = UI.HEAD, TextSize = 20, TextColor3 = white,
			Text = "★ Warehouse Level 20: the top. Three reefers and gold trim.", ZIndex = 23, Parent = card })
	else
		local nextLevel = WarehouseRules.level(level + 1)
		local news = WarehouseRules.news(level + 1)
		local card = blueprintCard(1, 112)
		UI.label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -200, 0, 26), Font = UI.HEAD, TextSize = 21, TextColor3 = white,
			Text = `Warehouse Level {level} → {level + 1}`, ZIndex = 23, Parent = card })
		local enough = state.level >= nextLevel.farmLevel
		UI.label({ Position = UDim2.fromOffset(16, 34), Size = UDim2.new(1, -200, 0, 22), Font = UI.HAND, TextSize = 18,
			TextColor3 = if enough then Color3.fromRGB(170, 240, 160) else Color3.fromRGB(255, 170, 150),
			Text = if enough then `✓ Farm Level {nextLevel.farmLevel}` else `Needs Farm Level {nextLevel.farmLevel} (you're {state.level})`, ZIndex = 23, Parent = card })
		local newsLabel = UI.label({ Position = UDim2.fromOffset(16, 56), Size = UDim2.new(1, -200, 0, 50), Font = UI.HAND, TextSize = 17, TextColor3 = white, TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top, Text = "New: " .. table.concat(news, " · "), ZIndex = 23, Parent = card })
		UI.fit(newsLabel, 11)
		local _, upgrade = UI.button({ text = `Upgrade  {UI.formatNumber(nextLevel.cost)}`, kind = if enough and state.coins >= nextLevel.cost then "gold" else "cream",
			size = UDim2.fromOffset(170, 48), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -14, 0.5, 0), textSize = 18, zIndex = 23, parent = card })
		upgrade.Activated:Connect(function()
			if not enough then
				UI.toast(`Your warehouse's next level needs Farm Level {nextLevel.farmLevel}.`, "Error", 3)
				return
			end
			send(WarehouseAction, "Upgrade")
		end)
	end
	-- the ladder: the next few levels
	for n = level + 2, math.min(WarehouseRules.MAX_LEVEL, level + 5) do
		local info = WarehouseRules.level(n)
		local milestone = info.building.from == n
		labelRow(n, if milestone then 74 else 50, if milestone then "🏭" else "·", `Level {n} · {UI.formatNumber(info.cost)} · Farm Lv {info.farmLevel}`,
			table.concat(WarehouseRules.news(n), " · "), if milestone then C.sky else C.kraft)
	end
end

------------------------------------------------------------------------

local TABS = { Pipeline = pipelineTab, Routes = routesTab, Upgrade = upgradeTab }

local shown = ""
local function render(force: boolean?)
	local state = PlayerState.current
	if not state or not UI.isOpen(panel) then
		return
	end
	local info = WarehouseRules.level(state.warehouse.level)
	local _, wages = WorkerRules.crew(state.workers)
	panel.toolbar.Text = `🏭 {info.building.name} · Level {state.warehouse.level}{if state.crew.strike then "  ·  🪧 your crew is on strike: no coins for wages" elseif wages > 0 then `  ·  wages {rate(wages)} coins a minute` else ""}`
	local signature = HttpService:JSONEncode({ panel.tab, state.warehouse, state.workers, state.crew, state.level, state.coins >= (if state.warehouse.level < WarehouseRules.MAX_LEVEL then WarehouseRules.level(state.warehouse.level + 1).cost else 0),
		state.inventory.crops, math.floor(now() / 5) })
	if signature == shown and not force then
		return
	end
	shown = signature
	UI.clear(panel.list)
	listLayout.Parent = panel.list
	TABS[panel.tab](state)
end

function WarehouseController.open(tab: string?)
	panel.open()
	if tab then
		panel.setTab(tab)
	end
end

function WarehouseController.Start()
	local button = HudController.sideButton("🏭", "Warehouse", 4)
	button.Activated:Connect(panel.toggle)
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
		while true do
			task.wait(1)
			render()
		end
	end)
end

return WarehouseController
