-- Working your field (docs/GameDesign.md §5.2): the big round stamp at the
-- bottom right does whatever the tile you're standing on needs: Harvest
-- (ripe), Water (growing, not watered this stage), Plant (empty soil: the
-- seed packet picked in the hotbar; with none in hand it opens the seed
-- picker, and plants what you pick). A chalkboard above it says what's
-- there and how long it has left, and the tile gets an outline. A key cap
-- on its rim says which key does it (E; X on a gamepad; none on a phone).
--
-- A smaller stamp sits above it when there's a second thing to do (F; B on a
-- gamepad): on a growing crop, hold it to dig the crop up, and on empty soil
-- with a seed in hand, it opens the seed picker to change seed (the user,
-- 2026-11-06: "Find a way that makes it easy and convenient for players to
-- plant and switch their seeds").
--
-- Hold the button (or E) and walk along a row to plant, water or harvest
-- every tile you cross. The server checks everything (FieldService); the
-- tiles' attributes (server/World/FarmArt) say what's on them. In a friend's
-- farm that trusts you, you can water and harvest for them (§4.1).
--
-- Other controllers can put their own action on the stamp, over the tile's
-- (FieldController.offer: CrimeController's Steal, Swing, Arrest, Climb),
-- with a progress bar for holds (FieldController.setProgress).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared.Config.Crops)
local DefenceRules = require(Shared.DefenceRules)
local LandRules = require(Shared.LandRules)
local PlotLayout = require(Shared.PlotLayout)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local WeatherRules = require(Shared.WeatherRules)

local Reasons = require(script.Parent.Parent.Reasons)
local Sfx = require(script.Parent.Parent.Sfx)
local UI = require(script.Parent.Parent.UI)
local HotbarController = require(script.Parent.HotbarController)
local PlayerState = require(script.Parent.Parent.PlayerState)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer
local FieldAction = Remotes.func("FieldAction")

local FieldController = {}

local REPEAT = 0.12 -- seconds between tries while held
local SAME_TILE_GAP = 0.8 -- don't redo the same action on the same tile sooner (its attributes take a moment to arrive)
local DIG_HOLD = 0.8 -- seconds you hold to dig a crop up: it can't be undone

local ACTIONS = { -- (the word sits a little high: the crop's name goes under it)
	Harvest = { text = "HARVEST\n ", kind = "gold", outline = C.gold },
	Water = { text = "WATER\n ", kind = "blue", outline = C.sky },
	Plant = { text = "PLANT\n ", kind = "green", outline = C.green },
}
local ALTS = { -- (the smaller stamp's two jobs)
	Dig = { text = "HOLD TO\nDIG UP", kind = "red" },
	Seeds = { text = "CHANGE\nSEED", kind = "cream" },
}

------------------------------------------------------------------------
-- The button, the info line, the outline

local DIAMETER = 104
local holder, button = UI.stamp({ name = "ContextStamp", text = "PLANT", kind = "green", diameter = DIAMETER,
	anchor = Vector2.new(1, 1), textSize = 22, parent = UI.screen })
holder.Visible = false
UI.fit(button, 12)
-- what it acts on, under the word
local sub = UI.label({
	Name = "Sub", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.62, 0), Size = UDim2.new(0.8, 0, 0, 18),
	Font = UI.HEAD, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Text = "", ZIndex = button.ZIndex + 1, Parent = button,
})
UI.fit(sub, 9)
-- the key that presses it, on its rim at the top left (none on a phone)
local stampKey = UI.keycap({ name = "Key", size = 32, anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0.13, 0.13),
	zIndex = button.ZIndex + 3, parent = holder })
local function showKey()
	stampKey.Visible = UI.setKey(stampKey, UI.inputKind(), Enum.KeyCode.E, Enum.KeyCode.ButtonX, nil)
end
showKey()
UserInputService.LastInputTypeChanged:Connect(showKey)

local info, infoLabel = UI.chalkboard({ name = "TileInfo", size = UDim2.fromOffset(0, 32), autoWidth = true, anchor = Vector2.new(1, 1),
	textSize = 21, visible = false, parent = UI.screen })

-- The smaller stamp, over the big one.
local altHolder, altButton = UI.stamp({ name = "TileAlt", text = "", kind = "cream", diameter = 72, anchor = Vector2.new(1, 1), textSize = 14, parent = UI.screen })
altHolder.Visible = false
UI.fit(altButton, 9)
local altKey = UI.keycap({ name = "Key", size = 24, anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0.13, 0.13), zIndex = altButton.ZIndex + 3, parent = altHolder })
local function showAltKey()
	altKey.Visible = UI.setKey(altKey, UI.inputKind(), Enum.KeyCode.F, Enum.KeyCode.ButtonB, nil)
