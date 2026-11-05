-- The save's shape (server/Util/SaveData): new saves start right, and old
-- saves gain new fields without losing anything.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local SaveData = harness.loadServer("Util/SaveData")
	local Settings = harness.load("Config/Settings")

	describe("crates that were waiting for a truck", function()
		it("join the one stock, with what was in the stockroom", function()
			local data = SaveData.deepCopy(SaveData.TEMPLATE)
			data.warehouse.dock = { { crop = "Carrot", key = "Carrot||", units = 72, grade = "A" } }
			data.store.stockroom = { { crop = "Wheat", key = "Wheat||", units = 12, grade = "B" } }
			data.store.started = true
			SaveData.migrate(data)
			expect(#data.store.stockroom).toBe(2)
			expect(data.warehouse.dock).toBe(nil)
		end)
		it("a new save has no second pile", function()
			expect(SaveData.TEMPLATE.warehouse.dock).toBe(nil)
		end)
	end)

	describe("a purse that isn't a number", function()
		local function loaded(coins)
			local data = SaveData.deepCopy(SaveData.TEMPLATE)
			data.coins = coins
			SaveData.migrate(data)
			return data.coins
		end
		it("is emptied, or it would pass every price check", function()
			expect(loaded(0 / 0)).toBe(0)
			expect(loaded(math.huge)).toBe(0)
			expect(loaded(-math.huge)).toBe(0)
		end)
		it("a real one is left alone, even below zero", function()
			expect(loaded(4200)).toBe(4200)
			expect(loaded(-950)).toBe(-950)
		end)
	end)

	describe("a new save", function()
		it("starts with 100 coins, 5 Carrot seeds and level 1", function()
			local data = SaveData.deepCopy(SaveData.TEMPLATE)
			expect(data.coins).toBe(Settings.START_COINS)
			expect(data.inventory.seeds.Carrot).toBe(5)
			expect(data.level).toBe(1)
			expect(#data.land.cleared).toBe(0)
		end)
		it("is a copy: changing one save never touches the template", function()
			local data = SaveData.deepCopy(SaveData.TEMPLATE)
			data.inventory.seeds.Carrot = 0
			expect(SaveData.TEMPLATE.inventory.seeds.Carrot).toBe(5)
		end)
	end)

	describe("your store", function()
		it("starts furnished with the starter kit, all free", function()
			local data = SaveData.deepCopy(SaveData.TEMPLATE)
			SaveData.migrate(data)
			local count = 0
			for _ in data.store.layout do
				count += 1
			end
			expect(count).toBe(5)
			expect(data.store.owned.ProduceCrate).toBe(2)
			expect(data.store.gifts.ProduceCrate).toBe(2)
			expect(data.store.nextId).toBe(6)
			local StoreLayout = harness.load("StoreLayout")
			expect((StoreLayout.check(data.store.layout, 1))).toBe(true)
		end)
		it("isn't furnished again on the next load, even after selling things", function()
			local data = SaveData.deepCopy(SaveData.TEMPLATE)
			SaveData.migrate(data)
			data.store.layout["4"] = nil
			SaveData.reconcile(data, SaveData.TEMPLATE)
			SaveData.migrate(data)
			expect(data.store.layout["4"]).toBe(nil)
			expect(data.store.nextId).toBe(6)
		end)
		it("turns an old Honour Box into the Shop Counter (a till you serve at), moving it if its back is to a wall", function()
			local StoreLayout = harness.load("StoreLayout")
			local data = SaveData.deepCopy(SaveData.TEMPLATE)
			SaveData.migrate(data)
			-- yesterday's starter store: the Honour Box in the corner by the door
			data.store.layout["5"] = { item = "HonourBox", x = 6, y = 1, rot = 2 }
			data.store.owned.ShopCounter, data.store.gifts.ShopCounter = nil, nil
			data.store.owned.HonourBox, data.store.gifts.HonourBox = 2, 1
			SaveData.migrate(data)
			local counter = data.store.layout["5"]
			expect(counter.item).toBe("ShopCounter")
			expect(`{counter.x},{counter.y},{counter.rot}`).toBe("2,2,3") -- (inside the staff door, like a new store's)
			expect(data.store.owned.ShopCounter).toBe(2)
			expect(data.store.gifts.ShopCounter).toBe(1)
			expect(data.store.owned.HonourBox).toBe(nil)
			expect((StoreLayout.check(data.store.layout, 1))).toBe(true)
		end)
		it("leaves a converted counter where it stood when there's room behind it", function()
			local StoreLayout = harness.load("StoreLayout")
			local data = SaveData.deepCopy(SaveData.TEMPLATE)
			SaveData.migrate(data)
			data.store.level = 3
			StoreLayout.grow(data.store.layout, 1, 3)
			data.store.layout["5"] = { item = "HonourBox", x = 6, y = 2, rot = 1 } -- (faces the door's side; free cell behind)
			SaveData.migrate(data)
			local counter = data.store.layout["5"]
			expect(`{counter.item} {counter.x},{counter.y},{counter.rot}`).toBe("ShopCounter 6,2,1")
			expect((StoreLayout.check(data.store.layout, 3))).toBe(true)
		end)
		it("takes over the Farm Stand's goods, prices and rating", function()
			local old = { shop = { tier = 0, shelves = { ["1"] = { crop = "Carrot", units = 9, a = 4 } },
				stockroom = { { crop = "Wheat", key = "Wheat||", units = 12, grade = "B" } },
				prices = { Carrot = 24 }, rating = { scores = { 5, 5, 2 } } } }
			SaveData.reconcile(old, SaveData.TEMPLATE)
			SaveData.migrate(old)
			expect(old.shop).toBe(nil)
			local units = {}
			for _, crate in old.store.stockroom do
				units[crate.crop] = (units[crate.crop] or 0) + crate.units
			end
			expect(units.Carrot).toBe(9)
			expect(units.Wheat).toBe(12)
			expect(old.store.prices.Carrot).toBe(24)
			expect(#old.store.rating.scores).toBe(3)
		end)
	end)

	describe("an old save", function()
		it("gains new fields and keeps its own values", function()
			local old = { coins = 1234, inventory = { seeds = { Pumpkin = 2 } } }
			SaveData.reconcile(old, SaveData.TEMPLATE)
			expect(old.coins).toBe(1234)
			expect(old.inventory.seeds.Pumpkin).toBe(2)
			expect(old.inventory.crops ~= nil).toBe(true)
			expect(old.crime.debts ~= nil).toBe(true)
		end)
		it("turns week 2's warehouse into Warehouse Level 1, its pickup's crates still loaded", function()
			local old = { warehouse = { tier = 0, buildingUntil = 0, queues = {}, routes = {}, dock = {}, trucks = {},
				bed = { { crop = "Carrot", key = "Carrot||", units = 12, grade = "A" } } } }
			SaveData.reconcile(old, SaveData.TEMPLATE)
			SaveData.migrate(old)
			expect(old.warehouse.level).toBe(1)
			expect(old.warehouse.tier).toBe(nil)
			expect(old.warehouse.bed).toBe(nil)
			expect(#old.warehouse.beds).toBe(1)
			expect(old.warehouse.beds[1][1].units).toBe(12)
			expect(old.crew.replant).toBe("same")
		end)
	end)

	describe("for DataStores", function()
		it("has no sparse number keys (they don't survive JSON)", function()
			local function check(value, path)
				if typeof(value) ~= "table" then
					return
				end
				local count, max = 0, 0
				for key, child in value do
					if typeof(key) == "number" then
						count += 1
						max = math.max(max, key)
					end
					check(child, `{path}.{tostring(key)}`)
				end
				if count > 0 and count ~= max then
					error(`{path} has sparse number keys`)
				end
			end
			check(SaveData.TEMPLATE, "save")
		end)
	end)
end
