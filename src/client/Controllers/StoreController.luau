-- The Store window (docs/GameDesign.md §4.8, §5.3): a shop counter with
-- price tags, from the side bar. The header has your store's name (Rename
-- changes it), its rating and why, and the big Decorate stamp.
--   Prices:  each crop out, in the stockroom or priced: what shoppers
--            expect today, what the truck pays now, your price on a tag
--            with − and +, the demand face and about how many sell a
--            minute (shared/DemandModel, the same sums the shoppers use)
--   Stock:   Fill all (in your store), the stockroom, and each display's
--            slots: what's on them and what each is kept to (Auto or a crop)
--   Upgrade: the next Store Level on blueprint paper, and the ladder
-- It also lets you, and only you, through your store's staff door.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared.Config.Crops)
local DemandModel = require(Shared.DemandModel)
local MarketPrice = require(Shared.MarketPrice)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local Shop = require(Shared.Config.Shop)
local Store = require(Shared.Config.Store)
local ShopRules = require(Shared.ShopRules)
local StoreLayout = require(Shared.StoreLayout)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)
local HudController = require(script.Parent.HudController)
local DecorateController = require(script.Parent.DecorateController)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer
local StoreAction = Remotes.func("StoreAction")

local StoreController = {}

local BLUEPRINT = Color3.fromRGB(44, 84, 132)
local HEADER = 74

local panel = UI.panel("Your Store", { tabs = { "Prices", "Stock", "Upgrade" }, tabColors = { C.gold, C.green, C.sky }, accent = C.green, width = 660, height = 470 })
local listLayout = make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.list })

-- The header: name, rating, why; the Decorate stamp on the right.
local header = make("Frame", {
	Name = "Header", Position = UDim2.fromOffset(18, panel.top), Size = UDim2.new(1, -36, 0, HEADER - 6),
	BackgroundColor3 = C.cream, ZIndex = 22, Parent = panel.frame,
}, { UI.corner(4), UI.stroke(UI.SEAM, 2) })
panel.list.Position = UDim2.fromOffset(14, panel.top + HEADER)
panel.list.Size = UDim2.new(1, -28, 1, -(panel.top + HEADER + 14))
local nameLabel = UI.label({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -205, 0, 26), Font = UI.HEAD, TextSize = 21, Text = "", ZIndex = 23, Parent = header })
UI.fit(nameLabel, 12)
local nameBox = make("TextBox", {
	Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -250, 0, 28), BackgroundColor3 = C.white, Font = UI.HEAD, TextSize = 19,
	TextColor3 = C.ink, PlaceholderText = "Your store's name", ClearTextOnFocus = false, Text = "", Visible = false, ZIndex = 24, Parent = header,
}, { UI.corner(4), UI.stroke(C.soil, 2) })
local renameHolder, renameButton = UI.button({ text = "Rename", kind = "cream", size = UDim2.fromOffset(76, 30), anchor = Vector2.new(1, 0),
	position = UDim2.new(1, -112, 0, 3), textSize = 18, zIndex = 23, parent = header })
local ratingLabel = UI.label({ Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -120, 0, 32), Font = UI.HAND, TextSize = 18, TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top, Text = "", ZIndex = 23, Parent = header })
UI.fit(ratingLabel, 12)
local _, decorateStamp = UI.stamp({ text = "DECORATE", kind = "blue", diameter = 86, anchor = Vector2.new(1, 0.5),
	position = UDim2.new(1, 8, 0.5, 0), textSize = 14, zIndex = 24, parent = header })

local function now(): number
	return workspace:GetServerTimeNow()
end

local function send(action: string, arg: string?, onDone: ((any) -> ())?)
	task.spawn(function()
		local result = StoreAction:InvokeServer(action, arg)
		if not result.ok then
			local text = Reasons(result.reason)
			if text then
				UI.toast(text, "Error", 3)
			end
		elseif onDone then
			onDone(result.result)
		end
	end)
