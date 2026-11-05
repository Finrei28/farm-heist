-- The raid race (docs/GameDesign.md §4.11), timed from the real layout
-- (shared/PlotLayout) and the real numbers (Config/Crime, Config/Defences,
-- Settings, Rarities, TravelRules). Used by tests/layout.test.luau and
-- tools/raidrace.luau.
--
-- A thief takes a Rare Pumpkin from the back row (column 8, row 4) and
-- runs straight back to the fence with it. They come in over the back
-- fence (the alarm goes off as they start climbing) or, with no Gate Lock,
-- walk in through the gate (the alarm goes off as they start stealing),
-- whichever leaves the owner less time. The owner reacts `notice` seconds
-- after the alarm, sprints, and catches the thief if they get within bat
-- reach before the thief is over the fence (someone climbing out still
-- counts as inside).
--
-- The defences that change the race (d = a set of these): lock (Gate
-- Lock), tall (Tall Back Fence), cloche (over that crop), dog (its kennel
-- on the back strip next to the thief's way out), mud (on their way out).
-- The scarecrow, the camera and the Watchman don't: they warn, show and
-- shut the gate, and the thief leaves over the back fence.
--
-- race.raid(d) → { entry, alarm, safe, ... } (seconds from the thief's
-- first step in); race.lead(d, where, notice) → seconds the thief is over
-- the fence before the owner reaches them (+ escapes, − caught), the owner
-- starting at "door" (the farmhouse door), "warehouse" or "town" (Home,
-- then the door).
return function(harness)
	local roblox = require("@lune/roblox")
	local Vector3 = roblox.Vector3
	local PlotLayout = harness.load("PlotLayout")
	local Crime = harness.load("Config/Crime")
	local Defences = harness.load("Config/Defences")
	local Settings = harness.load("Config/Settings")
	local Rarities = harness.load("Config/Rarities")
	local TravelRules = harness.load("TravelRules")

	local SHARP, SLOW = 1, 2.5 -- seconds an owner takes to react to the alarm: watching, or busy
	local DT = 0.005
	local P = PlotLayout.PLOT
	local function flat(v)
		return Vector3.new(v.X, 0, v.Z)
	end

	local tile = 3 * P.field.size + P.field.size -- row 4, column 8
	local crop = flat(PlotLayout.tileLocal(tile))
	local fence = Vector3.new(crop.X, 0, P.backFence)
	local landing = PlotLayout.climbPath(crop.X, "In")[5].Z -- (over the back fence: where they land)
	local gate = Vector3.new(P.gate.across, 0, 0)
	local carry = Settings.WALK_SPEED * Crime.CARRY_SPEED
	local hold = Rarities.ById.Rare.stealHold
	local reach = Crime.HIT_RANGE

	-- The back strip's yard spot on the thief's way out (the mud), and the
	-- one beside it (the kennel).
	local mudSpot, kennelSpot = nil, nil
	for n = 1, PlotLayout.YARD_SPOTS do
		local at = PlotLayout.yardSpot(n)
		if at.Z > P.field.depth and (not mudSpot or math.abs(at.X - crop.X) < math.abs(mudSpot.X - crop.X)) then
			mudSpot = at
		end
	end
	for n = 1, PlotLayout.YARD_SPOTS do
		local at = PlotLayout.yardSpot(n)
		local gap = math.abs(at.X - mudSpot.X)
		if at.Z == mudSpot.Z and gap > 1 and (not kennelSpot or gap < math.abs(kennelSpot.X - mudSpot.X)) then
			kennelSpot = at
		end
	end
	local function inMud(z: number): boolean
		local half = PlotLayout.YARD_SPOT / 2
		return math.abs(crop.X - mudSpot.X) <= half and math.abs(z - mudSpot.Z) <= half
	end

	-- Seconds to go straight along z from `from` to `to` at `speed`, with mud
	-- (d.mud) underfoot, the dog's slow from `slowFrom` for its seconds.
	local function go(from: number, to: number, speed: number, d, slowFrom: number?): number
		local z, t = from, 0
		local step = if to > from then 1 else -1
		while (to - z) * step > 0 do
			local keep = 1
			if d.mud and inMud(z) then
				keep *= 1 - Defences.MUD_SLOW
			end
			if slowFrom and t >= slowFrom and t < slowFrom + Crime.DOG_SLOW_SECONDS then
				keep *= 1 - Crime.DOG_SLOW
			end
			z += step * speed * keep * DT
			t += DT
		end
		return t
	end

	local function raid(d)
		local steal = hold * (if d.cloche then Crime.CLOCHE_HOLD else 1)
		-- the dog runs at them once they have the crop (DefenceService.OnTheft)
		local dogAt = if d.dog then (flat(kennelSpot) - crop).Magnitude / Defences.DOG_RUN else nil
		local out = go(crop.Z, fence.Z, carry, d, dogAt)
		local climbOut = if d.tall then Crime.TALL_FENCE_CLIMB else Crime.FENCE_CLIMB
		local options = {}
		-- over the back fence: the alarm goes off as they start climbing in
		local runIn = go(landing, crop.Z, Settings.RUN_SPEED, d)
		table.insert(options, { entry = "back fence", alarm = 0, safe = Crime.FENCE_CLIMB + runIn + steal + out + climbOut,
			runIn = runIn, steal = steal, out = out, climbOut = climbOut })
		-- through an open gate: nothing goes off until they start stealing
		if not d.lock then
			local walkIn = (crop - gate).Magnitude / Settings.RUN_SPEED
			table.insert(options, { entry = "gate", alarm = walkIn, safe = walkIn + steal + out + climbOut,
				runIn = walkIn, steal = steal, out = out, climbOut = climbOut })
		end
		local best = options[1]
		for _, option in options do
			if option.safe - option.alarm < best.safe - best.alarm then
				best = option
			end
		end
		return best
	end

	local starts = {
		door = flat(P.door),
		warehouse = flat(PlotLayout.centre(P.warehouse)),
	}
	-- Seconds from the alarm until the owner is in bat reach of where the
	-- thief climbs out.
	local function ownerReach(where: string, notice: number): number
		local from = starts[where] or starts.door
		local wait = if where == "town" then TravelRules.waitFor("Home", true) else 0
		return notice + wait + ((fence - from).Magnitude - reach) / Settings.RUN_SPEED
	end

	local function lead(d, where: string, notice: number): number
		local r = raid(d)
		return r.alarm + ownerReach(where, notice) - r.safe
	end

	return {
		SHARP = SHARP,
		SLOW = SLOW,
		run = (fence - crop).Magnitude,
		warehouseDistance = (fence - starts.warehouse).Magnitude,
		doorDistance = (fence - starts.door).Magnitude,
		raid = raid,
		ownerReach = ownerReach,
		lead = lead,
		-- every defence that changes the race
		ALL = { lock = true, tall = true, cloche = true, dog = true, mud = true },
	}
end
