-- Draws every farm's crew (docs/ArtDirection.md §8) from the WorkerEvent
-- remote (WorkerService decides what they do): blocky people in their job's
-- outfit (client/WorkerLooks) with a small name-and-level tag, standing at
-- their station and busy with their hands; a "Do" walks one to a tile, a
-- truck or a display and back, carrying what they took. On strike they sit
-- on a crate holding a sign. A Driver waits by their truck, and is away
-- with it. Made of local parts: nothing here matters to the game.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared.Config.Crops)
local Remotes = require(Shared.Remotes)
local Workers = require(Shared.Config.Workers)

local WorkerLooks = require(script.Parent.Parent.WorkerLooks)

local WorkerController = {}

local CULL = 300 -- studs from the camera: farther workers aren't drawn
local PAUSE = 0.6 -- seconds at the far end of a walk

local folder = Instance.new("Folder")
folder.Name = "Crews"
local crews = {} -- [plot] = { [id] = worker }

local function now(): number
	return workspace:GetServerTimeNow()
end

local function piece(model: Model, name: string, size: Vector3, color: Color3, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Shape = shape or Enum.PartType.Block
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- A worker in their job's clothes: each part with its offset from the feet
-- (legs and arms swing: they're marked).
local function build(info)
	local look = WorkerLooks.TYPES[info.type] or WorkerLooks.TYPES.Packer
	local skin = WorkerLooks.SKIN[(info.look - 1) % #WorkerLooks.SKIN + 1]
	local model = Instance.new("Model")
	model.Name = `Worker{info.id}`
	local parts = {
		{ piece(model, "LegL", Vector3.new(0.9, 2.2, 0.9), look.legs), CFrame.new(-0.5, 1.1, 0), "leg", -1 },
		{ piece(model, "LegR", Vector3.new(0.9, 2.2, 0.9), look.legs), CFrame.new(0.5, 1.1, 0), "leg", 1 },
		{ piece(model, "Body", Vector3.new(2.1, 2.3, 1.1), look.shirt), CFrame.new(0, 3.35, 0) },
		{ piece(model, "ArmL", Vector3.new(0.7, 2.1, 0.7), look.shirt), CFrame.new(-1.45, 3.4, 0), "arm", -1 },
		{ piece(model, "ArmR", Vector3.new(0.7, 2.1, 0.7), look.shirt), CFrame.new(1.45, 3.4, 0), "arm", 1 },
		{ piece(model, "Head", Vector3.new(1.6, 1.6, 1.6), skin, Enum.PartType.Ball), CFrame.new(0, 5.3, 0) },
	}
	-- what goes over the shirt
	if look.apron then
		table.insert(parts, { piece(model, "Apron", Vector3.new(1.7, 2.6, 0.12), look.apron), CFrame.new(0, 2.9, -0.6) })
	end
	if look.bib then -- overalls: the bib and straps
		table.insert(parts, { piece(model, "Bib", Vector3.new(1.5, 1.2, 0.12), look.bib), CFrame.new(0, 3.6, -0.6) })
		for _, x in { -0.6, 0.6 } do
			table.insert(parts, { piece(model, "Strap", Vector3.new(0.3, 1.2, 1.2), look.bib), CFrame.new(x, 4.1, 0) })
		end
	end
	if look.vest then -- hi-vis, with a reflective band
		table.insert(parts, { piece(model, "Vest", Vector3.new(2.2, 2, 1.2), look.vest), CFrame.new(0, 3.45, 0) })
		table.insert(parts, { piece(model, "VestBand", Vector3.new(2.25, 0.25, 1.25), Color3.fromRGB(230, 236, 240)), CFrame.new(0, 3.1, 0) })
	end
	if look.sash then
		table.insert(parts, { piece(model, "Sash", Vector3.new(0.5, 2.9, 1.25), look.sash), CFrame.new(0, 3.35, 0) * CFrame.Angles(0, 0, math.rad(35)) })
		table.insert(parts, { piece(model, "Rosette", Vector3.new(0.2, 0.8, 0.8), Color3.fromRGB(200, 69, 45), Enum.PartType.Cylinder), CFrame.new(-0.5, 3.9, -0.6) * CFrame.Angles(0, math.rad(90), 0) })
	end
	if look.hat == "straw" then
		table.insert(parts, { piece(model, "Brim", Vector3.new(0.2, 3.2, 3.2), Color3.fromRGB(242, 200, 110), Enum.PartType.Cylinder), CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.rad(90)) })
		table.insert(parts, { piece(model, "Crown", Vector3.new(0.9, 1.6, 1.6), Color3.fromRGB(242, 200, 110), Enum.PartType.Cylinder), CFrame.new(0, 6.4, 0) * CFrame.Angles(0, 0, math.rad(90)) })
	elseif look.hat == "cap" then
		table.insert(parts, { piece(model, "Cap", Vector3.new(0.6, 1.7, 1.7), look.hatColor, Enum.PartType.Cylinder), CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.rad(90)) })
		table.insert(parts, { piece(model, "Peak", Vector3.new(1.2, 0.15, 0.8), look.hatColor), CFrame.new(0, 5.85, -0.95) })
	elseif look.hat == "hard" then
		table.insert(parts, { piece(model, "HardHat", Vector3.new(1.9, 1.9, 1.9), look.hatColor, Enum.PartType.Ball), CFrame.new(0, 5.75, 0) })
		table.insert(parts, { piece(model, "HatRim", Vector3.new(0.15, 2.1, 2.1), look.hatColor, Enum.PartType.Cylinder), CFrame.new(0, 5.6, 0) * CFrame.Angles(0, 0, math.rad(90)) })
	end
	-- what they carry on a walk, and the strike sign (hidden until needed)
	local load = piece(model, "Load", Vector3.new(1.6, 1, 1.4), Color3.fromRGB(150, 108, 70))
	load.Transparency = 1
	table.insert(parts, { load, CFrame.new(0, 3.2, -1.3), "load" })
	local seat = piece(model, "SeatCrate", Vector3.new(2.2, 1.1, 1.8), Color3.fromRGB(150, 108, 70))
	seat.Transparency = 1
	table.insert(parts, { seat, CFrame.new(0, 0.55, 0.5), "seat" })
	local stick = piece(model, "SignStick", Vector3.new(0.2, 4.4, 0.2), Color3.fromRGB(107, 74, 47))
	stick.Transparency = 1
	table.insert(parts, { stick, CFrame.new(1.45, 6, -0.7), "strike" })
	local board = piece(model, "SignBoard", Vector3.new(3.6, 1.8, 0.15), Color3.fromRGB(255, 244, 220))
	board.Transparency = 1
	table.insert(parts, { board, CFrame.new(1.45, 8.2, -0.7), "strike" })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Enabled = false
	local words = Instance.new("TextLabel")
	words.Size = UDim2.fromScale(1, 1)
	words.BackgroundTransparency = 1
	words.Font = Enum.Font.FredokaOne
	words.TextScaled = true
	words.TextColor3 = Color3.fromRGB(200, 69, 45)
	words.Text = "ON STRIKE"
	words.Parent = gui
	gui.Parent = board
	-- the name tag
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromScale(6, 0.8)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 3.9, 0)
	tag.MaxDistance = 60
	tag.Adornee = parts[3][1]
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = ""
	label.Parent = tag
	tag.Parent = model
	model.Parent = folder
	return { model = model, parts = parts, load = load, strikeGui = gui, label = label, tag = tag, look = info.look, type = info.type }
