-- Raids on screen (docs/GameDesign.md §4.10–4.12, §5.4, §5.5; the art in
-- docs/ArtDirection.md §9). The server decides everything (CrimeService);
-- this draws it and sends intents:
--   * the context stamp (FieldController.offer): STEAL (hold) on a ripe crop
--     in someone else's field, SWING near anyone in your farm, ARREST (hold)
--     over a knocked-out Suspect, CLIMB at a back fence;
--   * a ring of dots over a crop being stolen (everyone; always on top for
--     its owner), and the crop shaking;
--   * a red ! over Suspects of your farm (always on top), a red "🧺 name" tag
--     over anyone carrying a sack, dizzy stars over anyone knocked out;
--   * your sack: a sign over the hotbar, "Get home!" with an arrow to your
--     barn; the knockout screen (grey, blurred, the countdown, Leave farm);
--     the BUSTED! mugshot card; the theft alarm card; BONK! and puffs;
--   * Roblox's reset button is off while you're a Suspect, knocked out or
--     carrying (§4.12).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crime = require(Shared.Config.Crime)
local CrimeRules = require(Shared.CrimeRules)
local Crops = require(Shared.Config.Crops)
local PlotLayout = require(Shared.PlotLayout)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)

local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)
local FieldController = require(script.Parent.FieldController)
local HotbarController = require(script.Parent.HotbarController)
local HudController = require(script.Parent.HudController)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer
local CrimeAction = Remotes.func("CrimeAction")
local TravelAction = Remotes.func("TravelAction")

local CrimeController = {}

local TICK = 0.1

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(who: Player): BasePart?
	local character = who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function myPlot(): number
	return player:GetAttribute("Plot") or 0
end

local function inFarm(who: Player): number
	return who:GetAttribute("InFarm") or 0
end

local function knockedOut(who: Player): boolean
	return (who:GetAttribute("KnockedOut") or 0) > now()
end

local function sackWeight(): number
	return player:GetAttribute("Sack") or 0
end

local function say(reason: string?)
	local text = Reasons(reason)
	if text then
		UI.toast(text, "Error", 2.5)
	end
end

local function floatAtStamp(text: string, color: Color3?)
	local stamp = UI.screen:FindFirstChild("ContextStamp")
	if stamp then
		local at = stamp.AbsolutePosition + stamp.AbsoluteSize / 2 - UI.screen.AbsolutePosition
		UI.float(text, UDim2.fromOffset(at.X, at.Y - 60), color)
	else
		UI.float(text, UDim2.fromScale(0.5, 0.6), color)
	end
end

------------------------------------------------------------------------
-- Holds on the stamp (a steal, an arrest): the bar fills while you hold.

local holdToken = 0

-- Runs a hold: start() → ok?, then the bar fills for `seconds`, then done().
-- Letting go first calls cancel(). Returns nothing.
local function runHold(seconds: number, done: () -> (), cancel: (() -> ())?, stillValid: (() -> boolean)?)
	holdToken += 1
	local token = holdToken
	local started = os.clock()
	FieldController.setProgress(0)
	while holdToken == token do
		local f = (os.clock() - started) / seconds
		FieldController.setProgress(f)
		if stillValid and not stillValid() then
			holdToken += 1
			FieldController.setProgress(nil)
			if cancel then
				cancel()
			end
			return
		end
		if f >= 1 then
			holdToken += 1
			FieldController.setProgress(nil)
			done()
			return
		end
		task.wait()
	end
	-- (let go)
	FieldController.setProgress(nil)
	if cancel then
		cancel()
	end
end

local function letGo()
	holdToken += 1
end

------------------------------------------------------------------------
-- Stealing

local stealing = nil -- { plot, tile } while a steal hold runs

local function tileUnder(plot: number): (BasePart?, number?)
	local root = rootOf(player)
	local tile = root and PlotLayout.tileAt(plot, root.Position)
	local model = workspace.World:FindFirstChild(`Plot{plot}`)
	local field = model and model:FindFirstChild("Field")
	return field and tile and field:FindFirstChild(`Tile{tile}`), tile
end

local function steal(plot: number, tile: number, part: BasePart)
	local pressed = holdToken
	local result = CrimeAction:InvokeServer("Steal", tostring(tile))
	if not result.ok then
		say(result.reason)
		return
	elseif holdToken ~= pressed then
		task.spawn(CrimeAction.InvokeServer, CrimeAction, "StealCancel") -- (let go before the server answered)
		return
	end
	stealing = { plot = plot, tile = tile }
	local crop = Crops.ById[result.result.crop]
	runHold(result.result.seconds, function()
		stealing = nil
		local done = CrimeAction:InvokeServer("StealDone")
		if done.ok then
			floatAtStamp(`+1 {crop.icon} 🧺`, C.alarm)
		else
			say(done.reason)
		end
	end, function()
		stealing = nil
		task.spawn(CrimeAction.InvokeServer, CrimeAction, "StealCancel")
	end, function()
		return part:GetAttribute("Stage") == "Ripe" and not knockedOut(player) and inFarm(player) == plot
	end)
