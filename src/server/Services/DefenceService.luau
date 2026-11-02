-- Defending your farm (docs/GameDesign.md §4.1, §4.10, §4.11, §5.4): the
-- defences you buy and set out (shared/DefenceRules, Config/Defences), the
-- Trusted list, the Sprout Shield and arrival grace, the domes over the
-- field, and what happens on your farm when someone steals from it (the
-- dog, the Watchman, the alarm light). Drawn by World/DefenceArt; the
-- clients draw the moving parts (client DefenceController).
--
-- Through the DefenceAction remote: Buy, Place, PutAway, Trust, Untrust,
-- DropShield, Visitors (the camera's list).
--
-- Attributes the clients read:
--   players: ShieldUntil, GraceUntil (server time their protection ends),
--     Slow + SlowUntil (the dog has them by the trousers: slower until then)
--   plot models: Trusted (",id,id,": DefenceRules.inTrustedText),
--     GateLocked, GateShutUntil (the Watchman shut it on Suspects),
--     AlarmUntil (the alarm light spins and the gate's flag flashes)
--   the dog (Defences/GuardDog/Dog): Chase (a thief's user id), ChaseAt
--   the gatehouse: SpotOn (the thief the spotlight follows), SpotUntil
--   field tiles: Cloche
--
-- CrimeService asks it who's protected or Trusted, how long a climb takes,
-- whether the gate stops someone, and tells it when the alarm goes off
-- (OnAlarm), a steal starts (OnSteal: the dog barks) and a theft is done
-- (OnTheft: the dog runs, the Watchman shuts the gate); it sets
-- DefenceService.raidFreeAt (the raid cap's dome).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Crime = require(Shared.Config.Crime)
local CrimeRules = require(Shared.CrimeRules)
local Defences = require(Shared.Config.Defences)
local DefenceRules = require(Shared.DefenceRules)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)

local Server = ServerScriptService.Server
local ActionRemote = require(Server.Util.ActionRemote)
local Analytics = require(Server.Util.Analytics)
local Notice = require(Server.Util.Notice)
local DefenceArt = require(Server.World.DefenceArt)
local DataService = require(script.Parent.DataService)
local MovementService = require(script.Parent.MovementService)
local PlotService = require(script.Parent.PlotService)

local DefenceEvent = Remotes.event("DefenceEvent")

local DefenceService = {}

local TICK = 0.25
local GATE_NEAR = 10 -- studs either side of the gate where it swings open for someone it lets through
local ALARM_LIGHT = 12 -- seconds the alarm light spins after an alarm
local SPOT_SECONDS = 25 -- seconds the Watchman's spotlight follows a thief
local SEEN_RANGE = 30 -- the scarecrow keeps quiet when you're this close to them yourself

-- [index] = { owner, dogReady, watchman (level or nil), warned = { [userId] = t },
--   seen = { [Player] = true }, inside = { [Player] = true }, side = { [Player] = "In"/"Out" },
--   visitors = { { userId, name, at, stole?, climbed?, arrested? } } }
local farms = {}
local shielded = {} -- [Player] = true while their Sprout Shield is up this session

-- Set by CrimeService: when a farm's raid cap lets a Common go again.
DefenceService.raidFreeAt = function(_ownerId: number, t: number): number
	return t
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function farmOf(index: number)
	return farms[index]
end

local function dataOfPlot(index: number)
	local owner = PlotService.ownerOf(index)
	return owner, owner and DataService.Get(owner)
end

local function frameOf(index: number): CFrame
	return PlotLayout.frame(index)
end

------------------------------------------------------------------------
-- Questions from CrimeService and the others

-- The Sprout Shield or arrival grace is up: they can't steal or be stolen from.
function DefenceService.isProtected(player: Player): boolean
	local t = now()
	return (player:GetAttribute("ShieldUntil") or 0) > t or (player:GetAttribute("GraceUntil") or 0) > t
end

-- `userId` is on `owner`'s Trusted list.
function DefenceService.isTrusted(owner: Player, userId: number): boolean
	local data = DataService.Get(owner)
	return data ~= nil and DefenceRules.isTrusted(data.trusted, userId)
end

-- A cloche over this tile of owner's field.
function DefenceService.cloche(owner: Player, tile: number): boolean
	local data = DataService.Get(owner)
	return data ~= nil and DefenceRules.cloche(data.defences, tile)
end

-- Seconds to climb a farm's back fence (going "In" or "Out", with a
-- stolen crop in your hands or not), and the fence's height.
function DefenceService.fence(index: number, direction: string, carrying: boolean): (number, number)
	local _, data = dataOfPlot(index)
	if not data then
		return Crime.FENCE_CLIMB, PlotLayout.FENCE_HEIGHT
	end
	return DefenceRules.fenceClimb(data.defences, direction, carrying), DefenceRules.fenceHeight(data.defences)
end

-- Whether a farm's gate stops this player going "In" or "Out": locked to
-- anyone but the owner and Trusted friends coming in; shut by the Watchman
-- on that farm's Suspects carrying a stolen crop, either way.
function DefenceService.gateBlocks(index: number, player: Player, direction: string): boolean
	local owner, data = dataOfPlot(index)
	if not owner or not data then
		return false
	end
	local model = PlotService.model(index)
	return DefenceRules.gateBlocks({
		mine = owner == player, trusted = DefenceRules.isTrusted(data.trusted, player.UserId),
		locked = DefenceRules.gateLocked(data.defences), shut = (model:GetAttribute("GateShutUntil") or 0) > now(),
		suspect = (player:GetAttribute("SuspectOf") or 0) == index, carrying = player:GetAttribute("StolenCrop") ~= nil,
		direction = direction,
	})
end

------------------------------------------------------------------------
-- Drawing a farm

local function setTileCloches(index: number, defences)
	local field = PlotService.model(index):FindFirstChild("Field")
	if not field then
		return
	end
	for tile = 1, PlotLayout.PLOT.field.size ^ 2 do
		local part = field:FindFirstChild(`Tile{tile}`)
		if part then
			local on = defences ~= nil and DefenceRules.cloche(defences, tile)
			if (part:GetAttribute("Cloche") == true) ~= on then
				part:SetAttribute("Cloche", if on then true else nil)
			end
		end
	end
end

-- The Watchman's level, if they have one (WorkerService keeps the crew).
local function watchmanLevel(data): number?
	local best = nil
	for _, worker in data.workers do
		if worker.type == "Watchman" then
			best = math.max(best or 0, worker.level)
		end
	end
	return best
end

-- Redraws a player's defences on their farm (after buying, placing ...).
function DefenceService.Redraw(player: Player)
	local index = PlotService.plotOf(player)
	local data = DataService.Get(player)
	if not index or not data then
		return
	end
	local model = PlotService.model(index)
	DefenceArt.show(model, frameOf(index), index, data.defences)
	setTileCloches(index, data.defences)
	model:SetAttribute("GateLocked", DefenceRules.gateLocked(data.defences))
	model:SetAttribute("Trusted", DefenceRules.trustedText(data.trusted))
end

------------------------------------------------------------------------
-- A theft (CrimeService)

-- Someone set off a farm's alarm (a steal, climbing in, walking in with
-- stolen crops, grabbing a dropped one): the alarm light, the Watchman's
-- bell and spotlight. Adds what the owner's alarm card shows to `payload`
-- (camera).
function DefenceService.OnAlarm(owner: Player, thief: Player, index: number, payload)
	local data = DataService.Get(owner)
	local farm = farmOf(index)
	if not data or not farm then
		return
	end
	local t = now()
	local model = PlotService.model(index)
	model:SetAttribute("AlarmUntil", t + ALARM_LIGHT)
	payload.camera = DefenceRules.has(data.defences, "Camera")
	if farm.watchman then
		local gatehouse = model:FindFirstChild("Gatehouse")
		if gatehouse then
			gatehouse:SetAttribute("SpotOn", thief.UserId)
			gatehouse:SetAttribute("SpotUntil", t + SPOT_SECONDS)
		end
		DefenceEvent:FireAllClients("Bell", { plot = index })
	end
	for _, visitor in farm.visitors do
		if visitor.userId == thief.UserId and t - visitor.at < Defences.VISITOR_LOG then
			if payload.climbing then
				visitor.climbed = true
			elseif payload.crop then
				visitor.stole = true
			end
		end
	end
end

-- A steal hold started on `tile`: a guard dog near enough barks (it runs
-- once they have the crop: OnTheft).
function DefenceService.OnSteal(owner: Player, _thief: Player, index: number, tile: number)
	local data = DataService.Get(owner)
	if data and DefenceRules.dogFor(data.defences, PlotLayout.tileLocal(tile)) then
		DefenceEvent:FireAllClients("Bark", { plot = index })
	end
end

-- A theft's done at plot-space point `at` (a crop off the field, or a
-- dropped one grabbed): the guard dog runs at the thief if its kennel is
-- near enough (once every DOG_COOLDOWN) and, when it gets there, slows them
-- for DOG_SLOW_SECONDS (never stops them); the Watchman shuts the gate on
-- them. Returns the seconds it's shut for, if it is.
function DefenceService.OnTheft(owner: Player, thief: Player, index: number, at: Vector3): number?
	local data = DataService.Get(owner)
	local farm = farmOf(index)
	if not data or not farm then
		return nil
	end
	local t = now()
	local shut = nil
	if farm.watchman then
		shut = DefenceRules.watchmanShut(farm.watchman)
		local model = PlotService.model(index)
		model:SetAttribute("GateShutUntil", math.max(model:GetAttribute("GateShutUntil") or 0, t + shut))
	end
	local spot = DefenceRules.dogFor(data.defences, at)
	if not spot or t < (farm.dogReady or 0) then
		return shut
	end
	farm.dogReady = t + Crime.DOG_COOLDOWN
	local holder = nil
	for _, child in (PlotService.model(index):FindFirstChild("Defences") or Instance.new("Folder")):GetChildren() do
		if child:GetAttribute("Spot") == spot then
			holder = child
		end
	end
	local dog = holder and holder:FindFirstChild("Dog")
	if dog then
		dog:SetAttribute("Chase", thief.UserId)
		dog:SetAttribute("ChaseAt", t)
	end
	DefenceEvent:FireAllClients("Bark", { plot = index })
	local _, n = DefenceRules.spotKind(spot)
	local from = PlotLayout.toWorld(index, PlotLayout.yardSpot(n :: number))
	local at = MovementService.positionOf(thief)
	local run = if at then (Vector3.new(at.X, 0, at.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude / Defences.DOG_RUN else 1
	task.delay(run, function()
		if thief.Parent == Players and PlotService.inFarm(thief) == index then
			thief:SetAttribute("Slow", Crime.DOG_SLOW)
			thief:SetAttribute("SlowUntil", now() + Crime.DOG_SLOW_SECONDS)
			Notice.send(thief, "🐕 The guard dog is at your heels: you're slowed!", "Error")
		end
	end)
	return shut
end

-- An arrest on a farm: noted in the camera's list.
function DefenceService.OnArrest(index: number, thief: Player)
	local farm = farmOf(index)
	for _, visitor in (farm and farm.visitors) or {} do
		if visitor.userId == thief.UserId then
			visitor.arrested = true
		end
	end
end

------------------------------------------------------------------------
-- Every tick: domes, the gate, the scarecrow, visitors

local function putBack(player: Player, index: number, inside: boolean)
	local frame = frameOf(index)
	local P = PlotLayout.PLOT
	local local_ = if inside then Vector3.new(P.gate.across, 3, 5) else Vector3.new(P.gate.across, 3, -5)
	local at = frame:PointToWorldSpace(local_)
	MovementService.Teleport(player, CFrame.lookAt(at, at + (if inside then frame.ZVector else -frame.ZVector)))
end

local function tickFarm(owner: Player, index: number, data, t: number)
	local farm = farmOf(index)
	if not farm then
		return
	end
	local model = PlotService.model(index)
	local frame = frameOf(index)

	-- the Sprout Shield ending, and the dome
	local shieldUntil = owner:GetAttribute("ShieldUntil") or 0
	if shielded[owner] and shieldUntil <= t then
		shielded[owner] = nil
		owner:SetAttribute("ShieldUntil", nil)
		DefenceEvent:FireClient(owner, "ShieldOver")
	end
	local graceUntil = owner:GetAttribute("GraceUntil") or 0
	local kind, ends = nil, nil
	if shieldUntil > t then
		kind, ends = "Shield", shieldUntil
	elseif graceUntil > t then
		kind, ends = "Grace", graceUntil
	else
		local free = DefenceService.raidFreeAt(owner.UserId, t)
		if free > t then
			kind, ends = "Watch", free
		end
	end
	DefenceArt.dome(model, frame, kind, ends)

	-- the Watchman (hired or let go in the Workers window)
	local level = watchmanLevel(data)
	if (level ~= nil) ~= (farm.watchman ~= nil) then
		DefenceArt.gatehouse(model, frame, index, level ~= nil)
	end
	farm.watchman = level

	-- the gate: shut while locked or shut on a Suspect, swung open for
	-- anyone it lets through who comes near
	local locked = DefenceRules.gateLocked(data.defences)
	local shut = (model:GetAttribute("GateShutUntil") or 0) > t
	DefenceArt.setGateBlocker(model, frame, locked or shut)
	local open = not locked and not shut

	local P = PlotLayout.PLOT
	for _, other in Players:GetPlayers() do
		local position = MovementService.positionOf(other)
		if not position then
			farm.seen[other], farm.side[other] = nil, nil
			continue
		end
		local p = frame:PointToObjectSpace(position)
		local nearGate = math.abs(p.X - P.gate.across) <= P.gate.width / 2 + 2 and math.abs(p.Z) <= GATE_NEAR and math.abs(p.Y) < 12
		local inside = PlotService.inFarm(other) == index
		if nearGate and not open and not DefenceService.gateBlocks(index, other, if inside then "Out" else "In") then
			open = true
		end
		if other == owner then
			continue
		end
		-- through the gate when it's shut for you (not climbing): back you go
		local side = if not nearGate or (other:GetAttribute("Climbing") or 0) > 0 then nil elseif p.Z < -1.3 then "Out" elseif p.Z > 0.4 then "In" else farm.side[other]
		local was = farm.side[other]
		if was and side and was ~= side and DefenceService.gateBlocks(index, other, side) then
			putBack(other, index, was == "In")
			Notice.send(other, if side == "In" then "The gate's locked: hold Climb to climb it (that makes you a Suspect)." else "The Watchman shut the gate on you: climb out!", "Error")
			side = was
		end
		farm.side[other] = side
		-- the scarecrow: someone who isn't Trusted comes near the field
		local trusted = DefenceRules.isTrusted(data.trusted, other.UserId)
		local sees = not trusted and math.abs(p.Y) < 30 and DefenceRules.scarecrowSees(data.defences, p)
		if sees and not farm.seen[other] and t - (farm.warned[other.UserId] or -math.huge) >= Defences.SCARECROW_GAP then
			local mine = MovementService.positionOf(owner)
			if not mine or (mine - position).Magnitude > SEEN_RANGE then
				farm.warned[other.UserId] = t
				DefenceEvent:FireClient(owner, "Near", { name = other.DisplayName, userId = other.UserId })
			end
		end
		farm.seen[other] = sees or nil
		-- the camera's list of who came in
		if inside and not farm.inside[other] then
			table.insert(farm.visitors, 1, { userId = other.UserId, name = other.DisplayName, at = t, trusted = trusted })
			while #farm.visitors > Defences.VISITOR_MAX do
				table.remove(farm.visitors)
			end
		end
		farm.inside[other] = inside or nil
	end
	DefenceArt.setGate(model, open, locked)
end

local function tick()
	local t = now()
	for owner, index in PlotService.owners() do
		local data = DataService.Get(owner)
		if data then
			local ok, err = pcall(tickFarm, owner, index, data, t)
			if not ok then
				warn(`[DefenceService] {err}`)
			end
		end
	end
end

------------------------------------------------------------------------
-- Actions

local actions = {}

local function atHome(player: Player): boolean
	local index = PlotService.plotOf(player)
	return index ~= nil and PlotService.inFarm(player) == index
end

function actions.Buy(player, data, arg)
	local itemId = arg or ""
	local def = Defences.ITEMS[itemId]
	if not PlotService.plotOf(player) then
		return "NoFarm"
	end
	local ok, why = DefenceRules.canBuy(data.defences, itemId, data.level, data.coins)
	if not ok then
		return if why == "Locked" then "NeedLevel" else why
	end
	if not DataService.SpendCoins(player, def.cost, Analytics.SHOP, itemId) then
		return "NoCoins"
	end
	local spot = DefenceRules.buy(data.defences, itemId)
	DefenceService.Redraw(player)
	return nil, { item = itemId, spot = spot }
end

-- "itemId|spot"
function actions.Place(player, data, arg)
	local itemId, spot = string.match(arg or "", "^(%w+)|([%w:]+)$")
	if not itemId or not spot then
		return "BadRequest"
	end
	local kind = DefenceRules.spotKind(spot)
	if (kind == "yard" or kind == "tile") and not atHome(player) then
		return "NotHome"
	end
	local ok, why = DefenceRules.canPlace(data.defences, data.land, itemId, spot)
	if not ok then
		return why
	end
	DefenceRules.place(data.defences, itemId, spot)
	DefenceService.Redraw(player)
	return nil
end

function actions.PutAway(player, data, arg)
	if not arg or not DefenceRules.spotKind(arg) then
		return "BadRequest"
	end
	if not DefenceRules.putAway(data.defences, arg) then
		return "Empty"
	end
	DefenceService.Redraw(player)
	return nil
end

function actions.Trust(player, data, arg)
	local other = Players:GetPlayerByUserId(tonumber(arg) or 0)
	if not other then
		return "NotHere"
	end
	local ok, why = DefenceRules.trust(data.trusted, player.UserId, other.UserId, other.DisplayName)
	if not ok then
		return if why == "Full" then "TrustedFull" elseif why == "Already" then "AlreadyTrusted" else why
	end
	DefenceService.Redraw(player)
	Notice.send(other, `🤝 {player.DisplayName} trusts you: you can walk into their farm, water and harvest for them (the crops go to their barn).`, "Good")
	return nil
end

function actions.Untrust(player, data, arg)
	local userId = tonumber(arg)
	if not userId or not DefenceRules.untrust(data.trusted, userId) then
		return "NotTrusted"
	end
	DefenceService.Redraw(player)
	return nil
end

-- Drop the Sprout Shield (and arrival grace) early, to start raiding.
function actions.DropShield(player, data, _arg)
	if not DefenceService.isProtected(player) then
		return "NoShield"
	end
	data.crime.shieldDropped = true
	player:SetAttribute("ShieldUntil", nil)
	player:SetAttribute("GraceUntil", nil)
	shielded[player] = nil
	DefenceEvent:FireClient(player, "ShieldOver")
	return nil
end

-- The camera's list of who came into your farm in the last half hour.
function actions.Visitors(player, data, _arg)
	local index = PlotService.plotOf(player)
	local farm = index and farmOf(index)
	if not farm then
		return "NoFarm"
	elseif not DefenceRules.has(data.defences, "Camera") then
		return "NoCamera"
	end
	local t = now()
	local list = {}
	for _, visitor in farm.visitors do
		if t - visitor.at <= Defences.VISITOR_LOG then
			table.insert(list, { name = visitor.name, ago = math.floor(t - visitor.at), stole = visitor.stole, climbed = visitor.climbed,
				arrested = visitor.arrested, trusted = visitor.trusted })
		end
	end
	return nil, list
end

------------------------------------------------------------------------
-- Dev commands

-- /shield off · /shield on
function DefenceService.DevShield(player: Player, on: boolean)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if on then
		data.playSeconds = 0
		data.crime.shieldDropped = false
		player:SetAttribute("ShieldUntil", now() + Crime.SHIELD_SECONDS)
		player:SetAttribute("GraceUntil", now() + Crime.ARRIVAL_GRACE)
		shielded[player] = true
	else
		player:SetAttribute("ShieldUntil", nil)
		player:SetAttribute("GraceUntil", nil)
		if shielded[player] then
			shielded[player] = nil
			DefenceEvent:FireClient(player, "ShieldOver")
		end
	end
end

-- /defences all: one of everything (four mud patches, cloches over the
-- first open tiles), set out round the field · /defences none
function DefenceService.DevAll(player: Player, all: boolean)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.defences = { owned = {}, placed = {} }
	if all then
		for _, itemId in Defences.ORDER do
			local def = Defences.ITEMS[itemId]
			for _ = 1, (if itemId == "Cloche" then 4 else def.max) do
				DefenceRules.buy(data.defences, itemId)
			end
		end
		DefenceRules.place(data.defences, "Scarecrow", "yard:4")
		DefenceRules.place(data.defences, "GuardDog", "yard:13")
		for _, n in { 10, 12, 15, 17 } do
			DefenceRules.place(data.defences, "MudPatch", `yard:{n}`)
		end
		local tiles = 0
		for tile = 1, 64 do
			if tiles < 4 and DefenceRules.canPlace(data.defences, data.land, "Cloche", `tile:{tile}`) then
				DefenceRules.place(data.defences, "Cloche", `tile:{tile}`)
				tiles += 1
			end
		end
	end
	DefenceService.Redraw(player)
	DataService.NotifyState(player)
end

------------------------------------------------------------------------

function DefenceService.Start()
	ActionRemote(Remotes.func("DefenceAction"), actions, DataService, 0.15)

	PlotService.OnAssigned(function(player, index, data)
		farms[index] = { owner = player, warned = {}, seen = {}, inside = {}, side = {}, visitors = {} }
		local model = PlotService.model(index)
		model:SetAttribute("GateShutUntil", nil)
		model:SetAttribute("AlarmUntil", nil)
		DefenceService.Redraw(player)
		-- protection: the Sprout Shield (play time) and arrival grace
		local t = now()
		local left = CrimeRules.shieldLeft(data.playSeconds, data.crime.shieldDropped)
		if left > 0 then
			player:SetAttribute("ShieldUntil", t + left)
			shielded[player] = true
		end
		player:SetAttribute("GraceUntil", t + Crime.ARRIVAL_GRACE)
	end)

	PlotService.OnReleased(function(player, index)
		farms[index] = nil
		shielded[player] = nil
		local model = PlotService.model(index)
		local frame = frameOf(index)
		DefenceArt.show(model, frame, index, { owned = {}, placed = {} })
		DefenceArt.gatehouse(model, frame, index, false)
		DefenceArt.dome(model, frame, nil)
		DefenceArt.setGateBlocker(model, frame, false)
		DefenceArt.setGate(model, true, false)
		setTileCloches(index, nil)
		for _, name in { "Trusted", "GateLocked", "GateShutUntil", "AlarmUntil" } do
			model:SetAttribute(name, nil)
		end
	end)

	DataService.OnWiped(function(player)
		DefenceService.Redraw(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, farm in farms do
			farm.seen[player], farm.inside[player], farm.side[player] = nil, nil, nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			tick()
		end
	end)
end

return DefenceService
