-- The Workers window (docs/GameDesign.md §4.9, §5.3), from the side bar or
-- the Hiring Hall's job board in town: a corkboard with two tabs.
--   Crew: an ID badge for each worker: photo, name, job, level and speed
--         ("Lv 4 · 60%"), the XP bar, the trait, the wage, Train when the
--         bar is full, and Let go; your wages a minute and the Farmhands'
--         replanting at the top.
--   Hire: today's board, 3 candidates for each job with a free slot (a new
--         board every 10 minutes); jobs with no slot say what opens one.
-- And the Welcome back card: what the farm and the crew did while you
-- were away (WorkerService).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LandRules = require(Shared.LandRules)
local Remotes = require(Shared.Remotes)
local WarehouseRules = require(Shared.WarehouseRules)
local WorkerRules = require(Shared.WorkerRules)
local Workers = require(Shared.Config.Workers)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)
local WorkerLooks = require(script.Parent.Parent.WorkerLooks)
local HudController = require(script.Parent.HudController)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer
local WorkerAction = Remotes.func("WorkerAction")

local WorkersController = {}

local CORK = Color3.fromRGB(196, 150, 96)
local REPLANT = { same = "the same seed", cheapest = "the cheapest seed", none = "nothing (just harvest)" }
local REPLANT_ORDER = { "same", "cheapest", "none" }

local panel = UI.panel("Workers", { tabs = { "Crew", "Hire" }, tabColors = { C.gold, C.green }, accent = C.gold, toolbar = true, width = 660, height = 470 })
panel.list.BackgroundTransparency = 0
panel.list.BackgroundColor3 = CORK
local listLayout = make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.list })

local function now(): number
	return workspace:GetServerTimeNow()
end

local function send(action: string, arg: string?)
	task.spawn(function()
		local result = WorkerAction:InvokeServer(action, arg)
		if not result.ok then
			local text = Reasons(result.reason)
			if text then
				UI.toast(text, "Error", 3)
			end
		end
	end)
end

local function context(state)
	local registers = 0
	for _, entry in state.store.layout do
		if entry.item == "Register" then
			registers += 1
		end
	end
	return { warehouseLevel = state.warehouse.level, storeLevel = state.store.level, openTiles = LandRules.openTiles(state.land),
		registers = registers, trucks = WarehouseRules.level(state.warehouse.level).trucks }
end

local function pct(level: number): string
	return `{math.floor(WorkerRules.efficiency(level) * 100 + 0.5)}% speed`
end

local function wageText(wage: number): string
	return string.format("%.1f coins/min", wage)
end

