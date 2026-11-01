-- The movement check (shared/MoveRules, MovementService): normal play,
-- sprinting, falling, jumping and lag never trip it; teleports and speed
-- hacks do. A thief can't teleport out of a farm with a sack.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local Vector3 = require("@lune/roblox").Vector3
	local MoveRules = harness.load("MoveRules")
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
		it("a thief with a sack who runs anyway is caught; walking with it is fine", function()
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
end
