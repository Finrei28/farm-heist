-- Your store's floor plan (shared/StoreLayout, Config/Store) against
-- docs/GameDesign.md §4.8: the levels and buildings, the layout rules,
-- the aisles shoppers walk, Charm, and the floor growing.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local StoreLayout = harness.load("StoreLayout")
	local Store = harness.load("Config/Store")

	local function starter()
		local layout = {}
		for i, entry in Store.START do
			layout[tostring(i)] = { item = entry.item, x = entry.x, y = entry.y, rot = entry.rot }
		end
		return layout
	end
	local function with(layout, entry)
		local copy = table.clone(layout)
		copy.new = entry
		return copy
	end

	describe("levels", function()
		it("run 1–20, costing about 3.9 million in all, each needing a higher or equal Farm Level", function()
			expect(#Store.LEVELS).toBe(20)
			local total = 0
			for n, row in Store.LEVELS do
				total += row.cost
				if n > 1 then
					expect(row.cost).toBeGreaterThan(Store.LEVELS[n - 1].cost)
					expect(row.farmLevel >= Store.LEVELS[n - 1].farmLevel).toBe(true)
				end
			end
			expect(total).toBeNear(3_900_000, 120_000)
		end)
		it("open floor at every level (a row or a column; both at 4, 5, 10, 15 and 20), inside each level's building", function()
			for n = 1, 20 do
				local level = StoreLayout.level(n)
				expect(level.floor[1] <= level.building.cells[1] and level.floor[2] <= level.building.cells[2]).toBe(true)
				if n > 1 then
					local before = StoreLayout.level(n - 1).floor
					local grownX, grownY = level.floor[1] - before[1], level.floor[2] - before[2]
					expect(grownX >= 0 and grownX <= 1 and grownY >= 0 and grownY <= 1).toBe(true)
					expect(grownX + grownY).toBe(if table.find({ 4, 5, 10, 15, 20 }, n) then 2 else 1)
				end
			end
			expect(StoreLayout.level(1).floor[1]).toBe(6)
			expect(StoreLayout.level(1).floor[2]).toBe(4)
			-- the biggest floor is the Supermarket's whole building
			local top = StoreLayout.level(20)
			expect(top.floor[1] == top.building.cells[1] and top.floor[2] == top.building.cells[2]).toBe(true)
			expect(top.floor[1] * top.floor[2]).toBe(280)
		end)
		it("let more shoppers in at once in a bigger building", function()
			for stage = 2, #Store.BUILDINGS do
				expect(Store.BUILDINGS[stage].shoppers).toBeGreaterThan(Store.BUILDINGS[stage - 1].shoppers)
			end
			expect(StoreLayout.level(1).shoppers).toBe(8)
			expect(StoreLayout.level(20).shoppers).toBe(24)
			-- (and the level-up card says so)
			expect(table.find(StoreLayout.news(15), "room for 24 shoppers at once") ~= nil).toBe(true)
			expect(table.find(StoreLayout.news(16), "room for 24 shoppers at once")).toBe(nil)
		end)
		it("put up a new building at 5, 10 and 15, each fitting the shop lot", function()
			expect(StoreLayout.level(4).building.id).toBe("CornerStore")
			expect(StoreLayout.level(5).building.id).toBe("FarmShop")
			expect(StoreLayout.level(10).building.id).toBe("MarketHall")
			expect(StoreLayout.level(15).building.id).toBe("Supermarket")
			for stage, building in Store.BUILDINGS do
				-- (each building's whole floor is open by its last level; tests/layout.test checks they fit the plot)
				local last = StoreLayout.level(if stage < #Store.BUILDINGS then Store.BUILDINGS[stage + 1].from - 1 else #Store.LEVELS)
				expect(last.floor[1] == building.cells[1] and last.floor[2] == building.cells[2]).toBe(true)
				if stage > 1 then
					expect(building.cells[1] >= Store.BUILDINGS[stage - 1].cells[1]).toBe(true)
					expect(building.cells[2] >= Store.BUILDINGS[stage - 1].cells[2]).toBe(true)
				end
			end
		end)
		it("give 6 stockroom crates at Level 1 and 44 at 20; 1–4 checkouts; bigger baskets", function()
			expect(StoreLayout.level(1).stockroom).toBe(6)
			expect(StoreLayout.level(20).stockroom).toBe(44)
			expect(StoreLayout.level(2).checkouts).toBe(1)
			expect(StoreLayout.level(3).checkouts).toBe(2)
			expect(StoreLayout.level(10).checkouts).toBe(3)
			expect(StoreLayout.level(15).checkouts).toBe(4)
			expect(StoreLayout.level(4).wants[2]).toBe(1)
			expect(StoreLayout.level(5).wants[2]).toBe(2)
			expect(StoreLayout.level(15).wants[1]).toBe(2)
			expect(StoreLayout.level(14).billboard).toBe(false)
			expect(StoreLayout.level(16).billboard).toBe(true)
		end)
		it("unlock every catalog item by Level 20, and each building's gift by its level", function()
			for id, item in Store.ITEMS do
				expect(item.level >= 1 and item.level <= 20).toBe(true)
				expect(table.find(Store.ORDER, id) ~= nil).toBe(true)
			end
			expect(#Store.ORDER).toBe((function()
				local n = 0
				for _ in Store.ITEMS do
					n += 1
				end
				return n
			end)())
			for _, building in Store.BUILDINGS do
				if building.gift then
					expect(Store.ITEMS[building.gift].level <= building.from).toBe(true)
				end
			end
		end)
	end)

	describe("the starter store", function()
		it("is a valid layout on the Level 1 floor (6×4)", function()
			local ok, reason, id = StoreLayout.check(starter(), 1)
			if not ok then
				error(`{reason} {id}`)
			end
		end)
		it("queues at the Honour Box up the side wall, clear of the aisle", function()
			local queue = StoreLayout.queues(starter(), 1)["5"]
			expect(#queue).toBe(3)
			expect(StoreLayout.key(queue[1][1], queue[1][2])).toBe("6,2")
			expect(StoreLayout.key(queue[3][1], queue[3][2])).toBe("6,4")
		end)
		it("has room for a few new things at Level 1", function()
			local layout = starter()
			for i = 1, 3 do
				local x, y, rot = StoreLayout.findSpot(layout, 1, "ProduceCrate")
				expect(x ~= nil).toBe(true)
				layout[`new{i}`] = { item = "ProduceCrate", x = x, y = y, rot = rot }
			end
			expect((StoreLayout.check(layout, 1))).toBe(true)
		end)
	end)

	describe("the rules", function()
		it("keep items on the open floor", function()
			local ok, reason = StoreLayout.check(with(starter(), { item = "PottedPlant", x = 7, y = 1, rot = 0 }), 1)
			expect(ok).toBe(false)
			expect(reason).toBe("OutOfFloor")
			expect((StoreLayout.check(with(starter(), { item = "PottedPlant", x = 7, y = 1, rot = 0 }), 2))).toBe(true)
		end)
		it("don't let two items share a cell, even a rug", function()
			local _, reason = StoreLayout.check(with(starter(), { item = "PottedPlant", x = 2, y = 4, rot = 0 }), 1)
			expect(reason).toBe("Overlap")
			_, reason = StoreLayout.check(with(starter(), { item = "Rug", x = 5, y = 4, rot = 0 }), 1)
			expect(reason).toBe("Overlap")
		end)
		it("keep the cells inside both doors clear (a rug is fine)", function()
			local _, reason = StoreLayout.check(with(starter(), { item = "PottedPlant", x = 3, y = 1, rot = 0 }), 1)
			expect(reason).toBe("Doorway")
			_, reason = StoreLayout.check(with(starter(), { item = "PottedPlant", x = 1, y = 2, rot = 0 }), 1)
			expect(reason).toBe("Doorway")
			expect((StoreLayout.check(with(starter(), { item = "Rug", x = 3, y = 1, rot = 0 }), 1))).toBe(true)
		end)
		it("keep the space in front of a display free", function()
			local ok, reason, id = StoreLayout.check(with(starter(), { item = "PottedPlant", x = 4, y = 3, rot = 0 }), 1)
			expect(ok).toBe(false)
			expect(reason).toBe("FrontBlocked")
			expect(id).toBe("3") -- the second Produce Crate
		end)
		it("refuse a move that cuts a display off from the door, naming it", function()
			-- 7×5: a crate in the back corner, facing along the back wall.
			local layout = {
				box = { item = "HonourBox", x = 5, y = 1, rot = 2 },
				a = { item = "ProduceCrate", x = 1, y = 5, rot = 3 }, -- its front: (2, 5)
				p2 = { item = "PottedPlant", x = 3, y = 5, rot = 0 },
			}
			expect((StoreLayout.check(layout, 3))).toBe(true)
			layout.p1 = { item = "PottedPlant", x = 2, y = 4, rot = 0 } -- closes (2, 5) in
			local ok, why, id = StoreLayout.check(layout, 3)
			expect(ok).toBe(false)
			expect(why).toBe("Unreachable")
			expect(id).toBe("a")
		end)
		it("need a queue for every checkout: 2 free cells in a line, straight back or turning", function()
			local layout = starter()
			layout["5"] = { item = "HonourBox", x = 4, y = 1, rot = 2 } -- straight back is a crate: it turns
			expect((StoreLayout.check(layout, 1))).toBe(true)
			local queue = StoreLayout.queues(layout, 1)["5"]
			expect(StoreLayout.key(queue[2][1], queue[2][2])).toBe("3,2")
			layout["5"] = { item = "HonourBox", x = 1, y = 1, rot = 3 } -- the door straight on, the wall to the right ...
			layout.p = { item = "PottedPlant", x = 2, y = 2, rot = 0 } -- ... and a plant to the left
			local _, reason, id = StoreLayout.check(layout, 1)
			expect(reason).toBe("NoQueue")
			expect(id).toBe("5")
		end)
		it("don't let two checkouts share a queue", function()
			local layout = starter()
			layout["5"] = { item = "HonourBox", x = 4, y = 1, rot = 2 } -- queues (4,2) (3,2) (2,2)
			layout.b = { item = "HonourBox", x = 2, y = 1, rot = 2 } -- back into the shelf, left the staff door, right the other queue
			local _, reason, id = StoreLayout.check(layout, 3)
			expect(reason).toBe("NoQueue")
			expect(id).toBe("b")
		end)
		it("keep room behind a Register for whoever serves at it", function()
			local layout = starter()
			StoreLayout.grow(layout, 1, 3)
			layout["5"] = { item = "Register", x = 4, y = 2, rot = 0 } -- faces the door's row; serves from (4,3) (5,3)
			local ok, reason, id = StoreLayout.check(layout, 3)
			if not ok then
				error(`{reason} {id}`)
			end
			layout.p = { item = "PottedPlant", x = 5, y = 3, rot = 0 }
			_, reason, id = StoreLayout.check(layout, 3)
			expect(reason).toBe("BehindBlocked")
			expect(id).toBe("5")
		end)
		it("queue at a Register from its till end, and send shoppers to the slot they want", function()
			local register = { item = "Register", x = 4, y = 2, rot = 0 }
			local till = StoreLayout.tillFront(register)
			expect(StoreLayout.key(till[1], till[2])).toBe("4,1") -- (the model's +X side is the lower x at rot 0)
			register.rot = 2
			till = StoreLayout.tillFront(register)
			expect(StoreLayout.key(till[1], till[2])).toBe("5,3")
			local shelf = { item = "WoodenShelf", x = 1, y = 3, rot = 0 }
			local first, second = StoreLayout.slotFront(shelf, 1), StoreLayout.slotFront(shelf, 2)
			expect(StoreLayout.key(first[1], first[2])).toBe("1,2")
			expect(StoreLayout.key(second[1], second[2])).toBe("2,2")
			local crate = StoreLayout.slotFront({ item = "ProduceCrate", x = 3, y = 3, rot = 0 }, 1)
			expect(StoreLayout.key(crate[1], crate[2])).toBe("3,2")
		end)
		it("allow one checkout at Levels 1–2, and need at least one", function()
			local layout = starter()
			layout.b = { item = "HonourBox", x = 2, y = 1, rot = 2 }
			local _, reason = StoreLayout.check(layout, 2)
			expect(reason).toBe("TooManyCheckouts")
			layout.b = nil
			layout["5"] = nil
			_, reason = StoreLayout.check(layout, 1)
			expect(reason).toBe("NoCheckout")
		end)
		it("hang wall items on the building's walls, never over the staff door or each other", function()
			local layout = starter()
			layout.w = { item = "Clock", side = "back", at = 8 }
			expect((StoreLayout.check(layout, 4))).toBe(true) -- (the Corner Store's back wall is 8 cells)
			layout.w = { item = "Clock", side = "back", at = 9 }
			local _, reason = StoreLayout.check(layout, 4)
			expect(reason).toBe("WallSpace")
			layout.w = { item = "Mural", side = "gate", at = Store.STAFF_Y }
			_, reason = StoreLayout.check(layout, 4)
			expect(reason).toBe("Doorway")
			layout.w = { item = "Mural", side = "hedge", at = 1 }
			layout.v = { item = "Clock", side = "hedge", at = 2 }
			_, reason = StoreLayout.check(layout, 4)
			expect(reason).toBe("Overlap")
		end)
		it("cap the floor at 100 items", function()
			local layout = { box = { item = "HonourBox", x = 5, y = 1, rot = 2 } }
			for i = 1, Store.MAX_FLOOR_ITEMS + 1 do
				layout[`r{i}`] = { item = "Rug", x = (i - 1) % 12 + 1, y = 2 + (i - 1) // 12, rot = 0 }
			end
			local _, reason = StoreLayout.check(layout, 20)
			expect(reason).toBe("TooMany")
		end)
		it("turn items: a 2×1 shelf facing sideways covers two rows", function()
			local cells = StoreLayout.cells({ item = "WoodenShelf", x = 4, y = 2, rot = 1 })
			expect(#cells).toBe(2)
			expect(StoreLayout.key(cells[2][1], cells[2][2])).toBe("4,3")
			local fronts = StoreLayout.fronts({ item = "WoodenShelf", x = 4, y = 2, rot = 1 })
			expect(StoreLayout.key(fronts[1][1], fronts[1][2])).toBe("3,2")
			expect(StoreLayout.key(fronts[2][1], fronts[2][2])).toBe("3,3")
		end)
	end)

	describe("aisles", function()
		it("find the shortest walk from the door, around things", function()
			local path = StoreLayout.path(starter(), 1, { 3, 1 }, { 1, 2 })
			expect(#path).toBe(4) -- (3,1) (3,2) (2,2) (1,2), or the same length another way
			expect(StoreLayout.path(starter(), 1, { 3, 1 }, { 1, 4 })).toBe(nil) -- (the shelf stands there)
		end)
		it("cut corners across open floor, never through a display", function()
			local layout = { box = { item = "HonourBox", x = 6, y = 1, rot = 2 } }
			local cells = StoreLayout.path(layout, 13, { 3, 1 }, { 9, 6 })
			local smooth = StoreLayout.smooth(layout, 13, cells)
			expect(#smooth).toBe(2) -- straight there
			layout.shelf = { item = "WoodenShelf", x = 5, y = 3, rot = 0 }
			layout.shelf2 = { item = "WoodenShelf", x = 7, y = 3, rot = 0 }
			cells = StoreLayout.path(layout, 13, { 3, 1 }, { 6, 5 })
			smooth = StoreLayout.smooth(layout, 13, cells)
			expect(#smooth >= 3).toBe(true)
			expect(StoreLayout.length(smooth) <= #cells - 1 + 1e-9).toBe(true)
		end)
	end)

	describe("Charm", function()
		it("adds each item's Charm, later copies counting less (10 plants ≈ 6)", function()
			local layout = {}
			for i = 1, 10 do
				layout[tostring(i)] = { item = "PottedPlant", x = i, y = 1, rot = 0 }
			end
			expect(StoreLayout.charm(layout)).toBeNear(5.86, 0.01)
			expect(StoreLayout.charmStars(layout)).toBe(0)
		end)
		it("gives +0.1★ for every 10, up to +1★ (one of everything is about 106)", function()
			local layout = { a = { item = "Fountain", x = 1, y = 1, rot = 0 } }
			expect(StoreLayout.charmStars(layout)).toBeNear(0.1, 1e-9)
			for id in Store.ITEMS do
				layout[id] = { item = id, x = 1, y = 1, rot = 0 }
			end
			expect(StoreLayout.charm(layout)).toBeNear(112, 0.5)
			expect(StoreLayout.charmStars(layout)).toBe(1)
		end)
		it("counts displays' Charm too (the Tiered Rack, Showcase and Pedestal)", function()
			expect(StoreLayout.charm({ a = { item = "TieredRack", x = 1, y = 1, rot = 0 } })).toBe(1)
			expect(StoreLayout.charm({ a = { item = "WoodenShelf", x = 1, y = 1, rot = 0 } })).toBe(0)
		end)
	end)

	describe("growing", function()
		it("moves the back row back when the floor gets deeper, keeping it valid", function()
			local layout = starter()
			expect(StoreLayout.grow(layout, 2, 3)).toBe(true)
			expect(layout["1"].y).toBe(5)
			expect(layout["5"].y).toBe(1) -- (the Honour Box stays by the door)
			expect((StoreLayout.check(layout, 3))).toBe(true)
		end)
		it("leaves things where they are when the floor only gets wider", function()
			local layout = starter()
			expect(StoreLayout.grow(layout, 1, 2)).toBe(false)
			expect(layout["1"].y).toBe(4)
		end)
		it("keeps every level's layout valid from the starter store up to 20", function()
			local layout = starter()
			for n = 2, 20 do
				StoreLayout.grow(layout, n - 1, n)
				local ok, reason = StoreLayout.check(layout, n)
				if not ok then
					error(`level {n}: {reason}`)
				end
			end
		end)
		it("finds room for each new building's gift", function()
			local layout = starter()
			for n = 2, 20 do
				StoreLayout.grow(layout, n - 1, n)
				local level = StoreLayout.level(n)
				if level.building.from == n and level.building.gift then
					local x, y, rot = StoreLayout.findSpot(layout, n, level.building.gift)
					expect(x ~= nil).toBe(true)
					layout[`gift{n}`] = { item = level.building.gift, x = x, y = y, rot = rot }
				end
			end
			expect((StoreLayout.check(layout, 20))).toBe(true)
		end)
	end)
end
