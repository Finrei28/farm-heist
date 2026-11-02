-- The Defences window (docs/GameDesign.md §4.11, §5.3), from the side bar
-- (🛡️): blueprint paper, three tabs.
--   Defences: your Sprout Shield (time left, Drop it), then a card for each
--             defence: what it does, its price and Farm Level, how many you
--             have out, and Buy · Place · Put away.
--   Trusted:  your Trusted friends (Remove), and the players here you could
--             add, friends first.
--   Camera:   who came into your farm in the last half hour (with the
--             Security Camera).
-- Setting things out: your field from above with a green spot wherever this
-- defence can go (round the field, or open tiles for cloches); tap one to
-- set it there, tap one of yours to put it away; the dog's and the
-- scarecrow's reach drawn on the ground.
-- And two cards: the scarecrow's "Sam is near your crops" (amber), and the
-- Farm Rules card when your Sprout Shield ends.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defences = require(Shared.Config.Defences)
local DefenceRules = require(Shared.DefenceRules)
local LandRules = require(Shared.LandRules)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)
local HudController = require(script.Parent.HudController)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer
local DefenceAction = Remotes.func("DefenceAction")
local TravelAction = Remotes.func("TravelAction")

local DefenceController = {}

local PAPER = Color3.fromRGB(38, 82, 136) -- blueprint
local CARD = Color3.fromRGB(52, 102, 160)
local LINE = Color3.fromRGB(214, 232, 250)
local AMBER = Color3.fromRGB(240, 160, 40)

local panel = UI.panel("Defences", { tabs = { "Defences", "Trusted", "Camera" }, tabColors = { C.sky, C.green, C.gold }, accent = C.sky,
	toolbar = true, width = 660, height = 470, tabWidth = 104 })
panel.list.BackgroundTransparency = 0
panel.list.BackgroundColor3 = PAPER
local listLayout = make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.list })

local function now(): number
	return workspace:GetServerTimeNow()
end

local function myPlot(): number?
	local plot = player:GetAttribute("Plot")
	return if plot and plot > 0 then plot else nil
end

local function send(action: string, arg: string?, done: ((any) -> ())?)
	task.spawn(function()
		local result = DefenceAction:InvokeServer(action, arg)
		if not result.ok then
			local text = Reasons(result.reason)
			if text then
				UI.toast(text, "Error", 3)
			end
		elseif done then
			done(result.result)
		end
		if panel.refresh then
			panel.refresh()
		end
	end)
end

-- A blueprint card: blue paper with a white pencil line round it.
local function card(order: number, height: number, color: Color3?): Frame
	return make("Frame", {
		Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = color or CARD, LayoutOrder = order, ZIndex = 22, Parent = panel.list,
	}, { UI.corner(6), UI.stroke(LINE, 1.5, 0.35) })
end

local function text(parent: Instance, props)
	props.Parent = parent
	props.ZIndex = 23
	props.TextColor3 = props.TextColor3 or LINE
	return UI.fit(UI.label(props), 10)
end

------------------------------------------------------------------------
-- Protection

local function shieldLeft(): (number, string?)
	local t = now()
	local shield = (player:GetAttribute("ShieldUntil") or 0) - t
	local grace = (player:GetAttribute("GraceUntil") or 0) - t
	if shield > 0 then
		return shield, "Shield"
	elseif grace > 0 then
		return grace, "Grace"
	end
	return 0, nil
end

local confirmDrop = false

local function shieldCard(order: number)
	local left, kind = shieldLeft()
	local box = card(order, 64, if kind then Color3.fromRGB(58, 120, 70) else Color3.fromRGB(120, 60, 50))
	local line = if kind == "Shield" then `🌱 Sprout Shield: {UI.formatTime(left)} left. Nobody can steal from you, and you can't steal.`
		elseif kind == "Grace" then `🌱 Just arrived: your farm is protected for {UI.formatTime(left)}, so you can harvest what ripened while you were away.`
		else "🚨 Raids are on: anyone can steal your ripe crops. Bonk thieves with your bat, then arrest them!"
	text(box, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, if kind then -150 else -24, 1, -12), Font = UI.HAND, TextSize = 18, TextWrapped = true, Text = line })
	if kind then
		local _, drop = UI.button({ text = if confirmDrop then "Tap to confirm" else "Drop it now", kind = if confirmDrop then "red" else "cream",
			size = UDim2.fromOffset(126, 40), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -10, 0.5, 0), textSize = 15, zIndex = 23, parent = box })
		drop.Activated:Connect(function()
			if confirmDrop then
				confirmDrop = false
				send("DropShield")
			else
				confirmDrop = true
				panel.refresh()
				task.delay(4, function()
					confirmDrop = false
				end)
			end
		end)
	end
