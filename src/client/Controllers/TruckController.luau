-- Drives every farm's trucks to the City and back (docs/GameDesign.md §4.6)
-- from each truck's DepartAt / ArriveAt / ReturnAt attributes
-- (TruckService): out of its dock's lane, round the ring road the short way,
-- up the highway into the tunnel; out of sight in the City; then the same
-- way home, backing up to the dock at the end. Each lane's striped boom
-- lifts as its truck goes through. Only this client's copy moves: the
-- server's trucks stay parked. The warehouse side is rebuilt as farms level
-- up, so trucks are found again whenever their models change.
--
-- Trucks are solid, so a truck never drives through anyone: it stops (and
-- beeps) while someone stands in its way or in its bed, then makes up the
-- time at half as fast again. The trip's timing is the server's: only the
-- picture waits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlotLayout = require(ReplicatedStorage:WaitForChild("Shared").PlotLayout)

local TruckController = {}

local SPEED = 40 -- studs a second (faster if a route wouldn't fit in half the trip)
local BOOM_UP = math.rad(80)
local BOOM_NEAR = 24 -- studs from the gate that lift the boom
local HIDDEN = CFrame.new(0, -40, PlotLayout.HIGHWAY.to + 40) -- (underground beyond the tunnel)
local CLEAR_AHEAD = 6 -- studs in front of a truck that must be clear for it to move
local CLEAR_SIDE = 5.6 -- studs from its middle line (it's 8.8 wide)
local CATCH_UP = 0.5 -- extra share of speed while making up lost time

local trucks = {} -- [truck Model] = { boom, hinge, parked, route, length, firstLeg, lift, gate, angle, home, late, beep }

local function track(index: number, truck: Model)
	local warehouse = truck.Parent and truck.Parent.Parent
	local dock = truck:GetAttribute("Dock") or 1
	local gate = warehouse and warehouse:FindFirstChild("Lanes") and warehouse.Lanes:FindFirstChild(`Gate{dock}`)
	local boom = gate and gate:FindFirstChild("Boom")
	local across = gate and gate:GetAttribute("Across") or PlotLayout.WAREHOUSES[1].docks[1]
	local route = PlotLayout.truckRoute(index, across, truck:GetAttribute("Length"))
	local parked = truck:GetPivot()
	trucks[truck] = {
		boom = boom,
		hinge = boom and boom:GetPivot(),
		parked = parked,
		route = route,
		length = PlotLayout.pathLength(route),
		firstLeg = (route[2] - route[1]).Magnitude,
		lift = parked.Position.Y - route[1].Y,
		gate = PlotLayout.toWorld(index, Vector3.new(across, 0, -0.5)),
		angle = 0,
		home = true,
		late = 0, -- seconds behind the server's timing (waiting for people)
	}
end

-- "BEEP BEEP!" over the cab while a truck waits for someone to move.
local function beep(farm, truck: Model, on: boolean)
	if on and not farm.beep then
		local gui = Instance.new("BillboardGui")
		gui.Name = "Beep"
		gui.Size = UDim2.fromOffset(150, 44)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 11, 0)
		gui.MaxDistance = 120
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(255, 244, 220)
		label.TextColor3 = Color3.fromRGB(200, 69, 45)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = "BEEP BEEP!"
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = label
		local padding = Instance.new("UIPadding")
		padding.PaddingTop, padding.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
		padding.Parent = label
		label.Parent = gui
		gui.Adornee = truck:FindFirstChild("Cab") or truck:FindFirstChildWhichIsA("BasePart")
		gui.Parent = truck
		farm.beep = gui
	elseif not on and farm.beep then
		farm.beep:Destroy()
		farm.beep = nil
	end
end

-- Whether anyone stands where a truck at `at`, moving along `direction`,
-- is about to go (`clear` studs past its end), or in its bed, or on it.
local function inTheWay(at: CFrame, direction: Vector3, length: number, clear: number): boolean
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local offset = root.Position - at.Position
			local ahead = offset:Dot(direction)
			local side = (offset - direction * ahead) * Vector3.new(1, 0, 1)
			if math.abs(offset.Y) < 14 and side.Magnitude < CLEAR_SIDE and ahead > -length / 2 - 1 and ahead < length / 2 + clear then
				return true
			end
		end
	end
	return false
end

-- The trip under way ({ departAt, arriveAt, returnAt }, from the truck's
-- attributes), kept on this client while the truck is running late: the
-- server clears the attributes once the trip's time is up, and a truck
-- still waiting for someone mustn't jump home through them.
local function tripOf(farm, truck: Model)
	local returnAt = truck:GetAttribute("ReturnAt") or 0
	if returnAt > 0 then
		local departAt = truck:GetAttribute("DepartAt") or 0
		if farm.trip and farm.trip.departAt ~= departAt then
			farm.late = 0 -- (a new trip: back on time)
		end
		farm.trip = { departAt = departAt, arriveAt = truck:GetAttribute("ArriveAt") or 0, returnAt = returnAt }
	elseif farm.late <= 0 then
		farm.trip = nil
	end
	return farm.trip
end

-- Where a truck is at server time t on a trip, or nil when it's parked.
local function place(farm, trip, t: number): CFrame?
	if not trip then
		return nil
	end
	local departAt, arriveAt, returnAt = trip.departAt, trip.arriveAt, trip.returnAt
	if returnAt <= 0 or t >= returnAt or t < departAt then
		return nil
	end
	local speed = math.max(SPEED, farm.length / math.max(1, (arriveAt - departAt) * 0.9))
	local drive = farm.length / speed
	local distance, outbound
	if t < departAt + drive then
		distance, outbound = (t - departAt) * speed, true
	elseif t < returnAt - drive then
		return HIDDEN
	else
		distance, outbound = (returnAt - t) * speed, false
	end
	local position, direction = PlotLayout.along(farm.route, distance)
	-- Nose first both ways, except backing up the lane at the end.
	local facing = if outbound or distance <= farm.firstLeg then direction else -direction
	local at = position + Vector3.new(0, farm.lift, 0)
	return CFrame.lookAt(at, at + facing)
end

local function step(dt: number)
	local now = workspace:GetServerTimeNow()
	for truck, farm in trucks do
		if not truck.Parent then
			trucks[truck] = nil -- (the warehouse was rebuilt: its new trucks are tracked)
			continue
		end
		local trip = tripOf(farm, truck)
		local cframe = place(farm, trip, now - farm.late)
		local waiting = false
		if cframe and cframe ~= HIDDEN then
			-- stop for anyone in the way; otherwise drive, making up lost time
			local nextAt = place(farm, trip, now - farm.late + 0.1)
			local moving = if nextAt and nextAt ~= HIDDEN then (nextAt.Position - cframe.Position) * Vector3.new(1, 0, 1) else nil
			-- (backing up to the dock it only needs the room left to go: people on the dock are fine)
			local left = (cframe.Position - farm.parked.Position).Magnitude
			local clear = if nextAt and (nextAt.Position - farm.parked.Position).Magnitude < left then math.min(CLEAR_AHEAD, left + 0.5) else CLEAR_AHEAD
			if moving and moving.Magnitude > 1e-3 and inTheWay(truck:GetPivot(), moving.Unit, truck:GetAttribute("Length") or 20, clear) then
				waiting = true
				farm.late += dt
				cframe = place(farm, trip, now - farm.late)
			elseif farm.late > 0 then
				farm.late = math.max(0, farm.late - dt * CATCH_UP)
			end
		else
			farm.late = 0 -- (out of sight or parked: back on time)
		end
		beep(farm, truck, waiting and farm.late > 0.4)
		if cframe then
			truck:PivotTo(cframe)
			farm.home = false
		elseif not farm.home then
			truck:PivotTo(farm.parked)
			farm.home = true
		end
		if farm.boom then
			local near = (truck:GetPivot().Position - farm.gate).Magnitude < BOOM_NEAR and not farm.home
			local target = if near then BOOM_UP else 0
			if math.abs(farm.angle - target) > 1e-3 then
				farm.angle += math.clamp(target - farm.angle, -dt * 3, dt * 3)
				farm.boom:PivotTo(farm.hinge * CFrame.Angles(0, 0, farm.angle))
			end
		end
	end
end

-- Finds a farm's trucks now and whenever its warehouse side is rebuilt (a
-- truck is a persistent model: it arrives whole, never part by part).
local function watch(index: number, plot: Model)
	local function add(truck: Instance)
		if truck:IsA("Model") and not trucks[truck] then
			track(index, truck)
		end
	end
	local function warehouseAdded(warehouse: Instance)
		if warehouse.Name ~= "Warehouse" then
			return
		end
		local folder = warehouse:WaitForChild("Trucks", 10)
		if folder then
			folder.ChildAdded:Connect(add)
			for _, truck in folder:GetChildren() do
				add(truck)
			end
		end
	end
	plot.ChildAdded:Connect(warehouseAdded)
	local warehouse = plot:FindFirstChild("Warehouse")
	if warehouse then
		task.spawn(warehouseAdded, warehouse)
	end
end

function TruckController.Start()
	local world = workspace:WaitForChild("World")
	world:WaitForChild(`Plot{PlotLayout.COUNT}`)
	for index = 1, PlotLayout.COUNT do
		watch(index, world[`Plot{index}`])
	end
	RunService.Heartbeat:Connect(step)
end

return TruckController
