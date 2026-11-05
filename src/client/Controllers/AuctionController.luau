-- The Auction House on your screen (docs/GameDesign.md §4.4, §5.3; the
-- server's AuctionService, the hall in World/AuctionArt). Everything comes
-- from ReplicatedStorage.Auction's attributes:
--   * the lot board on the hall's back wall (a chalkboard: the lot, the top
--     bid and who has it, the clock; between auctions, when the next is),
--     the lot over its pedestal, Goldie Gavel's calls in a speech bubble,
--     the bell swinging when an auction starts and confetti when a lot sells;
--   * the bid card (red velvet in a gold frame, right of the screen) while
--     you're inside the hall during a lot: the lot, its estimate, the top
--     bid, a clock that flashes when a late bid puts it back, a big RAISE
--     PADDLE button for what Goldie's asking and +10% / +25% jump bids,
--     your paddle number, whether you lead, your coins, what comes next;
--   * the room, like a real auction: a bidder's call in a speech bubble
--     over their head ("52,000!") as their paddle goes up (PoseController
--     raises it), Goldie turning to look at whoever just bid and nodding
--     as she talks, her gavel coming down on "Going once", "Going twice"
--     and SOLD, the winner hopping for joy;
--   * a note a minute before each auction (with a Town button), and one when
--     it starts saying what's up.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auction = require(Shared.Config.Auction)
local AuctionRules = require(Shared.AuctionRules)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local WorkerRules = require(Shared.WorkerRules)
local Workers = require(Shared.Config.Workers)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local Bubbles = require(script.Parent.Parent.Bubbles)
local UI = require(script.Parent.Parent.UI)
local HudController = require(script.Parent.HudController)
local PoseController = require(script.Parent.PoseController)
local Sfx = require(script.Parent.Parent.Sfx)

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
-- Like a real auction: the big button raises your paddle for what Goldie's
-- asking (the next step up); the two small ones jump the bid.
local buttons = {}
for i, share in Auction.QUICK do
	local holder, button = UI.button({ text = "", kind = "gold", size = UDim2.fromOffset(if i == 1 then 136 else 80, 46),
		position = UDim2.fromOffset(if i == 1 then 16 else 16 + 142 + (i - 2) * 86, 146), textSize = 16, parent = card })
	buttons[i] = { holder = holder, button = button, share = share }
