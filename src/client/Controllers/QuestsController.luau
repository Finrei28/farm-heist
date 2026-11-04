-- The Quests window (docs/GameDesign.md §4.15, §4.16; shared/QuestRules,
-- server QuestService), from the side bar's Quests crate:
--   Today:   the login streak (7 days, today's ticked, what tomorrow brings),
--            today's three quests as pinned notes (what to do, a progress
--            bar with the numbers, the coins, Claim), the bonus for all three,
--            and when new ones come;
--   Cropdex: every crop, plain and with each mutation (a coloured dot each,
--            filled once found), by rarity with what finding them all pays,
--            and the mutation sets (a badge each).
-- A green ! on the crate while a quest or the bonus is waiting to be claimed.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared.Config.Crops)
local QuestRules = require(Shared.QuestRules)
local Quests = require(Shared.Config.Quests)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local Weather = require(Shared.Config.Weather)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)
local HudController = require(script.Parent.HudController)

local C = UI.C
local make = UI.make
local QuestAction = Remotes.func("QuestAction")

local QuestsController = {}

local panel = UI.panel("Quests", { tabs = { "Today", "Cropdex" }, tabColors = { C.green, C.gold }, accent = C.green,
	toolbar = true, width = 640, height = 470, tabWidth = 104 })
local listLayout = make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.list })

local function send(action: string, arg: string?)
	task.spawn(function()
		local result = QuestAction:InvokeServer(action, arg)
		if result.ok then
			UI.float(`+{UI.formatNumber(result.result.coins)} 🪙`, UDim2.fromScale(0.5, 0.45), C.gold)
		else
			local text = Reasons(result.reason)
			if text then
				UI.toast(text, "Error", 2.5)
			end
		end
	end)
end

-- A cream note on the kraft list.
local function note(order: number, height: number, color: Color3?): Frame
	return make("Frame", {
		Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = color or C.cream, LayoutOrder = order, ZIndex = 22, Parent = panel.list,
	}, { UI.corner(4), UI.stroke(C.stitch, 1.5) })
end

local function label(parent: Instance, props)
	props.Parent = parent
	props.ZIndex = 23
	return UI.fit(UI.label(props), 10)
end

-- "5 h 12 min" until the next UTC midnight.
local function untilTomorrow(): string
	local t = os.time()
	return UI.formatTime(86400 - t % 86400)
end

------------------------------------------------------------------------
-- Today

local function rewardText(reward): string
	if reward.decor then
		return "🎁"
	elseif reward.seeds then
		return "🌱"
	end
	return "💰" -- (🪙 is too new for Roblox's emoji)
end

local function streakCard(state, order: number)
	local box = note(order, 92, Color3.fromRGB(255, 236, 196))
	local streak = state.streak
	local today = QuestRules.day(os.time())
	local days = if streak.lastClaimDay == today or streak.lastClaimDay == today - 1 then streak.days else 0
	label(box, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 24), Font = UI.HEAD, TextSize = 18,
		Text = if days > 0 then `🔥 Day {days} of {#Quests.STREAK} in a row` else "🔥 Join every day for a streak" })
	for i, reward in Quests.STREAK do
		local got = i <= days
		local cell = make("Frame", {
			Position = UDim2.new((i - 1) / #Quests.STREAK, 12 - (i - 1) * 24 / #Quests.STREAK, 0, 34), Size = UDim2.new(1 / #Quests.STREAK, -6, 0, 48),
			BackgroundColor3 = if got then C.green else C.cream, ZIndex = 23, Parent = box,
		}, { UI.corner(6), UI.stroke(C.soil, 1.5) })
		make("TextLabel", { Size = UDim2.new(1, 0, 0.45, 0), BackgroundTransparency = 1, Font = UI.HEAD, TextSize = 13, ZIndex = 24,
			TextColor3 = if got then C.cream else C.ink, Text = `Day {i}`, Parent = cell })
		make("TextLabel", { Position = UDim2.fromScale(0, 0.4), Size = UDim2.new(1, 0, 0.6, 0), BackgroundTransparency = 1, Font = UI.HEAD, TextSize = 20,
			ZIndex = 24, Text = if got then "✓" else rewardText(reward), TextColor3 = if got then C.cream else C.ink, Parent = cell })
	end
end

local function questCard(state, quest, index: number)
	local done = QuestRules.done(quest)
	local box = note(index + 1, 78)
	make("Frame", { -- the tack
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = if quest.claimed then C.green elseif done then C.gold else C.red, ZIndex = 24, Parent = box,
	}, { UI.corner(6), UI.stroke(C.soilDark, 1.5) })
	label(box, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -170, 0, 26), Font = UI.HAND, TextSize = 22,
		Text = `{if quest.claimed then "✅" elseif done then "⭐" else "📋"} {QuestRules.text(quest)}` })
	local bar = make("Frame", { Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -170, 0, 18), BackgroundColor3 = C.kraft, ZIndex = 23, Parent = box },
		{ UI.corner(9), UI.stroke(C.soil, 1.5) })
	make("Frame", { Size = UDim2.fromScale(math.clamp(quest.progress / quest.n, 0, 1), 1), BackgroundColor3 = if done then C.gold else C.green, ZIndex = 24, Parent = bar },
		{ UI.corner(9) })
	label(bar, { Size = UDim2.fromScale(1, 1), Font = UI.HEAD, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center,
		Text = `{UI.formatNumber(quest.progress)} / {UI.formatNumber(quest.n)}` }).ZIndex = 25
	local holder, button = UI.button({
		text = if quest.claimed then "✓ Claimed" elseif done then `CLAIM {UI.formatShort(quest.reward)}` else `💰 {UI.formatShort(quest.reward)}`,
		kind = if quest.claimed then "cream" elseif done then "green" else "cream", size = UDim2.fromOffset(140, 46),
		anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -12, 0.5, 2), textSize = 16, zIndex = 23, parent = box,
	})
	holder.Name = "Claim"
	button.Activated:Connect(function()
		if done and not quest.claimed then
			send("Claim", tostring(index))
		elseif not done then
			UI.toast(`Not done yet: {QuestRules.text(quest)} ({quest.progress} of {quest.n}).`, nil, 2.5)
		end
	end)
