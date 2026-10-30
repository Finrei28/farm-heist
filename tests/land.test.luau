-- Land Permits (shared/LandRules): land opens by Farm Level, one touching
-- block at a time, for the fee of the permit used.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local LandRules = harness.load("LandRules")
	local Land = harness.load("Config/Land")

	local function newLand()
		return { cleared = {} }
	end

	local function clearNow(land, block)
		LandRules.startClearing(land, block)
		local opened
		for _ = 1, Land.OBSTACLES do
			opened = LandRules.clearObstacle(land)
		end
		return opened
	end

	describe("the grid", function()
		it("puts tiles in the right blocks", function()
			expect(LandRules.blockOfTile(1)).toBe(1)
			expect(LandRules.blockOfTile(2)).toBe(1)
			expect(LandRules.blockOfTile(3)).toBe(2)
			expect(LandRules.blockOfTile(9)).toBe(1)
			expect(LandRules.blockOfTile(64)).toBe(16)
			local tiles = LandRules.tilesOf(1)
			table.sort(tiles)
			expect(table.concat(tiles, ",")).toBe("1,2,9,10")
			for block = 1, 16 do
				for _, tile in LandRules.tilesOf(block) do
					expect(LandRules.blockOfTile(tile)).toBe(block)
				end
			end
		end)
		it("starts with the 4×4 corner by the farmhouse: 16 tiles", function()
			local land = newLand()
			expect(LandRules.openTiles(land)).toBe(16)
			expect(LandRules.isTileOpen(land, 1)).toBe(true)
			expect(LandRules.isTileOpen(land, 28)).toBe(true) -- column 4, row 4: the start corner's far tile
			expect(LandRules.isTileOpen(land, 5)).toBe(false)
			expect(LandRules.isTileOpen(land, 0)).toBe(false)
			expect(LandRules.isTileOpen(land, 65)).toBe(false)
		end)
		it("calls back-fence blocks riskier", function()
			expect(LandRules.risk(2)).toBe("Safer")
			expect(LandRules.risk(3)).toBe("Riskier")
			expect(LandRules.risk(9)).toBe("Safer")
		end)
	end)

	describe("permits", function()
		it("are earned at levels 2, 4, 6 ... 32", function()
			expect(LandRules.permitsEarned(1)).toBe(0)
			expect(LandRules.permitsEarned(2)).toBe(1)
			expect(LandRules.permitsEarned(12)).toBe(6)
			expect(LandRules.permitsEarned(31)).toBe(11)
			expect(LandRules.permitsEarned(50)).toBe(12)
			expect(LandRules.nextPermitLevel(12)).toBe(14)
			expect(LandRules.nextPermitLevel(32)).toBe(nil)
		end)
		it("can't be used without the level, whatever your coins", function()
			local _, reason = LandRules.canClear(newLand(), 1, 1e9, 3)
			expect(reason).toBe("NoPermit")
		end)
	end)

	describe("clearing", function()
		it("the first permit costs 250 and opens a block after 4 obstacles", function()
			local land = newLand()
			expect(LandRules.canClear(land, 2, 250, 3)).toBe(true)
			expect(LandRules.startClearing(land, 3)).toBe(250)
			expect(LandRules.clearObstacle(land)).toBe(nil)
			expect(LandRules.clearObstacle(land)).toBe(nil)
			expect(LandRules.clearObstacle(land)).toBe(nil)
			expect(LandRules.clearObstacle(land)).toBe(3)
			expect(LandRules.openTiles(land)).toBe(20)
			expect(LandRules.permitsLeft(land, 2)).toBe(0)
			local _, reason = LandRules.canClear(land, 2, 1e9, 4)
			expect(reason).toBe("NoPermit")
		end)
		it("a Farmhand can finish the clearing in one go", function()
			local land = newLand()
			LandRules.startClearing(land, 9)
			LandRules.clearObstacle(land)
			expect(LandRules.finishClearing(land)).toBe(9)
			expect(LandRules.isOpen(land, 9)).toBe(true)
			expect(LandRules.finishClearing(land)).toBe(nil)
		end)
		it("only touches open land", function()
			local land = newLand()
			local _, reason = LandRules.canClear(land, 50, 1e9, 4)
			expect(reason).toBe("NotTouching")
			local clearable = LandRules.clearable(land)
			table.sort(clearable)
			expect(table.concat(clearable, ",")).toBe("3,7,9,10")
		end)
		it("refuses open blocks, nonsense blocks, a second block at once, and empty wallets", function()
			local land = newLand()
			expect(select(2, LandRules.canClear(land, 50, 1e9, 1))).toBe("AlreadyOpen")
			expect(select(2, LandRules.canClear(land, 50, 1e9, 0))).toBe("BadBlock")
			expect(select(2, LandRules.canClear(land, 50, 1e9, 17))).toBe("BadBlock")
			expect(select(2, LandRules.canClear(land, 50, 1e9, 2.5))).toBe("BadBlock")
			expect(select(2, LandRules.canClear(land, 50, 249, 3))).toBe("TooPoor")
			LandRules.startClearing(land, 3)
			expect(select(2, LandRules.canClear(land, 50, 1e9, 9))).toBe("Busy")
		end)
		it("charges each permit's own fee, in order, whichever block it goes on", function()
			local land = newLand()
			clearNow(land, 9)
			local _, permit = LandRules.nextPermit(land)
			expect(permit.fee).toBe(2_000)
			expect(LandRules.startClearing(land, 3)).toBe(2_000)
		end)
		it("opens the whole 8×8 by level 32", function()
			local land = newLand()
			local spent = 0
			while #LandRules.clearable(land) > 0 do
				local block = LandRules.clearable(land)[1]
				expect(LandRules.canClear(land, 32, 1e9, block)).toBe(true)
				local _, permit = LandRules.nextPermit(land)
				spent += permit.fee
				clearNow(land, block)
			end
			expect(LandRules.openTiles(land)).toBe(64)
			expect(LandRules.nextPermit(land)).toBe(nil)
			local total = 0
			for _, permit in Land.PERMITS do
				total += permit.fee
			end
			expect(spent).toBe(total)
		end)
	end)
end
