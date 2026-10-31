-- The truck (shared/TruckRules): loading, the price locking at dispatch,
-- payment on arrival (once only), and the truck coming home.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local TruckRules = harness.load("TruckRules")
	local Warehouse = harness.load("Config/Warehouse")

	local function newWarehouse()
		return { tier = 0, bed = {}, dock = {}, trucks = {} }
	end
	local function crate(crop, units, grade)
		return { crop = crop, key = `{crop}||`, units = units, grade = grade or "B" }
	end
	local pickup = Warehouse.TIERS[1]

	describe("loading", function()
		it("fills the pickup's bed up to 4 crates", function()
			local warehouse = newWarehouse()
			for _ = 1, pickup.truckCrates do
				expect(TruckRules.load(warehouse, crate("Carrot", 12), 0)).toBe(nil)
			end
			expect(TruckRules.load(warehouse, crate("Carrot", 12), 0)).toBe("TruckFull")
			expect(#warehouse.bed).toBe(4)
		end)
		it("can't load while the truck is out", function()
			local warehouse = newWarehouse()
			TruckRules.load(warehouse, crate("Carrot", 12), 0)
			TruckRules.dispatch(warehouse, 0, function()
				return 20
			end)
			expect(TruckRules.load(warehouse, crate("Carrot", 12), 10)).toBe("TruckAway")
			expect(TruckRules.load(warehouse, crate("Carrot", 12), pickup.roundTrip)).toBe(nil)
		end)
	end)

	describe("dispatching", function()
		it("locks every crate's price when the truck leaves", function()
			local warehouse = newWarehouse()
			TruckRules.load(warehouse, crate("Carrot", 12, "A"), 0)
			TruckRules.load(warehouse, crate("Pumpkin", 6), 0)
			local prices = { Carrot = 20, Pumpkin = 600 }
			local run = TruckRules.dispatch(warehouse, 100, function(cropId)
				return prices[cropId]
			end)
			expect(run.coins).toBe(276 + 3600)
			expect(run.crates[1].price).toBe(20)
			expect(run.crates[2].coins).toBe(3600)
			expect(run.arriveAt).toBe(100 + pickup.roundTrip / 2)
			expect(run.returnAt).toBe(100 + pickup.roundTrip)
			expect(#warehouse.bed).toBe(0)
			prices.Pumpkin = 1 -- the market crashing after it left changes nothing
			expect(run.coins).toBe(3876)
		end)
		it("won't leave empty, or twice", function()
			local warehouse = newWarehouse()
			local run, why = TruckRules.dispatch(warehouse, 0, function()
				return 1
			end)
			expect(run).toBe(nil)
			expect(why).toBe("TruckEmpty")
			TruckRules.load(warehouse, crate("Carrot", 1), 0)
			TruckRules.dispatch(warehouse, 0, function()
				return 1
			end)
			warehouse.bed = { crate("Carrot", 1) }
			run, why = TruckRules.dispatch(warehouse, 5, function()
				return 1
			end)
			expect(why).toBe("TruckAway")
		end)
	end)

	describe("payment", function()
		it("pays when the truck reaches the City, once", function()
			local warehouse = newWarehouse()
			TruckRules.load(warehouse, crate("Carrot", 12), 0)
			TruckRules.dispatch(warehouse, 0, function()
				return 20
			end)
			expect(#TruckRules.collect(warehouse, pickup.roundTrip / 2 - 1)).toBe(0)
			local due = TruckRules.collect(warehouse, pickup.roundTrip / 2)
			expect(#due).toBe(1)
			expect(due[1].coins).toBe(240)
			expect(#TruckRules.collect(warehouse, pickup.roundTrip / 2 + 5)).toBe(0)
		end)
		it("pays a run that arrived while you were away when you come back", function()
			local warehouse = newWarehouse()
			TruckRules.load(warehouse, crate("Carrot", 12), 0)
			TruckRules.dispatch(warehouse, 0, function()
				return 20
			end)
			local due = TruckRules.collect(warehouse, 86400)
			expect(#due).toBe(1)
			expect(TruckRules.tidy(warehouse, 86400)).toBe(1)
			expect(#warehouse.trucks).toBe(0)
		end)
		it("keeps an unpaid run even after the truck is home", function()
			local warehouse = newWarehouse()
			TruckRules.load(warehouse, crate("Carrot", 12), 0)
			TruckRules.dispatch(warehouse, 0, function()
				return 20
			end)
			expect(TruckRules.tidy(warehouse, pickup.roundTrip * 2)).toBe(0)
			expect(TruckRules.home(warehouse, pickup.roundTrip * 2)).toBe(1)
		end)
	end)

	describe("trucks home", function()
		it("counts the bigger warehouses' second truck", function()
			local warehouse = newWarehouse()
			warehouse.tier = 2
			expect(TruckRules.home(warehouse, 0)).toBe(2)
			TruckRules.load(warehouse, crate("Carrot", 12), 0)
			TruckRules.dispatch(warehouse, 0, function()
				return 20
			end)
			expect(TruckRules.home(warehouse, 1)).toBe(1)
			expect(TruckRules.load(warehouse, crate("Carrot", 12), 1)).toBe(nil)
			expect(TruckRules.nextBack(warehouse, 1).returnAt).toBe(Warehouse.TIERS[3].roundTrip)
		end)
	end)
end
