-- The farm running while you're away (shared/PipelineRules): growth,
-- Farmhands, the warehouse, trucks, the shop and wages, with nothing lost or
-- made up along the way.
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
		for _, crate in state.truckQueue do
			total += crate.units
		end
		for _, crate in state.bed do
			total += crate.units
		end
		for _, run in report.runs do
			total += run.crates * 12 -- (carrots: 12 to a crate)
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
		end)
	end)

	describe("the warehouse and the truck", function()
		local function crew(state)
			state.speeds.Sort, state.speeds.Pack, state.speeds.Load = 30, 7.5, 10
			state.drivers = 1
			state.truck = { crates = 4, roundTrip = 60, backAt = 0 }
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
		end)
		it("never loses or makes up a carrot", function()
			local state = PipelineRules.newState()
			crew(state)
			state.barn.Carrot = 1000
			local report = PipelineRules.simulate(state, 2 * HOUR, Workers.OFFLINE_RATE, NOW, flat(20))
			expect(unitsIn(state, report)).toBe(1000)
		end)
		it("wait for you without a Driver", function()
			local state = PipelineRules.newState()
			crew(state)
			state.drivers = 0
			state.barn.Carrot = 240
			local report = PipelineRules.simulate(state, HOUR, 1, NOW, flat(20))
			expect(report.shippedCrates).toBe(0)
			expect(#state.bed).toBe(4)
		end)
		it("follow the Driver's price rule", function()
			local state = PipelineRules.newState()
			crew(state)
			state.minPrice = 1.0
			state.barn.Carrot = 240
			local report = PipelineRules.simulate(state, HOUR, 1, NOW, flat(15)) -- below the base 18
			expect(report.shippedCrates).toBe(0)
		end)
		it("split crates between truck and shop as routed", function()
			local state = PipelineRules.newState()
			crew(state)
			state.routes.Carrot = 0.5
			state.barn.Carrot = 240
			local report = PipelineRules.simulate(state, HOUR, 1, NOW, flat(20))
			expect(report.crates).toBe(20)
			expect(report.shippedCrates).toBe(8) -- 10 for the truck: two full loads, 2 crates waiting
			expect(#state.truckQueue + #state.bed).toBe(2)
			expect(state.stockroom.Carrot).toBe(120)
		end)
		it("a Shed Hand packs and loads on its own at T0", function()
			local state = PipelineRules.newState()
			state.speeds.Shed = 4
			state.drivers = 1
			state.barn.Carrot = 48
			local report = PipelineRules.simulate(state, HOUR, 1, NOW, flat(20))
			expect(report.shippedCrates).toBe(4)
		end)
	end)

	describe("the shop", function()
		it("sells from the shelves at your price; a silly price sells less", function()
			local function run(price)
				local state = PipelineRules.newState()
				state.shelves.Carrot = 40
				state.shop.prices.Carrot = price
				return PipelineRules.simulate(state, HOUR, 1, NOW, flat(18))
			end
			local fair, silly = run(18), run(60)
			expect(fair.shopUnits).toBeGreaterThan(silly.shopUnits)
			expect(fair.shopCoins).toBe(fair.shopUnits * 18)
			expect(fair.shopUnits <= 40).toBe(true)
		end)
		it("a bigger shop needs a Cashier", function()
			local state = PipelineRules.newState()
			state.shop.tier = 1
			state.shelves.Carrot = 40
			state.shop.prices.Carrot = 18
			local report = PipelineRules.simulate(state, HOUR, 1, NOW, flat(18))
			expect(report.shopUnits).toBe(0)
			state.speeds.Register = 6
			report = PipelineRules.simulate(state, HOUR, 1, NOW, flat(18))
			expect(report.shopUnits).toBeGreaterThan(0)
		end)
		it("Stockers fill shelves from the stockroom, up to capacity", function()
			local state = PipelineRules.newState()
			state.stockroom.Carrot = 500
			state.speeds.Shelves = 40
			PipelineRules.simulate(state, 10 * 60, 1, NOW, flat(18))
			expect(state.shelves.Carrot).toBe(state.shop.capacity)
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

	describe("wages", function()
		it("are paid at the offline rate for every simulated minute", function()
			local state = PipelineRules.newState()
			state.wages = 54
			local report = PipelineRules.simulate(state, 20 * HOUR, Workers.OFFLINE_RATE, NOW)
			expect(report.wages).toBe(54 * Workers.OFFLINE_RATE * 8 * 60)
		end)
	end)
end
