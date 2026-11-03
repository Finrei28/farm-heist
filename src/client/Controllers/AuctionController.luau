-- The Auction House on your screen (docs/GameDesign.md §4.4, §5.3; the
-- server's AuctionService, the hall in World/AuctionArt). Everything comes
-- from ReplicatedStorage.Auction's attributes:
--   * the lot board on the hall's back wall (a chalkboard: the lot, the top
--     bid and who has it, the clock; between auctions, when the next is),
--     the lot over its pedestal, Goldie Gavel's calls in a speech bubble,
--     the bell swinging when an auction starts and confetti when a lot sells;
--   * the bid card (red velvet in a gold frame, right of the screen) while
--     you're inside the hall during a lot: the lot, its estimate, the top
--     bid, a clock that flashes when a late bid puts it back, +5% / +10% /
--     +25% buttons with what each bids (one Bid button for the opening
--     bid), whether you lead, your coins, and what comes next;
--   * a note a minute before each auction (with a Town button), and one when
--     it starts saying what's up.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auction = require(Shared.Config.Auction)
local AuctionRules = require(Shared.AuctionRules)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local WorkerRules = require(Shared.WorkerRules)
local Workers = require(Shared.Config.Workers)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)
local HudController = require(script.Parent.HudController)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer

local AuctionController = {}

local VELVET = Color3.fromRGB(128, 26, 38)
local GOLD = Color3.fromRGB(240, 186, 64)
local CHALK = C.chalk

local AuctionAction = Remotes.func("AuctionAction")
local board = ReplicatedStorage:WaitForChild("Auction")

local function now(): number -- (the auction clock, with the dev shift: AuctionService)
	return workspace:GetServerTimeNow() + (ReplicatedStorage:GetAttribute("AuctionShift") or 0)
end

-- This auction's lots (decoded once each time they change), and the lot on
-- now with its number (nil, 0 between lots).
local lotsCache, lotsText = {}, nil
local function lots()
	local text = board:GetAttribute("Lots") or "[]"
	if text ~= lotsText then
		local ok, list = pcall(HttpService.JSONDecode, HttpService, text)
		lotsCache, lotsText = if ok then list else {}, text
	end
	return lotsCache
end

local function current()
	local k = board:GetAttribute("Lot") or 0
	return if k > 0 then lots()[k] else nil, k
end

-- A lot as AuctionRules sees it, for the quick bids.
local function ruleLot()
	local bid = board:GetAttribute("Bid") or 0
	return { opening = board:GetAttribute("Opening") or 0, bids = if bid > 0 then { { userId = board:GetAttribute("LeaderId"), amount = bid } } else {} }
end

local function inHall(): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and PlotLayout.insideBuilding("Auction", root.Position, Auction.HALL_MARGIN)
end

------------------------------------------------------------------------
-- The bid card

local card = make("Frame", {
	Name = "AuctionCard", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 10), Size = UDim2.fromOffset(340, 236),
	BackgroundColor3 = VELVET, Visible = false, Parent = UI.screen,
}, { UI.corner(10), UI.stroke(GOLD, 4) })
make("Frame", { -- (the gold frame's inner line)
	Name = "Inner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -14, 1, -14),
	BackgroundTransparency = 1, Parent = card,
}, { UI.corner(7), UI.stroke(Color3.fromRGB(196, 140, 40), 1.5) })
local header = UI.label({
	Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -90, 0, 24), Font = UI.HEAD, TextSize = 18, TextColor3 = GOLD,
	Text = "🔨 LOT 1 OF 3", Parent = card,
})
local clock = make("Frame", { -- the clock: a cream disc with the seconds left
	Name = "Clock", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(54, 54),
	BackgroundColor3 = C.cream, ZIndex = 2, Parent = card,
}, { UI.corner(27), UI.stroke(GOLD, 3) })
local clockStroke = clock:FindFirstChildOfClass("UIStroke")
local clockLabel = UI.label({
	Size = UDim2.fromScale(1, 1), Font = UI.HEAD, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Text = "60",
	ZIndex = 3, Parent = clock,
})
local iconDisc = make("Frame", {
	Position = UDim2.fromOffset(14, 40), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = C.cream, Parent = card,
}, { UI.corner(26), UI.stroke(GOLD, 2) })
local iconLabel = UI.label({ Size = UDim2.fromScale(1, 1), Font = UI.HEAD, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Text = "🌱", Parent = iconDisc })
local nameLabel = UI.label({
	Position = UDim2.fromOffset(76, 38), Size = UDim2.new(1, -150, 0, 26), Font = UI.HEAD, TextSize = 20, TextColor3 = C.cream, Text = "", Parent = card,
})
UI.fit(nameLabel, 12)
local detailLabel = UI.label({
	Position = UDim2.fromOffset(76, 64), Size = UDim2.new(1, -90, 0, 34), Font = UI.HAND, TextSize = 17, TextColor3 = Color3.fromRGB(246, 222, 200),
	TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Text = "", Parent = card,
})
local bidLabel = UI.label({
	Position = UDim2.fromOffset(16, 100), Size = UDim2.new(1, -32, 0, 24), Font = UI.HEAD, TextSize = 18, TextColor3 = GOLD, Text = "", Parent = card,
})
UI.fit(bidLabel, 11)
local estimateLabel = UI.label({
	Position = UDim2.fromOffset(16, 124), Size = UDim2.new(1, -32, 0, 18), Font = UI.HAND, TextSize = 17, TextColor3 = Color3.fromRGB(246, 222, 200), Text = "", Parent = card,
})
local buttons = {}
for i, share in Auction.QUICK do
	local holder, button = UI.button({ text = "", kind = "gold", size = UDim2.fromOffset(98, 46), position = UDim2.fromOffset(16 + (i - 1) * 104, 146),
		textSize = 16, parent = card })
	buttons[i] = { holder = holder, button = button, share = share }