end

------------------------------------------------------------------------
-- Defences

local placeMode -- (below)

local function defencesTab(state)
	shieldCard(0)
	local order = 1
	for _, itemId in Defences.ORDER do
		local def = Defences.ITEMS[itemId]
		local owned = DefenceRules.owned(state.defences, itemId)
		local out = #DefenceRules.spotsOf(state.defences, itemId)
		local locked = state.level < def.level
		local box = card(order, 118)
		order += 1
		local icon = make("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = PAPER, ZIndex = 23, Parent = box },
			{ UI.corner(26), UI.stroke(LINE, 1.5, 0.3) })
		text(icon, { Size = UDim2.fromScale(1, 1), Font = UI.HEAD, TextSize = 30, Text = def.icon, TextXAlignment = Enum.TextXAlignment.Center })
		text(box, { Position = UDim2.fromOffset(72, 8), Size = UDim2.new(1, -230, 0, 24), Font = UI.HEAD, TextSize = 20, Text = def.name, TextColor3 = C.cream })
		text(box, { Position = UDim2.fromOffset(72, 32), Size = UDim2.new(1, -84, 0, 38), Font = UI.HAND, TextSize = 16, TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top, Text = def.blurb })
		text(box, { Position = UDim2.fromOffset(72, 70), Size = UDim2.new(1, -84, 0, 16), Font = UI.BODY, TextSize = 13, Text = def.detail, TextTransparency = 0.25 })
		-- the price tag, or what it needs
		local tag = if locked then `🔒 Farm Level {def.level}` else `🪙 {UI.formatNumber(def.cost)}{if def.max > 1 then " each" else ""}`
		text(box, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(150, 20), Font = UI.HEAD, TextSize = 16,
			Text = tag, TextColor3 = if locked then LINE else C.gold, TextXAlignment = Enum.TextXAlignment.Right })
		-- what you have, and the buttons
		local status = if owned == 0 then "" elseif def.max == 1 then (if out > 0 then "✅ Set out" else "📦 Put away")
			else `✅ {out} of {owned} set out{if owned < def.max then ` · you can have {def.max}` else ""}`
		text(box, { Position = UDim2.fromOffset(12, 90), Size = UDim2.fromOffset(200, 20), Font = UI.HEAD, TextSize = 15, Text = status, TextColor3 = C.cream })
		local buttons = make("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -6), Size = UDim2.fromOffset(330, 34),
			BackgroundTransparency = 1, ZIndex = 23, Parent = box }, { make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
		local function addButton(label: string, kind: string, n: number, fn: () -> ())
			local _, b = UI.button({ text = label, kind = kind, size = UDim2.fromOffset(104, 32), textSize = 15, order = n, zIndex = 24, parent = buttons })
			b.Activated:Connect(fn)
		end
		if owned < def.max and not locked then
			addButton(if owned == 0 then "Buy" else "Buy another", if state.coins >= def.cost then "gold" else "cream", 1, function()
				send("Buy", itemId, function(result)
					UI.toast(if result and result.spot then `{def.icon} {def.name} is up!` else `{def.icon} Bought! Now pick a spot for it.`, "Good")
					if not (result and result.spot) then
						placeMode(itemId)
					end
				end)
			end)
		end
		if owned > 0 then
			if def.spot == "yard" or def.spot == "tile" then
				addButton(if def.max == 1 and out > 0 then "Move" else "Place", "blue", 2, function()
					placeMode(itemId)
				end)
			elseif out > 0 then
				addButton("Put away", "cream", 2, function()
					send("PutAway", def.spot)
				end)
			else
				addButton("Put it up", "blue", 2, function()
					send("Place", `{itemId}|{def.spot}`)
				end)
			end
		end
	end
end

------------------------------------------------------------------------
-- Trusted

local friends = {} -- [userId] = true/false (cached)

local function isFriend(other: Player): boolean
	if friends[other.UserId] == nil then
		friends[other.UserId] = false
		task.spawn(function()
			local ok, yes = pcall(player.IsFriendsWith, player, other.UserId)
			friends[other.UserId] = ok and yes == true
			if ok and yes then
				panel.refresh()
			end
		end)
	end
	return friends[other.UserId]
end

local function trustedTab(state)
	local intro = card(0, 64, Color3.fromRGB(58, 120, 70))
	text(intro, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 1, -12), Font = UI.HAND, TextSize = 17, TextWrapped = true,
		Text = "🤝 Trusted friends walk in through your locked gate and your store's staff door, water and harvest for you (the crops go to your barn), can't steal from you, and your bat can't touch them." })
	local order = 1
	local head = make("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 22, Parent = panel.list })
	text(head, { Size = UDim2.fromScale(1, 1), Font = UI.HEAD, TextSize = 17, TextColor3 = C.cream, Text = `YOUR LIST · {#state.trusted} of {Defences.TRUSTED_MAX}` })
	order += 1
	if #state.trusted == 0 then
		local none = card(order, 34)
		order += 1
		text(none, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), Font = UI.HAND, TextSize = 16, Text = "Nobody yet." })
	end
	for _, entry in state.trusted do
		local row = card(order, 44)
		order += 1
		local here = Players:GetPlayerByUserId(entry.id) ~= nil
		text(row, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -140, 1, 0), Font = UI.HEAD, TextSize = 17, TextColor3 = C.cream,
			Text = `{entry.name}{if here then "  · here now" else ""}` })
		local _, remove = UI.button({ text = "Remove", kind = "cream", size = UDim2.fromOffset(100, 32), anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -8, 0.5, 0), textSize = 15, zIndex = 23, parent = row })
		remove.Activated:Connect(function()
			send("Untrust", tostring(entry.id))
		end)
	end
	-- the players here you could add, friends first
	local others = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and not DefenceRules.isTrusted(state.trusted, other.UserId) then
			table.insert(others, other)
		end
	end
	table.sort(others, function(a, b)
		local fa, fb = isFriend(a), isFriend(b)
		if fa ~= fb then
			return fa
		end
		return a.DisplayName < b.DisplayName
	end)
	local head2 = make("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 22, Parent = panel.list })
	order += 1
	text(head2, { Size = UDim2.fromScale(1, 1), Font = UI.HEAD, TextSize = 17, TextColor3 = C.cream, Text = "PLAYERS HERE" })
	if #others == 0 then
		local none = card(order, 34)
		order += 1
		text(none, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), Font = UI.HAND, TextSize = 16, Text = "Nobody else is in this server." })
	end
	for _, other in others do
		local row = card(order, 44)
		order += 1
		text(row, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -140, 1, 0), Font = UI.HEAD, TextSize = 17, TextColor3 = C.cream,
			Text = `{if isFriend(other) then "⭐ " else ""}{other.DisplayName}{if isFriend(other) then "  · friend" else ""}` })
		local full = #state.trusted >= Defences.TRUSTED_MAX
		local _, add = UI.button({ text = "Trust", kind = if full then "cream" else "green", size = UDim2.fromOffset(100, 32), anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -8, 0.5, 0), textSize = 15, zIndex = 23, parent = row })
		add.Activated:Connect(function()
			send("Trust", tostring(other.UserId), function()
				UI.toast(`🤝 {other.DisplayName} is on your Trusted list.`, "Good")
			end)
		end)
	end