end

local function bonusCard(state, order: number)
	local all = #state.quests.list > 0
	for _, quest in state.quests.list do
		all = all and quest.claimed
	end
	local _, scale = QuestRules.tier(state.level)
	local box = note(order, 58, Color3.fromRGB(236, 248, 220))
	label(box, { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -170, 1, -12), Font = UI.HAND, TextSize = 19, TextWrapped = true,
		Text = if state.quests.bonusClaimed then `🎉 All three done today! New quests in {untilTomorrow()}.`
			else `🎉 Do all three for a bonus of {UI.formatNumber(Quests.BONUS * scale)} coins. New quests in {untilTomorrow()}.` })
	if not state.quests.bonusClaimed then
		local _, button = UI.button({ text = "BONUS", kind = if all then "gold" else "cream", size = UDim2.fromOffset(140, 42),
			anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -12, 0.5, 2), textSize = 16, zIndex = 23, parent = box })
		button.Activated:Connect(function()
			if all then
				send("Bonus")
			else
				UI.toast("Finish and claim all three quests first!", nil, 2.5)
			end
		end)
	end
end

-- The Farm Guide's card, back if you closed it (or from the start once done).
local function guideCard(state, order: number)
	local guide = state.guide
	if not (guide.hidden or guide.finished) then
		return
	end
	local box = note(order, 52, Color3.fromRGB(240, 232, 214))
	label(box, { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -180, 1, -12), Font = UI.HAND, TextSize = 19, TextWrapped = true,
		Text = if guide.finished then "📋 The Farm Guide: all done. Read it again?" else "📋 The Farm Guide: you closed it. Bring it back?" })
	local _, button = UI.button({ text = if guide.finished then "Read again" else "Show guide", kind = "blue", size = UDim2.fromOffset(150, 40),
		anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -12, 0.5, 2), textSize = 16, zIndex = 23, parent = box })
	button.Activated:Connect(function()
		require(script.Parent.GuideController).show()
		UI.closePanels()
	end)
end

local function todayTab(state)
	streakCard(state, 0)
	for index, quest in state.quests.list do
		questCard(state, quest, index)
	end
	bonusCard(state, 10)
	guideCard(state, 11)
end

------------------------------------------------------------------------
-- Cropdex

local function cropCard(parent: Instance, cropdex, crop, order: number)
	local found = QuestRules.seen(cropdex, crop.id)
	local rarity = Rarities.ById[crop.rarity]
	local box = make("Frame", { BackgroundColor3 = if found then C.cream else Color3.fromRGB(226, 210, 180), LayoutOrder = order, ZIndex = 23, Parent = parent },
		{ UI.corner(5), UI.stroke(rarity.color, 2) })
	make("TextLabel", { Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, Font = UI.HEAD, TextSize = 24,
		Text = crop.icon, TextTransparency = if found then 0 else 0.65, ZIndex = 24, Parent = box })
	local name = make("TextLabel", { Position = UDim2.fromOffset(40, 4), Size = UDim2.new(1, -44, 0, 30), BackgroundTransparency = 1, Font = UI.HEAD,
		TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if found then C.ink else Color3.fromRGB(150, 130, 108), ZIndex = 24,
		Text = if found then crop.name else `{crop.name}\nnot found yet`, Parent = box })
	UI.fit(name, 9)
	-- one dot per mutation: filled in its colour once found
	for i, mutation in Weather.MUTATION_ORDER do
		local got = QuestRules.seen(cropdex, crop.id, mutation)
		make("Frame", {
			Position = UDim2.fromOffset(6 + (i - 1) * 17, 40), Size = UDim2.fromOffset(13, 13),
			BackgroundColor3 = Weather.MUTATIONS[mutation].color, BackgroundTransparency = if got then 0 else 0.85, ZIndex = 24, Parent = box,
		}, { UI.corner(7), UI.stroke(C.soil, 1, if got then 0.2 else 0.6) })
	end
