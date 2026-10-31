-- Warehouse Levels (shared/WarehouseRules): what each level adds up to,
-- what's new at each one, levelling up and the buildings going up, routes,
-- and old saves.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local WarehouseRules = harness.load("WarehouseRules")
	local Warehouse = harness.load("Config/Warehouse")

	local function newWarehouse(level)
		local warehouse = { level = level or 1, routes = {}, beds = {}, dock = {}, sorted = {}, trucks = {} }
		WarehouseRules.finish(warehouse, warehouse.level)
		return warehouse
	end

	describe("levels", function()
		it("add up the table (§4.6)", function()
			local one = WarehouseRules.level(1)
			expect(one.truckCrates).toBe(4)
			expect(one.roundTrip).toBe(60)
			expect(one.hold).toBe(6)
			expect(one.building.id).toBe("PackingShed")
			local three = WarehouseRules.level(3)
			expect(three.truckCrates).toBe(5)
			expect(three.roundTrip).toBe(50)
			expect(three.hold).toBe(10)
			local nine = WarehouseRules.level(9)
			expect(nine.building.id).toBe("Warehouse")
			expect(nine.truck).toBe("BoxTruck")
			expect(nine.truckCrates).toBe(16)
			expect(nine.roundTrip).toBe(75)
			expect(nine.conveyors).toBe(1.1)
			expect(nine.hold).toBe(30)
			local fifteen = WarehouseRules.level(15)
			expect(fifteen.trucks).toBe(2)
			expect(fifteen.premium).toBe(0.1)
			expect(fifteen.washLine).toBe(true)
			local top = WarehouseRules.level(20)
			expect(top.trucks).toBe(3)
			expect(top.truckCrates).toBe(40)
			expect(top.roundTrip).toBe(80)
			expect(top.hold).toBe(150)
			expect(top.conveyors).toBe(1.5)
		end)
		it("each one adds something you can feel", function()
			for n = 2, WarehouseRules.MAX_LEVEL do
				expect(#WarehouseRules.news(n) > 0).toBe(true)
			end
		end)
		it("cost more each level, need a higher Farm Level, and come to about 4.1 million", function()
			local total = 0
			for n = 2, WarehouseRules.MAX_LEVEL do
				local info, before = Warehouse.LEVELS[n], Warehouse.LEVELS[n - 1]
				expect(info.cost > before.cost).toBe(true)
				expect(info.farmLevel > before.farmLevel).toBe(true)
				total += info.cost
			end
			expect(total > 4_000_000 and total < 4_200_000).toBe(true)
		end)
		it("say what's new, including the building and worker slots", function()
			local news = table.concat(WarehouseRules.news(5), " | ")
			expect(string.find(news, "Distribution Warehouse", 1, true) ~= nil).toBe(true)
			expect(string.find(news, "Box Truck: 12 crates", 1, true) ~= nil).toBe(true)
			expect(string.find(news, "room for a Sorter", 1, true) ~= nil).toBe(true)
			expect(string.find(news, "room for a Driver", 1, true) ~= nil).toBe(true)
			local ten = table.concat(WarehouseRules.news(10), " | ")
			expect(string.find(ten, "2 Semis, 24 crates each", 1, true) ~= nil).toBe(true)
			expect(string.find(ten, "room for a 2nd Driver", 1, true) ~= nil).toBe(true)
			expect(string.find(table.concat(WarehouseRules.news(4), " | "), "room for a 2nd Shed Hand", 1, true) ~= nil).toBe(true)
			expect(string.find(table.concat(WarehouseRules.news(7), " | "), "conveyors 10% faster", 1, true) ~= nil).toBe(true)
		end)
	end)

	describe("levelling up", function()
		it("needs the Farm Level and the coins, one level at a time", function()
			local warehouse = newWarehouse()
			expect(WarehouseRules.cannotUpgrade(warehouse, 1, 10_000)).toBe("NeedLevel")
			expect(WarehouseRules.cannotUpgrade(warehouse, 2, 799)).toBe("NoCoins")
			expect(WarehouseRules.cannotUpgrade(warehouse, 2, 800)).toBe(nil)
			expect(WarehouseRules.upgrade(warehouse)).toBe("Built")
			expect(warehouse.level).toBe(2)
			expect(WarehouseRules.cannotUpgrade(newWarehouse(20), 50, 1e9)).toBe("MaxLevel")
		end)
		it("builds a new building over time, the old one working meanwhile", function()
			local warehouse = newWarehouse(4)
			expect(WarehouseRules.upgrade(warehouse)).toBe("Building")
			expect(warehouse.level).toBe(4)
			expect(warehouse.build.to).toBe(5)
			expect(WarehouseRules.cannotUpgrade(warehouse, 50, 1e9)).toBe("Building")
			expect(WarehouseRules.work(warehouse, 119)).toBe(false)
			expect(WarehouseRules.work(warehouse, 1)).toBe(true)
			expect(warehouse.level).toBe(5)
			expect(warehouse.build).toBe(nil)
		end)
	end)

	describe("routes", function()
		it("send everything by truck unless told otherwise", function()
			local warehouse = newWarehouse(5)
			expect(WarehouseRules.route(warehouse, "Carrot")).toBe(1)
			warehouse.routes.Carrot = 0
			expect(WarehouseRules.route(warehouse, "Carrot")).toBe(0)
			warehouse.routes.Carrot = "Keep"
			expect(WarehouseRules.route(warehouse, "Carrot")).toBe(nil)
			warehouse.routes.Carrot = 0.7
			expect(WarehouseRules.route(warehouse, "Carrot")).toBe(0.7)
		end)
		it("can only be split from Level 5", function()
			local warehouse = newWarehouse(4)
			warehouse.routes.Carrot = 0.7
			expect(WarehouseRules.route(warehouse, "Carrot")).toBe(1)
		end)
	end)

	describe("old saves", function()
		it("turn a tier into its building's first level and the bed into the first truck's", function()
			local old = { tier = 1, buildingUntil = 0, queues = {}, routes = {}, bed = { { crop = "Carrot", units = 12, grade = "B" } }, beds = {}, dock = {}, trucks = {}, level = 1 }
			WarehouseRules.migrate(old)
			expect(old.level).toBe(5)
			expect(old.tier).toBe(nil)
			expect(old.bed).toBe(nil)
			expect(#old.beds[1]).toBe(1)
		end)
	end)
end