end

------------------------------------------------------------------------
-- Camera

local visitors = nil -- the camera's list, fetched when the tab opens
local function fetchVisitors()
	task.spawn(function()
		local result = DefenceAction:InvokeServer("Visitors")
		visitors = if result.ok then result.result else {}
		panel.refresh()
	end)
end

local function cameraTab(state)
	if not DefenceRules.has(state.defences, "Camera") then
		local box = card(0, 76)
		local def = Defences.ITEMS.Camera
		text(box, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 1, -12), Font = UI.HAND, TextSize = 18, TextWrapped = true,
			Text = `📹 With a Security Camera (Farm Level {def.level}, {UI.formatNumber(def.cost)} coins) the theft alarm shows the thief live, even when you're away, and this page shows who came into your farm.` })
		return
	end
	local head = card(0, 44)
	text(head, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -140, 1, 0), Font = UI.HEAD, TextSize = 17, TextColor3 = C.cream,
		Text = "📹 Who came in (the last 30 min)" })
	local _, refresh = UI.button({ text = "Refresh", kind = "blue", size = UDim2.fromOffset(100, 32), anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -8, 0.5, 0), textSize = 15, zIndex = 23, parent = head })
	refresh.Activated:Connect(fetchVisitors)
	if visitors == nil then
		fetchVisitors()
		return
	end
	if #visitors == 0 then
		local none = card(1, 34)
		text(none, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), Font = UI.HAND, TextSize = 16, Text = "Nobody's been in." })
	end
	for i, visitor in visitors do
		local row = card(i, 40)
		local what = {}
		if visitor.trusted then
			table.insert(what, "🤝 Trusted")
		end
		if visitor.climbed then
			table.insert(what, "🧗 climbed in")
		end
		if visitor.stole then
			table.insert(what, "🧺 stole")
		end
		if visitor.arrested then
			table.insert(what, "🚔 arrested")
		end
		local ago = if visitor.ago < 60 then "just now" else `{visitor.ago // 60} min ago`
		text(row, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.45, -12, 1, 0), Font = UI.HEAD, TextSize = 16, TextColor3 = C.cream, Text = visitor.name })
		text(row, { Position = UDim2.new(0.45, 0, 0, 0), Size = UDim2.new(0.55, -12, 1, 0), Font = UI.HAND, TextSize = 16,
			Text = `{ago}{if #what > 0 then "  ·  " .. table.concat(what, " · ") else ""}` })
	end
