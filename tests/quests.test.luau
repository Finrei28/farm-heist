-- Daily quests, the login streak and the Cropdex (shared/QuestRules, §4.15,
-- §4.16).
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local QuestRules = harness.load("QuestRules")
	local Quests = harness.load("Config/Quests")
	local Crops = harness.load("Config/Crops")

	local ALEX = 101
	local DAY = 20_400
	local T = DAY * 86400 + 3600

	local function fresh()
		return { day = 0, list = {}, bonusClaimed = false }
	end

	describe("daily quests", function()
		it("are three a day, the same all day, new the next", function()
			local q = fresh()
			expect(QuestRules.refresh(q, ALEX, T, { level = 10, raids = true })).toBe(true)
			expect(#q.list).toBe(3)
			local first = q.list[1].id
			expect(QuestRules.refresh(q, ALEX, T + 3600, { level = 10, raids = true })).toBe(false)
			expect(q.list[1].id).toBe(first)
			expect(QuestRules.refresh(q, ALEX, T + 86400, { level = 10, raids = true })).toBe(true)
		end)
		it("are never three of the same, and leave out raids under the Sprout Shield and the auction before Farm Level 8", function()
			for day = 1, 300 do
				local list = QuestRules.roll(ALEX + day, day, { level = 3, raids = false })
				local seen = {}
				for _, quest in list do
					expect(seen[quest.id]).toBe(nil)
					seen[quest.id] = true
					expect(quest.id ~= "Arrest" and quest.id ~= "Deposit" and quest.id ~= "Auction").toBe(true)
				end
			end
		end)
		it("grow with your Farm Level, rewards ×4 from Level 8 and ×15 from Level 20", function()
			local function harvest(level)
				for day = 1, 200 do
					for _, quest in QuestRules.roll(ALEX, day, { level = level, raids = true }) do
						if quest.id == "Harvest" then
							return quest
						end
					end
				end
				return nil
			end
			expect(harvest(1).n).toBe(30)
			expect(harvest(1).reward).toBe(2_000)
			expect(harvest(8).reward).toBe(8_000)
			expect(harvest(20).n).toBe(400)
			expect(harvest(20).reward).toBe(30_000)
		end)
		it("count what you do, pay once when done, and pay a bonus for all three", function()
			local q = { day = DAY, bonusClaimed = false, list = {
				{ id = "Harvest", stat = "harvest", n = 30, reward = 2_000, progress = 0, claimed = false },
				{ id = "Ship", stat = "crates", n = 2, reward = 4_000, progress = 0, claimed = false },
				{ id = "Mutation", stat = "mutations", n = 1, reward = 6_000, progress = 0, claimed = false },
			} }
			expect(select(2, QuestRules.claim(q, 1))).toBe("NotDone")
			expect(#QuestRules.bump(q, "harvest", 12)).toBe(0)
			expect(#QuestRules.bump(q, "harvest", 40)).toBe(1)
			expect(q.list[1].progress).toBe(30)
			expect(QuestRules.claim(q, 1)).toBe(2_000)
			expect(select(2, QuestRules.claim(q, 1))).toBe("Claimed")
			expect(select(2, QuestRules.claimBonus(q, 1))).toBe("NotDone")
			QuestRules.bump(q, "crates", 2)
			QuestRules.bump(q, "mutations", 1)
			QuestRules.claim(q, 2)
			QuestRules.claim(q, 3)
			expect(QuestRules.claimBonus(q, 1)).toBe(Quests.BONUS)
			expect(select(2, QuestRules.claimBonus(q, 1))).toBe("Claimed")
		end)
		it("read as plain sentences", function()
			expect(QuestRules.text({ id = "Harvest", n = 30 })).toBe("Harvest 30 crops")
			expect(QuestRules.text({ id = "Arrest", n = 1 })).toBe("Arrest a thief")
			expect(QuestRules.text({ id = "Arrest", n = 2 })).toBe("Arrest 2 thieves")
			expect(QuestRules.text({ id = "Store", n = 15000 })).toBe("Earn 15,000 coins in your store")
			expect(QuestRules.number(120000)).toBe("120,000")
			expect(QuestRules.number(999)).toBe("999")
		end)
	end)

	describe("the login streak", function()
		it("pays day 1, then each day in a row, back to day 1 after 7 or a missed day", function()
			local s = { days = 0, lastClaimDay = 0 }
			expect(QuestRules.claimStreak(s, DAY, 1)).toBe(1)
			expect(QuestRules.claimStreak(s, DAY, 1)).toBe(nil) -- (once a day)
			for d = 2, 7 do
				expect(QuestRules.claimStreak(s, DAY + d - 1, 1)).toBe(d)
			end
			expect(QuestRules.claimStreak(s, DAY + 7, 1)).toBe(1)
			expect(QuestRules.claimStreak(s, DAY + 9, 1)).toBe(1) -- (missed a day)
		end)
		it("gives a decoration on day 7, and coins that grow with your level", function()
			expect(Quests.STREAK[7].decor ~= nil).toBe(true)
			local s = { days = 0, lastClaimDay = 0 }
			local _, reward = QuestRules.claimStreak(s, DAY, 20)
			expect(reward.coins).toBe(Quests.STREAK[1].coins * 15)
			expect(Quests.STREAK[1].coins).toBe(2_000) -- (the config isn't changed)
		end)
	end)

	describe("the Cropdex", function()
		it("records each crop and mutation once", function()
			local c = {}
			expect((QuestRules.record(c, "Carrot"))).toBe(true)
			expect((QuestRules.record(c, "Carrot"))).toBe(false)
			expect((QuestRules.record(c, "Carrot", "Wet"))).toBe(true)
			expect(QuestRules.seen(c, "Carrot", "Wet")).toBe(true)
			expect(QuestRules.seen(c, "Carrot", "Golden")).toBe(false)
			local found, total = QuestRules.progress(c)
			expect(found).toBe(2)
			expect(total).toBe(#Crops.List * 7)
		end)
		it("pays out once when every crop of a rarity is found", function()
			local c = {}
			local last
			for _, crop in Crops.List do
				if crop.rarity == "Common" then
					last = { QuestRules.record(c, crop.id) }
				end
			end
			expect(last[2]).toBe("Common")
			expect(QuestRules.nextSeed("Common")).toBe("Corn")
			expect(QuestRules.nextSeed("Legendary") ~= nil).toBe(true)
			expect(QuestRules.nextSeed("Mythic")).toBe(nil)
		end)
		it("finishes a mutation set when every crop has it", function()
			local c = {}
			local set
			for _, crop in Crops.List do
				local _, _, s = QuestRules.record(c, crop.id, "Wet")
				set = s or set
			end
			expect(set).toBe("Wet")
		end)
	end)
end
