-- The travel buttons (docs/GameDesign.md §4.11): Home, Town and Visit each
-- take a 3 s channel (moving cancels it), then the server teleports you
-- (MovementService.Teleport). Each has its own cooldown. None work while
-- you're a Suspect, knocked out or carrying a Loot Sack, and that's checked
-- again when the channel ends. tests/travel.test.luau.
--
-- travel (per player, not saved) = { channel = { kind, startedAt, from }?, readyAt = { [kind] = time } }
local TravelRules = {
	CHANNEL = 3,
	MOVE_TOLERANCE = 1.5, -- studs you can drift during the channel
	COOLDOWNS = { Home = 60, Town = 30, Visit = 30 },
}

function TravelRules.new()
	return { channel = nil, readyAt = {} }
end

-- status = { suspect, knockedOut, carrying }
local function blocked(status): boolean
	return status ~= nil and (status.suspect or status.knockedOut or status.carrying) == true
end

function TravelRules.cooldownLeft(travel, kind: string, now: number): number
	return math.max(0, (travel.readyAt[kind] or 0) - now)
end

-- Starts a channel. Returns ok, reason.
function TravelRules.start(travel, kind: string, now: number, position: Vector3, status): (boolean, string?)
	if not TravelRules.COOLDOWNS[kind] then
		return false, "Unknown"
	end
	if blocked(status) then
		return false, "Blocked"
	end
	if travel.channel then
		return false, "Busy"
	end
	if TravelRules.cooldownLeft(travel, kind, now) > 0 then
		return false, "Cooldown"
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
	travel.readyAt[channel.kind] = now + TravelRules.COOLDOWNS[channel.kind]
	return true, channel.kind
end

function TravelRules.cancel(travel)
	travel.channel = nil
end

return TravelRules
