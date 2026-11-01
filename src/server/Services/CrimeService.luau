-- Raids (docs/GameDesign.md §4.10–4.12): stealing ripe crops from someone
-- else's field into your Loot Sack, emptying it at your own barn, the
-- owner's bat, knockouts, Suspects, arrests and fines, climbing the back
-- fence, and every way of dodging an arrest (the §4.12 table). The rules are
-- shared/CrimeRules, shared/SackRules and shared/FineRules; this applies them.
--
-- Everything is timed and checked here, from trusted positions
-- (MovementService): a steal hold (start → done ≥ the hold time, still in
-- reach, the crop still ripe, room in the sack), a swing (the owner's bat,
-- inside their farm, the target in front within reach with a clear line),
-- an arrest hold (the target knocked out, a Suspect, within 8 studs).
--
-- Players carry attributes the clients draw from: Sack (weight carried),
-- SackFrom (the farm the last crop came from), SuspectOf (the farm they're
-- a Suspect of, or 0), KnockedOut (server time they wake, or 0), KOSuspect,
-- KOPlot, ImmuneUntil, Climbing (a farm's index while climbing its back
-- fence). A field tile being stolen from has the tag "Stealing" and
-- StealBy (user id), StealStart / StealEnds (server time).
--
-- Nothing here is saved except through FineRules (fines, debts, the arrest
-- record); loot never saves until it's deposited.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local BarnRules = require(Shared.BarnRules)
local Crime = require(Shared.Config.Crime)
local CrimeRules = require(Shared.CrimeRules)
local Crops = require(Shared.Config.Crops)
local FineRules = require(Shared.FineRules)
local PlotLayout = require(Shared.PlotLayout)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local SackRules = require(Shared.SackRules)
local Settings = require(Shared.Config.Settings)

local Server = ServerScriptService.Server
local ActionRemote = require(Server.Util.ActionRemote)
local Analytics = require(Server.Util.Analytics)
local Notice = require(Server.Util.Notice)
local CrimeArt = require(Server.World.CrimeArt)
local DataService = require(script.Parent.DataService)
local FieldService = require(script.Parent.FieldService)
local MarketService = require(script.Parent.MarketService)
local MovementService = require(script.Parent.MovementService)
local PlotService = require(script.Parent.PlotService)
local TravelService = require(script.Parent.TravelService)

local CrimeEvent = Remotes.event("CrimeEvent")

local CrimeService = {}

local TICK = 0.25
local BUSTED_SECONDS = 2.5 -- the mugshot card, before the police porch

local states = {} -- [Player] = state (below)
local ledgers = {} -- ["ownerId"] = raid ledger (shared/CrimeRules.raidAdd)
local leaving = {} -- [Player] = true once they're leaving the game
local mugNumber = 41 -- (the number board on the mugshot)

local function now(): number
	return workspace:GetServerTimeNow()
end

-- A player's raid state: their visits to other farms, sack, the hold or
-- climb under way, cooldowns, the owner's last swing.
local function stateOf(player: Player)
	local state = states[player]
	if not state then
		state = {
			visits = {}, -- [plot] = shared/CrimeRules visit
			sack = SackRules.new(),
			farm = 0, -- the farm they were in at the last tick
			hold = nil, -- { plot, tile, key, crop, ownerId, startedAt, seconds }
			climb = nil, -- { plot, direction, token }
			arrest = nil, -- { target, startedAt } (an owner arresting)
			cooldowns = {}, -- ["ownerId"] = server time they may steal there again
			alarms = {}, -- ["ownerId"] = when that owner was last alarmed about them
			lastSwingAt = -math.huge,
			ko = nil, -- { plot, token, loot, charge, by, leave }
			koToken = 0,
		}
		states[player] = state
	end
	return state
end

local function visitOf(state, plot: number)
	local visit = state.visits[plot]
	if not visit then
		visit = CrimeRules.newVisit()
		state.visits[plot] = visit
	end
	return visit
end

local function ledgerOf(ownerId: number)
	local key = tostring(ownerId)
	ledgers[key] = ledgers[key] or {}
	return ledgers[key]
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function carrying(state): boolean
	return not SackRules.isEmpty(state.sack)
end

local function isKnockedOut(state, t: number): boolean
	return state.ko ~= nil and CrimeRules.isKnockedOut(state.visits[state.ko.plot] or CrimeRules.newVisit(), t)
end

local function tilePart(plot: number, tile: number): BasePart?
	local field = PlotService.model(plot):FindFirstChild("Field")
	return field and field:FindFirstChild(`Tile{tile}`)
end

local function priceOf(cropId: string): number
	return MarketService.price(cropId)
end

local function owners(): { [number]: Player }
	local byId = {}
	for owner in PlotService.owners() do
		byId[owner.UserId] = owner
	end
	return byId
end

------------------------------------------------------------------------
-- The sack

