-- Is a position inside a farm? (docs/GameDesign.md §3, §4.12.) A farm's zone
-- is a box with holes cut out of it (your store, §4.8):
-- { cframe = CFrame, size = Vector3, holes = { box }? }. Always checked with
-- the trusted position (MovementService.positionOf). Leaving needs you to be
-- a stud past the edge, or a stud into a hole (so standing on the line
-- doesn't flicker the bat on and off), and anyone climbing the back fence or
-- a gate counts as inside for the whole climb, in or out. tests/zone.test.luau.
local ZoneRules = {
	HYSTERESIS = 1,
}

local function inBox(box, position: Vector3, margin: number): boolean
	local p = box.cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= box.size.X / 2 + margin
		and math.abs(p.Y) <= box.size.Y / 2 + margin
		and math.abs(p.Z) <= box.size.Z / 2 + margin
end

-- climbing: they're partway over the fence or gate of this farm.
function ZoneRules.inside(zone, position: Vector3, wasInside: boolean?, climbing: boolean?): boolean
	if climbing then
		return true
	end
	local margin = if wasInside then ZoneRules.HYSTERESIS else 0
	if not inBox(zone, position, margin) then
		return false
	end
	for _, hole in zone.holes or {} do
		if inBox(hole, position, -margin) then
			return false
		end
	end
	return true
end

return ZoneRules
