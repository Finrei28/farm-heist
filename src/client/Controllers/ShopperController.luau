-- Draws the NPC shoppers in every store (docs/ArtDirection.md §8) from the
-- ShopperEvent remote (StoreService decides what they do). Each "Path" is a
-- walk from server time `at` through world points at Shop.SPEED, replacing
-- the last one: along the sidewalk, through the door, down the aisles to a
-- display, into a checkout queue, out again. They say what happened in a
-- bubble ("🥕×3", "Too dear!"), their basket fills with what they picked,
-- and a coin pop shows when they pay; the bell over the door rings as they
-- come in. Roblox-shaped people in all sorts of
-- outfits (client/People), made of local parts: nothing here matters to the game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local Shop = require(Shared.Config.Shop)
local Store = require(Shared.Config.Store)
local Bubbles = require(script.Parent.Parent.Bubbles)
local People = require(script.Parent.Parent.People)
local Sfx = require(script.Parent.Parent.Sfx)

local ShopperController = {}

-- Who comes shopping (docs/ArtDirection.md §8): Roblox-shaped people in all
-- sorts of outfits with a wicker basket, built by client/People from their
-- `look` number (the farm crews share the body).

-- What a basket shows: each crop's colour (big ones fill it alone).
local PRODUCE = {
	Carrot = Color3.fromRGB(240, 130, 40), Wheat = Color3.fromRGB(232, 196, 96), Potato = Color3.fromRGB(196, 150, 96),
	Lettuce = Color3.fromRGB(120, 190, 80), Corn = Color3.fromRGB(246, 206, 70), Onion = Color3.fromRGB(200, 140, 90),
	Strawberry = Color3.fromRGB(220, 50, 60), Tomato = Color3.fromRGB(226, 64, 48), BellPepper = Color3.fromRGB(220, 60, 40),
	Pumpkin = Color3.fromRGB(236, 130, 40), Watermelon = Color3.fromRGB(70, 140, 60), Blueberry = Color3.fromRGB(70, 90, 190),
	Pineapple = Color3.fromRGB(232, 190, 60), CocoaPod = Color3.fromRGB(150, 90, 50), Dragonfruit = Color3.fromRGB(230, 70, 140),
	GrapeVine = Color3.fromRGB(120, 60, 140), Moonmelon = Color3.fromRGB(200, 220, 255), Starfruit = Color3.fromRGB(250, 220, 80),
	GoldenApple = Color3.fromRGB(250, 200, 60), CrystalRose = Color3.fromRGB(160, 220, 255), PhoenixPepper = Color3.fromRGB(255, 120, 40),
	DragonsEyePumpkin = Color3.fromRGB(180, 40, 60),
}
local BIG = { Pumpkin = true, Watermelon = true, Moonmelon = true, DragonsEyePumpkin = true }
local FADE = 1
local CULL = 300 -- studs from the camera: farther shoppers aren't drawn (a busy Supermarket has 24, and there are 8 stores)
local DOOR_REACH = 3 -- studs from the middle of the door's cell: they're coming through it
local DOOR_GAP = 4 -- seconds: a busy store's door doesn't ring on and on

local SAY_SIZE = UDim2.fromScale(4.6, 1.2) -- a bubble, in studs
local PAID_SIZE = UDim2.fromScale(3.2, 1.2) -- what they paid is short, with a coin

local folder = Instance.new("Folder")
folder.Name = "Shoppers"
local shoppers = {} -- [id] = shopper

