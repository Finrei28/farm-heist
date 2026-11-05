-- An arm's pose, worked out once. A crop held overhead is welded to the torso,
-- so a hand on it never moves against the torso and neither does the arm: this
-- gives the three Motor6D.Transforms that put the hand there, and client
-- PoseController sets them each frame over the walking animation. An IKControl
-- solved it again every frame from wherever the animation had the arm, and the
-- arm twitched with every step (the user, 2026-11-05; measured in Studio: a hand
-- turned up to 125° in one frame, standing still).
local ArmPose = {}

local function basis(direction: Vector3, side: Vector3): CFrame
	local z = direction.Unit
	local x = (side - z * side:Dot(z)).Unit
	return CFrame.fromMatrix(Vector3.zero, x, z:Cross(x), z)
end

-- The turn that takes `direction` to `toDirection` and `side` to `toSide`.
local function turn(direction: Vector3, side: Vector3, toDirection: Vector3, toSide: Vector3): CFrame
	return basis(toDirection, toSide) * basis(direction, side):Inverse()
end

-- The Transforms of an arm's three joints (each with a C0 and a C1) that put
-- the hand on `hand`, in the frame of the part the shoulder hangs from, with
-- the elbow out toward `pole`. A hand out of reach gets as near as it can.
function ArmPose.solve(shoulder, elbow, wrist, hand: CFrame, pole: Vector3): (CFrame, CFrame, CFrame)
	local upperBone = elbow.C0.Position - shoulder.C1.Position
	local lowerBone = wrist.C0.Position - elbow.C1.Position
	local a, b = upperBone.Magnitude, lowerBone.Magnitude

	-- where the elbow goes: on the circle both bones reach, nearest the pole
	local from = shoulder.C0.Position
	local toWrist = (hand * wrist.C1).Position - from
	local axis = toWrist.Unit
	local reach = math.clamp(toWrist.Magnitude, math.abs(a - b) + 0.01, a + b - 0.01)
	local along = (a * a - b * b + reach * reach) / (2 * reach)
	local out = pole - from
	out = (out - axis * out:Dot(axis)).Unit
	local at = from + axis * along + out * math.sqrt(math.max(a * a - along * along, 0))
	local upperWay = (at - from).Unit
	local lowerWay = (from + axis * reach - at).Unit

	-- an elbow bends the forearm toward the arm's front (-Z, hanging down)
	local upperTurn = turn(upperBone, Vector3.new(0, 0, -1), upperWay, lowerWay - upperWay * lowerWay:Dot(upperWay))
	local upper = CFrame.new(from - upperTurn * shoulder.C1.Position) * upperTurn
	local elbowJoint = upper * elbow.C0
	local lowerTurn = turn(lowerBone, Vector3.new(1, 0, 0), lowerWay, upper.XVector)
	local lower = CFrame.new(elbowJoint.Position - lowerTurn * elbow.C1.Position) * lowerTurn

	return (shoulder.C0:Inverse() * upper * shoulder.C1).Rotation,
		(elbowJoint:Inverse() * lower * elbow.C1).Rotation,
		((lower * wrist.C0):Inverse() * hand * wrist.C1).Rotation
end

return ArmPose
