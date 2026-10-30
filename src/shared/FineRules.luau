-- Fines and debt (docs/GameDesign.md §4.12):
--   fine = max(floor, 8% × the thief's sales income in the last hour)
--          × repeat multiplier (1 / 1.5 / 2) × 1.5 if they fled
--   floor = max(25, 1.5 × the loot's market value)
-- Paid from the thief's wallet; whatever's missing becomes debt to that
-- owner, paid from half of the thief's future income. The owner only ever
-- gets what's collected, so fines never create coins (an empty alt account
-- pays nothing). tests/fine.test.luau.
--
-- crime (in the thief's save) = { earn = { ["bucket"] = coins }, arrests = { unix },
--                                 debts = { { ownerId, amount, createdAt } }, lastArrestAt }
local Crime = require(script.Parent.Config.Crime)

local FineRules = {}

local function bucketOf(now: number): number
	return now // Crime.EARN_BUCKET
end

-- Notes sales income (truck and shop sales only: not trades, refunds or
-- fines received).
function FineRules.addEarnings(crime, now: number, amount: number)
	if amount <= 0 then
		return
	end
	local current = bucketOf(now)
	local key = tostring(current)
	crime.earn[key] = (crime.earn[key] or 0) + amount
	for k in crime.earn do
		local bucket = tonumber(k)
		if not bucket or bucket <= current - Crime.EARN_BUCKETS then
			crime.earn[k] = nil
		end
	end
end

-- Sales income in the last hour (the 12 newest 5-minute buckets).
function FineRules.lastHour(crime, now: number): number
	local current = bucketOf(now)
	local total = 0
	for k, amount in crime.earn do
		local bucket = tonumber(k)
		if bucket and bucket > current - Crime.EARN_BUCKETS and bucket <= current then
			total += amount
		end
	end
	return total
end

-- Arrests in the last REPEAT_WINDOW, before this one.
function FineRules.priorArrests(crime, now: number): number
	local count = 0
	for _, at in crime.arrests do
		if now - at < Crime.REPEAT_WINDOW then
			count += 1
		end
	end
	return count
end

function FineRules.repeatMultiplier(prior: number): number
	return Crime.REPEAT[math.min(prior + 1, #Crime.REPEAT)]
end

-- The fine. f = { lootValue, earnings (last hour), prior (arrests), fled }
function FineRules.amount(f): number
	local floor = math.max(Crime.FLOOR_MIN, Crime.FLOOR_LOOT * (f.lootValue or 0))
	local base = math.max(floor, Crime.FINE_RATE * (f.earnings or 0))
	local multiplier = FineRules.repeatMultiplier(f.prior or 0) * (if f.fled then Crime.FLEE else 1)
	return math.floor(base * multiplier + 0.5)
end

-- Works out and takes a fine from a thief's save (data: coins, crime).
-- Returns { fine, paid, owed }: paid goes to the owner now; owed becomes a
-- debt to them.
function FineRules.arrest(data, ownerId: number, lootValue: number, now: number, fled: boolean?)
	local crime = data.crime
	FineRules.expire(crime, now)
	local fine = FineRules.amount({
		lootValue = lootValue,
		earnings = FineRules.lastHour(crime, now),
		prior = FineRules.priorArrests(crime, now),
		fled = fled,
	})
	local paid = math.clamp(data.coins, 0, fine)
	data.coins -= paid
	local owed = fine - paid
	if owed > 0 then
		table.insert(crime.debts, { ownerId = ownerId, amount = owed, createdAt = now })
	end
	-- Keep only arrests that still count toward the repeat multiplier.
	for i = #crime.arrests, 1, -1 do
		if now - crime.arrests[i] >= Crime.REPEAT_WINDOW then
			table.remove(crime.arrests, i)
		end
	end
	table.insert(crime.arrests, now)
	crime.lastArrestAt = now
	crime.fled = fled == true -- (the next join starts on the police porch with "You fled arrest")
	return { fine = fine, paid = paid, owed = owed }
end

-- Drops debts older than DEBT_EXPIRY (forgiven).
function FineRules.expire(crime, now: number)
	for i = #crime.debts, 1, -1 do
		if now - crime.debts[i].createdAt >= Crime.DEBT_EXPIRY then
			table.remove(crime.debts, i)
		end
	end
end

function FineRules.totalDebt(crime, now: number): number
	FineRules.expire(crime, now)
	local total = 0
	for _, debt in crime.debts do
		total += debt.amount
	end
	return total
end

-- Pays debts, oldest first, from `coins`. Returns what's left of the coins
-- and { ["ownerId"] = paid } for the payout queue.
local function payDebts(crime, coins: number)
	local payments = {}
	while coins > 0 and #crime.debts > 0 do
		local debt = crime.debts[1]
		local pay = math.min(coins, debt.amount)
		debt.amount -= pay
		coins -= pay
		local key = tostring(debt.ownerId)
		payments[key] = (payments[key] or 0) + pay
		if debt.amount <= 0 then
			table.remove(crime.debts, 1)
		end
	end
	return coins, payments
end

-- Income arriving while in debt (sales, and auction refunds): GARNISH of it
-- goes to the debts. Returns the coins the player keeps and the payments.
function FineRules.garnish(crime, income: number, now: number)
	FineRules.expire(crime, now)
	if income <= 0 or #crime.debts == 0 then
		return income, {}
	end
	local share = math.floor(income * Crime.GARNISH)
	local left, payments = payDebts(crime, share)
	return income - share + left, payments
end

-- Paying early at the police desk with `coins`. Returns change and payments.
function FineRules.payEarly(crime, coins: number, now: number)
	FineRules.expire(crime, now)
	return payDebts(crime, math.max(0, coins))
end

-- Players in debt can't put coins into trades.
function FineRules.inDebt(crime, now: number): boolean
	return FineRules.totalDebt(crime, now) > 0
end

return FineRules
