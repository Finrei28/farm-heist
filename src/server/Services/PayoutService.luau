-- Debts (docs/GameDesign.md §4.12). An unpaid fine is owed to the farmer who
-- made the arrest; half of the thief's sales income pays it off
-- (shared/FineRules.garnish, through DataService.Garnish). An owner in this
-- server is paid at once; anyone else through the payout queue
-- (shared/PayoutRules: DataStore Payouts_v1, key Owner_<userId>), batched to
-- one record per owner every 5 minutes. Owners collect their queue when
-- they join and every few minutes while they play. The police desk on the
-- porch (PoliceAction "Pay") pays debts early.
--
-- In Studio without API access the DataStore calls fail: payments wait in
-- memory and are tried again (both players are usually in one server there).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local FineRules = require(Shared.FineRules)
local PayoutRules = require(Shared.PayoutRules)
local Remotes = require(Shared.Remotes)

local Server = ServerScriptService.Server
local ActionRemote = require(Server.Util.ActionRemote)
local Analytics = require(Server.Util.Analytics)
local Notice = require(Server.Util.Notice)
local DataService = require(script.Parent.DataService)

local PayoutService = {}

local FLUSH_EVERY = 30 -- seconds between looks at the batches waiting
local CLAIM_EVERY = 300 -- seconds between checks of an online owner's queue
local NOTE_GAP = 30 -- seconds between notes about debt payments (store sales come every few seconds)

local pending = {} -- ["debtorId"] = PayoutRules pending batches
local notes = {} -- ["userId:Paid" or "userId:Got"] = { amount, at }: debt payments not yet told about
local serial = 0
local store = nil

local function storeOf()
	if not store then
		local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, "Payouts_v1")
		store = if ok then result else nil
	end
	return store
end

local function keyFor(ownerId: number): string
	return `Owner_{ownerId}`
end

local function ownerHere(ownerId: number): Player?
	local owner = Players:GetPlayerByUserId(ownerId)
	return if owner and DataService.Get(owner) then owner else nil
end

-- Tells someone about debt payments, at most every NOTE_GAP seconds
-- (summed up meanwhile): a debtor what their sales paid, an owner what came in.
local function note(player: Player, role: string, amount: number, text: (number) -> string)
	local key = `{player.UserId}:{role}`
	local entry = notes[key] or { amount = 0, at = -math.huge }
	notes[key] = entry
	entry.amount += amount
	if os.clock() - entry.at >= NOTE_GAP then
		Notice.send(player, text(entry.amount), "Good")
		entry.amount, entry.at = 0, os.clock()
	end
end

-- One payment to an owner: now if they're here, else into the batch.
local function pay(debtorId: number, ownerId: number, amount: number)
	if amount <= 0 then
		return
	end
	local owner = ownerHere(ownerId)
	if owner then
		DataService.AddCoins(owner, amount, Analytics.GAMEPLAY, "DebtPayment")
		local debtor = Players:GetPlayerByUserId(debtorId)
		local name = if debtor then debtor.DisplayName else "A thief you arrested"
		note(owner, "Got", amount, function(total)
			return `💰 {name} paid you {total} coins of their fine.`
		end)
		return
	end
	local key = tostring(debtorId)
	pending[key] = pending[key] or {}
	PayoutRules.addPending(pending[key], ownerId, amount, os.time())
end

