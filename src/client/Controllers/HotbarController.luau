-- The hotbar (docs/GameDesign.md §5.2): your seeds along the bottom, as
-- seed packets (crimped top, a band in the rarity colour, the count on a
-- tag). The one you pick stands up out of the row: it's what the context
-- stamp plants, and a chalkboard over the Home and Town boards says what it
-- is. Tap a packet, or press 1–9; tap the one you're holding (or its key)
-- again to put it away. Inside your own farm the bat (a Tool the
-- server gives you there: CrimeService) is the first packet: tap it to hold
-- it, tap a seed to put it away. Watering is the context stamp's job.
--
-- Pressing Plant with no seed in hand opens the seed picker
-- (HotbarController.openPicker): every seed you have as a big packet, the
-- ones you can't plant yet greyed with their level. So does the context
-- stamp's CHANGE SEED, and, with more seeds than the bar holds, the ALL packet
-- at its end. The seed in your hand always keeps a place on the bar
-- (shared/HotbarRules), so you can always put it away.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared.Config.Crops)
local HotbarRules = require(Shared.HotbarRules)
local Rarities = require(Shared.Config.Rarities)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Sfx = require(script.Parent.Parent.Sfx)
local UI = require(script.Parent.Parent.UI)
local HudController = require(script.Parent.HudController)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer

local HotbarController = {}

local MAX_SLOTS = 9
local SLOT = 54 -- a packet's width
local PACKET = 66 -- and height
local LIFT = 8 -- how far the picked packet stands up
local THUMB_ROOM = 150 -- px a touch screen keeps clear for the thumbstick

local selected: string? = nil -- the seed in hand (nil: none, until you pick one)
local keyOrder = {} -- what keys 1–9 pick, in the bar's order: "Bat" or a crop id
local changedEvent = Instance.new("BindableEvent")
HotbarController.changed = changedEvent.Event

local bar = make("Frame", {
	Name = "Hotbar",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.fromOffset(0, PACKET + LIFT),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Parent = UI.screen,
}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom }) })

local empty = UI.chalkboard({ name = "Empty", size = UDim2.fromOffset(300, 34), text = "No seeds! Barley sells them in town", visible = false, parent = bar })

-- The seed in your hand, in words: a packet's picture alone doesn't say.
local heldBoard, heldLabel = UI.chalkboard({ name = "HeldSeed", size = UDim2.fromOffset(0, 30), anchor = Vector2.new(0.5, 1), autoWidth = true, visible = false, parent = UI.screen })
local seedCounts = {} -- [crop id] = how many, from the save

-- The crop the context stamp plants (nil if you have no seeds).
function HotbarController.selectedSeed(): string?
	return selected
end

-- The bat, wherever it is (the backpack, or your hand), or nil.
local function batTool(): Tool?
	local character = player.Character
	local held = character and character:FindFirstChild("Bat")
	if held and held:IsA("Tool") then
		return held
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local stored = backpack and backpack:FindFirstChild("Bat")
	return if stored and stored:IsA("Tool") then stored else nil
end

function HotbarController.hasBat(): boolean
	return batTool() ~= nil
end

function HotbarController.batEquipped(): boolean
	local tool = batTool()
	return tool ~= nil and tool.Parent == player.Character
end

-- Takes the bat in hand (the Swing button does it for you). Returns the bat, or nil.
function HotbarController.equipBat(): Tool?
	local tool = batTool()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not tool or not humanoid then
		return nil
	end
	if tool.Parent ~= player.Character then
		humanoid:EquipTool(tool)
	end
	return tool
end

local function unequipBat()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and HotbarController.batEquipped() then
		humanoid:UnequipTools()
	end
end

-- Which packet stands up: the bat while it's in your hand, else your seed.
-- (none with the bat out, or a stolen crop in your hands)
local function showHeld()
	local crop = if selected and not HotbarController.batEquipped() then Crops.ById[selected] else nil
	heldBoard.Visible = crop ~= nil and bar.Visible and player:GetAttribute("StolenCrop") == nil
	if crop then
		local count = seedCounts[selected] or 0
		heldLabel.Text = `{crop.icon or "🌱"} {Crops.seeds(selected, count)} ×{count}`
	end
end

