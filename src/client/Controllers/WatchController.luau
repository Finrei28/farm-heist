-- The farm keeping watch, on every screen (docs/GameDesign.md §4.11, §5.4;
-- the art in World/DefenceArt). The server says what happens with
-- attributes (DefenceService); this moves it smoothly here:
--   * the guard dog: lying by its kennel; when its Chase/ChaseAt are set it
--     runs at the thief, legs going, barks round them for 3 s and trots home;
--   * the alarm light on the farmhouse ridge spins red and the gate's flag
--     flashes while the plot's AlarmUntil is ahead;
--   * the Watchman's spotlight follows the thief (the gatehouse's SpotOn
--     until SpotUntil) and his bell swings when it rings (DefenceEvent Bell);
--   * the sign over a dome counts down (Ends).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crime = require(Shared.Config.Crime)
local Defences = require(Shared.Config.Defences)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.Parent.UI)
local Sfx = require(script.Parent.Parent.Sfx)

local C = UI.C
local WatchController = {}

local ALARM_RED = Color3.fromRGB(255, 52, 40)
local DARK_RED = Color3.fromRGB(150, 34, 30)

local function now(): number
	return workspace:GetServerTimeNow()
end

local function world(): Instance?
	return workspace:FindFirstChild("World")
end

local function plotModel(index: number): Instance?
	local w = world()
	return w and w:FindFirstChild(`Plot{index}`)
end

local function rootOf(who: Player?): BasePart?
	local character = who and who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- A word popping up over a spot in the world (DING DING!).
local function popText(at: Vector3, text: string, color: Color3)
	local anchor = UI.make("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(at),
		Parent = workspace.CurrentCamera,
	})
	local gui = UI.make("BillboardGui", { Adornee = anchor, Size = UDim2.fromOffset(150, 46), MaxDistance = 160, LightInfluence = 0, Parent = anchor })
	local label = UI.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.3, 0.3), BackgroundTransparency = 1,
		Font = UI.HEAD, TextScaled = true, Text = text, TextColor3 = color, TextStrokeColor3 = C.soilDark, TextStrokeTransparency = 0, Rotation = -6, Parent = gui,
	})
	TweenService:Create(label, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.fromScale(1, 1) }):Play()
	TweenService:Create(gui, TweenInfo.new(1), { StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0) }):Play()
	task.delay(0.75, function()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(1.1, function()
		anchor:Destroy()
	end)
end

------------------------------------------------------------------------
-- The guard dog

-- Its alert: a gold ! popping up over its head, going where the dog goes.
-- (Gold, not the red ! that marks a Suspect: the dog's warning you, it isn't one.)
local ALERT_SIZE = 52
local ALERT_SPOT = CFrame.new(0, 3, -1.2) -- from its feet: over its head (it faces −Z)
local function alertMark(dog: Model, state)
	if state.mark then
		state.mark:Destroy()
	end
	local body = dog.PrimaryPart or dog:FindFirstChildWhichIsA("BasePart", true)
	if not body then
		return
	end
	local spot = UI.make("Attachment", { Name = "DogAlert", Position = body.CFrame:PointToObjectSpace((state.pivot * ALERT_SPOT).Position), Parent = body })
	local gui = UI.make("BillboardGui", {
		Adornee = spot, Size = UDim2.fromOffset(ALERT_SIZE, ALERT_SIZE), MaxDistance = 200, LightInfluence = 0, Parent = spot,
	})
	local disc = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.3, 0.3), BackgroundColor3 = C.gold, Parent = gui,
	}, { UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.stroke(C.cream, 3) })
	UI.make("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = UI.HEAD, TextScaled = true, Text = "!", TextColor3 = C.soilDark, Parent = disc,
	})
	state.mark = spot
	TweenService:Create(disc, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.92, 0.92) }):Play()
	task.delay(1.1, function()
		if state.mark == spot then
			state.mark = nil
		end
		spot:Destroy()
	end)
end

local dogs = {} -- [Model] = { home, pivot, ground, phase ("rest" · "run" · "hold" · "home"), reachedAt, chaseAt, lastBark, step }

