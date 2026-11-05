-- Raids on screen (docs/GameDesign.md §4.10–4.12, §5.4, §5.5; the art in
-- docs/ArtDirection.md §9). The server decides everything (CrimeService);
-- this draws it and sends intents:
--   * the context stamp (FieldController.offer): STEAL (hold) on a ripe crop
--     in someone else's field (or why not: a Sprout Shield, the Neighbourhood
--     Watch; none on a farm that trusts you), SWING near anyone in your farm,
--     ARREST (hold) over a knocked-out Suspect, TAKE BACK or GRAB (hold) by
--     a crop a bonked thief dropped, CLIMB at a back fence or at a gate
--     that stops you (locked, or shut on you by a Watchman);
--   * a ring of dots over a crop being stolen (everyone; always on top for
--     its owner), and the crop shaking; a label over a dropped crop with
--     the time left before it goes back to its owner's barn;
--   * a red ! over Suspects of your farm (always on top), a red "🎃 name" tag
--     over anyone carrying a stolen crop (held up over their head: the
--     server's CrimeArt; arms and the bat's swing: PoseController), dizzy
--     stars over anyone knocked out;
--   * the crop in your hands: a sign over the hotbar, "Get home!" with an
--     arrow to your barn; the knockout screen (grey, blurred, the countdown, Leave farm);
--     the BUSTED! mugshot card; BONK! and puffs;
--   * the theft alarm card: who and what, an arrow at the screen's edge
--     pointing to the thief, the Security Camera's live picture of them, the
--     Watchman shutting the gate once they have the crop, and Go home;
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
local DefenceRules = require(Shared.DefenceRules)
local LootRules = require(Shared.LootRules)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local WeatherRules = require(Shared.WeatherRules)

local Reasons = require(script.Parent.Parent.Reasons)
local Sfx = require(script.Parent.Parent.Sfx)
local UI = require(script.Parent.Parent.UI)
local FieldController = require(script.Parent.FieldController)
local HotbarController = require(script.Parent.HotbarController)
local HudController = require(script.Parent.HudController)
local PoseController = require(script.Parent.PoseController)

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

