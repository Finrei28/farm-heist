-- Draws every farm's crew (docs/ArtDirection.md §8) from the WorkerEvent
-- remote (WorkerService decides what they do): people with the shoppers'
-- body in their job's uniform (client/People, client/WorkerLooks; since
-- 2026-11-05) with a small name-and-level tag, standing at
-- their station and busy with their hands; a "Do" walks one to a truck or a
-- display and back, carrying what they took, or, with `stay`, one way (a
-- Farmhand goes from crop to crop). A walk starts from wherever they are, so
-- a new one never jumps them back. On strike they walk out to the lawn by
-- your door and stand there holding up a banner. A Driver waits by their
-- truck, and is away with it. Made of local parts: nothing here matters to
-- the game.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared.Config.Crops)
local Remotes = require(Shared.Remotes)
local Workers = require(Shared.Config.Workers)

local People = require(script.Parent.Parent.People)

local WorkerController = {}

local CULL = 300 -- studs from the camera: farther workers aren't drawn
local PAUSE = 0.6 -- seconds at the far end of a walk
local WALK = 10 -- studs a second

local folder = Instance.new("Folder")
folder.Name = "Crews"
local crews = {} -- [plot] = { [id] = worker }

local function now(): number
	return workspace:GetServerTimeNow()
end

-- A string's own number (a worker's id: their hair is theirs).
local function hash(text: string): number
	local h = 0
	for i = 1, #text do
		h = (h * 31 + string.byte(text, i)) % 1_000_003
	end
	return h
end

-- A worker in their job's uniform on the shoppers' body (client/People),
-- with the props the controller shows when needed: what they carry on a
-- walk and the banner they hold up on strike.
local function build(info)
	local model, parts, add, torso = People.worker(info.type, info.look, hash(tostring(info.id)))
	model.Name = `Worker{info.id}`
	local brown = Color3.fromRGB(150, 108, 70)
	local function prop(name, size, at, color, role)
		local p = add(name, size, at, color, { limb = role })
		p.Transparency = 1
		return p
	end
	local load = prop("Load", Vector3.new(2.0, 1.0, 1.3), Vector3.new(0, 3.3, -1.5), brown, "load") -- (between the hands, arms out)
	-- (a banner on two sticks, one in each hand, right over their head: no wider
	-- than they are, so it can't go through a wall they're standing by)
	for _, side in { -1, 1 } do
		prop("SignStick", Vector3.new(0.2, 4.4, 0.2), Vector3.new(side * 1.5, 6, -0.7), Color3.fromRGB(107, 74, 47), "strike")
	end
	local board = prop("SignBoard", Vector3.new(3.4, 1.8, 0.15), Vector3.new(0, 8.2, -0.7), Color3.fromRGB(255, 244, 220), "strike")
	local strikeGuis = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do -- (you might be behind them)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
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
		table.insert(strikeGuis, gui)
	end
	-- the name tag
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromScale(6, 0.8)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 3.9, 0)
	tag.MaxDistance = 60
	tag.Adornee = torso
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
	local list = {}
	for _, entry in parts do
		table.insert(list, entry[1])
	end
	return { model = model, parts = parts, list = list, cframes = {}, load = load, strikeGuis = strikeGuis, label = label, tag = tag, look = info.look, type = info.type }
end