end
showAltKey()
UserInputService.LastInputTypeChanged:Connect(showAltKey)
local altBar = make("Frame", {
	Name = "Hold", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -3), Size = UDim2.new(1, 6, 0, 11),
	BackgroundColor3 = C.cream, Visible = false, ZIndex = 3, Parent = altHolder,
}, { UI.corner(5), UI.stroke(UI.SEAM, 2) })
local altFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.alarm, ZIndex = 4, Parent = altBar }, { UI.corner(5) })

local stampRight, stampSize, altSize = 18, DIAMETER, 72

-- The chalkboard sits over the big stamp, or beside the small one when that's
-- up over it (over that, it ran up behind the Farm Guide on a short screen).
local function placeInfo()
	local beside = if altHolder.Visible and not UI.touch then (stampSize + altSize) / 2 + 10 else 0
	info.Position = UDim2.new(1, -(stampRight + beside), 1, -(stampSize + 36)) -- (room for the hold bar between them)
end

UI.onLayout(function()
	stampRight = if UI.touch then UI.touchRoom() + 4 else 18
	stampSize = if UI.compact then 92 else DIAMETER
	altSize = if UI.compact then 64 else 72
	holder.Size = UDim2.fromOffset(stampSize, stampSize)
	holder.Position = UDim2.new(1, -stampRight, 1, -14)
	altHolder.Size = UDim2.fromOffset(altSize, altSize)
	altHolder.Position = if UI.touch
		then UDim2.new(1, -(stampRight + stampSize + 6), 1, -84) -- (a phone: beside the big stamp, on the hotbar's top edge. Over it, the Farm Guide hid it)
		else UDim2.new(1, -(stampRight + (stampSize - altSize) / 2), 1, -(stampSize + 22))
	placeInfo()
end)

-- A progress bar over the stamp, for holds (a steal, an arrest).
local progress = make("Frame", {
	Name = "Progress", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.new(1, 8, 0, 13),
	BackgroundColor3 = C.cream, Visible = false, ZIndex = 3, Parent = holder,
}, { UI.corner(6), UI.stroke(UI.SEAM, 2) })
local progressFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.alarm, ZIndex = 4, Parent = progress }, { UI.corner(6) })

-- fraction 0–1 (nil hides the bar); color: the fill (default alarm red).
function FieldController.setProgress(fraction: number?, color: Color3?)
	progress.Visible = fraction ~= nil
	progressFill.Size = UDim2.fromScale(math.clamp(fraction or 0, 0, 1), 1)
	progressFill.BackgroundColor3 = color or C.alarm
end

local outline = make("SelectionBox", {
	Name = "TileOutline",
	LineThickness = 0.15,
	SurfaceTransparency = 0.85,
	Color3 = C.green,
	SurfaceColor3 = C.green,
	Visible = false,
	Parent = UI.screen,
})

------------------------------------------------------------------------
-- What's under you

-- The tile you're standing on, in your own farm or in a friend's that
-- trusts you (then the third value is their name).
local function myTile(): (BasePart?, number?, string?)
	local plot = player:GetAttribute("Plot")
	local here = player:GetAttribute("InFarm") or 0
	local friend = nil
	if here == 0 then
		return nil, nil, nil
	elseif here ~= plot then
		local model = workspace.World:FindFirstChild(`Plot{here}`)
		if not model or not DefenceRules.inTrustedText(model:GetAttribute("Trusted"), player.UserId) then
			return nil, nil, nil
		end
		plot, friend = here, model:GetAttribute("OwnerName") or "your friend"
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local tile = root and PlotLayout.tileAt(plot, root.Position)
	if not tile then
		return nil, nil, nil
	end
	local field = workspace.World:FindFirstChild(`Plot{plot}`)
	return field and field.Field:FindFirstChild(`Tile{tile}`), tile, friend
