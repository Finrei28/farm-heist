-- The hotbar (docs/GameDesign.md §5.2): your seeds along the bottom, as
-- seed packets (crimped top, a band in the rarity colour, the count on a
-- tag). The one you pick stands up out of the row: it's what the context
-- stamp plants. Tap a packet, or press 1–9. Inside your own farm the bat
-- (a Tool the server gives you there: CrimeService) is the first packet:
-- tap it to hold it, tap a seed to put it away. Watering is the context
-- stamp's job.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared.Config.Crops)
local Rarities = require(Shared.Config.Rarities)

local PlayerState = require(script.Parent.Parent.PlayerState)
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

local selected: string? = nil
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
end

local function select(cropId: string?)
	if selected == cropId then
		return
	end
	selected = cropId
	highlight()
	changedEvent:Fire(cropId)
end

-- A tap or a key: the bat goes in or out of your hand; a seed puts it away.
local function pick(id: string)
	if id == "Bat" then
		if HotbarController.batEquipped() then
			unequipBat()
		else
			HotbarController.equipBat()
		end
	else
		unequipBat()
		select(id)
	end
	highlight()
end

local function order(a: string, b: string): boolean
	local ca, cb = Crops.ById[a], Crops.ById[b]
	local ra, rb = Rarities.ById[ca].order, Rarities.ById[cb].order
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

local function rebuild(state)
	local seeds = state.inventory.seeds
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
	for i, cropId in ids do
		if #keyOrder >= MAX_SLOTS then
			break
		end
		local crop = Crops.ById[cropId]
		packet(cropId, i, Rarities.ById[crop.rarity].color, crop.icon or "🌱", `×{seeds[cropId]}`, C.kraft, C.ink)
	end
	-- Keep the pick if you still have it; else the first packet.
	local keep = selected and table.find(ids, selected) and selected or ids[1]
	selected = nil
	select(keep)
	highlight()
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
		bar.Position = UDim2.new(0.5, 0, 1, -10)
	end)
	HudController.HOTBAR_HEIGHT = PACKET + LIFT

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
