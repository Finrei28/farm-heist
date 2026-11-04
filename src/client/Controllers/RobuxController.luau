-- The 💎 Robux window (docs/GameDesign.md §7; Config/Monetization,
-- Config/Cosmetics, shared/RobuxRules, server MonetizationService):
--   Passes:  VIP and Bigger Barn, with what each gives, Owned once bought;
--   Weather: the four weathers for the whole server, what each does, and
--            the ones in your barn with Start (or why they can't start yet);
--   Boost:   the Growth Boost and how much of it you have left to play;
--   Style:   bat skins and truck paints: Wear the ones you own (the plain
--            ones are free), buy the rest; VIP Gold comes with VIP.
-- Every price is on a green Robux button with the Robux sign. Buying opens
-- Roblox's own purchase prompt. In Studio, items whose id isn't set up yet
-- are granted without a purchase (DevBuy) so the window can be tried.
-- The VIP's [VIP] chat tag is here too (TextChatService).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared.Config.Cosmetics)
local Monetization = require(Shared.Config.Monetization)
local Remotes = require(Shared.Remotes)
local RobuxRules = require(Shared.RobuxRules)
local Weather = require(Shared.Config.Weather)
local WeatherRules = require(Shared.WeatherRules)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)
local HudController = require(script.Parent.HudController)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer
local RobuxAction = Remotes.func("RobuxAction")
local RobuxFunnel = Remotes.event("RobuxFunnel")
local STUDIO = RunService:IsStudio()

local RobuxController = {}

local ROBUX_GREEN = Color3.fromRGB(0, 160, 90)
local MUTED = Color3.fromRGB(105, 85, 62)

local panel = UI.panel("Robux Shop", { tabs = { "Passes", "Weather", "Boost", "Style" },
	tabColors = { C.gold, C.sky, C.green, C.red }, accent = ROBUX_GREEN, toolbar = true, width = 660, height = 470, tabWidth = 100 })
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.list })

-- (why a weather in your barn can't start yet: "it can start when ...")
local WHY = {
	WeatherBusy = "the weather someone bought ends",
	MoonNow = "the Harvest Moon is over",
	MoonSoon = "the Harvest Moon is over (it's nearly here)",
	BetterWeather = "the better weather on now ends",
}

-- The same, naming the weather on now and who bought it ("Sam's
-- Thunderstorm ends").
local function whyNow(why: string, now): string
	local name = Weather.TYPES[now.id] and Weather.TYPES[now.id].name or "weather"
	if why == "WeatherBusy" and now.boughtBy then
		return `{now.boughtBy}'s {name} ends`
	elseif why == "BetterWeather" then
		return `the {name} ends (it's better)`
	end
	return WHY[why]
end

------------------------------------------------------------------------
-- Prices and buying

local prices = {} -- ["pass:id" / "product:id"] = Robux, from Roblox

local function shown(item, isPass: boolean): boolean
	local id = if isPass then item.passId else item.productId
	return id ~= 0 or STUDIO
end

local function priceOf(item, isPass: boolean): number
	local id = if isPass then item.passId else item.productId
	local key = `{if isPass then "pass" else "product"}:{id}`
	if id ~= 0 and prices[key] == nil then
		prices[key] = false -- (asked once)
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id,
				if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product)
			if ok and info and info.PriceInRobux then
				prices[key] = info.PriceInRobux
				panel.refresh()
			end
		end)
	end
	return prices[key] or item.price
end

local function call(action: string, arg: string?, quiet: boolean?)
	task.spawn(function()
		local ok, result = pcall(RobuxAction.InvokeServer, RobuxAction, action, arg)
		if not (ok and result and result.ok) and not quiet and not (result and result.reason == "Cooldown") then
			local why = WHY[result and result.reason]
			UI.toast(if why then `Not yet: it can start when {why}.` else Reasons(result and result.reason) or "Couldn't do that right now.", "Error", 3)
		end
	end)
end

local function buy(item, isPass: boolean)
	local id = if isPass then item.passId else item.productId
	RobuxFunnel:FireServer(`Prompt:{item.id}`)
	if id == 0 then
		call("DevBuy", item.id) -- (Studio: not set up on the Creator Dashboard yet)
	elseif isPass then
		MarketplaceService:PromptGamePassPurchase(player, id)
	else
		MarketplaceService:PromptProductPurchase(player, id)
	end
end

------------------------------------------------------------------------
-- Drawing

local function card(order: number, height: number, accent: Color3?): Frame
	local box = make("Frame", {
		Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = C.cream, LayoutOrder = order, ZIndex = 22, Parent = panel.list,
	}, { UI.corner(4), UI.stroke(C.stitch, 1.5) })
	make("Frame", { Name = "Band", Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = accent or C.gold, BorderSizePixel = 0, ZIndex = 23, Parent = box }, { UI.corner(3) })
	return box
