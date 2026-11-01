-- The payout queue (shared/PayoutRules): debt payments to owners in other
-- servers, claimed once, batched, and pruned.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local PayoutRules = harness.load("PayoutRules")
	local Crime = harness.load("Config/Crime")

	local NOW = 1_000_000

	describe("the queue", function()
		it("adds records with ids and drops old ones", function()
			local old = PayoutRules.record(7, 50, NOW - Crime.PAYOUT_KEEP - 1, 1)
			local queue = PayoutRules.append({ old }, PayoutRules.record(7, 40, NOW, 2), NOW)
			expect(#queue).toBe(1)
			expect(queue[1].amount).toBe(40)
			expect(queue[1].id).toBe("7-1000000-2")
		end)
		it("pays each record once, even if removing it failed", function()
			local queue = {}
			queue = PayoutRules.append(queue, PayoutRules.record(7, 40, NOW, 1), NOW)
			queue = PayoutRules.append(queue, PayoutRules.record(8, 25, NOW, 2), NOW)
			local claimed = {}
			local total, ids = PayoutRules.unclaimed(queue, claimed)
			expect(total).toBe(65)
			PayoutRules.claim(claimed, ids, NOW)
			-- the removal didn't go through: the records are still there
			expect((PayoutRules.unclaimed(queue, claimed))).toBe(0)
			expect(#PayoutRules.withoutClaimed(queue, claimed, NOW)).toBe(0)
		end)
		it("forgets claimed ids once their records would be gone", function()
			local claimed = { a = NOW - Crime.PAYOUT_KEEP, b = NOW - 10, c = true }
			PayoutRules.pruneClaimed(claimed, NOW)
			expect(claimed.a).toBe(nil)
			expect(claimed.b).toBe(NOW - 10)
			expect(claimed.c).toBe(nil)
		end)
	end)

	describe("batching", function()
		it("sends one record per owner every 5 minutes at most", function()
			local pending = {}
			PayoutRules.addPending(pending, 7, 10, NOW)
			PayoutRules.addPending(pending, 7, 15, NOW + 60)
			expect(#PayoutRules.due(pending, NOW + 120)).toBe(0)
			local due = PayoutRules.due(pending, NOW + Crime.PAYOUT_BATCH)
			expect(#due).toBe(1)
			expect(due[1].ownerId).toBe(7)
			expect(due[1].amount).toBe(25)
			expect(#PayoutRules.due(pending, NOW + 1000)).toBe(0)
		end)
		it("sends everything when the debtor leaves", function()
			local pending = {}
			PayoutRules.addPending(pending, 7, 10, NOW)
			PayoutRules.addPending(pending, 3, 5, NOW)
			local due = PayoutRules.due(pending, NOW + 1, true)
			expect(#due).toBe(2)
			expect(due[1].ownerId).toBe(3)
		end)
	end)
end