end

------------------------------------------------------------------------
-- The bat

local lastSwing = 0

local function nearest(filter: (Player) -> boolean, range: number): (Player?, number)
	local me = rootOf(player)
	if not me then
		return nil, math.huge
	end
	local best, bestDistance = nil, range
	for _, other in Players:GetPlayers() do
		local root = other ~= player and rootOf(other)
		if root and filter(other) then
			local distance = (root.Position - me.Position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	return best, bestDistance
end

-- The bat only hits in front of you, so a swing first turns you to face
-- the nearest person in reach (the server still checks the angle).
local function faceNearest(): boolean
	local mine = myPlot()
	local me = rootOf(player)
	if not me or mine == 0 then
		return false
	end
	local target = nearest(function(other)
		return inFarm(other) == mine and not knockedOut(other)
	end, Crime.HIT_RANGE + Crime.HIT_LAG)
	local root = target and rootOf(target)
	if not root then
		return false
	end
	local at = Vector3.new(root.Position.X, me.Position.Y, root.Position.Z)
	if (at - me.Position).Magnitude > 0.1 then
		me.CFrame = CFrame.lookAt(me.Position, at)
	end
	return true
end

local function swing()
	if os.clock() - lastSwing < Crime.SWING_COOLDOWN then
		return
	end
	lastSwing = os.clock()
	local turned = faceNearest()
	local tool = HotbarController.equipBat()
	if tool then
		local anim = Instance.new("StringValue") -- (Roblox's Animate script plays its slash for this)
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
	end
	if turned then
		task.wait(0.2) -- (the wind-up: and the server sees you've turned)
	end
	local result = CrimeAction:InvokeServer("Swing")
	if not result.ok then
		say(result.reason)
	end
end

local function arrest(target: Player)
	local pressed = holdToken
	local result = CrimeAction:InvokeServer("ArrestStart", tostring(target.UserId))
	if not result.ok then
		say(result.reason)
		return
	elseif holdToken ~= pressed then
		return -- (let go already)
	end
	runHold(Crime.ARREST_HOLD + 0.05, function()
		local done = CrimeAction:InvokeServer("Arrest", tostring(target.UserId))
		if not done.ok then
			say(done.reason)
		end
	end, nil, function()
		return knockedOut(target)
	end)
end

------------------------------------------------------------------------
-- The context stamp: what you can do right now

local function climbHere(): (number?, string?)
	local root = rootOf(player)
	if not root then
		return nil, nil
	end
	for index = 1, PlotLayout.COUNT do
		local p = PlotLayout.frame(index):PointToObjectSpace(root.Position)
		local direction = PlotLayout.climbAt(p, Crime.CLIMB_REACH)
		if direction then
			return index, direction
		end
	end
	return nil, nil
end

local function updateOffers()
	local mine = myPlot()
	local here = inFarm(player)
	local me = knockedOut(player)

	-- ARREST: a knocked-out Suspect in your farm, close by
	local target = nil
	if not me and mine > 0 and here == mine then
		target = nearest(function(other)
			return knockedOut(other) and other:GetAttribute("KOSuspect") == true and other:GetAttribute("KOPlot") == mine
		end, Crime.ARREST_RANGE)
	end
	if target then
		local name = target.DisplayName
		FieldController.offer("Arrest", {
			priority = 40, text = "ARREST\n ", sub = name, kind = "red", info = `🚔 Hold to arrest {name}`,
			press = function()
				arrest(target)
			end,
			release = letGo,
		})
	else
		FieldController.withdraw("Arrest")
	end

	-- SWING: a Suspect near you in your farm (anyone, with the bat in your hand)
	local victim = nil
	if not me and not target and mine > 0 and here == mine and HotbarController.hasBat() then
		local armed = HotbarController.batEquipped()
		victim = nearest(function(other)
			local suspect = (other:GetAttribute("SuspectOf") or 0) == mine or (other:GetAttribute("Sack") or 0) > 0
			return inFarm(other) == mine and not knockedOut(other) and (suspect or armed)
		end, Crime.SWING_NEAR)
	end
	if victim then
		local suspect = (victim:GetAttribute("SuspectOf") or 0) == mine or (victim:GetAttribute("Sack") or 0) > 0
		FieldController.offer("Swing", {
			priority = 30, text = "SWING\n ", sub = `🏏 {victim.DisplayName}`, kind = "red",
			info = if suspect then `{victim.DisplayName} is a Suspect: bonk, then arrest!` else `{victim.DisplayName} is only visiting (bonking pays nothing)`,
			press = swing,
		})
	else
		FieldController.withdraw("Swing")
	end

	-- STEAL: a ripe crop under you, in someone else's farm
	local offered = false
	if not me and not stealing and here > 0 and here ~= mine then
		local part, tile = tileUnder(here)
		local cropId = part and part:GetAttribute("Stage") == "Ripe" and part:GetAttribute("Crop")
		if part and tile and cropId then
			offered = true
			local crop = Crops.ById[cropId]
			local rarity = Rarities.ById[crop.rarity]
			local room = Crime.SACK_CAPACITY - sackWeight()
			local suspect = (player:GetAttribute("SuspectOf") or 0) == here
			if rarity.sackWeight > room then
				FieldController.offer("Steal", {
					priority = 20, text = "FULL\n ", sub = `🧺 {sackWeight()}/{Crime.SACK_CAPACITY}`, kind = "wood",
					info = "Your sack is full: get home and it empties into your barn",
					press = function()
						UI.toast("Your sack is full! Get home to empty it.", "Error", 2.5)
					end,
				})
			else
				FieldController.offer("Steal", {
					priority = 20, text = "STEAL\n ", sub = `{crop.icon} {crop.name}`, kind = "red",
					info = if suspect then `Hold {CrimeRules.stealHold(crop.rarity)} s · 🧺 {sackWeight()}/{Crime.SACK_CAPACITY}`
						else "Stealing makes you a Suspect: the farmer can bonk and arrest you!",
					press = function()
						steal(here, tile, part)
					end,
					release = letGo,
				})
			end
		end
	end
	if stealing then
		offered = true -- (keep the button while the hold runs)
	end
	if not offered then
		FieldController.withdraw("Steal")
	end

	-- CLIMB: at a back fence, either side
	local plot, direction = nil, nil
	if not me and not stealing then
		plot, direction = climbHere()
	end
	if plot then
		local model = workspace.World:FindFirstChild(`Plot{plot}`)
		local owner = model and model:GetAttribute("OwnerName")
		local trespass = direction == "In" and plot ~= mine and owner ~= nil
		FieldController.offer("Climb", {
			priority = 10, text = "CLIMB\n ", sub = if direction == "In" then "in" else "out", kind = if trespass then "red" else "blue",
			info = if trespass then `Climbing into {owner}'s farm makes you a Suspect!`
				elseif direction == "In" then "Climb over the back fence"
				else "Climb out over the back fence",
			press = function()
				local result = CrimeAction:InvokeServer("Climb")
				if not result.ok then
					say(result.reason)
				end
			end,
		})
	else
		FieldController.withdraw("Climb")
	end
end

------------------------------------------------------------------------
-- Markers over people: the Suspect !, the sack tag, dizzy stars

local markers = {} -- [Player] = { suspect, sack, stars }

local function billboard(name: string, adornee: BasePart, size: UDim2, offset: Vector3, onTop: boolean, maxDistance: number)
	return make("BillboardGui", {
		Name = name, Adornee = adornee, Size = size, StudsOffsetWorldSpace = offset, AlwaysOnTop = onTop,
		MaxDistance = maxDistance, LightInfluence = 0, ResetOnSpawn = false, Parent = UI.screen.Parent,
	})
end

local function clearMarker(gui)
	if gui then
		gui:Destroy()
	end
end

local function suspectMarker(other: Player, head: BasePart)
	local gui = billboard("SuspectMark", head, UDim2.fromOffset(46, 66), Vector3.new(0, 3.2, 0), true, 400)
	make("Frame", {
		Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(2, 0), BackgroundColor3 = C.alarm,
		Parent = gui,
	}, { UI.corner(21), UI.stroke(C.cream, 3),
		make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = UI.HEAD, Text = "!", TextSize = 32, TextColor3 = C.cream }) })
	make("TextLabel", {
		Position = UDim2.fromOffset(-37, 44), Size = UDim2.fromOffset(120, 20), BackgroundTransparency = 1, Font = UI.HEAD,
		Text = other.DisplayName, TextSize = 15, TextColor3 = C.cream, TextStrokeColor3 = C.alarm, TextStrokeTransparency = 0, Parent = gui,
	})
	return gui
end

local function sackTag(other: Player, head: BasePart)
	local gui = billboard("SackTag", head, UDim2.fromScale(7, 1.1), Vector3.new(0, 2.2, 0), false, 150)
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = UI.HEAD, TextScaled = true,
		Text = `🧺 {other.DisplayName}`, TextColor3 = C.alarm, TextStrokeColor3 = C.cream, TextStrokeTransparency = 0.2, Parent = gui,
	})
	return gui