end

local function stars(value: number): string
	local whole = math.floor(value + 0.5)
	return string.rep("★", whole) .. string.rep("☆", 5 - whole)
end

local function myPlot(): number?
	return player:GetAttribute("Plot")
end

local function inMyStore(): boolean
	local plot = myPlot()
	return plot ~= nil and (player:GetAttribute("InStore") or 0) == plot
end

-- A crate-label row, like the Barn's: colour band, icon, stencilled name,
-- a handwritten line (the left half when the row has buttons).
local function labelRow(order: number, height: number, icon: string, title: string, detail: string, color: Color3?, wide: boolean?)
	local frame = make("Frame", {
		Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = C.cream, LayoutOrder = order, ZIndex = 22, Parent = panel.list,
	}, { UI.corner(3), UI.stroke(UI.SEAM, 2) })
	make("Frame", { Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = color or C.soil, BorderSizePixel = 0, ZIndex = 23, Parent = frame })
	UI.label({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0, 40, 0, math.min(height, 56)), Font = UI.HEAD, Text = icon, TextSize = 28, ZIndex = 23, Parent = frame })
	local width = if wide then UDim2.new(1, -70, 0, 0) else UDim2.new(0.5, -60, 0, 0)
	UI.fit(UI.label({ Position = UDim2.fromOffset(58, 5), Size = width + UDim2.fromOffset(0, 22), Font = UI.HEAD, TextSize = 17, Text = string.upper(title), ZIndex = 23, Parent = frame }), 11)
	UI.label({ Position = UDim2.fromOffset(58, 27), Size = width + UDim2.fromOffset(0, height - 30), Font = UI.HAND, TextSize = 17, TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, Text = detail, ZIndex = 23, Parent = frame })
	return frame
end

------------------------------------------------------------------------
-- The header

-- Why the rating is what it is, in one line.
local function why(store): string
	local gaveUp, nothing = 0, 0
	for _, score in store.rating.scores do
		if score == Shop.SCORE_LEFT_QUEUE then
			gaveUp += 1
		elseif score == Shop.SCORE_TOO_DEAR then
			nothing += 1
		end
	end
	if gaveUp >= 3 then
		local onlyRegisters = true
		for _, id in StoreLayout.ofKind(store.layout, "Checkout") do
			if not Store.ITEMS[store.layout[id].item].staffed then
				onlyRegisters = false
			end
		end
		if onlyRegisters then
			return `{gaveUp} shoppers gave up in the queue: stand behind your Register, or add an Honour Box`
		elseif #StoreLayout.ofKind(store.layout, "Checkout") < StoreLayout.level(store.level).checkouts then
			return `{gaveUp} shoppers gave up in the queue: open another checkout (Decorate)`
		end
		return `{gaveUp} shoppers gave up in the queue: more checkouts come with Store Levels`
	end
	if nothing >= 5 then
		return `{nothing} found nothing they'd pay: lower a price, or keep displays full`
	end
	if StoreLayout.charm(store.layout) < Store.CHARM_STEP then
		return "Decorate: every 10 Charm adds 0.1★"
	end
	return "Shoppers like it here!"
end

local function drawHeader(state)
	local store = state.store
	local building = StoreLayout.level(store.level).building
	nameLabel.Text = store.name or `{player.DisplayName}'s {building.name}`
	local value = ShopRules.stars(store)
	local charm = StoreLayout.charm(store.layout)
	ratingLabel.Text = `{stars(value)} {string.format("%.1f", value)} · Charm {math.floor(charm)} (+{string.format("%.1f", StoreLayout.charmStars(store.layout))}★) · Level {store.level}\n{why(store)}`
end