local function highlight()
	local bat = HotbarController.batEquipped()
	for _, slot in bar:GetChildren() do
		local id = slot:IsA("Frame") and slot:GetAttribute("Crop")
		if id then
			local mine = if id == "Bat" then bat else (not bat and id == selected)
			local packet = slot.Packet
			packet.Position = UDim2.fromOffset(0, if mine then 0 else LIFT)
			packet.UIStroke.Color = if mine then C.gold else UI.SEAM
			packet.UIStroke.Thickness = if mine then 4 else 2
		end
	end
	showHeld()
end

local pickerDone: ((string) -> ())? = nil -- what the open seed picker plants once you pick
local picker -- (the seed picker's window: below)
local rebuild: (any) -> () -- (below)

-- On a touch screen the bar sits between the thumbstick and the context stamp,
-- with as many packets as fit: over the stamp, its last packets couldn't be
-- tapped (the stamp's size and place: FieldController).
local function touchSpan(): (number, number)
	local stamp = UI.touchRoom() + 4 + (if UI.compact then 92 else 104) + 8
	return THUMB_ROOM, UI.screen.AbsoluteSize.X - stamp
end

local function slots(): number
	if not UI.touch then
		return MAX_SLOTS
	end
	local left, right = touchSpan()
	return math.clamp(math.floor((right - left + 6) / (SLOT + 6)), 4, MAX_SLOTS)
end

local function placeBar()
	if UI.touch then
		local left, right = touchSpan()
		bar.Position = UDim2.new(0, (left + right) / 2, 1, -10)
	else
		bar.Position = UDim2.new(0.5, 0, 1, -10)
	end
end

local function select(cropId: string?)
	if selected == cropId then
		return
	end
	selected = cropId
	if cropId and not bar:FindFirstChild(cropId) and PlayerState.current then
		rebuild(PlayerState.current) -- (it takes a place on the bar, and comes back here)
		return
	end
	highlight()
	changedEvent:Fire(cropId)
	if cropId and pickerDone then -- (picked from the picker, or with a key while it was open)
		local done = pickerDone
		pickerDone = nil
		picker.close()
		task.spawn(done, cropId)
	end
end

-- A tap or a key: the bat goes in or out of your hand; a seed puts the bat
-- away; the seed you're holding goes away (nothing stands up then).
local function pick(id: string)
	if id == "More" then
		if HotbarController.pickerOpen() then
			picker.close()
		else
			HotbarController.openPicker(function() end)
		end
		return
	end
	if id == "Bat" then
		if HotbarController.batEquipped() then
			unequipBat()
		else
			HotbarController.equipBat()
		end
	else
		local hadBat = HotbarController.batEquipped()
		unequipBat()
		if selected == id and not hadBat then
			select(nil)
		else
			select(id)
		end
	end
	highlight()
end

local function order(a: string, b: string): boolean
	local ca, cb = Crops.ById[a], Crops.ById[b]
	local ra, rb = Rarities.ById[ca.rarity].order, Rarities.ById[cb.rarity].order
	if ra ~= rb then
		return ra < rb
	end
	return table.find(Crops.List, ca) < table.find(Crops.List, cb)
end

-- A packet frame: cream with a crimped top and a coloured band, an icon, a
-- tag along the bottom, the key in the corner. Returns the slot.
local function packet(id: string, layoutOrder: number, band: Color3, icon: string, tagText: string, tagColor: Color3, tagInk: Color3)
	local slot = make("Frame", {
		Name = id,
		Size = UDim2.fromOffset(SLOT, PACKET + LIFT),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Parent = bar,
	})
	slot:SetAttribute("Crop", id)
	local body = make("Frame", {
		Name = "Packet",
		Position = UDim2.fromOffset(0, LIFT),
		Size = UDim2.fromOffset(SLOT, PACKET),
		BackgroundColor3 = C.cream,
		Parent = slot,
	}, { UI.corner(3), UI.stroke(UI.SEAM, 2) })
	UI.crimp(body, C.cream, 5, 6)
	make("Frame", { -- the packet's band (the rarity colour; red for the bat)
		Size = UDim2.new(1, 0, 0, 7), Position = UDim2.fromOffset(0, 5), BackgroundColor3 = band, BorderSizePixel = 0, Parent = body,
	})
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 13), BackgroundTransparency = 1,
		Font = UI.HEAD, Text = icon, TextSize = 28, TextColor3 = C.ink, Parent = body,
	})
	make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, -6, 0, 16),
		BackgroundColor3 = tagColor, Font = UI.HEAD, Text = tagText, TextSize = 13, TextColor3 = tagInk, Parent = body,
	}, { UI.corner(3) })
	table.insert(keyOrder, id)
	if not UI.touch then
		make("TextLabel", {
			Position = UDim2.fromOffset(3, 12), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1,
			Font = UI.HEAD, Text = tostring(#keyOrder), TextSize = 11, TextColor3 = C.soil, Parent = body,
		})
	end
	make("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3, Parent = slot,
	}).Activated:Connect(function()
		pick(id)
	end)
	return slot