end

-- The action for a tile now, and the info line. friend: whose farm you're
-- helping on (you water and harvest; only they plant and clear).
local function actionFor(part: BasePart, friend: string?): (string?, string)
	if friend then
		local cropId = part:GetAttribute("Crop")
		if not part:GetAttribute("Open") then
			return nil, `🌿 Overgrown: {friend} clears their own land`
		elseif not cropId then
			return nil, `🤝 {friend}'s field: only they plant here`
		end
		local crop = Crops.ById[cropId]
		local name = `{crop.icon} {Crops.count(cropId, part:GetAttribute("Yield") or crop.perPatch)}`
		if part:GetAttribute("Stage") == "Ripe" then
			return "Harvest", `🤝 {name} · Ripe! (for {friend}'s barn)`
		end
		local left = (part:GetAttribute("RipeAt") or 0) - workspace:GetServerTimeNow()
		local line = `🤝 {name} · ripe in {UI.formatTime(left)}`
		if part:GetAttribute("Watered") then
			return nil, `{line} · 💧`
		end
		return "Water", line
	end
	local cropId = part:GetAttribute("Crop")
	if not part:GetAttribute("Open") then
		local state = PlayerState.current
		local overgrowth = part.Parent:FindFirstChild(`Overgrowth{part:GetAttribute("Block")}`)
		if overgrowth and overgrowth:GetAttribute("Clearing") then
			return nil, "⛏ Hold E on each glowing obstacle to clear it"
		elseif state and LandRules.permitsLeft(state.land, state.level) > 0 then
			return nil, "🌿 Overgrown: use your Land Permit at a yellow sign"
		end
		return nil, "🌿 Overgrown: Land Permits come with Farm Levels"
	end
	if cropId then
		local crop = Crops.ById[cropId]
		local mutation = part:GetAttribute("Mutation")
		local name = `{crop.icon} {Crops.count(cropId, part:GetAttribute("Yield") or crop.perPatch, mutation)}`
		if part:GetAttribute("Stage") == "Ripe" then
			return "Harvest", if mutation then `✨ {name} · worth ×{WeatherRules.value(mutation)}!` else `{name} · Ripe!`
		end
		local left = (part:GetAttribute("RipeAt") or 0) - workspace:GetServerTimeNow()
		local line = `{name} · ripe in {UI.formatTime(left)}`
		if part:GetAttribute("Watered") then
			return nil, `{line} · 💧`
		end
		return "Water", line
	end
	local seed = HotbarController.selectedSeed()
	local fresh = if part:GetAttribute("Fresh") then " · Fresh soil +25%" else ""
	if not seed then
		if HotbarController.hasSeeds() then
			return "Plant", `Empty soil{fresh} · pick a seed`
		end
		return nil, `Empty soil{fresh} · no seeds: Barley sells them in town`
	end
	local crop = Crops.ById[seed]
	local state = PlayerState.current
	if state and state.level < Rarities.ById[crop.rarity].seedLevel then
		return nil, `{crop.icon} {crop.name} needs Lv {Rarities.ById[crop.rarity].seedLevel}`
	end
	return "Plant", `Empty soil{fresh}`
end

-- The smaller stamp's job on a tile: dig up what's growing there (a ripe crop
-- you harvest), or change seed on soil you're about to plant. Your own farm only.
local function altFor(part: BasePart, friend: string?): string?
	if friend or not part:GetAttribute("Open") then
		return nil
	elseif part:GetAttribute("Crop") then
		return if part:GetAttribute("Stage") ~= "Ripe" then "Dig" else nil
	end
	return if HotbarController.selectedSeed() and HotbarController.hasOtherSeeds() then "Seeds" else nil
end

------------------------------------------------------------------------
-- Doing it

-- A press does one action. Hold it and, after HOLD_DELAY, the same kind of
-- action repeats on every tile you walk onto (harvest a row, plant a row):
-- never a different one (no harvest-then-replant from one long press).
local HOLD_DELAY = 0.35
local holding = false
local holdKind: string? = nil
local holdStarted = 0
local busy = false
local lastDone = { tile = 0, kind = "", at = 0 }
local lastError = 0
local current = { part = nil, tile = nil, kind = nil, offer = nil, alt = nil }