end

------------------------------------------------------------------------

local TABS = { Defences = defencesTab, Trusted = trustedTab, Camera = cameraTab }

local shown = ""
local function render(force: boolean?)
	local state = PlayerState.current
	if not state or not UI.isOpen(panel) then
		return
	end
	local _, kind = shieldLeft()
	panel.toolbar.Text = if panel.tab == "Trusted" then `🤝 {#state.trusted} of {Defences.TRUSTED_MAX} Trusted friends`
		elseif panel.tab == "Camera" then "📹 Your camera watches the farm"
		else "🛡️ Defences warn, slow and expose thieves: your bat does the rest."
	local others = {}
	for _, other in Players:GetPlayers() do
		table.insert(others, other.UserId)
	end
	local signature = HttpService:JSONEncode({ panel.tab, state.defences, state.trusted, state.level, math.floor(state.coins / 100), kind or "",
		if kind then math.floor(shieldLeft()) else 0, others, confirmDrop, visitors or false })
	if signature == shown and not force then
		return
	end
	shown = signature
	UI.clear(panel.list)
	listLayout.Parent = panel.list
	TABS[panel.tab](state)
end
panel.refresh = function()
	render(true)
end

------------------------------------------------------------------------
-- Setting things out: your field from above, glowing spots

local placing = nil -- { itemId, markers = { gui }, parts = { part }, bar }
local camera = workspace.CurrentCamera

local bar = make("Frame", {
	Name = "PlaceBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(560, 64),
	BackgroundColor3 = PAPER, Visible = false, ZIndex = 30, Parent = UI.screen,
}, { UI.corner(8), UI.stroke(LINE, 2, 0.2) })
local barText = UI.label({ Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -150, 1, -8), Font = UI.HAND, TextSize = 18, TextWrapped = true,
	TextColor3 = LINE, ZIndex = 31, Text = "", Parent = bar })
local _, doneButton = UI.button({ text = "DONE", kind = "green", size = UDim2.fromOffset(110, 44), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -10, 0.5, 0),
	textSize = 20, zIndex = 31, parent = bar })
UI.onLayout(function()
	bar.Size = UDim2.fromOffset(math.min(560, UI.screen.AbsoluteSize.X - 40), 64)
end)

local function clearPlacing()
	if not placing then
		return
	end
	for _, thing in placing.things do
		thing:Destroy()
	end
	placing.things = {}
end

