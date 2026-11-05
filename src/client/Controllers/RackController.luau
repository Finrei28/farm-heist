-- The packed crates window (docs/GameDesign.md §4.6; the user, 2026-11-05:
-- "interact with the packed crates at the packing shed that opens up a panel
-- where they can select crates they can send to the stockroom"). "Send to
-- stockroom" at the rack (the Cold Room from Warehouse Level 5) opens it:
--   * the crates here, alike ones together, with Send (with the hand cart, up
--     to four): a crate sent is the store's, whatever its crop's route, and a
--     Stocker puts it out (shared/PackRules);
--   * what's in the stockroom already.
-- A mutated crate only goes by truck, so it stays here. Walking away closes it.
-- The server checks everything (WarehouseService). As in the dock window, rows
-- stay put and only their words change, so a crew at work never loses a press.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared.CrateRules)
local Crops = require(Shared.Config.Crops)
local PackRules = require(Shared.PackRules)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local Warehouse = require(Shared.Config.Warehouse)
local WarehouseRules = require(Shared.WarehouseRules)

local CropNames = require(script.Parent.Parent.CropNames)
local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local Sfx = require(script.Parent.Parent.Sfx)
local UI = require(script.Parent.Parent.UI)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer
local WarehouseAction = Remotes.func("WarehouseAction")

local RackController = {}

local WALK_AWAY = 20 -- studs from the crates that close the window
-- where things go in the list
local HERE, EMPTY, CRATES, IN_STOCKROOM, STOCKROOM_CRATES = 1, 2, 10, 1000, 1001

local panel = UI.panel("Packed crates", { accent = C.green, toolbar = true, width = 620, height = 440 })
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.list })

local spot: BasePart? = nil

local function send(key: string, grade: string)
	Sfx.play("UiClick")
	task.spawn(function()
		local result = WarehouseAction:InvokeServer("SendCrate", `{key}|{grade}`)
		if not result.ok then
			local text = Reasons(result.reason)
			if text then
				UI.toast(text, "Error", 3)
			end
		end
	end)
end

local function heading(order: number): TextLabel
	return UI.label({ Size = UDim2.new(1, 0, 0, 24), Font = UI.HEAD, TextSize = 17, LayoutOrder = order, ZIndex = 23, Parent = panel.list })
end

local here = heading(HERE)
local inStockroom = heading(IN_STOCKROOM)
inStockroom.Text = "IN THE STOCKROOM"

local emptyNote = make("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = C.cream, LayoutOrder = EMPTY, Visible = false, ZIndex = 22, Parent = panel.list },
	{ UI.corner(3), UI.stroke(UI.SEAM, 2) })
UI.label({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), Font = UI.HAND, TextSize = 19, TextWrapped = true, ZIndex = 23, Parent = emptyNote,
	Text = "No crates here to send. Pack some at the bench." })

local rows = {} -- ["Rack key/grade" or "Shelf key/grade"] = its row, kept while it's showing

-- A stack of crates: its colour band, what it is, and (at `canSend`) a button.
local function makeRow(stack, canSend: boolean)
	local crop = Crops.ById[stack.crop]
	local frame = make("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = C.cream, ZIndex = 22, Parent = panel.list }, { UI.corner(3), UI.stroke(UI.SEAM, 2) })
	make("Frame", { Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = Rarities.ById[crop.rarity].color, BorderSizePixel = 0, ZIndex = 23, Parent = frame })
	UI.label({ Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(40, 40), Font = UI.HEAD, Text = crop.icon or "🌱", TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 23, Parent = frame })
	local name = UI.fit(UI.label({ Position = UDim2.fromOffset(58, 5), Size = UDim2.new(1, -190, 0, 22), Font = UI.HEAD, TextSize = 17, TextColor3 = CropNames.color(stack.key), ZIndex = 23, Parent = frame }), 11)
	local line = UI.fit(UI.label({ Position = UDim2.fromOffset(58, 28), Size = UDim2.new(1, -190, 0, 20), Font = UI.HAND, TextSize = 18, ZIndex = 23, Parent = frame }), 11)
	local row = { frame = frame, name = name, line = line }
	if canSend then
		local holder, button = UI.button({ text = "Send", kind = "green", size = UDim2.fromOffset(112, 40), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -10, 0.5, 0),
			textSize = 16, zIndex = 23, parent = frame })
		button.Activated:Connect(function()
			send(stack.key, stack.grade)
		end)
		row.holder, row.button, row.kind = holder, button, "green"
	end
	return row
end

-- Shows a stack's row. moves: how many crates Send takes (nil: it has no Send).
local function showRow(order: number, side: string, stack, moves: number?, open: boolean?)
	local id = `{side} {stack.key}/{stack.grade}`
	local row = rows[id] or makeRow(stack, moves ~= nil)
	rows[id] = row
	row.shown = true
	row.frame.LayoutOrder = order
	row.name.Text = string.upper(`{CropNames.of(stack.key)} ×{UI.formatNumber(stack.units)}{if stack.grade == "A" then " · grade A" else ""}`)
	row.line.Text = `{stack.crates} crate{if stack.crates == 1 then "" else "s"}{if CrateRules.storeable(stack.key) then "" else " · truck only"}`
	if row.button then
		row.button.Text = if moves and moves > 1 then `Send {moves}` else "Send"
		local kind = if open then "green" else "cream"
		if row.kind ~= kind then
			row.kind = kind
			UI.setButtonKind(row.holder, kind)
		end
	end
end

local function render()
	local state = PlayerState.current
	if not state or not UI.isOpen(panel) then
		return
	end
	local info = WarehouseRules.level(state.warehouse.level)
	local rack, shelf = PackRules.sides(state)
	local room = PackRules.stockroomRoom(state)
	panel.toolbar.Text = `📦 Packed crates {#state.store.stockroom}/{PackRules.size(state)}  ·  🏪 Stockroom {#shelf}/{PackRules.stockroomSize(state)}`
	here.Text = if info.stage == 1 then "ON THE RACK" else "IN THE COLD ROOM"

	for _, row in rows do
		row.shown = false
	end
	local most = if info.handCart then Warehouse.HAND_CART else 1
	local stacks = PackRules.stacks(rack)
	emptyNote.Visible = #stacks == 0
	for i, stack in stacks do
		local canSend = CrateRules.storeable(stack.key)
		-- (a Send and a row without one are told apart by the side's name)
		showRow(CRATES + i, if canSend then "Rack" else "Truck", stack, if canSend then math.max(1, math.min(most, stack.crates, room)) else nil, room > 0)
	end
	local stocked = PackRules.stacks(shelf)
	inStockroom.Visible = #stocked > 0
	for i, stack in stocked do
		showRow(STOCKROOM_CRATES + i, "Shelf", stack)
	end
	for id, row in rows do
		if not row.shown then
			row.frame:Destroy()
			rows[id] = nil
		end
	end
end

function RackController.Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Opens") == "Rack" and prompt:GetAttribute("OwnerId") == player.UserId then
			spot = prompt.Parent :: BasePart
			panel.open()
		end
	end)
	panel.onOpen = render
	panel.onClose = function()
		spot = nil
	end
	PlayerState.changed:Connect(render)
	task.spawn(function()
		while true do
			task.wait(1)
			if UI.isOpen(panel) then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and spot and (root.Position - spot.Position).Magnitude > WALK_AWAY then
					panel.close()
				end
			end
		end
	end)
end

return RackController