-- A gold coin over `bubble`, sized by it so it shrinks with it (UI.coin's in
-- pixels, for windows), and not in the label, whose padding would push it onto
-- the number. Hidden until someone pays.
local function coinIn(bubble: BillboardGui): Frame
	local function round(frame: Frame)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
	end
	local coin = Instance.new("Frame")
	coin.Name = "Coin"
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.fromScale(0.07, 0.5)
	coin.Size = UDim2.fromScale(0.68, 0.68)
	coin.SizeConstraint = Enum.SizeConstraint.RelativeYY
	coin.BackgroundColor3 = Color3.fromRGB(255, 221, 110)
	coin.ZIndex = 2
	coin.Visible = false
	round(coin)
	local rim = Instance.new("UIStroke")
	rim.Color = Color3.fromRGB(122, 78, 18)
	rim.Thickness = 2
	rim.Parent = coin
	local face = Instance.new("Frame")
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromScale(0.62, 0.62)
	face.BackgroundColor3 = Color3.fromRGB(240, 178, 52)
	face.BorderSizePixel = 0
	face.ZIndex = 3
	round(face)
	face.Parent = coin
	local shine = Instance.new("Frame")
	shine.Position = UDim2.fromScale(0.2, 0.16)
	shine.Size = UDim2.fromScale(0.24, 0.24)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.25
	shine.BorderSizePixel = 0
	shine.ZIndex = 4
	round(shine)
	shine.Parent = coin
	coin.Parent = bubble
	return coin
end