-- offer = { priority, text, sub?, kind (a stamp colour), info? (the
-- chalkboard line), press = fn, release = fn? }. The highest priority wins
-- over the tile's own action.
local offers = {}

function FieldController.offer(id: string, offer)
	offers[id] = offer
end

function FieldController.withdraw(id: string)
	offers[id] = nil
end

local function bestOffer()
	local best = nil
	for _, offer in offers do
		if not best or offer.priority > best.priority then
			best = offer
		end
	end
	return best
end

local function floatAtButton(text: string, color: Color3?)
	local at = holder.AbsolutePosition + holder.AbsoluteSize / 2 - UI.screen.AbsolutePosition
	UI.float(text, UDim2.fromOffset(at.X, at.Y - 50), color)
end

local update: () -> () -- (below: act opens the picker and looks again once you pick)
local pickerTile: number? = nil -- the tile the seed picker was opened for (it closes if you walk off it)

local act: () -> ()

-- The seed picker for this tile: what you pick is in your hand and planted here.
local function pickSeedFor(tile: number)
	if HotbarController.pickerOpen() then
		return
	end
	holding = false
	pickerTile = tile
	HotbarController.openPicker(function()
		pickerTile = nil
		update()
		if current.kind == "Plant" and current.tile == tile then
			lastDone = { tile = 0, kind = "", at = 0 }
			act()
		end
	end, true)
end