-- The stolen crop in someone's hands (CrimeService), if any.
local function carried(who: Player): string?
	return who:GetAttribute("StolenCrop")
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
-- Letting go first calls cancel(). Returns nothing. color: the bar's (red
-- by default: a crime or an arrest).
local function runHold(seconds: number, done: () -> (), cancel: (() -> ())?, stillValid: (() -> boolean)?, color: Color3?)
	holdToken += 1
	local token = holdToken
	local started = os.clock()
	FieldController.setProgress(0, color)
	while holdToken == token do
		local f = (os.clock() - started) / seconds
		FieldController.setProgress(f, color)
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
-- Dropped crops (a bonked thief's, §4.12): its owner, the farm's owner
-- and their Trusted friends hold TAKE BACK, anyone else GRAB

local picking = nil -- the dropped crop while a pick-up hold runs

local function plotModel(index: number?): Instance?
	return index and workspace.World:FindFirstChild(`Plot{index}`)
end

-- What picking up this dropped crop does for you: "TakeBack" or "Grab".
local function dropRole(drop: Instance): string
	local farm = plotModel(drop:GetAttribute("Plot"))
	local cropOwnerId = drop:GetAttribute("OwnerId")
	local cropFarm = nil
	for index = 1, PlotLayout.COUNT do
		local model = plotModel(index)
		if model and model:GetAttribute("OwnerId") == cropOwnerId then
			cropFarm = model
		end
	end
	return LootRules.dropRole({
		whoId = player.UserId, cropOwnerId = cropOwnerId, farmOwnerId = farm and farm:GetAttribute("OwnerId"),
		trustedByCrop = cropFarm ~= nil and DefenceRules.inTrustedText(cropFarm:GetAttribute("Trusted"), player.UserId),
		trustedByFarm = farm ~= nil and DefenceRules.inTrustedText(farm:GetAttribute("Trusted"), player.UserId),
	})
end

-- The nearest dropped crop you can reach in the farm you're in.
local function nearestDrop(here: number): Model?
	local me = rootOf(player)
	if not me or here == 0 then
		return nil
	end
	local best, bestDistance = nil, Crime.DROP_REACH
	for _, drop in CollectionService:GetTagged("DroppedCrop") do
		if drop:IsA("Model") and drop:GetAttribute("Plot") == here then
			local at = drop:GetPivot().Position
			local distance = Vector2.new(at.X - me.Position.X, at.Z - me.Position.Z).Magnitude
			if distance <= bestDistance then
				best, bestDistance = drop, distance
			end
		end
	end
	return best
end

local function pickUp(drop: Model)
	local pressed = holdToken
	local id = tostring(drop:GetAttribute("DropId"))
	local result = CrimeAction:InvokeServer("PickUpStart", id)
	if not result.ok then
		say(result.reason)
		return
	elseif holdToken ~= pressed then
		task.spawn(CrimeAction.InvokeServer, CrimeAction, "PickUpCancel") -- (let go before the server answered)
		return
	end
	picking = drop
	local crop = Crops.ById[drop:GetAttribute("Crop")]
	local takeBack = result.result.role == "TakeBack"
	runHold(result.result.seconds + 0.05, function()
		picking = nil
		local done = CrimeAction:InvokeServer("PickUp", id)
		if done.ok then
			floatAtStamp(if takeBack then `{crop.icon} back in the barn` else `+1 {crop.icon} 🧺`, if takeBack then C.green else C.alarm)
		else
			say(done.reason)
		end
	end, function()
		picking = nil
		task.spawn(CrimeAction.InvokeServer, CrimeAction, "PickUpCancel")
	end, function()
		return drop.Parent ~= nil and not knockedOut(player)
	end, if takeBack then C.green else nil)
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
	faceNearest()
	if HotbarController.equipBat() and player.Character then
		PoseController.swing(player.Character) -- (at once on your screen; everyone else's from SwingAt)
	end
	task.wait(PoseController.WIND_UP) -- (it lands as the bat comes round; and the server sees you've turned)
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

-- A farm's gate stops you going `direction` (shared/DefenceRules.gateBlocks).
local function gateBlocksMe(index: number, direction: string): boolean
	local model = workspace.World:FindFirstChild(`Plot{index}`)
	if not model or model:GetAttribute("OwnerId") == nil then
		return false
	end
	return DefenceRules.gateBlocks({
		mine = myPlot() == index, trusted = DefenceRules.inTrustedText(model:GetAttribute("Trusted"), player.UserId),
		locked = model:GetAttribute("GateLocked") == true, shut = (model:GetAttribute("GateShutUntil") or 0) > now(),
		suspect = (player:GetAttribute("SuspectOf") or 0) == index, carrying = carried(player) ~= nil, direction = direction,
	})
end

-- Where you could climb: a back fence (either side), or a gate that stops
-- you. Returns the farm, "In"/"Out", and "fence"/"gate".
local function climbHere(): (number?, string?, string?)
	local root = rootOf(player)
	if not root then
		return nil, nil, nil
	end
	for index = 1, PlotLayout.COUNT do
		local p = PlotLayout.frame(index):PointToObjectSpace(root.Position)
		local direction = PlotLayout.climbAt(p, Crime.CLIMB_REACH)
		if direction then
			return index, direction, "fence"
		end
		direction = PlotLayout.gateClimbAt(p, Crime.CLIMB_REACH)
		if direction and gateBlocksMe(index, direction) then
			return index, direction, "gate"
		end
	end
	return nil, nil, nil
end

-- Why you can't steal on this farm right now (nil: you can try): your own
-- Sprout Shield or arrival grace, theirs, or the raid cap's Neighbourhood
-- Watch. Returns the stamp's words and the chalkboard line.
local function protection(here: number): (string?, string?)
	local t = now()
	local mine = math.max(player:GetAttribute("ShieldUntil") or 0, player:GetAttribute("GraceUntil") or 0) - t
	if mine > 0 then
		local shield = (player:GetAttribute("ShieldUntil") or 0) > t
		return "SHIELD", if shield then `🌱 Your Sprout Shield is on for {UI.formatTime(mine)}: no stealing until it ends (or drop it in 🛡️ Defend)`
			else `🌱 You just arrived: no stealing for {UI.formatTime(mine)}`
	end
	local model = workspace.World:FindFirstChild(`Plot{here}`)
	local owner = model and Players:GetPlayerByUserId(model:GetAttribute("OwnerId") or 0)
	if owner then
		local theirs = math.max(owner:GetAttribute("ShieldUntil") or 0, owner:GetAttribute("GraceUntil") or 0) - t
		if theirs > 0 then
			return "SHIELD", `🌱 {owner.DisplayName}'s farm is protected for {UI.formatTime(theirs)}`
		end
	end
	local dome = model and model:FindFirstChild("Dome")
	if dome and dome:GetAttribute("Kind") == "Watch" then
		return "WATCHED", `👮 The neighbours are watching this farm: wait {UI.formatTime(math.max(0, (dome:GetAttribute("Ends") or t) - t))}`
	end
	return nil, nil
end

-- The first time you go to climb a locked gate: are you sure?
local gateWarned = false
local gateConfirm = nil
local function confirmGate(owner: string)
	if gateConfirm then
		return
	end
	gateConfirm = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(360, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.cream, ZIndex = 45, Parent = UI.screen,
	}, { UI.corner(6), UI.stroke(C.alarm, 4), make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
		make("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
	UI.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Font = UI.HEAD, TextSize = 20, TextColor3 = C.alarm,
		TextXAlignment = Enum.TextXAlignment.Center, Text = `🔒 Climb into {owner}'s farm?`, LayoutOrder = 1, ZIndex = 46, Parent = gateConfirm })
	UI.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Font = UI.HAND, TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Center, Text = "Their gate is locked: climbing in counts as trespassing. You'll be a Suspect, so they can bonk you and arrest you.",
		LayoutOrder = 2, ZIndex = 46, Parent = gateConfirm })
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 3, ZIndex = 46, Parent = gateConfirm },
		{ make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
	local _, go = UI.button({ text = "Climb in", kind = "red", size = UDim2.fromOffset(140, 42), zIndex = 46, parent = row })
	local _, stop = UI.button({ text = "Cancel", kind = "cream", size = UDim2.fromOffset(120, 42), zIndex = 46, parent = row })
	local function close()
		if gateConfirm then
			gateConfirm:Destroy()
			gateConfirm = nil
		end
	end
	go.Activated:Connect(function()
		gateWarned = true
		close()
		local result = CrimeAction:InvokeServer("Climb")
		if not result.ok then
			say(result.reason)
		end
	end)
	stop.Activated:Connect(close)
	task.delay(10, close)
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
				and not other:GetAttribute("Busted") -- (arrested: on their way to the police)
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
			local suspect = (other:GetAttribute("SuspectOf") or 0) == mine or carried(other) ~= nil
			return inFarm(other) == mine and not knockedOut(other) and (suspect or armed)
		end, Crime.SWING_NEAR)
	end
	if victim then
		local suspect = (victim:GetAttribute("SuspectOf") or 0) == mine or carried(victim) ~= nil
		-- (just woken up, a bonk only nudges them: a crop they dropped comes first)
		local immune = (victim:GetAttribute("ImmuneUntil") or 0) > now()
		FieldController.offer("Swing", {
			priority = if immune then 22 else 30, text = "SWING\n ", sub = `🏏 {victim.DisplayName}`, kind = "red",
			info = if immune then `{victim.DisplayName} just woke up: for a few seconds a bonk only nudges them`
				elseif suspect then `{victim.DisplayName} is a Suspect: bonk, then arrest!`
				else `{victim.DisplayName} is only visiting (bonking pays nothing)`,
			press = swing,
		})
	else
		FieldController.withdraw("Swing")
	end

	-- STEAL: a ripe crop under you, in someone else's farm (not a friend's
	-- that trusts you: you harvest those for them, FieldController)
	local offered = false
	local hereModel = here > 0 and workspace.World:FindFirstChild(`Plot{here}`)
	local trustsMe = hereModel and DefenceRules.inTrustedText(hereModel:GetAttribute("Trusted"), player.UserId)
	if not me and not stealing and here > 0 and here ~= mine and not trustsMe then
		local part, tile = tileUnder(here)
		local cropId = part and part:GetAttribute("Stage") == "Ripe" and part:GetAttribute("Crop")
		local blocked, why = protection(here)
		if part and tile and cropId and blocked then
			offered = true
			FieldController.offer("Steal", {
				priority = 20, text = `{blocked}\n `, sub = "no stealing", kind = "wood", info = why,
				press = function()
					UI.toast(why :: string, "Error", 3)
				end,
			})
		elseif part and tile and cropId then
			offered = true
			local crop = Crops.ById[cropId]
			local holding = carried(player)
			local suspect = (player:GetAttribute("SuspectOf") or 0) == here
			local cloche = part:GetAttribute("Cloche") == true
			if holding then
				local inHand = Crops.ById[holding]
				local what = Crops.count(holding, player:GetAttribute("StolenCount") or 1)
				FieldController.offer("Steal", {
					priority = 20, text = "HANDS\nFULL", kind = "wood", -- (two words fill the stamp)
					info = `You can carry one patch at a time: take your {inHand.icon} {what} home first`,
					press = function()
						UI.toast(`Your hands are full! Take your {what} home first.`, "Error", 2.5)
					end,
				})
			else
				-- the whole patch, or one of the big ones (a pumpkin, a melon)
				local count = math.min(part:GetAttribute("Yield") or crop.perPatch, crop.carry or math.huge)
				local heist = WeatherRules.isHeistNight(WeatherRules.now())
				local hold = (string.gsub(string.format("%.1f", CrimeRules.stealHold(crop.rarity, { cloche = cloche, harvestMoon = heist })), "%.0$", ""))
				FieldController.offer("Steal", {
					priority = 20, text = "STEAL\n ", sub = `{crop.icon} ×{count}`, kind = "red",
					info = if suspect then `Hold {hold} s{if cloche then " (it's under glass)" elseif heist then " (Heist Night!)" else ""}, then carry {if count == 1 then "it" else "them"} home over your head`
						elseif cloche then `🔮 Under a glass cloche: {hold} s to steal. Stealing makes you a Suspect!`
						elseif heist then `🌕 Heist Night: steals are quicker ({hold} s). Stealing makes you a Suspect!`
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

	-- TAKE BACK / GRAB: a crop a bonked thief dropped, within reach
	local drop = picking or (if not me and not stealing then nearestDrop(here) else nil)
	if drop and drop.Parent then
		local crop = Crops.ById[drop:GetAttribute("Crop")]
		local what = `{crop.icon} ×{drop:GetAttribute("Count") or 1}`
		local blocked, why = protection(here)
		local function press()
			pickUp(drop)
		end
		-- (while the hold runs it keeps the stamp: SWING coming back as a
		-- thief's immunity ends mustn't take it over)
		local priority = if picking then 35 else 25
		if dropRole(drop) == "TakeBack" then
			FieldController.offer("PickUp", {
				priority = priority, text = "TAKE\nBACK", kind = "green", -- (two words fill the stamp: the crop's in the hint)
				info = `Hold to put the {what} back in the barn, before someone grabs it`, press = press, release = letGo,
			})
		elseif blocked and not picking then
			FieldController.offer("PickUp", {
				priority = 25, text = `{blocked}\n `, sub = "no grabbing", kind = "wood", info = why,
				press = function()
					UI.toast(why :: string, "Error", 3)
				end,
			})
		elseif carried(player) and not picking then
			FieldController.offer("PickUp", {
				priority = 25, text = "HANDS\nFULL", kind = "wood", info = `{what} dropped here, but your hands are full: take your crop home first`,
				press = function()
					UI.toast("Your hands are full! Take your crop home first.", "Error", 2.5)
				end,
			})
		else
			FieldController.offer("PickUp", {
				priority = priority, text = "GRAB\n ", sub = what, kind = "red",
				info = if drop:GetAttribute("DroppedBy") == player.UserId then "You dropped it! Grabbing it back makes you a Suspect again: the farmer can bonk and arrest you!"
					else "A thief dropped it. Grabbing it makes you a Suspect: the farmer can bonk and arrest you!",
				press = press, release = letGo,
			})
		end
	else
		FieldController.withdraw("PickUp")
	end

	-- CLIMB: at a back fence, either side; at a gate that stops you
	local plot, direction, over = nil, nil, nil
	if not me and not stealing and not picking then
		plot, direction, over = climbHere()
	end
	if plot then
		local model = workspace.World:FindFirstChild(`Plot{plot}`)
		local owner = model and model:GetAttribute("OwnerName")
		local trusted = model and DefenceRules.inTrustedText(model:GetAttribute("Trusted"), player.UserId)
		local trespass = direction == "In" and plot ~= mine and owner ~= nil and not trusted
		local what = if over == "gate" then "the gate" else "the back fence"
		FieldController.offer("Climb", {
			priority = 10, text = "CLIMB\n ", sub = if over == "gate" then (if direction == "In" then "the gate" else "out!") elseif direction == "In" then "in" else "out",
			kind = if trespass then "red" else "blue",
			info = if trespass and over == "gate" then `🔒 {owner}'s gate is locked. Climbing in makes you a Suspect!`
				elseif trespass then `Climbing into {owner}'s farm makes you a Suspect!`
				elseif over == "gate" then "🔔 The Watchman shut the gate on you: climb out!"
				elseif direction == "In" then `Climb over {what}`
				else `Climb out over {what}`,
			press = function()
				if trespass and over == "gate" and not gateWarned then
					confirmGate(owner)
					return
				end
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
-- Markers over people: the Suspect !, the carrier's tag, dizzy stars

local markers = {} -- [Player] = { suspect, carry, carryCrop, stars }

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

-- A red name with the crop's icon, over the crop they're holding up.
local function carryTag(other: Player, head: BasePart, cropId: string)
	local gui = billboard("CarryTag", head, UDim2.fromScale(7, 1.1), Vector3.new(0, 5.4, 0), false, 150)
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = UI.HEAD, TextScaled = true,
		Text = `{Crops.ById[cropId].icon} {other.DisplayName}`, TextColor3 = C.alarm, TextStrokeColor3 = C.cream, TextStrokeTransparency = 0.2, Parent = gui,
	})
	return gui
end

-- Over a dropped crop: what it is, and a bar running down to when it goes
-- back to its owner's barn by itself.
local dropLabels = {} -- [Model] = { gui, bar }

local function labelDrop(drop: Instance)
	local core = drop:IsA("Model") and (drop.PrimaryPart or drop:FindFirstChild("Core"))
	local crop = Crops.ById[drop:GetAttribute("Crop") or ""]
	if dropLabels[drop] or not core or not core:IsA("BasePart") or not crop then
		return
	end
	local top = (core:GetAttribute("Height") or 2) - (core:GetAttribute("HoldY") or 1) -- (from the core up to the crop's top)
	local gui = billboard("DropLabel", core, UDim2.fromOffset(96, 56), Vector3.new(0, top + 1.6, 0), false, 120)
	local plate = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.cream, Parent = gui },
		{ UI.corner(8), UI.stroke(C.soil, 2) })
	UI.label({ Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 16), Font = UI.HAND, TextSize = 16, Text = "Dropped!",
		TextColor3 = C.soil, TextXAlignment = Enum.TextXAlignment.Center, Parent = plate })
	UI.label({ Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 24), Font = UI.HEAD, TextSize = 20,
		Text = `{crop.icon} ×{drop:GetAttribute("Count") or 1}`, TextColor3 = C.ink, TextXAlignment = Enum.TextXAlignment.Center, Parent = plate })
	local track = make("Frame", { Position = UDim2.new(0, 10, 1, -11), Size = UDim2.new(1, -20, 0, 6), BackgroundColor3 = C.stitch,
		BorderSizePixel = 0, Parent = plate }, { UI.corner(3) })
	local bar = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.gold, BorderSizePixel = 0, Parent = track }, { UI.corner(3) })
	dropLabels[drop] = { gui = gui, bar = bar }
