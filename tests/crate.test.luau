-- Crates and washing by hand (shared/CrateRules), against docs/GameDesign.md §4.6.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local CrateRules = harness.load("CrateRules")
	local BarnRules = harness.load("BarnRules")
	local Warehouse = harness.load("Config/Warehouse")

	local WASH = Warehouse.WASH

	describe("crate sizes", function()
		it("fit 12 Commons, 10 Uncommons, 6 Rares, 4 Epics, 2 Legendaries, 1 Mythic", function()
			expect(CrateRules.size("Carrot")).toBe(12)
			expect(CrateRules.size("Corn")).toBe(10)
			expect(CrateRules.size("Pumpkin")).toBe(6)
			expect(CrateRules.size("Pineapple")).toBe(4)
			expect(CrateRules.size("Moonmelon")).toBe(2)
			expect(CrateRules.size("CrystalRose")).toBe(1)
		end)
	end)

	describe("washing", function()
		it("fills the meter in WASH.fill seconds and keeps it full", function()
			expect(CrateRules.meter(0)).toBe(0)
			expect(CrateRules.meter(WASH.fill / 2)).toBeNear(0.5, 1e-9)
			expect(CrateRules.meter(WASH.fill * 3)).toBe(1)
		end)
		it("gives grade A only for a let-go in the green", function()
			local middle = (WASH.greenMin + WASH.greenMax) / 2 * WASH.fill
			expect(CrateRules.grade(middle)).toBe("A")
			expect(CrateRules.grade(0.1)).toBe("B") -- still muddy
			expect(CrateRules.grade(WASH.fill * 2)).toBe("B") -- over-sprayed
		end)
		it("gives the server's slack either side of the green", function()
			local justEarly = WASH.greenMin * WASH.fill - 0.05
			expect(CrateRules.grade(justEarly)).toBe("B")
			expect(CrateRules.grade(justEarly, WASH.slack)).toBe("A")
			local justLate = WASH.greenMax * WASH.fill + 0.05
			expect(CrateRules.grade(justLate, WASH.slack)).toBe("A")
		end)
		it("leaves a green window a thumb can hit (at least 0.3 s)", function()
			expect((WASH.greenMax - WASH.greenMin) * WASH.fill).toBeGreaterThan(0.3)
		end)
	end)

	describe("packing", function()
		local function inventory(units)
			return { crops = { [BarnRules.key("Carrot")] = units }, seeds = {}, items = {} }
		end
		it("takes a full crate from the barn", function()
			local inv = inventory(30)
			local crate = CrateRules.pack(inv, BarnRules.key("Carrot"), "A")
			expect(crate.crop).toBe("Carrot")
			expect(crate.units).toBe(12)
			expect(crate.grade).toBe("A")
			expect(inv.crops[BarnRules.key("Carrot")]).toBe(18)
		end)
		it("sends a crate out part-full when that's all there is", function()
			local inv = inventory(5)
			local crate = CrateRules.pack(inv, BarnRules.key("Carrot"), "B")
			expect(crate.units).toBe(5)
			expect(inv.crops[BarnRules.key("Carrot")]).toBe(nil)
		end)
		it("packs nothing from an empty or unknown stack", function()
			expect(CrateRules.pack(inventory(0), BarnRules.key("Carrot"), "A")).toBe(nil)
			expect(CrateRules.pack(inventory(5), BarnRules.key("Pumpkin"), "A")).toBe(nil)
			expect(CrateRules.pack(inventory(5), "Nope||", "A")).toBe(nil)
		end)
		it("never takes a grade but A or B", function()
			expect(CrateRules.pack(inventory(5), BarnRules.key("Carrot"), "S").grade).toBe("B")
		end)
	end)

	describe("value", function()
		it("is units × price, and grade A is worth 15% more", function()
			local b = { crop = "Carrot", key = "Carrot||", units = 12, grade = "B" }
			local a = { crop = "Carrot", key = "Carrot||", units = 12, grade = "A" }
			expect(CrateRules.value(b, 20)).toBe(240)
			expect(CrateRules.value(a, 20)).toBe(276)
		end)
	end)
end
