-- Keeps players' positions honest. A character's position is decided by the
-- player's own client (that's how Roblox physics works), so an exploit can
-- teleport, and anything the server checks by distance (stealing a crop,
-- taking a stolen crop home, a bat hit, an arrest, bidding in the Auction
-- House, trading face to face) could be cheated.
--
-- Every tick each player gets a movement allowance (a little faster than
-- sprinting), saved up to a small cap so lag bursts are fine, and spends it
-- on how far they really moved across the ground (rising is limited too;
-- falling isn't). A move the allowance can't cover sends them back to their
-- last good spot. That spot is their trusted position: every server check
-- uses MovementService.positionOf, so a teleport-and-act in one frame
-- doesn't work either.
--
-- Walls count too: a character's client decides what stops it, so a step
-- through a farm's fences, hedges or the store's walls is sent back the same
-- way (PlotLayout.wallCrossing), and so is hanging in the air over a farm,
-- out of reach of the bat (MoveRules.hovering).
--
-- The game's own teleports (Home, Town, Visit, the police porch, respawns)
-- happen on the server through MovementService.Teleport (or after
-- MovementService.Allow), so they never count as cheating. For a moment
-- after one the client may still say where it was, so a move from too far
-- off is ignored then. It's never trusted: the trusted position stays where
-- the server put them, and they have to walk from there. The Travel buttons'
-- rules are in shared/TravelRules.
--
-- Characters don't collide with each other (the "Players" group): pushing
-- is how an exploit flings people, and how anyone could block a doorway.
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DefenceRules = require(ReplicatedStorage.Shared.DefenceRules)
local MoveRules = require(ReplicatedStorage.Shared.MoveRules)
local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)

local Analytics = require(script.Parent.Parent.Util.Analytics)

local MovementService = {}

local TICK = 0.1
local GRACE = 2 -- seconds after a respawn or server teleport while the client catches up
local PLAYER_GROUP = "Players"

local tracked = {} -- [Player] = { trusted, low (the last spot not up in the air), budget (MoveRules), graceUntil, strikes, lastStrikeLog, scale? }

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- The last position that passed the check (nil before the character exists,
-- and once it's dead: a body lying where its client put it can't reach
-- anything).
function MovementService.positionOf(player: Player): Vector3?
	local state = tracked[player]
	if state and state.trusted then
		return state.trusted
	end
	local root = rootOf(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return if root and humanoid and humanoid.Health > 0 then root.Position else nil
end

-- The server is about to move this player (or just did): for a moment,
-- moves that don't add up are ignored, not punished.
function MovementService.Allow(player: Player, seconds: number?)
	local state = tracked[player]
	if state then
		state.graceUntil = math.max(state.graceUntil, os.clock() + (seconds or GRACE))
		MoveRules.refill(state.budget)
	end
end

-- A share of the usual movement allowance (1 = sprinting is fine): a thief
-- carrying a stolen crop on a farm can only walk, slower (CrimeService).
function MovementService.SetScale(player: Player, scale: number?)
	local state = tracked[player]
	if state then
		state.scale = scale
	end
end

-- Moves a player and trusts the new spot.
function MovementService.Teleport(player: Player, frame: CFrame)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart then
		humanoid.Sit = false
		task.wait(0.1) -- (let the seat weld go)
	end
	MovementService.Allow(player)
	character:PivotTo(frame)
	local state = tracked[player]
	if state then
		state.trusted, state.low = frame.Position, frame.Position
	end
end

local function strike(player: Player, state, distance: number)
	state.strikes += 1
	local now = os.clock()
	if now - (state.lastStrikeLog or 0) > 60 then
		state.lastStrikeLog = now
		Analytics.event(player, "MovementRejected", state.strikes)
		warn(`[MovementService] {player.Name} ({player.UserId}) moved {math.floor(distance)} studs too far; sent back ({state.strikes} so far)`)
	end
end

-- Whether a step goes through a farm's fences, hedges or the store's walls.
-- The staff door opens for the owner and their Trusted friends.
local function throughWall(player: Player, from: Vector3, to: Vector3): boolean
	local world = workspace:FindFirstChild("World")
	for index = 1, PlotLayout.COUNT do
		local model = world and world:FindFirstChild(`Plot{index}`)
		local crossing = PlotLayout.wallCrossing(index, from, to, model and model:GetAttribute("StoreStage"))
		if crossing == "Wall" then
			return true
		elseif crossing == "StaffDoor" and not (model and (model:GetAttribute("OwnerId") == player.UserId
			or DefenceRules.inTrustedText(model:GetAttribute("Trusted"), player.UserId))) then
			return true
		end
	end
	return false
end

local airParams = RaycastParams.new()
airParams.FilterType = Enum.RaycastFilterType.Exclude
airParams.RespectCanCollide = true

-- How high a character is above what's under it, over a farm (0 elsewhere,
-- or low enough not to matter: most ticks never cast a ray).
local function heightOverFarm(character: Model, position: Vector3): number
	if position.Y <= MoveRules.HOVER_HEIGHT or not PlotLayout.plotAt(position) then
		return 0
	end
	airParams.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(position, Vector3.new(0, -position.Y - 10, 0), airParams)
	return if hit then position.Y - hit.Position.Y else position.Y