end

-- Icon, name and lines on the left of a card, leaving `right` px.
local function words(box: Frame, icon: string, name: string, lines: { string }, right: number)
	UI.label({ Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(12, 8), Text = icon, TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 23, Parent = box })
	UI.fit(UI.label({ Size = UDim2.new(1, -(70 + right), 0, 24), Position = UDim2.fromOffset(64, 6), Font = UI.HEAD, TextSize = 20,
		Text = name, ZIndex = 23, Parent = box }), 12)
	UI.fit(UI.label({ Size = UDim2.new(1, -(70 + right), 1, -36), Position = UDim2.fromOffset(64, 31), Font = UI.BODY, TextSize = 14,
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = MUTED, Text = table.concat(lines, "\n"), ZIndex = 23, Parent = box }), 10)
end

local function rightButton(box: Frame, text: string, kind: string, y: number?): TextButton
	local _, button = UI.button({ text = text, kind = kind, size = UDim2.fromOffset(130, 42), anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -12, y or 0.5, 0), textSize = 18, zIndex = 23, parent = box })
	return button
end

local function rightTag(box: Frame, text: string, color: Color3, y: number?)
	make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, y or 0.5, 0), Size = UDim2.fromOffset(130, 34),
		BackgroundColor3 = color, Font = UI.HEAD, Text = text, TextSize = 16, TextColor3 = C.cream, ZIndex = 23, Parent = box,
	}, { UI.corner(17), UI.stroke(UI.SEAM, 1.5) })
end

local function buyButton(box: Frame, item, isPass: boolean, y: number?)
	local button = rightButton(box, `{UI.ROBUX} {priceOf(item, isPass)}`, "robux", y)
	button.Activated:Connect(function()
		buy(item, isPass)
	end)
	local id = if isPass then item.passId else item.productId
	if id == 0 then
		UI.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 1, -16), Size = UDim2.fromOffset(160, 14), Font = UI.BODY,
			TextSize = 11, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Right, Text = "Studio: no id yet, free here", ZIndex = 23, Parent = box })
	end
end

local function section(order: number, text: string)
	UI.label({ Size = UDim2.new(1, 0, 0, 26), Font = UI.HAND, TextSize = 22, Text = text, LayoutOrder = order, ZIndex = 22, Parent = panel.list })
end

local function state()
	return PlayerState.current or {}
end

local function vip(): boolean
	return player:GetAttribute("Pass_VIP") == true
end

------------------------------------------------------------------------
-- The tabs

local function passesTab()
	panel.toolbar.Text = "Passes are yours for good. None of them helps you steal or stops a raid."
	for order, pass in Monetization.Passes do
		if not shown(pass, true) then
			continue
		end
		local box = card(order, 104, pass.color)
		local lines = {}
		for _, perk in pass.perks do
			table.insert(lines, `✓ {perk}`)
		end
		words(box, pass.icon, pass.name, lines, 146)
		if player:GetAttribute(`Pass_{pass.id}`) == true then
			rightTag(box, "Owned ✓", C.green)
		else
			buyButton(box, pass, true)
		end
	end
end

local function weatherTab()
	local t = WeatherRules.now()
	local now = WeatherRules.weather(t)
	local kind = Weather.TYPES[now.id]
	local by = if now.boughtBy then ` (from {now.boughtBy})` else ""
	panel.toolbar.Text = `{kind.icon} {kind.name} now{by} · the next Harvest Moon in {UI.formatTime(WeatherRules.nextMoon(t) - t)}`
	local tokens = state().weatherTokens or {}
	local order = 0
	for _, product in Monetization.Products do
		local id = product.grant.weather
		if not id or not shown(product, false) then
			continue
		end
		order += 1
		local have = tokens[id] or 0
		local why = RobuxRules.canStartWeather(id, now, t, WeatherRules.nextMoon(t))
		local box = card(order, if have > 0 or why then 138 else 92, C.sky)
		local top = make("Frame", { Size = UDim2.new(1, 0, 0, 92), BackgroundTransparency = 1, ZIndex = 23, Parent = box })
		words(top, product.icon, product.name, { product.blurb }, 146)
		buyButton(top, product, false)
		if have > 0 or why then
			-- a strip along the card's foot: the ones in your barn (Start, or
			-- why not yet), or, before buying, that it would have to wait
			local strip = make("Frame", { Position = UDim2.new(0, 10, 0, 92), Size = UDim2.new(1, -20, 0, 40), BackgroundColor3 = Color3.fromRGB(226, 240, 250),
				ZIndex = 23, Parent = box }, { UI.corner(4) })
			UI.fit(UI.label({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -160, 1, 0), Font = UI.HAND, TextSize = 19,
				Text = if have == 0 then `Not right now: bought now, it waits in your barn until {whyNow(why, now)}`
					elseif why then `{product.icon} {have} in your barn: it can start when {whyNow(why, now)}`
					else `{product.icon} {have} in your barn, ready to start`,
				ZIndex = 24, Parent = strip }), 12)
			if have > 0 and not why then
				local _, start = UI.button({ text = "Start now", kind = "green", size = UDim2.fromOffset(130, 34), anchor = Vector2.new(1, 0.5),
					position = UDim2.new(1, -4, 0.5, 0), textSize = 17, zIndex = 24, parent = strip })
				start.Activated:Connect(function()
					call("StartWeather", id)
				end)
			end
		end
	end
