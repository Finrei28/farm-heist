-- The dock window (docs/GameDesign.md §4.6; the user, 2026-11-05: "Allow
-- selecting which crates/produce goes on the truck"). "Load crates" at a
-- truck's dock opens it:
--   * the truck: how full it is, and Send with what it would lock now;
--   * your packed crates (shared/PackRules), alike ones together, with what
--     each pays by truck and in your store: Load puts one on (with the hand
--     cart, up to four);
--   * what's on the truck, with Take off, while it's home.
-- Walking away closes it. The server checks everything (TruckService).
--
-- Rows stay put and only their words change: with a crew at work the crates
-- change every second, and a row rebuilt under your finger between pressing
-- and letting go loses the press (found in Studio, 2026-11-05).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared.CrateRules)
local Crops = require(Shared.Config.Crops)
local MarketPrice = require(Shared.MarketPrice)
local PackRules = require(Shared.PackRules)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local ShopRules = require(Shared.ShopRules)
local TruckRules = require(Shared.TruckRules)
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
local TruckAction = Remotes.func("TruckAction")

local DockController = {}

local WALK_AWAY = 20 -- studs from the dock that close the window
-- where things go in the list
local TOP, PACKED, EMPTY, CRATES, ON_TRUCK, TRUCK_CRATES = 1, 2, 3, 100, 1000, 1001

local panel = UI.panel("Load the truck", { accent = C.red, toolbar = true, width = 620, height = 440 })
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.list })

local truck = 1 -- the dock that's open
local spot: BasePart? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

local function send(action: string, arg: string?)
	Sfx.play("UiClick")
	task.spawn(function()
		local result = TruckAction:InvokeServer(action, arg)
		if not result.ok then
			local text = Reasons(result.reason)
			if text then
				UI.toast(text, "Error", 3)
			end
		end
	end)
end