-- A pinned card on the corkboard (a cream card with the job's colour band).
local function card(parent: Instance, order: number, size: UDim2, color: Color3)
	local frame = make("Frame", { Size = size, BackgroundColor3 = C.cream, LayoutOrder = order, Rotation = ((order * 37) % 5 - 2) * 0.3, ZIndex = 22, Parent = parent },
		{ UI.corner(4), UI.stroke(UI.SEAM, 2) })
	make("Frame", { Name = "Band", Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 23, Parent = frame }, { UI.corner(4) })
	make("Frame", { -- the pin
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = C.red, ZIndex = 25, Parent = frame,
	}, { UI.corner(5), UI.stroke(UI.SEAM, 1) })
	return frame
end

-- The badge's photo: the job's picture in its colour.
local function photo(parent: Instance, typeName: string, size: number, x: number, y: number)
	local holder = make("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size), BackgroundColor3 = WorkerLooks.color(typeName), ZIndex = 23, Parent = parent },
		{ UI.corner(size / 2), UI.stroke(UI.SEAM, 2) })
	UI.label({ Size = UDim2.fromScale(1, 1), Font = UI.HEAD, TextSize = math.floor(size * 0.55), Text = WorkerLooks.TYPES[typeName].icon, ZIndex = 24, Parent = holder })
end

------------------------------------------------------------------------
-- Crew

local confirmFire = nil -- the uid waiting for a second tap on Let go

local function crewTab(state)
	local list = {}
	for uid, worker in state.workers do
		table.insert(list, { uid = uid, worker = worker })
	end
	table.sort(list, function(a, b)
		local ia, ib = table.find(Workers.ORDER, a.worker.type) or 99, table.find(Workers.ORDER, b.worker.type) or 99
		if ia ~= ib then
			return ia < ib
		end
		return (tonumber(a.uid) or 0) < (tonumber(b.uid) or 0)
	end)
	-- the Farmhands' replanting: every choice on show, the current one green
	local top = card(panel.list, 0, UDim2.new(1, 0, 0, 54), C.green)
	UI.fit(UI.label({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -350, 0, 22), Font = UI.HEAD, TextSize = 16, Text = "AFTER A HARVEST, FARMHANDS PLANT", ZIndex = 23, Parent = top }), 10)
	UI.fit(UI.label({ Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -350, 0, 20), Font = UI.HAND, TextSize = 16, Text = `{REPLANT[state.crew.replant] or "the same seed"} (from your seed bag)`, ZIndex = 23, Parent = top }), 10)
	for i, choice in REPLANT_ORDER do
		local _, button = UI.button({ text = if choice == "same" then "Same seed" elseif choice == "cheapest" then "Cheapest" else "Nothing",
			kind = if state.crew.replant == choice then "green" else "cream", size = UDim2.fromOffset(104, 36), anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -10 - (3 - i) * 110, 0.5, 2), textSize = 15, zIndex = 23, parent = top })
		button.Activated:Connect(function()
			send("Replant", choice)
		end)
	end
	if #list == 0 then
		local empty = card(panel.list, 1, UDim2.new(1, 0, 0, 80), C.sky)
		UI.label({ Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 1, -20), Font = UI.HAND, TextSize = 19, TextWrapped = true, ZIndex = 23, Parent = empty,
			Text = if state.freeHireUsed then "No crew yet. Workers harvest, pack, load and sell for you, even while you're away. Hire them on the Hire tab or at the Hiring Hall in town."
				else "No crew yet. Your first hire is free! Try a Shed Hand: they wash, pack and load crates at the Packing Shed for you (Hire tab)." })
		return
	end
	for i, entry in list do
		local worker, uid = entry.worker, entry.uid
		local kind = Workers.TYPES[worker.type]
		local badge = card(panel.list, i, UDim2.new(1, 0, 0, 92), WorkerLooks.color(worker.type))
		photo(badge, worker.type, 58, 12, 16)
		UI.fit(UI.label({ Position = UDim2.fromOffset(82, 12), Size = UDim2.new(1, -330, 0, 24), Font = UI.HEAD, TextSize = 20, Text = worker.name or kind.name, ZIndex = 23, Parent = badge }), 12)
		local trait = worker.trait and Workers.TRAITS[worker.trait]
		UI.fit(UI.label({ Position = UDim2.fromOffset(82, 36), Size = UDim2.new(1, -330, 0, 20), Font = UI.HAND, TextSize = 17, ZIndex = 23, Parent = badge,
			Text = `{kind.name} · Level {worker.level} · {pct(worker.level)}{if trait then ` · {trait.name}: {trait.text}` else ""} · paid {wageText(WorkerRules.wage(worker))}` }), 11)
		-- the XP bar
		local need = WorkerRules.xpToNext(worker.level)
		local bar = make("Frame", { Position = UDim2.fromOffset(82, 62), Size = UDim2.new(1, -330, 0, 14), BackgroundColor3 = C.kraft, ZIndex = 23, Parent = badge },
			{ UI.corner(4), UI.stroke(UI.SEAM, 1) })
		local ready = WorkerRules.ready(worker)
		if need then
			make("Frame", { Size = UDim2.fromScale(math.clamp((worker.xp or 0) / need, 0, 1), 1), BackgroundColor3 = if ready then C.gold else C.green, ZIndex = 24, Parent = bar }, { UI.corner(4) })
		end
		UI.label({ Size = UDim2.fromScale(1, 1), Font = UI.HEAD, TextSize = 12, ZIndex = 25, Parent = bar,
			Text = if not need then "Top level" elseif ready then "⭐ Ready to train" else `{math.floor(worker.xp or 0)} / {need} XP · learns by working` })
		-- Train and Let go
		local fee = WorkerRules.trainFee(worker)
		if fee then
			local _, train = UI.button({ text = `Train · {UI.formatNumber(fee)}`,
				kind = if ready and state.coins >= fee then "gold" else "cream", size = UDim2.fromOffset(146, 40), anchor = Vector2.new(1, 0),
				position = UDim2.new(1, -96, 0, 22), textSize = 15, zIndex = 23, parent = badge })
			train.Activated:Connect(function()
				if not ready then
					UI.toast(`{worker.name} needs a full XP bar first: they learn by working (10 XP a minute, a quarter of that while you're away).`, "Error", 4)
					return
				end
				send("Train", uid)
			end)
		end
		local firing = confirmFire == uid
		local _, fire = UI.button({ text = if firing then "Sure?" else "Let go", kind = if firing then "red" else "cream", size = UDim2.fromOffset(78, 40),
			anchor = Vector2.new(1, 0), position = UDim2.new(1, -10, 0, 22), textSize = 15, zIndex = 23, parent = badge })
		fire.Activated:Connect(function()
			if confirmFire == uid then
				confirmFire = nil
				send("Fire", uid)
			else
				confirmFire = uid
				panel.refresh()
				task.delay(3, function()
					if confirmFire == uid then
						confirmFire = nil
						panel.refresh()
					end
				end)
			end
		end)
	end
