-- The Auction House (shared/AuctionRules): valid bids, quick bids, the
-- anti-snipe clock, and who leads when the leader leaves.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local AuctionRules = harness.load("AuctionRules")
	local Auction = harness.load("Config/Auction")
	local Crops = harness.load("Config/Crops")

	local NOW = 1_000_000

	local function lot(estimate)
		return AuctionRules.open({ kind = "Seed", id = "Moonmelon", estimate = estimate or 12_000 }, NOW)
	end

	describe("the schedule", function()
		it("runs an auction every 8 minutes on the clock", function()
			local start = NOW - NOW % Auction.INTERVAL
			expect(AuctionRules.index(start)).toBe(AuctionRules.index(start + Auction.INTERVAL - 1))
			expect(AuctionRules.nextAt(start + 5)).toBe(start + Auction.INTERVAL)
		end)
		it("rolls the same lots for the same seed, each worth something", function()
			local a, b = AuctionRules.rollLots(77), AuctionRules.rollLots(77)
			expect(#a).toBe(Auction.LOTS)
			for index, entry in a do
				expect(entry.id).toBe(b[index].id)
				expect(entry.estimate).toBeGreaterThan(0)
				if entry.kind == "Seed" then
					expect(Crops.ById[entry.id].rarity).toBe(entry.rarity)
				end
			end
		end)
		it("offers Mythic seeds now and then (about 8% of lots)", function()
			local mythic, total = 0, 0
			for seed = 1, 3000 do
				for _, entry in AuctionRules.rollLots(seed) do
					total += 1
					if entry.rarity == "Mythic" then
						mythic += 1
					end
				end
			end
			expect(mythic / total).toBeNear(0.08, 0.02)
		end)
	end)

	describe("bidding", function()
		it("opens at 40% of the estimate", function()
			expect(lot().opening).toBe(4_800)
			expect(AuctionRules.minBid(lot())).toBe(4_800)
		end)
		it("needs 5% more (at least 10) to outbid, and the quick bids match the mockup", function()
			local l = lot()
			AuctionRules.place(l, 1, 7_350, NOW + 1)
			expect(AuctionRules.minBid(l)).toBe(7_718)
			expect(AuctionRules.quickBid(l, 0.05)).toBe(7_720)
			expect(AuctionRules.quickBid(l, 0.10)).toBe(8_090)
			expect(AuctionRules.quickBid(l, 0.25)).toBe(9_190)
		end)
		it("refuses low bids, outbidding yourself, and bids after the clock", function()
			local l = lot()
			expect(select(2, AuctionRules.place(l, 1, 4_000, NOW + 1))).toBe("TooLow")
			AuctionRules.place(l, 1, 4_800, NOW + 1)
			expect(select(2, AuctionRules.place(l, 1, 6_000, NOW + 2))).toBe("AlreadyLeading")
			expect(select(2, AuctionRules.place(l, 2, 6_000, NOW + Auction.LOT_SECONDS))).toBe("Closed")
		end)
		it("hands back the previous leader for a refund", function()
			local l = lot()
			AuctionRules.place(l, 1, 4_800, NOW + 1)
			local ok, _, refund = AuctionRules.place(l, 2, 5_100, NOW + 2)
			expect(ok).toBe(true)
			expect(refund.userId).toBe(1)
			expect(refund.amount).toBe(4_800)
		end)
		it("puts the clock back to 10 s for a late bid, not an early one", function()
			local l = lot()
			AuctionRules.place(l, 1, 4_800, NOW + 10)
			expect(l.endsAt).toBe(NOW + Auction.LOT_SECONDS)
			AuctionRules.place(l, 2, 5_100, NOW + 56)
			expect(l.endsAt).toBe(NOW + 66)
		end)
	end)

	describe("a bidder leaving the server", function()
		it("hands the lead to the highest earlier bidder who can still pay", function()
			local l = lot()
			AuctionRules.place(l, 1, 4_800, NOW + 1)
			AuctionRules.place(l, 2, 5_100, NOW + 2)
			AuctionRules.place(l, 3, 6_000, NOW + 3)
			local leader = AuctionRules.bidderLeft(l, 3, function(userId)
				return userId ~= 2 -- player 2 spent their coins since
			end)
			expect(leader.userId).toBe(1)
			expect(leader.amount).toBe(4_800)
			expect(AuctionRules.leader(l).userId).toBe(1)
		end)
		it("changes nothing when someone who isn't leading leaves", function()
			local l = lot()
			AuctionRules.place(l, 1, 4_800, NOW + 1)
			AuctionRules.place(l, 2, 5_100, NOW + 2)
			expect(AuctionRules.bidderLeft(l, 1, function()
				return true
			end)).toBe(nil)
			expect(AuctionRules.leader(l).userId).toBe(2)
		end)
		it("leaves no leader when nobody else can pay", function()
			local l = lot()
			AuctionRules.place(l, 1, 4_800, NOW + 1)
			expect(AuctionRules.bidderLeft(l, 1, function()
				return true
			end)).toBe(nil)
			expect(AuctionRules.leader(l)).toBe(nil)
		end)
	end)

	describe("closing", function()
		it("sells to the leader once the clock runs out", function()
			local l = lot()
			AuctionRules.place(l, 7, 4_800, NOW + 1)
			local _, over = AuctionRules.close(l, NOW + 30)
			expect(over).toBe(false)
			local winner, done = AuctionRules.close(l, NOW + Auction.LOT_SECONDS)
			expect(done).toBe(true)
			expect(winner.userId).toBe(7)
			expect(select(2, AuctionRules.place(l, 8, 9_000, NOW + Auction.LOT_SECONDS))).toBe("Closed")
		end)
	end)
end
