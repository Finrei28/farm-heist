-- Player-to-player trading (docs/GameDesign.md §4.13; shared/TradeRules, the
-- client's TradeController), in person: only with someone within
-- TradeRules.NEAR_DISTANCE (20 studs), and walking more than APART_DISTANCE
-- (40) apart cancels it. A structured window (no chat needed):
--   Request (the Trade crate's list of players near you, or [T] by them)
--   → they Accept within 30 s → both offer up to 8 stacks (barn crops,
--     seeds) and coins → both Ready → a 5 s countdown (any change resets
--     it) → both Confirm → the swap (TradeRules.swap: everything or
--     nothing), both saves written straight away, and the trade logged.
-- Trading unlocks after an hour of play (playSeconds; Studio skips this for
-- testing), and a player's Trade requests setting can turn requests off.
--
-- ProfileStore session-locks each save, so crops can't be copied by
-- hopping servers mid-trade.
--
-- Support (the owner, anyone in Util/Staff, anyone in Studio) can undo a
-- trade from chat, in live servers too:
--   /trades <name or userId>          their last trades, numbered
--   /rollback <name or userId> <n>    undo their trade number n
-- Undoing (TradeRules.reverse, once per trade) gives each player back what
-- they gave and takes what they got (or what it was worth, if it's gone).
-- It's queued in the log store for each player and applied when their save
-- is open: now if they're on this server, on the server they're on (via
-- MessagingService), or when they next join. (Tide Market's pattern.)
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local TradeRules = require(Shared.TradeRules)

local ActionRemote = require(script.Parent.Parent.Util.ActionRemote)
local Analytics = require(script.Parent.Parent.Util.Analytics)
local Notice = require(script.Parent.Parent.Util.Notice)
local Staff = require(script.Parent.Parent.Util.Staff)
local DataService = require(script.Parent.DataService)
local MarketService = require(script.Parent.MarketService)
local MovementService = require(script.Parent.MovementService)

local TradeEvent = Remotes.event("TradeEvent")

local TradeService = {}

local REQUEST_COOLDOWN = 8 -- seconds before asking the same player again
local LOG_STORE = "TradeLog_v1"
local LOG_PER_PLAYER = 30 -- recent trades kept in each player's history
local UNDO_TOPIC = "TradeUndo" -- MessagingService: { userId } has an undo waiting

local trades = {} -- [Player] = trade (both players point at the same one)
local invites = {} -- [target Player] = { [from Player] = os.clock() sent }
local lastAsked = {} -- [from Player] = { [target userId] = os.clock() }

-- trade = {
--   id, a, b (Players), offers = { [Player] = TradeRules offer },
--   ready = { [Player] = true }, confirmed = { [Player] = true },
--   phase = "editing" | "countdown" | "confirm" | "closed",
--   endsAt (server time the countdown ends), version (bumped on any change)
-- }

local function canTrade(player): boolean
	local data = DataService.Get(player)
	return data ~= nil and (RunService:IsStudio() or TradeRules.unlocked(data.playSeconds))
end

local function nearEachOther(a, b, limit: number?): boolean
	return TradeRules.near(MovementService.positionOf(a), MovementService.positionOf(b), limit)
end

local function other(trade, player)
	return if trade.a == player then trade.b else trade.a
end

local function side(player, offer)
	return { data = DataService.Get(player), offer = offer }
end

-- What `player` sees of the trade: both offers with their values now.
local function viewFor(trade, player)
	local priceOf = MarketService.priceAt()
	local them = other(trade, player)
	local function half(who)
		local offer = trade.offers[who]
		local lines = {}
		for _, line in offer.lines do
			table.insert(lines, { kind = line.kind, key = line.key, count = line.count, value = TradeRules.lineValue(line, priceOf) })
		end
		return {
			lines = lines,
			coins = offer.coins,
			value = TradeRules.offerValue(offer, priceOf),
			ready = trade.ready[who] == true,
			confirmed = trade.confirmed[who] == true,
		}
	end
	local view = { id = trade.id, phase = trade.phase, endsAt = trade.endsAt, you = half(player), them = half(them) }
	view.them.userId = them.UserId
	view.them.name = them.DisplayName
	return view
end

local function push(trade)
	for _, player in { trade.a, trade.b } do
		TradeEvent:FireClient(player, { kind = "state", trade = viewFor(trade, player) })
	end
end

-- Any change to an offer: everyone has to look again.
local function changed(trade)
	trade.version += 1
	trade.ready = {}
	trade.confirmed = {}
	trade.phase = "editing"
	trade.endsAt = nil
	push(trade)
end

local function close(trade, reasons)
	if trade.phase == "closed" then
		return
	end
	trade.phase = "closed"
	for _, player in { trade.a, trade.b } do
		if trades[player] == trade then
			trades[player] = nil
		end
		if player.Parent then
			TradeEvent:FireClient(player, { kind = "closed", reason = reasons[player] })
		end
	end
end

-- Writes both saves now (instead of waiting for the autosave), so a server
-- crash right after can't leave one side saved and the other not.
local function saveNow(player)
	local profile = DataService.GetProfile(player)
	if profile and profile:IsActive() then
		task.spawn(pcall, profile.Save, profile)
	end
end

local function logStore(): DataStore?
	local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, LOG_STORE)
	return if ok then store else nil
end

-- A record of the trade: in full under its id, and in each player's recent
-- history (for support, and to undo one if ever needed).
local function log(trade, gave)
	local record = {
		id = trade.id,
		time = os.time(),
		a = { userId = trade.a.UserId, lines = gave[trade.a].lines, coins = gave[trade.a].coins },
		b = { userId = trade.b.UserId, lines = gave[trade.b].lines, coins = gave[trade.b].coins },
	}
	print(`[TradeService] trade {trade.id}: {trade.a.Name} gave {#record.a.lines} stacks + {record.a.coins} coins, `
		.. `{trade.b.Name} gave {#record.b.lines} stacks + {record.b.coins} coins`)
	task.spawn(function()
		local store = logStore()
		if not store then
			return -- (Studio without API access)
		end
		pcall(store.SetAsync, store, `Trade_{trade.id}`, record)
		for _, userId in { trade.a.UserId, trade.b.UserId } do
			pcall(store.UpdateAsync, store, `User_{userId}`, function(history)
				history = history or {}
				table.insert(history, 1, { id = trade.id, time = record.time, with = if userId == trade.a.UserId then trade.b.UserId else trade.a.UserId })
				while #history > LOG_PER_PLAYER do
					table.remove(history)
				end
				return history
			end)
		end
	end)
end

local MESSAGES = {
	Gone = "a stack in the trade isn't all there any more",
	NotEnoughCoins = "there aren't enough coins for that offer",
	InDebt = "coins can't be traded while you owe a debt",
	BarnFull = "there isn't room in the barn",
	Empty = "nothing has been offered yet",
}

local function execute(trade)
	local a, b = trade.a, trade.b
	local dataA, dataB = DataService.Get(a), DataService.Get(b)
	if not (dataA and dataB) then
		return close(trade, { [a] = "The trade was cancelled.", [b] = "The trade was cancelled." })
	end
	-- What each gives, for the log and the messages (before it moves).
	local priceOf = MarketService.priceAt()
	local gave = {
		[a] = { lines = TradeRules.logLines(trade.offers[a], priceOf), coins = trade.offers[a].coins },
		[b] = { lines = TradeRules.logLines(trade.offers[b], priceOf), coins = trade.offers[b].coins },
	}
	local ok, reason, which = TradeRules.swap(side(a, trade.offers[a]), side(b, trade.offers[b]))
	if not ok then
		local who = if which == "a" then a else b
		local why = MESSAGES[reason] or "something changed"
		for _, player in { a, b } do
			TradeEvent:FireClient(player, {
				kind = "problem",
				text = if player == who then `Couldn't trade: {why} (yours).` else `Couldn't trade: {why} ({who.DisplayName}'s).`,
			})
		end
		changed(trade)
		return
	end

	trade.phase = "closed"
	trades[a], trades[b] = nil, nil
	for _, player in { a, b } do
		DataService.AddCoins(player, 0) -- (refreshes the coin leaderstat and the state)
		saveNow(player)
	end
	log(trade, gave)
	for _, player in { a, b } do
		local data = DataService.Get(player)
		local net = gave[other(trade, player)].coins - gave[player].coins
		if data and net ~= 0 then
			Analytics.coins(player, net, data.coins, Analytics.GAMEPLAY, "Trade")
		end
		Analytics.event(player, "TradeCompleted")
	end
	for _, player in { a, b } do
		local them = other(trade, player)
		local got = gave[them]
		local value = got.coins
		for _, line in got.lines do
			value += line.value
		end
		TradeEvent:FireClient(player, { kind = "closed", done = true, with = them.DisplayName, lines = got.lines, coins = got.coins, value = value })
	end
end

local function startTrade(a, b)
	local trade = {
		id = HttpService:GenerateGUID(false),
		a = a,
		b = b,
		offers = { [a] = TradeRules.newOffer(), [b] = TradeRules.newOffer() },
		ready = {},
		confirmed = {},
		phase = "editing",
		version = 0,
	}
	trades[a], trades[b] = trade, trade
	invites[a], invites[b] = nil, nil
	push(trade)
end

local function playerFrom(arg): Player?
	local userId = tonumber(arg)
	return userId and Players:GetPlayerByUserId(userId)
end

local ACTIONS = {}

-- arg: the other player's UserId.
function ACTIONS.Request(player, _data, arg)
	local target = playerFrom(arg)
	if not target or target == player then
		return "NotFound"
	end
	local targetData = DataService.Get(target)
	if not targetData then
		return "NotFound"
	elseif not canTrade(player) then
		return "TradeLocked"
	elseif not canTrade(target) then
		return "TheyLocked"
	elseif trades[player] then
		return "Busy"
	elseif trades[target] then
		return "TheyBusy"
	elseif targetData.settings.trades == false then
		return "TheyDisabled"
	elseif not nearEachOther(player, target) then
		return "TooFar"
	end
	-- They asked you first: that's a yes.
	local theirs = invites[player] and invites[player][target]
	if theirs and os.clock() - theirs < TradeRules.REQUEST_SECONDS then
		startTrade(target, player)
		return nil
	end
	local asked = lastAsked[player] or {}
	lastAsked[player] = asked
	if asked[target.UserId] and os.clock() - asked[target.UserId] < REQUEST_COOLDOWN then
		return "Cooldown"
	end
	asked[target.UserId] = os.clock()
	invites[target] = invites[target] or {}
	invites[target][player] = os.clock()
	TradeEvent:FireClient(target, { kind = "invite", userId = player.UserId, name = player.DisplayName, seconds = TradeRules.REQUEST_SECONDS })
	return nil
end

-- arg: the UserId of who asked.
function ACTIONS.Accept(player, _data, arg)
	local from = playerFrom(arg)
	local sent = from and invites[player] and invites[player][from]
	if not sent or os.clock() - sent > TradeRules.REQUEST_SECONDS + 2 then
		return "Expired"
	end
	invites[player][from] = nil
	if trades[player] then
		return "Busy"
	elseif trades[from] then
		return "TheyBusy"
	elseif not (canTrade(player) and canTrade(from)) then
		return "TradeLocked"
	elseif not nearEachOther(player, from) then
		return "TooFar"
	end
	startTrade(from, player)
	return nil
end

function ACTIONS.Decline(player, _data, arg)
	local from = playerFrom(arg)
	if from and invites[player] and invites[player][from] then
		invites[player][from] = nil
		TradeEvent:FireClient(from, { kind = "declined", name = player.DisplayName })
	end
	return nil
end

-- The rest act on your open trade.
local function myTrade(player)
	local trade = trades[player]
	if not trade or trade.phase == "closed" then
		return nil
	end
	return trade
end

-- arg: "crop|Carrot|||12" or "seed|Corn|3" (kind, key, count; 0 takes it out).
function ACTIONS.Set(player, data, arg)
	local trade = myTrade(player)
	if not trade then
		return "NoTrade"
	end
	local kind, key, count = string.match(arg or "", "^(%a+)|(.+)|(%d+)$")
	local failure = TradeRules.setLine(trade.offers[player], data, kind, key, tonumber(count))
	if failure then
		return failure
	end
	changed(trade)
	return nil
end

-- arg: how many coins to offer (replaces the amount).
function ACTIONS.Coins(player, data, arg)
	local trade = myTrade(player)
	if not trade then
		return "NoTrade"
	end
	local amount, failure = TradeRules.cleanCoins(tonumber(arg), data)
	if not amount then
		return failure
	end
	if amount ~= trade.offers[player].coins then
		trade.offers[player].coins = amount
		changed(trade)
	end
	return nil
end

-- arg: "1" ready, "0" not.
function ACTIONS.Ready(player, data, arg)
	local trade = myTrade(player)
	if not trade then
		return "NoTrade"
	end
	if arg ~= "1" then
		if trade.ready[player] then
			changed(trade) -- (back to editing for both)
		end
		return nil
	end
	local them = other(trade, player)
	-- (a problem on your side is yours to fix first; theirs shows at Confirm)
	local reason, which = TradeRules.check({ data = data, offer = trade.offers[player] }, side(them, trade.offers[them]))
	if reason == "Empty" or (reason and which == "a") then
		return reason
	end
	trade.ready[player] = true
	if trade.ready[trade.a] and trade.ready[trade.b] and trade.phase == "editing" then
		trade.phase = "countdown"
		trade.endsAt = workspace:GetServerTimeNow() + TradeRules.COUNTDOWN
		local version = trade.version
		task.delay(TradeRules.COUNTDOWN, function()
			if trade.version == version and trade.phase == "countdown" then
				trade.phase = "confirm"
				push(trade)
			end
		end)
	end
	push(trade)
	return nil
end

function ACTIONS.Confirm(player)
	local trade = myTrade(player)
	if not trade then
		return "NoTrade"
	elseif trade.phase ~= "confirm" then
		return "NotYet"
	end
	trade.confirmed[player] = true
	if trade.confirmed[trade.a] and trade.confirmed[trade.b] then
		execute(trade)
	else
		push(trade)
	end
	return nil
end

function ACTIONS.Cancel(player)
	local trade = trades[player]
	if trade then
		local them = other(trade, player)
		close(trade, { [player] = "You cancelled the trade.", [them] = `{player.DisplayName} cancelled the trade.` })
	end
	return nil
end

---------------------------------------------------------------------------
-- Undoing trades (support)

-- Applies any undo waiting for this player (their save is open here). Each
-- is marked in the save, so applying one twice does nothing; the queue entry
-- is cleared only after the save is written.
local applying = {}
local function applyPending(player)
	local store = logStore()
	local data = DataService.Get(player)
	if not (store and data) or applying[player] then
		return
	end
	applying[player] = true
	local ok, pending = pcall(store.GetAsync, store, `Undo_{player.UserId}`)
	if ok and type(pending) == "table" and #pending > 0 then
		local done = {}
		for _, undo in pending do
			local report = TradeRules.reverse(data, undo)
			done[undo.tradeId] = true
			if report then
				print(`[TradeService] undid trade {undo.tradeId} for {player.Name}: took {report.taken} back, `
					.. `charged {report.charged} coins for what was gone, gave back {report.returned}, coins {report.coins}`
					.. (if report.shortfall > 0 then ` (short {report.shortfall})` else ""))
				Notice.send(player, "Support undid one of your trades: what you gave is back, and what you got has gone back.")
			end
		end
		local trade = trades[player]
		if trade then
			close(trade, { [player] = "The trade was cancelled.", [other(trade, player)] = "The trade was cancelled." })
		end
		DataService.AddCoins(player, 0)
		local profile = DataService.GetProfile(player)
		if profile and profile:IsActive() then
			pcall(profile.Save, profile)
		end
		pcall(store.UpdateAsync, store, `Undo_{player.UserId}`, function(list)
			local left = {}
			for _, undo in list or {} do
				if not done[undo.tradeId] then
					table.insert(left, undo)
				end
			end
			return left
		end)
	end
	applying[player] = nil
end

-- Undoes a logged trade for both players. Returns (ok, message).
function TradeService.Rollback(tradeId: string): (boolean, string)
	local store = logStore()
	if not store then
		return false, "The trade log isn't available here (turn on Studio API access)."
	end
	local record, already = nil, false
	local ok, err = pcall(store.UpdateAsync, store, `Trade_{tradeId}`, function(current)
		if type(current) ~= "table" then
			return nil
		end
		record = current
		if current.undone then
			already = true
			return nil
		end
		current.undone = os.time()
		return current
	end)
	if not ok then
		return false, `Couldn't read the trade log: {err}`
	elseif not record then
		return false, "No trade with that id in the log."
	elseif already then
		return false, "That trade has already been undone."
	end
	for _, userId in { record.a.userId, record.b.userId } do
		local undo = TradeRules.undoFor(record, userId)
		pcall(store.UpdateAsync, store, `Undo_{userId}`, function(list)
			list = list or {}
			table.insert(list, undo)
			return list
		end)
		local here = Players:GetPlayerByUserId(userId)
		if here then
			task.spawn(applyPending, here)
		else
			pcall(MessagingService.PublishAsync, MessagingService, UNDO_TOPIC, { userId = userId })
		end
	end
	return true, "Undone: both players get back what they gave (now if they're online, or when they next join)."
end

local function userIdFrom(text: string?): number?
	if not text then
		return nil
	end
	local number = tonumber(text)
	if number then
		return number
	end
	for _, someone in Players:GetPlayers() do
		if string.lower(someone.Name) == string.lower(text) or string.lower(someone.DisplayName) == string.lower(text) then
			return someone.UserId
		end
	end
	local ok, userId = pcall(Players.GetUserIdFromNameAsync, Players, text)
	return if ok then userId else nil
end

local function history(userId: number)
	local store = logStore()
	if not store then
		return nil
	end
	local ok, list = pcall(store.GetAsync, store, `User_{userId}`)
	return if ok then (list or {}) else nil
end

local function nameOf(userId: number): string
	local someone = Players:GetPlayerByUserId(userId)
	if someone then
		return someone.Name
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	return if ok then name else tostring(userId)
end

local function supportCommand(name: string, alias: string, handler)
	local command = Instance.new("TextChatCommand")
	command.Name = name
	command.PrimaryAlias = alias
	command.AutocompleteVisible = false
	command.Triggered:Connect(function(source, text)
		local player = Players:GetPlayerByUserId(source.UserId)
		if not (player and Staff.isStaff(player)) then
			return
		end
		local args = {}
		for word in string.gmatch(text, "%S+") do
			table.insert(args, word)
		end
		Notice.send(player, handler(args))
	end)
	command.Parent = TextChatService
end

local function startSupport()
	-- /trades <name or userId>: their last 8 trades, newest first.
	supportCommand("TradesCommand", "/trades", function(args)
		local userId = userIdFrom(args[2])
		if not userId then
			return "Usage: /trades <name or userId>"
		end
		local list = history(userId)
		if not list then
			return "The trade log isn't available here."
		elseif #list == 0 then
			return `{nameOf(userId)} has no trades logged.`
		end
		local lines = { `{nameOf(userId)}'s trades, newest first (/rollback {userId} n to undo one):` }
		for index = 1, math.min(8, #list) do
			local entry = list[index]
			table.insert(lines, `{index}. {os.date("!%Y-%m-%d %H:%M", entry.time)} UTC with {nameOf(entry.with)}`)
		end
		return table.concat(lines, "\n")
	end)
	-- /rollback <name or userId> <n>: undo their trade number n from /trades.
	supportCommand("RollbackCommand", "/rollback", function(args)
		local userId = userIdFrom(args[2])
		local index = tonumber(args[3])
		if not (userId and index) then
			return "Usage: /rollback <name or userId> <n>   (n from /trades)"
		end
		local list = history(userId)
		local entry = list and list[index]
		if not entry then
			return `No trade number {index} for {nameOf(userId)}. Check /trades {userId}.`
		end
		local _, message = TradeService.Rollback(entry.id)
		return message
	end)

	-- An undo for someone on this server, queued by another one.
	task.spawn(pcall, MessagingService.SubscribeAsync, MessagingService, UNDO_TOPIC, function(message)
		local data = message.Data
		local someone = type(data) == "table" and Players:GetPlayerByUserId(data.userId)
		if someone then
			applyPending(someone)
		end
	end)
	-- ... and any waiting when a player joins.
	DataService.OnLoaded(function(player)
		applyPending(player)
	end)
end

-- (a trade's offers as a line for tests and /state)
function TradeService.Describe(player: Player): string?
	local trade = trades[player]
	if not trade then
		return nil
	end
	local offer = trade.offers[player]
	local parts = {}
	for _, line in offer.lines do
		table.insert(parts, `{line.count} {line.key}`)
	end
	return `trading with {other(trade, player).DisplayName}: {table.concat(parts, ", ")} + {Format.number(offer.coins)} coins ({trade.phase})`
end

function TradeService.Start()
	startSupport()
	ActionRemote(Remotes.func("TradeAction"), ACTIONS, DataService, 0.1)

	-- (someone leaving mid-trade: it's off, and nothing has moved)
	Players.PlayerRemoving:Connect(function(player)
		local trade = trades[player]
		if trade then
			close(trade, { [other(trade, player)] = `{player.DisplayName} left, so the trade was cancelled.` })
		end
		invites[player] = nil
		lastAsked[player] = nil
		for _, list in invites do
			list[player] = nil
		end
	end)

	-- In person: walking well apart ends it. And a stack sold, packed or
	-- planted meanwhile comes out of the offer (both have to look again).
	task.spawn(function()
		while true do
			task.wait(1)
			local checked = {}
			for _, trade in trades do
				if not checked[trade] and trade.phase ~= "closed" then
					checked[trade] = true
					if not nearEachOther(trade.a, trade.b, TradeRules.APART_DISTANCE) then
						local text = "You walked too far apart, so the trade was cancelled."
						close(trade, { [trade.a] = text, [trade.b] = text })
					else
						local moved = false
						for _, player in { trade.a, trade.b } do
							local data = DataService.Get(player)
							if data and TradeRules.clamp(trade.offers[player], data) then
								moved = true
							end
						end
						if moved then
							changed(trade)
						end
					end
				end
			end
		end
	end)
end

return TradeService
