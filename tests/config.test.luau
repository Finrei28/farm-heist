-- The config tables agree with each other and with the design doc: every id
-- points at something real, grow times sit in their rarity's band, and
-- profit per tile-minute rises with every rarity (docs/GameDesign.md §6.1).
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local Crops = harness.load("Config/Crops")
	local Rarities = harness.load("Config/Rarities")
	local Land = harness.load("Config/Land")
	local Crime = harness.load("Config/Crime")
	local Workers = harness.load("Config/Workers")
	local Shop = harness.load("Config/Shop")
	local Warehouse = harness.load("Config/Warehouse")
	local GrowthRules = harness.load("GrowthRules")

	describe("crops", function()
		it("are 22, each with a real rarity and positive numbers", function()
			expect(#Crops.List).toBe(22)
			for _, crop in Crops.List do
				expect(Rarities.ById[crop.rarity] ~= nil).toBe(true)
				expect(crop.seed).toBeGreaterThan(0)
				expect(crop.grow).toBeGreaterThan(0)
				expect(crop.value).toBeGreaterThan(0)
				expect(Crops.ById[crop.id]).toBe(crop)
			end
		end)
		it("grow within their rarity's band (§4.2)", function()
			local bands = {
				Common = { 60, 150 }, Uncommon = { 240, 360 }, Rare = { 720, 1200 },
				Epic = { 2400, 3600 }, Legendary = { 7200, 10800 }, Mythic = { 21600, 21600 },
			}
			for _, crop in Crops.List do
				local band = bands[crop.rarity]
				expect(crop.grow).toBeAtLeast(band[1])
				expect(crop.grow <= band[2]).toBe(true)
			end
		end)
		it("pay more per tile-minute at every rarity than any crop of the rarity below", function()
			local low, high = {}, {}
			for _, crop in Crops.List do
				local profit = GrowthRules.profitPerMinute(crop.id)
				low[crop.rarity] = math.min(low[crop.rarity] or math.huge, profit)
				high[crop.rarity] = math.max(high[crop.rarity] or -math.huge, profit)
			end
			for index = 2, #Rarities.List do
				local below, this = Rarities.List[index - 1].id, Rarities.List[index].id
				if not (low[this] > high[below]) then
					error(`{this} (from {low[this]}) doesn't beat {below} (up to {high[below]})`)
				end
			end
		end)
		it("match the doc's profit column", function()
			expect(GrowthRules.profitPerMinute("Carrot")).toBeNear(8, 0.01)
			expect(GrowthRules.profitPerMinute("Tomato")).toBeNear(12.35, 0.01)
			expect(GrowthRules.profitPerMinute("Pumpkin")).toBeNear(14, 0.01)
			expect(GrowthRules.profitPerMinute("GoldenApple")).toBeNear(29.8, 0.05)
		end)
	end)

	describe("rarities", function()
		it("fit in the Loot Sack, and a Legendary or Mythic fills it", function()
			for _, rarity in Rarities.List do
				expect(rarity.sackWeight <= Crime.SACK_CAPACITY).toBe(true)
			end
			expect(Rarities.ById.Legendary.sackWeight).toBe(Crime.SACK_CAPACITY)
			expect(Rarities.ById.Mythic.sackWeight).toBe(Crime.SACK_CAPACITY)
		end)
		it("take longer to steal the rarer they are", function()
			for index = 2, #Rarities.List do
				expect(Rarities.List[index].stealHold).toBeGreaterThan(Rarities.List[index - 1].stealHold)
			end
		end)
	end)

	describe("land", function()
		it("has 4 start blocks plus 12 permits: the whole 8×8", function()
			expect(#Land.START_BLOCKS).toBe(4)
			expect(#Land.PERMITS).toBe(12)
			expect((#Land.START_BLOCKS + #Land.PERMITS) * Land.BLOCK_TILES ^ 2).toBe(Land.GRID_TILES ^ 2)
		end)
		it("asks for higher levels and bigger fees, permit after permit", function()
			for index = 2, #Land.PERMITS do
				expect(Land.PERMITS[index].level).toBeGreaterThan(Land.PERMITS[index - 1].level)
				expect(Land.PERMITS[index].fee).toBeGreaterThan(Land.PERMITS[index - 1].fee)
			end
			expect(Land.PERMITS[1].level).toBe(2)
			expect(Land.PERMITS[12].level).toBe(32)
		end)
	end)

	describe("buildings and workers", function()
		it("have caps for every building tier", function()
			for name, kind in Workers.TYPES do
				if kind.caps then
					if #kind.caps ~= #Warehouse.TIERS or #kind.caps ~= #Shop.TIERS then
						error(`{name} has {#kind.caps} caps`)
					end
				end
			end
		end)
		it("give one Driver slot per truck", function()
			for index, tier in Warehouse.TIERS do
				expect(Workers.TYPES.Driver.caps[index]).toBe(if index == 1 then 0 else tier.trucks)
			end
		end)
		it("give one Cashier slot per register", function()
			for index, tier in Shop.TIERS do
				expect(Workers.TYPES.Cashier.caps[index]).toBe(tier.registers)
			end
		end)
	end)
end
