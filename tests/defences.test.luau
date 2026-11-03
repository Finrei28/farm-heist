-- Defences and the Trusted list (shared/DefenceRules, Config/Defences),
-- the Sprout Shield and the raid cap's dome (shared/CrimeRules), and where
-- defences stand (shared/PlotLayout): docs/GameDesign.md §4.1, §4.10, §4.11.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local Vector3 = require("@lune/roblox").Vector3
	local DefenceRules = harness.load("DefenceRules")
	local Defences = harness.load("Config/Defences")
	local Crime = harness.load("Config/Crime")
	local CrimeRules = harness.load("CrimeRules")
	local LandRules = harness.load("LandRules")
	local PlotLayout = harness.load("PlotLayout")

	local P = PlotLayout.PLOT

	local function fresh()
		return { owned = {}, placed = {} }
	end
	local function land()
		return { cleared = {}, fresh = {}, fieldLevel = 1 }
	end
	local function reason(ok, why)
		return if ok then "ok" else why
	end

	describe("the catalog", function()
		it("lists every defence once, each with a price, a level and a spot kind", function()
			local seen = {}
			for _, id in Defences.ORDER do
				local def = Defences.ITEMS[id]
				expect(def ~= nil).toBe(true)
				expect(seen[id]).toBe(nil)
				seen[id] = true
				expect(def.cost > 0 and def.level >= 1 and def.max >= 1).toBe(true)
				expect(table.find({ "yard", "tile", "gate", "fence", "camera", "floods" }, def.spot) ~= nil).toBe(true)
			end
			for id in Defences.ITEMS do
				expect(seen[id]).toBe(true)
			end
		end)
		it("keeps the design's prices and levels (§4.11)", function()
			expect(Defences.ITEMS.Scarecrow.cost).toBe(25_000)
			expect(Defences.ITEMS.GateLock.level).toBe(8)
			expect(Defences.ITEMS.TallFence.level).toBe(12)
			expect(Defences.ITEMS.GuardDog.cost).toBe(600_000)
			expect(Defences.ITEMS.Cloche.cost).toBe(30_000)
			expect(Defences.ITEMS.MudPatch.max).toBe(4)
			expect(Defences.ITEMS.Floodlights.level).toBe(10)
			expect(Defences.ITEMS.Floodlights.cost).toBe(120_000)
		end)
		it("open one at a time, in the window's order, none before the Sprout Shield's Farm Levels", function()
			local last = 0
			for _, id in Defences.ORDER do
				local level = Defences.ITEMS[id].level
				expect(level > last).toBe(true)
				last = level
			end
			expect(Defences.ITEMS[Defences.ORDER[1]].level >= 5).toBe(true)
		end)
	end)

	describe("buying", function()
		it("needs the Farm Level and the coins, and stops at the most a farm can have", function()
			local d = fresh()
			expect(reason(DefenceRules.canBuy(d, "Scarecrow", 4, 1e6))).toBe("Locked")
			expect(reason(DefenceRules.canBuy(d, "Scarecrow", 5, 24_999))).toBe("NoCoins")
			expect(reason(DefenceRules.canBuy(d, "Scarecrow", 5, 25_000))).toBe("ok")
			DefenceRules.buy(d, "Scarecrow")
			expect(reason(DefenceRules.canBuy(d, "Scarecrow", 50, 1e9))).toBe("Max")
			expect(reason(DefenceRules.canBuy(d, "Nope", 50, 1e9))).toBe("NoItem")
		end)
		it("sets up the gate lock, the tall fence and the camera as you buy them", function()
			local d = fresh()
			expect(DefenceRules.buy(d, "GateLock")).toBe("gate")
			expect(DefenceRules.buy(d, "TallFence")).toBe("fence")
			expect(DefenceRules.buy(d, "Camera")).toBe("camera")
			expect(DefenceRules.buy(d, "Floodlights")).toBe("floods")
			expect(DefenceRules.gateLocked(d)).toBe(true)
			expect(DefenceRules.fenceClimb(d, "Out", true)).toBe(Crime.TALL_FENCE_CLIMB)
			expect(DefenceRules.fenceHeight(d)).toBe(PlotLayout.TALL_FENCE_HEIGHT)
			expect(DefenceRules.has(d, "Camera")).toBe(true)
		end)
		it("waits for you to set out the rest", function()
			local d = fresh()
			expect(DefenceRules.buy(d, "MudPatch")).toBe(nil)
			expect(DefenceRules.spare(d, "MudPatch")).toBe(1)
			expect(DefenceRules.has(d, "MudPatch")).toBe(false)
		end)
	end)

	describe("setting them out", function()
		it("puts each one on its own kind of spot, one thing a spot", function()
			local d = fresh()
			DefenceRules.buy(d, "MudPatch")
			DefenceRules.buy(d, "MudPatch")
			DefenceRules.buy(d, "Scarecrow")
			expect(reason(DefenceRules.canPlace(d, land(), "MudPatch", "tile:1"))).toBe("WrongSpot")
			expect(reason(DefenceRules.canPlace(d, land(), "MudPatch", "gate"))).toBe("WrongSpot")
			expect(reason(DefenceRules.canPlace(d, land(), "MudPatch", "yard:27"))).toBe("WrongSpot")
			expect(reason(DefenceRules.canPlace(d, land(), "MudPatch", "yard:12"))).toBe("ok")
			DefenceRules.place(d, "MudPatch", "yard:12")
			expect(reason(DefenceRules.canPlace(d, land(), "Scarecrow", "yard:12"))).toBe("Taken")
			expect(reason(DefenceRules.canPlace(d, land(), "MudPatch", "yard:13"))).toBe("ok")
			DefenceRules.place(d, "MudPatch", "yard:13")
			expect(reason(DefenceRules.canPlace(d, land(), "MudPatch", "yard:14"))).toBe("NoneSpare")
		end)
		it("moves a one-of (the scarecrow, the dog) when you set it out somewhere else", function()
			local d = fresh()
			DefenceRules.buy(d, "GuardDog")
			DefenceRules.place(d, "GuardDog", "yard:3")
			expect(reason(DefenceRules.canPlace(d, land(), "GuardDog", "yard:14"))).toBe("ok")
			expect(DefenceRules.place(d, "GuardDog", "yard:14")).toBe("yard:3")
			expect(d.placed["yard:3"]).toBe(nil)
			expect(d.placed["yard:14"]).toBe("GuardDog")
		end)
		it("puts cloches over open tiles only", function()
			local d = fresh()
			DefenceRules.buy(d, "Cloche")
			local first = nil
			for tile = 1, 64 do
				if LandRules.isTileOpen(land(), tile) then
					first = first or tile
				elseif reason(DefenceRules.canPlace(d, land(), "Cloche", `tile:{tile}`)) ~= "Overgrown" then
					error(`a cloche fits on overgrown tile {tile}`)
				end
			end
			expect(reason(DefenceRules.canPlace(d, land(), "Cloche", `tile:{first}`))).toBe("ok")
			DefenceRules.place(d, "Cloche", `tile:{first}`)
			expect(DefenceRules.cloche(d, first)).toBe(true)
			expect(DefenceRules.cloche(d, first + 1)).toBe(false)
		end)
		it("puts things away and lets them go back up", function()
			local d = fresh()
			DefenceRules.buy(d, "GateLock")
			expect(DefenceRules.putAway(d, "gate")).toBe("GateLock")
			expect(DefenceRules.gateLocked(d)).toBe(false)
			expect(DefenceRules.spare(d, "GateLock")).toBe(1)
			expect(reason(DefenceRules.canPlace(d, land(), "GateLock", "gate"))).toBe("ok")
			DefenceRules.place(d, "GateLock", "gate")
			expect(reason(DefenceRules.canPlace(d, land(), "GateLock", "gate"))).toBe("AlreadyOut")
		end)
	end)

	describe("what they do", function()
		it("the scarecrow sees anyone within 25 studs of the field, not further", function()
			local d = fresh()
			DefenceRules.buy(d, "Scarecrow")
			local back = P.field.depth + P.field.size * P.field.tile
			local p = Vector3.new(0, 0, back + 24)
			expect(DefenceRules.scarecrowSees(d, p)).toBe(false) -- (not set out yet)
			DefenceRules.place(d, "Scarecrow", "yard:1")
			expect(DefenceRules.scarecrowSees(d, p)).toBe(true)
			expect(DefenceRules.scarecrowSees(d, Vector3.new(0, 0, back + 26))).toBe(false)
			expect(DefenceRules.scarecrowSees(d, Vector3.new(0, 0, P.field.depth + 30))).toBe(true) -- (in the field)
			-- from the back trail, just over the fence
			expect(DefenceRules.scarecrowSees(d, Vector3.new(0, 0, P.backFence + 4))).toBe(true)
		end)
		it("the dog runs at thefts within 30 studs of its kennel", function()
			local d = fresh()
			DefenceRules.buy(d, "GuardDog")
			DefenceRules.place(d, "GuardDog", "yard:13") -- (behind the raid race's tile)
			local tile = PlotLayout.tileLocal(3 * P.field.size + P.field.size)
			expect(DefenceRules.dogFor(d, tile)).toBe("yard:13")
			expect(DefenceRules.dogFor(d, PlotLayout.tileLocal(1))).toBe(nil)
		end)
		it("mud covers its own 12 × 12 square", function()
			local d = fresh()
			DefenceRules.buy(d, "MudPatch")
			DefenceRules.place(d, "MudPatch", "yard:12")
			local at = PlotLayout.yardSpot(12)
			expect(DefenceRules.inMud(d, at + Vector3.new(5.9, 0, -5.9))).toBe(true)
			expect(DefenceRules.inMud(d, at + Vector3.new(6.5, 0, 0))).toBe(false)
		end)
		it("a locked gate stops anyone but you and Trusted friends coming in; walking out is free", function()
			local function g(o)
				local base = { mine = false, trusted = false, locked = true, shut = false, suspect = false, direction = "In" }
				for k, v in o do
					base[k] = v
				end
				return DefenceRules.gateBlocks(base)
			end
			expect(g({})).toBe(true)
			expect(g({ mine = true })).toBe(false)
			expect(g({ trusted = true })).toBe(false)
			expect(g({ direction = "Out" })).toBe(false)
			expect(g({ locked = false })).toBe(false)
		end)
		it("a gate the Watchman shut stops that farm's Suspects carrying a stolen crop both ways, nobody else", function()
			local base = { mine = false, trusted = false, locked = false, shut = true, suspect = true, carrying = true, direction = "Out" }
			expect(DefenceRules.gateBlocks(base)).toBe(true)
			base.direction = "In"
			expect(DefenceRules.gateBlocks(base)).toBe(true)
			base.carrying = false -- (a Suspect with empty hands walks out)
			expect(DefenceRules.gateBlocks(base)).toBe(false)
			base.carrying, base.suspect = true, false
			expect(DefenceRules.gateBlocks(base)).toBe(false)
		end)
		it("the Watchman shuts the gate 10 s at Level 1 up to 20 s at Level 10", function()
			expect(DefenceRules.watchmanShut(1)).toBe(10)
			expect(DefenceRules.watchmanShut(10)).toBe(20)
			expect(DefenceRules.watchmanShut(4)).toBeNear(13.33, 0.01)
		end)
		it("the Tall Back Fence only slows climbing out with a stolen crop", function()
			local d = fresh()
			DefenceRules.buy(d, "TallFence")
			expect(DefenceRules.fenceClimb(d, "Out", true)).toBe(Crime.TALL_FENCE_CLIMB)
			expect(DefenceRules.fenceClimb(d, "Out", false)).toBe(Crime.FENCE_CLIMB)
			expect(DefenceRules.fenceClimb(d, "In", false)).toBe(Crime.FENCE_CLIMB)
			expect(DefenceRules.fenceClimb(fresh(), "Out", true)).toBe(Crime.FENCE_CLIMB)
		end)
	end)

	describe("where they stand", function()
		local W, D = PlotLayout.WIDTH, PlotLayout.DEPTH
		local half = PlotLayout.YARD_SPOT / 2
		local function box(at)
			return { min = Vector3.new(at.X - half, 0, at.Z - half), max = Vector3.new(at.X + half, 0, at.Z + half) }
		end
		local function apart(a, b)
			return a.max.X <= b.min.X or b.max.X <= a.min.X or a.max.Z <= b.min.Z or b.max.Z <= a.min.Z
		end
		it("rings the field with 26 yard spots, apart from each other, the field and every building", function()
			local field = { min = Vector3.new(P.field.across, 0, P.field.depth),
				max = Vector3.new(P.field.across + P.field.size * P.field.tile, 0, P.field.depth + P.field.size * P.field.tile) }
			local others = { field = field, farmhouse = P.farmhouse, warehouse = P.warehouse, path = P.path, shop = P.shop }
			for n = 1, PlotLayout.YARD_SPOTS do
				local b = box(PlotLayout.yardSpot(n))
				expect(b.min.X >= -W / 2 + 3 and b.max.X <= W / 2 - 3 and b.max.Z <= D - 2).toBe(true)
				for name, other in others do
					if not apart(b, other) then
						error(`yard spot {n} runs into the {name}`)
					end
				end
				for m = n + 1, PlotLayout.YARD_SPOTS do
					if not apart(b, box(PlotLayout.yardSpot(m))) then
						error(`yard spots {n} and {m} overlap`)
					end
				end
				-- each within 25 studs of the field (the scarecrow's warning reaches every one)
				expect(DefenceRules.fromField(PlotLayout.yardSpot(n)) <= Defences.SCARECROW_RANGE).toBe(true)
			end
		end)
		it("lets a kennel behind the field cover the raid race's tile", function()
			local tile = PlotLayout.tileLocal(3 * P.field.size + P.field.size)
			local best = math.huge
			for n = 1, PlotLayout.YARD_SPOTS do
				local at = PlotLayout.yardSpot(n)
				best = math.min(best, Vector3.new(at.X - tile.X, 0, at.Z - tile.Z).Magnitude)
			end
			expect(best <= Defences.DOG_RANGE).toBe(true)
		end)
		it("puts the camera on the barn's back corner", function()
			local c = P.camera
			expect(c.X > P.farmhouse.min.X and c.X < P.farmhouse.max.X and math.abs(c.Z - 112) < 1).toBe(true)
		end)
		it("climbs the gate in from the sidewalk and out from the yard", function()
			local x = P.gate.across
			expect(PlotLayout.gateClimbAt(Vector3.new(x, 0, -3), 4)).toBe("In")
			expect(PlotLayout.gateClimbAt(Vector3.new(x, 0, 3), 4)).toBe("Out")
			expect(PlotLayout.gateClimbAt(Vector3.new(x + P.gate.width, 0, -3), 4)).toBe(nil)
			expect(PlotLayout.gateClimbAt(Vector3.new(x, 0, 12), 4)).toBe(nil)
			local path = PlotLayout.gateClimbPath(x, "In")
			expect(path[1].Z < 0 and path[#path].Z > 0).toBe(true)
			path = PlotLayout.gateClimbPath(x, "Out")
			expect(path[1].Z > 0 and path[#path].Z < 0).toBe(true)
		end)
	end)

	describe("the Trusted list", function()
		it("takes up to 10 players, not yourself, nobody twice", function()
			local list = {}
			expect(reason(DefenceRules.trust(list, 1, 1, "me"))).toBe("Self")
			for id = 2, 11 do
				expect(reason(DefenceRules.trust(list, 1, id, `p{id}`))).toBe("ok")
			end
			expect(reason(DefenceRules.trust(list, 1, 2, "p2"))).toBe("Already")
			expect(reason(DefenceRules.trust(list, 1, 12, "p12"))).toBe("Full")
			expect(DefenceRules.untrust(list, 5)).toBe(true)
			expect(DefenceRules.isTrusted(list, 5)).toBe(false)
			expect(reason(DefenceRules.trust(list, 1, 12, "p12"))).toBe("ok")
		end)
		it("is written on the farm for every client to read", function()
			local list = {}
			expect(DefenceRules.trustedText(list)).toBe("")
			DefenceRules.trust(list, 1, 23, "a")
			DefenceRules.trust(list, 1, 456, "b")
			local text = DefenceRules.trustedText(list)
			expect(DefenceRules.inTrustedText(text, 23)).toBe(true)
			expect(DefenceRules.inTrustedText(text, 456)).toBe(true)
			expect(DefenceRules.inTrustedText(text, 2)).toBe(false)
			expect(DefenceRules.inTrustedText(text, 45)).toBe(false)
			expect(DefenceRules.inTrustedText(nil, 23)).toBe(false)
		end)
	end)

	describe("protection", function()
		it("the Sprout Shield lasts your first 45 minutes of play, or until you drop it", function()
			expect(CrimeRules.shieldLeft(0)).toBe(45 * 60)
			expect(CrimeRules.shieldLeft(44 * 60)).toBe(60)
			expect(CrimeRules.shieldLeft(46 * 60)).toBe(0)
			expect(CrimeRules.shieldLeft(10, true)).toBe(0)
		end)
		it("the raid cap frees up as steals age out of the 10 minutes", function()
			local NOW = 1_000_000
			local ledger = {}
			expect(CrimeRules.raidFreeAt(ledger, NOW, 1)).toBe(NOW)
			CrimeRules.raidAdd(ledger, NOW - 300, 5)
			CrimeRules.raidAdd(ledger, NOW - 100, 5)
			-- full: a Common waits for the first 5 to age out
			expect(CrimeRules.raidFreeAt(ledger, NOW, 1)).toBe(NOW - 300 + Crime.RAID_WINDOW)
			expect(CrimeRules.raidFreeAt(ledger, NOW + 301, 1)).toBe(NOW + 301)
		end)
	end)
end
