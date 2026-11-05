-- The bat and its skins (World/CrimeArt, Config/Cosmetics): every one is a
-- Tool with a handle, every piece welded to it with nothing to bump into,
-- and about the plain bat's length (a skin is a look: the same swing, the
-- same bonk). The Golden Bat's gold glows, and it sparkles and leaves a
-- trail. The Carrot Club is the crop's own meshes once they're imported
-- (stand-ins here), and rings until then.
return function(spec, harness)
	local describe, it, expect = spec.describe, spec.it, spec.expect
	local roblox = require("@lune/roblox")
	local Cosmetics = harness.load("Config/Cosmetics")
	local DATA = harness.loadServer("World/CropMeshData")

	local game = roblox.Instance.new("DataModel")
	local globals = { Instance = roblox.Instance, workspace = game:GetService("Workspace") }

	local function load(withMeshes: boolean)
		local models = nil
		if withMeshes then
			models = roblox.Instance.new("Folder")
			models.Name = "CropModels"
			for mesh, info in DATA.meshes do
				local part = roblox.Instance.new("MeshPart")
				part.Name = mesh
				part.Size = info.size
				part.Parent = models
			end
		end
		harness.setStorageChild("CropModels", models)
		return harness.loadServerWith("World/CrimeArt", globals)
	end

	-- How far the shown parts reach along the handle.
	local function reach(tool)
		local low, high = math.huge, -math.huge
		for _, part in tool:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 then
				for _, x in { -1, 1 } do
					for _, y in { -1, 1 } do
						for _, z in { -1, 1 } do
							local corner = part.CFrame * roblox.CFrame.new(x * part.Size.X / 2, y * part.Size.Y / 2, z * part.Size.Z / 2)
							low, high = math.min(low, corner.Position.Y), math.max(high, corner.Position.Y)
						end
					end
				end
			end
		end
		return low, high
	end

	local function skins()
		local list = { false }
		for _, item in Cosmetics.LIST do
			if item.kind == "bat" then
				table.insert(list, item.id)
			end
		end
		return list
	end

	local function eachSkin(check)
		for _, withMeshes in { false, true } do
			local CrimeArt = load(withMeshes)
			for _, skin in skins() do
				check(CrimeArt.bat(skin or nil), skin, withMeshes)
			end
		end
		harness.setStorageChild("CropModels", nil)
	end

	describe("every skin", function()
		it("is a Tool held by its handle, every piece welded on with nothing to bump into", function()
			eachSkin(function(tool)
				local handle = tool:FindFirstChild("Handle")
				expect(tool:IsA("Tool")).toBe(true)
				expect(handle ~= nil).toBe(true)
				for _, part in tool:GetDescendants() do
					if part:IsA("BasePart") then
						expect(part.Anchored).toBe(false)
						expect(part.CanCollide).toBe(false)
						expect(part.Massless).toBe(true)
						if part ~= handle then
							local weld = part:FindFirstChildOfClass("WeldConstraint")
							expect(weld ~= nil and weld.Part0 == handle).toBe(true)
						end
					end
				end
			end)
		end)
		it("is about the plain bat's length", function()
			local CrimeArt = load(false)
			local low, high = reach(CrimeArt.bat(nil))
			local length = high - low
			eachSkin(function(tool)
				local a, b = reach(tool)
				expect(math.abs((b - a) - length) < 0.8).toBe(true)
			end)
		end)
	end)

	describe("skins with their own shape", function()
		it("have no bat under them: the handle's hidden and none of the bat's pieces are there", function()
			eachSkin(function(tool, skin)
				if skin then
					expect(tool.Handle.Transparency).toBe(1)
					for _, name in { "Knob", "Neck", "Barrel", "Band", "Tip" } do
						expect(tool:FindFirstChild(name)).toBe(nil)
					end
				end
			end)
		end)
		it("the Golden Bat's gold glows, with a halo and a light; it sparkles; its trail runs between two attachments", function()
			eachSkin(function(tool, skin)
				if skin == "GoldenBat" then
					local trail = tool.Handle:FindFirstChildOfClass("Trail")
					expect(tool:FindFirstChild("BatHead").Material).toBe(roblox.Enum.Material.Neon)
					expect(tool:FindFirstChild("Halo", true) ~= nil).toBe(true)
					expect(tool:FindFirstChild("Sparkles", true) ~= nil).toBe(true)
					expect(tool:FindFirstChild("Glow", true) ~= nil).toBe(true)
					expect(trail ~= nil).toBe(true)
					expect(trail.Attachment0.Parent == tool.Handle and trail.Attachment1.Parent == tool.Handle).toBe(true)
				end
			end)
		end)
		it("the Carrot Club is the crop's own meshes once they're imported, rings until then", function()
			eachSkin(function(tool, skin, withMeshes)
				if skin == "CarrotClub" then
					expect(tool:FindFirstChild("Carrot") ~= nil).toBe(withMeshes)
					expect(tool:FindFirstChild("CarrotTop") ~= nil).toBe(withMeshes)
					expect(tool:FindFirstChild("Root") ~= nil).toBe(not withMeshes)
				end
			end)
		end)
	end)
end