end

local STAR_COUNT = 5
local function dizzyStars(head: BasePart)
	local gui = billboard("DizzyStars", head, UDim2.fromScale(5, 3), Vector3.new(0, 1.6, 0), false, 160)
	for i = 1, STAR_COUNT do
		make("TextLabel", {
			Name = `Star{i}`, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.26, 0.4), BackgroundTransparency = 1,
			Font = UI.HEAD, TextScaled = true, Text = "★", TextColor3 = C.gold, TextStrokeColor3 = C.soilDark, TextStrokeTransparency = 0, Parent = gui,
		})
	end
	return gui
end

local function updateMarkers()
	local mine = myPlot()
	local t = os.clock()
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local head = character and character:FindFirstChild("Head")
		local m = markers[other] or {}
		markers[other] = m
		if not head or not head:IsA("BasePart") then
			clearMarker(m.suspect)
			clearMarker(m.sack)
			clearMarker(m.stars)
			markers[other] = {}
			continue
		end
		-- the red ! for the owner of the farm they're a Suspect of
		local suspect = other ~= player and mine > 0 and (other:GetAttribute("SuspectOf") or 0) == mine
		if suspect and not (m.suspect and m.suspect.Adornee == head) then
			clearMarker(m.suspect)
			m.suspect = suspectMarker(other, head)
		elseif not suspect and m.suspect then
			clearMarker(m.suspect)
			m.suspect = nil
		end
		-- a red name with a sack, for everyone
		local carrying = (other:GetAttribute("Sack") or 0) > 0
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = if carrying then Enum.HumanoidDisplayDistanceType.None else Enum.HumanoidDisplayDistanceType.Viewer
		end
		if carrying and other ~= player and not (m.sack and m.sack.Adornee == head) then
			clearMarker(m.sack)
			m.sack = sackTag(other, head)
		elseif (not carrying or other == player) and m.sack then
			clearMarker(m.sack)
			m.sack = nil
		end
		if m.sack and m.suspect then
			m.sack.Enabled = false -- (the ! already names them)
		elseif m.sack then
			m.sack.Enabled = true
		end
		-- dizzy stars while knocked out
		local out = knockedOut(other)
		if out and not (m.stars and m.stars.Adornee == head) then
			clearMarker(m.stars)
			m.stars = dizzyStars(head)
		elseif not out and m.stars then
			clearMarker(m.stars)
			m.stars = nil
		end
		if m.stars then
			for i = 1, STAR_COUNT do
				local a = t * 3 + i * math.pi * 2 / STAR_COUNT
				local star = m.stars:FindFirstChild(`Star{i}`)
				star.Position = UDim2.fromScale(0.5 + 0.38 * math.cos(a), 0.5 + 0.22 * math.sin(a))
				star.ZIndex = if math.sin(a) > 0 then 2 else 1
			end
		end
	end
