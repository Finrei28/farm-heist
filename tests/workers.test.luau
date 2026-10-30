-- Workers (shared/WorkerRules): speeds, wages, fees and station caps.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local WorkerRules = harness.load("WorkerRules")

	local function ctx(overrides)
		local c = { warehouseTier = 1, shopTier = 1, openTiles = 16, level = 5 }
		for k, v in overrides or {} do
			c[k] = v
		end
		return c
	end

	describe("pay", function()
		it("goes up 15% a level; Frugal takes 20% off", function()
			expect(WorkerRules.wage({ type = "Packer", level = 1 })).toBe(5)
			expect(WorkerRules.wage({ type = "Packer", level = 2 })).toBeNear(5.75, 1e-9)
			expect(WorkerRules.wage({ type = "Packer", level = 3 })).toBeNear(6.6125, 1e-9)
			expect(WorkerRules.wage({ type = "Cashier", level = 1, trait = "Frugal" })).toBeNear(4.8, 1e-9)
		end)
		it("hiring costs 40 minutes of wages (the Hiring Hall mockup: 230 and 192)", function()
			expect(WorkerRules.hireFee({ type = "Loader", level = 2, trait = "Speedy" })).toBe(230)
			expect(WorkerRules.hireFee({ type = "Cashier", level = 1, trait = "Frugal" })).toBe(192)
		end)
		it("training stops at level 5", function()
			expect(WorkerRules.trainFee({ type = "Packer", level = 4 })).toBeGreaterThan(0)
			expect(WorkerRules.trainFee({ type = "Packer", level = 5 })).toBe(nil)
		end)
	end)

	describe("speed", function()
		it("goes up 20% a level; Speedy +20%; Night Owls +30% at night", function()
			expect(WorkerRules.speed({ type = "Packer", level = 1 })).toBe(7.5)
			expect(WorkerRules.speed({ type = "Packer", level = 3 })).toBeNear(7.5 * 1.44, 1e-9)
			expect(WorkerRules.speed({ type = "Packer", level = 1, trait = "Speedy" })).toBeNear(9, 1e-9)
			expect(WorkerRules.speed({ type = "Sorter", level = 1, trait = "NightOwl" }, true)).toBeNear(39, 1e-9)
			expect(WorkerRules.speed({ type = "Sorter", level = 1, trait = "NightOwl" }, false)).toBe(30)
			expect(WorkerRules.speed({ type = "Driver", level = 1 })).toBe(0)
		end)
		it("Sorters grade A more often with levels and care", function()
			expect(WorkerRules.gradeAChance({ type = "Sorter", level = 1 })).toBeNear(0.4, 1e-9)
			expect(WorkerRules.gradeAChance({ type = "Sorter", level = 3, trait = "Careful" })).toBeNear(0.71, 1e-9)
		end)
		it("a crew adds up per station", function()
			local speeds, wages = WorkerRules.crew({
				{ type = "Packer", level = 1 }, { type = "Packer", level = 1 }, { type = "Loader", level = 1 },
			})
			expect(speeds.Pack).toBe(15)
			expect(speeds.Load).toBe(10)
			expect(wages).toBe(15)
		end)
	end)

	describe("station caps", function()
		it("follow the warehouse tier", function()
			expect(WorkerRules.cap("Sorter", ctx({ warehouseTier = 0 }))).toBe(0)
			expect(WorkerRules.cap("Packer", ctx({ warehouseTier = 1 }))).toBe(2)
			expect(WorkerRules.cap("Packer", ctx({ warehouseTier = 3 }))).toBe(4)
			expect(WorkerRules.cap("ShedHand", ctx({ warehouseTier = 0 }))).toBe(1)
			expect(WorkerRules.cap("ShedHand", ctx({ warehouseTier = 1 }))).toBe(0)
		end)
		it("follow the shop tier for shop workers", function()
			expect(WorkerRules.cap("Cashier", ctx({ shopTier = 0 }))).toBe(0)
			expect(WorkerRules.cap("Cashier", ctx({ shopTier = 2, warehouseTier = 0 }))).toBe(2)
		end)
		it("give 1 Farmhand per 16 open tiles, up to 4, and a Watchman from level 8", function()
			expect(WorkerRules.cap("Farmhand", ctx({ openTiles = 16 }))).toBe(1)
			expect(WorkerRules.cap("Farmhand", ctx({ openTiles = 40 }))).toBe(2)
			expect(WorkerRules.cap("Farmhand", ctx({ openTiles = 64 }))).toBe(4)
			expect(WorkerRules.cap("Watchman", ctx({ level = 7 }))).toBe(0)
			expect(WorkerRules.cap("Watchman", ctx({ level = 8 }))).toBe(1)
		end)
		it("stop hiring when a station is full or locked", function()
			local crew = { { type = "Packer", level = 1 }, { type = "Packer", level = 1 } }
			expect(select(2, WorkerRules.canHire(crew, "Packer", ctx()))).toBe("Full")
			expect(select(2, WorkerRules.canHire(crew, "Sorter", ctx({ warehouseTier = 0 })))).toBe("Locked")
			expect(WorkerRules.canHire(crew, "Loader", ctx())).toBe(true)
		end)
		it("turn the Shed Hand into a Packer when the warehouse is built", function()
			local crew = { { type = "ShedHand", level = 3 } }
			WorkerRules.promoteShedHands(crew)
			expect(crew[1].type).toBe("Packer")
			expect(crew[1].level).toBe(3)
		end)
	end)
end