-- On the ground (`y` up: lines drawn over the field sit above its tiles).
local function ground(frame: CFrame, p: Vector3, y: number?): CFrame
	return frame * CFrame.new(p.X, y or 0.3, p.Z)
end

-- A flat ring of glowing dashes round `centre` (plot space), `radius` studs.
local function ring(frame: CFrame, centre: Vector3, radius: number, color: Color3)
	local segments = 40
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		local p = centre + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		local dash = make("Part", {
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon,
			Color = color, Transparency = 0.25, Size = Vector3.new(0.5, 0.1, radius * math.pi * 2 / segments * 0.6),
			CFrame = ground(frame, p, 1.0) * CFrame.Angles(0, -a, 0), Parent = workspace.CurrentCamera,
		})
		table.insert(placing.things, dash)
	end
end

-- A dashed outline of the field grown by `by` studs (the scarecrow's reach).
local function fieldOutline(frame: CFrame, by: number, color: Color3)
	local field = PlotLayout.PLOT.field
	local side = field.size * field.tile
	local x0, z0, x1, z1 = field.across, field.depth, field.across + side, field.depth + side
	local function dash(p: Vector3, angle: number, length: number)
		local part = make("Part", {
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon,
			Color = color, Transparency = 0.25, Size = Vector3.new(0.5, 0.1, length), CFrame = ground(frame, p, 1.0) * CFrame.Angles(0, angle, 0),
			Parent = workspace.CurrentCamera,
		})
		table.insert(placing.things, part)
	end
	for _, edge in { { x0, z0 - by, x1, z0 - by }, { x0, z1 + by, x1, z1 + by }, { x0 - by, z0, x0 - by, z1 }, { x1 + by, z0, x1 + by, z1 } } do
		local a, b = Vector3.new(edge[1], 0, edge[2]), Vector3.new(edge[3], 0, edge[4])
		local n = math.floor((b - a).Magnitude / 4)
		for i = 0, n - 1 do
			local p = a:Lerp(b, (i + 0.5) / n)
			dash(p, if edge[1] == edge[3] then 0 else math.pi / 2, 2.2)
		end
	end
	for _, corner in { { x0, z0, math.pi }, { x1, z0, math.pi * 1.5 }, { x1, z1, 0 }, { x0, z1, math.pi / 2 } } do
		for i = 1, 6 do
			local a = corner[3] + (i - 0.5) / 6 * math.pi / 2
			local p = Vector3.new(corner[1] + math.cos(a) * by, 0, corner[2] + math.sin(a) * by)
			dash(p, -a, 2.2)
		end
	end
end

local function marker(frame: CFrame, p: Vector3, label: string, color: Color3, onTap: (() -> ())?)
	local anchor = make("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one,
		CFrame = ground(frame, p) + Vector3.new(0, 1, 0), Parent = workspace.CurrentCamera,
	})
	table.insert(placing.things, anchor)
	local gui = make("BillboardGui", { Adornee = anchor, Size = UDim2.fromOffset(46, 46), AlwaysOnTop = true, LightInfluence = 0, Active = true,
		Parent = player.PlayerGui }) -- (Active: without it a billboard's buttons can't be pressed)
	table.insert(placing.things, gui)
	local button = make("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, Font = UI.HEAD, Text = label, TextSize = 24, TextColor3 = C.cream,
		AutoButtonColor = true, Active = onTap ~= nil, Parent = gui,
	}, { UI.corner(23), UI.stroke(C.soilDark, 2) })
	if onTap then
		button.Activated:Connect(onTap)
	end
end

