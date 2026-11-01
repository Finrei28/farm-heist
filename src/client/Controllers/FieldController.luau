-- Working your field (docs/GameDesign.md §5.2): the big round stamp at the
-- bottom right does whatever the tile you're standing on needs: Harvest
-- (ripe), Water (growing, not watered this stage), Plant (empty soil: the
-- seed packet picked in the hotbar). A chalkboard above it says what's
-- there and how long it has left, and the tile gets an outline.
--
-- Hold the button (or E) and walk along a row to plant, water or harvest
-- every tile you cross. The server checks everything (FieldService); the
-- tiles' attributes (server/World/FarmArt) say what's on them.
--
-- Other controllers can put their own action on the stamp, over the tile's
-- (FieldController.offer: CrimeController's Steal, Swing, Arrest, Climb),
-- with a progress bar for holds (FieldController.setProgress).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared.Config.Crops)
local LandRules = require(Shared.LandRules)
local PlotLayout = require(Shared.PlotLayout)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)

local Reasons = require(script.Parent.Parent.Reasons)
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

local ACTIONS = { -- (the word sits a little high: the crop's name goes under it)
	Harvest = { text = "HARVEST\n ", kind = "gold", outline = C.gold },
	Water = { text = "WATER\n ", kind = "blue", outline = C.sky },
	Plant = { text = "PLANT\n ", kind = "green", outline = C.green },
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

local info, infoLabel = UI.chalkboard({ name = "TileInfo", size = UDim2.fromOffset(0, 32), autoWidth = true, anchor = Vector2.new(1, 1),
	textSize = 21, visible = false, parent = UI.screen })

UI.onLayout(function()
	local right = if UI.touch then UI.touchRoom() + 4 else 18
	local d = if UI.compact then 92 else DIAMETER
	holder.Size = UDim2.fromOffset(d, d)
	holder.Position = UDim2.new(1, -right, 1, -14)
	info.Position = UDim2.new(1, -right, 1, -(d + 36)) -- (room for the hold bar between them)
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

local function myTile(): (BasePart?, number?)
	local plot = player:GetAttribute("Plot")
	if not plot or player:GetAttribute("InFarm") ~= plot then
		return nil, nil
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local tile = root and PlotLayout.tileAt(plot, root.Position)
	if not tile then
		return nil, nil
	end
	local field = workspace.World:FindFirstChild(`Plot{plot}`)
	return field and field.Field:FindFirstChild(`Tile{tile}`), tile
end

-- The action for a tile now, and the info line.
local function actionFor(part: BasePart): (string?, string)
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
		local name = `{crop.icon} {crop.name}`
		if part:GetAttribute("Stage") == "Ripe" then
			return "Harvest", `{name} · Ripe!`
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
		return nil, `Empty soil{fresh} · no seeds`
	end
	local crop = Crops.ById[seed]
	local state = PlayerState.current
	if state and state.level < Rarities.ById[crop.rarity].seedLevel then
		return nil, `{crop.icon} {crop.name} needs Lv {Rarities.ById[crop.rarity].seedLevel}`
	end
	return "Plant", `Empty soil{fresh}`
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
local current = { part = nil, tile = nil, kind = nil, offer = nil }

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

local function act()
	local part, tile, kind = current.part, current.tile, current.kind
	if busy or not part or not kind then
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
		if kind == "Harvest" and crop then
			floatAtButton(`+1 {crop.icon}`, C.gold)
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

local function update()
	local offer = bestOffer()
	if offer then
		current = { part = nil, tile = nil, kind = nil, offer = offer }
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
	local part, tile = myTile()
	local kind, line = nil, ""
	if part then
		kind, line = actionFor(part)
	end
	current = { part = part, tile = tile, kind = kind, offer = nil }
	info.Visible = part ~= nil
	infoLabel.Text = line
	holder.Visible = kind ~= nil
	if kind then
		local look = ACTIONS[kind]
		button.Text = look.text
		UI.setStampKind(holder, look.kind)
		local crop = if kind == "Plant" then Crops.ById[HotbarController.selectedSeed() or ""] else Crops.ById[part:GetAttribute("Crop") or ""]
		sub.Text = if crop then `{crop.icon} {crop.name}` else ""
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

	-- E (or the gamepad's X), unless a prompt (Barley, a "Clear here" sign) is showing.
	local promptsShown = 0
	ProximityPromptService.PromptShown:Connect(function()
		promptsShown += 1
	end)
	ProximityPromptService.PromptHidden:Connect(function()
		promptsShown = math.max(0, promptsShown - 1)
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
