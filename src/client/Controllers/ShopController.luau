-- The Shop window (docs/GameDesign.md §4.8, §5.3): your Farm Stand, from the
-- side bar.
--   Prices:  each crop on the shelves or in the stockroom: what shoppers
--            expect today, what the truck pays now, your price on a tag
--            with − and +, the demand face and about how many sell a
--            minute (shared/DemandModel, the same sums the shoppers use)
--   Shelves: the rating and why, each shelf (take it down), the stockroom
--            and how to stock the shelves (at the stand's counter)
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
local ShopRules = require(Shared.ShopRules)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)
local HudController = require(script.Parent.HudController)

local C = UI.C
local make = UI.make
local ShopAction = Remotes.func("ShopAction")

local ShopController = {}

local panel = UI.panel("Farm Stand", { tabs = { "Prices", "Shelves" }, tabColors = { C.gold, C.green }, accent = C.green, toolbar = true, width = 620, height = 430 })
local listLayout = make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.list })

local function now(): number
	return workspace:GetServerTimeNow()
end

local function send(action: string, arg: string)
	task.spawn(function()
		local result = ShopAction:InvokeServer(action, arg)
		if not result.ok then
			local text = Reasons(result.reason)
			if text then
				UI.toast(text, "Error", 3)
			end
		end
	end)
end

local function stars(value: number): string
	local whole = math.floor(value + 0.5)
	return string.rep("★", whole) .. string.rep("☆", 5 - whole)
end

-- A crate label row like the Barn's: colour band, icon, stencilled name,
-- a handwritten line. Rows with buttons on the right keep their text to the
-- left half; a note (wide) uses the whole row.
local function labelRow(order: number, height: number, icon: string, title: string, detail: string, color: Color3?, wide: boolean?)
	local frame = make("Frame", {
		Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = C.cream, LayoutOrder = order, ZIndex = 22, Parent = panel.list,
	}, { UI.corner(3), UI.stroke(UI.SEAM, 2) })
	make("Frame", { Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = color or C.soil, BorderSizePixel = 0, ZIndex = 23, Parent = frame })
	UI.label({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0, 40, 1, 0), Font = UI.HEAD, Text = icon, TextSize = 28, ZIndex = 23, Parent = frame })
	local width = if wide then UDim2.new(1, -70, 0, 0) else UDim2.new(0.5, -60, 0, 0)
	UI.fit(UI.label({ Position = UDim2.fromOffset(58, 5), Size = width + UDim2.fromOffset(0, 22), Font = UI.HEAD, TextSize = 17, Text = string.upper(title), ZIndex = 23, Parent = frame }), 11)
	UI.label({ Position = UDim2.fromOffset(58, 27), Size = width + UDim2.fromOffset(0, height - 30), Font = UI.HAND, TextSize = 17, TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, Text = detail, ZIndex = 23, Parent = frame })
	return frame
end

------------------------------------------------------------------------
-- Prices