end

------------------------------------------------------------------------
-- Steal rings: a ring of dots over a crop being stolen, filling up

local RING_DOTS = 20
local rings = {} -- [tile part] = { gui, dots, home }

local function makeRing(part: BasePart, owned: boolean)
	local gui = billboard("StealRing", part, UDim2.fromOffset(96, 96), Vector3.new(0, 7, 0), owned, if owned then 600 else 140)
	local dots = {}
	for i = 1, RING_DOTS do
		local a = (i - 1) / RING_DOTS * math.pi * 2 - math.pi / 2
		dots[i] = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + 0.4 * math.cos(a), 0.5 + 0.4 * math.sin(a)),
			Size = UDim2.fromOffset(13, 13), BackgroundColor3 = C.cream, Parent = gui,
		}, { UI.corner(7), UI.stroke(C.soilDark, 2) })
	end
	make("TextLabel", {
		Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(46, 46),
		BackgroundTransparency = 1, Font = UI.HEAD, TextSize = 34, Text = "🧺", Parent = gui,
	})
	return { gui = gui, dots = dots, owned = owned }
end

-- (tiles being stolen from carry the "Stealing" tag: CrimeService)
local function updateRings()
	local mine = myPlot()
	local t = now()
	local seen = {}
	for _, part in CollectionService:GetTagged("Stealing") do
		if not part:IsA("BasePart") or not part:IsDescendantOf(workspace) then
			continue
		end
		seen[part] = true
		local ring = rings[part]
		if not ring then
			local model = part:FindFirstAncestorWhichIsA("Model")
			local plot = model and model:GetAttribute("PlotIndex")
			ring = makeRing(part, plot ~= nil and plot == mine)
			local crop = part:FindFirstChild("Crop")
			if crop and crop:IsA("Model") then
				ring.crop, ring.base = crop, crop:GetPivot()
			end
			rings[part] = ring
		end
		local start, ends = part:GetAttribute("StealStart") or t, part:GetAttribute("StealEnds") or t + 1
		local f = math.clamp((t - start) / math.max(0.1, ends - start), 0, 1)
		local lit = math.floor(f * RING_DOTS + 0.5)
		for i, dot in ring.dots do
			dot.BackgroundColor3 = if i <= lit then C.alarm else C.cream
		end
		if ring.owned then -- (your crop: the ring flashes)
			local big = math.floor(t * 4) % 2 == 0
			ring.gui.Size = UDim2.fromOffset(if big then 106 else 96, if big then 106 else 96)
		end
		-- the crop shakes and rustles
		if ring.crop and ring.crop.Parent == part then
			ring.crop:PivotTo(ring.base * CFrame.Angles(0, 0, math.rad(math.sin(t * 28) * 7)))
		end
	end
	for part, ring in rings do
		if not seen[part] then
			ring.gui:Destroy()
			if ring.crop and ring.crop.Parent == part then
				ring.crop:PivotTo(ring.base)
			end
			rings[part] = nil
		end
	end
end