local function title(text: string)
	local sign = panel.frame:FindFirstChild("Sign")
	if sign then
		sign.Size = UDim2.fromOffset(math.max(180, #text * 15 + 76), 46)
		sign.Title.Text = text
	end
end

local function heading(order: number, text: string): TextLabel
	return UI.label({ Size = UDim2.new(1, 0, 0, 24), Font = UI.HEAD, TextSize = 17, Text = text, LayoutOrder = order, ZIndex = 23, Parent = panel.list })
end

local function noteRow(order: number): (Frame, TextLabel)
	local frame = make("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = C.cream, LayoutOrder = order, Visible = false, ZIndex = 22, Parent = panel.list },
		{ UI.corner(3), UI.stroke(UI.SEAM, 2) })
	local label = UI.label({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), Font = UI.HAND, TextSize = 19, TextWrapped = true, ZIndex = 23, Parent = frame })
	return frame, label
end

-- The window's fixed rows.
local road, roadText = noteRow(TOP)
local emptyNote, emptyText = noteRow(EMPTY)
emptyText.Text = "Nothing packed yet. Wash and pack crates at the bench, then load them here."
heading(PACKED, "PACKED CRATES")
local onTruck = heading(ON_TRUCK, "ON THE TRUCK")

local sendRow = make("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = TOP, Visible = false, ZIndex = 22, Parent = panel.list })
UI.label({ Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -190, 1, 0), Font = UI.HAND, TextSize = 19, TextWrapped = true, ZIndex = 23, Parent = sendRow,
	Text = "Prices lock the moment it leaves." })
local _, sendButton = UI.button({ text = "Send", kind = "gold", size = UDim2.fromOffset(170, 44), anchor = Vector2.new(1, 0.5),
	position = UDim2.new(1, -4, 0.5, 0), textSize = 17, zIndex = 23, parent = sendRow })
sendButton.Activated:Connect(function()
	send("Dispatch", tostring(truck))
end)

-- What one of a stack pays, by truck and in your store.
local function worth(stack, state, info, t: number): string
	local market = MarketPrice.price(stack.crop, t)
	local price = TruckRules.unitPrice(stack.crop, market, info.premium)
	local truckPays = math.floor(CrateRules.unitPrice({ grade = stack.grade, key = stack.key }, price) + 0.5)
	if not CrateRules.storeable(stack.key) then
		return `🚚 {UI.formatNumber(truckPays)} coins each (truck only)`
	end
	local storePays = state.store.prices[stack.crop] or math.floor(ShopRules.reference(stack.crop, market) + 0.5)
	return `🚚 {UI.formatNumber(truckPays)} · 🏪 {UI.formatNumber(storePays)} coins each`
end

local rows = {} -- ["Load key/grade" or "Unload key/grade"] = its row, kept while it's showing

-- A stack of crates: its colour band, what it is, and a button that does
-- `action` to it.
local function makeRow(stack, action: string)
	local crop = Crops.ById[stack.crop]
	local frame = make("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = C.cream, ZIndex = 22, Parent = panel.list }, { UI.corner(3), UI.stroke(UI.SEAM, 2) })
	make("Frame", { Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = Rarities.ById[crop.rarity].color, BorderSizePixel = 0, ZIndex = 23, Parent = frame })
	UI.label({ Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(40, 40), Font = UI.HEAD, Text = crop.icon or "🌱", TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 23, Parent = frame })
	local name = UI.fit(UI.label({ Position = UDim2.fromOffset(58, 5), Size = UDim2.new(1, -190, 0, 22), Font = UI.HEAD, TextSize = 17, TextColor3 = CropNames.color(stack.key), ZIndex = 23, Parent = frame }), 11)
	local line = UI.fit(UI.label({ Position = UDim2.fromOffset(58, 28), Size = UDim2.new(1, -190, 0, 20), Font = UI.HAND, TextSize = 18, ZIndex = 23, Parent = frame }), 11)
	local holder, button = UI.button({ text = "", kind = "cream", size = UDim2.fromOffset(112, 40), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -10, 0.5, 0),
		textSize = 16, zIndex = 23, parent = frame })
	button.Activated:Connect(function()
		send(action, `{truck}|{stack.key}|{stack.grade}`)
	end)
	return { frame = frame, name = name, line = line, holder = holder, button = button }
end

-- Shows a stack's row, with `word` and how many crates its button moves.
local function showRow(order: number, stack, action: string, word: string, moves: number, kind: string, detail: string)
	local id = `{action} {stack.key}/{stack.grade}`
	local row = rows[id] or makeRow(stack, action)
	rows[id] = row
	row.shown = true
	row.frame.LayoutOrder = order
	row.name.Text = string.upper(`{CropNames.of(stack.key)} ×{stack.units}{if stack.grade == "A" then " · grade A" else ""}`)
	row.line.Text = `{stack.crates} crate{if stack.crates == 1 then "" else "s"} · {detail}`
	row.button.Text = if moves > 1 then `{word} {moves}` else word
	if row.kind ~= kind then
		row.kind = kind
		UI.setButtonKind(row.holder, kind)
	end
end

local function render()
	local state = PlayerState.current
	if not state or not UI.isOpen(panel) then
		return
	end
	local t = now()
	local warehouse = state.warehouse
	local info = WarehouseRules.level(warehouse.level)
	local name = `{Warehouse.TRUCK_NAMES[info.truck]}{if info.trucks > 1 then ` {truck}` else ""}`
	local bed = warehouse.beds[truck] or {}
	local run = TruckRules.runOf(warehouse, truck, t)
	title(`Load the {name}`)
	panel.toolbar.Text = `🚚 {name} {if run then "on the road" else `{#bed}/{info.truckCrates} crates`}  ·  📦 Packed crates {#state.store.stockroom}/{PackRules.size(state)}`

	road.Visible = run ~= nil
	if run then
		roadText.Text = if t < run.arriveAt then `Your {name} is on the road: paid in {UI.formatTime(run.arriveAt - t)}, then it heads home.`
			else `Sold! Your {name} is home in {UI.formatTime(run.returnAt - t)}.`
	end
	sendRow.Visible = run == nil and #bed > 0
	if sendRow.Visible then
		local total = TruckRules.quote(bed, function(cropId)
			return MarketPrice.price(cropId, t)
		end, info.premium)
		sendButton.Text = `Send · {UI.formatNumber(total)}`
	end

	for _, row in rows do
		row.shown = false
	end
	local most = if info.handCart then Warehouse.HAND_CART else 1
	local room = if run then 0 else info.truckCrates - #bed
	local stacks = PackRules.stacks(state.store.stockroom)
	emptyNote.Visible = #stacks == 0
	for i, stack in stacks do
		showRow(CRATES + i, stack, "Load", "Load", math.max(1, math.min(most, stack.crates, room)), if room > 0 then "blue" else "cream", worth(stack, state, info, t))
	end
	onTruck.Visible = #bed > 0 and not run
	if onTruck.Visible then
		for i, stack in PackRules.stacks(bed) do
			showRow(TRUCK_CRATES + i, stack, "Unload", "Take off", math.min(most, stack.crates), "cream", worth(stack, state, info, t))
		end
	end
	for id, row in rows do
		if not row.shown then
			row.frame:Destroy()
			rows[id] = nil
		end
	end
end

function DockController.Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Opens") == "Dock" and prompt:GetAttribute("OwnerId") == player.UserId then
			truck = prompt:GetAttribute("Truck") or 1
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
				render()
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and spot and (root.Position - spot.Position).Magnitude > WALK_AWAY then
					panel.close()
				end
			end
		end
	end)
end

return DockController