-- `share` (0 to 1) of the way along a list of points, and the way they're
-- heading there.
local function along(points: { Vector3 }, share: number, facing: Vector3): (Vector3, Vector3)
	local left = 0
	for i = 2, #points do
		left += (points[i] - points[i - 1]).Magnitude
	end
	left *= share
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local length = (b - a).Magnitude
		if left <= length or i == #points then
			local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			return a:Lerp(b, if length > 0 then math.min(left / length, 1) else 1), if flat.Magnitude > 0.1 then flat.Unit else facing
		end
		left -= length
	end
	return points[#points], facing
end

-- The way back from a walk's far end: the way they came, to their post.
local function homeward(worker, walk): { Vector3 }
	local points = {}
	for i = #walk.points, 2, -1 do
		table.insert(points, walk.points[i])
	end
	table.insert(points, worker.at)
	return points
end

-- Where the worker is at time t, the way they face, whether they're walking,
-- and whether they're on the way back.
local function place(worker, t: number): (Vector3, Vector3, boolean, boolean)
	local walk = worker.walk
	if walk then
		local out = walk.seconds
		local elapsed = math.max(t - walk.at, 0)
		local position, dir = along(walk.points, math.min(elapsed / out, 1), worker.face)
		if elapsed < out then
			return position, dir, true, false
		elseif walk.stay then
			worker.walk = nil
			worker.stand = if walk.home then nil else { at = walk.to, face = dir }
		elseif elapsed < out + PAUSE then
			return walk.to, dir, false, false
		elseif elapsed < out * 2 + PAUSE then
			local back, facing = along(homeward(worker, walk), (elapsed - out - PAUSE) / out, -dir)
			return back, facing, true, true
		else
			worker.walk = nil
			worker.stand = nil
		end
	end
	if worker.stand then
		return worker.stand.at, worker.stand.face, false, false
	end
	return worker.at, worker.face, false, false
end

-- A Driver whose truck is out on the road is away with it.
local function driverAway(plot: number, worker): boolean
	if worker.type ~= "Driver" or worker.strike then
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
			local position, face, walking, returning = place(worker, t)
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
			-- (a crate out to the truck, a harvested crop on the way back: `back`)
			local walk = worker.walk
			local carrying = walking and walk ~= nil and walk.carry ~= nil and returning == (walk.back == true)
			-- (their legs keep up with their pace: a trained Farmhand fairly flies)
			local swing = if walking then math.sin(t * 9 * (walk and walk.stride or 1)) * 0.6 else 0
			local busy = if not walking and not worker.strike then math.sin(t * 4 + worker.phase) * 0.35 else 0
			local picketing = worker.strike and not walking -- (the banner goes up once they're there: it's taller than the doors)
			local cframes = worker.cframes
			for i, entry in worker.parts do
				local p, offset, role, side, pivot = entry[1], entry[2], entry[3], entry[4], entry[5]
				local pose = offset
				if role == "leg" or role == "arm" then
					-- legs from the hip: swinging as they walk; arms from the shoulder: forward
					-- to carry, busy at their station, the banner held up on strike
					local angle = if role == "leg" then swing * side
						elseif carrying then math.rad(70)
						elseif picketing then math.rad(160)
						else busy * side - swing * side
					pose = CFrame.new(pivot) * CFrame.Angles(angle, 0, 0) * CFrame.new(-pivot) * offset
				elseif role then -- (the props: shown only when needed)
					local shown = if role == "load" then carrying else picketing
					local transparency = if shown then 0 else 1
					if p.Transparency ~= transparency then
						p.Transparency = transparency
					end
				end
				cframes[i] = base * pose
			end
			workspace:BulkMoveTo(worker.list, cframes, Enum.BulkMoveMode.FireCFrameChanged)
			for _, gui in worker.strikeGuis do
				gui.Enabled = picketing
			end
			-- (workers side by side get their tags at different heights,
			-- a Stocker's a line over the Cashier's: they wait a cell apart by the staff door)
			local lift = ((worker.nth or 1) - 1) % 3 * 0.9 + (if worker.type == "Stocker" then 0.9 else 0)
			worker.tag.Enabled = not picketing -- (side by side their names run together: the banners say it)
			worker.tag.StudsOffsetWorldSpace = Vector3.new(0, 3.9 + lift, 0)
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
		local from = worker.at and (place(worker, now()))
		local strike = info.strike == true
		-- (out to the picket line and back; a Farmhand whose post moves, one
		-- being let go beside them, walks there too)
		local walks = from ~= nil and (strike ~= (worker.strike == true) or (worker.type == "Farmhand" and not worker.walk and not worker.stand))
		if walks and (from - info.at).Magnitude > 0.5 then
			local points = { from }
			for _, point in info.via or {} do
				table.insert(points, point)
			end
			table.insert(points, info.at)
			local length = 0
			for i = 2, #points do
				length += (points[i] - points[i - 1]).Magnitude
			end
			worker.stand = nil
			worker.walk = { at = now(), points = points, to = info.at, seconds = length / WALK, stay = true, home = true, back = false }
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
		local points = { (place(worker, now())) }
		for _, point in event.via or {} do
			table.insert(points, point)
		end
		table.insert(points, event.to)
		local length = 0
		for i = 2, #points do
			length += (points[i] - points[i - 1]).Magnitude
		end
		worker.walk = { at = event.at, points = points, to = event.to, seconds = event.seconds, carry = event.carry,
			back = event.back == true, stay = event.stay == true, home = event.home == true,
			stride = math.clamp(length / math.max(event.seconds, 0.1) / WALK, 0.7, 2.6) }
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
