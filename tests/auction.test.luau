-- The Auction House (shared/AuctionRules): valid bids, quick bids, the
-- anti-snipe clock, and who leads when the leader leaves.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local AuctionRules = harness.load("AuctionRules")
	local Auction = harness.load("Config/Auction")
	local Crops = harness.load("Config/Crops")

	local NOW = 1_000_000

	local function lot(estimate)
		return AuctionRules.open({ kind = "Seed", id = "Moonmelon", estimate = estimate or 120_000 }, NOW)
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
		it("offers seeds, rare workers and defences, each something you can get", function()
			local Workers = harness.load("Config/Workers")
			local Defences = harness.load("Config/Defences")
			local kinds = {}
			for seed = 1, 400 do
				for _, entry in AuctionRules.rollLots(seed) do
					kinds[entry.kind] = true
					if entry.kind == "WorkerContract" then
						expect(Workers.CONTRACTS[entry.id] ~= nil).toBe(true)
					elseif entry.kind == "Defence" then
						expect(Defences.ITEMS[entry.id] ~= nil).toBe(true)
						expect(entry.estimate).toBe(Defences.ITEMS[entry.id].cost)
					end
					local d = AuctionRules.describe(entry)
					expect(#d.name > 0 and #d.icon > 0).toBe(true)
				end
			end
			expect(kinds.Seed and kinds.WorkerContract and kinds.Defence).toBe(true)
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
			expect(lot().opening).toBe(48_000)
			expect(AuctionRules.minBid(lot())).toBe(48_000)
		end)
		it("needs 5% more (at least 100) to outbid, and the quick bids match the mockup", function()
			local l = lot()
			AuctionRules.place(l, 1, 73_500, NOW + 1)
			expect(AuctionRules.minBid(l)).toBe(77_175)
			expect(AuctionRules.quickBid(l, 0.05)).toBe(77_200)
			expect(AuctionRules.quickBid(l, 0.10)).toBe(80_900)
			expect(AuctionRules.quickBid(l, 0.25)).toBe(91_900)
		end)
		it("refuses low bids, outbidding yourself, and bids after the clock", function()
			local l = lot()
			expect(select(2, AuctionRules.place(l, 1, 40_000, NOW + 1))).toBe("TooLow")
			AuctionRules.place(l, 1, 48_000, NOW + 1)
			expect(select(2, AuctionRules.place(l, 1, 60_000, NOW + 2))).toBe("AlreadyLeading")
			expect(select(2, AuctionRules.place(l, 2, 60_000, NOW + Auction.LOT_SECONDS))).toBe("Closed")
		end)
		it("hands back the previous leader for a refund", function()
			local l = lot()
			AuctionRules.place(l, 1, 48_000, NOW + 1)
			local ok, _, refund = AuctionRules.place(l, 2, 51_000, NOW + 2)
			expect(ok).toBe(true)
			expect(refund.userId).toBe(1)
			expect(refund.amount).toBe(48_000)
		end)
		it("puts the clock back to 10 s for a late bid, not an early one", function()
			local l = lot()
			AuctionRules.place(l, 1, 48_000, NOW + 10)
			expect(l.endsAt).toBe(NOW + Auction.LOT_SECONDS)
			AuctionRules.place(l, 2, 51_000, NOW + 56)
			expect(l.endsAt).toBe(NOW + 66)
		end)
	end)

	describe("a bidder leaving the server", function()
		it("hands the lead to the highest earlier bidder who can still pay", function()
			local l = lot()
			AuctionRules.place(l, 1, 48_000, NOW + 1)
			AuctionRules.place(l, 2, 51_000, NOW + 2)
			AuctionRules.place(l, 3, 60_000, NOW + 3)
			local leader = AuctionRules.bidderLeft(l, 3, function(userId)
				return userId ~= 2 -- player 2 spent their coins since
			end)
			expect(leader.userId).toBe(1)
			expect(leader.amount).toBe(48_000)
			expect(AuctionRules.leader(l).userId).toBe(1)
		end)
		it("changes nothing when someone who isn't leading leaves", function()
			local l = lot()
			AuctionRules.place(l, 1, 48_000, NOW + 1)
			AuctionRules.place(l, 2, 51_000, NOW + 2)
			expect(AuctionRules.bidderLeft(l, 1, function()
				return true
			end)).toBe(nil)
			expect(AuctionRules.leader(l).userId).toBe(2)
		end)
		it("leaves no leader when nobody else can pay", function()
			local l = lot()
			AuctionRules.place(l, 1, 48_000, NOW + 1)
			expect(AuctionRules.bidderLeft(l, 1, function()
				return true
			end)).toBe(nil)
			expect(AuctionRules.leader(l)).toBe(nil)
		end)
	end)

	describe("what you can win", function()
		local DefenceRules = harness.load("DefenceRules")
		local function ctx(level)
			return {
				level = level, defences = { owned = {}, placed = {} }, workers = {},
				workerCtx = { warehouseLevel = 5, storeLevel = 1, farmLevel = level, openTiles = 16, registers = 0, trucks = 1 },
			}
		end
		it("a defence needs its Farm Level and room for one more", function()
			local dog = { kind = "Defence", id = "GuardDog", estimate = 600_000 }
			expect(select(2, AuctionRules.canWin(dog, ctx(15)))).toBe("DefenceLocked")
			local c = ctx(16)
			expect(AuctionRules.canWin(dog, c)).toBe(true)
			DefenceRules.buy(c.defences, "GuardDog")
			expect(select(2, AuctionRules.canWin(dog, c))).toBe("DefenceMax")
		end)
		it("a rare worker needs a free slot for their job", function()
			local rose = { kind = "WorkerContract", id = "GrandmaRose", estimate = 200_000 }
			local c = ctx(10)
			expect(AuctionRules.canWin(rose, c)).toBe(true)
			c.workerCtx.warehouseLevel = 1 -- (no Packers at the Packing Shed)
			expect(select(2, AuctionRules.canWin(rose, c))).toBe("NoSlot")
		end)
		it("a seed always, even a Mythic before you can plant it", function()
			expect(AuctionRules.canWin({ kind = "Seed", id = "CrystalRose", estimate = 400_000 }, ctx(1))).toBe(true)
		end)
		it("a rare worker joins at their level with their own trait, and works harder while you're away", function()
			local WorkerRules = harness.load("WorkerRules")
			local rose = WorkerRules.fromContract("GrandmaRose")
			expect(rose.type).toBe("Packer")
			expect(rose.level).toBe(8)
			expect(rose.trait).toBe("Tireless")
			local plain = { type = "Packer", level = 8, xp = 0 }
			expect(WorkerRules.speed(rose, { away = true })).toBeNear(2 * WorkerRules.speed(plain, { away = true }), 1e-9)
			expect(WorkerRules.speed(rose)).toBeNear(WorkerRules.speed(plain), 1e-9)
		end)
	end)

	describe("closing", function()
		it("sells to the leader once the clock runs out", function()
			local l = lot()
			AuctionRules.place(l, 7, 48_000, NOW + 1)
			local _, over = AuctionRules.close(l, NOW + 30)
			expect(over).toBe(false)
			local winner, done = AuctionRules.close(l, NOW + Auction.LOT_SECONDS)
			expect(done).toBe(true)
			expect(winner.userId).toBe(7)
			expect(select(2, AuctionRules.place(l, 8, 90_000, NOW + Auction.LOT_SECONDS))).toBe("Closed")
		end)
	end)
end