end

local function updateDropLabels()
	local t = now()
	for drop, label in dropLabels do
		if drop.Parent == nil then
			label.gui:Destroy()
			dropLabels[drop] = nil
		else
			local left = math.clamp(((drop:GetAttribute("Expires") or t) - t) / Crime.DROP_SECONDS, 0, 1)
			label.bar.Size = UDim2.fromScale(left, 1)
		end
	end
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
			clearMarker(m.carry)
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
		-- a red name with the crop's icon over anyone carrying one, for everyone
		local cropId = carried(other)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = if cropId then Enum.HumanoidDisplayDistanceType.None else Enum.HumanoidDisplayDistanceType.Viewer
		end
		if cropId and other ~= player and not (m.carry and m.carry.Adornee == head and m.carryCrop == cropId) then
			clearMarker(m.carry)
			m.carry, m.carryCrop = carryTag(other, head, cropId), cropId
		elseif (not cropId or other == player) and m.carry then
			clearMarker(m.carry)
			m.carry, m.carryCrop = nil, nil
		end
		if m.carry and m.suspect then
			m.carry.Enabled = false -- (the ! already names them)
		elseif m.carry then
			m.carry.Enabled = true
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

local function makeRing(part: BasePart, owned: boolean, cropId: string?)
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
		BackgroundTransparency = 1, Font = UI.HEAD, TextSize = 34, Text = if cropId and Crops.ById[cropId] then Crops.ById[cropId].icon else "🌱", Parent = gui,
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
			ring = makeRing(part, plot ~= nil and plot == mine, part:GetAttribute("Crop"))
			Sfx.play("Rustle", part)
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
-- The crop in your hands: a sign over the hotbar with an arrow to your barn

