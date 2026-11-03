-- A farm's defences drawn (World/DefenceArt), built for real with
-- @lune/roblox Instances on a real farm: the back fence both ways, the
-- gate's leaves swinging and its lock, every defence on its spot (meshes
-- once the props are imported, stand-ins before), the Watchman's gatehouse
-- and the domes, nothing anchored loose or solid where you'd walk.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local roblox = require("@lune/roblox")
	local Defences = harness.load("Config/Defences")
	local DefenceRules = harness.load("DefenceRules")
	local PlotLayout = harness.load("PlotLayout")
	local PROPS = harness.loadServer("World/PropMeshData")

	local game = roblox.Instance.new("DataModel")
	local workspace = game:GetService("Workspace")
	local globals = { Instance = roblox.Instance, workspace = workspace }

	local function build()
		local WorldBuilder = harness.loadServerWith("World/WorldBuilder", globals)
		return WorldBuilder.Build()
	end

	-- one of everything, set out
	local function everything()
		local d = { owned = {}, placed = {} }
		for _, itemId in Defences.ORDER do
			for _ = 1, math.min(Defences.ITEMS[itemId].max, 4) do
				DefenceRules.buy(d, itemId)
			end
		end
		DefenceRules.place(d, "Scarecrow", "yard:4")
		DefenceRules.place(d, "GuardDog", "yard:13")
		for _, n in { 10, 12, 15, 17 } do
			DefenceRules.place(d, "MudPatch", `yard:{n}`)
		end
		local land = { cleared = {}, fresh = {}, fieldLevel = 1 }
		local placed = 0
		for tile = 1, 64 do
			if placed < 4 and DefenceRules.canPlace(d, land, "Cloche", `tile:{tile}`) then
				DefenceRules.place(d, "Cloche", `tile:{tile}`)
				placed += 1
			end
		end
		return d
	end

	-- the box round a model's parts (their middles, ± half their size)
	local function bounds(model)
		local lo, hi = nil, nil
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				local p, h = part.CFrame.Position, part.Size / 2
				local m = math.max(h.X, h.Y, h.Z)
				local a, b = p - roblox.Vector3.new(m, m, m), p + roblox.Vector3.new(m, m, m)
				lo = if lo then roblox.Vector3.new(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) else a
				hi = if hi then roblox.Vector3.new(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z)) else b
			end
		end
		return (lo + hi) / 2, hi - lo
	end

	local function count(model, name)
		local n = 0
		for _, part in model:GetDescendants() do
			if part.Name == name then
				n += 1
			end
		end
		return n
	end

	describe("a farm's defences", function()
		local ok, world = pcall(build)
		it("the world builds with them", function()
			if not ok then
				error(world)
			end
		end)
		if not ok then
			return
		end
		local DefenceArt = harness.loadServerWith("World/DefenceArt", globals)
		local plot = world:FindFirstChild("Plot1")
		local frame = PlotLayout.frame(1)

		it("starts with the slatted back fence, open gate leaves and a dark alarm light", function()
			expect(plot.BackFence:GetAttribute("Tall")).toBe(false)
			expect(plot:FindFirstChild("GateLeaves") ~= nil).toBe(true)
			expect(plot.GateLeaves:GetAttribute("Open")).toBe(true)
			expect(plot:FindFirstChild("AlarmBeacon") ~= nil).toBe(true)
			expect(plot:FindFirstChild("GateBlocker")).toBe(nil)
			-- (the old stand-ins are gone)
			expect(plot:FindFirstChild("Scarecrow")).toBe(nil)
			expect(plot:FindFirstChild("Kennel")).toBe(nil)
			expect(plot:FindFirstChild("Gatehouse")).toBe(nil)
		end)

		it("draws every defence on its spot, without the props: stand-ins", function()
			local d = everything()
			DefenceArt.show(plot, frame, 1, d)
			local folder = plot:FindFirstChild("Defences")
			expect(folder ~= nil).toBe(true)
			expect(count(folder, "Scarecrow")).toBe(1)
			expect(count(folder, "Kennel")).toBe(1)
			expect(count(folder, "Dog")).toBe(1)
			expect(count(folder, "MudPatch")).toBe(4 + 4)
			expect(count(folder, "Cloche")).toBe(4 + 4)
			expect(count(folder, "Camera")).toBe(1)
			expect(plot.BackFence:GetAttribute("Tall")).toBe(true)
			-- each yard thing stands on its own spot
			for _, holder in folder:GetChildren() do
				local spot = holder:GetAttribute("Spot")
				local kind, n = DefenceRules.spotKind(spot or "")
				if kind == "yard" then
					local at = frame:PointToWorldSpace(PlotLayout.yardSpot(n))
					local centre, size = bounds(holder)
					if math.abs(centre.X - at.X) > PlotLayout.YARD_SPOT / 2 or math.abs(centre.Z - at.Z) > PlotLayout.YARD_SPOT / 2
						or size.X > PlotLayout.YARD_SPOT + 3 or size.Z > PlotLayout.YARD_SPOT + 3 then
						error(`{holder.Name} on {spot} spills off it ({size})`)
					end
				end
			end
		end)

		it("anchors everything, and nothing but the kennel, the floodlights' posts and the blockers is solid", function()
			for _, part in plot.Defences:GetDescendants() do
				if part:IsA("BasePart") then
					expect(part.Anchored).toBe(true)
					if part.CanCollide and not string.find(part:GetFullName(), "Kennel") and not string.find(part.Name, "Solid")
						and part.Name ~= "FloodPost" and part.Name ~= "FloodPlinth" then
						error(`{part:GetFullName()} is solid`)
					end
				end
			end
		end)
		it("stands the floodlights just off the field's corners, clear of its tiles and the yard spots, lit only at night", function()
			local floods = plot.Defences:FindFirstChild("Floodlights")
			expect(floods ~= nil).toBe(true)
			local field = PlotLayout.PLOT.field
			local x0, z0 = field.across, field.depth
			local x1, z1 = x0 + field.size * field.tile, z0 + field.size * field.tile
			local posts, lights = 0, 0
			for _, part in floods:GetDescendants() do
				if part:IsA("BasePart") and part.Name == "FloodPost" then
					posts += 1
					local p = PlotLayout.frame(1):PointToObjectSpace(part.CFrame.Position)
					local offX = math.min(math.abs(p.X - x0), math.abs(p.X - x1))
					local offZ = math.min(math.abs(p.Z - z0), math.abs(p.Z - z1))
					expect(offX < 3 and offZ < 3).toBe(true) -- (inside the 3-stud gap before the yard spots)
					expect(p.X < x0 or p.X > x1 or p.Z < z0 or p.Z > z1).toBe(true) -- (off the field)
				elseif part:IsA("SpotLight") then
					lights += 1
					expect(part.Enabled).toBe(false)
					expect(part:HasTag("NightLight")).toBe(true)
				end
			end
			expect(posts).toBe(4)
			expect(lights).toBe(4)
			expect(plot:GetAttribute("Floodlights")).toBe(true)
		end)

		it("uses the meshes once the props are imported", function()
			local props = roblox.Instance.new("Folder")
			props.Name = "PropModels"
			for mesh, info in PROPS.meshes do
				local part = roblox.Instance.new("MeshPart")
				part.Name = mesh
				part.Size = info.size
				part.Parent = props
			end
			harness.setStorageChild("PropModels", props)
			local Fresh = harness.loadServerWith("World/DefenceArt", globals)
			Fresh.show(plot, frame, 1, everything())
			local meshes = {}
			for _, part in plot.Defences:GetDescendants() do
				if part:IsA("MeshPart") then
					meshes[part.Name] = (meshes[part.Name] or 0) + 1
				end
			end
			for _, name in { "Scarecrow", "GuardDog", "MudPatch", "Cloche", "SecurityCamera" } do
				if PROPS.meshes[name] then
					expect((meshes[name] or 0) > 0).toBe(true)
				end
			end
			harness.setStorageChild("PropModels", nil)
		end)

		it("puts everything away again", function()
			DefenceArt.show(plot, frame, 1, { owned = {}, placed = {} })
			expect(#plot.Defences:GetChildren()).toBe(0)
			expect(plot.BackFence:GetAttribute("Tall")).toBe(false)
		end)

		it("shuts the gate with its lock showing, and opens it again", function()
			DefenceArt.setGate(plot, false, true)
			expect(plot.GateLeaves:GetAttribute("Open")).toBe(false)
			local padlock = plot.GateLeaves.LeafRight.Lock.Padlock
			expect(padlock.Transparency).toBe(0)
			-- the leaves span the gateway, shut
			-- shut, the left leaf lies across the gateway (along the fence)
			local _, size = bounds(plot.GateLeaves.LeafLeft)
			local across = math.abs(frame.XVector:Dot(size))
			expect(across > 7).toBe(true)
			DefenceArt.setGate(plot, true, false)
			expect(padlock.Transparency).toBe(1)
			DefenceArt.setGateBlocker(plot, frame, true)
			expect(plot:FindFirstChild("GateBlocker").CanCollide).toBe(true)
			DefenceArt.setGateBlocker(plot, frame, false)
			expect(plot:FindFirstChild("GateBlocker")).toBe(nil)
		end)

		it("builds the Watchman's gatehouse inside the gate, with a bell and a spotlight", function()
			DefenceArt.gatehouse(plot, frame, 1, true)
			local hut = plot:FindFirstChild("Gatehouse")
			expect(hut ~= nil).toBe(true)
			expect(hut:FindFirstChild("AlarmBell", true) ~= nil).toBe(true)
			expect(hut:FindFirstChild("SpotBeam") ~= nil).toBe(true)
			local g = PlotLayout.PLOT.gatehouse
			for _, part in hut:GetDescendants() do
				if part:IsA("BasePart") and part.Name ~= "GatehouseRoof" and part.Name ~= "GatehouseRidge" then
					local p = frame:PointToObjectSpace(part.CFrame.Position)
					if p.X < g.min.X - 2.5 or p.X > g.max.X + 2.5 or p.Z < g.min.Z - 2.5 or p.Z > g.max.Z + 2.5 then
						error(`{part.Name} sticks out of the gatehouse's lot`)
					end
				end
			end
			DefenceArt.gatehouse(plot, frame, 1, false)
			expect(plot:FindFirstChild("Gatehouse")).toBe(nil)
		end)

		it("puts a dome over the field, changes it and takes it away", function()
			DefenceArt.dome(plot, frame, "Shield", 100)
			expect(plot.Dome:GetAttribute("Kind")).toBe("Shield")
			expect(plot.Dome.CanCollide).toBe(false)
			DefenceArt.dome(plot, frame, "Shield", 200)
			expect(plot.Dome:GetAttribute("Ends")).toBe(200)
			DefenceArt.dome(plot, frame, "Watch", 300)
			expect(plot.Dome:GetAttribute("Kind")).toBe("Watch")
			DefenceArt.dome(plot, frame, nil)
			expect(plot:FindFirstChild("Dome")).toBe(nil)
		end)
	end)
end