end

-- Where the worker is at time t, the way they face, and whether they're walking.
local function place(worker, t: number): (Vector3, Vector3, boolean)
	local walk = worker.walk
	if walk then
		local out = walk.seconds
		local total = out * 2 + PAUSE
		local elapsed = t - walk.at
		if elapsed >= total or elapsed < 0 then
			worker.walk = nil
		else
			local from, to = worker.at, walk.to
			local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
			local dir = if flat.Magnitude > 0.1 then flat.Unit else worker.face
			if elapsed < out then
				return from:Lerp(to, elapsed / out), dir, true
			elseif elapsed < out + PAUSE then
				return to, dir, false
			end
			return to:Lerp(from, (elapsed - out - PAUSE) / out), -dir, true
		end
	end
	return worker.at, worker.face, false
end

-- A Driver whose truck is out on the road is away with it.
local function driverAway(plot: number, worker): boolean
	if worker.type ~= "Driver" then
		return false
	end
	local model = workspace.World:FindFirstChild(`Plot{plot}`)
	local warehouse = model and model:FindFirstChild("Warehouse")
	local truck = warehouse and warehouse.Trucks:FindFirstChild(`Truck{worker.nth}`)
	return truck ~= nil and (truck:GetAttribute("ReturnAt") or 0) > now()