end
local raiseScale = make("UIScale", { Parent = buttons[1].holder }) -- (it pulses when you've been outbid: "back to you!")
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
local myBid = nil -- "auction:lot" you last bid on (the paddle button pulses if you're outbid on it)
local function bid(amount: number)
	if bidding then
		return
	end
	bidding = true
	if player.Character then
		PoseController.raisePaddle(player.Character) -- (up at once: the server tells everyone else)
	end
	local result = AuctionAction:InvokeServer("Bid", tostring(amount))
	bidding = false
	if result.ok then
		myBid = `{board:GetAttribute("Index")}:{board:GetAttribute("Lot")}`
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
local TICK_FROM = 10 -- seconds left on a lot when the clock starts ticking
local FAST_TICK = 3 -- ... and the last few, higher
local lastTick = nil -- the second last ticked
local leadingOn = nil -- "auction:lot" you're the top bid on

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
	local paddleNo = player:GetAttribute("Paddle")
	header.Text = `🔨 LOT {k} OF {count}{if paddleNo then `  ·  PADDLE {paddleNo}` else ""}`
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
		statusLabel.Text = if k < count then "The next lot is coming up..."
			else `That's all for this auction: the next one is in {UI.formatTime(AuctionRules.nextAt(now()) - now())}.`
		for _, entry in buttons do
			entry.holder.Visible = false
		end
		return
	end

	local t = now()
	local left = math.max(0, (board:GetAttribute("EndsAt") or t) - t)
	clockLabel.Text = tostring(math.ceil(left))
	local second = math.ceil(left)
	if left > 0 and left <= TICK_FROM and second ~= lastTick then
		Sfx.play("AuctionTick", nil, if second <= FAST_TICK then 1.3 else 1)
	end
	lastTick = second
	local snipe = board:GetAttribute("Snipe") or 0
	if snipe ~= lastSnipe then
		lastSnipe = snipe
		flashUntil = os.clock() + 1.2
	end
	local flashing = os.clock() < flashUntil and (if UI.flashing >= 0.5 then math.floor(os.clock() * 6) % 2 == 0 else true) -- (Settings: steady red)
	clock.BackgroundColor3 = if flashing then C.alarm elseif left <= 10 then Color3.fromRGB(255, 226, 160) else C.cream
	clockStroke.Color = if left <= 10 then C.alarm else GOLD

	local top = board:GetAttribute("Bid") or 0
	local leaderId = board:GetAttribute("LeaderId") or 0
	local leading = top > 0 and leaderId == player.UserId
	local thisLot = `{board:GetAttribute("Index")}:{k}`
	if leading then
		leadingOn = thisLot
	elseif leadingOn == thisLot and top > 0 then
		leadingOn = nil
		Sfx.play("Outbid")
	end
	bidLabel.Text = if top > 0 then `Top bid: {UI.formatNumber(top)}  ·  {if leading then "you!" else board:GetAttribute("Leader")}`
		else `Opening bid: {UI.formatNumber(board:GetAttribute("Opening") or 0)}  ·  no bids yet`
	local why = blocked(lot)
	local coins = state and state.coins or 0
	local rules = ruleLot()
	for i, entry in buttons do
		local amount = AuctionRules.quickBid(rules, entry.share)
		entry.amount = amount
		-- (before anyone bids, only the paddle: for the opening price)
		entry.holder.Visible = not leading and not why and (top > 0 or i == 1)
		entry.holder.Size = UDim2.fromOffset(if i > 1 then 80 elseif top > 0 then 136 else 200, 46)
		entry.button.Text = if i == 1 then `🙋 RAISE PADDLE\n{UI.formatNumber(amount)}` else `+{math.floor(entry.share * 100)}%\n{UI.formatShort(amount)}`
		UI.setButtonKind(entry.holder, if coins >= amount then "gold" else "cream")
	end
	-- outbid on this lot: the paddle button pulses ("back to you!")
	local outbid = not leading and myBid == `{board:GetAttribute("Index")}:{k}` and not UI.calm
	raiseScale.Scale = if outbid then 1 + 0.05 * math.sin(os.clock() * 9) else 1
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
	local bubble = make("BillboardGui", { -- (up and to her right, off the lot board; two lines for her patter)
		Name = "Call", Size = UDim2.fromScale(9, 2.4), StudsOffset = Vector3.new(4.2, 2.2, 0), MaxDistance = 80, Enabled = false,
		Adornee = goldie:FindFirstChild("Head"), Parent = goldie,
	})
	local bubbleCard = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.cream, Parent = bubble }, { UI.corner(12), UI.stroke(C.ink, 2) })
	local bubbleText = make("TextLabel", {
		Size = UDim2.new(1, -14, 1, -8), Position = UDim2.fromOffset(7, 4), BackgroundTransparency = 1, TextScaled = true, TextWrapped = true, Font = UI.HEAD,
		TextColor3 = C.ink, Text = "", Parent = bubbleCard,
	})
	-- Goldie's moving parts: her head (turns to the bidder, nods as she
	-- talks) and her gavel (comes down round her grip)
	local head = goldie:FindFirstChild("Head")
	local headParts, gavelParts = {}, {}
	for _, part in goldie:GetChildren() do
		if part:IsA("BasePart") then
			if table.find({ "Head", "Beak", "Wattle", "Eye", "Comb", "BowTie", "BowKnot" }, part.Name) then
				headParts[part] = part.CFrame
			elseif string.match(part.Name, "^Gavel") then
				gavelParts[part] = part.CFrame
			end
		end
	end
	local handle = goldie:FindFirstChild("GavelHandle")
	local grip = handle and handle.CFrame * CFrame.Angles(0, 0, math.rad(-90)) * CFrame.new(0, -0.6, 0) -- (World/AuctionArt.goldie's grip)
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
		bell = { model = bell, base = bell:GetPivot(), pivot = pivot, axis = PlotLayout.buildingFrame("Auction").XVector },
		goldie = { head = head and head.CFrame, headParts = headParts, gavelParts = gavelParts, grip = grip, yaw = 0, nodAt = -math.huge, bangAt = -math.huge,
			gavelHead = goldie:FindFirstChild("GavelHead") } }
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
		view.detail.Text = `Rare seeds, rare workers and defences: {Auction.LOTS} lots every {Auction.INTERVAL // 60} minutes`
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
			local paddleNo = board:GetAttribute("LeaderPaddle") or 0
			view.bid.Text = if top > 0 then `Top bid: {UI.formatNumber(top)} · paddle {paddleNo} ({board:GetAttribute("Leader")})`
				else `Opening bid: {UI.formatNumber(board:GetAttribute("Opening") or 0)}`
			view.clock.Text = `{math.ceil(math.max(0, (board:GetAttribute("EndsAt") or t) - t))}s`
		end
		view.foot.Text = "Raise your paddle with the card on your screen. A bid in the last 10 s puts the clock back to 10."
	end
	-- Goldie's call (AuctionService's: her patter, by paddle number)
	local call = board:GetAttribute("Call") or ""
	Bubbles.set(hall.bubble, call ~= "")
	hall.bubbleText.Text = call
	-- the lot bobs over its pedestal
	hall.over.WorldCFrame = hall.overAt + Vector3.new(0, if UI.calm then 0 else math.sin(os.clock() * 2) * 0.25, 0)
