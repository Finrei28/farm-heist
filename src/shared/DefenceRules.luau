-- Defences and the Trusted list (docs/GameDesign.md §4.1, §4.11;
-- Config/Defences): buying, where each one can stand, and what each does to
-- a thief. Pure functions over the save's tables (tests/defences.test.luau);
-- DefenceService applies them.
--
-- defences = { owned = { [itemId] = how many you own },
--              placed = { [spot] = itemId } }
-- A spot is "yard:N" (PlotLayout.yardSpot, 1–26), "tile:N" (a field tile,
-- 1–64), or an item's own place: "gate", "fence", "camera", "floods". What you own
-- but haven't set out is put away (in the barn).
--
-- trusted = { { id, name } }, up to TRUSTED_MAX.
local Defences = require(script.Parent.Config.Defences)
local Crime = require(script.Parent.Config.Crime)
local LandRules = require(script.Parent.LandRules)
local PlotLayout = require(script.Parent.PlotLayout)

local DefenceRules = {}

local FIXED = { gate = true, fence = true, camera = true, floods = true }

-- "yard" · "tile" · "gate" · "fence" · "camera" · "floods", and the number of a yard
-- spot or tile; nil for anything else.
function DefenceRules.spotKind(spot: string): (string?, number?)
	if FIXED[spot] then
		return spot, nil
	end
	local kind, n = string.match(spot, "^(%a+):(%d+)$")
	n = tonumber(n)
	if kind == "yard" and n and n >= 1 and n <= PlotLayout.YARD_SPOTS then
		return kind, n
	elseif kind == "tile" and n and n >= 1 and n <= PlotLayout.PLOT.field.size ^ 2 then
		return kind, n
	end
	return nil, nil
end

function DefenceRules.owned(defences, itemId: string): number
	return defences.owned[itemId] or 0
end

-- The spots where this item stands, sorted.
function DefenceRules.spotsOf(defences, itemId: string): { string }
	local list = {}
	for spot, id in defences.placed do
		if id == itemId then
			table.insert(list, spot)
		end
	end
	table.sort(list)
	return list
end

-- How many are put away (owned and not set out).
function DefenceRules.spare(defences, itemId: string): number
	return DefenceRules.owned(defences, itemId) - #DefenceRules.spotsOf(defences, itemId)
end

-- Whether a farm has one of these set out.
function DefenceRules.has(defences, itemId: string): boolean
	for _, id in defences.placed do
		if id == itemId then
			return true
		end
	end
	return false
end

-- Whether you can buy one more. Returns ok, reason ("NoItem", "Locked",
-- "Max", "NoCoins").
function DefenceRules.canBuy(defences, itemId: string, level: number, coins: number): (boolean, string?)
	local def = Defences.ITEMS[itemId]
	if not def then
		return false, "NoItem"
	elseif level < def.level then
		return false, "Locked"
	elseif DefenceRules.owned(defences, itemId) >= def.max then
		return false, "Max"
	elseif coins < def.cost then
		return false, "NoCoins"
	end
	return true, nil
end

-- Buys one (check canBuy first). The ones with their own place go up
-- straight away: returns that spot, else nil (it waits to be set out).
function DefenceRules.buy(defences, itemId: string): string?
	defences.owned[itemId] = DefenceRules.owned(defences, itemId) + 1
	local spot = Defences.ITEMS[itemId].spot
	if FIXED[spot] and defences.placed[spot] == nil then
		defences.placed[spot] = itemId
		return spot
	end
	return nil
end

-- Whether this item can go on this spot. land: the save's land (a cloche
-- needs an open tile). Returns ok, reason ("NoItem", "WrongSpot", "Taken",
-- "NoneSpare", "Overgrown"). A one-of item already out somewhere moves.
function DefenceRules.canPlace(defences, land, itemId: string, spot: string): (boolean, string?)
	local def = Defences.ITEMS[itemId]
	local kind, n = DefenceRules.spotKind(spot)
	if not def then
		return false, "NoItem"
	elseif kind ~= def.spot then
		return false, "WrongSpot"
	elseif defences.placed[spot] ~= nil then
		return false, if defences.placed[spot] == itemId and FIXED[spot] then "AlreadyOut" else "Taken"
	elseif DefenceRules.spare(defences, itemId) <= 0 and not (def.max == 1 and DefenceRules.owned(defences, itemId) == 1) then
		return false, "NoneSpare"
	elseif kind == "tile" and not LandRules.isTileOpen(land, n :: number) then
		return false, "Overgrown"
	end
	return true, nil
end

-- Sets one out (check canPlace first). Returns the spot it moved from, if
-- it was a one-of already out.
function DefenceRules.place(defences, itemId: string, spot: string): string?
	local from = nil
	if DefenceRules.spare(defences, itemId) <= 0 then
		from = DefenceRules.spotsOf(defences, itemId)[1]
		if from then
			defences.placed[from] = nil
		end
	end
	defences.placed[spot] = itemId
	return from
end

-- Puts away whatever is on a spot. Returns its item id (nil: nothing there).
function DefenceRules.putAway(defences, spot: string): string?
	local itemId = defences.placed[spot]
	defences.placed[spot] = nil
	return itemId
end

------------------------------------------------------------------------
-- What they do