end
local statusLabel = UI.label({
	Position = UDim2.fromOffset(16, 196), Size = UDim2.new(1, -32, 0, 18), Font = UI.HAND, TextSize = 17, TextColor3 = C.cream, Text = "", Parent = card,
})
UI.fit(statusLabel, 11)
local footLabel = UI.label({
	Position = UDim2.fromOffset(16, 214), Size = UDim2.new(1, -32, 0, 16), Font = UI.HAND, TextSize = 15, TextColor3 = Color3.fromRGB(230, 200, 176), Text = "", Parent = card,
})
UI.fit(footLabel, 10)
local cardScale = make("UIScale", { Parent = card })
UI.onLayout(function()
	card.Size = UDim2.fromOffset(340, 236)
	-- (phones: smaller, up in the top right corner; in the middle it hid the
	-- Town signpost and ran under the jump button)
	local phone = UI.compact and UI.touch
	cardScale.Scale = if phone then 0.8 else 1
	card.AnchorPoint = if phone then Vector2.new(1, 0) else Vector2.new(1, 0.5)
	card.Position = if phone then UDim2.new(1, -10, 0, 2) else UDim2.new(1, -16, 0.5, if UI.compact then 0 else 10)
end)

local bidding = false
local function bid(amount: number)
	if bidding then
		return
	end
	bidding = true
	local result = AuctionAction:InvokeServer("Bid", tostring(amount))
	bidding = false
	if result.ok then
		UI.float(`🔨 {UI.formatNumber(amount)}!`, UDim2.new(1, -180, 0.5, -60), GOLD)
	else
		local text = Reasons(result.reason)
		if text then
			UI.toast(text, "Error", 2.5)
		end
	end
end
for _, entry in buttons do
	entry.button.Activated:Connect(function()
		if entry.amount then
			bid(entry.amount)
		end
	end)
end

-- Why you couldn't take this lot home (a defence's Farm Level or room for
-- one more, a free slot for a rare worker's job): what the card says
-- instead of the buttons. nil: you can.
local function blocked(lot): string?
	local state = PlayerState.current
	if not state or lot.kind == "Seed" then
		return nil
	end
	local ok, why = AuctionRules.canWin(lot, { level = state.level, defences = state.defences, workers = state.workers, workerCtx = WorkerRules.context(state) })
	if ok then
		return nil
	elseif lot.kind == "WorkerContract" then
		local job = Workers.TYPES[Workers.CONTRACTS[lot.id].type].name
		return `No free {job} slot in your crew (Workers window: see what opens more).`
	end
	return Reasons(why)
end

local lastSnipe = 0
local flashUntil = 0