end

------------------------------------------------------------------------
-- Hire

local function hireTab(state)
	local window = WorkerRules.boardWindow(now())
	local ctx = context(state)
	local hired = if state.crew.hired.window == window then state.crew.hired.ids else {}
	local free = not state.freeHireUsed
	local canHire = free or state.level >= 2
	if free then
		local note = card(panel.list, 0, UDim2.new(1, 0, 0, 44), C.gold)
		UI.label({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 1, -12), Font = UI.HEAD, TextSize = 18, Text = "🎉 Your first hire is free!", ZIndex = 23, Parent = note })
	elseif state.level < 2 then
		local note = card(panel.list, 0, UDim2.new(1, 0, 0, 44), C.red)
		UI.label({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 1, -12), Font = UI.HAND, TextSize = 18, Text = "Hiring more workers comes with Farm Level 2.", ZIndex = 23, Parent = note })
	end
	local order = 1
	for _, typeName in Workers.ORDER do
		local kind = Workers.TYPES[typeName]
		local slots = WorkerRules.slots(typeName, ctx)
		local have = 0
		for _, worker in state.workers do
			if worker.type == typeName then
				have += 1
			end
		end
		local nextSlot = WorkerRules.nextSlot(typeName, ctx)
		if slots == 0 and not nextSlot then
			continue -- (a job you're past: Shed Hands once the warehouse is built)
		end
		local header = make("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 22, Parent = panel.list })
		order += 1
		local open = have < slots
		local opens = if nextSlot and string.sub(nextSlot, 1, 2) == "a " then `needs {nextSlot}` else `opens at {nextSlot}`
		local status = if slots == 0 then `🔒 {opens}` elseif not open and nextSlot then `full · more at {nextSlot}` elseif not open then "full"
			else `{have} of {slots} hired`
		UI.fit(UI.label({ Size = UDim2.new(1, -8, 1, 0), Position = UDim2.fromOffset(6, 0), Font = UI.HEAD, TextSize = 18, TextColor3 = C.cream,
			TextStrokeColor3 = UI.SEAM, TextStrokeTransparency = 0.2, ZIndex = 23, Parent = header,
			Text = `{WorkerLooks.TYPES[typeName].icon} {string.upper(kind.name)} · {status}  ·  {kind.job}` }), 11)
		if not open then
			continue
		end
		local row = make("Frame", { Size = UDim2.new(1, 0, 0, 112), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 22, Parent = panel.list },
			{ make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
		order += 1
		for slot, candidate in WorkerRules.candidates(player.UserId, window, typeName) do
			local taken = hired[candidate.id] == true
			local cardFrame = card(row, slot, UDim2.new(1 / 3, -6, 1, -4), WorkerLooks.color(typeName))
			photo(cardFrame, typeName, 36, 8, 12)
			UI.fit(UI.label({ Position = UDim2.fromOffset(50, 10), Size = UDim2.new(1, -56, 0, 20), Font = UI.HEAD, TextSize = 17, Text = candidate.name, ZIndex = 23, Parent = cardFrame }), 11)
			local trait = Workers.TRAITS[candidate.trait]
			UI.fit(UI.label({ Position = UDim2.fromOffset(50, 30), Size = UDim2.new(1, -56, 0, 18), Font = UI.HAND, TextSize = 15, ZIndex = 23, Parent = cardFrame,
				Text = `Level {candidate.level} · {pct(candidate.level)}` }), 10)
			UI.fit(UI.label({ Position = UDim2.fromOffset(8, 50), Size = UDim2.new(1, -16, 0, 18), Font = UI.HAND, TextSize = 15, ZIndex = 23, Parent = cardFrame,
				Text = `{trait.name}: {trait.text} · paid {wageText(WorkerRules.wage(candidate))}` }), 10)
			local _, hire = UI.button({ text = if taken then "Hired ✓" elseif free then "Hire · free" else `Hire · {UI.formatNumber(candidate.fee)}`,
				kind = if taken or not canHire then "cream" elseif free or state.coins >= candidate.fee then "green" else "cream",
				size = UDim2.new(1, -16, 0, 34), anchor = Vector2.new(0.5, 1), position = UDim2.new(0.5, 0, 1, -6), textSize = 15, zIndex = 23, parent = cardFrame })
			hire.Activated:Connect(function()
				if not taken then
					send("Hire", candidate.id)
				end
			end)
		end
	end
end

------------------------------------------------------------------------

local TABS = { Crew = crewTab, Hire = hireTab }

local shown = ""
local function render(force: boolean?)
	local state = PlayerState.current
	if not state or not UI.isOpen(panel) then
		return
	end
	local _, wages = WorkerRules.crew(state.workers)
	local count = 0
	for _ in state.workers do
		count += 1
	end
	panel.toolbar.Text = if panel.tab == "Hire" then `📋 New faces on the board in {UI.formatTime(WorkerRules.boardLeft(math.floor(now())))}`
		elseif state.crew.strike then `🪧 Your crew is on strike: wages are {math.ceil(wages)}/min and you're short`
		else `👷 {count} worker{if count == 1 then "" else "s"} · wages {string.format("%.1f", wages)} coins a minute`
	local signature = HttpService:JSONEncode({ panel.tab, state.workers, state.crew, state.freeHireUsed, state.level, math.floor(state.coins / 50),
		state.warehouse.level, state.store.level, WorkerRules.boardWindow(now()), confirmFire or "" })
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

function WorkersController.open(tab: string?)
	panel.open()
	if tab then
		panel.setTab(tab)
	end
end

------------------------------------------------------------------------
-- The Welcome back card: a letter from the farm, pinned up while you read it.

local letter = make("Frame", {
	Name = "WelcomeBack", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(400, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.cream, Rotation = -1, Visible = false, ZIndex = 35, Parent = UI.screen,
}, { UI.corner(6), UI.stroke(C.stitch, 2), make("UIPadding", { PaddingTop = UDim.new(0, 18), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) }),
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
UI.onLayout(function()
	letter.Size = UDim2.fromOffset(if UI.compact then 360 else 400, 0)
end)

local function line(order: number, text: string, props)
	return UI.fit(UI.label({ Size = UDim2.new(1, 0, 0, props and props.height or 24), Font = props and props.font or UI.HAND, TextSize = props and props.size or 19,
		TextColor3 = props and props.color or C.ink, TextXAlignment = props and props.align or Enum.TextXAlignment.Left, TextWrapped = true,
		Text = text, LayoutOrder = order, ZIndex = 36, Parent = letter }), 11)
end

local function duration(seconds: number): string
	local hours, minutes = seconds // 3600, (seconds % 3600) // 60
	if hours > 0 then
		return `{hours} h {minutes} min`
	end
	return `{math.max(1, minutes)} min`
end

local function showWelcome(notice)
	for _, child in letter:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	line(1, "WELCOME BACK!", { font = UI.HEAD, size = 28, height = 34, align = Enum.TextXAlignment.Center, color = C.red })
	line(2, `You were away {duration(notice.away)}. Your crops kept growing (at a quarter of the speed).`, { height = 46 })
	local net = (notice.truckCoins or 0) + (notice.storeCoins or 0) - (notice.wages or 0)
	if (notice.crew or 0) > 0 then
		line(3, `👷 Your crew worked {duration((notice.minutes or 0) * 60)} at a quarter of the speed:`, { font = UI.BODY_BOLD, size = 17, height = 24 })
		local order = 4
		local function add(text: string, color: Color3?)
			line(order, text, { color = color })
			order += 1
		end
		if (notice.harvested or 0) > 0 then
			add(`🧺 {UI.formatNumber(notice.harvested)} crops harvested`)
		end
		if (notice.crates or 0) > 0 then
			add(`📦 {UI.formatNumber(notice.crates)} crates packed`)
		end
		if (notice.runs or 0) > 0 or (notice.truckCoins or 0) > 0 then
			add(`🚚 {notice.runs} truck{if notice.runs == 1 then "" else "s"} sent · +{UI.formatNumber(notice.truckCoins or 0)}{if (notice.onRoad or 0) > 0 then ` (+{UI.formatNumber(notice.onRoad)} still on the road)` else ""}`)
		end
		if (notice.storeUnits or 0) > 0 then
			add(`🏪 Your store sold {UI.formatNumber(notice.storeUnits)} · +{UI.formatNumber(notice.storeCoins or 0)}`)
		end
		if (notice.wages or 0) > 0 then
			add(`💸 Wages −{UI.formatNumber(notice.wages)}`)
		end
		if (notice.strikeMinutes or 0) > 0 then
			add(`🪧 On strike for {duration(notice.strikeMinutes * 60)}: you ran short of coins for wages`, C.red)
		end
		if notice.ready and #notice.ready > 0 then
			add(`⭐ Ready to train: {table.concat(notice.ready, ", ")}`, Color3.fromRGB(176, 120, 16))
		end
	elseif (notice.truckCoins or 0) > 0 then
		line(4, `🚚 Your truck sold in the City: +{UI.formatNumber(notice.truckCoins)}`)
	else
		line(4, "Workers keep your farm going while you're away: hire them at the Hiring Hall.", { height = 46 })
	end
	if net ~= 0 then
		line(40, `{if net >= 0 then "+" else "−"}{UI.formatNumber(math.abs(net))} coins`, { font = UI.HEAD, size = 24, height = 32, align = Enum.TextXAlignment.Center,
			color = if net >= 0 then C.green else C.red })
	end
	local holder = make("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, LayoutOrder = 50, ZIndex = 36, Parent = letter })
	local _, close = UI.button({ text = "Back to work!", kind = "green", size = UDim2.fromOffset(190, 44), anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.55), textSize = 18, zIndex = 37, parent = holder })
	close.Activated:Connect(function()
		letter.Visible = false
	end)
	letter.Visible = true
	letter.Rotation = -6
	TweenService:Create(letter, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Rotation = -1 }):Play()
end

-- A badge on the side bar's Workers crate: ⭐ someone is ready to train,
-- 🪧 the crew is on strike. (So you notice after the toast has gone.)
local function badge(button: GuiObject)
	local holder = make("Frame", {
		Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 6), Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = C.gold, Visible = false, ZIndex = 5, Parent = button.Parent,
	}, { UI.corner(13), UI.stroke(UI.SEAM, 2) })
	local label = UI.label({ Size = UDim2.fromScale(1, 1), Font = UI.HEAD, TextSize = 15, Text = "", ZIndex = 6, Parent = holder })
	local function update()
		local state = PlayerState.current
		if not state then
			return
		end
		local ready = false
		for _, worker in state.workers do
			ready = ready or WorkerRules.ready(worker)
		end
		holder.Visible = state.crew.strike or ready
		holder.BackgroundColor3 = if state.crew.strike then C.alarm else C.green -- (a gold star shows on green)
		label.Text = if state.crew.strike then "!" else "⭐"
	end
	PlayerState.changed:Connect(update)
	update()
end

function WorkersController.Start()
	local button = HudController.sideButton("👷", "Workers", 5)
	button.Activated:Connect(panel.toggle)
	badge(button)
	panel.onOpen = function()
		render(true)
	end
	panel.onTab(function()
		render(true)
	end)
	PlayerState.changed:Connect(function()
		render()
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Opens") == "HiringHall" then
			WorkersController.open("Hire")
		end
	end)
	Remotes.event("Notify").OnClientEvent:Connect(function(notice)
		if notice.kind == "Welcome" then
			showWelcome(notice)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			render()
		end
	end)
end

return WorkersController