end

local function cropdexTab(state)
	local cropdex = state.cropdex or {}
	local order = 0
	-- the mutations' key and their sets
	local key = note(order, 94, Color3.fromRGB(255, 244, 220))
	label(key, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 22), Font = UI.HAND, TextSize = 18,
		Text = "Each dot is a mutation, filled once you've had that crop with it. Every crop with one mutation is a badge!" })
	for i, mutation in Weather.MUTATION_ORDER do
		local count = 0
		for _, crop in Crops.List do
			if QuestRules.seen(cropdex, crop.id, mutation) then
				count += 1
			end
		end
		local done = cropdex.sets and cropdex.sets[mutation]
		local column, row = (i - 1) % 3, (i - 1) // 3
		local chip = make("Frame", { Position = UDim2.new(column / 3, 12 - column * 8, 0, 30 + row * 30), Size = UDim2.new(1 / 3, -8, 0, 26),
			BackgroundColor3 = if done then C.gold else C.cream, ZIndex = 23, Parent = key }, { UI.corner(13), UI.stroke(C.soil, 1.5) })
		make("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Weather.MUTATIONS[mutation].color, ZIndex = 24, Parent = chip },
			{ UI.corner(7) })
		label(chip, { Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -28, 1, 0), Font = UI.HEAD, TextSize = 13,
			Text = `{if done then "🏅 " else ""}{mutation} {count}/{#Crops.List}` }).ZIndex = 25
	end
	for _, rarityId in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
		order += 1
		local crops = {}
		for _, crop in Crops.List do
			if crop.rarity == rarityId then
				table.insert(crops, crop)
			end
		end
		local found = 0
		for _, crop in crops do
			if QuestRules.seen(cropdex, crop.id) then
				found += 1
			end
		end
		local rows = math.ceil(#crops / 4)
		local section = note(order, 32 + rows * 64, Color3.fromRGB(246, 232, 206))
		local seed = QuestRules.nextSeed(rarityId)
		local done = cropdex.tiers and cropdex.tiers[rarityId]
		label(section, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 24), Font = UI.HEAD, TextSize = 16,
			TextColor3 = Rarities.ById[rarityId].color:Lerp(C.ink, 0.45),
			Text = `{rarityId}: {found} of {#crops}{if done then "  ✓ paid" else `  ·  find them all: +{UI.formatShort(Quests.CROPDEX_TIER[rarityId])}{if seed then ` and a {Crops.ById[seed].name} seed` else ""}`}` })
		local grid = make("Frame", { Position = UDim2.fromOffset(8, 30), Size = UDim2.new(1, -16, 0, rows * 64), BackgroundTransparency = 1, ZIndex = 22, Parent = section },
			{ make("UIGridLayout", { CellSize = UDim2.new(0.25, -6, 0, 58), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
		for i, crop in crops do
			cropCard(grid, cropdex, crop, i)
		end
	end
end

------------------------------------------------------------------------

local TABS = { Today = todayTab, Cropdex = cropdexTab }

local shown = ""
local function render(force: boolean?)
	local state = PlayerState.current
	if not state or not UI.isOpen(panel) then
		return
	end
	if panel.tab == "Cropdex" then
		local found, total = QuestRules.progress(state.cropdex or {})
		panel.toolbar.Text = `📖 Cropdex: {found} of {total} found`
	else
		panel.toolbar.Text = "📋 Today's quests: do them, then claim your coins"
	end
	local signature = HttpService:JSONEncode({ panel.tab, state.quests, state.streak, state.cropdex or {}, state.level, math.floor(os.time() / 60) })
	if signature == shown and not force then
		return
	end
	shown = signature
	UI.clear(panel.list)
	listLayout.Parent = panel.list
	TABS[panel.tab](state)
end

-- A green ! on the crate while there's something to claim.
local function badge(button: GuiObject)
	local holder = make("Frame", {
		Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 6), Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = C.green, Visible = false, ZIndex = 5, Parent = button.Parent,
	}, { UI.corner(13), UI.stroke(UI.SEAM, 2) })
	UI.label({ Size = UDim2.fromScale(1, 1), Font = UI.HEAD, TextSize = 16, Text = "!", TextColor3 = C.cream,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = holder })
	local function update()
		local state = PlayerState.current
		if not state then
			return
		end
		local waiting, all = false, #state.quests.list > 0
		for _, quest in state.quests.list do
			waiting = waiting or (QuestRules.done(quest) and not quest.claimed)
			all = all and quest.claimed
		end
		holder.Visible = waiting or (all and not state.quests.bonusClaimed)
	end
	PlayerState.changed:Connect(update)
	update()
end

function QuestsController.Start()
	local button = HudController.sideButton("📋", "Quests", 7)
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
	task.spawn(function()
		while true do
			task.wait(5)
			render()
		end
	end)
end

return QuestsController