function act()
	local part, tile, kind = current.part, current.tile, current.kind
	if busy or not part or not kind or HotbarController.pickerOpen() then
		return
	end
	if kind == "Plant" and not HotbarController.selectedSeed() then
		pickSeedFor(tile) -- (nothing in hand: pick a seed, then it's planted here)
		return
	end
	local now = os.clock()
	if lastDone.tile == tile and lastDone.kind == kind and now - lastDone.at < SAME_TILE_GAP then
		return
	end
	busy = true
	lastDone = { tile = tile, kind = kind, at = now }
	local cropId = if kind == "Plant" then HotbarController.selectedSeed() else part:GetAttribute("Crop")
	local arg = if kind == "Plant" then `{tile}|{cropId}` else tostring(tile)
	local result = FieldAction:InvokeServer(kind, arg)
	busy = false
	local crop = cropId and Crops.ById[cropId]
	if result.ok then
		Sfx.play(kind, part, 0.95 + math.random() * 0.1) -- (Plant · Water · Harvest, a little different each time)
		if kind == "Harvest" and crop then
			local mutation = result.result and result.result.mutation
			floatAtButton(`+{result.result and result.result.count or 1} {crop.icon}{if mutation then ` ✨{mutation}` else ""}`, C.gold)
		elseif kind == "Water" then
			floatAtButton("💧", C.sky)
		elseif kind == "Plant" and crop then
			floatAtButton("🌱", C.green)
		end
	elseif os.clock() - lastError > 1.5 then
		local level = crop and Rarities.ById[crop.rarity].seedLevel
		local text = Reasons(result.reason, level and `Needs Farm Level {level}.`)
		if text then
			lastError = os.clock()
			UI.toast(text, "Error", 2.5)
		end
	end
end

local digging = nil -- { tile, at }: the crop you're holding the smaller stamp on

local function showAlt(alt: string?)
	altHolder.Visible = alt ~= nil
	if alt then
		altButton.Text = ALTS[alt].text
		UI.setStampKind(altHolder, ALTS[alt].kind)
	end
	placeInfo()
end

function update()
	local offer = bestOffer()
	if offer then
		current = { part = nil, tile = nil, kind = nil, offer = offer, alt = nil }
		showAlt(nil)
		holder.Visible = true
		button.Text = offer.text
		UI.setStampKind(holder, offer.kind)
		sub.Text = offer.sub or ""
		sub.TextColor3 = button.TextColor3
		info.Visible = offer.info ~= nil
		infoLabel.Text = offer.info or ""
		outline.Visible = false
		return
	end
	local part, tile, friend = myTile()
	local kind, line = nil, ""
	if part then
		kind, line = actionFor(part, friend)
	end
	if pickerTile and (not HotbarController.pickerOpen() or tile ~= pickerTile or kind ~= "Plant") then
		if HotbarController.pickerOpen() then
			HotbarController.closePicker() -- (you walked off the soil you were planting)
		end
		pickerTile = nil
	end
	local alt = if part then altFor(part, friend) else nil
	current = { part = part, tile = tile, kind = kind, offer = nil, alt = alt }
	showAlt(alt)
	info.Visible = part ~= nil
	infoLabel.Text = if digging then "Keep holding: the crop and its seed are lost" else line
	holder.Visible = kind ~= nil
	if kind then
		local look = ACTIONS[kind]
		button.Text = look.text
		UI.setStampKind(holder, look.kind)
		local crop = if kind == "Plant" then Crops.ById[HotbarController.selectedSeed() or ""] else Crops.ById[part:GetAttribute("Crop") or ""]
		sub.Text = if crop then `{crop.icon} {crop.name}` elseif kind == "Plant" then "🌱 Pick seed" else ""
		sub.TextColor3 = button.TextColor3
		outline.Color3 = look.outline
		outline.SurfaceColor3 = look.outline
	else
		outline.Color3 = C.cream
		outline.SurfaceColor3 = C.cream
	end
	outline.Adornee = part
	outline.Visible = part ~= nil
	if holding and kind and kind == holdKind and os.clock() - holdStarted >= HOLD_DELAY then
		task.spawn(act)
	end
end

-- Digs up the crop you're standing on, after a hold: it can't be undone.
local function dig(tile: number, part: BasePart)
	local result = FieldAction:InvokeServer("Dig", tostring(tile))
	if result.ok then
		Sfx.play("Harvest", part, 0.7)
		UI.float("Dug up", UDim2.fromOffset(altHolder.AbsolutePosition.X + altHolder.AbsoluteSize.X / 2 - UI.screen.AbsolutePosition.X,
			altHolder.AbsolutePosition.Y - UI.screen.AbsolutePosition.Y - 10), C.cream)
	else
		local text = Reasons(result.reason)
		if text then
			UI.toast(text, "Error", 2.5)
		end
	end
end

local function altRelease()
	digging = nil
end

local function altPress()
	local tile, part = current.tile, current.part
	if current.alt == "Seeds" and tile then
		pickSeedFor(tile)
	elseif current.alt == "Dig" and tile and part and not digging then
		local this = { tile = tile, at = os.clock() }
		digging = this
		altBar.Visible = true
		task.spawn(function()
			while digging == this and current.tile == tile and current.alt == "Dig" do
				local share = (os.clock() - this.at) / DIG_HOLD
				altFill.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
				if share >= 1 then
					digging = nil
					altBar.Visible = false
					dig(tile, part)
					return
				end
				RunService.Heartbeat:Wait()
			end
			if digging == this then
				digging = nil
			end
			altBar.Visible = false
		end)
	end
end

local pressedOffer = nil

local function press()
	if current.offer then
		pressedOffer = current.offer
		task.spawn(current.offer.press)
		return
	end
	holding = true
	holdKind = current.kind
	holdStarted = os.clock()
	task.spawn(act)
end

local function releasePress()
	holding = false
	local offer = pressedOffer
	pressedOffer = nil
	if offer and offer.release then
		task.spawn(offer.release)
	end
end

------------------------------------------------------------------------

function FieldController.Start()
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			press()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			releasePress()
		end
	end)

	altButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			altPress()
		end
	end)
	altButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			altRelease()
		end
	end)
	ContextActionService:BindActionAtPriority("FieldAlt", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			if current.alt then
				altPress()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end
		altRelease()
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.F, Enum.KeyCode.ButtonB)

	-- E (or the gamepad's X), unless a prompt on E (Barley, a "Clear here"
	-- sign, Fill) is showing: one on another key (a player's [T] Trade) doesn't count.
	local shownOnE = {}
	local promptsShown = 0
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt.KeyboardKeyCode == Enum.KeyCode.E and not shownOnE[prompt] then
			shownOnE[prompt] = true
			promptsShown += 1
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if shownOnE[prompt] then
			shownOnE[prompt] = nil
			promptsShown = math.max(0, promptsShown - 1)
		end
	end)
	ContextActionService:BindActionAtPriority("FieldContext", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			if (current.kind or current.offer) and promptsShown == 0 then
				press()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end
		releasePress()
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.E, Enum.KeyCode.ButtonX)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= REPEAT then
			elapsed = 0
			update()
		end
	end)
end

return FieldController
