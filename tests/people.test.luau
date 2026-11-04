-- The valley's NPCs (client/People): every job's worker and a spread of
-- shoppers build, each limb swings from a pivot at the hip or shoulder,
-- and everyone stands on the ground under a ceiling: nothing below the feet,
-- nothing (but the hidden props) over a Corner Store's head height.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local roblox = require("@lune/roblox")
	local People = harness.loadClientWith("People", { Instance = roblox.Instance })
	local WorkerLooks = harness.loadClientWith("WorkerLooks", {})

	-- The lowest and highest point of a figure's shown parts, at rest.
	local function span(parts)
		local low, high = math.huge, -math.huge
		for _, entry in parts do
			local p, offset = entry[1], entry[2]
			if p.Transparency < 1 then
				for _, corner in { -1, 1 } do
					local y = (offset * roblox.CFrame.new(0, corner * p.Size.Y / 2, 0)).Position.Y
					low, high = math.min(low, y), math.max(high, y)
				end
			end
		end
		return low, high
	end

	local function checkLimbs(parts)
		for _, entry in parts do
			local limb = entry[3]
			if limb == "leg" or limb == "arm" or limb == "basketArm" then
				expect(entry[5] ~= nil).toBe(true)
				expect(entry[4] == -1 or entry[4] == 1).toBe(true)
			end
		end
	end

	describe("workers", function()
		it("every job and every look builds: a head with a face, limbs on pivots, feet on the ground", function()
			local jobs = 0
			for typeName in WorkerLooks.TYPES do
				jobs += 1
				for look = 1, 8 do
					local model, parts, _, torso = People.worker(typeName, look, look * 3)
					expect(torso.Name).toBe("Torso")
					local head = model:FindFirstChild("Head")
					expect(head ~= nil and head:FindFirstChild("Face") ~= nil).toBe(true)
					checkLimbs(parts)
					local low, high = span(parts)
					expect(math.abs(low) < 0.01).toBe(true)
					expect(high < 6.5).toBe(true)
				end
			end
			expect(jobs).toBe(10)
		end)
		it("every job's badge has a colour", function()
			for typeName in WorkerLooks.TYPES do
				expect(typeof(WorkerLooks.color(typeName))).toBe("Color3")
			end
		end)
	end)

	describe("shoppers", function()
		it("100 looks build, limbs on pivots, the basket hidden until they pick something", function()
			for look = 1, 100 do
				local _, parts, torso, basket, k = People.shopper(look)
				expect(torso.Name).toBe("Torso")
				checkLimbs(parts)
				for _, p in basket.all do
					expect(p.Transparency).toBe(1)
				end
				local low, high = span(parts)
				expect(math.abs(low) < 0.01).toBe(true)
				expect(high < 6.5 * k).toBe(true)
			end
		end)
	end)
end
