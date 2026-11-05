-- How characters hold things (docs/ArtDirection.md §9), drawn by each client
-- for every character (the server only puts the things there). R15 only:
-- an R6 character keeps Roblox's own animations. Walking legs keep going under
-- all of them:
--   * Something carried (a stolen crop held up over the head: CarriedCrop,
--     World/CrimeArt): each hand on its side (the crop's LeftHold / RightHold,
--     spots in the torso's frame), palm in, the elbows out. The pose never
--     changes against the torso, so it's worked out once (shared/ArmPose) and
--     set on the arm's joints each frame, after the Animator.
--   * The bat (a Tool named Bat in the right hand): the right hand follows
--     a target this moves each frame. At rest the bat leans back over the
--     right shoulder; a swing (PoseController.swing for your own, at once;
--     the character's SwingAt for everyone else's) lifts it back behind the
--     head, brings it round in front and down across to the left, and back.
--   * The bidder paddle in the Auction House (BidderPaddle, AuctionService):
--     held up in front of the chest, the number facing out. A bid
--     (PoseController.raisePaddle for your own, at once; PaddleUp for
--     everyone else's) snaps it up over the head with a shake, holds it
--     there while the bid's called, and brings it down. Winning a lot
--     (Cheer) waves it overhead, the other arm up too.
-- The bat and the paddle are IKControls (the Animator applies them after its
-- animations).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ArmPose = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ArmPose"))
local Sfx = require(script.Parent.Parent.Sfx)

local PoseController = {}

-- Seconds from pressing Swing to the bat coming round in front: the hit
-- (CrimeController asks the server then).
PoseController.WIND_UP = 0.22

-- The bat's poses, in the upper torso's frame (X right, Y up, -Z forward)
-- for a standard-sized arm (scaled to each character's): where the right
-- hand is, which way the bat points from it, and which way the forearm
-- comes into the hand (the wrist bends: at the hit the bat runs on from an
-- arm swinging across from the right).
local REST = { hand = Vector3.new(0.75, 0, -0.85), bat = Vector3.new(0.15, 0.85, 0.55), arm = Vector3.new(0.2, -0.8, 0.5) } -- leaning back over the shoulder
-- (each pose turns the bat less than half a turn from the last: a turn
-- from pointing back to pointing forward goes up over the top)
local SWING = {
	{ t = 0, pose = REST },
	{ t = 0.12, pose = { hand = Vector3.new(1.0, 1.25, 0.1), bat = Vector3.new(-0.2, 0.4, 1), arm = Vector3.new(0.2, -1, -0.2) } }, -- wound up behind the head
	{ t = 0.17, pose = { hand = Vector3.new(0.75, 1.35, -0.7), bat = Vector3.new(-0.15, 1, -0.1), arm = Vector3.new(0.1, -0.6, 0.8) } }, -- coming over the top
	{ t = 0.22, pose = { hand = Vector3.new(0.3, 0.45, -1.8), bat = Vector3.new(-0.3, 0.05, -1), arm = Vector3.new(1, -0.2, 0.3) } }, -- the hit: level, out in front
	{ t = 0.34, pose = { hand = Vector3.new(-0.4, -0.4, -1.3), bat = Vector3.new(-0.7, -0.6, -0.4), arm = Vector3.new(0.8, 0.5, 0.3) } }, -- followed through, low on the left
	{ t = 0.5, pose = { hand = Vector3.new(0.5, -0.1, -1.1), bat = Vector3.new(0.2, 0.6, -0.75), arm = Vector3.new(0.5, -0.3, 0.8) } }, -- brought up in front
	{ t = 0.75, pose = REST },
}
local SWING_LENGTH = SWING[#SWING].t
local SEEN_AT = 0.1 -- (someone else's swing is seen from here: the server hears of it at the hit)

-- The bidder paddle's poses (as the bat's: the paddle points along `bat`;
-- the elbow out to the side turns the number to face forward).
-- (at rest it leans out beside the head, so the face and the number both show)
local PADDLE_REST = { hand = Vector3.new(1.0, -0.8, -0.6), bat = Vector3.new(0.45, 1, -0.15), arm = Vector3.new(0.6, -0.7, 0.4) }
local PADDLE_UP = { hand = Vector3.new(1.25, 1.7, 0.05), bat = Vector3.new(0.15, 1, 0), arm = Vector3.new(0.9, -0.6, 0.1) } -- (up beside the head, not across the face)
local RAISE_IN, RAISE_HOLD, RAISE_OUT = 0.14, 1.3, 0.35 -- seconds: up, held while the bid's called, down
local CHEER = 1.8 -- seconds of waving after winning a lot
local CHEER_LEFT = Vector3.new(-0.95, 1.65, -0.3) -- (the other hand, up)
local SHOULDER = Vector3.new(1, 0.56, 0) -- (a standard R15 right shoulder, and its arm's reach)
local REACH = 2.3
local HOLD_WRIST = 0.2 -- how far out from straight down the wrist comes into a hand on a carried crop
local HOLD_ELBOW = Vector3.new(3, 1.2, -0.6) -- which way a carrying elbow points (the right one; torso space)
local HOLD_IN = 0.2 -- seconds for the arms to go up

-- In Studio, a pose can be tried out from the command bar without a
-- restart: workspace:SetAttribute("Pose_rest_hand", Vector3.new(...)) (or
-- _bat, _arm), or Pose_2_bat for SWING[2]; Pose_slow = 10 plays swings ten
-- times slower.
local tuning = RunService:IsStudio()
local function tuned(pose, key: number | string, field: string): Vector3
	if tuning then
		local value = workspace:GetAttribute(`Pose_{key}_{field}`)
		if typeof(value) == "Vector3" then
			return value
		end
	end
	return pose[field]
end

local function smooth(x: number): number
	return x * x * (3 - 2 * x)
end

-- Where the hand is, which way the bat points and which way the forearm
-- comes in, `t` seconds into a swing (nil: resting).
local function batPose(t: number?): (Vector3, Vector3, Vector3)
	if not t or t >= SWING_LENGTH then
		return tuned(REST, "rest", "hand"), tuned(REST, "rest", "bat").Unit, tuned(REST, "rest", "arm").Unit
	end
	for i = 1, #SWING - 1 do
		local a, b = SWING[i], SWING[i + 1]
		if t <= b.t then
			local f = smooth((t - a.t) / (b.t - a.t))
			local ka, kb = if a.pose == REST then "rest" else i, if b.pose == REST then "rest" else i + 1
			local hand = tuned(a.pose, ka, "hand"):Lerp(tuned(b.pose, kb, "hand"), f)
			local bat = tuned(a.pose, ka, "bat").Unit:Lerp(tuned(b.pose, kb, "bat").Unit, f)
			local arm = tuned(a.pose, ka, "arm").Unit:Lerp(tuned(b.pose, kb, "arm").Unit, f)
			return hand, if bat.Magnitude > 1e-3 then bat.Unit else Vector3.new(0, 1, 0), arm
		end
	end
	return batPose(nil)
end

-- How far up the paddle is (0 held in front, 1 overhead) and how far it's
-- shaken to the side, at `clock`.
local function paddleLift(rig, clock: number): (number, number)
	local up, shake = 0, 0
	local slow = if tuning then workspace:GetAttribute("Pose_slow") or 1 else 1
	if rig.paddleUpAt then
		local t = (clock - rig.paddleUpAt) / slow
		if t < RAISE_IN then
			up = smooth(t / RAISE_IN)
		elseif t < RAISE_IN + RAISE_HOLD then
			up = 1
		elseif t < RAISE_IN + RAISE_HOLD + RAISE_OUT then
			up = 1 - smooth((t - RAISE_IN - RAISE_HOLD) / RAISE_OUT)
		else
			rig.paddleUpAt = nil
		end
		if t < RAISE_IN + 0.6 then -- (a shake as it goes up: "here!")
			shake = math.sin(t * 22) * 0.14 * (1 - t / (RAISE_IN + 0.6))
		end
	end
	if rig.cheerAt then
		local t = (clock - rig.cheerAt) / slow
		if t < CHEER then
			up = math.max(up, if t < 0.15 then smooth(t / 0.15) elseif t > CHEER - 0.3 then smooth((CHEER - t) / 0.3) else 1)
			shake = math.sin(t * 11) * 0.3
		else
			rig.cheerAt = nil
		end
	end
	return up, shake
end

------------------------------------------------------------------------

local rigs = {} -- [character] = { humanoid, torso, shoulder, reach, swingAt, holding, heldAt, arms = { { motor, pose } }, bat = { ik, target, pole }, paddle = { ik, target, pole, left? } }

-- An IKControl moving one arm's hand to `target`, the elbow toward `pole`.
local function armIK(rig, character: Model, side: string, kind: Enum.IKControlType, target: Attachment, pole: Attachment): IKControl?
	local upper = character:FindFirstChild(`{side}UpperArm`)
	local hand = character:FindFirstChild(`{side}Hand`)
	if not upper or not hand then
		return nil
	end
	local ik = Instance.new("IKControl")
	ik.Name = `{side}Pose`
	ik.Type = kind
	ik.ChainRoot = upper
	ik.EndEffector = hand
	ik.Target = target
	ik.Pole = pole
	ik.SmoothTime = 0
	ik.Weight = 0
	ik.Parent = rig.humanoid
	TweenService:Create(ik, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Weight = 1 }):Play()
	return ik
end

local function newPole(rig, name: string, position: Vector3): Attachment
	local pole = Instance.new("Attachment")
	pole.Name = name
	pole.Position = position
	pole.Parent = rig.torso
	return pole
end

-- Hands on something carried: each arm's pose, worked out here and held by
-- holdArms.
local function hold(character: Model, rig, held: Instance)
	rig.arms = {}
	for _, side in { "Left", "Right" } do
		local at = held:GetAttribute(`{side}Hold`)
		local upper = character:FindFirstChild(`{side}UpperArm`)
		local lower = character:FindFirstChild(`{side}LowerArm`)
		local hand = character:FindFirstChild(`{side}Hand`)
		local shoulder = upper and upper:FindFirstChild(`{side}Shoulder`)
		local elbow = lower and lower:FindFirstChild(`{side}Elbow`)
		local wrist = hand and hand:FindFirstChild(`{side}Wrist`)
		if typeof(at) == "Vector3" and shoulder and elbow and wrist then
			local out = if side == "Left" then -1 else 1
			local frame = CFrame.lookAt(at, at + Vector3.new(0, 0, 1), Vector3.new(out * HOLD_WRIST, -1, 0)) -- (the arm raised in front and on up: palm in)
			local a, b, c = ArmPose.solve(shoulder, elbow, wrist, frame, HOLD_ELBOW * Vector3.new(out, 1, 1))
			table.insert(rig.arms, { motor = shoulder, pose = a })
			table.insert(rig.arms, { motor = elbow, pose = b })
			table.insert(rig.arms, { motor = wrist, pose = c })
		end
	end
	rig.holding = held
	rig.heldAt = os.clock()
end

local function letGo(rig)
	rig.arms = nil
	rig.holding = nil
end

-- The bat in hand: a target the right hand follows (moved every frame).
local function takeBat(character: Model, rig)
	local target = Instance.new("Attachment")
	target.Name = "BatHand"
	target.Parent = rig.torso
	local pole = newPole(rig, "BatPole", Vector3.new(2, -1.5, 0.6)) -- (the elbow down, out and back)
	local ik = armIK(rig, character, "Right", Enum.IKControlType.Transform, target, pole)
	rig.bat = { ik = ik, target = target, pole = pole }
end

local function dropBat(rig)
	if rig.bat then
		for _, thing in { rig.bat.ik, rig.bat.target, rig.bat.pole } do
			if thing then
				thing:Destroy()
			end
		end
		rig.bat = nil
	end
	rig.swingAt = nil
end

-- The bidder paddle in hand: a spot the right hand goes to (where the hand
-- is only: an arm overhead can't turn its wrist far enough to point a
-- paddle up, so aimPaddle points the paddle itself from the fist).
local function takePaddle(character: Model, rig)
	local target = Instance.new("Attachment")
	target.Name = "PaddleHand"
	target.Parent = rig.torso
	local pole = newPole(rig, "PaddlePole", Vector3.new(2.6, -0.6, 0.2)) -- (the elbow out to the side)
	local ik = armIK(rig, character, "Right", Enum.IKControlType.Position, target, pole)
	rig.paddle = { ik = ik, target = target, pole = pole }
end

-- The paddle runs out of the fist along `dir` with its number facing
-- forward, however the wrist ended up turned: on this screen each of its
-- welds (the server's, to the hand) is hung from the upper torso instead,
-- at the spot the hand is sent to, each part at its Grip (the paddle's own
-- grip space: the handle along -Z, the disc's faces ±X). (Aiming it from
-- the hand read the hand a frame before its IK, so the paddle pointed out
-- in front; and the Grip is read each time, as a cache of the server's C0
-- keyed by the weld lost entries and piled offsets up.)
local function aimPaddle(character: Model, rig, at: Vector3, dir: Vector3)
	local paddle = character:FindFirstChild("BidderPaddle")
	if not paddle then
		return
	end
	local forward = Vector3.new(0, 0, -1) -- (torso space)
	local facing = forward - dir * forward:Dot(dir)
	if facing.Magnitude < 1e-3 then
		return
	end
	local z = -dir
	local x = facing.Unit
	local y = z:Cross(x)
	local grip = CFrame.fromMatrix(at, x, y, z)
	for _, part in paddle:GetChildren() do
		local weld = part:FindFirstChildOfClass("Weld")
		local base = part:GetAttribute("Grip")
		if weld and typeof(base) == "CFrame" then
			if weld.Part0 ~= rig.torso then
				weld.Part0 = rig.torso
			end
			weld.C0 = grip * base
		end
	end
end

-- The other arm up while cheering (made when the cheer starts, gone after).
local function cheerLeft(character: Model, rig, on: boolean)
	local paddle = rig.paddle
	if on and not paddle.left then
		local target = Instance.new("Attachment")
		target.Name = "CheerHand"
		target.Position = rig.shoulder * Vector3.new(-1, 1, 1) + (CHEER_LEFT - SHOULDER * Vector3.new(-1, 1, 1)) * (rig.reach / REACH)
		target.Parent = rig.torso
		local pole = newPole(rig, "CheerPole", Vector3.new(-2.6, 0.6, -0.2))
		paddle.left = { target = target, pole = pole, ik = armIK(rig, character, "Left", Enum.IKControlType.Position, target, pole) }
	elseif not on and paddle.left then
		for _, thing in { paddle.left.ik, paddle.left.target, paddle.left.pole } do
			if thing then
				thing:Destroy()
			end
		end
		paddle.left = nil
	end
end

local function dropPaddle(rig)
	if rig.paddle then
		if rig.paddle.left then
			for _, thing in { rig.paddle.left.ik, rig.paddle.left.target, rig.paddle.left.pole } do
				if thing then
					thing:Destroy()
				end
			end
		end
		for _, thing in { rig.paddle.ik, rig.paddle.target, rig.paddle.pole } do
			if thing then
				thing:Destroy()
			end
		end
		rig.paddle = nil
	end
end

-- Where the right hand goes (torso space) for a pose: scaled to this
-- character's arm, the hand turned so the bat runs along its -Z and its +Y
-- (toward the wrist) points the way the forearm comes in.
local function handFrame(rig, hand: Vector3, bat: Vector3, arm: Vector3): CFrame
	local at = rig.shoulder + (hand - SHOULDER) * (rig.reach / REACH)
	local up = arm - bat * arm:Dot(bat)
	if up.Magnitude < 1e-3 then
		up = Vector3.new(0, 1, 0)
	end
	return CFrame.lookAt(at, at + bat, up.Unit)
end

local function armLength(character: Model): (Vector3, number)
	local upper = character:FindFirstChild("RightUpperArm")
	local lower = character:FindFirstChild("RightLowerArm")
	local hand = character:FindFirstChild("RightHand")
	local shoulder = upper and upper:FindFirstChild("RightShoulder")
	local elbow = lower and lower:FindFirstChild("RightElbow")
	local wrist = hand and hand:FindFirstChild("RightWrist")
	if not (shoulder and elbow and wrist) then
		return SHOULDER, REACH
	end
	return shoulder.C0.Position,
		(shoulder.C1.Position - elbow.C0.Position).Magnitude + (elbow.C1.Position - wrist.C0.Position).Magnitude + wrist.C1.Position.Magnitude
end

local function track(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	character:WaitForChild("RightHand", 10)
	local torso = character:FindFirstChild("UpperTorso")
	if not torso then
		return
	end
	local shoulder, reach = armLength(character)
	local rig = { humanoid = humanoid, torso = torso, shoulder = shoulder, reach = reach, swingAt = nil, ownSwingAt = -math.huge }
	rigs[character] = rig
	character:GetAttributeChangedSignal("SwingAt"):Connect(function()
		if os.clock() - rig.ownSwingAt < 0.6 then
			return -- (your own swing: already playing)
		end
		rig.swingAt = os.clock() - SEEN_AT
		Sfx.play("Swing", torso)
	end)
	rig.ownPaddleAt = -math.huge
	character:GetAttributeChangedSignal("PaddleUp"):Connect(function()
		if os.clock() - rig.ownPaddleAt < 1 then
			return -- (your own bid: already up)
		end
		rig.paddleUpAt = os.clock()
	end)
	character:GetAttributeChangedSignal("Cheer"):Connect(function()
		rig.cheerAt = os.clock()
	end)
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(workspace) then
			letGo(rig)
			dropBat(rig)
			dropPaddle(rig)
			rigs[character] = nil
		end
	end)
end

-- Your own bid: your paddle goes up at once (the server tells everyone else).
function PoseController.raisePaddle(character: Model)
	local rig = rigs[character]
	if rig then
		rig.paddleUpAt = os.clock()
		rig.ownPaddleAt = os.clock()
	end
end

-- Your own swing, at once (the server tells everyone else).
function PoseController.swing(character: Model)
	local rig = rigs[character]
	if rig then
		rig.swingAt = os.clock()
		rig.ownSwingAt = os.clock()
		Sfx.play("Swing", rig.torso)
	end
end

-- (before the Animator runs: it solves the IKs against these targets)
local function step()
	local clock = os.clock()
	for character, rig in rigs do
		-- carrying: hands on it
		local held = character:FindFirstChild("CarriedCrop")
		if held ~= rig.holding then
			letGo(rig)
			if held then
				hold(character, rig, held)
			end
		end
		-- the bidder paddle: held in front, raised to bid, waved to cheer
		local paddle = character:FindFirstChild("BidderPaddle")
		if paddle and not held and not rig.humanoid.PlatformStand then
			if not rig.paddle then
				takePaddle(character, rig)
			end
			local up, shake = paddleLift(rig, clock)
			local rest, raised = PADDLE_REST, PADDLE_UP
			local hand = tuned(rest, "paddle_rest", "hand"):Lerp(tuned(raised, "paddle_up", "hand"), up) + Vector3.new(shake, 0, 0)
			local point = tuned(rest, "paddle_rest", "bat").Unit:Lerp(tuned(raised, "paddle_up", "bat").Unit, up) + Vector3.new(shake * 0.9, 0, 0)
			local arm = tuned(rest, "paddle_rest", "arm").Unit:Lerp(tuned(raised, "paddle_up", "arm").Unit, up)
			local frame = handFrame(rig, hand, point.Unit, arm.Unit)
			rig.paddle.target.CFrame = frame
			aimPaddle(character, rig, frame.Position, point.Unit)
			cheerLeft(character, rig, rig.cheerAt ~= nil)
			continue
		elseif rig.paddle then
			dropPaddle(rig)
		end
		-- the bat: over the shoulder, or swinging
		local tool = character:FindFirstChild("Bat")
		local armed = tool ~= nil and tool:IsA("Tool") and not held and not rig.humanoid.PlatformStand
		if not armed then
			if rig.bat then
				dropBat(rig)
			end
			continue
		end
		if not rig.bat then
			takeBat(character, rig)
		end
		local slow = if tuning then workspace:GetAttribute("Pose_slow") or 1 else 1
		local t = if rig.swingAt then (clock - rig.swingAt) / slow else nil
		if t and t >= SWING_LENGTH then
			rig.swingAt, t = nil, nil
		end
		local hand, bat, arm = batPose(t)
		rig.bat.target.CFrame = handFrame(rig, hand, bat, arm)
	end
end

-- (after the Animator: this frame's walk is under these already)
local function holdArms()
	local clock = os.clock()
	for _, rig in rigs do
		if rig.arms then
			local up = smooth(math.min(1, (clock - rig.heldAt) / HOLD_IN))
			for _, arm in rig.arms do
				arm.motor.Transform = if up < 1 then arm.motor.Transform:Lerp(arm.pose, up) else arm.pose
			end
		end
	end
end

function PoseController.Start()
	local function watch(other: Player)
		other.CharacterAdded:Connect(function(character)
			task.spawn(track, character)
		end)
		if other.Character then
			task.spawn(track, other.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, other in Players:GetPlayers() do
		watch(other)
	end
	RunService.PreAnimation:Connect(step)
	RunService.PreSimulation:Connect(holdArms)
end

return PoseController
