-- Prints the raid race (docs/GameDesign.md §4.11) worked out from the real
-- layout and numbers: how far ahead a thief is (+, they escape) or behind
-- (−, caught) as defences are added, against an owner at the farmhouse
-- door, the warehouse or in town, reacting sharply (1 s) or slowly (2.5 s).
-- Run after changing PlotLayout, Config/Crime, Config/Defences, walking
-- speeds or the travel channel (from the project folder):
--   lune run tools/raidrace
local Harness = require("../tests/lib/harness")
local raidRace = require("../tests/lib/raidrace")

Harness.reset()
Harness.fresh()
local race = raidRace(Harness)

local TIERS = {
	{ "nothing", {} },
	{ "Gate Lock (Lv 8)", { lock = true } },
	{ "+ Tall Back Fence (Lv 12)", { lock = true, tall = true } },
	{ "+ cloche on that crop (Lv 14)", { lock = true, tall = true, cloche = true } },
	{ "+ guard dog (Lv 16)", { lock = true, tall = true, cloche = true, dog = true } },
	{ "+ mud on the way out (Lv 24)", race.ALL },
}

local function pad(text: string, width: number): string
	return text .. string.rep(" ", math.max(0, width - utf8.len(text)))
end

print("The raid race: a Rare Pumpkin from the back row (thief's lead in seconds: + escapes, - caught)")
print(string.format("  back row to the fence: %.0f studs; warehouse to there: %.0f; farmhouse door to there: %.0f",
	race.run, race.warehouseDistance, race.doorDistance))
for _, notice in { race.SHARP, race.SLOW } do
	print("")
	print(`  Owner reacts in {notice} s     {pad("way in", 11)}  door  warehouse  town`)
	for _, tier in TIERS do
		local r = race.raid(tier[2])
		local leads = {}
		for _, where in { "door", "warehouse", "town" } do
			table.insert(leads, string.format("%+5.1f", race.lead(tier[2], where, notice)))
		end
		print(`  {pad(tier[1], 30)} {pad(r.entry, 11)} {leads[1]}  {leads[2]}     {leads[3]}`)
	end
end
local r = race.raid(race.ALL)
print("")
print(string.format("  Everything: climb in %.1f + run in %.1f + steal %.1f + run out %.1f + climb out %.1f = safe at %.1f s after the alarm",
	1.5, r.runIn, r.steal, r.out, r.climbOut, r.safe - r.alarm))