local function showSack(player: Player, state)
	local weight = SackRules.weight(state.sack)
	player:SetAttribute("Sack", weight)
	local last = state.sack.items[#state.sack.items]
	player:SetAttribute("SackCrop", last and last.crop or nil)
	-- with a sack you only walk, slower (shared/SackRules; the client sets the speed)
	MovementService.SetScale(player, if weight > 0 then Settings.WALK_SPEED * Crime.SACK_SPEED / Settings.RUN_SPEED else nil)
	if player.Character then
		CrimeArt.showSack(player.Character, weight, last and last.crop)
	end
end

-- Loot goes back: each crop to its own farm's owner if they're here, else
-- to the owner who stopped the thief (stopper). Out of the raid ledger too.
local function returnLoot(player: Player, state, stopper: Player?)
	if not carrying(state) then
		return
	end
	local here = owners()
	local items = SackRules.takeAll(state.sack)
	local back = SackRules.returns(items, function(id)
		return here[id] ~= nil and DataService.Get(here[id]) ~= nil
	end, stopper and stopper.UserId)
	for key, list in back do
		local owner = here[tonumber(key) :: number]
		local data = owner and DataService.Get(owner)
		if data then
			for _, item in list do
				BarnRules.addCrops(data.inventory, item.key, 1) -- (returns always fit, §4.5)
				if item.entry and item.ownerId == owner.UserId then
					CrimeRules.raidRemove(ledgerOf(owner.UserId), item.entry)
				end
			end
			Notice.send(owner, `Recovered from {player.DisplayName}: {SackRules.summary(list)}. It's back in your barn.`, "Good")
			DataService.NotifyState(owner)
		end
	end
	if not leaving[player] then
		showSack(player, state)
	end
end

------------------------------------------------------------------------
-- Holds, climbs and Suspects

local function clearTile(plot: number, tile: number)
	local part = tilePart(plot, tile)
	if part then
		CollectionService:RemoveTag(part, "Stealing")
		part:SetAttribute("StealBy", nil)
		part:SetAttribute("StealStart", nil)
		part:SetAttribute("StealEnds", nil)
	end
end

local function cancelHold(state)
	local hold = state.hold
	if hold then
		state.hold = nil
		clearTile(hold.plot, hold.tile)
	end
end

-- The farm they count as a Suspect of: the one they're in, else the most
-- recent one they still are (60 s after the last suspicious act), else 0.
local function suspectOf(player: Player, state, t: number): number
	if state.farm > 0 and PlotService.plotOf(player) ~= state.farm then
		local visit = state.visits[state.farm]
		if visit and CrimeRules.isSuspect(visit, t, carrying(state)) then
			return state.farm
		end
	end
	local best, latest = 0, -math.huge
	for plot, visit in state.visits do
		if CrimeRules.isSuspect(visit, t) and visit.lastSuspectAt > latest then
			best, latest = plot, visit.lastSuspectAt
		end
	end
	return best
end

-- Tells an owner someone is stealing from them (at most every ALARM_GAP s
-- per thief), with the theft alarm card on their screen.
local function alarm(owner: Player, thief: Player, state, payload)
	local key = tostring(owner.UserId)
	local t = now()
	if t - (state.alarms[key] or -math.huge) < Crime.ALARM_GAP and not payload.force then
		return
	end
	state.alarms[key] = t
	payload.userId = thief.UserId
	payload.name = thief.DisplayName
	CrimeEvent:FireClient(owner, "Alarm", payload)
end

------------------------------------------------------------------------
-- Characters: knocked down, climbing, standing up

local function groundBelow(position: Vector3, character: Model): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position.Y else position.Y - 3
end

-- The server takes the character: anchored, its physics owned by the server,
-- so nothing the player's client does can move it.
local function holdCharacter(player: Player)
	local root = rootOf(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return nil
	end
	if not root.Anchored then
		pcall(root.SetNetworkOwner, root, nil)
	end
	root.Anchored = true
	return root, humanoid
end

local function release(player: Player)
	local root = rootOf(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	humanoid.PlatformStand = false
	MovementService.Allow(player)
	root.Anchored = false
	pcall(root.SetNetworkOwner, root, player)
end

-- Flat on their back on the ground (dizzy stars are drawn by the clients).
-- Returns the way they were facing, to stand them up the same way.
local function knockDown(player: Player): Vector3
	local root, humanoid = holdCharacter(player)
	if not root or not humanoid then
		return Vector3.new(0, 0, -1)
	end
	humanoid.PlatformStand = true
	humanoid:UnequipTools() -- (whatever was in their hand drops back into the backpack)
	local character = player.Character :: Model
	local floor = groundBelow(root.Position, character)
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude < 1e-3 then Vector3.new(0, 0, -1) else flat.Unit
	local at = Vector3.new(root.Position.X, floor + 0.75, root.Position.Z)
	-- (tipped over backwards: the head where their back was, face up)
	character:PivotTo(CFrame.lookAt(at, at + flat) * CFrame.Angles(math.rad(90), 0, 0))
	return flat
end

-- Back on their feet where they lie, facing the way they fell.
local function standUp(player: Player, facing: Vector3?)
	local root = rootOf(player)
	if not root then
		return
	end
	local character = player.Character :: Model
	local floor = groundBelow(root.Position, character)
	local at = Vector3.new(root.Position.X, floor + 3, root.Position.Z)
	character:PivotTo(CFrame.lookAt(at, at + (facing or Vector3.new(0, 0, -1))))
	release(player)
end

local function cancelClimb(player: Player, state)
	local climb = state.climb
	if not climb then
		return
	end
	state.climb = nil
	player:SetAttribute("Climbing", nil)
	-- (back down on the farm's side of the fence)
	local path = PlotLayout.climbPath(climb.x, climb.direction)
	local inside = if climb.direction == "In" then path[#path] else path[1]
	local character = player.Character
	if character then
		local frame = PlotLayout.frame(climb.plot)
		character:PivotTo(CFrame.lookAt(frame:PointToWorldSpace(inside), frame:PointToWorldSpace(inside - Vector3.new(0, 0, 1))))
	end
end

------------------------------------------------------------------------
-- Knockouts and arrests

local wake -- (below)

local function setKnockedOut(player: Player, ko, visit)
	player:SetAttribute("KnockedOut", if ko then visit.koUntil else nil)
	player:SetAttribute("KOSuspect", if ko then ko.suspect else nil)
	player:SetAttribute("KOPlot", if ko then ko.plot else nil)
	player:SetAttribute("ImmuneUntil", visit and visit.immuneUntil or nil)
end

-- A bat hit lands on `target` in `owner`'s farm.
local function knockOut(owner: Player, target: Player, plot: number)
	local t = now()
	local state = stateOf(target)
	local visit = visitOf(state, plot)
	local wasCarrying = carrying(state)
	-- what they had: the sack, and the crop they were halfway through taking
	local loot = SackRules.value(state.sack.items, priceOf)
	local taken = table.clone(state.sack.items)
	if state.hold then
		loot += priceOf(state.hold.crop)
		table.insert(taken, { crop = state.hold.crop })
	end
	cancelHold(state)
	cancelClimb(target, state)
	local suspect = CrimeRules.knockOut(visit, t, wasCarrying)
	state.koToken += 1
	state.ko = { plot = plot, token = state.koToken, loot = loot, charge = SackRules.summary(taken), by = owner.UserId, suspect = suspect }
	returnLoot(target, state, owner)
	TravelService.Cancel(target)
	state.ko.facing = knockDown(target)
	setKnockedOut(target, state.ko, visit)
	local root = rootOf(target)
	CrimeEvent:FireAllClients("Bonk", { userId = target.UserId, at = root and root.Position, suspect = suspect })
	Analytics.event(owner, "Knockout", if suspect then 1 else 0)
	local token = state.koToken
	task.delay(Crime.KO_SECONDS, function()
		wake(target, token)
	end)
end

-- The knockout's over (nobody arrested them): up again, 6 s immune, and off
-- the farm if they asked to leave.
function wake(player: Player, token: number)
	local state = states[player]
	if not state or not state.ko or state.ko.token ~= token or leaving[player] then
		return
	end
	local ko = state.ko
	state.ko = nil
	setKnockedOut(player, nil, state.visits[ko.plot])
	if ko.leave then
		release(player)
		local at = PlotLayout.visitWorld(ko.plot) + Vector3.new(0, 3, 0)
		MovementService.Teleport(player, CFrame.lookAt(at, at - PlotLayout.frame(ko.plot).ZVector)) -- (on the sidewalk, facing the road)
	else
		standUp(player, ko.facing)
	end
end

-- The Sheriff board and arrest XP skip staged arrests (§4.15): loot under 50
-- coins, or more than 3 of one thief by one owner in a UTC day.
local function countsForBoard(ownerData, thiefId: number, loot: number): boolean
	local day = os.time() // 86400
	local board = ownerData.crime.board
	if not board or board.day ~= day then
		board = { day = day, pairs = {} }
		ownerData.crime.board = board
	end
	local key = tostring(thiefId)
	if not CrimeRules.countsForBoard(loot, board.pairs[key] or 0) then
		return false
	end
	board.pairs[key] = (board.pairs[key] or 0) + 1
	return true
end

local function porchFrame(): CFrame
	local at = PlotLayout.policePorchWorld() + Vector3.new(0, 3, 0)
	return CFrame.lookAt(at, Vector3.new(0, at.Y, 0)) -- (facing the square)
end

-- Fines a thief and pays the owner what's collected (the rest is debt).
-- fled: they left the game (or died) to dodge it: ×1.5. Must not yield (it
-- runs as a save closes).
local function fine(thief: Player, owner: Player, loot: number, fled: boolean)
	local data = DataService.Get(thief)
	local ownerData = DataService.Get(owner)
	if not data then
		return nil
	end
	local before = data.coins
	local result = FineRules.arrest(data, owner.UserId, loot, os.time(), fled)
	data.coins = before -- (taken through AddCoins, for the leaderstats and the economy log)
	if result.owed > 0 then
		data.crime.debts[#data.crime.debts].ownerName = owner.DisplayName -- (for the police desk)
	end
	DataService.AddCoins(thief, -result.paid, Analytics.GAMEPLAY, "Fine")
	data.stats.timesArrested += 1
	if ownerData then
		ownerData.stats.arrestsMade += 1
		if result.paid > 0 then
			DataService.AddCoins(owner, result.paid, Analytics.GAMEPLAY, "FineReceived")
		end
		if countsForBoard(ownerData, thief.UserId, loot) then
			DataService.AddXp(owner, Crime.ARREST_XP)
		end
	end
	return result
end

local function arrest(owner: Player, target: Player, fled: boolean)
	local state = stateOf(target)
	local ko = state.ko
	local plot = (ko and ko.plot) or PlotService.plotOf(owner) or 0
	local loot = if ko then ko.loot else SackRules.value(state.sack.items, priceOf)
	local charge = if ko then ko.charge else SackRules.summary(state.sack.items)
	returnLoot(target, state, owner)
	local result = fine(target, owner, loot, fled)
	if not result then
		return
	end
	state.cooldowns[tostring(owner.UserId)] = now() + Crime.SAME_FARM_COOLDOWN -- (arrested there: §4.10)
	state.visits[plot] = nil
	cancelHold(state)
	Analytics.event(target, if fled then "FledArrest" else "Arrest", result.fine)
	local what = if charge ~= "" then `Crop theft: {charge}` else "Trespassing to steal"
	local owed = if result.owed > 0 then ` ({result.owed} more as they pay off the debt)` else ""
	if fled then
		Notice.send(owner, `🚔 {target.DisplayName} fled arrest! Fined {result.fine} (×1.5): +{result.paid} coins{owed}.`, "Good")
		return
	end
	state.ko = nil
	state.koToken += 1
	state.busted = true -- (on their way to the police: nobody can bonk them again)
	mugNumber += 1
	local root = rootOf(target)
	CrimeEvent:FireAllClients("Puff", { at = root and root.Position, userId = target.UserId })
	CrimeEvent:FireClient(target, "Busted", { name = target.DisplayName, charge = what, fine = result.fine, paid = result.paid,
		owed = result.owed, owner = owner.DisplayName, number = mugNumber })
	CrimeEvent:FireClient(owner, "Arrested", { name = target.DisplayName, fine = result.fine, paid = result.paid, owed = result.owed })
	task.delay(BUSTED_SECONDS, function()
		state.busted = nil
		local data = DataService.Get(target)
		if target.Parent ~= Players or leaving[target] or not data then
			return
		end
		setKnockedOut(target, nil, nil)
		release(target)
		MovementService.Teleport(target, porchFrame())
		local debt = FineRules.totalDebt(data.crime, os.time())
		Notice.send(target, if debt > 0
			then `You owe {debt} coins. Half of your sales pay it off; or pay at the police desk here.`
			else `Fine paid. You can't steal from {owner.DisplayName}'s farm for 3 minutes.`)
	end)
end

------------------------------------------------------------------------
-- Entering and leaving farms

local function onEnter(player: Player, state, plot: number, t: number)
	if plot == 0 or PlotService.plotOf(player) == plot then
		return
	end
	local visit = visitOf(state, plot)
	CrimeRules.enter(visit, t)
	if carrying(state) then
		-- caught with stolen goods counts (§4.12): the owner sees a Suspect
		local owner = PlotService.ownerOf(plot)
		if owner then
			alarm(owner, player, state, { carrying = SackRules.summary(state.sack.items), plot = plot })
		end
	end
end

local function onExit(player: Player, state, plot: number, t: number)
	if plot == 0 or PlotService.plotOf(player) == plot then
		return
	end
	local visit = state.visits[plot]
	if visit then
		CrimeRules.exit(visit)
	end
	cancelHold(state)
	local owner = PlotService.ownerOf(plot)
	if owner and SackRules.hasFrom(state.sack, owner.UserId) then
		state.cooldowns[tostring(owner.UserId)] = t + Crime.SAME_FARM_COOLDOWN
		local mine = {}
		for _, item in state.sack.items do
			if item.ownerId == owner.UserId then
				table.insert(mine, item)
			end
		end
		Notice.send(player, "Safe! Now get home and your sack empties into your barn.", "Good")
		Notice.send(owner, `{player.DisplayName} got away with {SackRules.summary(mine)}. Harvest ripe crops fast, and bonk thieves with your bat!`, "Error")
	end
end

-- The bat is yours only while you're inside your own farm (§4.12).
local function updateBat(player: Player, state)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local home = PlotService.plotOf(player)
	local want = home ~= nil and state.farm == home and humanoid ~= nil and humanoid.Health > 0
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = state.bat
	if want and not (tool and tool.Parent) and backpack then
		tool = CrimeArt.bat()
		tool.Parent = backpack
		state.bat = tool
	elseif not want and tool then
		tool:Destroy()
		state.bat = nil
	end
end

-- Emptying the sack at your own farmhouse door.
local function deposit(player: Player, state)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local items = SackRules.takeAll(state.sack)
	for _, item in items do
		BarnRules.addCrops(data.inventory, item.key, 1) -- (always fits, §4.5)
	end
	data.stats.stolenValue += SackRules.value(items, priceOf)
	showSack(player, state)
	DataService.NotifyState(player)
	CrimeEvent:FireClient(player, "Deposited", { text = `+{SackRules.summary(items)} (stolen) in your barn` })
	Analytics.event(player, "StealDeposited", #items)
end

local function tick()
	local t = now()
	for _, player in Players:GetPlayers() do
		local state = states[player]
		if not state or leaving[player] then
			continue
		end
		local farm = PlotService.inFarm(player)
		if farm ~= state.farm then
			local was = state.farm
			state.farm = farm
			onExit(player, state, was, t)
			onEnter(player, state, farm, t)
		end
		updateBat(player, state)
		-- a hold stops if they walk out of reach
		local hold = state.hold
		if hold then
			local position = MovementService.positionOf(player)
			local centre = PlotLayout.tileWorld(hold.plot, hold.tile)
			if not position or Vector2.new(position.X - centre.X, position.Z - centre.Z).Magnitude > FieldService.REACH + 2 then
				cancelHold(state)
			end
		end
		-- home with loot: into the barn
		local home = PlotService.plotOf(player)
		if carrying(state) and home and farm == home then
			local position = MovementService.positionOf(player)
			if position and (position - PlotLayout.spawnWorld(home)).Magnitude <= Crime.DEPOSIT_RANGE + 3 then
				deposit(player, state)
			end
		end
		local suspect = suspectOf(player, state, t)
		if (player:GetAttribute("SuspectOf") or 0) ~= suspect then
			player:SetAttribute("SuspectOf", suspect)
		end
	end
end

------------------------------------------------------------------------
-- Actions

local actions = {}

local function parseTile(arg: string?): number?
	local tile = tonumber(arg)
	if tile and tile == math.floor(tile) and tile >= 1 and tile <= 64 then
		return tile
	end
	return nil
end

-- tile: start a steal hold on that tile of the farm you're in.
function actions.Steal(player, _data, arg)
	local t = now()
	local state = stateOf(player)
	local tile = parseTile(arg)
	local plot = PlotService.inFarm(player)
	local owner = plot > 0 and PlotService.ownerOf(plot)
	if not tile or not owner then
		return "NotInside"
	elseif owner == player then
		return "YourOwn"
	elseif state.hold or state.climb or (player:GetAttribute("Climbing") or 0) > 0 then
		return "Holding"
	end
	local ownerData = DataService.Get(owner)
	if not ownerData then
		return "NotLoaded"
	end
	local position = MovementService.positionOf(player)
	local centre = PlotLayout.tileWorld(plot, tile)
	if not position or Vector2.new(position.X - centre.X, position.Z - centre.Z).Magnitude > FieldService.REACH then
		return "TooFar"
	end
	local cropId = FieldService.RipeCrop(owner, ownerData, tostring(tile))
	local rarity = if cropId then Crops.ById[cropId].rarity else "Common"
	local ok, why = CrimeRules.canSteal({
		now = t, inside = true, knockedOut = isKnockedOut(state, t),
		thiefProtected = false, farmProtected = false, trusted = false, -- (the Sprout Shield, arrival grace and Trusted list come in week 6)
		cooldownUntil = state.cooldowns[tostring(owner.UserId)], ripe = cropId ~= nil, rarity = rarity,
		sackUsed = SackRules.weight(state.sack), raidUsed = CrimeRules.raidUsed(ledgerOf(owner.UserId), t),
	})
	if not ok then
		return if why == "Cooldown" then "FarmCooldown" else why
	end
	local seconds = CrimeRules.stealHold(rarity)
	state.hold = { plot = plot, tile = tile, key = tostring(tile), crop = cropId, ownerId = owner.UserId, startedAt = t, seconds = seconds }
	CrimeRules.markSuspect(visitOf(state, plot), t)
	player:SetAttribute("SuspectOf", plot)
	local part = tilePart(plot, tile)
	if part then
		part:SetAttribute("StealBy", player.UserId)
		part:SetAttribute("StealStart", t)
		part:SetAttribute("StealEnds", t + seconds)
		CollectionService:AddTag(part, "Stealing")
	end
	TravelService.Cancel(player) -- (a Home channel under way stops: §4.11)
	alarm(owner, player, state, { crop = cropId, plot = plot, tile = tile, ends = t + seconds })
	Analytics.event(player, "StealStarted", Rarities.ById[rarity].order)
	return nil, { seconds = seconds, crop = cropId }
end

function actions.StealDone(player, _data, _arg)
	local t = now()
	local state = stateOf(player)
	local hold = state.hold
	if not hold then
		return "NoHold"
	elseif not CrimeRules.holdDone(hold.startedAt, t, hold.seconds) then
		return "TooSoon"
	end
	cancelHold(state)
	local owner = PlotService.ownerOf(hold.plot)
	local ownerData = owner and DataService.Get(owner)
	if not owner or owner.UserId ~= hold.ownerId or not ownerData then
		return "FarmClosed"
	elseif PlotService.inFarm(player) ~= hold.plot then
		return "NotInside"
	elseif isKnockedOut(state, t) then
		return "KnockedOut"
	end
	local position = MovementService.positionOf(player)
	local centre = PlotLayout.tileWorld(hold.plot, hold.tile)
	if not position or Vector2.new(position.X - centre.X, position.Z - centre.Z).Magnitude > FieldService.REACH + 2 then
		return "TooFar"
	end
	-- (the owner, a friend or a Farmhand may have picked it first: §4.10)
	if FieldService.RipeCrop(owner, ownerData, hold.key) ~= hold.crop then
		return "Gone"
	elseif not SackRules.fits(state.sack, hold.crop) then
		return "SackFull"
	end
	local ledger = ledgerOf(owner.UserId)
	local weight = SackRules.weightOf(hold.crop)
	if CrimeRules.raidUsed(ledger, t) + weight > Crime.RAID_CAP_WEIGHT then
		return "RaidCap"
	end
	local cropId, key = FieldService.TakeRipe(owner, ownerData, hold.key)
	if not cropId then
		return "Gone"
	end
	SackRules.add(state.sack, cropId, key :: string, owner.UserId, CrimeRules.raidAdd(ledger, t, weight))
	showSack(player, state)
	DataService.NotifyState(owner)
	local crop = Crops.ById[cropId]
	Notice.send(owner, `😠 {player.DisplayName} stole your {crop.icon} {crop.name}!`, "Error")
	return nil, { crop = cropId, weight = SackRules.weight(state.sack) }
end

function actions.StealCancel(player, _data, _arg)
	cancelHold(stateOf(player))
	return nil
end

-- A swing of the bat: the server picks who it hits (the nearest valid
-- target), so the client only says "swing".
function actions.Swing(player, _data, _arg)
	local t = now()
	local state = stateOf(player)
	local plot = PlotService.plotOf(player)
	local root = rootOf(player)
	local tool = state.bat
	local character = player.Character
	if not plot or not root or not tool or not character then
		Analytics.event(player, "HitRejected", 1)
		return "NoBat"
	end
	if tool.Parent ~= character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:EquipTool(tool) -- (the Swing button picks the bat up for you)
		end
	end
	local lastSwingAt = state.lastSwingAt
	if t - lastSwingAt < Crime.SWING_COOLDOWN then
		return "Cooldown"
	end
	state.lastSwingAt = t
	local from = MovementService.positionOf(player) or root.Position
	local facing = root.CFrame.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local best, bestDistance, nudged = nil, math.huge, nil
	for _, other in Players:GetPlayers() do
		if other == player or leaving[other] or (states[other] and states[other].busted) then
			continue
		end
		local at = MovementService.positionOf(other)
		local otherRoot = rootOf(other)
		if not at or not otherRoot then
			continue
		end
		local inside = PlotService.inFarm(other) == plot
		local distance = (at - from).Magnitude
		local otherState = stateOf(other)
		local visit = otherState.visits[plot]
		if inside and visit and distance <= Crime.SWING_NEAR + 4 then
			CrimeRules.swungAt(visit, t) -- (missing counts too: the chase rule)
		end
		params.FilterDescendantsInstances = { character, other.Character }
		local hit = workspace:Raycast(from + Vector3.new(0, 1.5, 0), (at + Vector3.new(0, 1, 0)) - (from + Vector3.new(0, 1.5, 0)), params)
		local ok, why = CrimeRules.validHit({
			now = t, lastSwingAt = lastSwingAt, attackerIsOwner = true, attackerInside = PlotService.inFarm(player) == plot,
			targetInside = inside, distance = distance, angle = CrimeRules.angleTo(facing, from, at), lineClear = hit == nil,
			targetTrusted = false, targetImmune = visit ~= nil and CrimeRules.isImmune(visit, t),
		})
		if ok and distance < bestDistance then
			best, bestDistance = other, distance
		elseif why == "Immune" and distance <= Crime.HIT_RANGE + Crime.HIT_LAG then
			nudged = other
		end
	end
	if best then
		knockOut(player, best, plot)
		return nil, { hit = best.UserId }
	elseif nudged then
		local nudgedRoot = rootOf(nudged)
		CrimeEvent:FireAllClients("Nudge", { at = nudgedRoot and nudgedRoot.Position })
	end
	return nil, { hit = 0 }
end

local function arrestTarget(player: Player, arg: string?): (Player?, string?)
	local target = Players:GetPlayerByUserId(tonumber(arg) or 0)
	local plot = PlotService.plotOf(player)
	if not target or target == player or not plot then
		return nil, "BadRequest"
	end
	local state = states[target]
	local visit = state and state.ko and state.ko.plot == plot and state.visits[plot]
	if not visit then
		return nil, "NotKnockedOut"
	end
	local from, at = MovementService.positionOf(player), MovementService.positionOf(target)
	local ok, why = CrimeRules.canArrest(visit, now(), {
		distance = if from and at then (at - from).Magnitude else math.huge,
		ownerInside = PlotService.inFarm(player) == plot,
	})
	if not ok then
		return nil, why
	end
	return target, nil
end

-- userId: start holding Arrest on a knocked-out Suspect.
function actions.ArrestStart(player, _data, arg)
	local target, why = arrestTarget(player, arg)
	if not target then
		return why
	end
	stateOf(player).arrest = { target = target, startedAt = now() }
	return nil
end

function actions.Arrest(player, _data, arg)
	local state = stateOf(player)
	local pending = state.arrest
	local target, why = arrestTarget(player, arg)
	if not target then
		return why
	elseif not pending or pending.target ~= target or not CrimeRules.holdDone(pending.startedAt, now(), Crime.ARREST_HOLD) then
		return "TooSoon"
	end
	state.arrest = nil
	arrest(player, target, false)
	return nil
end

-- Over the back fence of the farm you're at, in or out (1.5 s, §4.10).
function actions.Climb(player, _data, _arg)
	local t = now()
	local state = stateOf(player)
	local position = MovementService.positionOf(player)
	if not position or state.climb or state.hold or isKnockedOut(state, t) or player:GetAttribute("KnockedOut") then
		return "Holding"
	end
	local plot, direction, x = nil, nil, 0
	for index = 1, PlotLayout.COUNT do
		local p = PlotLayout.frame(index):PointToObjectSpace(position)
		local d = PlotLayout.climbAt(p, Crime.CLIMB_REACH)
		if d then
			plot, direction, x = index, d, p.X
			break
		end
	end
	if not plot then
		return "TooFar"
	end
	local root = holdCharacter(player)
	if not root then
		return "NoCharacter"
	end
	TravelService.Cancel(player)
	local token = (state.climbToken or 0) + 1
	state.climbToken = token
	state.climb = { plot = plot, direction = direction, x = x, token = token }
	player:SetAttribute("Climbing", plot) -- (inside that farm for the whole climb, either way: §4.12)
	local owner = PlotService.ownerOf(plot)
	if direction == "In" and owner and owner ~= player then
		local visit = visitOf(state, plot)
		CrimeRules.enter(visit, t)
		CrimeRules.markSuspect(visit, t)
		player:SetAttribute("SuspectOf", plot)
		alarm(owner, player, state, { climbing = true, plot = plot, force = true })
	end
	local frame = PlotLayout.frame(plot)
	local path = PlotLayout.climbPath(x, direction)
	local facing = if direction == "In" then -frame.ZVector else frame.ZVector
	local character = player.Character :: Model
	task.spawn(function()
		-- up, over and down along the path, a few steps a frame (the server
		-- holds the character, so everyone sees the same climb)
		local legs = #path - 1
		local per = Crime.FENCE_CLIMB / legs
		for i = 1, legs do
			local a, b = frame:PointToWorldSpace(path[i]), frame:PointToWorldSpace(path[i + 1])
			local started = os.clock()
			while os.clock() - started < per do
				if state.climb == nil or state.climb.token ~= token or character.Parent == nil then
					return -- (knocked off the fence, or gone)
				end
				local at = a:Lerp(b, math.clamp((os.clock() - started) / per, 0, 1))
				character:PivotTo(CFrame.lookAt(at, at + facing))
				task.wait()
			end
		end
		if state.climb and state.climb.token == token then
			state.climb = nil
			local landing = frame:PointToWorldSpace(path[#path])
			character:PivotTo(CFrame.lookAt(landing, landing + facing))
			player:SetAttribute("Climbing", nil)
			release(player)
		end
	end)
	return nil, { seconds = Crime.FENCE_CLIMB, direction = direction }
end

-- The Leave farm button (knocked out, not a Suspect): you wake up outside.
function actions.LeaveFarm(player, _data, _arg)
	local state = stateOf(player)
	if not state.ko or state.ko.suspect then
		return "NotAllowed"
	end
	state.ko.leave = true
	return nil
end

------------------------------------------------------------------------
-- Leaving the game, dying, a farm closing

-- Runs as a player's save closes (DataService.BeforeRelease): an automatic
-- arrest for fleeing one, the loot back either way. Must not yield.
local function beforeRelease(player: Player, _data, shuttingDown: boolean)
	local state = states[player]
	leaving[player] = true
	if not state then
		return
	end
	cancelHold(state)
	local t = now()
	local plot = (state.ko and state.ko.plot) or (player:GetAttribute("Climbing") or 0)
	if plot == 0 then
		plot = state.farm
	end
	local owner = plot > 0 and PlotService.ownerOf(plot) or nil
	local visit = (plot > 0 and state.visits[plot]) or CrimeRules.newVisit()
	local ownerDistance = nil
	if owner and owner ~= player then
		local a, b = MovementService.positionOf(owner), MovementService.positionOf(player)
		ownerDistance = if a and b then (a - b).Magnitude else nil
	end
	local outcome = CrimeRules.leaveOutcome(visit, t, { carrying = carrying(state), ownerDistance = ownerDistance, shuttingDown = shuttingDown })
	if (outcome == "Fled" or outcome == "Chased") and owner and owner ~= player then
		arrest(owner, player, true)
	elseif outcome ~= "None" then
		returnLoot(player, state, nil)
	end
end

-- Dying (or being removed) while knocked out as a Suspect is an automatic
-- arrest; with loot, the loot goes back.
local function onDied(player: Player)
	local state = states[player]
	if not state or leaving[player] or player.Parent ~= Players then
		return
	end
	cancelHold(state)
	state.climb = nil
	player:SetAttribute("Climbing", nil)
	local t = now()
	local plot = state.ko and state.ko.plot or state.farm
	local visit = (plot > 0 and state.visits[plot]) or CrimeRules.newVisit()
	local outcome = CrimeRules.deathOutcome(visit, t, carrying(state))
	local owner = plot > 0 and PlotService.ownerOf(plot) or nil
	if outcome == "Fled" and owner and owner ~= player then
		arrest(owner, player, true)
		Notice.send(player, "You fled arrest: fined ×1.5.", "Error")
	elseif outcome == "ReturnLoot" then
		returnLoot(player, state, owner)
	end
	state.ko = nil
	state.koToken += 1
	setKnockedOut(player, nil, nil)
end

-- An owner left: their farm closes. Anyone in it goes out to the sidewalk,
-- holds stop, knockouts there end and its Suspect marks clear (§4.1).
local function farmClosed(ownerPlayer: Player, plot: number)
	ledgers[tostring(ownerPlayer.UserId)] = nil
	for other, state in states do
		if other == ownerPlayer or leaving[other] then
			continue
		end
		if state.hold and state.hold.plot == plot then
			cancelHold(state)
		end
		local inside = state.farm == plot or (other:GetAttribute("Climbing") or 0) == plot or (state.ko and state.ko.plot == plot)
		if state.climb and state.climb.plot == plot then
			state.climb = nil
			other:SetAttribute("Climbing", nil)
		end
		if state.ko and state.ko.plot == plot then
			state.ko = nil
			state.koToken += 1
			setKnockedOut(other, nil, nil)
		end
		state.visits[plot] = nil
		if inside then
			release(other)
			local at = PlotLayout.visitWorld(plot) + Vector3.new(0, 3, 0)
			MovementService.Teleport(other, CFrame.lookAt(at, at - PlotLayout.frame(plot).ZVector))
			Notice.send(other, "This farm just closed: its owner left.")
		end
	end
end

------------------------------------------------------------------------

-- { suspect, knockedOut, carrying } for the travel buttons.
function CrimeService.Status(player: Player)
	local state = states[player]
	if not state then
		return { suspect = false, knockedOut = false, carrying = false }
	end
	local t = now()
	return {
		suspect = suspectOf(player, state, t) > 0,
		knockedOut = isKnockedOut(state, t) or state.climb ~= nil,
		carrying = carrying(state),
	}
end

-- Dev commands (/ko, /suspect, /sack, /crimelog).
function CrimeService.DevKnockOut(player: Player, suspect: boolean)
	local plot = PlotService.inFarm(player)
	if plot == 0 then
		plot = PlotService.plotOf(player) or 1
	end
	local state = stateOf(player)
	if suspect then
		CrimeRules.markSuspect(visitOf(state, plot), now())
	end
	knockOut(player, player, plot)
end

function CrimeService.DevSuspect(player: Player): number
	local plot = PlotService.inFarm(player)
	if plot > 0 then
		CrimeRules.markSuspect(visitOf(stateOf(player), plot), now())
	end
	return plot
end

function CrimeService.DevFillSack(player: Player, cropId: string, count: number, ownerId: number)
	local state = stateOf(player)
	for _ = 1, count do
		if not SackRules.fits(state.sack, cropId) then
			break
		end
		SackRules.add(state.sack, cropId, BarnRules.key(cropId), ownerId)
	end
	showSack(player, state)
end

function CrimeService.DevLog(player: Player): string
	local state = stateOf(player)
	local data = DataService.Get(player)
	local t = now()
	local lines = { `[crimelog] {player.Name}: farm {state.farm}, SuspectOf {player:GetAttribute("SuspectOf") or 0}, sack {SackRules.weight(state.sack)} ({SackRules.summary(state.sack.items)})` }
	for plot, visit in state.visits do
		table.insert(lines, `  visit farm {plot}: inside {visit.inside}, suspect {CrimeRules.isSuspect(visit, t)}, KO {CrimeRules.isKnockedOut(visit, t)}, immune {CrimeRules.isImmune(visit, t)}`)
	end
	for key, untilAt in state.cooldowns do
		table.insert(lines, `  cooldown on owner {key}: {math.max(0, math.ceil(untilAt - t))} s`)
	end
	if data then
		local crime = data.crime
		table.insert(lines, `  coins {data.coins}, debts {FineRules.totalDebt(crime, os.time())} ({#crime.debts}), arrests in 30 min {FineRules.priorArrests(crime, os.time())}, last-hour earnings {FineRules.lastHour(crime, os.time())}, lastArrestAt {crime.lastArrestAt}, fled {crime.fled}`)
	end
	local home = PlotService.plotOf(player)
	if home then
		table.insert(lines, `  your farm's raid ledger: {CrimeRules.raidUsed(ledgerOf(player.UserId), t)} of {Crime.RAID_CAP_WEIGHT} weight in 10 min`)
	end
	return table.concat(lines, "\n")
end

function CrimeService.Start()
	ActionRemote(Remotes.func("CrimeAction"), actions, DataService, 0.1)
	TravelService.status = CrimeService.Status

	-- After an arrest (or fleeing one) you start on the police porch for 2
	-- minutes, even after rejoining (§4.12).
	PlotService.spawnOverride = function(player: Player)
		local data = DataService.Get(player)
		if data and CrimeRules.startsOnPorch(data.crime, os.time()) then
			return porchFrame()
		end
		return nil
	end

	local function track(player: Player)
		stateOf(player)
		player.CharacterAdded:Connect(function(character)
			local state = stateOf(player)
			state.bat = nil
			state.farm = 0
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid then
				humanoid.Died:Connect(function()
					onDied(player)
				end)
			end
			task.defer(showSack, player, state)
		end)
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end

	-- Coming back soon after fleeing an arrest: say why you're at the police.
	DataService.OnLoaded(function(player, data)
		if data.crime.fled and CrimeRules.startsOnPorch(data.crime, os.time()) then
			task.delay(4, function()
				Notice.send(player, "You fled arrest last time, so you were fined ×1.5 and start at the police station.", "Error")
			end)
		end
		data.crime.fled = false
	end)

	DataService.BeforeRelease(beforeRelease)
	PlotService.OnReleased(farmClosed)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			states[player] = nil
			leaving[player] = nil
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(tick)
			if not ok then
				warn(`[CrimeService] {err}`)
			end
		end
	end)
end

return CrimeService
