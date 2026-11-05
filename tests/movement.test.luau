-- The movement check (shared/MoveRules, MovementService): normal play,
-- sprinting, falling, jumping and lag never trip it; teleports and speed
-- hacks do. A thief can't teleport out of a farm with a stolen crop.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local Vector3 = require("@lune/roblox").Vector3
	local MoveRules = harness.load("MoveRules")
	local PlotLayout = harness.load("PlotLayout")
	local Settings = harness.load("Config/Settings")

	local TICK = 0.1

	-- Moves at `speed` studs a second (across the ground) for `seconds`;
	-- returns how many ticks were rejected.
	local function run(budget, speed, seconds, rise)
		local rejected = 0
		for _ = 1, math.floor(seconds / TICK + 0.5) do
			local ok = MoveRules.step(budget, Vector3.new(speed * TICK, (rise or 0) * TICK, 0), TICK)
			if not ok then
				rejected += 1
			end
		end
		return rejected
	end

	describe("fair movement", function()
		it("walking and sprinting for a long time are fine", function()
			expect(run(MoveRules.new(), Settings.WALK_SPEED, 60)).toBe(0)
			expect(run(MoveRules.new(), Settings.RUN_SPEED, 60)).toBe(0)
		end)
		it("falling off a hill is fine (falling is free)", function()
			expect(run(MoveRules.new(), 0, 3, -120)).toBe(0)
		end)
		it("a lag spike (frozen, then catching up all at once) is fine", function()
			local budget = MoveRules.new()
			run(budget, Settings.RUN_SPEED, 5)
			expect((MoveRules.step(budget, Vector3.new(Settings.RUN_SPEED * 1.2, 0, 0), 1.2))).toBe(true)
			expect(run(budget, Settings.RUN_SPEED, 5)).toBe(0)
		end)
	end)

	describe("cheating", function()
		it("a teleport from a field to the back trail (100 studs) is rejected straight away", function()
			local ok, overBy = MoveRules.step(MoveRules.new(), Vector3.new(100, 0, 0), TICK)
			expect(ok).toBe(false)
			expect(overBy).toBeGreaterThan(30)
		end)
		it("a speed hack (twice sprint speed) is caught within a few seconds", function()
			local budget = MoveRules.new()
			local firstRejection = nil
			for tick = 1, 60 do
				if not MoveRules.step(budget, Vector3.new(Settings.RUN_SPEED * 2 * TICK, 0, 0), TICK) then
					firstRejection = tick
					break
				end
			end
			expect(firstRejection ~= nil and firstRejection * TICK <= 4).toBe(true)
		end)
		it("flying straight up is caught", function()
			expect(run(MoveRules.new(), 0, 3, 40)).toBeGreaterThan(0)
		end)
		it("a thief carrying a stolen crop who runs anyway is caught; walking with it is fine", function()
			local scale = Settings.WALK_SPEED * 0.85 / Settings.RUN_SPEED
			local function carry(speed, seconds)
				local budget = MoveRules.new()
				local rejected = 0
				for _ = 1, math.floor(seconds / TICK + 0.5) do
					if not MoveRules.step(budget, Vector3.new(speed * TICK, 0, 0), TICK, scale) then
						rejected += 1
					end
				end
				return rejected
			end
			expect(carry(Settings.WALK_SPEED * 0.85, 60)).toBe(0)
			expect(carry(Settings.RUN_SPEED, 30)).toBeGreaterThan(0)
		end)
	end)

	describe("just after a server teleport", function()
		it("a client still saying where it was is ignored, not trusted", function()
			expect(MoveRules.fits(MoveRules.new(), Vector3.new(400, 0, 0))).toBe(false)
		end)
		it("walking off from where the server put you counts as normal", function()
			expect(MoveRules.fits(MoveRules.new(), Vector3.new(3, 0, 0))).toBe(true)
		end)
		it("looking doesn't spend the allowance", function()
			local budget = MoveRules.new()
			MoveRules.fits(budget, Vector3.new(50, 0, 0))
			expect(budget.across).toBe(MoveRules.SAVED)
		end)
	end)

	describe("hanging in the air over a farm", function()
		it("a jump never counts: it tops out under the limit", function()
			local budget = MoveRules.new()
			for _ = 1, 100 do
				expect(MoveRules.hovering(budget, 10.2, TICK)).toBe(false)
			end
		end)
		it("a fall off a roof is over before it counts", function()
			local budget = MoveRules.new()
			for _ = 1, 10 do
				expect(MoveRules.hovering(budget, 30, TICK)).toBe(false)
			end
			expect(MoveRules.hovering(budget, 2, TICK)).toBe(false)
			expect(budget.air).toBe(0)
		end)
		it("hovering out of the bat's reach is caught", function()
			local budget = MoveRules.new()
			local caught = false
			for _ = 1, 20 do
				caught = caught or MoveRules.hovering(budget, 20, TICK)
			end
			expect(caught).toBe(true)
		end)
	end)

	describe("a farm's walls", function()
		-- a point in plot 3's space, in the world
		local function at(x, z)
			return PlotLayout.toWorld(3, Vector3.new(x, 3, z))
		end
		local gate = PlotLayout.PLOT.gate
		local depth = PlotLayout.DEPTH
		local half = PlotLayout.WIDTH / 2

		it("the gateway is the way in and out, on foot or at a run", function()
			expect(PlotLayout.wallCrossing(3, at(gate.across, -3), at(gate.across, 3))).toBe(nil)
			expect(PlotLayout.wallCrossing(3, at(gate.across, 3), at(gate.across, -3))).toBe(nil)
			expect(PlotLayout.wallCrossing(3, at(gate.across + 8, -2), at(gate.across + 8, 1))).toBe(nil)
		end)
		it("walking about inside or outside crosses nothing", function()
			expect(PlotLayout.wallCrossing(3, at(40, 200), at(43, 203))).toBe(nil)
			expect(PlotLayout.wallCrossing(3, at(40, -10), at(90, -10))).toBe(nil)
			expect(PlotLayout.wallCrossing(3, at(40, depth + 10), at(90, depth + 10))).toBe(nil)
		end)
		it("the front fence beside the gateway stops you", function()
			expect(PlotLayout.wallCrossing(3, at(60, -3), at(60, 3))).toBe("Wall")
		end)
		it("the back fence stops you both ways: only the climb goes over it", function()
			expect(PlotLayout.wallCrossing(3, at(0, depth + 3), at(0, depth - 3))).toBe("Wall")
			expect(PlotLayout.wallCrossing(3, at(0, depth - 3), at(0, depth + 3))).toBe("Wall")
		end)
		it("the hedges stop you", function()
			expect(PlotLayout.wallCrossing(3, at(half - 3, 120), at(half + 6, 120))).toBe("Wall")
			expect(PlotLayout.wallCrossing(3, at(-half + 3, 120), at(-half - 6, 120))).toBe("Wall")
		end)
		it("a store's walls stop you, except at the staff door", function()
			local box = PlotLayout.storeBox(1)
			local middle = (box.min.X + box.max.X) / 2
			expect(PlotLayout.wallCrossing(3, at(middle, box.max.Z - 3), at(middle, box.max.Z + 4), 1)).toBe("Wall")
			local door = PlotLayout.storeLocal(0.5, 2)
			expect(PlotLayout.wallCrossing(3, at(door.X - 3, door.Z), at(door.X + 3, door.Z), 1)).toBe("StaffDoor")
		end)
		it("the store's front door is none of the farm's business", function()
			local door = PlotLayout.storeLocal(3, 1)
			expect(PlotLayout.wallCrossing(3, at(door.X, -3), at(door.X, 3), 1)).toBe(nil)
		end)
		it("knows which plot you're over", function()
			expect(PlotLayout.plotAt(at(0, 100))).toBe(3)
			expect(PlotLayout.plotAt(Vector3.new(0, 3, 0))).toBe(nil)
		end)
	end)
end
