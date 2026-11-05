-- The leaderboards (shared/LeaderRules): weeks from Monday UTC, this week's
-- stats starting over, net worth and Top Store's 200-shopper bar.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local LeaderRules = harness.load("LeaderRules")
	local BarnRules = harness.load("BarnRules")
	local Crops = harness.load("Config/Crops")
	local Store = harness.load("Config/Store")
	local Warehouse = harness.load("Config/Warehouse")
	local Defences = harness.load("Config/Defences")

	local MONDAY = 1793577600 -- Monday 2 November 2026, 00:00 UTC

	local function newData()
		return {
			coins = 1000,
			silo = 0,
			land = { fieldLevel = 1 },
			inventory = { crops = {}, seeds = {}, items = {} },
			warehouse = { level = 1, dock = {}, beds = { {} } },
			store = { level = 1, layout = {}, owned = { ProduceCrate = 2 }, gifts = { ProduceCrate = 2 }, stockroom = {} },
			defences = { owned = {}, placed = {} },
		}
	end

	describe("who's on the boards", function()
		it("real players, never Studio's test players", function()
			expect(LeaderRules.counts(123456)).toBe(true)
			expect(LeaderRules.counts(-1)).toBe(false)
			expect(LeaderRules.counts(-8)).toBe(false)
			expect(LeaderRules.counts(0)).toBe(false)
		end)
	end)

	describe("weeks", function()
		it("turn over on Monday at midnight UTC", function()
			expect(os.date("!%A %H:%M", MONDAY)).toBe("Monday 00:00")
			expect(LeaderRules.week(MONDAY)).toBe(LeaderRules.week(MONDAY + 7 * 86400 - 1))
			expect(LeaderRules.week(MONDAY + 7 * 86400)).toBe(LeaderRules.week(MONDAY) + 1)
			expect(LeaderRules.week(MONDAY - 1)).toBe(LeaderRules.week(MONDAY) - 1)
			expect(LeaderRules.weekLeft(MONDAY + 86400)).toBe(6 * 86400)
		end)
		it("keep this week's stats, starting them over in a new week", function()
			local data = newData()
			LeaderRules.bump(data, "arrests", 1, MONDAY + 100)
			LeaderRules.bump(data, "arrests", 2, MONDAY + 200)
			LeaderRules.bump(data, "stolen", 900, MONDAY + 300)
			expect(LeaderRules.thisWeek(data, "arrests", MONDAY + 400)).toBe(3)
			expect(LeaderRules.thisWeek(data, "arrests", MONDAY + 7 * 86400)).toBe(0) -- (an old week's numbers don't count)
			LeaderRules.bump(data, "arrests", 1, MONDAY + 7 * 86400 + 5)
			expect(LeaderRules.thisWeek(data, "arrests", MONDAY + 7 * 86400 + 6)).toBe(1)
			expect(LeaderRules.thisWeek(data, "stolen", MONDAY + 7 * 86400 + 6)).toBe(0)
		end)
	end)

	describe("net worth", function()
		it("is the coins on a new farm (its starter kit is free)", function()
			expect(LeaderRules.netWorth(newData())).toBe(1000)
		end)
		it("adds crops, seeds, crates, buildings and defences at what they cost", function()
			local data = newData()
			data.inventory.crops[BarnRules.key("Carrot")] = 10
			data.inventory.seeds.Corn = 2
			data.store.stockroom = { { crop = "Pumpkin", key = BarnRules.key("Pumpkin"), units = 3 } }
			data.warehouse.level = 3
			data.store.level = 2
			data.store.owned.ProduceCrate = 3 -- (one bought)
			data.defences.owned.Scarecrow = 1
			local expected = 1000 + 10 * Crops.ById.Carrot.value + 2 * Crops.ById.Corn.seed + 3 * Crops.ById.Pumpkin.value
				+ Warehouse.LEVELS[2].cost + Warehouse.LEVELS[3].cost + Store.LEVELS[2].cost + Store.ITEMS.ProduceCrate.cost + Defences.ITEMS.Scarecrow.cost
			expect(LeaderRules.netWorth(data)).toBe(expected)
		end)
	end)

	describe("Top Store", function()
		it("only counts a store with 200 shoppers this week", function()
			local data = newData()
			LeaderRules.bump(data, "shoppers", 199, MONDAY)
			expect(LeaderRules.storeScore(data, 4.62, MONDAY)).toBe(nil)
			LeaderRules.bump(data, "shoppers", 1, MONDAY)
			expect(LeaderRules.storeScore(data, 4.62, MONDAY)).toBe(462)
			expect(LeaderRules.show("TopStore", 462, tostring)).toBe("4.6★")
			expect(LeaderRules.show("Sheriff", 12, tostring)).toBe("12")
		end)
	end)
end