-- Writes the batches that are due (all of a debtor's when `all`). Yields.
local function flush(debtorKey: string?, all: boolean?)
	local ds = storeOf()
	for key, batches in pending do
		if debtorKey and key ~= debtorKey then
			continue
		end
		for _, due in PayoutRules.due(batches, os.time(), all) do
			local owner = ownerHere(due.ownerId)
			if owner then
				DataService.AddCoins(owner, due.amount, Analytics.GAMEPLAY, "DebtPayment") -- (they've arrived since)
				continue
			end
			serial += 1
			local record = PayoutRules.record(tonumber(key) :: number, due.amount, os.time(), serial)
			local ok = ds ~= nil and pcall(ds.UpdateAsync, ds, keyFor(due.ownerId), function(queue)
				return PayoutRules.append(queue, record, os.time())
			end)
			if not ok then
				-- (try again later)
				PayoutRules.addPending(batches, due.ownerId, due.amount, os.time() - 240)
			end
		end
		if next(batches) == nil then
			pending[key] = nil
		end
	end
end

-- Collects what debtors in other servers have paid this owner. Yields.
local function claim(player: Player)
	local ds = storeOf()
	local data = DataService.Get(player)
	if not ds or not data then
		return
	end
	local ok, queue = pcall(ds.GetAsync, ds, keyFor(player.UserId))
	if not ok or typeof(queue) ~= "table" or #queue == 0 then
		return
	end
	data = DataService.Get(player)
	if not data then
		return
	end
	local total, ids = PayoutRules.unclaimed(queue, data.payoutsClaimed)
	if total > 0 then
		PayoutRules.claim(data.payoutsClaimed, ids, os.time())
		DataService.AddCoins(player, total, Analytics.GAMEPLAY, "DebtPayment")
		Notice.send(player, `💰 Thieves you arrested paid off {total} coins of their fines.`, "Good")
	end
	PayoutRules.pruneClaimed(data.payoutsClaimed, os.time())
	local claimed = data.payoutsClaimed
	pcall(ds.UpdateAsync, ds, keyFor(player.UserId), function(current)
		return PayoutRules.withoutClaimed(current, claimed, os.time())
	end)
end

-- DataService.Garnish: half of a debtor's income goes to their debts.
local function garnish(player: Player, data, coins: number): number
	local before = FineRules.totalDebt(data.crime, os.time())
	if before <= 0 then
		return coins
	end
	local kept, payments = FineRules.garnish(data.crime, coins, os.time())
	for key, amount in payments do
		pay(player.UserId, tonumber(key) :: number, amount)
	end
	local left = FineRules.totalDebt(data.crime, os.time())
	if left <= 0 then
		Notice.send(player, "Debt paid off! You keep all your sales again.", "Good")
	else
		note(player, "Paid", coins - kept, function(total)
			return `{total} coins of your sales went to your debts ({left} left to pay).`
		end)
	end
	return kept
end

local actions = {}

-- "all" or a number of coins: pays debts early, oldest first.
function actions.Pay(player, data, arg)
	local total = FineRules.totalDebt(data.crime, os.time())
	if total <= 0 then
		return "NoDebt"
	end
	local amount = if arg == "all" then total else math.floor(tonumber(arg) or 0)
	amount = math.min(amount, total, data.coins)
	if amount <= 0 then
		return "NoCoins"
	end
	if not DataService.SpendCoins(player, amount, Analytics.GAMEPLAY, "DebtPayment") then
		return "NoCoins"
	end
	local change, payments = FineRules.payEarly(data.crime, amount, os.time())
	if change > 0 then
		DataService.AddCoins(player, change, Analytics.GAMEPLAY, "DebtChange")
	end
	for key, paid in payments do
		pay(player.UserId, tonumber(key) :: number, paid)
	end
	local left = FineRules.totalDebt(data.crime, os.time())
	Notice.send(player, if left > 0 then `Paid {amount - change} coins. You still owe {left}.` else "All paid off! You keep all your sales again.", "Good")
	return nil
end

function PayoutService.Start()
	DataService.Garnish = garnish
	ActionRemote(Remotes.func("PoliceAction"), actions, DataService, 0.5)

	DataService.OnLoaded(function(player)
		task.spawn(claim, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		notes[`{player.UserId}:Got`], notes[`{player.UserId}:Paid`] = nil, nil
		task.spawn(flush, tostring(player.UserId), true)
	end)
	game:BindToClose(function()
		flush(nil, true)
	end)

	-- The police desk on the porch opens the Police Desk window.
	local desk = workspace.World.Town:FindFirstChild("PoliceDesk", true)
	if desk then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PolicePrompt"
		prompt.ActionText = "Police desk"
		prompt.ObjectText = "Sheriff Clucks"
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Opens", "PoliceDesk") -- (the client opens the window)
		prompt.Parent = desk
	end

	task.spawn(function()
		local sinceClaim = 0
		while true do
			task.wait(FLUSH_EVERY)
			flush(nil, false)
			sinceClaim += FLUSH_EVERY
			if sinceClaim >= CLAIM_EVERY then
				sinceClaim = 0
				for _, player in Players:GetPlayers() do
					task.spawn(claim, player)
				end
			end
		end
	end)
end

return PayoutService