end

local function smooth01(x: number): number
	return x * x * (3 - 2 * x)
end

-- Goldie: her head turns to whoever just bid (and back to the room), nods
-- as she talks; her gavel comes down when she calls it.
local function animateGoldie(dt: number)
	local g = hall and hall.goldie
	if not g or not g.head then
		return
	end
	local clock = os.clock()
	local target = 0
	local bidder = Players:GetPlayerByUserId(board:GetAttribute("BidderId") or 0)
	local root = bidder and bidder.Character and bidder.Character:FindFirstChild("HumanoidRootPart")
	if root and (board:GetAttribute("Phase") or "") ~= "" then
		local v = g.head:VectorToObjectSpace(root.Position - g.head.Position)
		target = math.clamp(math.atan2(v.X, v.Z), math.rad(-50), math.rad(50))
	end
	g.yaw += (target - g.yaw) * (1 - math.exp(-dt * 5))
	local nodT = clock - g.nodAt
	local nod = if nodT < 0.35 and not UI.calm then math.sin(math.pi * nodT / 0.35) * 0.18 else 0
	local turn = g.head * CFrame.Angles(0, g.yaw, 0) * CFrame.Angles(nod, 0, 0) * g.head:Inverse()
	for part, base in g.headParts do
		part.CFrame = turn * base
	end
	if g.grip then
		local t = clock - g.bangAt
		local a = if t < 0.08 then t / 0.08 elseif t < 0.14 then 1 elseif t < 0.4 then 1 - smooth01((t - 0.14) / 0.26) else 0
		local swing = g.grip * CFrame.Angles(math.rad(75) * a, 0, 0) * g.grip:Inverse()
		for part, base in g.gavelParts do
			part.CFrame = swing * base
		end
	end
end

