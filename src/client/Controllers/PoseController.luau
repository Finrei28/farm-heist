-- How characters hold things (docs/ArtDirection.md §9), drawn by each client
-- for every character (the server only puts the things there). R15 only:
-- an R6 character keeps Roblox's own animations. Both are IKControls (the
-- Animator applies them after its animations, so walking legs keep going):
--   * Something carried (a stolen crop held up over the head: CarriedCrop,
--     World/CrimeArt; a crate in the arms: CarriedCrate, World/YardArt):
--     each hand on the LeftHold / RightHold attachment on its sides, the
--     elbows out.
--   * The bat (a Tool named Bat in the right hand): the right hand follows
--     a target this moves each frame. At rest the bat leans back over the
--     right shoulder; a swing (PoseController.swing for your own, at once;
--     the character's SwingAt for everyone else's) lifts it back behind the
--     head, brings it round in front and down across to the left, and back.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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
local SHOULDER = Vector3.new(1, 0.56, 0) -- (a standard R15 right shoulder, and its arm's reach)
local REACH = 2.3

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

------------------------------------------------------------------------

local rigs = {} -- [character] = { humanoid, torso, shoulder, reach, swingAt, holding, iks, bat = { ik, target, pole } }

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

-- Hands on something carried. Returns false while its hand spots haven't
-- arrived yet (it's tried again next frame).
local function hold(character: Model, rig, held: Instance): boolean
	local targets = {}
	for _, side in { "Left", "Right" } do
		local target = held:FindFirstChild(`{side}Hold`, true)
		if not target or not target:IsA("Attachment") then
			return false
		end
		targets[side] = target
	end
	rig.iks = {}
	for side, target in targets do
		local out = if side == "Left" then -1 else 1
		-- (an IKControl gives up near full stretch: lower the spot, on this
		-- screen, until this character's arm reaches it easily)
		local shoulder = Vector3.new(out * math.abs(rig.shoulder.X), rig.shoulder.Y, rig.shoulder.Z)
		for _ = 1, 40 do
			if (rig.torso.CFrame:PointToObjectSpace(target.WorldPosition) - shoulder).Magnitude <= rig.reach * 0.8 then
				break
			end
			target.Position -= Vector3.new(0, 0.05, 0)
		end
		local high = rig.torso.CFrame:PointToObjectSpace(target.WorldPosition).Y > 0.8 -- (over the head: elbows out wide; in front: out and back)
		local pole = newPole(rig, `{side}HoldPole`, if high then Vector3.new(out * 3, 1.2, -0.6) else Vector3.new(out * 2.4, -0.8, 0.8))
		table.insert(rig.iks, pole)
		local ik = armIK(rig, character, side, Enum.IKControlType.Position, target, pole)
		if ik then
			table.insert(rig.iks, ik)
		end
	end
	rig.holding = held
	return true
end

local function letGo(rig)
	for _, thing in rig.iks or {} do
		thing:Destroy()
	end
	rig.iks = nil
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
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(workspace) then
			letGo(rig)
			dropBat(rig)
			rigs[character] = nil
		end
	end)
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
		local held = character:FindFirstChild("CarriedCrop") or character:FindFirstChild("CarriedCrate")
		if held ~= rig.holding then
			letGo(rig)
			if held then
				hold(character, rig, held)
			end
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
end

return PoseController