local carrySign = make("Frame", {
	Name = "CarrySign", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(340, 44), Visible = false, Parent = UI.screen,
}, { UI.corner(6), UI.stroke(UI.SEAM, 3) })
UI.wood(carrySign, 2, false, C.red)
local carryLabel = UI.label({
	Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -64, 1, 0), Font = UI.HEAD, TextSize = 20, TextColor3 = C.cream,
	TextStrokeColor3 = UI.SEAM, TextStrokeTransparency = 0, Text = "", ZIndex = 3, Parent = carrySign,
})
UI.fit(carryLabel, 11)
local arrowDisc = make("Frame", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = C.cream, ZIndex = 3, Parent = carrySign,
}, { UI.corner(18), UI.stroke(UI.SEAM, 2) })
local arrow = make("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = UI.HEAD, Text = "↑", TextSize = 28, TextColor3 = C.red, ZIndex = 4, Parent = arrowDisc,
})
UI.onLayout(function()
	carrySign.Position = UDim2.new(0.5, 0, 1, -(HudController.HOTBAR_HEIGHT + 20))
end)

local function updateCarrySign()
	local cropId = carried(player)
	carrySign.Visible = cropId ~= nil and not knockedOut(player)
	local travel = UI.screen:FindFirstChild("Travel")
	if travel then
		travel.Visible = cropId == nil -- (no travel with stolen crops: walk home)
	end
	if not cropId then
		return
	end
	local crop = Crops.ById[cropId]
	local mine = myPlot()
	local what = `{crop.icon} {Crops.count(cropId, player:GetAttribute("StolenCount") or 1)}`
	carryLabel.Text = `{what} · Get home!` -- (it's yours once you're in your own farm)
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
			if UI.calm then nil else make("BlurEffect", { Size = 6, Parent = camera }), -- (Reduced motion: grey, no blur)
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
				if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("Tool") or child.Name == "CarriedCrop" or child:IsA("BillboardGui") then
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
		`Fine: {UI.formatNumber(info.fine)} coins, paid to {info.owner}`,
	}
	if info.owed > 0 then
		table.insert(lines, if info.paid > 0
			then `You had {UI.formatNumber(info.paid)}: you owe {info.owner} {UI.formatNumber(info.owed)} more. Half of your sales pay it off.`
			else `You had no coins: you owe {info.owner} {UI.formatNumber(info.owed)}. Half of your sales pay it off.`)
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
local alarm = nil -- { userId, plot, untilAt } while the alarm card is up

