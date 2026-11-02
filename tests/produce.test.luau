-- The stolen crops thieves carry (World/ProduceArt): every crop has a model,
-- its parts all inside the size it says it is (the hands go on its sides,
-- client/PoseController), nothing to bump into; and the trucks they drive
-- past are solid (World/YardArt).
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local roblox = require("@lune/roblox")
	local Crops = harness.load("Config/Crops")

	local game = roblox.Instance.new("DataModel")
	local globals = { Instance = roblox.Instance, workspace = game:GetService("Workspace") }

	describe("carried crops (World/ProduceArt)", function()
		local ProduceArt = harness.loadServerWith("World/ProduceArt", globals)
		it("builds every crop, as many as a patch gives (and a bumper patch), the size it says, with nothing solid", function()
			for _, crop in Crops.List do
			for _, count in { 1, crop.perPatch, math.ceil(crop.perPatch * 1.5 - 1e-9) } do
				local model, core = ProduceArt.build(crop.id, roblox.CFrame.new(), count)
				local parts = 0
				for _, part in model:GetDescendants() do
					parts += if part:IsA("BasePart") then 1 else 0
				end
				if parts > 160 then
					error(`{crop.id} ×{count}: {parts} parts (keep a carried crop under 160)`)
				end
				local width, height, hold = core:GetAttribute("Width"), core:GetAttribute("Height"), core:GetAttribute("HoldY")
				expect(width > 0.5 and height > 0.5 and hold > 0 and hold < height).toBe(true)
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") then
						if part.CanCollide or part.CanTouch then
							error(`{crop.id}: {part.Name} can be bumped into`)
						end
						-- (a part's middle within the size, give or take its own half)
						local p = part.CFrame.Position
						local slack = part.Size.Magnitude / 2
						if math.abs(p.X) > width / 2 + slack or p.Y < -0.3 or p.Y > height + 0.3 then
							error(`{crop.id} ×{count}: {part.Name} at {p} is outside {width} × {height}`)
						end
					end
				end
			end
			end
		end)
	end)

	describe("trucks (World/YardArt)", function()
		local WorldBuilder = harness.loadServerWith("World/WorldBuilder", globals)
		local YardArt = harness.loadServerWith("World/YardArt", globals)
		local world = WorldBuilder.Build()
		for _, level in { 1, 5, 10, 15 } do
			it(`are solid at Warehouse Level {level}: you walk round them, not through`, function()
				local warehouse = YardArt.setLevel(world.Plot1, level)
				for _, truck in warehouse.Trucks:GetChildren() do
					local solid = {}
					for _, part in truck:GetDescendants() do
						if part:IsA("BasePart") and part.CanCollide then
							solid[part.Name] = true
						end
					end
					for _, name in { "Chassis", "Hood", "Cab", "Wheel", "BedFloor" } do
						if not solid[name] then
							error(`{truck.Name} ({truck:GetAttribute("Kind")}): its {name} isn't solid`)
						end
					end
				end
			end)
		end
	end)
end
