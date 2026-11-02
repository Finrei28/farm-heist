-- The travel buttons (docs/GameDesign.md §4.11): Home, Town and Visit each
-- take a 3 s channel (moving cancels it), then the server teleports you
-- (MovementService.Teleport). There's no cooldown: the channel is the
-- price, and what keeps travel from being an escape is that none work while
-- you're a Suspect, knocked out or carrying stolen crops, checked again when
-- the channel ends (the user, 2026-11-02: "what's the point of having
-- cooldowns for the home and town button?"). tests/travel.test.luau.
--
-- travel (per player, not saved) = { channel = { kind, startedAt, from }? }
local TravelRules = {
	CHANNEL = 3,
	MOVE_TOLERANCE = 1.5, -- studs you can drift during the channel
	KINDS = { Home = true, Town = true, Visit = true },
}

function TravelRules.new()
	return { channel = nil }
end

-- status = { suspect, knockedOut, carrying }
local function blocked(status): boolean
	return status ~= nil and (status.suspect or status.knockedOut or status.carrying) == true
end

-- Starts a channel. Returns ok, reason.
function TravelRules.start(travel, kind: string, now: number, position: Vector3, status): (boolean, string?)
	if not TravelRules.KINDS[kind] then
		return false, "Unknown"
	end
	if blocked(status) then
		return false, "Blocked"
	end
	if travel.channel then
		return false, "Busy"
	end
	travel.channel = { kind = kind, startedAt = now, from = position }
	return true, nil
end

-- Ends the channel. Returns ok and the kind (go!), or false and a reason.
-- Either way the channel is over.
function TravelRules.finish(travel, now: number, position: Vector3, status): (boolean, string)
	local channel = travel.channel
	if not channel then
		return false, "NoChannel"
	end
	if now - channel.startedAt < TravelRules.CHANNEL - 0.05 then
		return false, "TooSoon" -- (keeps the channel: the service checks again later)
	end
	travel.channel = nil
	if (position - channel.from).Magnitude > TravelRules.MOVE_TOLERANCE then
		return false, "Moved"
	end
	if blocked(status) then
		return false, "Blocked"
	end
	return true, channel.kind
end

function TravelRules.cancel(travel)
	travel.channel = nil
end

return TravelRules
