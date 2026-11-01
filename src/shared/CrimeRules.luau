-- The rules of raids: who may steal, Suspects, bat hits, knockouts, arrests,
-- and what leaving the game in the middle of one does (docs/GameDesign.md
-- §4.10–4.12). Pure functions over plain tables, so every way of dodging an
-- arrest is tested (tests/crime.test.luau). CrimeService applies them.
--
-- A visit is one player's record for one farm:
--   { inside, visitSuspect, lastSuspectAt, koUntil, immuneUntil, lastSwungAt }
-- lastSwungAt: when that farm's owner last swung the bat at them.
-- Whether someone carries a Loot Sack belongs to the player, not the visit,
-- so it's passed in where it matters.
local Crime = require(script.Parent.Config.Crime)
local Rarities = require(script.Parent.Config.Rarities)

local CrimeRules = {}

local NEVER = -math.huge

function CrimeRules.newVisit()
	return {
		inside = false,
		visitSuspect = false, -- became (or stayed) a Suspect during this visit
		lastSuspectAt = NEVER,
		koUntil = NEVER,
		immuneUntil = NEVER,
		lastSwungAt = NEVER,
	}
end

------------------------------------------------------------------------
-- Suspects

-- Walking in. Coming back within SUSPECT_LINGER of a suspicious act keeps
-- you a Suspect for the whole visit (popping out and back doesn't clear it).
function CrimeRules.enter(visit, now: number)
	visit.inside = true
	if now - visit.lastSuspectAt <= Crime.SUSPECT_LINGER then
		visit.visitSuspect = true
	end
end

function CrimeRules.exit(visit)
	visit.inside = false
	visit.visitSuspect = false
end

-- A suspicious act: starting a steal hold, or climbing in over the back
-- fence or a locked gate. (Climbing out never is.)
function CrimeRules.markSuspect(visit, now: number)
	visit.lastSuspectAt = now
	visit.visitSuspect = true
end

-- Suspect of this farm: carrying a sack inside it, or a suspicious act
-- during this visit, or one in the last SUSPECT_LINGER seconds.
function CrimeRules.isSuspect(visit, now: number, carrying: boolean?): boolean
	if carrying and visit.inside then
		return true
	end
	return visit.visitSuspect or now - visit.lastSuspectAt <= Crime.SUSPECT_LINGER
end

------------------------------------------------------------------------
-- Stealing

-- Seconds a steal hold takes. mods: { cloche, harvestMoon }.
function CrimeRules.stealHold(rarityId: string, mods): number
	local seconds = Rarities.ById[rarityId].stealHold
	if mods and mods.cloche then
		seconds *= Crime.CLOCHE_HOLD
	end
	if mods and mods.harvestMoon then
		seconds *= Crime.HARVEST_MOON_HOLD
	end
	return seconds
end

-- Whether a steal hold may start. ctx:
--   { now, inside, knockedOut, thiefProtected (Sprout Shield or arrival
--     grace), farmProtected (the owner's), trusted, cooldownUntil (same-farm
--     cooldown), ripe, rarity, sackUsed, raidUsed }
-- Returns ok, reason.
function CrimeRules.canSteal(ctx): (boolean, string?)
	if not ctx.inside then
		return false, "NotInside"
	end
	if ctx.knockedOut then
		return false, "KnockedOut"
	end
	if ctx.thiefProtected then
		return false, "YouAreProtected"
	end
	if ctx.farmProtected then
		return false, "FarmProtected"
	end
	if ctx.trusted then
		return false, "Trusted"
	end
	if ctx.now < (ctx.cooldownUntil or NEVER) then
		return false, "Cooldown"
	end
	if not ctx.ripe then
		return false, "NotRipe"
	end
	local weight = Rarities.ById[ctx.rarity].sackWeight
	if (ctx.sackUsed or 0) + weight > Crime.SACK_CAPACITY then
		return false, "SackFull"
	end
	if (ctx.raidUsed or 0) + weight > Crime.RAID_CAP_WEIGHT then
		return false, "RaidCap"
	end
	return true, nil
end

-- The server times every hold: done only once the full time has passed.
function CrimeRules.holdDone(startedAt: number, now: number, seconds: number): boolean
	return now - startedAt >= seconds - 0.05
end

-- The raid cap: a farm's ledger of sack weight lost, { { at, weight } }.
function CrimeRules.raidUsed(ledger, now: number): number
	local used = 0
	for i = #ledger, 1, -1 do
		if now - ledger[i].at >= Crime.RAID_WINDOW then
			table.remove(ledger, i)
		else
			used += ledger[i].weight
		end
	end
	return used
end

-- Notes a finished steal. Returns the entry, kept with the loot in the sack.
function CrimeRules.raidAdd(ledger, now: number, weight: number)
	local entry = { at = now, weight = weight }
	table.insert(ledger, entry)
	return entry
end

-- The loot went back to the farm (the thief was knocked out, or left
-- without getting home): it doesn't count against the cap.
function CrimeRules.raidRemove(ledger, entry)
	local index = table.find(ledger, entry)
	if index then
		table.remove(ledger, index)
	end
end

------------------------------------------------------------------------
-- The bat

-- The flat angle (degrees) between where `from` faces and the direction to `to`.
function CrimeRules.angleTo(facing: Vector3, from: Vector3, to: Vector3): number
	local look = Vector3.new(facing.X, 0, facing.Z)
	local toward = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if look.Magnitude < 1e-6 or toward.Magnitude < 1e-6 then
		return 0
	end
	local cos = math.clamp(look.Unit:Dot(toward.Unit), -1, 1)
	return math.deg(math.acos(cos))
end

-- Whether a swing hits. h:
--   { now, lastSwingAt, attackerIsOwner, attackerInside, targetInside,
--     distance, angle, lineClear, targetTrusted, targetImmune }
-- Returns ok, reason (logged as HitRejected when an exploit is likely).
function CrimeRules.validHit(h): (boolean, string?)
	if h.now - (h.lastSwingAt or NEVER) < Crime.SWING_COOLDOWN then
		return false, "Cooldown"
	end
	if not h.attackerIsOwner then
		return false, "NotOwner"
	end
	if not h.attackerInside then
		return false, "OwnerOutside"
	end
	if not h.targetInside then
		return false, "TargetOutside"
	end
	if h.targetTrusted then
		return false, "Trusted"
	end
	if h.targetImmune then
		return false, "Immune"
	end
	if h.distance > Crime.HIT_RANGE + Crime.HIT_LAG then
		return false, "TooFar"
	end
	if h.angle > Crime.HIT_ARC / 2 and h.distance > Crime.HIT_CLOSE then
		return false, "Behind"
	end
	if not h.lineClear then
		return false, "Blocked"
	end
	return true, nil
end

------------------------------------------------------------------------
-- Knockouts and arrests

-- A hit lands: 5 s knocked out, then 6 s when hits only nudge. Returns
-- whether they're a Suspect (only Suspects can be arrested).
function CrimeRules.knockOut(visit, now: number, carrying: boolean?): boolean
	if carrying and visit.inside then
		-- Caught with stolen goods (even from another farm): the sack goes
		-- back, but they stay arrestable.
		CrimeRules.markSuspect(visit, now)
	end
	visit.koUntil = now + Crime.KO_SECONDS
	visit.immuneUntil = now + Crime.KO_SECONDS + Crime.IMMUNE_SECONDS
	visit.lastSwungAt = now
	return CrimeRules.isSuspect(visit, now, carrying)
end

function CrimeRules.isKnockedOut(visit, now: number): boolean
	return now < visit.koUntil
end

-- Knocked out, or just woken: a hit only nudges.
function CrimeRules.isImmune(visit, now: number): boolean
	return now < visit.immuneUntil
end

-- The owner swung at them (missing counts too, for the chase rule).
function CrimeRules.swungAt(visit, now: number)
	visit.lastSwungAt = now
end

-- Whether the owner may arrest them. ctx: { distance, ownerInside }.
-- Returns ok, reason.
function CrimeRules.canArrest(visit, now: number, ctx): (boolean, string?)
	if not CrimeRules.isKnockedOut(visit, now) then
		return false, "NotKnockedOut"
	end
	if not CrimeRules.isSuspect(visit, now) then
		return false, "NotSuspect"
	end
	if not ctx.ownerInside then
		return false, "OwnerOutside"
	end
	if ctx.distance > Crime.ARREST_RANGE then
		return false, "TooFar"
	end
	return true, nil
end

-- The Leave farm button: for someone knocked out who did nothing wrong.
function CrimeRules.canLeaveFarm(visit, now: number): boolean
	return not CrimeRules.isSuspect(visit, now)
end

------------------------------------------------------------------------
-- Leaving, resetting and dying (the ways people try to dodge an arrest)

-- What happens when a player leaves the game while visiting this farm.
-- ctx: { carrying, ownerDistance (nil if the owner isn't here),
--        shuttingDown (BindToClose: nobody is penalised) }
-- Returns "Fled" | "Chased" | "ReturnLoot" | "None".
--   Fled:   knocked out as a Suspect → automatic arrest, fine × FLEE
--   Chased: carrying loot with the owner close, or swung at lately →
--           automatic arrest, fine × FLEE
--   ReturnLoot: carrying loot, nobody chasing (it could be a real
--           disconnect) → the loot goes back, no fine
-- Fled and Chased return the loot too.
function CrimeRules.leaveOutcome(visit, now: number, ctx): string
	if ctx.shuttingDown then
		return if ctx.carrying then "ReturnLoot" else "None"
	end
	if CrimeRules.isKnockedOut(visit, now) and CrimeRules.isSuspect(visit, now, ctx.carrying) then
		return "Fled"
	end
	if ctx.carrying and visit.inside then
		local close = ctx.ownerDistance ~= nil and ctx.ownerDistance <= Crime.CHASE_RANGE
		local swung = now - visit.lastSwungAt <= Crime.CHASE_SWING
		if close or swung then
			return "Chased"
		end
	end
	if ctx.carrying then
		return "ReturnLoot"
	end
	return "None"
end

-- The reset button is off while you're a Suspect, knocked out or carrying.
function CrimeRules.canReset(visit, now: number, carrying: boolean?): boolean
	return not (carrying or CrimeRules.isKnockedOut(visit, now) or (visit.inside and CrimeRules.isSuspect(visit, now)))
end

-- The character died or was removed (an exploit, falling out of the world)
-- while knocked out as a Suspect: that's an automatic arrest too.
function CrimeRules.deathOutcome(visit, now: number, carrying: boolean?): string
	if CrimeRules.isKnockedOut(visit, now) and CrimeRules.isSuspect(visit, now, carrying) then
		return "Fled"
	end
	return if carrying then "ReturnLoot" else "None"
end

-- Rejoining soon after an arrest (or after fleeing one) starts you on the
-- police porch, not at your farm. crime: the save's crime record.
function CrimeRules.startsOnPorch(crime, now: number): boolean
	return now - (crime.lastArrestAt or 0) < Crime.POLICE_PORCH_REJOIN
end

-- Whether an arrest counts for the Sheriff board and arrest XP (staged
-- arrests between friends don't). pairToday: arrests of this thief by this
-- owner already counted today.
function CrimeRules.countsForBoard(lootValue: number, pairToday: number): boolean
	return lootValue >= Crime.BOARD_MIN_LOOT and pairToday < Crime.BOARD_PAIR_LIMIT
end

return CrimeRules