local function updateCard()
	local lot, k = current()
	local phase = board:GetAttribute("Phase") or ""
	local show = lot ~= nil and phase ~= "" and inHall()
	card.Visible = show
	if not show then
		return
	end
	local what = AuctionRules.describe(lot)
	local count = #lots()
	header.Text = `🔨 LOT {k} OF {count}`
	iconLabel.Text = what.icon
	nameLabel.Text = what.name
	nameLabel.TextColor3 = if what.color then what.color:Lerp(C.cream, 0.35) else C.cream
	detailLabel.Text = what.detail
	estimateLabel.Text = `Worth about {UI.formatNumber(lot.estimate)}`
	local next = {}
	for i = k + 1, count do
		table.insert(next, AuctionRules.describe(lots()[i]).icon)
	end
	local state = PlayerState.current
	footLabel.Text = `Your coins: {UI.formatShort(state and state.coins or 0)}{if #next > 0 then `  ·  Next: {table.concat(next, " ")}` else "  ·  the last lot"}`

	if phase == "Sold" then
		local to = board:GetAttribute("SoldTo") or ""
		local amount = board:GetAttribute("SoldFor") or 0
		bidLabel.Text = if to ~= "" then `SOLD to {if to == player.DisplayName then "you" else to} for {UI.formatNumber(amount)}!` else "No bids: back to the vault"
		clockLabel.Text = "🔨"
		statusLabel.Text = if k < count then "The next lot is coming up..." else "That's all for this auction: the next one is in 8 minutes."
		for _, entry in buttons do
			entry.holder.Visible = false
		end
		return
	end

	local t = now()
	local left = math.max(0, (board:GetAttribute("EndsAt") or t) - t)
	clockLabel.Text = tostring(math.ceil(left))
	local snipe = board:GetAttribute("Snipe") or 0
	if snipe ~= lastSnipe then
		lastSnipe = snipe
		flashUntil = os.clock() + 1.2
	end
	local flashing = os.clock() < flashUntil and math.floor(os.clock() * 6) % 2 == 0
	clock.BackgroundColor3 = if flashing then C.alarm elseif left <= 10 then Color3.fromRGB(255, 226, 160) else C.cream
	clockStroke.Color = if left <= 10 then C.alarm else GOLD

	local top = board:GetAttribute("Bid") or 0
	local leaderId = board:GetAttribute("LeaderId") or 0
	local leading = top > 0 and leaderId == player.UserId
	bidLabel.Text = if top > 0 then `Top bid: {UI.formatNumber(top)}  ·  {if leading then "you!" else board:GetAttribute("Leader")}`
		else `Opening bid: {UI.formatNumber(board:GetAttribute("Opening") or 0)}  ·  no bids yet`
	local why = blocked(lot)
	local coins = state and state.coins or 0
	local rules = ruleLot()
	for i, entry in buttons do
		local amount = AuctionRules.quickBid(rules, entry.share)
		entry.amount = amount
		-- (before anyone bids, one button bids the opening price)
		entry.holder.Visible = not leading and not why and (top > 0 or i == 1)
		entry.holder.Size = UDim2.fromOffset(if top > 0 then 98 else 200, 46)
		entry.button.Text = if top > 0 then `+{math.floor(entry.share * 100)}%\n{UI.formatShort(amount)}` else `BID {UI.formatNumber(amount)}`
		UI.setButtonKind(entry.holder, if coins >= amount then "gold" else "cream")
	end
	if leading then
		statusLabel.Text = "🎉 You're the top bid! Your coins are held until someone outbids you."
	elseif coins < AuctionRules.quickBid(rules, Auction.QUICK[1]) then
		statusLabel.Text = `You need {UI.formatNumber(AuctionRules.quickBid(rules, Auction.QUICK[1]))} coins to bid on this one.`
	elseif why then
		statusLabel.Text = `🚫 {why}`
	elseif lot.kind == "WorkerContract" then
		local contract = Workers.CONTRACTS[lot.id]
		statusLabel.Text = `Joins your crew as a {Workers.TYPES[contract.type].name}: you have a free slot.`
	else
		statusLabel.Text = "Outbid? Your coins come straight back."
	end
end

------------------------------------------------------------------------
-- The hall: the board, the lot over its pedestal, Goldie's bubble, the bell

local hall = nil -- { board = TextLabels..., icon, bubble, bell = { model, base, pivot } }

local function chalk(parent: Instance, props)
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or CHALK
	props.TextScaled = true
	props.Parent = parent
	return make("TextLabel", props)
end