end

function rebuild(state)
	placeBar()
	local seeds = state.inventory.seeds
	seedCounts = seeds
	local ids = {}
	for cropId, count in seeds do
		if count > 0 and Crops.ById[cropId] then
			table.insert(ids, cropId)
		end
	end
	table.sort(ids, order)
	for _, child in bar:GetChildren() do
		if child:IsA("Frame") and child:GetAttribute("Crop") then
			child:Destroy()
		end
	end
	keyOrder = {}
	local hasBat = batTool() ~= nil
	if hasBat then
		packet("Bat", 0, C.red, "🏏", "BAT", C.red, C.cream)
	end
	empty.Visible = #ids == 0 and not hasBat
	local shown, more = HotbarRules.shown(ids, selected, slots() - #keyOrder)
	for i, cropId in shown do
		local crop = Crops.ById[cropId]
		packet(cropId, i, Rarities.ById[crop.rarity].color, crop.icon or "🌱", `×{seeds[cropId]}`, C.kraft, C.ink)
	end
	if more then -- (every seed you have, in the picker)
		packet("More", #shown + 1, C.green, "🎒", "ALL", C.green, C.cream)
	end
	-- Keep the seed in your hand while you still have some; none when it runs
	-- out (it never jumps to another seed: you pick the next one).
	local keep = if selected and table.find(ids, selected) then selected else nil
	selected = nil
	select(keep)
	highlight()
	if picker and UI.isOpen(picker) then
		HotbarController.fillPicker()
	end
end

------------------------------------------------------------------------
-- The seed picker: Plant with no seed in hand opens it.

picker = UI.panel("Pick a seed", { width = 560, height = 320, toolbar = true })
make("UIGridLayout", { CellSize = UDim2.fromOffset(96, 122), CellPadding = UDim2.fromOffset(10, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = picker.list })
picker.onClose = function()
	pickerDone = nil
end

-- Whether you have any seeds at all.
function HotbarController.hasSeeds(): boolean
	local state = PlayerState.current
	for cropId, count in state and state.inventory.seeds or {} do
		if count > 0 and Crops.ById[cropId] then
			return true
		end
	end
	return false
end

-- Whether you have a seed other than the one in your hand, to change to.
function HotbarController.hasOtherSeeds(): boolean
	local state = PlayerState.current
	for cropId, count in state and state.inventory.seeds or {} do
		if count > 0 and Crops.ById[cropId] and cropId ~= selected then
			return true
		end
	end
	return false
end

function HotbarController.pickerOpen(): boolean
	return UI.isOpen(picker)
end

function HotbarController.closePicker()
	picker.close()
end

-- (Re)draws the picker's packets from your seeds.
function HotbarController.fillPicker()
	UI.clear(picker.list)
	local state = PlayerState.current
	local seeds = state and state.inventory.seeds or {}
	local ids = {}
	for cropId, count in seeds do
		if count > 0 and Crops.ById[cropId] then
			table.insert(ids, cropId)
		end
	end
	table.sort(ids, order)
	for i, cropId in ids do
		local crop = Crops.ById[cropId]
		local rarity = Rarities.ById[crop.rarity]
		local locked = state.level < rarity.seedLevel
		local card = make("Frame", {
			Name = cropId, LayoutOrder = i, BackgroundColor3 = if locked then Color3.fromRGB(214, 206, 190) else C.cream,
			ZIndex = 23, Parent = picker.list,
		}, { UI.corner(4), UI.stroke(if cropId == selected then C.gold else UI.SEAM, if cropId == selected then 4 else 2) })
		UI.crimp(card, card.BackgroundColor3, 7, 7)
		make("Frame", { -- the rarity band
			Size = UDim2.new(1, 0, 0, 8), Position = UDim2.fromOffset(0, 6), BackgroundColor3 = rarity.color, BorderSizePixel = 0,
			ZIndex = 23, Parent = card,
		})
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 16), BackgroundTransparency = 1, Font = UI.HEAD,
			Text = crop.icon or "🌱", TextSize = 38, TextColor3 = C.ink, TextTransparency = if locked then 0.45 else 0, ZIndex = 23, Parent = card,
		})
		UI.fit(UI.label({
			Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 62), Font = UI.HEAD, TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center, Text = crop.name, TextColor3 = C.ink, ZIndex = 23, Parent = card,
		}), 10)
		make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -12, 0, 22),
			BackgroundColor3 = if locked then C.soil else C.kraft, Font = UI.HEAD,
			Text = if locked then `🔒 Lv {rarity.seedLevel}` else `×{seeds[cropId]}`,
			TextSize = 15, TextColor3 = if locked then C.cream else C.ink, ZIndex = 23, Parent = card,
		}, { UI.corner(3) })
		local hit = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 24, Parent = card })
		hit.Activated:Connect(function()
			if locked then
				UI.toast(`{crop.icon} {crop.name} needs Farm Level {rarity.seedLevel}.`, "Error", 2.5)
				return
			end
			Sfx.play("UiClick")
			unequipBat()
			if selected == cropId and pickerDone then -- (already in hand: plant it anyway)
				local done = pickerDone
				pickerDone = nil
				picker.close()
				task.spawn(done, cropId)
			else
				select(cropId)
			end
		end)
	end