end

local function check(player: Player, state, dt: number)
	local root = rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		state.trusted = nil
		return
	end
	local position = root.Position
	-- Just spawned, or held where they are by the server (a seat, anchored by
	-- a knockout or a climb): wherever they are is fine.
	if not state.trusted or humanoid.SeatPart or root.Anchored then
		state.trusted, state.low = position, position
		MoveRules.refill(state.budget)
		return
	end
	local offset = position - state.trusted
	-- Just moved by the server: the client may still say where it was.
	local settling = os.clock() < state.graceUntil
	if settling and not MoveRules.fits(state.budget, offset) then
		return
	end
	local ok, overBy = MoveRules.step(state.budget, offset, dt, state.scale)
	local walled = ok and throughWall(player, state.trusted, position)
	if ok and not walled then
		state.trusted = position
		local height = heightOverFarm(character, position)
		if height <= MoveRules.HOVER_HEIGHT then
			state.low = position
		end
		if MoveRules.hovering(state.budget, height, dt) and state.low then
			-- Hanging in the air: back down to where they left the ground.
			strike(player, state, height)
			state.trusted = state.low
			state.budget.air = 0
			character:PivotTo(CFrame.new(state.trusted) * root.CFrame.Rotation)
		end
		return
	end
	if settling then
		return
	end
	-- Too far, too fast, or through a wall: back to the last good spot.
	strike(player, state, if walled then offset.Magnitude else overBy)
	character:PivotTo(CFrame.new(state.trusted) * root.CFrame.Rotation)
end

-- Every part of a character is in the group that doesn't collide with itself.
local function joinGroup(part: Instance)
	if part:IsA("BasePart") then
		part.CollisionGroup = PLAYER_GROUP
	end
end

local function noPushing(character: Model)
	for _, part in character:GetDescendants() do
		joinGroup(part)
	end
	character.DescendantAdded:Connect(joinGroup)
end

function MovementService.Start()
	if not PhysicsService:IsCollisionGroupRegistered(PLAYER_GROUP) then
		PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	end
	PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, PLAYER_GROUP, false)

	local function track(player: Player)
		local state = { trusted = nil, low = nil, budget = MoveRules.new(), graceUntil = 0, strikes = 0 }
		tracked[player] = state
		player.CharacterAdded:Connect(function(character)
			state.trusted, state.low = nil, nil
			MovementService.Allow(player, GRACE + 2) -- (spawning, then being sent to your farm)
			noPushing(character)
		end)
		if player.Character then
			MovementService.Allow(player, GRACE + 2)
			noPushing(player.Character)
		end
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		tracked[player] = nil
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < TICK then
			return
		end
		local step = elapsed
		elapsed = 0
		for player, state in tracked do
			check(player, state, step)
		end
	end)
end

return MovementService