local function buildHall(house: Model)
	local lotBoard = house:WaitForChild("LotBoard", 30)
	local pedestal = house:WaitForChild("PedestalTop", 30)
	local goldie = house:WaitForChild("GoldieGavel", 30)
	local bell = house:WaitForChild("AuctionBell", 30)
	if not lotBoard or not pedestal or not goldie or not bell then
		return
	end
	local gui = make("SurfaceGui", {
		Name = "Board", Face = Enum.NormalId.Back, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40,
		LightInfluence = 0.3, Parent = lotBoard,
	})
	local view = {
		lot = chalk(gui, { Position = UDim2.fromScale(0.27, 0.06), Size = UDim2.fromScale(0.5, 0.13), Font = UI.HAND, TextXAlignment = Enum.TextXAlignment.Left }),
		icon = chalk(gui, { Position = UDim2.fromScale(0.03, 0.12), Size = UDim2.fromScale(0.22, 0.6), Font = UI.HEAD }),
		name = chalk(gui, { Position = UDim2.fromScale(0.27, 0.2), Size = UDim2.fromScale(0.7, 0.2), Font = UI.HEAD, TextXAlignment = Enum.TextXAlignment.Left }),
		detail = chalk(gui, { Position = UDim2.fromScale(0.27, 0.42), Size = UDim2.fromScale(0.7, 0.13), Font = UI.HAND, TextXAlignment = Enum.TextXAlignment.Left }),
		bid = chalk(gui, { Position = UDim2.fromScale(0.27, 0.6), Size = UDim2.fromScale(0.7, 0.18), Font = UI.HEAD, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left }),
		foot = chalk(gui, { Position = UDim2.fromScale(0.03, 0.82), Size = UDim2.fromScale(0.94, 0.12), Font = UI.HAND }),
		clock = chalk(gui, { Position = UDim2.fromScale(0.8, 0.04), Size = UDim2.fromScale(0.17, 0.16), Font = UI.HEAD, TextXAlignment = Enum.TextXAlignment.Right }),
	}
	-- (the pedestal's top is a cylinder lying on its side: offsets and
	-- emitters on it went sideways, so they hang from an upright attachment)
	local over = make("Attachment", { Name = "Over", Parent = pedestal })
	over.WorldCFrame = CFrame.new(pedestal.Position + Vector3.new(0, 1.2, 0))
	local float = make("BillboardGui", {
		Name = "Lot", Size = UDim2.fromScale(2.2, 2.2), LightInfluence = 0, MaxDistance = 80, Adornee = over, Parent = pedestal,
	})
	local floatIcon = make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextScaled = true, Font = UI.HEAD, Text = "", Parent = float })
	local bubble = make("BillboardGui", { -- (up and to her right, off the lot board)
		Name = "Call", Size = UDim2.fromScale(7, 1.6), StudsOffset = Vector3.new(3.2, 1.8, 0), MaxDistance = 80, Enabled = false,
		Adornee = goldie:FindFirstChild("Head"), Parent = goldie,
	})
	local bubbleCard = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.cream, Parent = bubble }, { UI.corner(12), UI.stroke(C.ink, 2) })
	local bubbleText = make("TextLabel", {
		Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), BackgroundTransparency = 1, TextScaled = true, Font = UI.HEAD,
		TextColor3 = C.ink, Text = "", Parent = bubbleCard,
	})
	-- confetti from the pedestal when a lot sells: four bursts in solid
	-- colours (one colour each: an emitter's colour changes over a flake's
	-- life, not per flake), tumbling as they fall
	local burst = make("Attachment", { Name = "Burst", Parent = pedestal })
	burst.WorldCFrame = CFrame.new(pedestal.Position + Vector3.new(0, 0.4, 0))
	local confetti = {}
	for _, color in { Color3.fromRGB(235, 70, 70), Color3.fromRGB(255, 200, 50), Color3.fromRGB(70, 160, 240), Color3.fromRGB(90, 200, 100) } do
		table.insert(confetti, make("ParticleEmitter", {
			Name = "Confetti", Rate = 0, Lifetime = NumberRange.new(2.2, 3.2), Speed = NumberRange.new(9, 14), SpreadAngle = Vector2.new(40, 40),
			Acceleration = Vector3.new(0, -9, 0), Drag = 1, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-360, 360),
			Size = NumberSequence.new(0.5), Squash = NumberSequence.new(1.2), Texture = "rbxasset://textures/particles/sparkles_main.dds",
			LightEmission = 0, LightInfluence = 0.4, Color = ColorSequence.new(color), EmissionDirection = Enum.NormalId.Top, Parent = burst,
		}))
	end
	local pivot = bell:GetAttribute("Pivot")
	hall = { view = view, float = floatIcon, over = over, overAt = over.WorldCFrame, bubble = bubble, bubbleText = bubbleText, confetti = confetti,
		bell = { model = bell, base = bell:GetPivot(), pivot = pivot, axis = PlotLayout.buildingFrame("Auction").XVector } }
end

