-- Keeps players' positions honest. A character's position is decided by the
-- player's own client (that's how Roblox physics works), so an exploit can
-- teleport, and anything the server checks by distance (stealing a crop,
-- emptying a sack at your barn, a bat hit, an arrest, bidding in the Auction
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
-- The game's own teleports (Home, Town, Visit, the police porch, respawns)
-- happen on the server through MovementService.Teleport (or after
-- MovementService.Allow), so they never count as cheating. The Travel
-- buttons' rules (3 s channel, cooldowns) are in shared/TravelRules.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MoveRules = require(ReplicatedStorage.Shared.MoveRules)

local Analytics = require(script.Parent.Parent.Util.Analytics)

local MovementService = {}

local TICK = 0.1
local GRACE = 2 -- seconds after a respawn or server teleport while the client catches up

local tracked = {} -- [Player] = { trusted, budget (MoveRules), graceUntil, strikes, lastStrikeLog, scale? }

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- The last position that passed the check (nil before the character exists).
function MovementService.positionOf(player: Player): Vector3?
	local state = tracked[player]
	if state and state.trusted then
		return state.trusted
	end
	local root = rootOf(player)
	return root and root.Position
end

-- The server is about to move this player (or just did): trust wherever
-- they end up for a moment.
function MovementService.Allow(player: Player, seconds: number?)
	local state = tracked[player]
	if state then
		state.graceUntil = math.max(state.graceUntil, os.clock() + (seconds or GRACE))
	end
end

-- A share of the usual movement allowance (1 = sprinting is fine): a thief
-- with a Loot Sack can only walk, slower (CrimeService).
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
		state.trusted = frame.Position
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

local function check(player: Player, state, dt: number)
	local root = rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		state.trusted = nil
		return
	end
	local position = root.Position
	-- Just spawned or teleported by the server, or sitting (a seat holds you
	-- in place), or anchored by a knockout: wherever they are is fine.
	if not state.trusted or os.clock() < state.graceUntil or humanoid.SeatPart or root.Anchored then
		state.trusted = position
		MoveRules.refill(state.budget)
		return
	end
	local ok, overBy = MoveRules.step(state.budget, position - state.trusted, dt, state.scale)
	if ok then
		state.trusted = position
		return
	end
	-- Too far, too fast: back to the last good spot.
	strike(player, state, overBy)
	character:PivotTo(CFrame.new(state.trusted) * root.CFrame.Rotation)
end

function MovementService.Start()
	local function track(player: Player)
		local state = { trusted = nil, budget = MoveRules.new(), graceUntil = 0, strikes = 0 }
		tracked[player] = state
		player.CharacterAdded:Connect(function()
			state.trusted = nil
			MovementService.Allow(player, GRACE + 2) -- (spawning, then being sent to your farm)
		end)
		if player.Character then
			MovementService.Allow(player, GRACE + 2)
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