end

-- The Growth Boost's time left, counted down here between the server's
-- updates (it only ticks while you play, and you're playing).
local boostSeen = { left = -1, at = 0 }
local function boostLeft(): number
	local left = state().boostLeft or 0
	if left ~= boostSeen.left then
		boostSeen.left, boostSeen.at = left, os.clock()
	end
	return math.max(0, left - (os.clock() - boostSeen.at))
end

local function boostTab()
	local left = boostLeft()
	panel.toolbar.Text = if left > 0 then `🚀 Growth Boost on: {UI.formatTime(left)} of play left` else "Only your own field grows faster. Its time waits while you're away."
	for order, product in Monetization.Products do
		if product.grant.boostSeconds and shown(product, false) then
			local box = card(order, 92, C.green)
			words(box, product.icon, product.name, { product.blurb }, 146)
			buyButton(box, product, false)
		end
	end
end

local function styleTab()
	panel.toolbar.Text = "Looks only: every bat bonks the same, every truck drives the same."
	local data = state()
	local order = 0
	for _, kind in Cosmetics.KINDS do
		order += 1
		section(order, kind.name)
		local worn = RobuxRules.worn(data, kind.id, vip())
		order += 1
		local plain = card(order, 72, C.soil)
		words(plain, kind.noneIcon, kind.none, { kind.noneBlurb }, 146)
		if worn == nil then
			rightTag(plain, "Wearing", C.green)
		else
			rightButton(plain, "Wear", "green").Activated:Connect(function()
				call("Equip", `{kind.id}|`)
			end)
		end
		for _, item in Cosmetics.LIST do
			if item.kind ~= kind.id then
				continue
			end
			local product = Monetization.ProductsById[`Cosmetic_{item.id}`]
			if product and not shown(product, false) then
				continue
			end
			order += 1
			local box = card(order, 72, if item.vip then C.gold else C.red)
			words(box, item.icon, item.name, { item.blurb }, 146)
			if worn == item.id then
				rightTag(box, "Wearing", C.green)
			elseif RobuxRules.owns(data, item.id, vip()) then
				rightButton(box, "Wear", "green").Activated:Connect(function()
					call("Equip", `{kind.id}|{item.id}`)
				end)
			elseif item.vip then
				rightButton(box, "⭐ Get VIP", "gold").Activated:Connect(function()
					panel.setTab("Passes")
				end)
			elseif product then
				buyButton(box, product, false)
			end
		end
	end
end

local TABS = { Passes = passesTab, Weather = weatherTab, Boost = boostTab, Style = styleTab }

function panel.refresh()
	if not UI.isOpen(panel) then
		return
	end
	local scroll = panel.list.CanvasPosition
	UI.clear(panel.list)
	TABS[panel.tab]()
	panel.list.CanvasPosition = scroll
end

------------------------------------------------------------------------

function RobuxController.Start()
	panel.onOpen = function()
		RobuxFunnel:FireServer("Opened")
		panel.refresh()
	end
	panel.onTab(function(name)
		if UI.isOpen(panel) then
			RobuxFunnel:FireServer(`Tab:{name}`)
			panel.list.CanvasPosition = Vector2.zero
			panel.refresh()
		end
	end)
	PlayerState.observe(panel.refresh)
	for _, pass in Monetization.Passes do
		player:GetAttributeChangedSignal(`Pass_{pass.id}`):Connect(panel.refresh)
	end
	local button = HudController.topButton("💎", "Robux", 1)
	button.Activated:Connect(panel.toggle)
	-- the weather's and the boost's clocks tick while the window is open
	task.spawn(function()
		while true do
			task.wait(1)
			if UI.isOpen(panel) and (panel.tab == "Weather" or panel.tab == "Boost") then
				panel.refresh()
			end
		end
	end)

	-- [VIP] in gold before a VIP's name in chat
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local speaker = source and Players:GetPlayerByUserId(source.UserId)
		if speaker and speaker:GetAttribute("Pass_VIP") == true then
			props.PrefixText = `<font color="#F2B33D">[VIP]</font> {message.PrefixText}`
		end
		return props
	end
end

return RobuxController