local function updateHall(t: number)
	if not hall then
		return
	end
	local view = hall.view
	local lot, k = current()
	local phase = board:GetAttribute("Phase") or ""
	if not lot or phase == "" then
		local nextAt = AuctionRules.nextAt(t)
		view.lot.Text = ""
		view.icon.Text = "🔨"
		view.name.Text = "Cloverdale Auction House"
		view.detail.Text = "Mythic seeds, rare workers and defences: 3 lots every 8 minutes"
		view.bid.Text = `Next auction in {UI.formatTime(nextAt - t)}`
		view.clock.Text = ""
		view.foot.Text = "Bid from inside the hall. Outbid? Your coins come straight back."
		hall.float.Text = ""
	else
		local what = AuctionRules.describe(lot)
		view.lot.Text = `Lot {k} of {#lots()}  ·  worth about {UI.formatNumber(lot.estimate)}`
		view.icon.Text = what.icon
		view.name.Text = what.name
		view.detail.Text = what.detail
		hall.float.Text = what.icon
		if phase == "Sold" then
			local to = board:GetAttribute("SoldTo") or ""
			view.bid.Text = if to ~= "" then `SOLD to {to} for {UI.formatNumber(board:GetAttribute("SoldFor") or 0)}!` else "No bids: back to the vault"
			view.clock.Text = ""
		else
			local top = board:GetAttribute("Bid") or 0
			view.bid.Text = if top > 0 then `Top bid: {UI.formatNumber(top)} · {board:GetAttribute("Leader")}` else `Opening bid: {UI.formatNumber(board:GetAttribute("Opening") or 0)}`
			view.clock.Text = `{math.ceil(math.max(0, (board:GetAttribute("EndsAt") or t) - t))}s`
		end
		view.foot.Text = "Bid with the card on your screen: +5%, +10% or +25%. A bid in the last 10 s puts the clock back to 10."
	end
	-- Goldie's call
	local call = board:GetAttribute("Call") or ""
	if phase == "Sold" and (board:GetAttribute("SoldTo") or "") ~= "" then
		call = `SOLD to {board:GetAttribute("SoldTo")}!`
	end
	hall.bubble.Enabled = call ~= ""
	hall.bubbleText.Text = call
	-- the lot bobs over its pedestal
	hall.over.WorldCFrame = hall.overAt + Vector3.new(0, math.sin(os.clock() * 2) * 0.25, 0)
end

local ringUntil = 0
local swinging = false
local function swingBell()
	local left = ringUntil - os.clock()
	if not hall or not hall.bell.pivot or (left <= 0 and not swinging) then
		return
	end
	local bell = hall.bell
	swinging = left > 0
	local angle = if left > 0 then math.sin(os.clock() * 9) * math.rad(28) * math.min(1, left / 1.5) else 0
	bell.model:PivotTo(CFrame.new(bell.pivot) * CFrame.fromAxisAngle(bell.axis, angle) * CFrame.new(-bell.pivot) * bell.base)
end

------------------------------------------------------------------------

function AuctionController.Start()
	task.spawn(function()
		local town = workspace:WaitForChild("World"):WaitForChild("Town")
		local house = town:WaitForChild("AuctionHouse", 60)
		if house then
			buildHall(house)
		end
	end)

	-- a new auction: the bell rings, and everyone hears what's up
	local lastStart = board:GetAttribute("StartedAt") or 0
	board:GetAttributeChangedSignal("StartedAt"):Connect(function()
		local started = board:GetAttribute("StartedAt") or 0
		if started == lastStart then
			return
		end
		lastStart = started
		ringUntil = os.clock() + 4
		local names = {}
		for _, lot in lots() do
			local what = AuctionRules.describe(lot)
			table.insert(names, `{what.icon} {what.name}`)
		end
		UI.toast(`🔔 The auction's on! {table.concat(names, " · ")}`, "Announce", 8, if inHall() then nil else {
			text = "TOWN 🏘️",
			press = function()
				HudController.travel("Town", "Heading to town... (stand still)")
			end,
		})
	end)
	-- a sale: confetti over the pedestal
	board:GetAttributeChangedSignal("Phase"):Connect(function()
		if board:GetAttribute("Phase") == "Sold" and (board:GetAttribute("SoldTo") or "") ~= "" and hall then
			for _, emitter in hall.confetti do
				emitter:Emit(18)
			end
		end
	end)

	local warned = nil
	RunService.RenderStepped:Connect(function()
		local t = now()
		-- the minute's warning before each auction
		local nextAt = AuctionRules.nextAt(t)
		if nextAt - t <= Auction.WARNING and warned ~= nextAt then
			warned = nextAt
			if not inHall() then
				UI.toast("🔨 The auction starts in 1 minute at the Auction House: Mythic seeds, rare workers, defences!", "Announce", 8, {
					text = "TOWN 🏘️",
					press = function()
						HudController.travel("Town", "Heading to town... (stand still)")
					end,
				})
			end
		end
		updateCard()
		updateHall(t)
		swingBell()
	end)
end

return AuctionController