renameButton.Activated:Connect(function()
	if nameBox.Visible then
		return
	end
	nameBox.Text = (PlayerState.current and PlayerState.current.store.name) or ""
	nameBox.Visible = true
	nameLabel.Visible = false
	renameHolder.Visible = false
	nameBox:CaptureFocus()
end)
nameBox.FocusLost:Connect(function(enterPressed)
	nameBox.Visible = false
	nameLabel.Visible = true
	renameHolder.Visible = true
	if enterPressed then
		send("Name", string.sub(nameBox.Text, 1, 60), function(name)
			UI.toast(if name then `Your store is now "{name}".` else "Back to your store's usual name.", "Good", 3)
		end)
	end
end)

------------------------------------------------------------------------
-- Prices

local function pricesTab(state)
	local store = state.store
	local t = now()
	local starsNow = ShopRules.stars(store)
	local onDisplay, inStock = ShopRules.onDisplay(store), ShopRules.stockroomUnits(store)
	local crops = {}
	for cropId in onDisplay do
		crops[cropId] = true
	end
	for cropId in inStock do
		crops[cropId] = true
	end
	for cropId in store.prices do -- (sold out, but you may want to change its price before filling again)
		if Crops.ById[cropId] then
			crops[cropId] = true
		end
	end
	local list = {}
	for cropId in crops do
		table.insert(list, cropId)
	end
	table.sort(list)
	if #list == 0 then
		labelRow(1, 60, "🏪", "Nothing to sell yet", "At the Packing Shed bench, pick 🏪 Store for a crate: it comes to your stockroom. Then Fill a display.", C.kraft, true)
	end
	-- (shoppers a minute, and how many slots are stocked: each shopper picks
	-- crops by their slots, so a crop's share is its slots of all of them)
	local shoppers = 60 / ShopRules.interval(store)
	local slots = 0
	for _, entry in onDisplay do
		slots += entry.slots
	end
	local wants = StoreLayout.level(store.level).wants
	local averageWants = (wants[1] + wants[2]) / 2
	for i, cropId in list do
		local crop = Crops.ById[cropId]
		local market = MarketPrice.price(cropId, t)
		local ref = ShopRules.reference(cropId, market)
		local price = store.prices[cropId] or math.floor(ref + 0.5)
		-- the displays it's on: their presentation, on average
		local present, count = 0, 0
		for _, id in StoreLayout.ofKind(store.layout, "Display") do
			for _, slot in store.layout[id].slots do
				if slot.crop == cropId and slot.units > 0 then
					present += Store.ITEMS[store.layout[id].item].present
					count += 1
				end
			end
		end
		local chance = DemandModel.buyChance(price, ref, starsNow, false, if count > 0 then present / count else 1)
		local share = if slots > 0 and onDisplay[cropId] then math.min(1, onDisplay[cropId].slots / slots * averageWants) else 0
		local perMinute = DemandModel.salesPerMinute(chance, shoppers, share)
		local out = if onDisplay[cropId] then onDisplay[cropId].units else 0
		local frame = labelRow(i, 74, crop.icon or "🌱", crop.name,
			`Shoppers expect ~{math.floor(ref + 0.5)} · truck pays {market} now\n{out} out on display · {inStock[cropId] or 0} in the stockroom`,
			Rarities.ById[crop.rarity].color)
		local low, high = DemandModel.priceRange(ref)
		local step = math.max(1, math.floor(ref * 0.05 + 0.5))
		local _, minus = UI.button({ text = "−", kind = "cream", size = UDim2.fromOffset(34, 36), anchor = Vector2.new(1, 0), position = UDim2.new(1, -228, 0, 8), textSize = 22, zIndex = 23, parent = frame })
		UI.tag({ text = tostring(price), coin = true, color = C.gold, size = UDim2.fromOffset(98, 32), anchor = Vector2.new(1, 0), position = UDim2.new(1, -124, 0, 10), zIndex = 23, parent = frame })
		local _, plus = UI.button({ text = "+", kind = "cream", size = UDim2.fromOffset(34, 36), anchor = Vector2.new(1, 0), position = UDim2.new(1, -84, 0, 8), textSize = 22, zIndex = 23, parent = frame })
		UI.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 4), Size = UDim2.fromOffset(66, 40), Font = UI.HEAD, TextSize = 30,
			TextXAlignment = Enum.TextXAlignment.Center, Text = DemandModel.face(chance), ZIndex = 23, Parent = frame })
		UI.fit(UI.label({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -4), Size = UDim2.fromOffset(250, 22), Font = UI.HAND, TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Right, Text = `{math.floor(chance * 100 + 0.5)}% buy · ~{string.format("%.1f", perMinute)} a minute`, ZIndex = 23, Parent = frame }), 11)
		minus.Activated:Connect(function()
			send("Price", `{cropId}|{math.max(low, price - step)}`)
		end)
		plus.Activated:Connect(function()
			send("Price", `{cropId}|{math.min(high, price + step)}`)
		end)
	end
	-- crops in the barn your displays can't hold yet
	local missing = {}
	for key, units in state.inventory.crops do
		local cropId = string.match(key, "^(%w+)")
		local crop = cropId and Crops.ById[cropId]
		if crop and units > 0 and not missing[crop.rarity] then
			local holds = false
			for itemId, def in Store.ITEMS do
				if def.kind == "Display" and def.level <= store.level and StoreLayout.holds(itemId, crop.rarity) then
					holds = true
				end
			end
			if not holds then
				missing[crop.rarity] = true
			end
		end
	end
	local order = #list + 1
	for _, rarity in { "Epic", "Legendary", "Mythic" } do
		if missing[rarity] then
			local needs = if rarity == "Epic" then "a Chiller Cabinet (Store Level 8)" else "a Glass Showcase (Store Level 10)"
			labelRow(order, 56, "🧊", `{rarity} crops`, `They need {needs}: sell them by truck until then.`, Rarities.ById[rarity].color, true)
			order += 1
		end
	end
	labelRow(order, 66, "💡", "Truck or store?",
		"When the market's down (▼), shoppers still expect the usual price: your store pays better. When it's up, send the truck.", C.gold, true)
