-- The save's shape (server/Util/SaveData): new saves start right, and old
-- saves gain new fields without losing anything.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local SaveData = harness.loadServer("Util/SaveData")
	local Settings = harness.load("Config/Settings")

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

	describe("an old save", function()
		it("gains new fields and keeps its own values", function()
			local old = { coins = 1234, inventory = { seeds = { Pumpkin = 2 } } }
			SaveData.reconcile(old, SaveData.TEMPLATE)
			expect(old.coins).toBe(1234)
			expect(old.inventory.seeds.Pumpkin).toBe(2)
			expect(old.inventory.crops ~= nil).toBe(true)
			expect(old.crime.debts ~= nil).toBe(true)
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
