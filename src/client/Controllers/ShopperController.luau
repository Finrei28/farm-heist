-- Draws the NPC shoppers at every Farm Stand (docs/ArtDirection.md §8) from
-- the ShopperEvent remote (ShopService decides what they do). Each one walks
-- the sidewalk to the stand (shared/PlotLayout.shopperRoute), waits at the
-- counter until the server says how it went, shows it (a basket and the
-- coins they paid, or a face at the price), then walks on and fades away.
-- Blocky people in varied colours, made of local parts: nothing here
-- matters to the game.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared.Config.Crops)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local Shop = require(Shared.Config.Shop)

local ShopperController = {}

local SHIRTS = {
	Color3.fromRGB(91, 182, 240), Color3.fromRGB(200, 69, 45), Color3.fromRGB(242, 179, 61), Color3.fromRGB(78, 159, 61),
	Color3.fromRGB(160, 92, 240), Color3.fromRGB(240, 120, 160), Color3.fromRGB(255, 244, 220), Color3.fromRGB(64, 120, 180),
}
local SKIN = { Color3.fromRGB(255, 220, 177), Color3.fromRGB(234, 192, 134), Color3.fromRGB(198, 134, 66), Color3.fromRGB(141, 85, 36), Color3.fromRGB(96, 60, 30) }
local LEGS = { Color3.fromRGB(58, 72, 110), Color3.fromRGB(70, 60, 50), Color3.fromRGB(40, 44, 48), Color3.fromRGB(120, 100, 80) }
local FADE = 1

local folder = Instance.new("Folder")
folder.Name = "Shoppers"
local shoppers = {} -- [id] = shopper

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

-- A blocky shopper: each part with its offset from the feet.
local function build(look: number)
	local rng = Random.new(look)
	local model = Instance.new("Model")
	model.Name = "Shopper"
	local shirt = SHIRTS[rng:NextInteger(1, #SHIRTS)]
	local skin = SKIN[rng:NextInteger(1, #SKIN)]
	local legs = LEGS[rng:NextInteger(1, #LEGS)]
	local parts = {
		{ piece(model, "LegL", Vector3.new(0.9, 2.2, 0.9), legs), CFrame.new(-0.5, 1.1, 0), true },
		{ piece(model, "LegR", Vector3.new(0.9, 2.2, 0.9), legs), CFrame.new(0.5, 1.1, 0), true },
		{ piece(model, "Body", Vector3.new(2.1, 2.3, 1.1), shirt), CFrame.new(0, 3.35, 0) },
		{ piece(model, "ArmL", Vector3.new(0.7, 2.1, 0.7), shirt), CFrame.new(-1.45, 3.4, 0) },
		{ piece(model, "ArmR", Vector3.new(0.7, 2.1, 0.7), shirt), CFrame.new(1.45, 3.4, 0) },
		{ piece(model, "Head", Vector3.new(1.6, 1.6, 1.6), skin, Enum.PartType.Ball), CFrame.new(0, 5.3, 0) },
	}
	if rng:NextNumber() < 0.45 then
		table.insert(parts, { piece(model, "Hat", Vector3.new(0.5, 2.2, 2.2), SHIRTS[rng:NextInteger(1, #SHIRTS)], Enum.PartType.Cylinder), CFrame.new(0, 6.15, 0) * CFrame.Angles(0, 0, math.rad(90)) })
	end
	local basket = piece(model, "Basket", Vector3.new(1.4, 0.8, 1), Color3.fromRGB(196, 150, 84))
	basket.Transparency = 1
	table.insert(parts, { basket, CFrame.new(1.45, 2.3, -0.4) })
	local bubble = Instance.new("BillboardGui")
	bubble.Size = UDim2.fromScale(6, 1.6)
	bubble.StudsOffsetWorldSpace = Vector3.new(0, 7.4, 0)
	bubble.MaxDistance = 90
	bubble.Enabled = false
	bubble.Adornee = parts[3][1]
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(255, 244, 220)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(58, 42, 28)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = label
	label.Parent = bubble
	bubble.Parent = model
	model.Parent = folder
	return model, parts, bubble, label, basket
end

local function arrive(event)
	if shoppers[event.id] then
		return
	end
	local route, counter = PlotLayout.shopperRoute(event.plot, event.lane)
	local model, parts, bubble, label, basket = build(event.look)
	shoppers[event.id] = {
		model = model, parts = parts, bubble = bubble, label = label, basket = basket,
		route = route, at = event.at, length = PlotLayout.pathLength(route),
		counterAt = PlotLayout.pathLength(route, counter), leaveAt = nil,
	}
end

local function done(event)
	local shopper = shoppers[event.id]
	if not shopper then
		return
	end
	local t = workspace:GetServerTimeNow()
	shopper.leaveAt = math.max(t, shopper.at + shopper.counterAt / Shop.SHOPPER_SPEED) + Shop.SHOPPER_BROWSE
	local crop = event.crop and Crops.ById[event.crop]
	if crop and event.units > 0 then
		shopper.label.Text = `🧺 {crop.icon or ""}×{event.units}  +{event.coins}`
		shopper.basket.Transparency = 0
		shopper.bubble.Enabled = true
	elseif crop then
		shopper.label.Text = `😟 {crop.icon or ""} too dear!`
		shopper.bubble.Enabled = true
	end
	task.delay(Shop.SHOPPER_BROWSE + 1.5, function()
		shopper.bubble.Enabled = false
	end)
end

local function step()
	local t = workspace:GetServerTimeNow()
	for id, shopper in shoppers do
		local walked = (t - shopper.at) * Shop.SHOPPER_SPEED
		local walking = true
		if shopper.leaveAt then
			if t < shopper.leaveAt then
				walked = math.min(walked, shopper.counterAt)
				walking = walked < shopper.counterAt
			else
				walked = shopper.counterAt + (t - shopper.leaveAt) * Shop.SHOPPER_SPEED
			end
		elseif walked >= shopper.counterAt then
			walked, walking = shopper.counterAt, false -- (waiting at the counter for the server)
		end
		if walked >= shopper.length + FADE * Shop.SHOPPER_SPEED or t - shopper.at > 120 then
			shopper.model:Destroy()
			shoppers[id] = nil
		else
			-- (at the counter this is the way they stepped up to it: facing the stand)
			local position, direction = PlotLayout.along(shopper.route, walked)
			local flat = Vector3.new(direction.X, 0, direction.Z)
			local feet = CFrame.lookAt(position + Vector3.new(0, 0.3, 0), position + Vector3.new(0, 0.3, 0) + (if flat.Magnitude > 0 then flat.Unit else Vector3.zAxis))
			local swing = if walking then math.sin(t * 9) * math.rad(28) else 0
			local fade = math.clamp((walked - shopper.length) / (FADE * Shop.SHOPPER_SPEED), 0, 1)
			for _, entry in shopper.parts do
				local p, offset, isLeg = entry[1], entry[2], entry[3]
				local pose = offset
				if isLeg then
					local sign = if p.Name == "LegL" then 1 else -1
					pose = CFrame.new(offset.X, 2.2, 0) * CFrame.Angles(swing * sign, 0, 0) * CFrame.new(0, -1.1, 0)
				end
				p.CFrame = feet * pose
				if p.Name ~= "Basket" or shopper.basket.Transparency < 1 then
					p.Transparency = fade
				end
			end
		end
	end
end

function ShopperController.Start()
	folder.Parent = workspace
	Remotes.event("ShopperEvent").OnClientEvent:Connect(function(kind, event)
		if kind == "Arrive" then
			arrive(event)
		elseif kind == "Done" then
			done(event)
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return ShopperController
