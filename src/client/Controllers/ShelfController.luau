-- The shelf panel (docs/GameDesign.md §4.8; the user, 2026-11-05: "players
-- should be able to press E to open a panel that shows all the produce they
-- have unlocked, with options to fill that shelf with the selected produce
-- or show out of stock"). E at one of your displays (its FillPrompt, which
-- carries the display's id) opens it:
--   * a seed-packet tab for each of the display's slots (a Produce Crate has
--     one and no tabs; a Wooden Shelf two, a Tiered Rack three);
--   * Auto first (the slot takes whatever the stockroom has most of), then a
--     card for every crop you've unlocked (its rarity's seed level, the one
--     that gates planting) and anything else you hold: how many are in the
--     stockroom, your price, and FILL, or OUT OF STOCK; crops this display
--     can't hold are greyed, with the display that can;
--   * the card the slot is kept to has a gold edge.
-- Picking one keeps the slot to it and fills the display (StoreAction
-- "Stock"); a one-slot display's panel closes once it's filled. Walking away
-- closes it. The Store window's Stock tab keeps Fill all.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared.Config.Crops)
local MarketPrice = require(Shared.MarketPrice)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local ShopRules = require(Shared.ShopRules)
local Store = require(Shared.Config.Store)
local StoreLayout = require(Shared.StoreLayout)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local Sfx = require(script.Parent.Parent.Sfx)
local UI = require(script.Parent.Parent.UI)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer
local StoreAction = Remotes.func("StoreAction")

local ShelfController = {}

local REACH = 11 -- studs from the display before the panel closes itself (you can fill from 9: StoreService.REACH)
local DIM = Color3.fromRGB(214, 206, 190)
local SLOT_TABS = { "Slot 1", "Slot 2", "Slot 3" }

local panel = UI.panel("Stock", {
	tabs = SLOT_TABS, tabColors = { C.green, C.green, C.green }, tabWidth = 116, toolbar = true, accent = C.green, width = 650, height = 430,
})
-- (cards short enough that two rows show on a short screen: in Studio's
-- 490-pixel view the second row's tags were cut off at 152)
make("UIGridLayout", { CellSize = UDim2.fromOffset(112, 132), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.list })

local shown = nil -- { id = display id, item = its model }
local busy = false

local function now(): number
	return workspace:GetServerTimeNow()
end

-- A crop's name for many ("carrots", "sheaves of wheat").
local function many(cropId: string): string
	return (string.gsub(Crops.count(cropId, 2), "^2 ", ""))
end

local function currentSlot(): number
	return tonumber(string.match(panel.tab or "", "%d+")) or 1
end

-- The first display in the catalog that holds a rarity ("a Chiller Cabinet").
local function holderOf(rarityId: string): string?
	for _, itemId in Store.ORDER do
		local def = Store.ITEMS[itemId]
		if def and def.kind == "Display" and StoreLayout.holds(itemId, rarityId) then
			return def.name
		end
	end
	return nil
end

-- One slot shows no tabs: the toolbar and the cards move up into their room.
local function layoutFor(slots: number)
	local top = if slots > 1 then 82 else 36
	panel.frame.Tabs.Visible = slots > 1
	for i, name in SLOT_TABS do
		panel.tabs[name].Visible = i <= slots
	end
	panel.toolbar.Position = UDim2.fromOffset(18, top)
	panel.list.Position = UDim2.fromOffset(14, top + 28)
	panel.list.Size = UDim2.new(1, -28, 1, -(top + 28 + 14))
end

-- The panel's sign says which display it is.
local function title(text: string)
	local sign = panel.frame:FindFirstChild("Sign")
	if sign then
		sign.Size = UDim2.fromOffset(math.max(180, #text * 15 + 76), 46)
		sign.Title.Text = text
	end
end

local function stock(choice: string, def)
	if busy or not shown then
		return
	end
	busy = true
	Sfx.play("UiClick")
	local id, slot = shown.id, currentSlot()
	task.spawn(function()
		local result = StoreAction:InvokeServer("Stock", `{id}|{slot}|{choice}`)
		busy = false
		if not result.ok then
			local text = Reasons(result.reason)
			if text then
				UI.toast(text, "Error", 3)
			end
			return
		end
		local moved = result.result and result.result.moved
		if moved and moved > 0 then
			local crop = Crops.ById[choice]
			UI.toast(if crop then `{crop.icon or ""} {Crops.count(crop.id, moved)} out on your {def.name}!` else `Your {def.name} is filled!`, "Good", 2.5)
			local state = PlayerState.current
			local entry = state and state.store.layout[id]
			if entry and #entry.slots == 1 then
				panel.close()
			end
		end
	end)
end

-- A card: the rarity band, the icon, the name, two lines, and its tag at
-- the bottom (FILL, OUT OF STOCK, or what holds it).
local function card(order: number, o)
	local frame = make("Frame", {
		Name = o.name, LayoutOrder = order, BackgroundColor3 = if o.dim then DIM else C.cream, ZIndex = 23, Parent = panel.list,
	}, { UI.corner(4), UI.stroke(if o.picked then C.gold else UI.SEAM, if o.picked then 4 else 2) })
	UI.crimp(frame, frame.BackgroundColor3, 7, 7)
	make("Frame", { -- the rarity band
		Size = UDim2.new(1, 0, 0, 8), Position = UDim2.fromOffset(0, 6), BackgroundColor3 = o.band, BorderSizePixel = 0, ZIndex = 23, Parent = frame,
	})
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 13), BackgroundTransparency = 1, Font = UI.HEAD,
		Text = o.icon, TextSize = 30, TextColor3 = C.ink, TextTransparency = if o.dim then 0.45 else 0, ZIndex = 23, Parent = frame,
	})
	UI.fit(UI.label({
		Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 46), Font = UI.HEAD, TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center, Text = o.name, TextColor3 = C.ink, ZIndex = 23, Parent = frame,
	}), 10)
	for i, line in { o.line1, o.line2 } do
		if line then
			UI.fit(UI.label({
				Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 48 + i * 16), Font = UI.HAND, TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Center, Text = line, TextColor3 = if o.dim then C.soil else C.ink, ZIndex = 23, Parent = frame,
			}), 10)
		end
	end
	local tag = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -12, 0, 22),
		BackgroundColor3 = o.tagColor, Font = UI.HEAD, Text = o.tag, TextSize = 15, TextColor3 = o.tagInk or C.cream, ZIndex = 23, Parent = frame,
	}, { UI.corner(3) })
	UI.fit(tag, 9)
	local hit = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 24, Parent = frame })
	hit.Activated:Connect(o.press)
