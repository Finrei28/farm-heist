-- Prints the raid race (docs/GameDesign.md §4.11) worked out from the real
-- layout and numbers. Run after changing PlotLayout, Config/Crime, walking
-- speeds or the travel channel (from the project folder):
--   lune run tools/raidrace
local Harness = require("../tests/lib/harness")
local raidRace = require("../tests/lib/raidrace")

Harness.reset()
Harness.fresh()
local race = raidRace(Harness)

local function s(seconds)
	return string.format("%.1f s", seconds)
end

print("The raid race: a Rare Pumpkin from the back row")
print(string.format("  back row to the fence: %.0f studs; warehouse to there: %.0f; farmhouse door to there: %.0f",
	race.run, race.warehouseDistance, race.doorDistance))
local t1, t2 = race.thief1, race.thief2
print(`  Thief 1, no defences:      hold {s(t1.hold)} + run {s(t1.run)} + climb {s(t1.climb)} = safe at {s(t1.safe)}`)
print(`  Thief 2, cloche+dog+tall:  hold {s(t2.hold)} + run {s(t2.run)} + climb {s(t2.climb)} = safe at {s(t2.safe)} (climbing from {s(t2.climbsAt)})`)
print(`  Owner at the warehouse:    in bat reach at {s(race.ownerWarehouse)}`)
print(`  Owner in town (Home):      in bat reach at {s(race.ownerTown)}`)
print("")
print(`  Thief 1 vs owner at the warehouse: {if t1.safe < race.ownerWarehouse then "escapes" else "caught"}`)
print(`  Thief 2 vs owner at the warehouse: {if race.ownerWarehouse < t2.safe then "caught" else "escapes"}`)
print(`  Thief 2 vs owner in town:          {if race.ownerTown < t2.safe then "caught" else "escapes"} (margin {s(t2.safe - race.ownerTown)})`)
