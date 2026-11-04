-- The Cloverdale Auction House (docs/GameDesign.md §4.4): an auction every
-- 8 minutes on the clock, 5 lots of about a minute each. Bids are escrowed
-- by AuctionService (taken from the wallet, given back when outbid); these
-- rules decide what's a valid bid, the anti-snipe clock, and who leads when
-- the leader leaves the server. tests/auction.test.luau.
--
-- lot = { kind, id, rarity?, estimate, opening, bids = { { userId, amount } }, endsAt, sold }
-- bids only ever go up, so the last one leads.
local Config = require(script.Parent.Config.Auction)
local Crops = require(script.Parent.Config.Crops)
local DefenceRules = require(script.Parent.DefenceRules)
local Defences = require(script.Parent.Config.Defences)
local Format = require(script.Parent.Format)
local Rarities = require(script.Parent.Config.Rarities)
local WorkerRules = require(script.Parent.WorkerRules)
local Workers = require(script.Parent.Config.Workers)

local AuctionRules = {}

-- The bid step for an amount this size (Config.STEPS).
function AuctionRules.step(amount: number): number
	for _, entry in Config.STEPS do
		if not entry.below or amount < entry.below then
			return entry.step
		end
	end
	return Config.STEPS[#Config.STEPS].step
end

local function roundUp(amount: number): number
	local step = AuctionRules.step(amount)
	return math.ceil(amount / step) * step
end

-- One of `options` by their weights (each 1 if it has none).
local function weighted(rng, options)
	local total = 0
	for _, option in options do
		total += option.weight or 1
	end
	local pick = rng:NextNumber() * total
	for _, option in options do
		pick -= option.weight or 1
		if pick < 0 then
			return option
		end
	end
	return options[#options]
end

-- The auction that's on (or last started) and when the next one starts.
function AuctionRules.index(now: number): number
	return now // Config.INTERVAL
end

function AuctionRules.nextAt(now: number): number
	return (now // Config.INTERVAL + 1) * Config.INTERVAL
end

-- What this auction's lots are. Every server rolls its own (seed from the
-- server and the auction index); estimates are what the lot is worth.
function AuctionRules.rollLots(seed: number)
	local rng = Random.new(seed)
	local lots = {}
	local function taken(kind: string, id: string): boolean
		for _, lot in lots do
			if lot.kind == kind and lot.id == id then
				return true
			end
		end
		return false
	end
	for _ = 1, Config.LOTS do
		local chosen = weighted(rng, Config.POOL)
		if chosen.kind == "Seed" then
			local options = {}
			for _, crop in Crops.List do
				if crop.rarity == chosen.rarity then
					table.insert(options, crop)
				end
			end
			-- (never the same lot twice in one auction: up to a few tries)
			local crop = options[rng:NextInteger(1, #options)]
			for _ = 1, 4 do
				if not taken("Seed", crop.id) then
					break
				end
				crop = options[rng:NextInteger(1, #options)]
			end
			table.insert(lots, { kind = "Seed", id = crop.id, rarity = crop.rarity, estimate = crop.seed })
		else
			local options = Config.ITEMS[chosen.kind]
			local item = weighted(rng, options)
			for _ = 1, 4 do
				if not taken(chosen.kind, item.id) then
					break
				end
				item = weighted(rng, options)
			end
			table.insert(lots, { kind = chosen.kind, id = item.id, estimate = item.estimate })
		end
	end
	return lots
end

-- Opens a lot for bidding (it runs LOT_SECONDS from `now`).
function AuctionRules.open(lot, now: number)
	lot.opening = roundUp(lot.estimate * Config.OPENING)
	lot.bids = {}
	lot.openedAt = now
	lot.endsAt = now + Config.LOT_SECONDS
	lot.sold = false
	return lot
end

-- The leading bid { userId, amount }, or nil.
function AuctionRules.leader(lot)
	return lot.bids[#lot.bids]
end

-- The lowest bid accepted now.
function AuctionRules.minBid(lot): number
	local top = AuctionRules.leader(lot)
	if not top then
		return lot.opening
	end
	return math.max(math.ceil(top.amount * (1 + Config.MIN_RAISE)), top.amount + AuctionRules.step(top.amount))
end

-- The +5% / +10% / +25% buttons.
function AuctionRules.quickBid(lot, share: number): number
	local top = AuctionRules.leader(lot)
	if not top then
		return lot.opening
	end
	return math.max(AuctionRules.minBid(lot), roundUp(top.amount * (1 + share)))
end

-- Places a bid (the service has checked the bidder is in the hall and can
-- pay). Returns ok, reason, and the previous leader to refund.
function AuctionRules.place(lot, userId: number, amount: number, now: number)
	if lot.sold or now >= lot.endsAt then
		return false, "Closed", nil
	end
	local top = AuctionRules.leader(lot)
	if top and top.userId == userId then
		return false, "AlreadyLeading", nil
	end
	if amount ~= math.floor(amount) or amount < AuctionRules.minBid(lot) then
		return false, "TooLow", nil
	end
	table.insert(lot.bids, { userId = userId, amount = amount })
	if lot.endsAt - now < Config.SNIPE then
		lot.endsAt = now + Config.SNIPE -- anti-snipe
	end
	return true, nil, top
end

-- A bidder left the server: their bids are gone. If they led, the highest
-- earlier bidder who can still pay (canPay(userId, amount), which also
-- escrows it) leads instead. Returns the new leader, or nil if nothing
-- changed or nobody can.
function AuctionRules.bidderLeft(lot, userId: number, canPay: (number, number) -> boolean)
	local top = AuctionRules.leader(lot)
	local wasLeading = top ~= nil and top.userId == userId
	for i = #lot.bids, 1, -1 do
		if lot.bids[i].userId == userId then
			table.remove(lot.bids, i)
		end
	end
	if not wasLeading or lot.sold then
		return nil
	end
	while #lot.bids > 0 do
		local candidate = lot.bids[#lot.bids]
		if canPay(candidate.userId, candidate.amount) then
			return candidate
		end
		-- Can't pay any more (spent it since): drop all their bids too.
		local gone = candidate.userId
		for i = #lot.bids, 1, -1 do
			if lot.bids[i].userId == gone then
				table.remove(lot.bids, i)
			end
		end
	end
	return nil
end

-- What a lot is, for the window, the hall's board and the notes:
-- { icon, name, detail, color? (its rarity's) }.
function AuctionRules.describe(lot)
	if lot.kind == "Seed" then
		local crop = Crops.ById[lot.id]
		local rarity = Rarities.ById[crop.rarity]
		return { icon = crop.icon or "🌱", name = `{crop.name} seed`, detail = `{crop.rarity} · plants one patch`, color = rarity.color }
	elseif lot.kind == "WorkerContract" then
		local contract = Workers.CONTRACTS[lot.id]
		local trait = Workers.TRAITS[contract.trait]
		return { icon = "📜", name = contract.name, detail = `{contract.title}, Level {contract.level} · {trait.name}: {trait.text}` }
	elseif lot.kind == "Defence" then
		local def = Defences.ITEMS[lot.id]
		return { icon = def.icon, name = def.name, detail = `A defence for your farm · from Farm Level {def.level}` }
	end
	return { icon = "📦", name = lot.id, detail = "" }
end

-- Whether a player could take this lot home if they won it: a defence
-- needs its Farm Level and room for one more, a rare worker a free slot for
-- their job. ctx = { level, defences, workers, workerCtx (WorkerRules.slots)
-- }. Returns ok, reason ("DefenceLocked" · "DefenceMax" · "NoSlot").
-- Seeds always can (a Mythic waits in the bag for Farm Level 20).
function AuctionRules.canWin(lot, ctx): (boolean, string?)
	if lot.kind == "Defence" then
		local def = Defences.ITEMS[lot.id]
		if ctx.level < def.level then
			return false, "DefenceLocked"
		elseif DefenceRules.owned(ctx.defences, lot.id) >= def.max then
			return false, "DefenceMax"
		end
	elseif lot.kind == "WorkerContract" then
		local contract = Workers.CONTRACTS[lot.id]
		if not WorkerRules.canHire(ctx.workers, contract.type, ctx.workerCtx) then
			return false, "NoSlot"
		end
	end
	return true, nil
end

------------------------------------------------------------------------
-- The room: bidder paddles and Goldie's patter

-- The bidder numbers a server hands out, in the order it hands them out:
-- 10 to 99, shuffled (the server's seed), so they look like a real
-- auction's and nobody can tell who came first. Past 90 bidders: 100 on.
function AuctionRules.paddleNumbers(seed: number): { number }
	local rng = Random.new(seed)
	local numbers = {}
	for n = 10, 99 do
		table.insert(numbers, n)
	end
	for i = #numbers, 2, -1 do
		local j = rng:NextInteger(1, i)
		numbers[i], numbers[j] = numbers[j], numbers[i]
	end
	return numbers
end

-- What Goldie Gavel says now, like a real auctioneer (her speech bubble;
-- "" for nothing). room = { k (the lot's number), name (what it is),
-- paddleOf(userId) -> number?, last = { at, userId, previous? } (the last
-- bid: when, whose, and whom it outbid) }. Returns the call and whether
-- she brings the gavel down with it ("Going once", "Going twice").
function AuctionRules.patter(lot, t: number, room): (string, boolean)
	local n = Format.number
	local left = lot.endsAt - t
	local top = AuctionRules.leader(lot)
	local function paddle(userId: number?): string
		local number = userId and room.paddleOf(userId)
		return if number then `paddle {number}` else "the bidder at the back"
	end
	if not top then
		if left <= 5 then
			return "Any bids? Anyone at all?", false
		end
		local since = t - (lot.openedAt or t)
		if since < 5 then
			return `Lot {room.k}: {room.name}! Who'll start me at {n(lot.opening)}?`, false
		elseif since % 12 < 4 then
			return `{n(lot.opening)}, anyone? It's worth {n(lot.estimate)}!`, false
		end
		return "", false
	end
	if left <= 2.5 then
		return `Going twice at {n(top.amount)}...`, true
	elseif left <= 5 then
		return `Going once at {n(top.amount)}...`, true
	end
	local ask = n(AuctionRules.quickBid(lot, Config.QUICK[1]))
	local last = room.last
	local since = if last then t - last.at else math.huge
	if since < 4 then
		if last.previous and last.previous ~= top.userId then
			return `{n(top.amount)} from {paddle(top.userId)}! Back to you, {paddle(last.previous)}: {ask}?`, false
		end
		return `{n(top.amount)} from {paddle(top.userId)}! Do I hear {ask}?`, false
	elseif since % 10 < 4 then
		return `I have {n(top.amount)} from {paddle(top.userId)}. {ask}, anyone?`, false
	end
	return "", false
end

-- Closes a lot once its clock runs out. Returns the winning bid (or nil:
-- no bids), and false if it isn't over yet.
function AuctionRules.close(lot, now: number)
	if now < lot.endsAt then
		return nil, false
	end
	lot.sold = true
	return AuctionRules.leader(lot), true
end

return AuctionRules