end

local function render()
	if not shown or not UI.isOpen(panel) then
		return
	end
	local state = PlayerState.current
	local store = state and state.store
	local entry = store and store.layout[shown.id]
	local def = entry and Store.ITEMS[entry.item]
	if not def or def.kind ~= "Display" or not entry.slots then
		panel.close() -- (sold or moved away in Decorate)
		return
	end
	local slots = #entry.slots
	if currentSlot() > slots then
		panel.setTab(SLOT_TABS[1]) -- (renders again)
		return
	end
	title(def.name)
	layoutFor(slots)
	local n = currentSlot()
	for i = 1, slots do
		local crop = Crops.ById[entry.slots[i].crop or entry.slots[i].set or ""]
		panel.tabs[SLOT_TABS[i]].Text = if crop then `{crop.icon or ""} Slot {i}` else `Slot {i}`
	end
	local slot = entry.slots[n]
	local onIt = slot.units > 0 and Crops.ById[slot.crop or ""]
	local where = if slots > 1 then `Slot {n}: ` else ""
	panel.toolbar.Text = if onIt
		then `{where}{onIt.icon or ""} {Crops.count(onIt.id, slot.units)} out of {ShopRules.slotRoom(def, onIt.id)}. Pick a crop to top it up or change it.`
		else `{where}{if slots > 1 then "empty" else "Empty"}. Pick a crop to fill it.`

	UI.clear(panel.list)
	local held = ShopRules.stockroomUnits(store)
	local anyHere = false
	for cropId, count in held do
		if count > 0 and ShopRules.canHold(entry.item, cropId) then
			anyHere = true
		end
	end
	-- Auto: whatever the stockroom has most of
	card(0, {
		name = "Auto", icon = "🔄", band = C.green, line1 = "Whatever you", line2 = "have most of", picked = slot.set == nil,
		tag = if anyHere then "FILL" else "OUT OF STOCK", tagColor = if anyHere then C.green else C.soil,
		press = function()
			if not anyHere then
				UI.toast(`Nothing in your stockroom this {def.name} can hold. Pack a crate for 🏪 Store at the Packing Shed bench.`, "Error", 3.5)
				return
			end
			stock("Auto", def)
		end,
	})
	-- every crop you've unlocked, and anything else you hold
	local t = now()
	for i, crop in Crops.List do
		local rarity = Rarities.ById[crop.rarity]
		local count = held[crop.id] or 0
		local mine = slot.crop == crop.id or slot.set == crop.id
		if state.level >= rarity.seedLevel or count > 0 or mine then
			local canHold = ShopRules.canHold(entry.item, crop.id)
			local price = store.prices[crop.id] or math.floor(ShopRules.reference(crop.id, MarketPrice.price(crop.id, t)) + 0.5)
			local holder = if canHold then nil else holderOf(crop.rarity)
			card(i, {
				name = crop.name, icon = crop.icon or "🌱", band = rarity.color, dim = not canHold, picked = slot.set == crop.id,
				line1 = if count > 0 then `📦 {count} in stock` else "📦 none in stock",
				line2 = `🪙 {UI.formatShort(price)} each`,
				tag = if not canHold then `Needs a {holder or "bigger display"}` elseif count > 0 then (if mine then "TOP UP" else "FILL") else "OUT OF STOCK",
				tagColor = if not canHold then C.stitch elseif count > 0 then C.green else C.soil, tagInk = if not canHold then C.ink else nil,
				press = function()
					if not canHold then
						UI.toast(`{crop.icon or ""} {rarity.name or crop.rarity} crops don't go on a {def.name}: put them on a {holder or "bigger display"}.`, "Error", 3.5)
					elseif count <= 0 then
						UI.toast(`No {many(crop.id)} in your stockroom: pack a crate of them for 🏪 Store at the Packing Shed bench.`, "Error", 3.5)
					else
						stock(crop.id, def)
					end
				end,
			})
		end
	end
end

-- Opens the panel for one of your displays (its id in your layout, its model).
function ShelfController.open(id: string, item: Instance?)
	shown = { id = id, item = item }
	panel.setTab(SLOT_TABS[1])
	panel.open()
	render()
end

function ShelfController.Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local id = prompt:GetAttribute("Display")
		if prompt.Name == "FillPrompt" and id and prompt:GetAttribute("OwnerId") == player.UserId then
			ShelfController.open(id, prompt:FindFirstAncestor(id))
		end
	end)
	panel.onTab(render)
	panel.onClose = function()
		shown = nil
	end
	PlayerState.changed:Connect(render)
	-- walking away closes it
	task.spawn(function()
		while true do
			task.wait(0.25)
			if shown and UI.isOpen(panel) then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local item = shown.item
				if not root or not item or not item.Parent or (root.Position - item:GetPivot().Position).Magnitude > REACH then
					panel.close()
				end
			end
		end
	end)
end

return ShelfController
