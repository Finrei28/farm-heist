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
		-- each lot's kind (a seed's rarity, or the item), over many auctions
		local function shares()
			local seen, total = {}, 0
			for seed = 1, 3000 do
				for _, entry in AuctionRules.rollLots(seed) do
					total += 1
					local key = if entry.kind == "Seed" then entry.rarity else entry.id
					seen[key] = (seen[key] or 0) + 1
				end
			end
			for key, n in seen do
				seen[key] = n / total
			end
			return seen
		end
		it("auctions 5 lots, seeds from Uncommon to Mythic (never Commons: Barley always has them)", function()
			expect(Auction.LOTS).toBe(5)
			expect(#AuctionRules.rollLots(5)).toBe(5)
			local s = shares()
			expect(s.Common).toBe(nil)
			for _, rarity in { "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
				expect((s[rarity] or 0) > 0).toBe(true)
			end
		end)
		it("makes rarer lots rarer: seeds by rarity, rare workers and defences by worth", function()
			local s = shares()
			expect(s.Uncommon).toBeGreaterThan(s.Rare)
			expect(s.Rare).toBeGreaterThan(s.Epic)
			expect(s.Epic).toBeGreaterThan(s.Legendary)
			expect(s.Legendary).toBeGreaterThan(s.Mythic)
			expect(s.Mythic).toBeNear(0.03, 0.01) -- (about 1 auction in 7 has one)
			expect(s.SpeedySam).toBeGreaterThan(s.GrandmaRose)
			expect(s.Cloche).toBeGreaterThan(s.GuardDog)
			expect(s.GuardDog).toBeGreaterThan(s.Camera)
		end)
		it("opens every lot below what it costs elsewhere: a seed below Barley's price, a defence below the shop's", function()
			local Defences = harness.load("Config/Defences")
			for _, crop in Crops.List do
				if crop.rarity ~= "Common" then
					local l = AuctionRules.open({ kind = "Seed", id = crop.id, estimate = crop.seed }, NOW)
					expect(l.opening).toBeLessThan(crop.seed)
				end
			end
			for _, item in Auction.ITEMS.Defence do
				local l = AuctionRules.open({ kind = "Defence", id = item.id, estimate = item.estimate }, NOW)
				expect(l.opening).toBeLessThan(Defences.ITEMS[item.id].cost)
			end
		end)
	end)

	describe("the room", function()
		it("hands out bidder paddles 10 to 99, each once, shuffled the same way for the same server", function()
			local a, b = AuctionRules.paddleNumbers(4242), AuctionRules.paddleNumbers(4242)
			expect(#a).toBe(90)
			local seen = {}
			for i, number in a do
				expect(number >= 10 and number <= 99).toBe(true)
				expect(seen[number]).toBe(nil)
				seen[number] = true
				expect(number).toBe(b[i])
			end
			local inOrder = true
			for i = 2, #a do
				inOrder = inOrder and a[i] > a[i - 1]
			end
			expect(inOrder).toBe(false)
		end)
		local paddles = { [1] = 47, [2] = 12 }
		local function room(k, last)
			return { k = k or 2, name = "Moonmelon seed", last = last, paddleOf = function(userId)
				return paddles[userId]
			end }
		end
		it("has Goldie open a lot by asking for the opening bid, then ask again if nobody bids", function()
			local l = lot()
			expect((AuctionRules.patter(l, NOW + 1, room(2)))).toBe("Lot 2: Moonmelon seed! Who'll start me at 48,000?")
			expect((AuctionRules.patter(l, NOW + 25, room(2)))).toBe("48,000, anyone? It's worth 120,000!")
			expect((AuctionRules.patter(l, NOW + 57, room(2)))).toBe("Any bids? Anyone at all?")
		end)
		it("has her take each bid by paddle number and ask for the next step up", function()
			local l = lot()
			AuctionRules.place(l, 1, 48_000, NOW + 10)
			expect((AuctionRules.patter(l, NOW + 11, room(2, { at = NOW + 10, userId = 1 })))).toBe("48,000 from paddle 47! Do I hear 50,400?")
			AuctionRules.place(l, 2, 50_400, NOW + 14)
			expect((AuctionRules.patter(l, NOW + 15, room(2, { at = NOW + 14, userId = 2, previous = 1 })))).toBe("50,400 from paddle 12! Back to you, paddle 47: 53,000?")
			expect((AuctionRules.patter(l, NOW + 34, room(2, { at = NOW + 14, userId = 2, previous = 1 })))).toBe("I have 50,400 from paddle 12. 53,000, anyone?")
		end)
		it("has her call going once and going twice, bringing the gavel down each time", function()
			local l = lot()
			AuctionRules.place(l, 1, 48_000, NOW + 10)
			local last = { at = NOW + 10, userId = 1 }
			local call, gavel = AuctionRules.patter(l, NOW + 56, room(2, last))
			expect(call).toBe("Going once at 48,000...")
			expect(gavel).toBe(true)
			call, gavel = AuctionRules.patter(l, NOW + 58, room(2, last))
			expect(call).toBe("Going twice at 48,000...")
			expect(gavel).toBe(true)
			expect(select(2, AuctionRules.patter(l, NOW + 11, room(2, last)))).toBe(false)
		end)
	end)

	describe("bidding", function()
		it("opens at 40% of the estimate", function()
			expect(lot().opening).toBe(48_000)
			expect(AuctionRules.minBid(lot())).toBe(48_000)
		end)
		it("bids in steps that suit the lot: a cheap seed's quick bids are three different amounts", function()
			local corn = AuctionRules.open({ kind = "Seed", id = "Corn", estimate = 900 }, NOW)
			expect(corn.opening).toBe(360) -- (40% of Barley's 900)
			AuctionRules.place(corn, 1, 360, NOW + 1)
			expect(AuctionRules.minBid(corn)).toBe(378)
			expect(AuctionRules.quickBid(corn, 0.05)).toBe(380)
			expect(AuctionRules.quickBid(corn, 0.10)).toBe(400)
			expect(AuctionRules.quickBid(corn, 0.25)).toBe(450)
			expect(AuctionRules.step(900)).toBe(10)
			expect(AuctionRules.step(4_000)).toBe(50)
			expect(AuctionRules.step(48_000)).toBe(100)
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
