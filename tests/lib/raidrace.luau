-- The raid race (docs/GameDesign.md §4.11), timed from the real layout
-- (shared/PlotLayout) and the real numbers (Config/Crime, Settings,
-- Rarities, TravelRules). Used by tests/layout.test.luau and
-- tools/raidrace.luau.
--
-- A thief takes a Rare Pumpkin from the back row (column 8, row 4) and runs
-- straight back to the fence. The owner notices after NOTICE seconds,
-- sprints, and catches the thief if they get within bat reach before the
-- thief is over the fence (someone climbing out still counts as inside).
return function(harness)
	local roblox = require("@lune/roblox")
	local Vector3 = roblox.Vector3
	local PlotLayout = harness.load("PlotLayout")
	local Crime = harness.load("Config/Crime")
	local Settings = harness.load("Config/Settings")
	local Rarities = harness.load("Config/Rarities")
	local TravelRules = harness.load("TravelRules")

	local NOTICE = 1 -- seconds to react to the theft alarm
	local P = PlotLayout.PLOT
	local function flat(v)
		return Vector3.new(v.X, 0, v.Z)
	end

	local tile = 3 * P.field.size + P.field.size -- row 4, column 8
	local crop = flat(PlotLayout.tileLocal(tile))
	local fence = Vector3.new(crop.X, 0, P.backFence)
	local run = (fence - crop).Magnitude
	local walk = Settings.WALK_SPEED * Crime.SACK_SPEED
	local hold = Rarities.ById.Rare.stealHold
	local reach = Crime.HIT_RANGE

	-- Thief 1: no defences.
	local thief1 = { hold = hold, run = run / walk, climb = Crime.FENCE_CLIMB }
	thief1.climbsAt = thief1.hold + thief1.run
	thief1.safe = thief1.climbsAt + thief1.climb

	-- Thief 2: a cloche on the tile, the guard dog, the tall fence.
	local slow = walk * (1 - Crime.DOG_SLOW)
	local slowStretch = slow * Crime.DOG_SLOW_SECONDS
	local runDefended = if run <= slowStretch then run / slow else Crime.DOG_SLOW_SECONDS + (run - slowStretch) / walk
	local thief2 = { hold = hold * Crime.CLOCHE_HOLD, run = runDefended, climb = Crime.TALL_FENCE_CLIMB }
	thief2.climbsAt = thief2.hold + thief2.run
	thief2.safe = thief2.climbsAt + thief2.climb

	-- The owner, from the warehouse or from town (Home, then the farmhouse door).
	local warehouseDistance = (fence - flat(PlotLayout.centre(P.warehouse))).Magnitude
	local doorDistance = (fence - flat(P.door)).Magnitude
	local ownerWarehouse = NOTICE + (warehouseDistance - reach) / Settings.RUN_SPEED
	local ownerTown = NOTICE + TravelRules.CHANNEL + (doorDistance - reach) / Settings.RUN_SPEED

	return {
		notice = NOTICE,
		run = run,
		thief1 = thief1,
		thief2 = thief2,
		warehouseDistance = warehouseDistance,
		doorDistance = doorDistance,
		ownerWarehouse = ownerWarehouse,
		ownerTown = ownerTown,
	}
end
