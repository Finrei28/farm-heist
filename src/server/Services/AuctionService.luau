-- The Cloverdale Auction House (docs/GameDesign.md §4.4; the rules in
-- shared/AuctionRules, the hall in World/AuctionArt). An auction starts
-- every 8 minutes on the clock: three lots, one after another, about a
-- minute each and 10 s between them. Every server rolls its own lots.
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
-- Goldie Gavel calls "Going once... going twice... SOLD!" in the last
-- seconds.
--
-- Clients see it on ReplicatedStorage.Auction's attributes:
--   Index    the auction's number (AuctionRules.index), Lot 1–3 (0: none on)
--   Lots     JSON: { { kind, id, estimate } } for this auction
--   Phase    "Open" (bidding) · "Sold" (the 10 s after a lot) · "" between auctions
--   Bid, Leader (name), LeaderId, MinBid, Opening, EndsAt (server time), Snipe (a late bid's count)
--   Call     Goldie's call now ("Going once..."), SoldTo, SoldFor (the last lot)
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
local current = nil -- { index, lots, k, phase = "Open" | "Sold" | "Done", gapUntil }
local wonCallbacks = {}

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

local function openLot(t: number)
	AuctionRules.open(current.lots[current.k], t)
	current.phase = "Open"
	current.called = 0
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
	board:SetAttribute("Call", if top then "SOLD!" else "No bids: back to the vault!")
	local winner = top and playerOf(top.userId)
	board:SetAttribute("SoldTo", if winner then winner.DisplayName else "")
	board:SetAttribute("SoldFor", if top then top.amount else 0)
	if top and winner then
		local data = DataService.Get(winner)
		if data and deliver(winner, data, lot, top.amount) then
			Notice.send(winner, `🔨 SOLD to you! {what.icon} {what.name} for {coins(top.amount)}: {whereItGoes(lot)}.`, "Good")
			Analytics.event(winner, "AuctionWon", top.amount)
			for _, callback in wonCallbacks do
				task.spawn(callback, winner, data, lot, top.amount)
			end
			if lot.kind == "Seed" and (lot.rarity == "Mythic" or lot.rarity == "Legendary") then
				for _, other in Players:GetPlayers() do
					if other ~= winner then
						Notice.send(other, `🔨 {winner.DisplayName} won a {what.name} at the Auction House for {coins(top.amount)}!`, "Announce")
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
		-- Goldie's calls in the last seconds (a late bid puts the clock back)
		local call = if left <= 2.5 then Auction.CALLS[2] elseif left <= 5 then Auction.CALLS[1] else ""
		if #lot.bids == 0 then
			call = if left <= 5 then "Any bids? Anyone?" else ""
		end
		if board:GetAttribute("Call") ~= call then
			board:SetAttribute("Call", call)
		end
		if left <= 0 then
			closeLot(t)
		end
	elseif current.phase == "Sold" and t >= current.gapUntil then
		if current.k >= #current.lots then
			current.phase = "Done"
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