-- The arrow at the screen's edge pointing to the thief (when they're off
-- your screen), with their name.
local arrow = make("Frame", {
	Name = "AlarmArrow", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(58, 58), BackgroundColor3 = C.alarm, Visible = false, ZIndex = 34, Parent = UI.screen,
}, { UI.corner(29), UI.stroke(C.cream, 3) })
-- (drawn, not a ➤: that character doesn't show in the game's fonts) a shaft
-- and two barbs pointing right; the whole thing turns to the thief
local arrowHead = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40),
	BackgroundTransparency = 1, ZIndex = 35, Parent = arrow })
make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.42, 0.5), Size = UDim2.fromOffset(24, 7), BackgroundColor3 = C.cream,
	BorderSizePixel = 0, ZIndex = 35, Parent = arrowHead }, { UI.corner(3) })
for _, turn in { 40, -40 } do
	make("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.82, 0, 0.5, if turn > 0 then -5 else 5), Size = UDim2.fromOffset(17, 7),
		Rotation = turn, BackgroundColor3 = C.cream, BorderSizePixel = 0, ZIndex = 36, Parent = arrowHead }, { UI.corner(3) })
end
local arrowName = UI.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.fromOffset(120, 18), Font = UI.HEAD, TextSize = 15,
	TextColor3 = C.cream, TextStrokeColor3 = C.soilDark, TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center, Text = "", ZIndex = 35, Parent = arrow })