-- A bidder's call: "52,000!" in a speech bubble over their head, popping
-- in as their paddle goes up, gone after a couple of seconds.
local function showCall(character: Model, amount: number)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("BidCall")
	if old then
		old:Destroy()
	end
	-- (beside the head on the bidder's left: their paddle goes up on the right,
	-- and a bubble over the head hid it. StudsOffsetWorldSpace is in the
	-- head's own frame, so it stays on that side whichever way they face.)
	local gui = make("BillboardGui", {
		Name = "BidCall", Size = UDim2.fromScale(4.6, 1.7), StudsOffsetWorldSpace = Vector3.new(-3.1, 1.6, 0), MaxDistance = 90, Enabled = false,
		Adornee = head, Parent = head,
	})
	Bubbles.set(gui, true)
	local group = make("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local scale = make("UIScale", { Scale = 0.2, Parent = group })
	make("Frame", { -- (the bubble's tail, pointing down at the bidder)
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.78, 0), Size = UDim2.fromScale(0.13, 0.32), SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Rotation = 45, BackgroundColor3 = C.cream, Parent = group,
	}, { UI.stroke(C.ink, 2) })
	local cardFrame = make("Frame", { Size = UDim2.fromScale(1, 0.8), BackgroundColor3 = C.cream, Parent = group }, { UI.corner(14), UI.stroke(C.ink, 2.5) })
	make("TextLabel", {
		Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), BackgroundTransparency = 1, TextScaled = true, Font = UI.HEAD,
		TextColor3 = Color3.fromRGB(200, 69, 45), Text = `{UI.formatNumber(amount)}!`, Parent = cardFrame,
	})
	TweenService:Create(scale, TweenInfo.new(if UI.calm then 0 else 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Sfx.play("Pop", head)
	task.delay(1.8, function()
		if gui.Parent then
			TweenService:Create(group, TweenInfo.new(0.35), { GroupTransparency = 1 }):Play()
			task.delay(0.4, function()
				gui:Destroy()
			end)
		end
	end)
end

-- Every character's calls (and your own hop when you win a lot, and a
-- word the first time you sit on a bench).
local toldSeat = false
local function watchCharacter(character: Model)
	character:GetAttributeChangedSignal("PaddleUp"):Connect(function()
		showCall(character, character:GetAttribute("PaddleCall") or 0)
	end)
	if character == player.Character then
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Seated:Connect(function(active, seat)
				if active and seat and seat.Name == "BenchSpot" and not toldSeat then
					toldSeat = true
					UI.toast("🪑 Take a seat! Raise your paddle from the card to bid. Jump to stand up.", "Good", 6)
				end
			end)
		end
		character:GetAttributeChangedSignal("Cheer"):Connect(function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and not UI.calm then
				humanoid.Jump = true
			end
		end)
	end
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
		if hall and hall.bell.model then
			Sfx.play("AuctionBell", hall.bell.model:IsA("BasePart") and hall.bell.model or hall.bell.model:FindFirstChildWhichIsA("BasePart", true))
		end
		-- every lot's icon, and the star lot (the one worth most) by name
		local icons, star = {}, nil
		for _, lot in lots() do
			table.insert(icons, AuctionRules.describe(lot).icon)
			if not star or lot.estimate > star.estimate then
				star = lot
			end
		end
		if UI.quiet and not inHall() then
			return -- (Quiet mode: the call is news for everyone)
		end
		local starText = if star then `  ·  the star lot: {AuctionRules.describe(star).icon} {AuctionRules.describe(star).name}` else ""
		UI.toast(`🔔 The auction's on! {#icons} lots: {table.concat(icons, " ")}{starText}`, "Announce", 8, if inHall() then nil else {
			text = "TOWN 🏘️",
			press = function()
				HudController.travel("Town")
			end,
		})
	end)
	-- a sale: confetti over the pedestal
	board:GetAttributeChangedSignal("Phase"):Connect(function()
		if board:GetAttribute("Phase") == "Sold" and (board:GetAttribute("SoldTo") or "") ~= "" and hall and not UI.calm then
			for _, emitter in hall.confetti do
				emitter:Emit(18)
			end
		end
	end)
	-- the lot is yours: a fanfare, just after the gavel
	player:GetAttributeChangedSignal("AuctionWon"):Connect(function()
		task.delay(0.3, Sfx.play, "BidWon")
	end)
	-- Goldie's gavel comes down ("Going once", "Going twice", SOLD), and she
	-- nods with each new call
	board:GetAttributeChangedSignal("Bang"):Connect(function()
		if hall and hall.goldie then
			hall.goldie.bangAt = os.clock()
			if hall.goldie.gavelHead then
				Sfx.play("Gavel", hall.goldie.gavelHead)
			end
		end
	end)
	board:GetAttributeChangedSignal("Call"):Connect(function()
		if hall and hall.goldie and (board:GetAttribute("Call") or "") ~= "" then
			hall.goldie.nodAt = os.clock()
		end
	end)
	-- every character's paddle calls
	local function watchPlayer(other: Player)
		other.CharacterAdded:Connect(watchCharacter)
		if other.Character then
			task.spawn(watchCharacter, other.Character) -- (it waits for your Humanoid)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end

	local warned = nil
	local last = os.clock()
	RunService.RenderStepped:Connect(function()
		local t = now()
		local dt = os.clock() - last
		last = os.clock()
		animateGoldie(dt)
		-- the minute's warning before each auction
		local nextAt = AuctionRules.nextAt(t)
		if nextAt - t <= Auction.WARNING and warned ~= nextAt then
			warned = nextAt
			if not inHall() and not UI.quiet then
				UI.toast("🔨 The auction starts in 1 minute at the Auction House: rare seeds, rare workers, defences!", "Announce", 8, {
					text = "TOWN 🏘️",
					press = function()
						HudController.travel("Town")
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