end

------------------------------------------------------------------------
-- Stock

-- What a slot can be kept to, in order: Auto, then crops this display can
-- hold that are in the stockroom or on it now.
local function slotChoices(store, entry, slot): { string }
	local choices = { "Auto" }
	local seen = {}
	local function add(cropId)
		if cropId and not seen[cropId] and ShopRules.canHold(entry.item, cropId) then
			seen[cropId] = true
			table.insert(choices, cropId)
		end
	end
	add(slot.set)
	add(slot.crop)
	local waiting = {}
	for cropId in ShopRules.stockroomUnits(store) do
		table.insert(waiting, cropId)
	end
	table.sort(waiting)
	for _, cropId in waiting do
		add(cropId)
	end
	return choices
end

local function stockTab(state)
	local store = state.store
	local order = 1
	-- Fill all
	local fillRow = labelRow(order, 56, "🧺", "Fill your displays",
		if inMyStore() then "Tops up every display from the stockroom." else "Walk into your store to Fill all, or hold E at a display.", C.green)
	local _, fillButton = UI.button({ text = "Fill all", kind = if inMyStore() then "green" else "cream", size = UDim2.fromOffset(120, 40),
		anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -10, 0.5, 2), textSize = 18, zIndex = 23, parent = fillRow })
	fillButton.Activated:Connect(function()
		if not inMyStore() then
			UI.toast("Walk into your store first.", "Error", 3)
			return
		end
		send("Fill", "all")
	end)
	order += 1
	-- the stockroom
	local units = ShopRules.stockroomUnits(store)
	local ids = {}
	for cropId in units do
		table.insert(ids, cropId)
	end
	table.sort(ids)
	local lines = {}
	for _, cropId in ids do
		local crop = Crops.ById[cropId]
		table.insert(lines, `{crop.icon or ""} {crop.name} ×{units[cropId]}`)
	end
	labelRow(order, 70, "📦", `Stockroom: {#store.stockroom} / {ShopRules.stockroomSize(store)} crates`,
		if #lines > 0 then table.concat(lines, "   ") else "Empty: send crates here from the Packing Shed bench (🏪 Store).", C.soil, true)
	order += 1
	-- each display
	for _, id in StoreLayout.ofKind(store.layout, "Display") do
		local entry = store.layout[id]
		local def = Store.ITEMS[entry.item]
		local low, high = StoreLayout.rarityRange(entry.item)
		local frame = labelRow(order, 30 + #entry.slots * 34, "🧺", def.name, `{low}–{high} · ×{string.format("%.2f", def.present)}`, C.gold)
		for n, slot in entry.slots do
			local crop = slot.crop and Crops.ById[slot.crop]
			local y = 26 + (n - 1) * 34
			UI.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -150, 0, y + 4), Size = UDim2.fromOffset(170, 26), Font = UI.HEAD, TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = if crop and slot.units > 0 then `{crop.icon or ""} {slot.units}/{def.units}` .. (if slot.a > 0 then ` ({slot.a} A)` else "")
					elseif crop then `{crop.icon or ""} empty` else "empty",
				ZIndex = 23, Parent = frame })
			local set = slot.set and Crops.ById[slot.set]
			local _, cycle = UI.button({ text = if set then `{set.icon or ""} {set.name}` else "Auto", kind = if set then "gold" else "cream",
				size = UDim2.fromOffset(132, 30), anchor = Vector2.new(1, 0), position = UDim2.new(1, -10, 0, y), textSize = 14, zIndex = 23, parent = frame })
			cycle.Activated:Connect(function()
				local choices = slotChoices(store, entry, slot)
				local at = table.find(choices, slot.set or "Auto") or 1
				local nextChoice = choices[at % #choices + 1]
				send("SetSlot", `{id}|{n}|{nextChoice}`)
			end)
		end
		order += 1
	end
	if #StoreLayout.ofKind(store.layout, "Display") == 0 then
		labelRow(order, 56, "🪑", "No displays", "Press Decorate and put out a Produce Crate or a Wooden Shelf.", C.kraft, true)
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
	local store = state.store
	local level = store.level
	local white = Color3.fromRGB(236, 244, 255)
	if store.build then
		local to = StoreLayout.level(store.build.to)
		local card = blueprintCard(1, 70)
		UI.label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 26), Font = UI.HEAD, TextSize = 20, TextColor3 = white,
			Text = `🏗 Building your {to.building.name}: {UI.formatTime(math.ceil(store.build.left))} left`, ZIndex = 23, Parent = card })
		UI.label({ Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -32, 0, 26), Font = UI.HAND, TextSize = 18, TextColor3 = white,
			Text = "Your store stays open meanwhile. While you're away the builders work a quarter as fast.", ZIndex = 23, Parent = card })
	elseif level >= #Store.LEVELS then
		local card = blueprintCard(1, 60)
		UI.label({ Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0), Font = UI.HEAD, TextSize = 20, TextColor3 = white,
			Text = "★ Store Level 20: the top. Your store is the pride of Cloverdale.", ZIndex = 23, Parent = card })
	else
		local nextLevel = StoreLayout.level(level + 1)
		local news = StoreLayout.news(level + 1)
		local card = blueprintCard(1, 112)
		UI.label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -200, 0, 26), Font = UI.HEAD, TextSize = 21, TextColor3 = white,
			Text = `Store Level {level} → {level + 1}`, ZIndex = 23, Parent = card })
		local enough = state.level >= nextLevel.farmLevel
		UI.label({ Position = UDim2.fromOffset(16, 34), Size = UDim2.new(1, -200, 0, 22), Font = UI.HAND, TextSize = 18,
			TextColor3 = if enough then Color3.fromRGB(170, 240, 160) else Color3.fromRGB(255, 170, 150),
			Text = if enough then `✓ Farm Level {nextLevel.farmLevel}` else `Needs Farm Level {nextLevel.farmLevel} (you're {state.level})`, ZIndex = 23, Parent = card })
		UI.label({ Position = UDim2.fromOffset(16, 56), Size = UDim2.new(1, -200, 0, 50), Font = UI.HAND, TextSize = 17, TextColor3 = white, TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top, Text = "New: " .. table.concat(news, " · "), ZIndex = 23, Parent = card })
		local _, upgrade = UI.button({ text = `Upgrade  {UI.formatNumber(nextLevel.cost)}`, kind = if enough and state.coins >= nextLevel.cost then "gold" else "cream",
			size = UDim2.fromOffset(170, 48), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -14, 0.5, 0), textSize = 18, zIndex = 23, parent = card })
		upgrade.Activated:Connect(function()
			if not enough then
				UI.toast(`Your store's next level needs Farm Level {nextLevel.farmLevel}.`, "Error", 3)
				return
			end
			send("Upgrade")
		end)
	end
	-- the ladder: the next few levels
	for n = level + 2, math.min(#Store.LEVELS, level + 5) do
		local info = StoreLayout.level(n)
		local milestone = info.building.from == n
		labelRow(n, 50, if milestone then "🏬" else "·", `Level {n} · {UI.formatNumber(info.cost)} · Farm Lv {info.farmLevel}`,
			table.concat(StoreLayout.news(n), " · "), if milestone then C.sky else C.kraft, true)
	end
end

------------------------------------------------------------------------

local TABS = { Prices = pricesTab, Stock = stockTab, Upgrade = upgradeTab }

local shown = ""
local function render(force: boolean?)
	local state = PlayerState.current
	if not state or not UI.isOpen(panel) then
		return
	end
	drawHeader(state)
	-- (the market moves the reference price: redraw each minute too)
	local signature = HttpService:JSONEncode({ panel.tab, state.store, state.level, state.coins, inMyStore(), math.floor(now() / 60),
		if state.store.build then math.ceil(state.store.build.left / 5) else 0 })
	if signature == shown and not force then
		return
	end
	shown = signature
	UI.clear(panel.list)
	listLayout.Parent = panel.list
	TABS[panel.tab](state)
end

-- Opens the window (on a tab).
function StoreController.open(tab: string?)
	panel.open()
	if tab then
		panel.setTab(tab)
	end
end

-- Lets you (only you) through your store's staff door: the blocker in it
-- stops everyone, but your own screen moves your character, so it lets go
-- of it here (StoreService swings the door open for everyone to see).
local function watchStaffDoor()
	local watched = nil
	local function letThrough(part: Instance)
		if part.Name == "StaffDoorBlocker" and part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	local function watch()
		local plot = myPlot()
		local model = plot and workspace:WaitForChild("World"):FindFirstChild(`Plot{plot}`)
		local store = model and model:WaitForChild("Store", 10)
		if not store or store == watched then
			return
		end
		watched = store
		store.DescendantAdded:Connect(letThrough)
		for _, part in store:GetDescendants() do
			letThrough(part)
		end
	end
	player:GetAttributeChangedSignal("Plot"):Connect(watch)
	task.spawn(watch)
end

function StoreController.Start()
	local button = HudController.sideButton("🏪", "Store", 2)
	button.Activated:Connect(panel.toggle)
	panel.onOpen = function()
		render(true)
	end
	panel.onTab(function()
		render(true)
	end)
	decorateStamp.Activated:Connect(function()
		DecorateController.enter()
	end)
	PlayerState.changed:Connect(function()
		render()
	end)
	player:GetAttributeChangedSignal("InStore"):Connect(function()
		render()
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			render()
		end
	end)
	watchStaffDoor()
end

return StoreController