local function updateArrow()
	local thief = alarm and alarm.untilAt > now() and Players:GetPlayerByUserId(alarm.userId)
	local root = thief and rootOf(thief)
	if not root then
		arrow.Visible = false
		return
	end
	local camera = workspace.CurrentCamera
	local point, onScreen = camera:WorldToViewportPoint(root.Position)
	local size = camera.ViewportSize
	if onScreen and point.X > 40 and point.X < size.X - 40 and point.Y > 40 and point.Y < size.Y - 40 then
		arrow.Visible = false
		return
	end
	-- (behind you: the projection flips, so point the other way)
	local dx, dy = point.X - size.X / 2, point.Y - size.Y / 2
	if point.Z < 0 then
		dx, dy = -dx, -dy
	end
	if math.abs(dx) < 1e-3 and math.abs(dy) < 1e-3 then
		dy = 1
	end
	-- (round the edge of the screen, clear of the coin sign at the top and the hotbar)
	local top, bottom = 150, size.Y - 130
	local cx, cy = size.X / 2, (top + bottom) / 2
	local hx, hy = size.X / 2 - 50, math.max(20, (bottom - top) / 2)
	local scale = math.min(hx / math.max(math.abs(dx), 1e-3), hy / math.max(math.abs(dy), 1e-3))
	local inset = UI.screen.AbsolutePosition
	arrow.Position = UDim2.fromOffset(cx + dx * scale - inset.X, cy + dy * scale - inset.Y)
	arrowHead.Rotation = math.deg(math.atan2(dy, dx))
	arrowName.Text = thief.DisplayName
	arrow.Visible = true
end

-- The Security Camera's picture (§4.11): the thief, live, seen from the
-- camera on your barn, over the tiles round them.
local feed = make("ViewportFrame", {
	Name = "CameraFeed", Size = UDim2.new(1, 0, 0, 150), BackgroundColor3 = Color3.fromRGB(40, 52, 44), LightColor = Color3.fromRGB(240, 240, 230),
	Ambient = Color3.fromRGB(150, 160, 150), LightDirection = Vector3.new(-1, -2, -1), Visible = false, ZIndex = 36,
}, { UI.corner(4), UI.stroke(C.soilDark, 2) })
local feedWorld = make("WorldModel", { Parent = feed })
local feedCamera = make("Camera", { FieldOfView = 34, Parent = feed })
feed.CurrentCamera = feedCamera
UI.label({ Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(160, 18), Font = UI.HEAD, TextSize = 14, TextColor3 = Color3.fromRGB(255, 90, 80),
	Text = "● REC  CAM 1", ZIndex = 37, Parent = feed })
local feedLost = UI.label({ Size = UDim2.fromScale(1, 1), Font = UI.HAND, TextSize = 20, TextColor3 = C.cream, TextXAlignment = Enum.TextXAlignment.Center,
	Text = "📹 No signal: they're out of the camera's sight", Visible = false, ZIndex = 37, Parent = feed })
local feedPairs = {} -- { { copy, source } }
local feedFor = nil

