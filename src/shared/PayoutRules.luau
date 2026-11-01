-- Debt payments to an owner who isn't in the debtor's server (docs/
-- GameDesign.md §4.12). Half of a debtor's sales income pays their fines
-- (shared/FineRules.garnish); an owner who's here is paid at once, anyone
-- else through the payout queue: a DataStore (Payouts_v1, key
-- Owner_<userId>) of records { id, from, amount, at }. Every record has an
-- id, and the owner's save keeps the ids it has claimed (payoutsClaimed), so
-- a record is never paid twice even if removing it fails. Payments to the
-- same owner are batched: one record every PAYOUT_BATCH seconds at most,
-- which keeps DataStore writes low. Pure functions (the DataStore's
-- UpdateAsync transforms among them); PayoutService does the calls.
-- tests/payout.test.luau.
local Crime = require(script.Parent.Config.Crime)

local PayoutRules = {}

function PayoutRules.record(fromId: number, amount: number, now: number, serial: number)
	return { id = `{fromId}-{math.floor(now)}-{serial}`, from = fromId, amount = amount, at = now }
end

-- The queue with this record added and records past PAYOUT_KEEP dropped.
function PayoutRules.append(queue, record, now: number)
	local out = {}
	for _, old in queue or {} do
		if now - old.at < Crime.PAYOUT_KEEP then
			table.insert(out, old)
		end
	end
	table.insert(out, record)
	return out
end

-- Records not claimed yet: their total and ids.
function PayoutRules.unclaimed(queue, claimed): (number, { string })
	local total, ids = 0, {}
	for _, record in queue or {} do
		if not claimed[record.id] then
			total += record.amount
			table.insert(ids, record.id)
		end
	end
	return total, ids
end

-- Marks ids as claimed in the owner's save (["id"] = when).
function PayoutRules.claim(claimed, ids: { string }, now: number)
	for _, id in ids do
		claimed[id] = now
	end
end

-- The queue without the records already claimed (or too old).
function PayoutRules.withoutClaimed(queue, claimed, now: number)
	local out = {}
	for _, record in queue or {} do
		if not claimed[record.id] and now - record.at < Crime.PAYOUT_KEEP then
			table.insert(out, record)
		end
	end
	return out
end

-- Forgets claimed ids old enough that their records are gone anyway.
function PayoutRules.pruneClaimed(claimed, now: number)
	for id, at in claimed do
		if typeof(at) ~= "number" or now - at >= Crime.PAYOUT_KEEP then
			claimed[id] = nil
		end
	end
end

------------------------------------------------------------------------
-- Batching: payments wait per owner until PAYOUT_BATCH has passed since that
-- owner's first waiting payment. pending = { ["ownerId"] = { amount, since } }

function PayoutRules.addPending(pending, ownerId: number, amount: number, now: number)
	local key = tostring(ownerId)
	local entry = pending[key]
	if not entry then
		entry = { amount = 0, since = now }
		pending[key] = entry
	end
	entry.amount += amount
end

-- Takes the batches that are due (all of them if `all`: the debtor is
-- leaving or the server is closing). Returns { { ownerId, amount } }.
function PayoutRules.due(pending, now: number, all: boolean?)
	local out = {}
	for key, entry in pending do
		if all or now - entry.since >= Crime.PAYOUT_BATCH then
			if entry.amount > 0 then
				table.insert(out, { ownerId = tonumber(key), amount = entry.amount })
			end
			pending[key] = nil
		end
	end
	table.sort(out, function(a, b)
		return a.ownerId < b.ownerId
	end)
	return out
end

return PayoutRules