local function groundAt(position: Vector3, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
	return if hit then hit.Position.Y else position.Y
end

local function dogState(dog: Model)
	local state = dogs[dog]
	if state then
		return state
	end
	local home = dog:GetAttribute("Home")
	if typeof(home) ~= "CFrame" then
		return nil
	end
	state = { home = home, pivot = home, ground = home.Position.Y, phase = "rest", chaseAt = 0, lastBark = 0, step = 0 }
	for _, part in dog:GetChildren() do
		if part:IsA("BasePart") then
			part:SetAttribute("DogRest", home:ToObjectSpace(part.CFrame))
		end
	end
	dogs[dog] = state
	return state
end

-- A trot: the front leg on one side goes with the back leg on the other.
local function legPhase(rest: CFrame): number
	return if (rest.Position.X > 0) ~= (rest.Position.Z > 0) then math.pi else 0
end

-- Moves the dog to `pivot` (its feet, facing its −Z), legs swinging by `stride`.
local function placeDog(dog: Model, state, pivot: CFrame, stride: number)
	state.pivot = pivot
	for _, part in dog:GetChildren() do
		if part:IsA("BasePart") then
			local rest = part:GetAttribute("DogRest")
			if typeof(rest) == "CFrame" then
				local frame = pivot * rest
				if part.Name == "DogLeg" and stride > 0 then
					local top = part.Size.Y / 2 -- (swung from the hip)
					frame *= CFrame.new(0, top, 0) * CFrame.Angles(math.sin(state.step + legPhase(rest)) * stride, 0, 0) * CFrame.new(0, -top, 0)
				end
				part.CFrame = frame
			end
		end
	end
end

local function updateDog(dog: Model, state, dt: number)
	local t = now()
	local chaseAt = dog:GetAttribute("ChaseAt") or 0
	if chaseAt ~= state.chaseAt and t - chaseAt < 8 then
		state.chaseAt, state.phase, state.reachedAt = chaseAt, "run", nil
	end
	if state.phase == "rest" then
		return
	end
	local thief = Players:GetPlayerByUserId(dog:GetAttribute("Chase") or 0)
	local target = rootOf(thief)
	local pos = state.pivot.Position
	local goal, speed = nil, Defences.DOG_RUN
	if state.phase == "run" then
		if not target or t - state.chaseAt > 6 then
			state.phase = "home"
		else
			local to = Vector3.new(target.Position.X, pos.Y, target.Position.Z)
			if (to - pos).Magnitude < 2.8 then
				state.phase, state.reachedAt = "hold", t
			else
				goal = to
			end
		end
	end
	if state.phase == "hold" then
		if not target or t - (state.reachedAt or t) > Crime.DOG_SLOW_SECONDS then
			state.phase = "home"
		else
			local to = Vector3.new(target.Position.X, pos.Y, target.Position.Z)
			if (to - pos).Magnitude > 3.4 then
				goal = to -- (keeping up with them)
			end
			if t - state.lastBark > 0.9 then
				state.lastBark = t
				alertMark(dog, state)
			end
			if not goal then
				-- at their heels, jumping and barking
				local look = if (to - pos).Magnitude > 0.1 then CFrame.lookAt(pos, to) else state.pivot
				local hop = math.abs(math.sin(t * 9)) * 0.35
				placeDog(dog, state, look.Rotation + Vector3.new(pos.X, state.ground + hop, pos.Z), 0)
				return
			end
		end
	end
	if state.phase == "home" then
		local home = state.home.Position
		local flatHome = Vector3.new(home.X, pos.Y, home.Z)
		if (flatHome - pos).Magnitude < 0.6 then
			state.phase = "rest"
			state.ground = home.Y
			placeDog(dog, state, state.home, 0)
			return
		end
		goal, speed = flatHome, Defences.DOG_RUN * 0.55 -- (a trot home)
	end
	if not goal then
		return
	end
	local offset = goal - pos
	local nextPos = pos + offset.Unit * math.min(offset.Magnitude, speed * dt)
	state.ground = groundAt(nextPos, { dog, if thief and thief.Character then thief.Character else dog })
	nextPos = Vector3.new(nextPos.X, state.ground, nextPos.Z)
	state.step += dt * speed * 0.9
	placeDog(dog, state, CFrame.lookAt(nextPos, nextPos + Vector3.new(offset.X, 0, offset.Z)), 0.6)
end

local function findDogs()
	local w = world()
	if not w then
		return
	end
	local seen = {}
	for index = 1, PlotLayout.COUNT do
		local model = w:FindFirstChild(`Plot{index}`)
		local defences = model and model:FindFirstChild("Defences")
		local holder = defences and defences:FindFirstChild("GuardDog")
		local dog = holder and holder:FindFirstChild("Dog")
		if dog then
			seen[dog] = true
			dogState(dog)
		end
	end
	for dog in dogs do
		if not seen[dog] then
			dogs[dog] = nil
		end
	end
end

------------------------------------------------------------------------
-- The alarm light, the gate's flag, the spotlight, the domes

local spin = 0
local flags = {} -- [BasePart] = its own colour

local function updateLights(dt: number)
	local w = world()
	if not w then
		return
	end
	local t = now()
	spin = (spin + dt * 7) % (math.pi * 2)
	for index = 1, PlotLayout.COUNT do
		local model = w:FindFirstChild(`Plot{index}`)
		if not model then
			continue
		end
		local on = (model:GetAttribute("AlarmUntil") or 0) > t
		local beacon = model:FindFirstChild("AlarmBeacon")
		local glass = beacon and beacon:FindFirstChild("BeaconGlass")
		if glass then
			local rest = glass:GetAttribute("Rest")
			if typeof(rest) ~= "CFrame" then
				rest = glass.CFrame
				glass:SetAttribute("Rest", rest)
			end
			local beam = glass:FindFirstChild("Beam")
			if on then
				glass.Material = Enum.Material.Neon
				glass.Color = ALARM_RED
				glass.CFrame = CFrame.new(rest.Position) * CFrame.Angles(0, spin, 0) * rest.Rotation
				if beam then
					beam.Brightness = 6
				end
			elseif glass.Material ~= Enum.Material.Glass then
				glass.Material = Enum.Material.Glass
				glass.Color = DARK_RED
				glass.CFrame = rest
				if beam then
					beam.Brightness = 0
				end
			end
		end
		local arch = model:FindFirstChild("GateArch")
		local flag = arch and arch:FindFirstChild("Flag")
		if flag then
			flags[flag] = flags[flag] or flag.Color
			flag.Color = if on and math.floor(t * 4) % 2 == 0 then ALARM_RED else flags[flag]
		end
		-- the Watchman's spotlight
		local gatehouse = model:FindFirstChild("Gatehouse")
		local beamPart = gatehouse and gatehouse:FindFirstChild("SpotBeam")
		if beamPart then
			local light = beamPart:FindFirstChild("Beam")
			local target = (gatehouse:GetAttribute("SpotUntil") or 0) > t and rootOf(Players:GetPlayerByUserId(gatehouse:GetAttribute("SpotOn") or 0))
			local lamp = gatehouse:FindFirstChild("Spotlight")
			local mount = beamPart:GetAttribute("Mount")
			if typeof(mount) ~= "CFrame" then
				mount = beamPart.CFrame
				beamPart:SetAttribute("Mount", mount)
				if lamp then
					lamp:SetAttribute("Rest", mount:ToObjectSpace(lamp.CFrame))
				end
			end
			local aim = if target then CFrame.lookAt(mount.Position, target.Position) else mount
			beamPart.CFrame = aim
			if lamp and typeof(lamp:GetAttribute("Rest")) == "CFrame" then
				lamp.CFrame = aim * lamp:GetAttribute("Rest")
			end
			if light then
				light.Brightness = if target then 9 else 0
			end
		end
	end
end

local function updateDomes()
	local w = world()
	if not w then
		return
	end
	local t = now()
	for index = 1, PlotLayout.COUNT do
		local model = w:FindFirstChild(`Plot{index}`)
		local dome = model and model:FindFirstChild("Dome")
		local sign = dome and dome:FindFirstChild("DomeSign")
		local label = sign and sign:FindFirstChild("Text")
		if label then
			local left = math.max(0, (dome:GetAttribute("Ends") or t) - t)
			label.Text = `{dome:GetAttribute("Title") or ""}\n{UI.formatTime(left)}`
		end
	end
end

-- The Watchman rings his bell: it swings, DING DING!
local function ringBell(index: number)
	local model = plotModel(index)
	local gatehouse = model and model:FindFirstChild("Gatehouse")
	local bell = gatehouse and gatehouse:FindFirstChild("AlarmBell")
	if not bell or not bell:IsA("BasePart") then
		return
	end
	local rest = bell:GetAttribute("Rest")
	if typeof(rest) ~= "CFrame" then
		rest = bell.CFrame
		bell:SetAttribute("Rest", rest)
	end
	popText(rest.Position + Vector3.new(0, 2.5, 0), "DING DING!", C.gold)
	Sfx.play("AlarmBell", bell)
	task.spawn(function()
		local started = os.clock()
		local top = bell.Size.Y / 2
		while os.clock() - started < 2.4 and bell.Parent do
			local a = math.sin((os.clock() - started) * 16) * 0.55 * (1 - (os.clock() - started) / 2.6)
			bell.CFrame = rest * CFrame.new(0, top, 0) * CFrame.Angles(a, 0, 0) * CFrame.new(0, -top, 0)
			RunService.Heartbeat:Wait()
		end
		if bell.Parent then
			bell.CFrame = rest
		end
	end)
end

------------------------------------------------------------------------

function WatchController.Start()
	Remotes.event("DefenceEvent").OnClientEvent:Connect(function(kind, info)
		if kind == "Bell" and info and info.plot then
			ringBell(info.plot)
		elseif kind == "Bark" and info and info.plot then
			for dog, state in dogs do
				local model = plotModel(info.plot)
				if model and dog:IsDescendantOf(model) then
					alertMark(dog, state)
					Sfx.at("DogAlert", state.pivot.Position)
				end
			end
		end
	end)
	local found, domes = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		found += dt
		domes += dt
		if found > 1 then
			found = 0
			pcall(findDogs)
		end
		if domes > 0.5 then
			domes = 0
			pcall(updateDomes)
		end
		local ok, err = pcall(function()
			for dog, state in dogs do
				if dog.Parent then
					updateDog(dog, state, dt)
				end
			end
			updateLights(dt)
		end)
		if not ok then
			warn(`[WatchController] {err}`)
		end
	end)
end

return WatchController
