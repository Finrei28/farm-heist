-- The Cloverdale Auction House (docs/GameDesign.md §4.4; the rules in
-- shared/AuctionRules, the hall in World/AuctionArt). An auction starts
-- every 8 minutes on the clock: five lots (Config/Auction.LOTS), one after
-- another, about a minute each and 10 s between them. Every server rolls
-- its own lots.
--
-- Bids come through the AuctionAction remote ("Bid" amount) and are only
-- taken from inside the hall (trusted position, PlotLayout.insideBuilding).
-- Bidding moves the coins out of your wallet (escrow); outbid, they come
-- straight back, as income for any debts (§4.12, so a bid can't hide coins
-- from a fine). A bid in the last 10 s puts the clock back to 10 s. The
-- winner's lot goes into their save at once (and it's saved). Leaving the
-- server cancels your bids: if you led, your coins go back into your save
-- before it closes and the highest earlier bidder who can still pay leads.
-- The coins a lead holds are written in the save too (auctionHeld), so a
-- server that closes mid-lot (an update) can't lose them: they come back
-- on the next join.
-- Like a real auction room: everyone in the hall holds a numbered bidder
-- paddle (World/AuctionArt.paddle, in the right hand; the number is theirs
-- for the server's life). A bid raises it and calls the amount out
-- (PoseController and AuctionController animate it on every screen from
-- the character's PaddleUp / PaddleCall), and Goldie Gavel works the room
-- by paddle number (AuctionRules.patter): "52,000 from paddle 47! Back to
-- you, paddle 12: 54,600?" ... "Going once... going twice... SOLD!", her
-- gavel coming down each time (Bang), the winner cheering (Cheer).
--
-- Clients see it on ReplicatedStorage.Auction's attributes:
--   Index    the auction's number (AuctionRules.index), Lot 1–5 (0: none on)
--   Lots     JSON: { { kind, id, estimate } } for this auction
--   Phase    "Open" (bidding) · "Sold" (the 10 s after a lot) · "" between auctions
--   Bid, Leader (name), LeaderId, LeaderPaddle, MinBid, Opening, EndsAt (server time), Snipe (a late bid's count)
--   BidderId the last bidder (Goldie looks at them)
--   Call     Goldie's call now, Bang (counts her gavel coming down), SoldTo, SoldFor (the last lot)
-- and on each player: Paddle (their bidder number); on a character:
-- PaddleUp (server time of their last bid), PaddleCall (its amount), Cheer
-- (server time they won a lot).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Auction = require(Shared.Config.Auction)
local AuctionRules = require(Shared.AuctionRules)
local DefenceRules = require(Shared.DefenceRules)
local Format = require(Shared.Format)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local WorkerRules = require(Shared.WorkerRules)

local Server = ServerScriptService.Server
local AuctionArt = require(Server.World.AuctionArt)
local ActionRemote = require(Server.Util.ActionRemote)
local Analytics = require(Server.Util.Analytics)
local Notice = require(Server.Util.Notice)
local DataService = require(script.Parent.DataService)
local DefenceService = require(script.Parent.DefenceService)
local MovementService = require(script.Parent.MovementService)
local WorkerService = require(script.Parent.WorkerService)

local AuctionService = {}

local TICK = 0.2
local START_LATE = 5 -- seconds: a server that wasn't up when the clock struck waits for the next one

local board = Instance.new("Folder")
board.Name = "Auction"

local serverSeed = math.random(1, 2 ^ 30) -- (each server rolls its own lots)
local current = nil -- { index, lots, k, phase = "Open" | "Sold" | "Done", gapUntil, last = { at, userId, previous } }
local wonCallbacks = {}

-- Bidder numbers: each player's, for the server's life (AuctionRules.paddleNumbers).
local paddleOrder = AuctionRules.paddleNumbers(serverSeed)
local paddleOf = {} -- [userId] = number
local handedOut = 0

local function paddleNumber(player: Player): number
	local number = paddleOf[player.UserId]
	if not number then
		handedOut += 1
		number = paddleOrder[handedOut] or (99 + handedOut - #paddleOrder)
		paddleOf[player.UserId] = number
		player:SetAttribute("Paddle", number)
	end
	return number
end

-- The auction clock: server time, plus the dev shift (/auction soon sets
-- ReplicatedStorage's AuctionShift; AuctionController adds it too).
local function now(): number
	return workspace:GetServerTimeNow() + (ReplicatedStorage:GetAttribute("AuctionShift") or 0)
end

-- 17,700 (for the notes)
local coins = Format.number

local function lotNow()
	return current and current.phase == "Open" and current.lots[current.k] or nil
end

local function playerOf(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

-- Shows the lot on the board (ReplicatedStorage.Auction's attributes).
local function publish()
	if not current then
		board:SetAttribute("Lot", 0)
		board:SetAttribute("Phase", "")
		return
	end
	local lot = current.lots[current.k]
	local top = lot and AuctionRules.leader(lot)
	board:SetAttribute("Index", current.index)
	board:SetAttribute("Lot", if current.phase == "Done" then 0 else current.k)
	board:SetAttribute("Phase", if current.phase == "Done" then "" else current.phase)
	board:SetAttribute("Bid", if top then top.amount else 0)
	board:SetAttribute("LeaderId", if top then top.userId else 0)
	local leader = top and playerOf(top.userId)
	board:SetAttribute("Leader", if leader then leader.DisplayName else "")
	board:SetAttribute("LeaderPaddle", if top then paddleOf[top.userId] or 0 else 0)
	board:SetAttribute("Opening", if lot then lot.opening else 0)
	board:SetAttribute("MinBid", if lot and current.phase == "Open" then AuctionRules.minBid(lot) else 0)
	board:SetAttribute("EndsAt", if lot then lot.endsAt else 0)
end

-- Coins back to a bidder who was outbid (or whose lot couldn't be handed
-- over): income for any debts they have (§4.12), not earnings.
local function refund(userId: number, amount: number)
	local player = playerOf(userId)
	local data = player and DataService.Get(player)
	if not player or not data or amount <= 0 then
		return
	end
	data.auctionHeld = math.max(0, (data.auctionHeld or 0) - amount)
	local kept = if DataService.Garnish then DataService.Garnish(player, data, amount) else amount
	DataService.AddCoins(player, kept, Analytics.GAMEPLAY, "AuctionRefund")
end

-- Coins a lead takes out of the wallet: held, and written in the save.
local function hold(player: Player, data, amount: number): boolean
	if not DataService.SpendCoins(player, amount, Analytics.SHOP, "AuctionBid") then
		return false
	end
	data.auctionHeld = (data.auctionHeld or 0) + amount
	return true
end

-- What a player's lot needs to go home with them (AuctionRules.canWin).
local function winCtx(player: Player, data)
	return { level = data.level, defences = data.defences, workers = data.workers, workerCtx = WorkerService.context(data) }
end

-- Hands a sold lot to its winner, for the `paid` coins their lead held.
-- False if they can't take it now (then they get their coins back).
local function deliver(player: Player, data, lot, paid: number): boolean
	if not AuctionRules.canWin(lot, winCtx(player, data)) then
		return false
	end
	if lot.kind == "Seed" then
		data.inventory.seeds[lot.id] = (data.inventory.seeds[lot.id] or 0) + 1
	elseif lot.kind == "Defence" then
		DefenceRules.buy(data.defences, lot.id)
		DefenceService.Redraw(player)
	elseif lot.kind == "WorkerContract" then
		local worker = WorkerRules.fromContract(lot.id)
		if not worker or not WorkerService.AddWorker(player, worker) then
			return false
		end
	end
	data.auctionHeld = math.max(0, (data.auctionHeld or 0) - paid) -- (spent: before the save below)
	DataService.NotifyState(player)
	local profile = DataService.GetProfile(player)
	if profile then
		task.spawn(function()
			pcall(profile.Save, profile) -- (a lot is saved at once: §4.4)
		end)
	end
	return true
end

-- Where a won lot ends up, for the winner's note.
local function whereItGoes(lot): string
	return if lot.kind == "Seed" then "it's in your seed bag"
		elseif lot.kind == "Defence" then "it's waiting in your Defences window"
		else "they've joined your crew"
end

-- Goldie's gavel comes down (every screen animates it and hears it).
local function bang()
	board:SetAttribute("Bang", (board:GetAttribute("Bang") or 0) + 1)
end

-- Everyone in the hall holds their bidder paddle in their right hand; it
-- goes when they leave (or carry something, which takes both hands).
local function updatePaddles()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
		local paddle = character and character:FindFirstChild("BidderPaddle")
		local position = MovementService.positionOf(player)
		local inHall = position ~= nil and PlotLayout.insideBuilding("Auction", position, 0)
		local busy = character ~= nil and (character:FindFirstChild("CarriedCrop") or character:FindFirstChild("CarriedCrate")) ~= nil
		local wanted = inHall and not busy and hand ~= nil and humanoid ~= nil and humanoid.Health > 0
		if wanted and not paddle then
			paddle = AuctionArt.paddle(paddleNumber(player))
			-- (R6: the arm's a single part; its fist is at the bottom)
			local fist = if hand.Name == "Right Arm" then CFrame.new(0, -1, 0) else CFrame.new()
			for _, part in paddle:GetChildren() do
				if part:IsA("BasePart") then
					local weld = Instance.new("Weld")
					weld.Part0 = hand
					weld.Part1 = part
					weld.C0 = fist * part.CFrame
					weld.Parent = part
				end
			end
			paddle.Parent = character
		elseif paddle and not wanted then
			paddle:Destroy()
		end
	end
end

-- The benches (World/AuctionArt's BenchSpots): Sit seats you, to watch and
-- bid from there (your paddle comes too); jump to stand up (Roblox's own).
-- Not with your hands full. A taken place hides its prompt.
local function sitDown(player: Player, seat: Seat)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or seat.Occupant ~= nil or humanoid.SeatPart == seat then
		return
	end
	if character:FindFirstChild("CarriedCrop") or character:FindFirstChild("CarriedCrate") then
		Notice.send(player, "Your hands are full: take it home first.", "Error")
		return
	end
	if humanoid.SeatPart then -- (moving along the row: off the old place first)
		humanoid.Sit = false
		task.wait(0.1)
	end
	seat:Sit(humanoid)
end

local function setUpBenches()
	local world = workspace:FindFirstChild("World")
	local house = world and world:FindFirstChild("Town") and world.Town:FindFirstChild("AuctionHouse")
	if not house then
		warn("[AuctionService] no Auction House to put the benches' seats in")
		return
	end
	for _, seat in house:GetDescendants() do
		if seat:IsA("Seat") and seat.Name == "BenchSpot" then
			local prompt = seat:FindFirstChild("SitPrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Triggered:Connect(function(player)
					sitDown(player, seat)
				end)
				seat:GetPropertyChangedSignal("Occupant"):Connect(function()
					prompt.Enabled = seat.Occupant == nil
				end)
			end
		end
	end
end

local function openLot(t: number)
	AuctionRules.open(current.lots[current.k], t)
	current.phase = "Open"
	current.called = 0
	current.last = nil
	board:SetAttribute("BidderId", 0)
	board:SetAttribute("Call", "")
	board:SetAttribute("SoldTo", "")
	board:SetAttribute("SoldFor", 0)
	publish()
end

local function startAuction(index: number, t: number)
	local lots = AuctionRules.rollLots(serverSeed + index)
	current = { index = index, lots = lots, k = 1, phase = "Open" }
	local list = {}
	for _, lot in lots do
		table.insert(list, { kind = lot.kind, id = lot.id, estimate = lot.estimate })
	end
	board:SetAttribute("Lots", HttpService:JSONEncode(list))
	board:SetAttribute("StartedAt", t) -- (the clients ring the bell)
	openLot(t)
end

local function closeLot(t: number)
	local lot = current.lots[current.k]
	local top = AuctionRules.close(lot, t)
	local what = AuctionRules.describe(lot)
	current.phase = "Sold"
	current.gapUntil = t + Auction.GAP
	local winner = top and playerOf(top.userId)
	local number = top and paddleOf[top.userId]
	board:SetAttribute("Call", if not top then "No bids? Back to the vault it goes!"
		elseif winner then `SOLD! To paddle {number}, {winner.DisplayName}, for {coins(top.amount)}!`
		else "SOLD!")
	if top then
		bang()
		if winner and winner.Character then
			winner.Character:SetAttribute("Cheer", t)
		end
	end
	board:SetAttribute("SoldTo", if winner then winner.DisplayName else "")
	board:SetAttribute("SoldFor", if top then top.amount else 0)
	if top and winner then
		local data = DataService.Get(winner)
		if data and deliver(winner, data, lot, top.amount) then
			Notice.send(winner, `🔨 SOLD to you! {what.icon} {what.name} for {coins(top.amount)}: {whereItGoes(lot)}.`, "Good")
			winner:SetAttribute("AuctionWon", t) -- (their fanfare: AuctionController)
			Analytics.event(winner, "AuctionWon", top.amount)
			for _, callback in wonCallbacks do
				task.spawn(callback, winner, data, lot, top.amount)
			end
			if lot.kind == "Seed" and (lot.rarity == "Mythic" or lot.rarity == "Legendary") then
				for _, other in Players:GetPlayers() do
					if other ~= winner then
						Notice.send(other, `🔨 {winner.DisplayName} won a {what.name} at the Auction House for {coins(top.amount)}!`, "Announce", { everyone = true })
					end
				end
			end
		else
			refund(top.userId, top.amount)
			Notice.send(winner, `You won the {what.name}, but couldn't take it home (no room for it): your {coins(top.amount)} coins are back.`, "Error")
		end
	end
	publish()
end

local function tick()
	local t = now()
	updatePaddles()
	local index = AuctionRules.index(t)
	if (not current or current.phase == "Done") and (not current or current.index < index) then
		if t - index * Auction.INTERVAL <= START_LATE then
			startAuction(index, t)
		end
		return
	end
	if not current then
		return
	end
	if current.phase == "Open" then
		local lot = current.lots[current.k]
		local left = lot.endsAt - t
		-- Goldie works the room (a late bid puts the clock back)
		local call, gavel = AuctionRules.patter(lot, t, {
			k = current.k, name = AuctionRules.describe(lot).name, last = current.last,
			paddleOf = function(userId)
				return paddleOf[userId]
			end,
		})
		if board:GetAttribute("Call") ~= call then
			board:SetAttribute("Call", call)
			if gavel then
				bang()
			end
		end
		if left <= 0 then
			closeLot(t)
		end
	elseif current.phase == "Sold" and t >= current.gapUntil then
		if current.k >= #current.lots then
			current.phase = "Done"
			board:SetAttribute("Call", "")
			publish()
		else
			current.k += 1
			openLot(t)
		end
	end
end

------------------------------------------------------------------------
-- Bidding

local actions = {}

-- "Bid" amount: at least the lot's MinBid, from inside the hall.
function actions.Bid(player, data, arg)
	local amount = tonumber(arg)
	local lot = lotNow()
	if not amount or amount ~= math.floor(amount) or amount <= 0 then
		return "BadRequest"
	elseif not lot then
		return "Closed"
	end
	local position = MovementService.positionOf(player)
	if not position or not PlotLayout.insideBuilding("Auction", position, Auction.HALL_MARGIN) then
		return "NotInHall"
	end
	local ok, why = AuctionRules.canWin(lot, winCtx(player, data))
	if not ok then
		return why
	end
	local top = AuctionRules.leader(lot)
	if top and top.userId == player.UserId then
		return "AlreadyLeading"
	elseif amount < AuctionRules.minBid(lot) then
		return "TooLow"
	elseif data.coins < amount then
		return "TooPoor"
	end
	local t = now()
	local endsBefore = lot.endsAt
	local placed, reason, previous = AuctionRules.place(lot, player.UserId, amount, t)
	if not placed then
		return reason
	end
	hold(player, data, amount)
	Analytics.event(player, "AuctionBid", amount)
	-- the paddle goes up and the bid's called out; Goldie takes it
	paddleNumber(player)
	current.last = { at = t, userId = player.UserId, previous = previous and previous.userId }
	board:SetAttribute("BidderId", player.UserId)
	if player.Character then
		player.Character:SetAttribute("PaddleCall", amount)
		player.Character:SetAttribute("PaddleUp", t)
	end
	if previous then
		refund(previous.userId, previous.amount)
		local outbid = playerOf(previous.userId)
		if outbid then
			local what = AuctionRules.describe(lot)
			Notice.send(outbid, `🔨 Outbid on the {what.name}! Your {coins(previous.amount)} coins are back. Bid again in the Auction House!`, "Error")
		end
	end
	if lot.endsAt > endsBefore then
		board:SetAttribute("Snipe", (board:GetAttribute("Snipe") or 0) + 1) -- (the clients flash the clock)
	end
	publish()
	return nil, { amount = amount }
end

------------------------------------------------------------------------

-- Calls callback(player, data, lot, amount) when someone wins a lot (the
-- daily quests).
function AuctionService.OnWon(callback)
	table.insert(wonCallbacks, callback)
end

-- Dev command /auction now: an auction starts this moment (off the clock).
function AuctionService.DevStart()
	local t = now()
	if current and current.phase ~= "Done" then
		local lot = current.lots[current.k]
		local top = current.phase == "Open" and AuctionRules.leader(lot)
		if top then
			refund(top.userId, top.amount)
		end
	end
	startAuction(AuctionRules.index(t), t)
end

function AuctionService.Start()
	board.Parent = ReplicatedStorage
	board:SetAttribute("Lot", 0)
	board:SetAttribute("Phase", "")
	ActionRemote(Remotes.func("AuctionAction"), actions, DataService, 0.25)
	setUpBenches()

	-- Leaving: your bids go; if you led, your coins go back into your save
	-- before it closes, and the next bidder who can still pay leads (their
	-- coins go back into escrow).
	DataService.BeforeRelease(function(player, data)
		local lot = lotNow()
		if not lot then
			return
		end
		local top = AuctionRules.leader(lot)
		if top and top.userId == player.UserId then
			data.coins += top.amount -- (straight into the save: it's closing)
			data.auctionHeld = math.max(0, (data.auctionHeld or 0) - top.amount)
			if RunService:IsStudio() then
				print(`[Auction] {player.Name} left leading the {AuctionRules.describe(lot).name}: {coins(top.amount)} back in their save ({coins(data.coins)})`)
			end
		end
		local leader = AuctionRules.bidderLeft(lot, player.UserId, function(userId, amount)
			local other = playerOf(userId)
			local otherData = other and DataService.Get(other)
			return other ~= nil and other ~= player and otherData ~= nil and hold(other, otherData, amount)
		end)
		if leader then
			local other = playerOf(leader.userId)
			if other then
				Notice.send(other, `🔨 {player.DisplayName} left: you lead the {AuctionRules.describe(lot).name} again at {coins(leader.amount)}.`, "Good")
			end
		end
		task.defer(publish)
	end)

	-- Coins a lead held when the player's last server closed (an update, a
	-- crash) come back on their next join: no lot here can be theirs yet.
	DataService.OnLoaded(function(player, data)
		local held = data.auctionHeld or 0
		if held <= 0 then
			return
		end
		refund(player.UserId, held)
		task.delay(6, function()
			Notice.send(player, `🔨 The {coins(held)} coins you'd bid at the Auction House when your last server closed are back.`, "Good")
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(tick)
			if not ok then
				warn(`[AuctionService] {err}`)
			end
		end
	end)
end

return AuctionService