------------------------------------------------------------------------
-- Your sack: a sign over the hotbar with an arrow to your barn

local sackSign = make("Frame", {
	Name = "SackSign", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(290, 44), Visible = false, Parent = UI.screen,
}, { UI.corner(6), UI.stroke(UI.SEAM, 3) })
UI.wood(sackSign, 2, false, C.red)
local sackLabel = UI.label({
	Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -64, 1, 0), Font = UI.HEAD, TextSize = 20, TextColor3 = C.cream,
	TextStrokeColor3 = UI.SEAM, TextStrokeTransparency = 0, Text = "", ZIndex = 3, Parent = sackSign,
})
UI.fit(sackLabel, 11)
local arrowDisc = make("Frame", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = C.cream, ZIndex = 3, Parent = sackSign,
}, { UI.corner(18), UI.stroke(UI.SEAM, 2) })
local arrow = make("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = UI.HEAD, Text = "↑", TextSize = 28, TextColor3 = C.red, ZIndex = 4, Parent = arrowDisc,
})
UI.onLayout(function()
	sackSign.Position = UDim2.new(0.5, 0, 1, -(HudController.HOTBAR_HEIGHT + 20))
end)

local function updateSack()
	local weight = sackWeight()
	local carrying = weight > 0
	sackSign.Visible = carrying and not knockedOut(player)
	local travel = UI.screen:FindFirstChild("Travel")
	if travel then
		travel.Visible = not carrying -- (no travel with a sack: walk home)
	end
	if not carrying then
		return
	end
	local mine = myPlot()
	local home = mine > 0 and inFarm(player) == mine
	sackLabel.Text = if home then `🧺 {weight}/{Crime.SACK_CAPACITY} · to your door!` else `🧺 {weight}/{Crime.SACK_CAPACITY} · Get home!`
	local root = rootOf(player)
	local camera = workspace.CurrentCamera
	arrowDisc.Visible = mine > 0 and root ~= nil
	if mine > 0 and root and camera then
		local to = PlotLayout.spawnWorld(mine) - root.Position
		local look = camera.CFrame.LookVector
		local heading = math.atan2(look.X, look.Z)
		local bearing = math.atan2(to.X, to.Z)
		arrow.Rotation = math.deg(heading - bearing)
	end
end

------------------------------------------------------------------------
-- The knockout screen (yours)

