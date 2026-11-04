-- Dumps the valley's NPCs as the clients build them (client/People) to
-- JSON, so tools/crop_art/partview.py can render them for a look before
-- Studio. From the project folder:
--   lune run tools/peopledump [out.json]
--   python tools/crop_art/partview.py out.json out.png people peopleback peopleclose poses
-- In a row along +X, 6 studs apart, facing −Z: every job's worker (z = 0),
-- shoppers with looks 1–10 (z = 12), and at z = 24 a worker walking with
-- a crate, one on strike and one busy at their station (the poses
-- WorkerController gives them). The face is a decal partview can't draw:
-- two eyes and a smile stand in for it (where Studio draws them: the eyes
-- 0.18 over the head's middle, the smile 0.1 under it).
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Harness = require("../tests/lib/harness")

local out = process.args[1] or "people.json"
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

Harness.reset()
local People = Harness.loadClientWith("People", { Instance = roblox.Instance })

local JOBS = { "Farmhand", "ShedHand", "Sorter", "Packer", "Loader", "Driver", "Stocker", "Cashier", "Greeter", "Watchman" }

local parts = {}
local function put(part, cf)
	local entry = {
		name = part.Name,
		class = part.ClassName,
		size = { part.Size.X, part.Size.Y, part.Size.Z },
		cframe = { cf:GetComponents() },
		color = { part.Color.R, part.Color.G, part.Color.B },
		neon = false,
		transparency = part.Transparency,
		shape = part.Shape.Name,
	}
	local special = part:FindFirstChildOfClass("SpecialMesh")
	if special and special.MeshType == roblox.Enum.MeshType.Head then
		entry.shape = "Head"
	end
	table.insert(parts, entry)
	if part:FindFirstChild("Face") then -- (the face decal's stand-in)
		local dark = { 0.16, 0.13, 0.12 }
		for _, x in { -0.2, 0.2 } do
			local eye = cf * CFrame.new(x * part.Size.X / 1.3, 0.18 * part.Size.Y / 1.3, -0.6 * part.Size.Z / 1.3)
			table.insert(parts, { name = "Eye", class = "Part", size = { 0.16, 0.22, 0.1 }, cframe = { eye:GetComponents() }, color = dark, shape = "Ball", transparency = 0 })
		end
		local smile = cf * CFrame.new(0, -0.1 * part.Size.Y / 1.3, -0.6 * part.Size.Z / 1.3)
		table.insert(parts, { name = "Smile", class = "Part", size = { 0.4, 0.07, 0.1 }, cframe = { smile:GetComponents() }, color = dark, transparency = 0 })
	end
end

-- One figure at `feet`, posed like the controllers do: legs and arms by
-- their angle (radians, forward +), props shown or not, sitting `sit` lower.
local function draw(figureParts, feet, pose)
	pose = pose or {}
	for _, entry in figureParts do
		local p, offset, role, side, pivot = entry[1], entry[2], entry[3], entry[4], entry[5]
		local shown = p.Transparency < 1
		if role == "load" then
			shown = pose.carrying == true
		elseif role == "seat" or role == "strike" then
			shown = pose.strike == true
		end
		if shown then
			local at = offset
			if (role == "leg" or role == "arm" or role == "basketArm") and pivot then
				local angle = if role == "leg" then (pose.leg or 0) * side else (if pose.arms then pose.arms(side) else 0)
				at = CFrame.new(pivot) * CFrame.Angles(angle, 0, 0) * CFrame.new(-pivot) * offset
			end
			put(p, feet * CFrame.new(0, if role == "seat" then 0 else (pose.sit or 0), 0) * at)
		end
	end
end

-- (a worker with the controller's props, built as WorkerController does)
local function worker(job, look, seed)
	local model, figureParts, add = People.worker(job, look, seed)
	local function prop(name, size, at, role)
		local p = add(name, size, at, roblox.Color3.fromRGB(150, 108, 70), { limb = role })
		p.Transparency = 1
	end
	prop("Load", Vector3.new(2.0, 1.0, 1.3), Vector3.new(0, 3.3, -1.5), "load")
	prop("SeatCrate", Vector3.new(2.2, 0.8, 1.8), Vector3.new(0, 0.4, 0.5), "seat")
	prop("SignStick", Vector3.new(0.2, 4.4, 0.2), Vector3.new(1.5, 6, -0.7), "strike")
	prop("SignBoard", Vector3.new(3.6, 1.8, 0.15), Vector3.new(1.5, 8.2, -0.7), "strike")
	return model, figureParts
end

for i, job in JOBS do
	local _, figureParts = worker(job, i, i * 13)
	draw(figureParts, CFrame.new((i - 1) * 6, 0, 0))
end
for look = 1, 10 do
	local _, figureParts = People.shopper(look)
	draw(figureParts, CFrame.new((look - 1) * 6, 0, 12))
end
local poses = {
	{ "Loader", { carrying = true, leg = 0.5, arms = function()
		return math.rad(70)
	end } },
	{ "ShedHand", { strike = true, sit = -1.1, leg = math.rad(80) * 1, arms = function(side)
		return if side > 0 then math.rad(160) else 0
	end } },
	{ "Watchman", { arms = function(side)
		return 0.35 * side
	end } },
	{ "Farmhand", { leg = 0.6, arms = function(side)
		return -0.6 * side
	end } },
}
for i, entry in poses do
	local _, figureParts = worker(entry[1], i + 2, i * 7)
	local pose = entry[2]
	if pose.strike then -- (both legs straight out, not one each way)
		local legs = pose.leg
		pose.leg = nil
		for _, e in figureParts do
			if e[3] == "leg" then
				e[4] = 1
			end
		end
		pose.leg = legs
	end
	draw(figureParts, CFrame.new((i - 1) * 6, 0, 24), pose)
end

-- the ground under each row (a lawn; partview keeps parts by their middle)
for _, z in { 0, 12, 24 } do
	local ground = CFrame.new(27, -0.5, z)
	table.insert(parts, { name = "Ground", class = "Part", size = { 80, 1, 12 }, cframe = { ground:GetComponents() }, color = { 0.55, 0.7, 0.42 }, transparency = 0 })
end

fs.writeFile(out, serde.encode("json", parts))
print(`{#parts} parts -> {out}`)