local function clearFeed()
	feedWorld:ClearAllChildren()
	table.clear(feedPairs)
	feedFor = nil
end

local function startFeed(thief: Player, plot: number)
	clearFeed()
	local character = thief.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root then
		feedLost.Visible = true
		return
	end
	feedLost.Visible = false
	feedFor = thief
	local was = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = was
	for _, thing in copy:GetDescendants() do
		if thing:IsA("Script") or thing:IsA("LocalScript") or thing:IsA("Sound") or thing:IsA("BillboardGui") then
			thing:Destroy()
		end
	end
	local sources = {}
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			sources[part:GetFullName()] = part
		end
	end
	for _, part in copy:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			local path = string.gsub(part:GetFullName(), "^" .. string.gsub(copy:GetFullName(), "%p", "%%%0"), character:GetFullName())
			local source = sources[path]
			if source then
				table.insert(feedPairs, { part, source })
			end
		end
	end
	copy.Parent = feedWorld
	-- the tiles round them (as they are now) and the lawn
	local model = workspace.World:FindFirstChild(`Plot{plot}`)
	local field = model and model:FindFirstChild("Field")
	for _, tile in (field and field:GetChildren()) or {} do
		if tile:IsA("BasePart") and (tile.Position - root.Position).Magnitude < 34 then
			local was2 = tile.Archivable
			tile.Archivable = true
			local ok, clone = pcall(tile.Clone, tile)
			tile.Archivable = was2
			if ok and clone then
				clone.Parent = feedWorld
			end
		end
	end
	make("Part", { Anchored = true, Size = Vector3.new(160, 0.4, 160), CFrame = CFrame.new(root.Position.X, root.Position.Y - 3.4, root.Position.Z),
		Color = Color3.fromRGB(125, 190, 90), Material = Enum.Material.SmoothPlastic, Parent = feedWorld })
end

local function updateFeed()
	if not feed.Visible or not feedFor then
		return
	end
	local root = rootOf(feedFor)
	if not root or not alarm then
		feedLost.Visible = true
		return
	end
	feedLost.Visible = false
	for _, pair in feedPairs do
		if pair[2].Parent then
			pair[1].CFrame = pair[2].CFrame
		end
	end
	local mount = PlotLayout.frame(alarm.plot):PointToWorldSpace(PlotLayout.PLOT.camera)
	feedCamera.CFrame = CFrame.lookAt(mount, root.Position)
	-- (zoomed in on them: about 12 studs across wherever they are)
	feedCamera.FieldOfView = math.clamp(math.deg(2 * math.atan(6 / math.max((root.Position - mount).Magnitude, 1))), 5, 40)
end

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
	if not (alarmCard.Visible and alarm and alarm.userId == info.userId) then
		Sfx.play("Siren") -- (once per thief, not for every crop they touch)
	end
	Sfx.duck(8)
	alarmToken += 1
	local token = alarmToken
	local crop = info.crop and Crops.ById[info.crop]
	alarmTitle.Text = if info.climbing == "gate" then `🚨 {info.name} is climbing over your locked gate!`
		elseif info.climbing then `🚨 {info.name} is climbing over your back fence!`
		elseif info.carrying then `🚨 {info.name} walked into your farm with stolen crops!`
		elseif info.grab and crop then `🚨 {info.name} is grabbing the dropped {crop.icon} {crop.name}!`
		elseif crop then `🚨 {info.name} is stealing your {crop.icon} {crop.name}!`
		else `🚨 {info.name} is in your farm!`
	local home = myPlot() > 0 and inFarm(player) == myPlot()
	alarmLine.Text = if home then "Run over and press SWING to bonk them 🏏 (look for the red !)" else "Go home to catch them!"
	homeHolder.Visible = not home
	local near = UI.screen:FindFirstChild("ScarecrowWarning") -- (the scarecrow's softer card gives way: DefenceController)
	if near then
		near.Visible = false
	end
	alarm = { userId = info.userId, plot = info.plot or myPlot(), untilAt = math.max(now() + 8, (info.ends or now()) + 4) }
	local thief = Players:GetPlayerByUserId(info.userId or 0)
	feed.Visible = info.camera == true and thief ~= nil
	if feed.Visible and thief and feedFor ~= thief then
		startFeed(thief, alarm.plot)
	end
	alarmCard.Visible = true
	for _, edge in edges do
		-- (Settings: Flashing effects scales it; at 0 there's no red edge)
		edge.BackgroundTransparency = 1 - 0.8 * UI.flashing
		local pulse = TweenService:Create(edge, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 4, true), { BackgroundTransparency = 1 })
		pulse.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				edge.BackgroundTransparency = 1 -- (a reversing tween ends where it began: red)
			end
		end)
		pulse:Play()
	end
	local stay = math.max(8, (info.ends or now()) - now() + 4) + (if info.camera then 6 else 0)
	alarm.untilAt = now() + stay
	task.delay(stay, function()
		if alarmToken == token then
			alarmCard.Visible = false
			feed.Visible = false
			alarm = nil
			clearFeed()
		end
	end)