local function drawPlacing()
	local state = PlayerState.current
	local plot = myPlot()
	if not placing or not state or not plot then
		return
	end
	clearPlacing()
	local frame = PlotLayout.frame(plot)
	local itemId = placing.itemId
	local def = Defences.ITEMS[itemId]
	local spare = DefenceRules.spare(state.defences, itemId)
	local out = #DefenceRules.spotsOf(state.defences, itemId)
	local canAdd = spare > 0 or (def.max == 1 and DefenceRules.owned(state.defences, itemId) == 1)
	local function tap(spot: string)
		return function()
			local here = state.defences.placed[spot]
			if here == itemId then
				send("PutAway", spot)
			elseif here == nil then
				send("Place", `{itemId}|{spot}`)
			end
		end
	end
	if def.spot == "yard" then
		for n = 1, PlotLayout.YARD_SPOTS do
			local spot = `yard:{n}`
			local p = PlotLayout.yardSpot(n)
			local here = state.defences.placed[spot]
			if here == itemId then
				marker(frame, p, def.icon, C.red, tap(spot))
			elseif here then
				marker(frame, p, Defences.ITEMS[here].icon, Color3.fromRGB(110, 110, 110), nil)
			elseif canAdd then
				marker(frame, p, "+", C.green, tap(spot))
				local square = make("Part", {
					Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon,
					Color = C.green, Transparency = 0.7, Size = Vector3.new(PlotLayout.YARD_SPOT - 0.6, 0.1, PlotLayout.YARD_SPOT - 0.6),
					CFrame = ground(frame, p), Parent = workspace.CurrentCamera,
				})
				table.insert(placing.things, square)
			end
		end
		-- what it reaches
		if itemId == "GuardDog" then
			for _, spot in DefenceRules.spotsOf(state.defences, itemId) do
				local _, n = DefenceRules.spotKind(spot)
				ring(frame, PlotLayout.yardSpot(n :: number), Defences.DOG_RANGE, C.gold)
			end
		elseif itemId == "Scarecrow" then
			fieldOutline(frame, Defences.SCARECROW_RANGE, C.gold)
		end
	else
		for tile = 1, PlotLayout.PLOT.field.size ^ 2 do
			if LandRules.isTileOpen(state.land, tile) then
				local spot = `tile:{tile}`
				local here = state.defences.placed[spot]
				local p = PlotLayout.tileLocal(tile)
				if here == itemId then
					marker(frame, p, def.icon, C.red, tap(spot))
				elseif canAdd then
					marker(frame, p, "+", C.green, tap(spot))
				end
			end
		end
	end
	local how = if itemId == "GuardDog" then " It guards crops within 30 studs of its kennel (the gold ring)."
		elseif itemId == "Scarecrow" then " It sees anyone inside the gold line."
		elseif itemId == "Cloche" then " Put them over your rarest crops."
		elseif itemId == "MudPatch" then " Thieves run for the back fence: slow them there."
		else ""
	barText.Text = if def.max == 1 and out > 0 then `{def.icon} Your {def.name} is out (red). Tap a green spot to move it there, or the red one to put it away.{how}`
		elseif canAdd then `{def.icon} Tap a green spot to set out your {def.name}.{how}`
		else `{def.icon} All {out} set out. Tap one (red) to put it away, or buy more in Defences.`
end

-- The HUD steps aside while you place (like Decorate); alarm cards that
-- come up meanwhile still show.
local hidden = {}
local KEEP = { Toasts = true, TheftAlarm = true, ScarecrowWarning = true, AlarmArrow = true }
local function setHud(visible: boolean)
	if visible then
		for child in hidden do
			child.Visible = true
		end
		table.clear(hidden)
		return
	end
	for _, child in UI.screen:GetChildren() do
		if child:IsA("GuiObject") and child ~= bar and not KEEP[child.Name] and child.Visible then
			hidden[child] = true
			child.Visible = false
		end
	end
end

local savedCamera = nil
placeMode = function(itemId: string)
	local plot = myPlot()
	if not plot or (player:GetAttribute("InFarm") or 0) ~= plot then
		UI.toast("Go to your own farm first: press 🏠 HOME.", "Error", 3)
		return
	end
	UI.closePanels()
	if placing then
		clearPlacing()
	end
	placing = { itemId = itemId, things = {} }
	if not savedCamera then
		savedCamera = { type = camera.CameraType, fov = camera.FieldOfView, cframe = camera.CFrame }
	end
	local frame = PlotLayout.frame(plot)
	local field = PlotLayout.PLOT.field
	local side = field.size * field.tile
	local middle = frame:PointToWorldSpace(Vector3.new(field.across + side / 2, 0, field.depth + side / 2 + 6))
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 50
	camera.CFrame = CFrame.lookAt(middle - frame.ZVector * 40 + Vector3.new(0, 175, 0), middle)
	setHud(false)
	bar.Visible = true
	drawPlacing()
end

