-- Drives every farm's trucks to the City and back (docs/GameDesign.md §4.6)
-- from each truck's DepartAt / ArriveAt / ReturnAt attributes
-- (TruckService): out of its dock's lane, round the ring road the short way,
-- up the highway into the tunnel; out of sight in the City; then the same
-- way home, backing up to the dock at the end. Each lane's striped boom
-- lifts as its truck goes through. Only this client's copy moves: the
-- server's trucks stay parked. The warehouse side is rebuilt as farms level
-- up, so trucks are found again whenever their models change.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlotLayout = require(ReplicatedStorage:WaitForChild("Shared").PlotLayout)

local TruckController = {}

local SPEED = 40 -- studs a second (faster if a route wouldn't fit in half the trip)
local BOOM_UP = math.rad(80)
local BOOM_NEAR = 24 -- studs from the gate that lift the boom
local HIDDEN = CFrame.new(0, -40, PlotLayout.HIGHWAY.to + 40) -- (underground beyond the tunnel)

local trucks = {} -- [truck Model] = { boom, hinge, parked, route, length, firstLeg, lift, gate, angle, home }

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
	}
end

-- Where a truck is at server time t, or nil when it's parked.
local function place(farm, truck: Model, t: number): CFrame?
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
	-- Nose first both ways, except backing up the lane at the end.
	local facing = if outbound or distance <= farm.firstLeg then direction else -direction
	local at = position + Vector3.new(0, farm.lift, 0)
	return CFrame.lookAt(at, at + facing)
end

local function step(dt: number)
	local t = workspace:GetServerTimeNow()
	for truck, farm in trucks do
		if not truck.Parent then
			trucks[truck] = nil -- (the warehouse was rebuilt: its new trucks are tracked)
			continue
		end
		local cframe = place(farm, truck, t)
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