local function pricesTab(state)
	local shop = state.shop
	local t = now()
	local starsNow = ShopRules.stars(shop)
	local crops = {}
	local onShelves, inStock = {}, ShopRules.stockroomUnits(shop)
	for _, shelf in shop.shelves do
		onShelves[shelf.crop] = (onShelves[shelf.crop] or 0) + shelf.units
	end
	for cropId in onShelves do
		crops[cropId] = true
	end
	for cropId in inStock do
		crops[cropId] = true
	end
	for cropId in shop.prices do -- (sold out, but you may want to change its price before restocking)
		if Crops.ById[cropId] then
			crops[cropId] = true
		end
	end
	local list = {}
	for cropId in crops do
		table.insert(list, cropId)
	end
	table.sort(list)
	panel.toolbar.Text = `{stars(starsNow)} {string.format("%.1f", starsNow)}  ·  a shopper every ~{math.floor(ShopRules.interval(shop) + 0.5)} s`
	if #list == 0 then
		labelRow(1, 60, "🏪", "Nothing to sell yet", "At the Packing Shed bench, pick 🏪 Stand for a crate: it comes to the stockroom here.", C.kraft, true)
		return
	end
	local stocked = #ShopRules.stocked(shop)
	for i, cropId in list do
		local crop = Crops.ById[cropId]
		local market = MarketPrice.price(cropId, t)
		local ref = ShopRules.reference(cropId, market)
		local price = shop.prices[cropId] or math.floor(ref + 0.5)
		local chance = DemandModel.buyChance(price, ref, starsNow)
		-- (a shopper picks a shelf: this crop's share is its shelves out of those stocked)
		local shelves = ShopRules.shelvesOf(shop, cropId)
		local share = if shelves > 0 then stocked / shelves else stocked + 1
		local perMinute = DemandModel.salesPerMinute(chance, shop.tier, starsNow, share)
		local frame = labelRow(i, 74, crop.icon or "🌱", crop.name,
			`Shoppers expect ~{math.floor(ref + 0.5)} · truck pays {market} now\n{onShelves[cropId] or 0} on the shelves · {inStock[cropId] or 0} in the stockroom`,
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
	labelRow(#list + 1, 66, "💡", "Truck or stand?",
		"When the market's down (▼), shoppers still expect the usual price: your stand pays better. When it's up, send the truck.", C.gold, true)
end

------------------------------------------------------------------------
-- Shelves

local function shelvesTab(state)
	local shop = state.shop
	local scores = shop.rating.scores
	local bought, dear = 0, 0
	for _, score in scores do
		if score == Shop.SCORE_BOUGHT then
			bought += 1
		else
			dear += 1
		end
	end
	local value = ShopRules.stars(shop)
	panel.toolbar.Text = `{stars(value)} {string.format("%.1f", value)}  ·  last {#scores} shoppers: {bought} bought, {dear} found it too dear`
	local tier = ShopRules.tier(shop)
	for i = 1, tier.shelves do
		local key = tostring(i)
		local shelf = shop.shelves[key]
		if shelf then
			local crop = Crops.ById[shelf.crop]
			local gradeA = if shelf.a > 0 then ` ({shelf.a} grade A)` else ""
			local frame = labelRow(i, 56, crop.icon or "🌱", `Shelf {i}: {crop.name}`,
				`{shelf.units} / {tier.shelfUnits}{gradeA} · price {shop.prices[shelf.crop] or "?"}`,
				Rarities.ById[crop.rarity].color)
			local _, takeDown = UI.button({ text = "Take down", kind = "cream", size = UDim2.fromOffset(110, 38), anchor = Vector2.new(1, 0.5),
				position = UDim2.new(1, -10, 0.5, 2), textSize = 16, zIndex = 23, parent = frame })
			takeDown.Activated:Connect(function()
				send("TakeDown", key)
			end)
		else
			labelRow(i, 56, "🧺", `Shelf {i}: empty`, "Stock the shelves at your stand's counter.", C.kraft, true)
		end
	end
	local units = ShopRules.stockroomUnits(shop)
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
	labelRow(tier.shelves + 1, 76, "📦", "Stockroom",
		(if #lines > 0 then table.concat(lines, "   ") else "Empty: send crates here from the Packing Shed (🏪 Stand).")
			.. "\nStand behind your Farm Stand's counter and hold E (Stock shelves).", C.soil, true)
end

------------------------------------------------------------------------

local TABS = { Prices = pricesTab, Shelves = shelvesTab }

local shown = ""
local function render(force: boolean?)
	local state = PlayerState.current
	if not state or not UI.isOpen(panel) then
		return
	end
	-- (the market moves the reference price: redraw each minute too)
	local signature = HttpService:JSONEncode({ panel.tab, state.shop, math.floor(now() / 60) })
	if signature == shown and not force then
		return
	end
	shown = signature
	UI.clear(panel.list)
	listLayout.Parent = panel.list
	TABS[panel.tab](state)
end

function ShopController.Start()
	local button = HudController.sideButton("🏪", "Stand", 2)
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
			task.wait(5)
			render()
		end
	end)
end

return ShopController
