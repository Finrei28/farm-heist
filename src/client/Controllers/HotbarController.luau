-- The hotbar (docs/GameDesign.md §5.2): your seeds along the bottom, as
-- seed packets (crimped top, a band in the rarity colour, the count on a
-- tag). The one you pick stands up out of the row: it's what the context
-- stamp plants. Tap a packet, or press 1–9. (The bat joins the row in the
-- stealing week; watering is the context stamp's job.)
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared.Config.Crops)
local Rarities = require(Shared.Config.Rarities)

local PlayerState = require(script.Parent.Parent.PlayerState)
local UI = require(script.Parent.Parent.UI)
local HudController = require(script.Parent.HudController)

local C = UI.C
local make = UI.make

local HotbarController = {}

local MAX_SLOTS = 9
local SLOT = 54 -- a packet's width
local PACKET = 66 -- and height
local LIFT = 8 -- how far the picked packet stands up

local selected: string? = nil
local seedsOwned = {} -- the ordered crop ids in the bar
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

-- The crop the context button plants (nil if you have no seeds).
function HotbarController.selectedSeed(): string?
	return selected
end

local function select(cropId: string?)
	if selected == cropId then
		return
	end
	selected = cropId
	for _, slot in bar:GetChildren() do
		if slot:IsA("Frame") and slot:GetAttribute("Crop") then
			local mine = slot:GetAttribute("Crop") == cropId
			local packet = slot.Packet
			packet.Position = UDim2.fromOffset(0, if mine then 0 else LIFT)
			packet.UIStroke.Color = if mine then C.gold else UI.SEAM
			packet.UIStroke.Thickness = if mine then 4 else 2
		end
	end
	changedEvent:Fire(cropId)
end

local function order(a: string, b: string): boolean
	local ca, cb = Crops.ById[a], Crops.ById[b]
	local ra, rb = Rarities.ById[ca].order, Rarities.ById[cb].order
	if ra ~= rb then
		return ra < rb
	end
	return table.find(Crops.List, ca) < table.find(Crops.List, cb)
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
	seedsOwned = ids
	for _, child in bar:GetChildren() do
		if child:IsA("Frame") and child:GetAttribute("Crop") then
			child:Destroy()
		end
	end
	empty.Visible = #ids == 0
	for i, cropId in ids do
		if i > MAX_SLOTS then
			break
		end
		local crop = Crops.ById[cropId]
		local rarity = Rarities.ById[crop.rarity]
		local slot = make("Frame", {
			Name = cropId,
			Size = UDim2.fromOffset(SLOT, PACKET + LIFT),
			BackgroundTransparency = 1,
			LayoutOrder = i,
			Parent = bar,
		})
		slot:SetAttribute("Crop", cropId)
		local packet = make("Frame", {
			Name = "Packet",
			Position = UDim2.fromOffset(0, LIFT),
			Size = UDim2.fromOffset(SLOT, PACKET),
			BackgroundColor3 = C.cream,
			Parent = slot,
		}, { UI.corner(3), UI.stroke(UI.SEAM, 2) })
		UI.crimp(packet, C.cream, 5, 6)
		make("Frame", { -- the packet's band in the rarity colour
			Size = UDim2.new(1, 0, 0, 7), Position = UDim2.fromOffset(0, 5), BackgroundColor3 = rarity.color, BorderSizePixel = 0, Parent = packet,
		})
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 13), BackgroundTransparency = 1,
			Font = UI.HEAD, Text = crop.icon or "🌱", TextSize = 28, TextColor3 = C.ink, Parent = packet,
		})
		make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, -6, 0, 16),
			BackgroundColor3 = C.kraft, Font = UI.HEAD, Text = `×{seeds[cropId]}`, TextSize = 13, TextColor3 = C.ink, Parent = packet,
		}, { UI.corner(3) })
		if not UI.touch and i <= 9 then
			make("TextLabel", {
				Position = UDim2.fromOffset(3, 12), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1,
				Font = UI.HEAD, Text = tostring(i), TextSize = 11, TextColor3 = C.soil, Parent = packet,
			})
		end
		make("TextButton", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3, Parent = slot,
		}).Activated:Connect(function()
			select(cropId)
		end)
	end
	-- Keep the pick if you still have it; else the first packet.
	local keep = selected and table.find(ids, selected) and selected or ids[1]
	selected = nil
	select(keep)
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
		if index and seedsOwned[index] then
			select(seedsOwned[index])
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(keys))
	UI.onLayout(function()
		bar.Position = UDim2.new(0.5, 0, 1, -10)
	end)
	HudController.HOTBAR_HEIGHT = PACKET + LIFT
end

return HotbarController