end

-- Opens the picker; once you pick a seed it's in your hand and onPick(cropId)
-- runs (planting: the stamp plants it). Closing it without picking does nothing.
function HotbarController.openPicker(onPick: ((string) -> ())?, planting: boolean?)
	picker.toolbar.Text = if planting then "Tap a seed to plant it here." else "Tap a seed to take it in hand."
	HotbarController.fillPicker()
	picker.open()
	pickerDone = onPick
	-- as tall as its rows of packets (a few seeds shouldn't sit in a big empty window)
	local frame = picker.frame
	local count = 0
	for _, child in picker.list:GetChildren() do
		if child:IsA("Frame") then
			count += 1
		end
	end
	local perRow = math.max(1, math.floor((frame.Size.X.Offset - 46) / 106))
	local rows = math.max(1, math.ceil(count / perRow))
	local most = (UI.screen.AbsoluteSize.Y - (if UI.compact then 40 else 90)) / UI.textScale
	frame.Size = UDim2.fromOffset(frame.Size.X.Offset, math.min(picker.top + rows * 134 + 20, 460, most))
end

function HotbarController.Start()
	PlayerState.observe(rebuild)
	local keys = {}
	for i = 1, MAX_SLOTS do
		keys[i] = Enum.KeyCode[({ "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" })[i]]
	end
	ContextActionService:BindAction("HotbarSelect", function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local index = table.find(keys, input.KeyCode)
		if index and keyOrder[index] then
			pick(keyOrder[index])
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(keys))
	UI.onLayout(function()
		if PlayerState.current then
			rebuild(PlayerState.current)
		else
			placeBar()
		end
	end)
	HudController.HOTBAR_HEIGHT = PACKET + LIFT
	UI.onLayout(function()
		heldBoard.Position = UDim2.new(0.5, 0, 1, -(HudController.HOTBAR_HEIGHT + 68))
	end)
	bar:GetPropertyChangedSignal("Visible"):Connect(showHeld)
	player:GetAttributeChangedSignal("StolenCrop"):Connect(showHeld)

	-- The bat comes and goes (your own farm only) and goes in and out of your hand.
	local function redraw()
		if PlayerState.current then
			rebuild(PlayerState.current)
		end
	end
	local function watch(container: Instance)
		container.ChildAdded:Connect(function(child)
			if child.Name == "Bat" then
				task.defer(redraw)
			end
		end)
		container.ChildRemoved:Connect(function(child)
			if child.Name == "Bat" then
				task.defer(redraw)
			end
		end)
	end
	local function onCharacter(character: Model)
		watch(character)
		local backpack = player:WaitForChild("Backpack", 10)
		if backpack then
			watch(backpack)
		end
		redraw()
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player:GetAttributeChangedSignal("InFarm"):Connect(function()
		task.delay(0.6, redraw) -- (in case the backpack was swapped on a respawn)
	end)
end

return HotbarController
