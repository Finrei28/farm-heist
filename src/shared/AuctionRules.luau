-- The Cloverdale Auction House (docs/GameDesign.md §4.4): an auction every
-- 8 minutes on the clock, 3 lots of about a minute each. Bids are escrowed
-- by AuctionService (taken from the wallet, given back when outbid); these
-- rules decide what's a valid bid, the anti-snipe clock, and who leads when
-- the leader leaves the server. tests/auction.test.luau.
--
-- lot = { kind, id, rarity?, estimate, opening, bids = { { userId, amount } }, endsAt, sold }
-- bids only ever go up, so the last one leads.
local Config = require(script.Parent.Config.Auction)
local Crops = require(script.Parent.Config.Crops)

local AuctionRules = {}

local function roundUp(amount: number): number
	return math.ceil(amount / Config.ROUND_TO) * Config.ROUND_TO
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
	local total = 0
	for _, entry in Config.POOL do
		total += entry.weight
	end
	local lots = {}
	for _ = 1, Config.LOTS do
		local pick = rng:NextNumber() * total
		local chosen = Config.POOL[#Config.POOL]
		for _, entry in Config.POOL do
			pick -= entry.weight
			if pick < 0 then
				chosen = entry
				break
			end
		end
		if chosen.kind == "Seed" then
			local options = {}
			for _, crop in Crops.List do
				if crop.rarity == chosen.rarity then
					table.insert(options, crop)
				end
			end
			local crop = options[rng:NextInteger(1, #options)]
			table.insert(lots, { kind = "Seed", id = crop.id, rarity = crop.rarity, estimate = crop.seed })
		else
			local options = Config.ITEMS[chosen.kind]
			local item = options[rng:NextInteger(1, #options)]
			table.insert(lots, { kind = chosen.kind, id = item.id, estimate = item.estimate })
		end
	end
	return lots
end

-- Opens a lot for bidding (it runs LOT_SECONDS from `now`).
function AuctionRules.open(lot, now: number)
	lot.opening = roundUp(lot.estimate * Config.OPENING)
	lot.bids = {}
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
	return math.max(math.ceil(top.amount * (1 + Config.MIN_RAISE)), top.amount + Config.MIN_STEP)
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