end

local function step()
	local t = now()
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	for plot, crew in crews do
		for _, worker in crew do
			local position, face, walking = place(worker, t)
			local hidden = (position - eye).Magnitude > CULL or driverAway(plot, worker)
			if hidden then
				if worker.model.Parent then
					worker.model.Parent = nil
				end
				continue
			end
			if not worker.model.Parent then
				worker.model.Parent = folder
			end
			local base = CFrame.lookAt(position, position + face) -- (the worker faces -Z: forward)
			local carrying = walking and worker.walk ~= nil and worker.walk.carry ~= nil
			local swing = if walking then math.sin(t * 9) * 0.6 else 0
			local busy = if not walking and not worker.strike then math.sin(t * 4 + worker.phase) * 0.35 else 0
			local sit = if worker.strike then -1.1 else 0 -- (on strike they sit on a crate)
			worker.load.Transparency = if carrying then 0 else 1
			for _, entry in worker.parts do
				local p, offset, role, side = entry[1], entry[2], entry[3], entry[4]
				local frame
				if role == "leg" then
					-- from the hip: swinging as they walk, straight out in front sitting down
					local angle = if worker.strike then math.rad(80) else swing * side
					frame = base * CFrame.new(offset.X, 2.2 + sit, offset.Z) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -1.1, 0)
				elseif role == "arm" then
					-- from the shoulder: forward to carry, busy at their station, the sign held up on strike
					local angle = if carrying then math.rad(70)
						elseif worker.strike then (if side > 0 then math.rad(160) else 0)
						else busy * side - swing * side
					frame = base * CFrame.new(offset.X, 4.45 + sit, offset.Z) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -1.05, 0)
				elseif role == "strike" or role == "seat" then
					p.Transparency = if worker.strike then 0 else 1
					frame = base * offset * CFrame.new(0, if role == "strike" then sit else 0, 0)
				else
					frame = base * offset * CFrame.new(0, sit, 0)
				end
				p.CFrame = frame
			end
			worker.strikeGui.Enabled = worker.strike
			-- (clear of the strike sign; workers side by side get their tags at different heights)
			worker.tag.StudsOffsetWorldSpace = Vector3.new(0, (if worker.strike then 5.6 else 3.9) + ((worker.nth or 1) - 1) % 3 * 0.9, 0)
		end
	end
end

local function clearPlot(plot: number)
	for _, worker in crews[plot] or {} do
		worker.model:Destroy()
	end
	crews[plot] = nil
end

local function onCrew(event)
	local crew = crews[event.plot] or {}
	crews[event.plot] = crew
	local seen = {}
	for _, info in event.workers do
		seen[info.id] = true
		local worker = crew[info.id]
		if worker and (worker.type ~= info.type or worker.look ~= info.look) then
			worker.model:Destroy()
			worker = nil
		end
		if not worker then
			worker = build(info)
			worker.phase = (tonumber(info.id) or 0) * 1.7
			crew[info.id] = worker
		end
		worker.at = info.at
		worker.face = if info.face.Magnitude > 0.01 then Vector3.new(info.face.X, 0, info.face.Z).Unit else Vector3.new(0, 0, 1)
		worker.strike = info.strike == true
		worker.nth = info.nth
		local job = Workers.TYPES[info.type]
		worker.label.Text = `{info.name or ""} · {if job then job.name else ""} Lv {info.level}`
	end
	for id, worker in crew do
		if not seen[id] then
			worker.model:Destroy()
			crew[id] = nil
		end
	end
end

local function onDo(event)
	local worker = crews[event.plot] and crews[event.plot][event.id]
	if worker then
		worker.walk = { at = event.at, to = event.to, seconds = event.seconds, carry = event.carry }
		if event.carry and Crops.ById[event.carry] then
			worker.load.Color = Color3.fromRGB(150, 108, 70)
		end
	end
end

function WorkerController.Start()
	folder.Parent = workspace
	local WorkerEvent = Remotes.event("WorkerEvent")
	WorkerEvent.OnClientEvent:Connect(function(kind, event)
		if kind == "Crew" then
			onCrew(event)
		elseif kind == "Do" then
			onDo(event)
		elseif kind == "Clear" then
			clearPlot(event.plot)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return WorkerController
