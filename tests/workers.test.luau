-- Workers (shared/WorkerRules): efficiency and wages by level, experience
-- and training, station slots, and the hiring board.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local WorkerRules = harness.load("WorkerRules")
	local Workers = harness.load("Config/Workers")

	local function ctx(overrides)
		local c = { warehouseLevel = 5, storeLevel = 2, openTiles = 16, registers = 0, trucks = 1 }
		for k, v in overrides or {} do
			c[k] = v
		end
		return c
	end
	local function worker(typeName, level, trait)
		return { type = typeName, level = level or 1, xp = 0, trait = trait }
	end

	describe("levels (§4.9)", function()
		it("work at 40% at Level 1 and 100% at Level 10", function()
			expect(WorkerRules.efficiency(1)).toBeNear(0.4, 1e-9)
			expect(WorkerRules.efficiency(10)).toBeNear(1, 1e-9)
			expect(WorkerRules.efficiency(4)).toBeNear(0.6, 1e-9)
			expect(WorkerRules.speed(worker("Packer", 1))).toBeNear(6, 1e-9)
			expect(WorkerRules.speed(worker("Packer", 10))).toBeNear(15, 1e-9)
		end)
		it("are paid 60% of the full wage at Level 1, so a trained worker is cheaper per job", function()
			expect(WorkerRules.wage(worker("Packer", 1))).toBeNear(5.25, 1e-9)
			expect(WorkerRules.wage(worker("Packer", 10))).toBeNear(8.75, 1e-9)
			local perCrateNew = WorkerRules.wage(worker("Packer", 1)) / WorkerRules.speed(worker("Packer", 1))
			local perCrateTop = WorkerRules.wage(worker("Packer", 10)) / WorkerRules.speed(worker("Packer", 10))
			expect(perCrateNew / perCrateTop).toBeNear(1.5, 1e-9)
		end)
		it("traits: Speedy +20%, Frugal −20% wage, Night Owls +30% at night, conveyors for the stations", function()
			expect(WorkerRules.speed(worker("Packer", 10, "Speedy"))).toBeNear(18, 1e-9)
			expect(WorkerRules.wage(worker("Packer", 10, "Frugal"))).toBeNear(7, 1e-9)
			expect(WorkerRules.speed(worker("Sorter", 10, "NightOwl"), { night = true })).toBeNear(78, 1e-9)
			expect(WorkerRules.speed(worker("Sorter", 10, "NightOwl"))).toBeNear(60, 1e-9)
			expect(WorkerRules.speed(worker("Loader", 10), { conveyors = 1.5 })).toBeNear(30, 1e-9)
			expect(WorkerRules.speed(worker("Farmhand", 10), { conveyors = 1.5 })).toBeNear(30, 1e-9)
			expect(WorkerRules.speed(worker("Driver", 10))).toBe(0)
		end)
		it("hiring costs 40 minutes of their wage", function()
			expect(WorkerRules.hireFee(worker("Packer", 1))).toBe(210)
			expect(WorkerRules.hireFee(worker("Cashier", 1, "Frugal"))).toBe(202)
		end)
		it("Sorters grade A from 40% to 85%, plus Careful and the Wash Line, at most 95%", function()
			expect(WorkerRules.gradeAChance(worker("Sorter", 1))).toBeNear(0.4, 1e-9)
			expect(WorkerRules.gradeAChance(worker("Sorter", 10))).toBeNear(0.85, 1e-9)
			expect(WorkerRules.gradeAChance(worker("Sorter", 10, "Careful"), true)).toBeNear(0.95, 1e-9)
		end)
		it("a Level 10 Driver takes 10% off the trip; a Greeter brings up to 25% more shoppers", function()
			expect(WorkerRules.tripShave(worker("Driver", 1))).toBe(0)
			expect(WorkerRules.tripShave(worker("Driver", 10))).toBeNear(0.1, 1e-9)
			expect(WorkerRules.greeterBoost(worker("Greeter", 10))).toBeNear(0.25, 1e-9)
			expect(WorkerRules.greeterBoost(worker("Greeter", 1))).toBeNear(0.1, 1e-9)
		end)
		it("a crew adds up per station", function()
			local speeds, wages = WorkerRules.crew({ worker("Packer", 10), worker("Packer", 10), worker("Loader", 10) })
			expect(speeds.Pack).toBeNear(30, 1e-9)
			expect(speeds.Load).toBeNear(20, 1e-9)
			expect(wages).toBeNear(26.25, 1e-9)
		end)
	end)

	describe("experience and training", function()
		it("an hour of work for Level 2, about 26 hours for Level 10, 75 in all", function()
			expect(WorkerRules.xpToNext(1)).toBe(600)
			expect(WorkerRules.xpToNext(1) / Workers.XP_PER_MINUTE).toBe(60)
			expect(WorkerRules.xpToNext(9) / Workers.XP_PER_MINUTE / 60).toBeNear(25.6, 0.1)
			expect(WorkerRules.xpToNext(10)).toBe(nil)
			local total = 0
			for level = 1, 9 do
				total += WorkerRules.xpToNext(level)
			end
			expect(total / Workers.XP_PER_MINUTE / 60).toBeNear(74.8, 0.2)
		end)
		it("costs 250 for Level 2 and about 42,000 for Level 10 (89,000 in all)", function()
			expect(WorkerRules.trainFee(worker("Packer", 1))).toBe(250)
			expect(WorkerRules.trainFee(worker("Packer", 9))).toBeNear(42_459, 1)
			local total = 0
			for level = 1, 9 do
				total += WorkerRules.trainFee(worker("Packer", level))
			end
			expect(total).toBeNear(89_360, 5)
			expect(WorkerRules.trainFee(worker("Driver", 1))).toBe(400) -- dearer jobs cost more to train
		end)
		it("the bar fills, waits for Train, and starts again", function()
			local w = worker("Packer", 1)
			expect(WorkerRules.cannotTrain(w, 1e9)).toBe("NeedXp")
			expect(WorkerRules.addXp(w, 599)).toBe(false)
			expect(WorkerRules.addXp(w, 50)).toBe(true)
			expect(w.xp).toBe(600) -- it stops at full
			expect(WorkerRules.ready(w)).toBe(true)
			expect(WorkerRules.cannotTrain(w, 249)).toBe("NoCoins")
			expect(WorkerRules.cannotTrain(w, 250)).toBe(nil)
			WorkerRules.train(w)
			expect(w.level).toBe(2)
			expect(w.xp).toBe(0)
			expect(WorkerRules.cannotTrain(worker("Packer", 10), 1e9)).toBe("MaxLevel")
		end)
	end)

	describe("slots", function()
		it("open with Warehouse Levels (§4.6)", function()
			expect(WorkerRules.slots("Sorter", ctx({ warehouseLevel = 4 }))).toBe(0)
			expect(WorkerRules.slots("Sorter", ctx({ warehouseLevel = 8 }))).toBe(2)
			expect(WorkerRules.slots("Packer", ctx({ warehouseLevel = 13 }))).toBe(4)
			expect(WorkerRules.slots("Loader", ctx({ warehouseLevel = 20 }))).toBe(3)
			expect(WorkerRules.slots("ShedHand", ctx({ warehouseLevel = 1 }))).toBe(1)
			expect(WorkerRules.slots("ShedHand", ctx({ warehouseLevel = 4 }))).toBe(2)
			expect(WorkerRules.slots("ShedHand", ctx({ warehouseLevel = 5 }))).toBe(0)
		end)
		it("a Driver per truck from Level 5", function()
			expect(WorkerRules.slots("Driver", ctx({ warehouseLevel = 4 }))).toBe(0)
			expect(WorkerRules.slots("Driver", ctx({ warehouseLevel = 10, trucks = 2 }))).toBe(2)
		end)
		it("open with Store Levels for the store's crew, a Cashier per Register", function()
			expect(WorkerRules.slots("Stocker", ctx({ storeLevel = 1 }))).toBe(0)
			expect(WorkerRules.slots("Stocker", ctx({ storeLevel = 8 }))).toBe(2)
			expect(WorkerRules.slots("Greeter", ctx({ storeLevel = 7 }))).toBe(0)
			expect(WorkerRules.slots("Greeter", ctx({ storeLevel = 8 }))).toBe(1)
			expect(WorkerRules.slots("Cashier", ctx({ registers = 2 }))).toBe(2)
		end)
		it("1 Farmhand per 16 open tiles, up to 4", function()
			expect(WorkerRules.slots("Farmhand", ctx({ openTiles = 16 }))).toBe(1)
			expect(WorkerRules.slots("Farmhand", ctx({ openTiles = 40 }))).toBe(2)
			expect(WorkerRules.slots("Farmhand", ctx({ openTiles = 64 }))).toBe(4)
		end)
		it("say what opens the next one", function()
			expect(WorkerRules.nextSlot("Sorter", ctx({ warehouseLevel = 5 }))).toBe("Warehouse Level 8")
			expect(WorkerRules.nextSlot("Sorter", ctx({ warehouseLevel = 18 }))).toBe(nil)
			expect(WorkerRules.nextSlot("Driver", ctx({ warehouseLevel = 3 }))).toBe("Warehouse Level 5")
			expect(WorkerRules.nextSlot("Driver", ctx({ warehouseLevel = 12, trucks = 2 }))).toBe("Warehouse Level 20")
			expect(WorkerRules.nextSlot("ShedHand", ctx({ warehouseLevel = 1 }))).toBe("Warehouse Level 4")
			expect(WorkerRules.nextSlot("ShedHand", ctx({ warehouseLevel = 4 }))).toBe(nil)
			expect(WorkerRules.nextSlot("Stocker", ctx({ storeLevel = 2 }))).toBe("Store Level 8")
			expect(WorkerRules.nextSlot("Farmhand", ctx({ openTiles = 16 }))).toBe("32 cleared tiles")
		end)
		it("stop hiring when a station is full or locked", function()
			local crew = { worker("Packer"), worker("Packer") }
			expect(select(2, WorkerRules.canHire(crew, "Packer", ctx({ warehouseLevel = 6 })))).toBe("Full")
			expect(select(2, WorkerRules.canHire(crew, "Sorter", ctx({ warehouseLevel = 4 })))).toBe("Locked")
			expect(WorkerRules.canHire(crew, "Loader", ctx())).toBe(true)
			expect(select(2, WorkerRules.canHire(crew, "Watchman", ctx()))).toBe("Unknown")
		end)
		it("turn Shed Hands into Packers when the warehouse is built", function()
			local crew = { { type = "ShedHand", level = 3, xp = 120 } }
			WorkerRules.promoteShedHands(crew)
			expect(crew[1].type).toBe("Packer")
			expect(crew[1].level).toBe(3)
			expect(crew[1].xp).toBe(120)
		end)
	end)

	describe("the hiring board", function()
		it("has 3 candidates a type, the same all through a 10-minute window", function()
			local a = WorkerRules.candidates(123456, 50, "Packer")
			local b = WorkerRules.candidates(123456, 50, "Packer")
			expect(#a).toBe(Workers.BOARD_SIZE)
			for i = 1, #a do
				expect(a[i].name).toBe(b[i].name)
				expect(a[i].level).toBe(b[i].level)
				expect(a[i].trait).toBe(b[i].trait)
				expect(a[i].fee).toBe(WorkerRules.hireFee(a[i]))
				expect(a[i].level >= 1 and a[i].level <= 3).toBe(true)
			end
		end)
		it("only offers traits that help the job", function()
			for window = 1, 30 do
				for _, candidate in WorkerRules.candidates(7, window, "Farmhand") do
					expect(candidate.trait ~= "Careful").toBe(true)
				end
				for _, candidate in WorkerRules.candidates(7, window, "Greeter") do
					expect(candidate.trait == "Frugal").toBe(true) -- (a Greeter has no speed and grades nothing)
				end
			end
			expect(table.find(WorkerRules.traitsFor("Sorter"), "Careful") ~= nil).toBe(true)
		end)
		it("changes with the window", function()
			local same = 0
			for window = 1, 20 do
				local a, b = WorkerRules.candidates(1, window, "Sorter")[1], WorkerRules.candidates(1, window + 1, "Sorter")[1]
				if a.name == b.name and a.trait == b.trait and a.level == b.level then
					same += 1
				end
			end
			expect(same < 5).toBe(true)
		end)
		it("counts the time to the next board", function()
			expect(WorkerRules.boardWindow(1200)).toBe(2)
			expect(WorkerRules.boardLeft(1200)).toBe(600)
			expect(WorkerRules.boardLeft(1799)).toBe(1)
		end)
	end)
end
