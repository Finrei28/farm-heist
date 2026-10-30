-- Is a position inside a farm? (docs/GameDesign.md §3, §4.12.) A farm's zone
-- is a box: { cframe = CFrame, size = Vector3 }. Always checked with the
-- trusted position (MovementService.positionOf). Leaving needs you to be a
-- stud past the edge (so standing on the line doesn't flicker the bat on
-- and off), and anyone climbing the back fence or a gate counts as inside
-- for the whole climb, in or out. tests/zone.test.luau.
local ZoneRules = {
	HYSTERESIS = 1,
}

-- climbing: they're partway over the fence or gate of this farm.
function ZoneRules.inside(zone, position: Vector3, wasInside: boolean?, climbing: boolean?): boolean
	if climbing then
		return true
	end
	local p = zone.cframe:PointToObjectSpace(position)
	local margin = if wasInside then ZoneRules.HYSTERESIS else 0
	return math.abs(p.X) <= zone.size.X / 2 + margin
		and math.abs(p.Y) <= zone.size.Y / 2 + margin
		and math.abs(p.Z) <= zone.size.Z / 2 + margin
end

return ZoneRules
