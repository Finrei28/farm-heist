-- The farm running while you're away (shared/PipelineRules): growth,
-- Farmhands, the warehouse, trucks, the store, wages and strikes, with
-- nothing lost or made up along the way.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local PipelineRules = harness.load("PipelineRules")
	local GrowthRules = harness.load("GrowthRules")
	local Workers = harness.load("Config/Workers")

	local NOW = 1_000_000
	local HOUR = 3600

	local function flat(price)
		return function()
			return price
		end
	end

	local function sum(map)
		local total = 0
		for _, units in map do
			total += units
		end
		return total
	end

	-- Every unit, wherever it is.
	local function unitsIn(state, report)
		local total = sum(state.barn) + sum(state.sorted) + sum(state.stockroom) + sum(state.shelves) + report.shopUnits
		for _, crate in state.hold do
			total += crate.units
		end
		for _, truck in state.trucks do
			for _, crate in truck.bed do
				total += crate.units
			end
		end
		for _, run in report.runs do
			for _, crate in run.crates do
				total += crate.units
			end
		end
		return total
	end

	describe("with nobody working", function()
		it("crops still grow, nothing moves, nobody's paid", function()
			local state = PipelineRules.newState()
			state.tiles["1"] = GrowthRules.plant("Carrot")
			state.barn.Carrot = 50
			local report = PipelineRules.simulate(state, HOUR, Workers.OFFLINE_RATE, NOW)
			expect(GrowthRules.isRipe(state.tiles["1"])).toBe(true)
			expect(state.barn.Carrot).toBe(50)
			expect(report.harvested).toBe(0)
			expect(report.wages).toBe(0)
		end)
		it("stops after 8 hours", function()
			local report = PipelineRules.simulate(PipelineRules.newState(), 20 * HOUR, Workers.OFFLINE_RATE, NOW)
			expect(report.minutes).toBe(8 * 60)
		end)
	end)

	describe("Farmhands", function()
		it("harvest ripe crops and replant from your seeds, skipping flagged tiles", function()
			local state = PipelineRules.newState()
			for tile = 1, 16 do
				state.tiles[tostring(tile)] = GrowthRules.plant("Carrot")
			end
			state.tiles["16"].leave = true
			state.seeds.Carrot = 10
			state.speeds.Field = 15
			local report = PipelineRules.simulate(state, HOUR, Workers.OFFLINE_RATE, NOW)
			expect(report.harvested).toBeGreaterThan(0)
			expect(state.seeds.Carrot).toBe(0)
			expect(state.barn.Carrot).toBe(report.harvested)
			expect(GrowthRules.isRipe(state.tiles["16"])).toBe(true) -- left in the field
			expect(report.worked.Field).toBeGreaterThan(0)
		end)
		it("replant the cheapest seed in the bag when told to", function()
			local state = PipelineRules.newState()
			state.tiles["1"] = GrowthRules.plant("Corn")
			GrowthRules.advance(state.tiles["1"], 24 * HOUR, 1)
			state.seeds = { Carrot = 1, Corn = 5 }
			state.replant = "cheapest"
			state.speeds.Field = 15
			PipelineRules.simulate(state, 60, 1, NOW)
			expect(state.tiles["1"].crop).toBe("Carrot")
		end)
		it("stop when the barn is full", function()
			local state = PipelineRules.newState()
			for tile = 1, 16 do
				state.tiles[tostring(tile)] = GrowthRules.plant("Carrot")
			end
			state.seeds.Carrot = 100
			state.barnRoom = 5
			state.speeds.Field = 30
			local report = PipelineRules.simulate(state, HOUR, 1, NOW)
			expect(report.harvested).toBe(5)
		end)
	end)

	describe("the warehouse and the trucks", function()
		local function crew(state)
			state.speeds.Sort, state.speeds.Pack, state.speeds.Load = 30, 7.5, 10
			state.holdSize = 20
			state.trucks[1].driver = true
		end

		it("ship everything at the locked price when a Driver is hired", function()
			local state = PipelineRules.newState()
			crew(state)
			state.barn.Carrot = 240 -- 20 crates
			local report = PipelineRules.simulate(state, HOUR, 1, NOW, flat(20))
			expect(report.shippedCrates).toBe(20)
			expect(report.truckCoins).toBe(240 * 20)
			expect(#report.runs).toBe(5)
			expect(report.runs[1].arriveAt - report.runs[1].at).toBe(30)
			expect(report.worked.Truck).toBeGreaterThan(0)
		end)
		it("never loses or makes up a carrot", function()
			local state = PipelineRules.newState()
			crew(state)
			state.barn.Carrot = 1000
			local report = PipelineRules.simulate(state, 2 * HOUR, Workers.OFFLINE_RATE, NOW, flat(20))
			expect(unitsIn(state, report)).toBe(1000)
		end)
		it("wait for you without a Driver, and packing pauses when the Cold Room is full", function()
			local state = PipelineRules.newState()
			crew(state)
			state.trucks[1].driver = false
			state.holdSize = 3
			state.barn.Carrot = 240
			local report = PipelineRules.simulate(state, HOUR, 1, NOW, flat(20))
			expect(report.shippedCrates).toBe(0)
			expect(#state.trucks[1].bed).toBe(4)
			expect(#state.hold).toBe(3)
			expect(report.crates).toBe(7)
		end)
		it("use every truck that has a Driver", function()
			local state = PipelineRules.newState()
			crew(state)
			state.speeds.Load = 40
			state.trucks[1].roundTrip = 600 -- (truck 1 is still out when the next crates are ready)
			state.trucks[2] = { crates = 4, roundTrip = 600, backAt = 0, driver = true, bed = {} }
			state.barn.Carrot = 96 -- 8 crates
			local report = PipelineRules.simulate(state, 10 * 60, 1, NOW, flat(20))
			local used = {}
			for _, run in report.runs do
				used[run.truck] = true
			end
			expect(used[1] and used[2]).toBe(true)
		end)
		it("follow the Drivers' price rule", function()
			local state = PipelineRules.newState()
			crew(state)
			state.minPrice = 1.0
			state.barn.Carrot = 240
			local report = PipelineRules.simulate(state, HOUR, 1, NOW, flat(15)) -- below the base 18
			expect(report.shippedCrates).toBe(0)
		end)
		it("split crates between truck and store as routed, and leave kept crops alone", function()
			local state = PipelineRules.newState()
			crew(state)
			state.routes.Carrot = 0.5
			state.routes.Tomato = "Keep"
			state.barn.Carrot = 240
			state.barn.Tomato = 40
			local report = PipelineRules.simulate(state, HOUR, 1, NOW, flat(20))
			expect(report.crates).toBe(20)
			expect(report.shippedCrates).toBe(8) -- 10 for the truck: two full loads, 2 crates waiting
			expect(#state.hold + #state.trucks[1].bed).toBe(2)
			expect(state.stockroom.Carrot).toBe(120)
			expect(state.barn.Tomato).toBe(40)
		end)
		it("send store crates to the truck once the stockroom is full", function()
			local state = PipelineRules.newState()
			crew(state)
			state.routes.Carrot = 0
			state.stockroomRoom = 2
			state.barn.Carrot = 48
			PipelineRules.simulate(state, HOUR, 1, NOW, flat(20))
			expect(state.stockroom.Carrot).toBe(24)
		end)
		it("grade the crew's share of crates A", function()
			local state = PipelineRules.newState()
			crew(state)
			state.trucks[1].driver = false
			state.holdSize = 100
			state.gradeA = 0.5
			state.barn.Carrot = 120
			PipelineRules.simulate(state, HOUR, 1, NOW, flat(20))
			local a = 0
			for _, crate in state.hold do
				a += if crate.grade == "A" then 1 else 0
			end
			for _, crate in state.trucks[1].bed do
				a += if crate.grade == "A" then 1 else 0
			end
			expect(a).toBe(5)
		end)
		it("pay Premium contracts on Legendary crates", function()
			local state = PipelineRules.newState()
			crew(state)
			state.premium = 0.1
			state.trucks[1].crates = 1
			state.barn.Moonmelon = 2 -- Legendary: 2 to a crate
			local report = PipelineRules.simulate(state, 10 * 60, 1, NOW, flat(100))
			expect(report.truckCoins).toBe(220)
		end)
		it("a Shed Hand packs and loads on its own at the Packing Shed", function()
			local state = PipelineRules.newState()
			state.speeds.Shed = 4
			state.trucks[1].driver = true
			state.barn.Carrot = 48
			local report = PipelineRules.simulate(state, HOUR, 1, NOW, flat(20))
			expect(report.shippedCrates).toBe(4)
			expect(report.worked.Shed).toBeGreaterThan(0)
		end)
	end)

	describe("the store", function()
		it("sells from the displays at your price; a silly price sells less", function()
			local function run(price)
				local state = PipelineRules.newState()
				state.shelves.Carrot = 40
				state.shop.prices.Carrot = price
				return PipelineRules.simulate(state, HOUR, 1, NOW, flat(18))
			end
			local fair, silly = run(18), run(60)
			expect(fair.shopUnits).toBeGreaterThan(silly.shopUnits)
			expect(fair.shopCoins).toBe(fair.shopUnits * 18)
			expect(fair.sold.Carrot).toBe(fair.shopUnits)
			expect(fair.shopUnits <= 40).toBe(true)
		end)
		it("a store with only Registers needs a Cashier", function()
			local state = PipelineRules.newState()
			state.shop.staffed = true
			state.shelves.Carrot = 40
			state.shop.prices.Carrot = 18
			local report = PipelineRules.simulate(state, HOUR, 1, NOW, flat(18))
			expect(report.shopUnits).toBe(0)
			state.speeds.Register = 6
			report = PipelineRules.simulate(state, HOUR, 1, NOW, flat(18))
			expect(report.shopUnits).toBeGreaterThan(0)
			expect(report.worked.Register).toBeGreaterThan(0)
		end)
		it("a Greeter brings more shoppers", function()
			local function run(boost)
				local state = PipelineRules.newState()
				state.shelves.Carrot = 1000
				state.shop.capacity = 1000
				state.shop.prices.Carrot = 18
				state.shop.boost = boost
				return PipelineRules.simulate(state, 2 * HOUR, 1, NOW, flat(18)).shopUnits
			end
			expect(run(0.25)).toBeGreaterThan(run(0) * 1.15)
		end)
		it("Stockers fill displays from the stockroom, up to capacity", function()
			local state = PipelineRules.newState()
			state.stockroom.Carrot = 500
			state.speeds.Shelves = 40
			local report = PipelineRules.simulate(state, 10 * 60, 1, NOW, flat(18))
			expect(state.shelves.Carrot).toBe(state.shop.capacity)
			expect(report.stocked).toBe(state.shop.capacity)
		end)
	end)

	describe("settling a whole absence", function()
		it("keeps crops growing past the workers' 8 hours", function()
			local state = PipelineRules.newState()
			state.tiles["1"] = GrowthRules.plant("CrystalRose") -- 24 h offline
			local report = PipelineRules.settle(state, 24 * HOUR, NOW)
			expect(report.minutes).toBe(8 * 60)
			expect(GrowthRules.isRipe(state.tiles["1"])).toBe(true)
		end)
		it("is the same as growing straight through when nobody works", function()
			local a, b = GrowthRules.plant("Moonmelon"), GrowthRules.plant("Moonmelon")
			local state = PipelineRules.newState()
			state.tiles["1"] = a
			PipelineRules.settle(state, 10 * HOUR, NOW)
			GrowthRules.offline(b, 10 * HOUR)
			expect(a.progress).toBeNear(b.progress, 1e-9)
		end)
	end)

	describe("wages and strikes", function()
		it("are paid at the offline rate for every simulated minute", function()
			local state = PipelineRules.newState()
			state.wages = 54
			local report = PipelineRules.simulate(state, 20 * HOUR, Workers.OFFLINE_RATE, NOW)
			expect(report.wages).toBe(54 * Workers.OFFLINE_RATE * 8 * 60)
		end)
		it("the crew strikes when the coins run out, and nothing is paid for it", function()
			local state = PipelineRules.newState()
			state.wages = 40
			state.coins = 100 -- 10 minutes at 10 a minute
			state.speeds.Sort = 30
			state.barn.Carrot = 1000
			local report = PipelineRules.simulate(state, HOUR, Workers.OFFLINE_RATE, NOW)
			expect(report.wages).toBe(100)
			expect(report.strikeMinutes).toBe(50)
			expect(state.coins).toBe(0)
			expect(report.worked.Sort).toBe(10)
		end)
		it("goes back to work when a sale brings coins in", function()
			local state = PipelineRules.newState()
			state.wages = 4
			state.coins = 0
			state.shelves.Carrot = 200
			state.shop.capacity = 200
			state.shop.prices.Carrot = 18
			local report = PipelineRules.simulate(state, HOUR, 1, NOW, flat(18))
			expect(report.strikeMinutes).toBeGreaterThan(0)
			expect(report.strikeMinutes < 60).toBe(true)
			expect(state.coins >= 0).toBe(true)
		end)
	end)
end
