-- Draws the NPC shoppers in every store (docs/ArtDirection.md §8) from the
-- ShopperEvent remote (StoreService decides what they do). Each "Path" is a
-- walk from server time `at` through world points at Shop.SPEED, replacing
-- the last one: along the sidewalk, through the door, down the aisles to a
-- display, into a checkout queue, out again. They say what happened in a
-- bubble ("🥕×3", "Too dear!"), their basket fills up, and a coin pop shows
-- when they pay. Blocky people in varied colours, made of local parts:
-- nothing here matters to the game.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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
local CULL = 300 -- studs from the camera: farther shoppers aren't drawn (a busy Supermarket has 24, and there are 8 stores)

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
	local goods = piece(model, "Goods", Vector3.new(1.2, 0.3, 0.8), Color3.fromRGB(226, 120, 60))
	goods.Transparency = 1
	table.insert(parts, { goods, CFrame.new(1.45, 2.75, -0.4) })
	local bubble = Instance.new("BillboardGui")
	bubble.Size = UDim2.fromScale(6, 1.6)
	bubble.StudsOffsetWorldSpace = Vector3.new(0, 4.1, 0) -- (under a Corner Store's 10-stud ceiling)
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
	return model, parts, bubble, label, basket, goods
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function say(shopper, text: string, color: Color3?)
	shopper.label.Text = text
	shopper.label.BackgroundColor3 = color or Color3.fromRGB(255, 244, 220)
	shopper.bubble.Enabled = true
	shopper.sayToken += 1
	local token = shopper.sayToken
	task.delay(2.6, function()
		if shopper.sayToken == token then
			shopper.bubble.Enabled = false
		end
	end)
end

local function path(event)
	local shopper = shoppers[event.id]
	if not shopper then
		local model, parts, bubble, label, basket, goods = build(event.look)
		shopper = { model = model, parts = parts, bubble = bubble, label = label, basket = basket, goods = goods, plot = event.plot, sayToken = 0 }
		shoppers[event.id] = shopper
	end
	shopper.points = event.points
	shopper.at = event.at
	shopper.length = PlotLayout.pathLength(event.points)
	shopper.face = event.face
	shopper.leave = event.leave == true
	local units = event.basket or 0
	shopper.basket.Transparency = if units > 0 then 0 else 1
	shopper.goods.Transparency = if units > 0 then 0 else 1
	shopper.goods.Size = Vector3.new(1.2, 0.15 + math.min(units, 12) * 0.04, 0.8)
	if event.say then
		say(shopper, event.say)
	end
end

local function paid(event)
	local shopper = shoppers[event.id]
	if shopper and event.coins > 0 then
		say(shopper, `+{event.coins}`, Color3.fromRGB(242, 179, 61))
	end
end

local function clear(event)
	for id, shopper in shoppers do
		if shopper.plot == event.plot then
			shopper.model:Destroy()
			shoppers[id] = nil
		end
	end
end

local function step()
	local t = now()
	local eye = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or Vector3.zero
	for id, shopper in shoppers do
		local walked = math.max(0, (t - shopper.at) * Shop.SPEED)
		local walking = walked > 0 and walked < shopper.length
		if (shopper.leave and walked >= shopper.length + FADE * Shop.SPEED) or t - shopper.at > 240 then
			shopper.model:Destroy()
			shoppers[id] = nil
			continue
		end
		local position, direction = PlotLayout.along(shopper.points, math.min(walked, shopper.length))
		local near = (position - eye).Magnitude < CULL
		shopper.model.Parent = if near then folder else nil
		if not near then
			continue
		end
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if not walking and shopper.face and not shopper.leave then
			local toward = shopper.face - position
			flat = Vector3.new(toward.X, 0, toward.Z)
		end
		local heading = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
		local feet = CFrame.lookAt(position, position + heading)
		local swing = if walking then math.sin(t * 9) * math.rad(28) else 0
		local fade = if shopper.leave then math.clamp((walked - shopper.length) / (FADE * Shop.SPEED), 0, 1) else 0
		for _, entry in shopper.parts do
			local p, offset, isLeg = entry[1], entry[2], entry[3]
			local pose = offset
			if isLeg then
				local sign = if p.Name == "LegL" then 1 else -1
				pose = CFrame.new(offset.X, 2.2, 0) * CFrame.Angles(swing * sign, 0, 0) * CFrame.new(0, -1.1, 0)
			end
			p.CFrame = feet * pose
			if (p.Name ~= "Basket" and p.Name ~= "Goods") or p.Transparency < 1 then
				p.Transparency = fade
			end
		end
	end
end

function ShopperController.Start()
	folder.Parent = workspace
	Remotes.event("ShopperEvent").OnClientEvent:Connect(function(kind, event)
		if kind == "Path" then
			path(event)
		elseif kind == "Paid" then
			paid(event)
		elseif kind == "Clear" then
			clear(event)
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return ShopperController
