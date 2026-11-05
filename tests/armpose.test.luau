-- An arm's pose (shared/ArmPose): the hand ends up exactly where it's sent,
-- turned as it's told, with the elbow out toward the pole, for either arm,
-- however its joints are set up.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local roblox = require("@lune/roblox")
	local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
	local ArmPose = harness.load("ArmPose")

	local function arm(out, tilt)
		local twist = CFrame.Angles(tilt, 0, tilt / 2)
		return { C0 = CFrame.new(out, 0.56, 0), C1 = CFrame.new(0, 0.4, 0) * twist },
			{ C0 = CFrame.new(0, -0.33, 0), C1 = CFrame.new(0, 0.26, 0) * twist },
			{ C0 = CFrame.new(0, -0.5, 0), C1 = CFrame.new(0, 0.12, 0) }
	end

	-- Where the parts end up: Part1 = Part0 * C0 * Transform * C1:Inverse().
	local function follow(shoulder, elbow, wrist, a, b, c)
		local upper = shoulder.C0 * a * shoulder.C1:Inverse()
		local lower = upper * elbow.C0 * b * elbow.C1:Inverse()
		return upper, lower, lower * wrist.C0 * c * wrist.C1:Inverse()
	end

	local function near(a, b, within)
		if (a - b).Magnitude > within then
			error(`{a} is not near {b}`)
		end
	end

	describe("holding something overhead", function()
		for _, case in { { "right", 1 }, { "left", -1 } } do
			for _, tilt in { 0, 0.3 } do
				it(`puts the {case[1]} hand on its spot{if tilt > 0 then " with turned joints" else ""}`, function()
					local out = case[2]
					local shoulder, elbow, wrist = arm(out, tilt)
					local at = Vector3.new(out * 1.1, 2.1, -0.05)
					local hand = CFrame.lookAt(at, at + Vector3.new(0, 0, 1), Vector3.new(out * 0.2, -1, 0))
					local pole = Vector3.new(out * 3, 1.2, -0.6)
					local a, b, c = ArmPose.solve(shoulder, elbow, wrist, hand, pole)
					local upper, _, ended = follow(shoulder, elbow, wrist, a, b, c)
					near(ended.Position, hand.Position, 0.01)
					near(ended.XVector, hand.XVector, 0.01)
					near(ended.YVector, hand.YVector, 0.01)
					-- the elbow's on the pole's side of the line from shoulder to wrist
					local from = shoulder.C0.Position
					local line = ((hand * wrist.C1).Position - from).Unit
					local elbowAt = (upper * elbow.C0).Position - from
					local side = pole - from
					side -= line * side:Dot(line)
					expect((elbowAt - line * elbowAt:Dot(line)):Dot(side) > 0).toBe(true)
					-- and the forearm bends in toward the crop from an elbow out wide
					expect(math.abs((upper * elbow.C0).Position.X) > math.abs(from.X)).toBe(true)
				end)
			end
		end

		it("reaches as far as it can for a spot out of reach, not past it", function()
			local shoulder, elbow, wrist = arm(1, 0)
			local at = Vector3.new(1, 9, 0)
			local a, b, c = ArmPose.solve(shoulder, elbow, wrist, CFrame.lookAt(at, at + Vector3.new(0, 0, 1), Vector3.new(0.2, -1, 0)), Vector3.new(3, 1.2, -0.6))
			local _, _, ended = follow(shoulder, elbow, wrist, a, b, c)
			expect(ended.Position.Y < 3).toBe(true)
			expect(ended.Position.Y > 1.5).toBe(true)
		end)
	end)
end