local koGui = make("Frame", {
	Name = "KnockedOut", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.7,
	Visible = false, ZIndex = 50, Parent = UI.screen,
})
local koCard = make("Frame", { -- (high up: your character lies in the middle of the screen)
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromOffset(380, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = C.cream, Rotation = -2, ZIndex = 51, Parent = koGui,
}, { UI.corner(6), UI.stroke(C.soilDark, 3), make("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
	make("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
local koTitle = UI.label({
	Size = UDim2.new(1, 0, 0, 52), Font = UI.HEAD, TextSize = 50, Text = "BONK!", TextColor3 = C.gold, TextStrokeColor3 = C.soilDark,
	TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, ZIndex = 52, Parent = koCard,
})
local koCount = UI.label({
	Size = UDim2.new(1, 0, 0, 30), Font = UI.HEAD, TextSize = 26, Text = "", TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, ZIndex = 52, Parent = koCard,
})
local koLine = UI.label({
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Font = UI.HAND, TextSize = 24, Text = "",
	TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, ZIndex = 52, Parent = koCard,
})
local leaveHolder, leaveButton = UI.button({ text = "Leave farm", kind = "green", size = UDim2.fromOffset(200, 46), order = 4, zIndex = 52, parent = koCard })

local koEffects = nil
local leaving = false

leaveButton.Activated:Connect(function()
	if leaving then
		return
	end
	local result = CrimeAction:InvokeServer("LeaveFarm")
	if result.ok then
		leaving = true
		leaveButton.Text = "You'll wake up outside"
		UI.setButtonKind(leaveHolder, "cream")
	end
end)

local function updateKnockout()
	local untilAt = player:GetAttribute("KnockedOut") or 0
	local out = untilAt > now()
	if out and not koGui.Visible then
		leaving = false
		koTitle.Text = "BONK!"
		leaveButton.Text = "Leave farm"
		UI.setButtonKind(leaveHolder, "green")
		koGui.Visible = true
		local camera = workspace.CurrentCamera
		koEffects = {
			make("ColorCorrectionEffect", { Saturation = -0.85, Brightness = -0.04, Parent = camera }),
			make("BlurEffect", { Size = 6, Parent = camera }),
		}
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = true
		end
	elseif not out and koGui.Visible then
		koGui.Visible = false
		for _, effect in koEffects or {} do
			effect:Destroy()
		end
		koEffects = nil
	end
	if out then
		local suspect = player:GetAttribute("KOSuspect") == true
		koLine.Text = if suspect then "You're a Suspect: the farmer can arrest you!" else "You're just stunned. You did nothing wrong."
		koLine.TextColor3 = if suspect then Color3.fromRGB(170, 40, 30) else C.ink
		leaveHolder.Visible = not suspect
		koCount.Text = `💫 Waking up in {math.max(1, math.ceil(untilAt - now()))}...`
	end
end

------------------------------------------------------------------------
-- BUSTED! (yours): a mugshot in front of a height chart, the charge, the fine

local function bustedCard(info)
	local dim = make("Frame", {
		Name = "Busted", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 60, Parent = UI.screen,
	})
	local card = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 270), BackgroundColor3 = C.kraft,
		Rotation = 1.5, ZIndex = 61, Parent = dim,
	}, { UI.corner(8), UI.stroke(C.soil, 3) })
	UI.onLayout(function()
		local size = UI.screen.AbsoluteSize
		card.Size = UDim2.fromOffset(math.min(520, size.X - 30), math.min(270, size.Y - 30))
	end)
	-- the photo: you, in front of the height chart
	local photo = make("Frame", {
		Position = UDim2.fromOffset(14, 14), Size = UDim2.new(0.42, -14, 1, -28), BackgroundColor3 = Color3.fromRGB(234, 230, 216), ClipsDescendants = true, ZIndex = 62, Parent = card,
	}, { UI.corner(4), UI.stroke(C.soilDark, 2) })
	for i = 1, 7 do
		make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, i / 8), Size = UDim2.new(1, 0, 0, if i % 2 == 0 then 3 else 2),
			BackgroundColor3 = Color3.fromRGB(70, 66, 60), BorderSizePixel = 0, ZIndex = 62, Parent = photo })
	end
	local viewport = make("ViewportFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(200, 200, 200), LightColor = Color3.fromRGB(255, 250, 240),
		ZIndex = 63, Parent = photo,
	})
	local character = player.Character
	if character then
		local ok = pcall(function()
			character.Archivable = true
			local clone = character:Clone()
			for _, child in clone:GetDescendants() do
				if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("Tool") or child.Name == "LootSack" or child:IsA("BillboardGui") then
					child:Destroy()
				end
			end
			local world = make("WorldModel", { Parent = viewport })
			clone:PivotTo(CFrame.new())
			for _, p in clone:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = true
				end
			end
			clone.Parent = world
			local head = clone:FindFirstChild("Head")
			local y = if head and head:IsA("BasePart") then head.Position.Y - 0.6 else 1.5
			local camera = make("Camera", { FieldOfView = 30, CFrame = CFrame.lookAt(Vector3.new(0, y, -9), Vector3.new(0, y, 0)), Parent = viewport })
			viewport.CurrentCamera = camera
		end)
		if not ok then
			viewport:Destroy()
		end
	end
	-- the number board you hold
	local board = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(0.86, 0, 0, 42), BackgroundColor3 = C.board, ZIndex = 64, Parent = photo,
	}, { UI.corner(3), UI.stroke(C.cream, 2) })
	UI.label({ Size = UDim2.new(1, 0, 0.5, 0), Font = UI.HAND, TextSize = 16, TextColor3 = C.chalk, TextXAlignment = Enum.TextXAlignment.Center,
		Text = "CLOVERDALE POLICE", ZIndex = 65, Parent = board })
	UI.fit(UI.label({ Position = UDim2.fromScale(0, 0.45), Size = UDim2.new(1, -6, 0.55, 0), Font = UI.HEAD, TextSize = 18, TextColor3 = C.chalk,
		TextXAlignment = Enum.TextXAlignment.Center, Text = `{info.name} · #{info.number}`, ZIndex = 65, Parent = board }), 10)
	-- the case file
	local file = make("Frame", {
		Position = UDim2.new(0.42, 10, 0, 14), Size = UDim2.new(0.58, -24, 1, -28), BackgroundTransparency = 1, ZIndex = 62, Parent = card,
	}, { make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local stamp = UI.label({ Size = UDim2.new(1, 0, 0, 52), Font = UI.HEAD, TextSize = 46, Text = "BUSTED!", TextColor3 = C.red,
		TextStrokeColor3 = C.cream, TextStrokeTransparency = 0, Rotation = -6, LayoutOrder = 1, ZIndex = 63, Parent = file })
	local lines = {
		info.charge,
		`Fine: {info.fine} coins, paid to {info.owner}`,
	}
	if info.owed > 0 then
		table.insert(lines, if info.paid > 0
			then `You had {info.paid}: you owe {info.owner} {info.owed} more. Half of your sales pay it off.`
			else `You had no coins: you owe {info.owner} {info.owed}. Half of your sales pay it off.`)
	end
	table.insert(lines, "Off to the police station!")
	for i, text in lines do
		UI.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Font = if i == 1 then UI.HEAD else UI.HAND,
			TextSize = if i == 1 then 19 else 21, Text = text, TextColor3 = if i == #lines then C.soil else C.ink, LayoutOrder = i + 1, ZIndex = 63, Parent = file })
	end
	stamp.TextTransparency = 1
	TweenService:Create(stamp, TweenInfo.new(0.25, Enum.EasingStyle.Back), { TextTransparency = 0, Rotation = -10 }):Play()
	task.delay(5, function()
		TweenService:Create(dim, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(card, TweenInfo.new(0.4), { Position = UDim2.fromScale(0.5, 1.4) }):Play()
		task.wait(0.45)
		dim:Destroy()
	end)
end

------------------------------------------------------------------------
-- The theft alarm (yours, as the owner) and the arrest pop

local alarmCard = make("Frame", {
	Name = "TheftAlarm", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(400, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = C.cream, Visible = false, ZIndex = 35, Parent = UI.screen,
}, { UI.corner(6), UI.stroke(C.alarm, 4), make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
local alarmTitle = UI.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Font = UI.HEAD, TextSize = 21,
	TextColor3 = C.alarm, TextXAlignment = Enum.TextXAlignment.Center, Text = "", LayoutOrder = 1, ZIndex = 36, Parent = alarmCard })
local alarmLine = UI.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Font = UI.HAND, TextSize = 21,
	TextXAlignment = Enum.TextXAlignment.Center, Text = "", LayoutOrder = 2, ZIndex = 36, Parent = alarmCard })
local homeHolder, homeButton = UI.button({ text = "🏠 Go home (3 s)", kind = "blue", size = UDim2.fromOffset(200, 42), order = 3, zIndex = 36, parent = alarmCard })
UI.onLayout(function()
	alarmCard.Position = UDim2.new(0.5, 0, 0, if UI.compact then 108 else 124)
	alarmCard.Size = UDim2.fromOffset(math.min(400, UI.screen.AbsoluteSize.X - 300), 0)
end)

-- The red pulse round the screen's edges.
local edges = {}
for _, spec in { { UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 18) }, { UDim2.new(0, 0, 1, -18), UDim2.new(1, 0, 0, 18) },
	{ UDim2.fromScale(0, 0), UDim2.new(0, 18, 1, 0) }, { UDim2.new(1, -18, 0, 0), UDim2.new(0, 18, 1, 0) } } do
	table.insert(edges, make("Frame", { Position = spec[1], Size = spec[2], BackgroundColor3 = C.alarm, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 34, Parent = UI.screen }))
end

local alarmToken = 0
homeButton.Activated:Connect(function()
	local result = TravelAction:InvokeServer("Home")
	if not result.ok then
		say(result.reason)
	else
		homeHolder.Visible = false
		alarmLine.Text = "Heading home... stand still!"
	end
end)

local function showAlarm(info)
	alarmToken += 1
	local token = alarmToken
	local crop = info.crop and Crops.ById[info.crop]
	alarmTitle.Text = if info.climbing then `🚨 {info.name} is climbing over your back fence!`
		elseif info.carrying then `🚨 {info.name} walked into your farm with stolen crops!`
		elseif crop then `🚨 {info.name} is stealing your {crop.icon} {crop.name}!`
		else `🚨 {info.name} is in your farm!`
	local home = myPlot() > 0 and inFarm(player) == myPlot()
	alarmLine.Text = if home then "Run over and press SWING to bonk them 🏏 (look for the red !)" else "Go home to catch them!"
	homeHolder.Visible = not home
	alarmCard.Visible = true
	for _, edge in edges do
		edge.BackgroundTransparency = 0.2
		local pulse = TweenService:Create(edge, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 4, true), { BackgroundTransparency = 1 })
		pulse.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				edge.BackgroundTransparency = 1 -- (a reversing tween ends where it began: red)
			end
		end)
		pulse:Play()
	end
	local stay = math.max(8, (info.ends or now()) - now() + 4)
	task.delay(stay, function()
		if alarmToken == token then
			alarmCard.Visible = false
		end
	end)
