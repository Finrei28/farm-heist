-- The travel buttons (docs/GameDesign.md §4.11): Home, Town and Visit send
-- you there at once (MovementService.Teleport), with no wait and no cooldown
-- (the user, 2026-11-05: "Remove the wait on the teleport, make it
-- instant."), except Home with a thief on your farm, which takes RAID_WAIT:
-- without it a farmer in town was always back in time, and a raid could
-- never get away (the user chose this, 2026-11-05: "wait if being raided").
-- What keeps travel from being an escape is that none work while you're a
-- Suspect, knocked out or carrying stolen crops. Home, a Suspect has got away:
-- travel works again (CrimeRules.holdsTravel). tests/travel.test.luau.
local TravelRules = {
	RAID_WAIT = 3, -- seconds
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

-- Seconds before you go. raided: there's a thief on your farm.
function TravelRules.waitFor(kind: string, raided: boolean?): number
	return if kind == "Home" and raided then TravelRules.RAID_WAIT else 0
end

return TravelRules