end

local function arrestedPop(info)
	alarmToken += 1
	alarmCard.Visible = false
	feed.Visible = false
	alarm = nil
	clearFeed()
	local pop = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromOffset(360, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.cream, Rotation = -3, ZIndex = 45, Parent = UI.screen,
	}, { UI.corner(6), UI.stroke(C.green, 4), make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
		make("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
	UI.label({ Size = UDim2.new(1, 0, 0, 40), Font = UI.HEAD, TextSize = 34, Text = "🚔 ARRESTED!", TextColor3 = C.green, TextStrokeColor3 = C.soilDark,
		TextStrokeTransparency = 0.6, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, ZIndex = 46, Parent = pop })
	local fine, paid, owed = UI.formatNumber(info.fine), UI.formatNumber(info.paid), UI.formatNumber(info.owed)
	local text = if info.owed <= 0 then `{info.name} paid you their {fine}-coin fine.`
		elseif info.paid > 0 then `{info.name} paid {paid} of their {fine}-coin fine to you. They owe you {owed} more: half of their sales come to you until it's paid.`
		else `{info.name} had no coins, so they owe you their {fine}-coin fine: half of their sales come to you until it's paid.`
	UI.label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Font = UI.HAND, TextSize = 21, Text = text,
		TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, ZIndex = 46, Parent = pop })
	if info.paid > 0 then
		UI.float(`+{paid}`, UDim2.fromScale(0.5, 0.2), C.gold)
	end
	UI.holdCentre(5)
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

-- The Golden Bat's bonk (looks only): gold sparkles on top of the stars.
local function goldBurst(at: Vector3)
	local anchor = make("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one,
		CFrame = CFrame.new(at + Vector3.new(0, 2, 0)), Parent = workspace.CurrentCamera,
	})
	local sparks = make("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(255, 220, 110)), Rate = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(9, 15), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -16, 0), LightEmission = 0.7, Parent = anchor,
	})
	sparks:Emit(36)
	task.delay(1.2, function()
		anchor:Destroy()
	end)
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
	local allowed = carried(player) == nil and not knockedOut(player) and (player:GetAttribute("SuspectOf") or 0) == 0
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
			Sfx.at("Bonk", info.at, 0.95 + math.random() * 0.1)
			local golden = info.skin == "GoldenBat"
			popText(info.at, "BONK!", C.gold, if golden then 40 else 30)
			starBurst(info.at)
			if golden then
				goldBurst(info.at)
			end
		elseif kind == "Nudge" and info.at then
			popText(info.at, "boing!", C.cream, 18)
		elseif kind == "Puff" and info.at then
			puff(info.at)
			popText(info.at, "BUSTED!", C.red, 30)
		elseif kind == "Busted" then
			Sfx.play("Whistle")
			bustedCard(info)
		elseif kind == "Arrested" then
			Sfx.play("Whistle")
			if (info.paid or 0) > 0 then
				task.delay(0.9, Sfx.play, "CashRegister") -- (the fine, paid to you: §4.12)
			end
			arrestedPop(info)
		elseif kind == "GateShut" then
			local line = `🔔 Your Watchman shut the gate on {info.name} for {info.seconds} s.`
			if alarmCard.Visible then
				alarmLine.Text ..= `\n{line}`
			else
				UI.toast(line, "Announce", 4)
			end
		elseif kind == "Deposited" then
			local crop = info.crop and Crops.ById[info.crop]
			UI.toast(info.text, "Good")
			UI.float(if crop then crop.icon else "⭐", UDim2.fromScale(0.5, 0.6), C.gold)
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
	player:GetAttributeChangedSignal("StolenCrop"):Connect(function()
		if carried(player) then
			carrySign.Rotation = -2
			TweenService:Create(carrySign, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Rotation = 0 }):Play()
		end
	end)

	local elapsed = 0
	feed.LayoutOrder = 3
	feed.Parent = alarmCard
	homeHolder.LayoutOrder = 4
	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(function()
			updateArrow()
			updateFeed()
		end)
		if not ok then
			warn(`[CrimeController] {err}`)
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		updateKnockout()
		updateCarrySign()
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
	CollectionService:GetInstanceAddedSignal("DroppedCrop"):Connect(function(drop)
		task.defer(labelDrop, drop) -- (once its parts have arrived)
	end)
	for _, drop in CollectionService:GetTagged("DroppedCrop") do
		labelDrop(drop)
	end
	RunService.Heartbeat:Connect(updateDropLabels)
	Players.PlayerRemoving:Connect(function(other)
		local m = markers[other]
		if m then
			clearMarker(m.suspect)
			clearMarker(m.carry)
			clearMarker(m.stars)
			markers[other] = nil
		end
	end)
end

return CrimeController