end

local function arrestedPop(info)
	alarmToken += 1
	alarmCard.Visible = false
	local pop = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromOffset(360, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.cream, Rotation = -3, ZIndex = 45, Parent = UI.screen,
	}, { UI.corner(6), UI.stroke(C.green, 4), make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
		make("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
	UI.label({ Size = UDim2.new(1, 0, 0, 40), Font = UI.HEAD, TextSize = 34, Text = "🚔 ARRESTED!", TextColor3 = C.green, TextStrokeColor3 = C.soilDark,
		TextStrokeTransparency = 0.6, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, ZIndex = 46, Parent = pop })
	local text = if info.owed <= 0 then `{info.name} paid you their {info.fine}-coin fine.`
		elseif info.paid > 0 then `{info.name} paid {info.paid} of their {info.fine}-coin fine to you. They owe you {info.owed} more: half of their sales come to you until it's paid.`
		else `{info.name} had no coins, so they owe you their {info.fine}-coin fine: half of their sales come to you until it's paid.`
	UI.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Font = UI.HAND, TextSize = 21, Text = text,
		TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, ZIndex = 46, Parent = pop })
	if info.paid > 0 then
		UI.float(`+{info.paid}`, UDim2.fromScale(0.5, 0.2), C.gold)
	end
	task.delay(5, function()
		pop:Destroy()
	end)
end