local function leavePlacing()
	if not placing then
		return
	end
	clearPlacing()
	placing = nil
	bar.Visible = false
	setHud(true)
	if savedCamera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = savedCamera.fov
		camera.CFrame = savedCamera.cframe -- (back where you were, not left up in the sky)
		savedCamera = nil
	end
end
doneButton.Activated:Connect(leavePlacing)

------------------------------------------------------------------------
-- Cards: the scarecrow's warning, the Farm Rules

local nearCard = make("Frame", {
	Name = "ScarecrowWarning", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(380, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = C.cream, Visible = false, ZIndex = 35, Parent = UI.screen,
}, { UI.corner(6), UI.stroke(AMBER, 4), make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
local nearTitle = UI.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Font = UI.HEAD, TextSize = 20,
	TextColor3 = Color3.fromRGB(176, 104, 16), TextXAlignment = Enum.TextXAlignment.Center, Text = "", LayoutOrder = 1, ZIndex = 36, Parent = nearCard })
local nearLine = UI.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Font = UI.HAND, TextSize = 19,
	TextXAlignment = Enum.TextXAlignment.Center, Text = "", LayoutOrder = 2, ZIndex = 36, Parent = nearCard })
local nearHome, nearHomeButton = UI.button({ text = "🏠 Go home (3 s)", kind = "blue", size = UDim2.fromOffset(190, 40), order = 3, zIndex = 36, parent = nearCard })
UI.onLayout(function()
	nearCard.Position = UDim2.new(0.5, 0, 0, if UI.compact then 108 else 124)
	nearCard.Size = UDim2.fromOffset(math.min(380, UI.screen.AbsoluteSize.X - 300), 0)
end)
nearHomeButton.Activated:Connect(function()
	local result = TravelAction:InvokeServer("Home")
	if not result.ok then
		local reason = Reasons(result.reason)
		if reason then
			UI.toast(reason, "Error", 2.5)
		end
	else
		nearHome.Visible = false
		nearLine.Text = "Heading home... stand still!"
	end
end)

local nearToken = 0
local function showNear(info)
	local alarm = UI.screen:FindFirstChild("TheftAlarm")
	if alarm and alarm.Visible then
		return -- (the red alarm says more)
	end
	nearToken += 1
	local token = nearToken
	local home = myPlot() ~= nil and (player:GetAttribute("InFarm") or 0) == myPlot()
	nearTitle.Text = `👀 {info.name} is near your crops`
	nearLine.Text = if home then "Your scarecrow saw them. Keep an eye out: if they steal, bonk them!" else "Your scarecrow saw them by your field."
	nearHome.Visible = not home
	nearCard.Visible = true
	task.delay(7, function()
		if nearToken == token then
			nearCard.Visible = false
		end
	end)
end

