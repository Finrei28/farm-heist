-- Packed crates (shared/PackRules): one stock for the trucks and the store,
-- what the crew does with each crate, and choosing crates at the dock.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local PackRules = harness.load("PackRules")
	local ShopRules = harness.load("ShopRules")
	local StoreLayout = harness.load("StoreLayout")
	local WarehouseRules = harness.load("WarehouseRules")

	local function save(warehouseLevel, storeLevel)
		return {
			warehouse = { level = warehouseLevel or 1, routes = {} },
			store = { level = storeLevel or 1, stockroom = {} },
		}
	end

	local function crate(cropId, grade, key)
		return { crop = cropId, key = key or `{cropId}||`, units = 12, grade = grade or "B" }
	end

	describe("what the crew may pack", function()
		local function warehouse(routes, packs)
			return { level = 1, routes = routes or {}, packs = packs }
		end
		it("takes plain crops by their route", function()
			expect(PackRules.crewTakes(warehouse(), "Carrot||")).toBe(true)
			expect(PackRules.crewTakes(warehouse({ Carrot = 0 }), "Carrot||")).toBe(true)
			expect(PackRules.crewTakes(warehouse({ Carrot = "Keep" }), "Carrot||")).toBe(false)
		end)
		it("leaves mutated and Giant crops until you pick them, even on an old save", function()
			expect(PackRules.crewTakes(warehouse(), "Carrot|Golden|")).toBe(false)
			expect(PackRules.crewTakes(warehouse(nil, {}), "Carrot||G")).toBe(false)
		end)
		it("takes only the kinds you've picked", function()
			local picked = warehouse(nil, { Golden = true })
			expect(PackRules.crewTakes(picked, "Carrot|Golden|")).toBe(true)
			expect(PackRules.crewTakes(picked, "Carrot|Frosted|")).toBe(false)
			expect(PackRules.crewTakes(picked, "Carrot||")).toBe(true)
		end)
		it("wants both picked for a Giant mutated crop", function()
			expect(PackRules.crewTakes(warehouse(nil, { Golden = true }), "Carrot|Golden|G")).toBe(false)
			expect(PackRules.crewTakes(warehouse(nil, { Giant = true }), "Carrot|Golden|G")).toBe(false)
			expect(PackRules.crewTakes(warehouse(nil, { Golden = true, Giant = true }), "Carrot|Golden|G")).toBe(true)
		end)
		it("still keeps a kept crop, whatever you've picked", function()
			expect(PackRules.crewTakes(warehouse({ Carrot = "Keep" }, { Golden = true }), "Carrot|Golden|")).toBe(false)
		end)
	end)

	describe("its size", function()
		it("is the rack's and the stockroom's room together", function()
			expect(PackRules.size(save())).toBe(WarehouseRules.level(1).hold + StoreLayout.level(1).stockroom)
		end)
		it("grows with either building", function()
			local start = PackRules.size(save())
			expect(PackRules.size(save(3, 1)) > start).toBe(true)
			expect(PackRules.size(save(1, 3)) > start).toBe(true)
		end)
		it("counts what's left, never below nothing", function()
			local data = save()
			expect(PackRules.room(data)).toBe(PackRules.size(data))
			table.insert(data.store.stockroom, crate("Carrot"))
			expect(PackRules.room(data)).toBe(PackRules.size(data) - 1)
			for _ = 1, 40 do
				table.insert(data.store.stockroom, crate("Carrot"))
			end
			expect(PackRules.room(data)).toBe(0)
		end)
	end)

	describe("what the crew does with a crate", function()
		it("by default it goes on the truck", function()
			expect(PackRules.crewUse(save().warehouse, crate("Carrot"))).toBe("Truck")
		end)
		it("a crop routed to the store is for the displays, never the truck", function()
			local data = save()
			data.warehouse.routes.Carrot = 0
			expect(PackRules.crewUse(data.warehouse, crate("Carrot"))).toBe("Store")
			table.insert(data.store.stockroom, crate("Carrot"))
			expect(PackRules.nextForTruck(data)).toBe(nil)
			expect(PackRules.nextForStore(data)).toBe(1)
		end)
		it("a crop you keep is left alone either way", function()
			local data = save()
			data.warehouse.routes.Carrot = "Keep"
			table.insert(data.store.stockroom, crate("Carrot"))
			expect(PackRules.nextForTruck(data)).toBe(nil)
			expect(PackRules.nextForStore(data)).toBe(nil)
		end)
		it("a split's crate goes the way it leans", function()
			local data = save(5)
			data.warehouse.routes.Carrot = 0.5
			local leaning = crate("Carrot")
			leaning.lean = "Store"
			expect(PackRules.crewUse(data.warehouse, leaning)).toBe("Store")
			expect(PackRules.crewUse(data.warehouse, crate("Carrot"))).toBe("Truck")
		end)
		it("a route overrules an old lean", function()
			local data = save()
			local leaning = crate("Carrot")
			leaning.lean = "Store"
			expect(PackRules.crewUse(data.warehouse, leaning)).toBe("Truck")
		end)
		it("a mutated crate goes by truck, and never for a crop ticked for the store", function()
			local data = save()
			local golden = crate("Carrot", "A", "Carrot|Golden|")
			expect(PackRules.crewUse(data.warehouse, golden)).toBe("Truck")
			data.warehouse.routes.Carrot = 0 -- (the user: "still packing crates onto the truck even though it's ticked for the store")
			expect(PackRules.crewUse(data.warehouse, golden)).toBe(nil)
			data.store.stockroom = { golden }
			expect(PackRules.nextForTruck(data)).toBe(nil)
			expect(PackRules.nextForStore(data)).toBe(nil)
		end)
		it("doesn't pack a mutated stack for a crop ticked for the store, even on Pack", function()
			local data = save()
			data.warehouse.packs = { Golden = true }
			expect(PackRules.crewTakes(data.warehouse, "Carrot|Golden|")).toBe(true)
			data.warehouse.routes.Carrot = 0
			expect(PackRules.crewTakes(data.warehouse, "Carrot|Golden|")).toBe(false)
			expect(PackRules.crewTakes(data.warehouse, "Carrot||")).toBe(true)
		end)
		it("finds the first crate for each, past the others", function()
			local data = save()
			data.warehouse.routes.Carrot = 0
			data.store.stockroom = { crate("Carrot"), crate("Tomato"), crate("Carrot") }
			expect(PackRules.nextForTruck(data)).toBe(2)
			expect(PackRules.nextForStore(data)).toBe(1)
		end)
	end)

	describe("sending crates to the stockroom", function()
		local function stocked(...)
			local data = save()
			data.store.stockroom = { ... }
			return data
		end
		it("makes them the store's, whatever the crop's route", function()
			local data = stocked(crate("Tomato"), crate("Tomato"))
			expect(PackRules.crewUse(data.warehouse, data.store.stockroom[1])).toBe("Truck")
			expect(PackRules.send(data, "Tomato||", "B", 1)).toBe(1)
			expect(PackRules.crewUse(data.warehouse, data.store.stockroom[1])).toBe("Store")
			expect(PackRules.crewUse(data.warehouse, data.store.stockroom[2])).toBe("Truck")
			local rack, shelf = PackRules.sides(data)
			expect(#rack).toBe(1)
			expect(#shelf).toBe(1)
			expect(PackRules.nextForTruck(data)).toBe(2)
			expect(PackRules.nextForStore(data)).toBe(1)
		end)
		it("takes a crop on Keep too", function()
			local data = stocked(crate("Tomato"))
			data.warehouse.routes.Tomato = "Keep"
			expect(PackRules.crewUse(data.warehouse, data.store.stockroom[1])).toBe(nil)
			expect(PackRules.send(data, "Tomato||", "B", 1)).toBe(1)
			expect(PackRules.crewUse(data.warehouse, data.store.stockroom[1])).toBe("Store")
		end)
		it("only sends the stack you picked, and as many as you asked for", function()
			local data = stocked(crate("Tomato", "A"), crate("Tomato"), crate("Tomato"), crate("Carrot"))
			expect(PackRules.send(data, "Tomato||", "B", 5)).toBe(2)
			expect(data.store.stockroom[1].to).toBe(nil)
			expect(data.store.stockroom[4].to).toBe(nil)
		end)
		it("never sends a crate twice", function()
			local data = stocked(crate("Tomato"))
			expect(PackRules.send(data, "Tomato||", "B", 1)).toBe(1)
			expect(PackRules.send(data, "Tomato||", "B", 1)).toBe(0)
		end)
		it("leaves mutated crates alone: they go by truck", function()
			local data = stocked(crate("Tomato", "B", "Tomato|Golden|"))
			expect(PackRules.send(data, "Tomato|Golden|", "B", 1)).toBe(0)
			data.store.stockroom[1].to = "Store" -- (even a save that says otherwise)
			expect(PackRules.crewUse(data.warehouse, data.store.stockroom[1])).toBe("Truck")
		end)
		it("stops when the stockroom's full", function()
			local data = stocked()
			local size = PackRules.stockroomSize(data)
			for _ = 1, size + 2 do
				table.insert(data.store.stockroom, crate("Tomato"))
			end
			expect(PackRules.send(data, "Tomato||", "B", 99)).toBe(size)
			expect(PackRules.stockroomRoom(data)).toBe(0)
			expect(PackRules.send(data, "Tomato||", "B", 1)).toBe(0)
		end)
	end)

	describe("where it's drawn", function()
		it("the store's crates in the stockroom, the rest on the rack, none lost", function()
			local data = save()
			data.warehouse.routes.Carrot = 0
			data.store.stockroom = { crate("Carrot"), crate("Tomato"), crate("Tomato") }
			local rack, shelf = PackRules.sides(data)
			expect(#rack).toBe(2)
			expect(#shelf).toBe(1)
		end)
	end)

	describe("choosing at the dock", function()
		it("groups crates that are alike, keeping grades and mutations apart", function()
			local list = PackRules.stacks({ crate("Carrot"), crate("Carrot"), crate("Carrot", "A"), crate("Carrot", "B", "Carrot|Wet|") })
			expect(#list).toBe(3)
			local total = 0
			for _, stack in list do
				total += stack.crates
			end
			expect(total).toBe(4)
		end)
		it("adds up the crates and units in a stack", function()
			local stack = PackRules.stacks({ crate("Carrot"), crate("Carrot") })[1]
			expect(stack.crates).toBe(2)
			expect(stack.units).toBe(24)
		end)
		it("puts the most valuable crop first", function()
			local list = PackRules.stacks({ crate("Carrot"), crate("Pumpkin") })
			expect(list[1].crop).toBe("Pumpkin")
		end)
		it("takes the oldest of a stack, up to how many you asked for", function()
			local first, second = crate("Carrot"), crate("Carrot")
			local crates = { crate("Tomato"), first, second, crate("Carrot") }
			local taken = PackRules.take(crates, "Carrot||", "B", 2)
			expect(#taken).toBe(2)
			expect(taken[1]).toBe(first)
			expect(taken[2]).toBe(second)
			expect(#crates).toBe(2)
		end)
		it("takes nothing that doesn't match", function()
			local crates = { crate("Carrot", "B") }
			expect(#PackRules.take(crates, "Carrot||", "A", 1)).toBe(0)
			expect(#PackRules.take(crates, "Tomato||", "B", 1)).toBe(0)
			expect(#crates).toBe(1)
		end)
		it("copes with an old crate that has no key", function()
			local old = { crop = "Carrot", units = 12, grade = "B" }
			expect(#PackRules.take({ old }, "Carrot||", "B", 1)).toBe(1)
		end)
	end)

	describe("the store's side", function()
		local function store(crates)
			local layout = {}
			layout["1"] = { item = "ProduceCrate", x = 1, y = 3, rot = 0, slots = StoreLayout.newSlots("ProduceCrate") }
			return { level = 1, layout = layout, stockroom = crates, prices = {}, rating = { scores = {} } }
		end
		local function price()
			return 10
		end

		it("a mutated crate never goes on a shelf: it would lose its worth", function()
			local shop = store({ crate("Carrot", "B", "Carrot|Wet|") })
			expect(ShopRules.fill(shop, "1", price)).toBe(0)
			expect(#shop.stockroom).toBe(1)
			expect(ShopRules.stockroomUnits(shop).Carrot).toBe(nil)
		end)
		it("by hand any plain crate goes out, whatever its route", function()
			local shop = store({ crate("Carrot") })
			expect(ShopRules.fill(shop, "1", price)).toBe(12)
		end)
		it("the crew only puts out what's routed to the store", function()
			local data = save()
			local shop = store({ crate("Carrot") })
			local allow = PackRules.forStore(data.warehouse)
			expect(ShopRules.restockDisplays(shop, price, 8, allow)).toBe(0)
			expect(ShopRules.nextDisplay(shop, nil, allow)).toBe(nil)
			data.warehouse.routes.Carrot = 0
			expect(ShopRules.nextDisplay(shop, nil, allow)).toBe("1")
			expect(ShopRules.restockDisplays(shop, price, 8, allow) > 0).toBe(true)
		end)
	end)
end