local function build(look: number)
	local model, parts, torso, basket, k = People.shopper(look)
	local bubble = Instance.new("BillboardGui")
	bubble.Size = SAY_SIZE
	bubble.StudsOffsetWorldSpace = Vector3.new(0, 4.1 * k, 0) -- (under a Corner Store's 10-stud ceiling)
	bubble.MaxDistance = 90
	bubble.Enabled = false
	bubble.Adornee = torso
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(255, 244, 220)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(58, 42, 28)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = label
	local room = Instance.new("UIPadding") -- (the text's clear of the rounded ends, and of the coin)
	room.Name = "Room"
	room.PaddingLeft = UDim.new(0.05, 0)
	room.PaddingRight = UDim.new(0.05, 0)
	room.Parent = label
	label.Parent = bubble
	coinIn(bubble)
	bubble.Parent = model
	model.Parent = folder
	return model, parts, bubble, label, basket
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- A bubble's colour by what they said: pleased green, cross red, else cream.
local MOOD = { good = Color3.fromRGB(214, 240, 196), bad = Color3.fromRGB(255, 206, 196) }
local TURN = math.rad(540) -- how fast they turn round (degrees a second): never a snap

local function say(shopper, text: string, color: Color3?, coin: boolean?)
	shopper.label.Text = text
	shopper.label.BackgroundColor3 = color or Color3.fromRGB(255, 244, 220)
	shopper.bubble.Coin.Visible = coin == true
	shopper.label.Room.PaddingLeft = UDim.new(if coin then 0.34 else 0.05, 0)
	shopper.bubble.Size = if coin then PAID_SIZE else SAY_SIZE
	Bubbles.set(shopper.bubble, true)
	shopper.sayToken += 1
	local token = shopper.sayToken
	task.delay(2.6, function()
		if shopper.sayToken == token then
			Bubbles.set(shopper.bubble, false)
		end
	end)
end

-- The basket shows once there's something in it: a few of the crop, or one
-- big one (a pumpkin, a melon).
local function fillBasket(shopper, units: number, crop: string?)
	local basket, hidden = shopper.basket, shopper.hidden
	local has = units > 0
	local big = crop ~= nil and BIG[crop] == true
	local color = PRODUCE[crop or ""] or PRODUCE.Carrot
	for _, p in basket.all do
		hidden[p] = not has
	end
	for i, p in basket.goods do
		hidden[p] = not has or big or (i == 3 and units < 12)
		p.Color = color
	end
	hidden[basket.big] = not has or not big
	basket.big.Color = color
end

local function path(event)
	local shopper = shoppers[event.id]
	if not shopper then
		local model, parts, bubble, label, basket = build(event.look)
		shopper = { model = model, parts = parts, bubble = bubble, label = label, basket = basket, hidden = {}, plot = event.plot, sayToken = 0,
			phase = (event.look % 17) / 17 * math.pi * 2, list = {}, cframes = {} }
		for _, entry in parts do
			table.insert(shopper.list, entry[1])
		end
		shoppers[event.id] = shopper
	end
	shopper.points = event.points
	shopper.at = event.at
	shopper.length = PlotLayout.pathLength(event.points)
	shopper.face = event.face
	shopper.leave = event.leave == true
	fillBasket(shopper, event.basket or 0, event.crop)
	if event.say then
		say(shopper, event.say, MOOD[event.mood or ""])
	end
end

local function paid(event)
	local shopper = shoppers[event.id]
	if shopper and event.coins > 0 then
		say(shopper, `+{Format.number(event.coins)}`, Color3.fromRGB(242, 179, 61), true)
		if event.plot == Players.LocalPlayer:GetAttribute("Plot") then -- (your own store's sales)
			Sfx.play("Coins", shopper.model.PrimaryPart or shopper.model:FindFirstChildWhichIsA("BasePart"))
		end
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

-- The bell over a store's door, once for each shopper coming in.
local doorRangAt = {} -- [plot] = when its door last rang
local function ringDoor(shopper, position: Vector3, t: number)
	local door = PlotLayout.storeWorld(shopper.plot, Store.DOOR_X, 1, position.Y)
	if (position - door).Magnitude > DOOR_REACH then
		return
	end
	shopper.rang = true
	if t - (doorRangAt[shopper.plot] or -math.huge) >= DOOR_GAP then
		doorRangAt[shopper.plot] = t
		Sfx.at("ShopBell", door)
	end
end

local function step(dt: number)
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
		if not shopper.rang and not shopper.leave then
			ringDoor(shopper, position, t)
		end
		-- Which way they face: along the walk while walking; once there, toward
		-- what they came for (`face`); and before their next walk starts (still
		-- choosing at a shelf, the walk to the queue already sent) the way they
		-- already faced: they used to turn to the till while still picking.
		local want = nil
		if walking then
			want = Vector3.new(direction.X, 0, direction.Z)
		elseif t >= shopper.at then
			local toward = if shopper.face and not shopper.leave then shopper.face - position else direction
			want = Vector3.new(toward.X, 0, toward.Z)
		end
		local heading = shopper.heading
		if want and want.Magnitude > 0.01 then
			want = want.Unit
			if not heading then
				heading = want
			else -- (turned toward it a little at a time, not snapped round)
				local angle = math.atan2(heading:Cross(want).Y, heading:Dot(want))
				local most = TURN * dt
				heading = CFrame.Angles(0, math.clamp(angle, -most, most), 0):VectorToWorldSpace(heading)
			end
		end
		heading = heading or Vector3.zAxis
		shopper.heading = heading
		local beat = t * 9 + shopper.phase
		local swing = if walking then math.sin(beat) * math.rad(26) else 0
		local bob = if walking then math.abs(math.sin(beat)) * 0.08 else 0
		local feet = CFrame.lookAt(position, position + heading) + Vector3.new(0, bob, 0)
		local fade = if shopper.leave then math.clamp((walked - shopper.length) / (FADE * Shop.SPEED), 0, 1) else 0
		local cframes, hidden = shopper.cframes, shopper.hidden
		for i, entry in shopper.parts do
			local p, offset, limb = entry[1], entry[2], entry[3]
			local pose = offset
			if limb then -- (legs swing; each arm against its leg; the basket arm only a little)
				local angle = if limb == "leg" then swing * entry[4] elseif limb == "arm" then -swing * entry[4] * 0.8 else -swing * entry[4] * 0.2
				local pivot = entry[5]
				pose = CFrame.new(pivot) * CFrame.Angles(angle, 0, 0) * CFrame.new(-pivot) * offset
			end
			cframes[i] = feet * pose
			local transparency = if hidden[p] then 1 else fade
			if p.Transparency ~= transparency then
				p.Transparency = transparency
				local face = p:FindFirstChild("Face")
				if face then
					face.Transparency = transparency
				end
			end
		end
		workspace:BulkMoveTo(shopper.list, cframes, Enum.BulkMoveMode.FireCFrameChanged)
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