-- The Farm Rules card: the Sprout Shield is over, here's how raids go,
-- in three pictures that light up one after another.
local function showRules()
	local dim = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.shade, BackgroundTransparency = 0.45, ZIndex = 40, Parent = UI.screen })
	local box = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 330), BackgroundColor3 = C.kraft,
		ZIndex = 41, Parent = dim,
	}, { UI.corner(12), UI.stroke(C.soil, 3) })
	UI.onLayout(function()
		box.Size = UDim2.fromOffset(math.min(560, UI.screen.AbsoluteSize.X - 30), math.min(330, UI.screen.AbsoluteSize.Y - 30))
	end)
	local sign = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(240, 46), ZIndex = 43, Parent = box },
		{ UI.corner(6), UI.stroke(UI.SEAM, 3) })
	UI.wood(sign, 2, false, C.red)
	UI.label({ Size = UDim2.fromScale(1, 1), Font = UI.HEAD, TextSize = 24, Text = "FARM RULES", TextColor3 = C.cream, TextStrokeColor3 = UI.SEAM,
		TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 44, Parent = sign })
	UI.fit(UI.label({ Position = UDim2.fromOffset(20, 34), Size = UDim2.new(1, -40, 0, 26), Font = UI.HAND, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Your Sprout Shield is over: ripe crops can be stolen now, yours and theirs!", ZIndex = 42, Parent = box }), 12)
	local row = make("Frame", { Position = UDim2.fromOffset(16, 70), Size = UDim2.new(1, -32, 1, -152), BackgroundTransparency = 1, ZIndex = 42, Parent = box },
		{ make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
	local steps = {
		{ "🧺🥕", "1. A thief grabs your ripe crops", "Your alarm goes off. Run home!" },
		{ "🏏💫", "2. In your farm you hold a bat", "SWING to bonk them: they drop your crop." },
		{ "🚔🪙", "3. Hold ARREST", "They're fined. Then TAKE BACK your crop!" },
	}
	local panels = {}
	for i, step in steps do
		local cardFrame = make("Frame", { Size = UDim2.new(1 / 3, -8, 1, 0), BackgroundColor3 = C.cream, BackgroundTransparency = 0.5, LayoutOrder = i, ZIndex = 42, Parent = row },
			{ UI.corner(8), UI.stroke(C.soil, 2, 0.5) })
		local picture = UI.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.new(1, 0, 0.45, 0), Font = UI.HEAD, TextScaled = true,
			Text = step[1], TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 0.6, ZIndex = 43, Parent = cardFrame })
		UI.fit(UI.label({ Position = UDim2.new(0, 6, 0.5, 2), Size = UDim2.new(1, -12, 0.22, 0), Font = UI.HEAD, TextSize = 15, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center, Text = step[2], ZIndex = 43, Parent = cardFrame }), 10)
		UI.fit(UI.label({ Position = UDim2.new(0, 6, 0.74, 0), Size = UDim2.new(1, -12, 0.24, 0), Font = UI.HAND, TextSize = 15, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center, Text = step[3], ZIndex = 43, Parent = cardFrame }), 10)
		panels[i] = { frame = cardFrame, picture = picture }
	end
	UI.fit(UI.label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -58), Size = UDim2.new(1, -40, 0, 20), Font = UI.HAND, TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center, Text = "🛡️ Defences warn, slow and show you thieves. 🤝 Trust your friends there too.", ZIndex = 42, Parent = box }), 11)
	local _, ok = UI.button({ text = "Got it!", kind = "green", size = UDim2.fromOffset(160, 44), anchor = Vector2.new(0.5, 1), position = UDim2.new(0.5, 0, 1, -10),
		textSize = 20, zIndex = 43, parent = box })
	ok.Activated:Connect(function()
		dim:Destroy()
	end)
	-- the pictures light up one after another, round and round
	task.spawn(function()
		local i = 0
		while dim.Parent do
			i = i % #panels + 1
			for j, p in panels do
				local lit = j == i
				p.frame.BackgroundTransparency = if lit then 0 else 0.5
				p.picture.TextTransparency = if lit then 0 else 0.6
				if lit then
					p.picture.Rotation = -8
					TweenService:Create(p.picture, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Rotation = 0 }):Play()
				end
			end
			task.wait(2.5)
		end
	end)
end

------------------------------------------------------------------------

function DefenceController.open(tab: string?)
	panel.open()
	if tab then
		panel.setTab(tab)
	end
end

function DefenceController.Start()
	local button = HudController.sideButton("🛡️", "Defend", 6)
	button.Activated:Connect(panel.toggle)
	panel.onOpen = function()
		visitors = nil
		render(true)
	end
	panel.onTab(function(tab)
		if tab == "Camera" then
			visitors = nil
		end
		render(true)
	end)
	PlayerState.changed:Connect(function()
		render()
		if placing then
			drawPlacing()
		end
	end)
	-- (the stamp and the signposts come back by themselves: keep them out of the way)
	-- (just before each frame is drawn, after their own updates)
	game:GetService("RunService"):BindToRenderStep("DefencePlacingHud", Enum.RenderPriority.Last.Value, function()
		if placing then
			setHud(false)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			render()
			-- (walked off your farm while placing: back to playing)
			if placing and (player:GetAttribute("InFarm") or 0) ~= myPlot() then
				leavePlacing()
			end
		end
	end)
	Players.PlayerAdded:Connect(function()
		render()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(render)
	end)
	Remotes.event("DefenceEvent").OnClientEvent:Connect(function(kind, info)
		if kind == "Near" and info then
			showNear(info)
		elseif kind == "ShieldOver" then
			showRules()
		end
	end)
end

return DefenceController