------------------------------------------------------------------------
-- Effects in the world: BONK!, a nudge, the arrest puff

local function popText(at: Vector3, text: string, color: Color3, size: number)
	local anchor = make("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(at + Vector3.new(0, 3, 0)),
		Parent = workspace.CurrentCamera,
	})
	local gui = make("BillboardGui", { Adornee = anchor, Size = UDim2.fromOffset(size * 5, size * 1.6), AlwaysOnTop = true, MaxDistance = 200, LightInfluence = 0, Parent = anchor })
	local label = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.3, 0.3), BackgroundTransparency = 1, Font = UI.HEAD,
		TextScaled = true, Text = text, TextColor3 = color, TextStrokeColor3 = C.soilDark, TextStrokeTransparency = 0, Rotation = -8, Parent = gui,
	})
	TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromScale(1, 1) }):Play()
	TweenService:Create(gui, TweenInfo.new(1.1), { StudsOffsetWorldSpace = Vector3.new(0, 2, 0) }):Play()
	task.delay(0.8, function()
		TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(1.2, function()
		anchor:Destroy()
	end)
end

local function starBurst(at: Vector3)
	for i = 1, 7 do
		local direction = CFrame.Angles(0, math.rad(i * 51), 0) * Vector3.new(1, 0.6 + (i % 3) * 0.3, 0)
		local star = make("Part", {
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5,
			Material = Enum.Material.Neon, Color = C.gold, CFrame = CFrame.new(at + Vector3.new(0, 2, 0)), Parent = workspace.CurrentCamera,
		})
		TweenService:Create(star, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(at + Vector3.new(0, 2, 0) + direction * 3), Size = Vector3.one * 0.15 }):Play()
		task.delay(0.55, function()
			star:Destroy()
		end)
	end
end

local function puff(at: Vector3)
	for i = 1, 9 do
		local offset = Vector3.new(math.cos(i * 0.7) * 1.6, (i % 3) * 0.8, math.sin(i * 0.7) * 1.6)
		local ball = make("Part", {
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Shape = Enum.PartType.Ball, Size = Vector3.one * 1.5,
			Color = Color3.fromRGB(245, 245, 240), Transparency = 0.1, CFrame = CFrame.new(at + offset), Parent = workspace.CurrentCamera,
		})
		TweenService:Create(ball, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 4.5, Transparency = 1,
			CFrame = CFrame.new(at + offset * 1.6 + Vector3.new(0, 1.5, 0)) }):Play()
		task.delay(1, function()
			ball:Destroy()
		end)
	end
end

------------------------------------------------------------------------
-- The reset button: off while you're a Suspect, knocked out or carrying

local resetAllowed: boolean? = nil
local function updateReset()
	local allowed = sackWeight() <= 0 and not knockedOut(player) and (player:GetAttribute("SuspectOf") or 0) == 0
	if allowed ~= resetAllowed then
		if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", allowed) then
			resetAllowed = allowed
		end
	end
end

------------------------------------------------------------------------

function CrimeController.Start()
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) -- (the bat lives in our hotbar)

	Remotes.event("CrimeEvent").OnClientEvent:Connect(function(kind, info)
		if kind == "Alarm" then
			showAlarm(info)
		elseif kind == "Bonk" and info.at then
			popText(info.at, "BONK!", C.gold, 30)
			starBurst(info.at)
		elseif kind == "Nudge" and info.at then
			popText(info.at, "boing!", C.cream, 18)
		elseif kind == "Puff" and info.at then
			puff(info.at)
			popText(info.at, "BUSTED!", C.red, 30)
		elseif kind == "Busted" then
			bustedCard(info)
		elseif kind == "Arrested" then
			arrestedPop(info)
		elseif kind == "Deposited" then
			UI.toast(`🧺 {info.text}`, "Good")
			UI.float("🧺", UDim2.fromScale(0.5, 0.6), C.gold)
		end
	end)

	-- Click with the bat in your hand: swing.
	local function watchBat(child: Instance)
		if child:IsA("Tool") and child.Name == "Bat" then
			child.Activated:Connect(swing)
		end
	end
	local function onCharacter(character: Model)
		character.ChildAdded:Connect(watchBat)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
	player:GetAttributeChangedSignal("Sack"):Connect(function()
		local weight = sackWeight()
		if weight > 0 then
			sackSign.Rotation = -2
			TweenService:Create(sackSign, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Rotation = 0 }):Play()
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		updateKnockout()
		updateSack()
		elapsed += dt
		if elapsed < TICK then
			return
		end
		elapsed = 0
		local ok, err = pcall(function()
			updateOffers()
			updateMarkers()
			updateRings()
			updateReset()
		end)
		if not ok then
			warn(`[CrimeController] {err}`)
		end
	end)
	Players.PlayerRemoving:Connect(function(other)
		local m = markers[other]
		if m then
			clearMarker(m.suspect)
			clearMarker(m.sack)
			clearMarker(m.stars)
			markers[other] = nil
		end
	end)
end

return CrimeController
