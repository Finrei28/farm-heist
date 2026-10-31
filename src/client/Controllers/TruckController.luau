-- Drives every farm's pickup to the City and back (docs/GameDesign.md §4.6)
-- from its DepartAt / ArriveAt / ReturnAt attributes (TruckService): out of
-- the driveway, round the ring road the short way, up the highway into the
-- tunnel; out of sight in the City; then the same way home, backing up to
-- the dock at the end. Each farm's striped boom lifts as its truck goes
-- through. Only this client's copy moves: the server's truck stays parked.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlotLayout = require(ReplicatedStorage:WaitForChild("Shared").PlotLayout)

local TruckController = {}

local SPEED = 40 -- studs a second (faster if a route wouldn't fit in half the trip)
local BOOM_UP = math.rad(80)
local BOOM_NEAR = 24 -- studs from the gate that lift the boom
local HIDDEN = CFrame.new(0, -40, PlotLayout.HIGHWAY.to + 40) -- (underground beyond the tunnel)

local farms = {} -- { truck, boom, hinge, parked, route, length, firstLeg, lift, gate, angle }

local function track(index: number)
	local plot = workspace.World:WaitForChild(`Plot{index}`)
	local truck = plot:WaitForChild("Truck")
	local boom = plot:WaitForChild("TruckGate"):WaitForChild("Boom")
	local route = PlotLayout.truckRoute(index)
	local parked = truck:GetPivot()
	local P = PlotLayout.PLOT
	table.insert(farms, {
		truck = truck,
		boom = boom,
		hinge = boom:GetPivot(),
		parked = parked,
		route = route,
		length = PlotLayout.pathLength(route),
		firstLeg = (route[2] - route[1]).Magnitude,
		lift = parked.Position.Y - route[1].Y,
		gate = PlotLayout.toWorld(index, Vector3.new((P.driveway.min.X + P.driveway.max.X) / 2, 0, -0.5)),
		angle = 0,
		home = true,
	})
end

-- Where a truck is at server time t, or nil when it's parked.
local function place(farm, t: number): CFrame?
	local truck = farm.truck
	local departAt = truck:GetAttribute("DepartAt") or 0
	local arriveAt = truck:GetAttribute("ArriveAt") or 0
	local returnAt = truck:GetAttribute("ReturnAt") or 0
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
	-- Nose first both ways, except backing up the driveway at the end.
	local facing = if outbound or distance <= farm.firstLeg then direction else -direction
	local at = position + Vector3.new(0, farm.lift, 0)
	return CFrame.lookAt(at, at + facing)
end

local function step(dt: number)
	local t = workspace:GetServerTimeNow()
	for _, farm in farms do
		local cframe = place(farm, t)
		if cframe then
			farm.truck:PivotTo(cframe)
			farm.home = false
		elseif not farm.home then
			farm.truck:PivotTo(farm.parked)
			farm.home = true
		end
		local near = (farm.truck:GetPivot().Position - farm.gate).Magnitude < BOOM_NEAR and not farm.home
		local target = if near then BOOM_UP else 0
		if math.abs(farm.angle - target) > 1e-3 then
			farm.angle += math.clamp(target - farm.angle, -dt * 3, dt * 3)
			farm.boom:PivotTo(farm.hinge * CFrame.Angles(0, 0, farm.angle))
		end
	end
end

function TruckController.Start()
	local world = workspace:WaitForChild("World")
	world:WaitForChild(`Plot{PlotLayout.COUNT}`)
	for index = 1, PlotLayout.COUNT do
		track(index)
	end
	RunService.Heartbeat:Connect(step)
end

return TruckController