-- A cloche over this tile (steals take Crime.CLOCHE_HOLD times as long).
function DefenceRules.cloche(defences, tile: number): boolean
	return defences.placed[`tile:{tile}`] == "Cloche"
end

-- Seconds to climb the back fence.
-- Seconds over the back fence going `direction`: the Tall Back Fence only
-- slows climbing out with a stolen crop in your hands (§4.11).
function DefenceRules.fenceClimb(defences, direction: string?, carrying: boolean?): number
	local tall = defences.placed.fence == "TallFence"
	return if tall and direction == "Out" and carrying then Crime.TALL_FENCE_CLIMB else Crime.FENCE_CLIMB
end

function DefenceRules.fenceHeight(defences): number
	return if defences.placed.fence == "TallFence" then PlotLayout.TALL_FENCE_HEIGHT else PlotLayout.FENCE_HEIGHT
end

function DefenceRules.gateLocked(defences): boolean
	return defences.placed.gate == "GateLock"
end

-- Whether a farm's gate stops someone going g.direction ("In"/"Out").
-- g = { mine (it's their own farm), trusted, locked (the Gate Lock is on),
-- shut (the Watchman has shut it), suspect (of that farm), carrying (a
-- stolen crop in their hands), direction }. Locked stops anyone but you and
-- Trusted friends coming in (walking out is always free); shut stops that
-- farm's Suspects carrying a stolen crop either way (they climb).
-- The server checks crossings with it (DefenceService) and every client
-- lets itself through the gateway with it (client GateController).
function DefenceRules.gateBlocks(g): boolean
	if g.mine then
		return false
	elseif g.shut and g.suspect and g.carrying then
		return true
	end
	return g.direction == "In" and g.locked == true and not g.trusted
end

-- How far a plot-space point is from the field's edge (0 on it).
function DefenceRules.fromField(p: Vector3): number
	local field = PlotLayout.PLOT.field
	local side = field.size * field.tile
	local dx = math.max(field.across - p.X, 0, p.X - (field.across + side))
	local dz = math.max(field.depth - p.Z, 0, p.Z - (field.depth + side))
	return math.sqrt(dx * dx + dz * dz)
end

-- The scarecrow sees someone at plot-space point p.
function DefenceRules.scarecrowSees(defences, p: Vector3): boolean
	return DefenceRules.has(defences, "Scarecrow") and DefenceRules.fromField(p) <= Defences.SCARECROW_RANGE
end

-- The yard spot of a kennel within the dog's range of plot-space point p
-- (the nearest), or nil.
function DefenceRules.dogFor(defences, p: Vector3): string?
	local best, bestDistance = nil, Defences.DOG_RANGE
	for _, spot in DefenceRules.spotsOf(defences, "GuardDog") do
		local _, n = DefenceRules.spotKind(spot)
		local at = PlotLayout.yardSpot(n :: number)
		local distance = Vector3.new(at.X - p.X, 0, at.Z - p.Z).Magnitude
		if distance <= bestDistance then
			best, bestDistance = spot, distance
		end
	end
	return best
end

-- Whether plot-space point p is on a mud patch.
function DefenceRules.inMud(defences, p: Vector3): boolean
	local half = PlotLayout.YARD_SPOT / 2
	for _, spot in DefenceRules.spotsOf(defences, "MudPatch") do
		local _, n = DefenceRules.spotKind(spot)
		local at = PlotLayout.yardSpot(n :: number)
		if math.abs(p.X - at.X) <= half and math.abs(p.Z - at.Z) <= half then
			return true
		end
	end
	return false
end

-- How long a Watchman shuts the gate on a Suspect: 15 s at Level 1 up to
-- 30 s at Level 10.
function DefenceRules.watchmanShut(level: number): number
	local from, to = Crime.WATCHMAN_SHUT[1], Crime.WATCHMAN_SHUT[2]
	return from + (to - from) * (math.clamp(level, 1, 10) - 1) / 9
end

------------------------------------------------------------------------
-- The Trusted list

function DefenceRules.isTrusted(trusted, userId: number): boolean
	for _, entry in trusted do
		if entry.id == userId then
			return true
		end
	end
	return false
end

-- Adds someone. Returns ok, reason ("Self", "Already", "Full").
function DefenceRules.trust(trusted, ownerId: number, userId: number, name: string): (boolean, string?)
	if userId == ownerId then
		return false, "Self"
	elseif DefenceRules.isTrusted(trusted, userId) then
		return false, "Already"
	elseif #trusted >= Defences.TRUSTED_MAX then
		return false, "Full"
	end
	table.insert(trusted, { id = userId, name = name })
	return true, nil
end

function DefenceRules.untrust(trusted, userId: number): boolean
	for i, entry in trusted do
		if entry.id == userId then
			table.remove(trusted, i)
			return true
		end
	end
	return false
end

-- The list as a string a plot model can carry (",123,456,"), so every
-- client can tell who's Trusted there (the gate, the staff door, the bat).
function DefenceRules.trustedText(trusted): string
	local ids = {}
	for _, entry in trusted do
		table.insert(ids, tostring(entry.id))
	end
	return if #ids > 0 then "," .. table.concat(ids, ",") .. "," else ""
end

function DefenceRules.inTrustedText(text: string?, userId: number): boolean
	return text ~= nil and string.find(text, `,{userId},`, 1, true) ~= nil
end

return DefenceRules
