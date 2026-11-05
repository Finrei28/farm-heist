-- The travel buttons (docs/GameDesign.md §4.11): Home, Town and Visit send
-- you there at once (MovementService.Teleport), with no wait and no cooldown
-- (the user, 2026-11-05: "Remove the wait on the teleport, make it
-- instant."). What keeps travel from being an escape is that none work while
-- you're a Suspect, knocked out or carrying stolen crops.
-- tests/travel.test.luau.
local TravelRules = {
	KINDS = { Home = true, Town = true, Visit = true },
}

-- Whether you can go. status = { suspect, knockedOut, carrying }. Returns
-- ok, reason.
function TravelRules.check(kind: string, status): (boolean, string?)
	if not TravelRules.KINDS[kind] then
		return false, "Unknown"
	end
	if status ~= nil and (status.suspect or status.knockedOut or status.carrying) == true then
		return false, "Blocked"
	end
	return true, nil
end

return TravelRules
