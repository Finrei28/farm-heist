-- Decorate mode (docs/GameDesign.md §4.8, §5.3): your store from above with
-- the grid in chalk, the roof off and the walls faded, a drawer of item cards
-- along the bottom (Displays · Checkouts · Decor · Wall · My items), and the
-- layout as a draft you change freely: tap a card, then a cell; the item
-- shows green where it fits and red where it doesn't, with why
-- (shared/StoreLayout, the same check the server makes). Turn (or R) turns
-- it, ✓ Place (or a second tap, or a click) places it. Pinch or the mouse
-- wheel zooms in; drag (or WASD) moves the view. Tap a placed item to move,
-- turn, put away (it stays yours) or sell it back for half. DONE sends the
-- draft to the server, which buys what's new and saves it; Cancel leaves
-- everything as it was. While you're in here your store hangs "Back soon"
-- (StoreService).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared.Config.Crops)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local Store = require(Shared.Config.Store)
local StoreLayout = require(Shared.StoreLayout)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer
local StoreAction = Remotes.func("StoreAction")

local DecorateController = {}

local CELL = Store.CELL
local FLOOR = PlotLayout.PLOT.store.floor
local DOOR_TOP = 8.5 -- (a little over the doors: the awning and signs are above it)
local TILT = math.rad(22) -- the camera leans back toward the road a little, so fronts show
local GREEN = Color3.fromRGB(90, 220, 110)
local RED = Color3.fromRGB(240, 70, 60)
local BLUEPRINT = Color3.fromRGB(44, 84, 132)
local GRID = Color3.fromRGB(60, 96, 150) -- (blueprint blue: shows on wood and white tiles)
local TABS = { "Displays", "Checkouts", "Decor", "Wall", "My items" }
local KIND_OF_TAB = { Displays = "Display", Checkouts = "Checkout", Decor = "Decor", Wall = "Wall" }

local active = false
local plot, level, stage = 0, 1, 1
local draft = {} -- [id] = entry (no slots)
local sells = {} -- [itemId] = count to sell back
local owned, gifts = {}, {}
local serverLayout = {}
local nextTemp = 1
local holding = nil -- { id?, item, rot, x, y, side?, at?, original? }
local selected = nil -- the id of a placed item you tapped
local tab = "Displays"
local view = nil -- workspace folder: grid, items, ghost
local hidden = {} -- [BasePart] = how hidden (1, or faded 0.75) on this screen while decorating
local hud = {} -- [GuiObject] = visible before
local savedCamera = nil
local zoom, pan = 1, Vector3.zero -- (pan: how far the view has moved over the floor, in studs)
local touchControls = nil -- Roblox's thumbstick and jump button, hidden while decorating
local MAX_ZOOM = 2.6 -- (more for the big buildings: maxZoom)
local pingAt = 0

------------------------------------------------------------------------
-- The overlay

local overlay = make("Frame", { Name = "Decorate", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 30, Parent = UI.screen })
local hint, hintLabel = UI.tag({ name = "Hint", text = "", color = C.cream, autoWidth = true, size = UDim2.fromOffset(0, 34), anchor = Vector2.new(0.5, 0),
	position = UDim2.new(0.5, 0, 0, 12), zIndex = 31, parent = overlay })
local doneHolder, doneStamp = UI.stamp({ text = "DONE", kind = "green", diameter = 78, anchor = Vector2.new(1, 1), position = UDim2.new(1, -16, 1, -190), textSize = 18, zIndex = 31, parent = overlay })
local costLabel = UI.label({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -270), Size = UDim2.fromOffset(150, 24), Font = UI.HEAD, TextSize = 17,
	TextColor3 = C.cream, TextStrokeColor3 = UI.SEAM, TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center, Text = "", ZIndex = 31, Parent = overlay })
local cancelHolder, cancelStamp = UI.stamp({ text = "X", kind = "red", diameter = 48, anchor = Vector2.new(1, 1), position = UDim2.new(1, -102, 1, -196), textSize = 20, zIndex = 31, parent = overlay })

-- The drawer: tabs and a row of cards.
local drawer = make("Frame", { Name = "Drawer", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -24, 0, 176),
	BackgroundColor3 = C.kraft, ZIndex = 31, Parent = overlay }, { UI.corner(10), UI.stroke(C.soil, 3) })
local tabRow = make("Frame", { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 30), BackgroundTransparency = 1, ZIndex = 32, Parent = drawer },
	{ make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
local cards = make("ScrollingFrame", { Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 1, -50), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 5, ScrollBarImageColor3 = C.soil, ScrollingDirection = Enum.ScrollingDirection.X, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X, ZIndex = 32, Parent = drawer },
	{ make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		make("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6) }) })

-- The buttons beside the ghost or a picked item (right side, above the drawer).
local tools = make("Frame", { Name = "Tools", AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(130, 230), BackgroundTransparency = 1, ZIndex = 31, Parent = overlay },
	{ make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Left }) })
local function tool(order: number, text: string, kind: string)
	local holder, button = UI.button({ text = text, kind = kind, size = UDim2.fromOffset(126, 40), textSize = 17, zIndex = 32, parent = tools })
	holder.LayoutOrder = order
	return holder, button
end
local moveHolder, moveButton = tool(1, "Move", "blue")
local rotateHolder, rotateButton = tool(2, "Turn", "cream")
local awayHolder, awayButton = tool(3, "Put away", "cream")
local sellHolder, sellButton = tool(4, "Sell", "red")
local placeHolder, placeButton = tool(5, "✓ Place", "green")
local dropHolder, dropButton = tool(6, "Cancel", "cream")

UI.onLayout(function()
	local compact = UI.compact
	drawer.Size = UDim2.new(1, -24, 0, if compact then 132 else 176)
	local above = if compact then 138 else 186
	tools.Position = UDim2.new(0, 16, 1, -above)
	tools.Size = UDim2.fromOffset(130, if compact then 180 else 230)
	local done = if compact then 64 else 78
	doneHolder.Size = UDim2.fromOffset(done, done)
	doneHolder.Position = UDim2.new(1, -16, 1, -(above + 4))
	cancelHolder.Position = UDim2.new(1, -(done + 26), 1, -(above + 10))
	costLabel.Position = UDim2.new(1, -8, 1, -(above + done + 8))
end)

------------------------------------------------------------------------
-- Helpers

local function data()
	return PlayerState.current
end

local function plotModel(): Model?
	return workspace.World:FindFirstChild(`Plot{plot}`)
end

local function counts(): { [string]: number }
	return StoreLayout.counts(draft)
end

-- How many of an item you have that aren't on the floor (or walls).
local function spare(itemId: string): number
	return (owned[itemId] or 0) - (sells[itemId] or 0) - (counts()[itemId] or 0)
end

-- Coins the draft costs (negative: it pays you back).
local function cost(): number
	local total = 0
	local placed = counts()
	for itemId, def in Store.ITEMS do
		local have = (owned[itemId] or 0) - (sells[itemId] or 0)
		total += math.max(0, (placed[itemId] or 0) - have) * def.cost
		total -= (sells[itemId] or 0) * math.floor(def.cost * Store.SELL_BACK)
	end
	return total
end

-- "your Pumpkin shelf" for a display with something on it, else "your Wooden Shelf".
local function nameOf(id: string): string
	local entry = draft[id] or serverLayout[id]
	if not entry then
		return "items"
	end
	local def = Store.ITEMS[entry.item]
	local old = serverLayout[id]
	local slot = old and old.slots and old.slots[1]
	local crop = slot and slot.crop and Crops.ById[slot.crop]
	if crop then
		local words = string.split(def.name, " ")
		return `your {crop.name} {string.lower(words[#words])}`
	end
	return `your {def.name}`
end

-- Why a layout doesn't work, in words. `self` is the item being placed.
local function explain(reason: string, about: string?, self: string?): string
	local mine = about == nil or about == self
	if reason == "OutOfFloor" then
		return "It doesn't fit on the open floor here."
	elseif reason == "Overlap" then
		return "Something's already there."
	elseif reason == "Doorway" then
		return "Keep the doorways clear."
	elseif reason == "WallSpace" then
		return "There's no room on that wall."
	elseif reason == "FrontBlocked" then
		return if mine then "Leave the space in front of it free." else `That's in front of {nameOf(about :: string)}.`
	elseif reason == "BehindBlocked" then
		return if mine then "A Register needs room behind it for whoever serves." else `That's where you'd stand to serve at {nameOf(about :: string)}.`
	elseif reason == "Unreachable" then
		return if mine then "Shoppers couldn't reach it from the door." else `This would block the aisle to {nameOf(about :: string)}.`
	elseif reason == "StaffDoor" then
		return "Keep a way to the staff door."
	elseif reason == "NoQueue" then
		return if mine then "A checkout needs 2 free cells in a line for its queue." else `This would block the queue at {nameOf(about :: string)}.`
	elseif reason == "NoCheckout" then
		return "Your store needs a checkout."
	elseif reason == "TooManyCheckouts" then
		return `Your store can have {StoreLayout.level(level).checkouts} checkouts at this level.`
	elseif reason == "TooMany" then
		return "That's as many items as a store can hold."
	end
	return Reasons(reason) or "That doesn't work."
end

local function setHint(text: string, color: Color3?)
	hintLabel.Text = text
	UI.setTagColor(hint, color or C.cream, if color == RED then C.cream else C.ink)
end

------------------------------------------------------------------------
-- The 3D view: grid, draft items, ghost

local function clearView()
	if view then
		view:Destroy()
	end
	view = Instance.new("Folder")
	view.Name = "DecorateView"
	view.Parent = workspace
end

local function flat(name: string, cframe: CFrame, size: Vector3, color: Color3, transparency: number?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.CFrame = cframe
	p.Transparency = transparency or 0
	p.Parent = view
	return p
end

-- The chalk grid over the open floor, and the two doors marked.
local function drawGrid()
	local frame = PlotLayout.frame(plot)
	local floor = StoreLayout.level(level).floor
	local w, d = floor[1], floor[2]
	local function at(cx: number, cy: number): CFrame
		return frame * CFrame.new(PlotLayout.storeLocal(cx, cy, FLOOR + 0.09))
	end
	for x = 0, w do
		flat("Chalk", at(x + 0.5, (d + 1) / 2), Vector3.new(0.16, 0.05, d * CELL), GRID, 0.25)
	end
	for y = 0, d do
		flat("Chalk", at((w + 1) / 2, y + 0.5), Vector3.new(w * CELL, 0.05, 0.16), GRID, 0.25)
	end
	for _, door in { { Store.DOOR_X, 1, "DOOR" }, { 1, Store.STAFF_Y, "STAFF" } } do
		local mark = flat("DoorMark", at(door[1], door[2]) * CFrame.new(0, -0.02, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(CELL - 0.4, 0.04, CELL - 0.4), C.gold, 0.55)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = UI.HEAD
		label.TextScaled = true
		label.TextColor3 = C.ink
		label.Text = door[3]
		label.Parent = gui
		gui.Parent = mark
	end
end

local itemModels = {} -- [id] = Model (this screen's copies)
local footprint

local function stripModel(model: Model, transparency: number?)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.LocalTransparencyModifier = 0
			if transparency and p.Transparency < transparency then
				p.Transparency = transparency
			end
		elseif p:IsA("ProximityPrompt") or p:IsA("BillboardGui") then
			p:Destroy()
		end
	end
end

-- A copy of an item to show: the real one with its produce if it's on the
-- floor already, else the catalog's.
local function copyOf(id: string?, itemId: string): Model
	local model = plotModel()
	local real = id and model and model.Store.Items:FindFirstChild(id)
	local source = if real and real:GetAttribute("Item") == itemId then real else ReplicatedStorage.StoreCatalog[itemId]
	local copy = source:Clone()
	stripModel(copy)
	return copy
end

-- A coloured plate on the floor (or the wall) under an item: green where it
-- fits, red where it doesn't, gold for the one you picked.
function footprint(model: Model, entry, color: Color3): BasePart
	local plate = model:FindFirstChild("Footprint")
	if not plate then
		plate = Instance.new("Part")
		plate.Name = "Footprint"
		plate.Anchored = true
		plate.CanCollide = false
		plate.CanQuery = false
		plate.CanTouch = false
		plate.CastShadow = false
		plate.Material = Enum.Material.Neon -- (it glows: easy to read on a phone)
		plate.Transparency = 0.45
		plate.Parent = model
	end
	plate.Color = color
	local def = Store.ITEMS[entry.item]
	if def.kind == "Wall" then
		plate.Size = Vector3.new(def.size[1] * CELL - 0.3, 3, 0.06)
		plate.CFrame = PlotLayout.storeItemFrame(plot, entry, stage) * CFrame.new(0, 0, -0.04)
	else
		local w, d = StoreLayout.span(entry.item, entry.rot or 0)
		plate.Size = Vector3.new(w * CELL - 0.3, 0.06, d * CELL - 0.3)
		local frame = PlotLayout.frame(plot)
		plate.CFrame = frame * CFrame.new(PlotLayout.storeLocal(entry.x + (w - 1) / 2, entry.y + (d - 1) / 2, FLOOR + 0.12))
	end
	return plate
end

local function drawItems()
	for _, model in itemModels do
		model:Destroy()
	end
	table.clear(itemModels)
	for id, entry in draft do
		local copy = copyOf(id, entry.item)
		copy:PivotTo(PlotLayout.storeItemFrame(plot, entry, stage))
		copy.Parent = view
		itemModels[id] = copy
		if id == selected then
			footprint(copy, entry, C.gold)
		end
	end
end

local ghost = nil -- { model, item }

local function trial()
	local candidate = table.clone(draft)
	local id = holding.id or "new"
	if Store.ITEMS[holding.item].kind == "Wall" then
		candidate[id] = { item = holding.item, side = holding.side, at = holding.at }
	else
		candidate[id] = { item = holding.item, x = holding.x, y = holding.y, rot = holding.rot }
	end
	return candidate, id
end

local function check()
	if not holding or (holding.x == nil and holding.side == nil) then
		return false, nil, nil
	end
	local candidate, id = trial()
	local ok, reason, about = StoreLayout.check(candidate, level)
	return ok, reason, about, id
end

local function drawGhost()
	if ghost and (not holding or ghost.item ~= holding.item) then
		ghost.model:Destroy()
		ghost = nil
	end
	if not holding or (holding.x == nil and holding.side == nil) then
		return
	end
	if not ghost then
		local model = copyOf(holding.id, holding.item)
		stripModel(model, 0.3)
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 0.55
		highlight.OutlineTransparency = 0
		highlight.Parent = model
		model.Parent = view
		ghost = { model = model, item = holding.item, highlight = highlight }
	end
	local candidate, id = trial()
	ghost.model:PivotTo(PlotLayout.storeItemFrame(plot, candidate[id], stage))
	local ok, reason, about = StoreLayout.check(candidate, level)
	ghost.highlight.FillColor = if ok then GREEN else RED
	ghost.highlight.OutlineColor = if ok then GREEN else RED
	footprint(ghost.model, candidate[id], if ok then GREEN else RED)
	if ok then
		setHint(if UI.touch then "Tap ✓ Place, or the same spot again" else "Click to place · R turns it", GREEN)
	else
		setHint(explain(reason :: string, about, id), RED)
	end
end

------------------------------------------------------------------------
-- The drawer

local function preview(parent: GuiObject, itemId: string)
	local viewport = make("ViewportFrame", { Size = UDim2.new(1, -8, 0, 54), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = BLUEPRINT,
		Ambient = Color3.fromRGB(170, 170, 170), LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-1, -2, -1.5),
		ZIndex = 34, Parent = parent }, { UI.corner(4) })
	local model = ReplicatedStorage.StoreCatalog[itemId]:Clone()
	model:PivotTo(CFrame.new())
	model.Parent = viewport
	local camera = Instance.new("Camera")
	local def = Store.ITEMS[itemId]
	local size = math.max(def.size[1], def.size[2]) * CELL
	local centre = if def.kind == "Wall" then Vector3.new(0, 0, -0.5) else Vector3.new(0, 2.6, 0)
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(centre + Vector3.new(size * 0.55, size * 0.45 + 2, -size * 1.25 - 3), centre)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local refreshDrawer

local function card(order: number, itemId: string)
	local def = Store.ITEMS[itemId]
	local locked = def.level > level
	local have = spare(itemId)
	local holder = make("Frame", { Size = UDim2.fromOffset(if UI.compact then 104 else 124, if UI.compact then 76 else 124), BackgroundColor3 = C.cream,
		LayoutOrder = order, ZIndex = 33, Parent = cards }, { UI.corner(5), UI.stroke(if holding and holding.item == itemId then C.green else UI.SEAM, if holding and holding.item == itemId then 3 else 2) })
	if not UI.compact then
		preview(holder, itemId)
	end
	local top = if UI.compact then 4 else 60
	UI.fit(UI.label({ Position = UDim2.fromOffset(6, top), Size = UDim2.new(1, -12, 0, 18), Font = UI.HEAD, TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center, Text = def.name, ZIndex = 34, Parent = holder }), 9)
	local detail
	if def.kind == "Display" then
		local low, high = StoreLayout.rarityRange(itemId)
		detail = `{def.slots}×{def.units} · {if low == high then low else `{low}–{high}`}`
	elseif def.kind == "Checkout" then
		detail = `a shopper every {def.serve} s` .. (if def.staffed then " (staffed)" else "")
	else
		detail = `Charm {def.charm}`
	end
	UI.fit(UI.label({ Position = UDim2.fromOffset(6, top + 17), Size = UDim2.new(1, -12, 0, 16), Font = UI.HAND, TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center, Text = `{def.size[1]}×{def.size[2]} · {detail}`, ZIndex = 34, Parent = holder }), 9)
	local priceText = if have > 0 then `Yours ×{have}` elseif locked then `🔒 Store Lv {def.level}` else UI.formatNumber(def.cost)
	UI.tag({ text = priceText, coin = have <= 0 and not locked, color = if have > 0 then C.green elseif locked then C.kraft else C.gold,
		textColor = if have > 0 then C.cream else C.ink, size = UDim2.fromOffset(if UI.compact then 92 else 110, 24), anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 6, 1, -4), textSize = 13, zIndex = 34, parent = holder })
	local hit = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 36, Parent = holder })
	hit.Activated:Connect(function()
		if locked and have <= 0 then
			UI.toast(`The {def.name} comes with Store Level {def.level}.`, "Error", 3)
			return
		end
		selected = nil
		holding = { item = itemId, rot = 0 }
		setHint(if def.kind == "Wall" then "Tap near a wall to hang it" else "Tap a spot on the floor", C.cream)
		drawItems()
		drawGhost()
		refreshDrawer()
	end)
end

function refreshDrawer()
	UI.clear(cards)
	local order = 0
	if tab == "My items" then
		for _, itemId in Store.ORDER do
			if spare(itemId) > 0 then
				order += 1
				card(order, itemId)
			end
		end
		if order == 0 then
			UI.label({ Size = UDim2.fromOffset(400, 60), Font = UI.HAND, TextSize = 18, Text = "Everything you own is out. Put something away and it waits here.",
				TextWrapped = true, ZIndex = 33, Parent = cards })
		end
	else
		for _, itemId in Store.ORDER do
			if Store.ITEMS[itemId].kind == KIND_OF_TAB[tab] then
				order += 1
				card(order, itemId)
			end
		end
	end
	for _, button in tabRow:GetChildren() do
		if button:IsA("Frame") then
			UI.setButtonKind(button, if button.Name == tab then "gold" else "cream")
		end
	end
	local total = cost()
	costLabel.Text = if total > 0 then `−{UI.formatNumber(total)}` elseif total < 0 then `+{UI.formatNumber(-total)}` else ""
	-- the tools that make sense now
	local picked = selected and draft[selected]
	moveHolder.Visible = picked ~= nil
	awayHolder.Visible = picked ~= nil
	sellHolder.Visible = picked ~= nil
	rotateHolder.Visible = picked ~= nil or (holding ~= nil and Store.ITEMS[holding.item].kind ~= "Wall")
	placeHolder.Visible = holding ~= nil
	dropHolder.Visible = holding ~= nil
	if picked then
		local def = Store.ITEMS[picked.item]
		local sellable = (owned[picked.item] or 0) - (sells[picked.item] or 0) - (gifts[picked.item] or 0) > 0
		sellHolder.Visible = sellable
		sellButton.Text = `Sell +{UI.formatNumber(math.floor(def.cost * Store.SELL_BACK))}`
		if def.kind == "Wall" then
			rotateHolder.Visible = false
		end
	end
end

for i, name in TABS do
	local holder, button = UI.button({ name = name, text = name, kind = "cream", size = UDim2.fromOffset(if name == "My items" then 92 else 86, 28), textSize = 14, zIndex = 33, parent = tabRow })
	holder.Name = name
	holder.LayoutOrder = i
	button.Activated:Connect(function()
		tab = name
		refreshDrawer()
	end)
end

------------------------------------------------------------------------
-- Pointing at the floor

-- The grid cell (floats) under a screen point, or nil.
local function cellAt(screen: Vector2): (number?, number?)
	local camera = workspace.CurrentCamera
	local ray = camera:ScreenPointToRay(screen.X, screen.Y) -- (input positions leave out Roblox's top bar)
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil, nil
	end
	local t = (FLOOR - ray.Origin.Y) / ray.Direction.Y
	if t <= 0 then
		return nil, nil
	end
	return PlotLayout.storeCellAt(plot, ray.Origin + ray.Direction * t)
end

-- Moves the ghost under a screen point. Returns whether it moved.
local function aim(screen: Vector2): boolean
	if not holding then
		return false
	end
	local cx, cy = cellAt(screen)
	if not cx then
		return false
	end
	local def = Store.ITEMS[holding.item]
	local before = `{holding.x},{holding.y},{holding.side},{holding.at}`
	if def.kind == "Wall" then
		local cells = Store.BUILDINGS[stage].cells
		local options = {
			{ side = "back", distance = math.abs(cy - (cells[2] + 0.5)), along = cx, length = cells[1] },
			{ side = "gate", distance = math.abs(cx - 0.5), along = cy, length = cells[2] },
			{ side = "hedge", distance = math.abs(cx - (cells[1] + 0.5)), along = cy, length = cells[2] },
		}
		table.sort(options, function(a, b)
			return a.distance < b.distance
		end)
		local best = options[1]
		holding.side = best.side
		holding.at = math.clamp(math.floor(best.along - (def.size[1] - 1) / 2 + 0.5), 1, math.max(1, best.length - def.size[1] + 1))
		holding.x = 0
	else
		local w, d = StoreLayout.span(holding.item, holding.rot)
		holding.x = math.floor(cx - (w - 1) / 2 + 0.5)
		holding.y = math.floor(cy - (d - 1) / 2 + 0.5)
	end
	drawGhost()
	return before ~= `{holding.x},{holding.y},{holding.side},{holding.at}`
end

-- The item on the floor (or wall) at a screen point.
local function itemAt(screen: Vector2): string?
	local cx, cy = cellAt(screen)
	if not cx then
		return nil
	end
	local x, y = math.floor(cx + 0.5), math.floor(cy + 0.5)
	for id, entry in draft do
		if not StoreLayout.isWall(entry) then
			for _, cell in StoreLayout.cells(entry) do
				if cell[1] == x and cell[2] == y then
					return id
				end
			end
		end
	end
	-- wall items: near the wall they hang on
	local cells = Store.BUILDINGS[stage].cells
	for id, entry in draft do
		if StoreLayout.isWall(entry) then
			local def = Store.ITEMS[entry.item]
			local along = if entry.side == "back" then cx else cy
			local distance = if entry.side == "back" then math.abs(cy - (cells[2] + 0.5)) elseif entry.side == "gate" then math.abs(cx - 0.5) else math.abs(cx - (cells[1] + 0.5))
			if distance < 1 and along >= entry.at - 0.5 and along <= entry.at + def.size[1] - 0.5 then
				return id
			end
		end
	end
	return nil
end

local function place()
	if not holding then
		return
	end
	local ok, reason, about, id = check()
	if not ok then
		UI.toast(explain(reason or "OutOfFloor", about, id), "Error", 3)
		return
	end
	local def = Store.ITEMS[holding.item]
	local newId = holding.id or `n{nextTemp}`
	if not holding.id then
		nextTemp += 1
	end
	draft[newId] = if def.kind == "Wall" then { item = holding.item, side = holding.side, at = holding.at }
		else { item = holding.item, x = holding.x, y = holding.y, rot = holding.rot }
	local wasNew = holding.id == nil
	-- keep a new item in hand for placing another (Cancel to stop)
	if wasNew and (spare(holding.item) > 0 or def.level <= level) then
		holding = { item = holding.item, rot = holding.rot }
		setHint("Placed! Tap another spot for one more, or Cancel", GREEN)
	else
		holding = nil
		setHint("Moved. Tap an item to change it, or pick from the drawer", C.cream)
	end
	drawItems()
	drawGhost()
	refreshDrawer()
end

local function turn()
	if holding and Store.ITEMS[holding.item].kind ~= "Wall" then
		holding.rot = (holding.rot + 1) % 4
		drawGhost()
		return
	end
	local entry = selected and draft[selected]
	if entry and not StoreLayout.isWall(entry) then
		for step = 1, 3 do
			local candidate = table.clone(draft)
			candidate[selected] = { item = entry.item, x = entry.x, y = entry.y, rot = (entry.rot + step) % 4 }
			local ok = StoreLayout.check(candidate, level)
			if ok then
				draft[selected] = candidate[selected]
				drawItems()
				refreshDrawer()
				return
			end
		end
		UI.toast("It won't turn here: move it first.", "Error", 3)
	end
end

local function drop()
	if holding and holding.original then
		draft[holding.id] = holding.original -- (back where it was)
	end
	holding = nil
	drawItems()
	drawGhost()
	refreshDrawer()
	setHint("Pick something from the drawer, or tap an item to move it", C.cream)
end

local function pressAt(screen: Vector2)
	if holding then
		-- a click places it where it's hovering; on a touch screen the first
		-- tap moves it and a second tap on the same spot places it
		if not aim(screen) then
			place()
		end
		return
	end
	selected = itemAt(screen)
	drawItems()
	refreshDrawer()
	if selected then
		setHint(`{Store.ITEMS[draft[selected].item].name}: move, turn, put away or sell`, C.cream)
	else
		setHint("Pick something from the drawer, or tap an item to move it", C.cream)
	end
end

moveButton.Activated:Connect(function()
	local entry = selected and draft[selected]
	if not entry then
		return
	end
	holding = { id = selected, item = entry.item, rot = entry.rot or 0, x = entry.x, y = entry.y, side = entry.side, at = entry.at, original = entry }
	draft[selected] = nil
	selected = nil
	drawItems()
	drawGhost()
	refreshDrawer()
end)
rotateButton.Activated:Connect(turn)
placeButton.Activated:Connect(place)
dropButton.Activated:Connect(drop)
awayButton.Activated:Connect(function()
	if not selected then
		return
	end
	local candidate = table.clone(draft)
	candidate[selected] = nil
	local ok, reason = StoreLayout.check(candidate, level)
	if not ok and reason == "NoCheckout" then
		UI.toast("Your store needs a checkout: put another one out first.", "Error", 3)
		return
	end
	draft[selected] = nil
	selected = nil
	drawItems()
	refreshDrawer()
	setHint("Put away: it's in My items", C.cream)
end)
sellButton.Activated:Connect(function()
	local entry = selected and draft[selected]
	if not entry then
		return
	end
	local candidate = table.clone(draft)
	candidate[selected] = nil
	local _, reason = StoreLayout.check(candidate, level)
	if reason == "NoCheckout" then
		UI.toast("Your store needs a checkout: put another one out first.", "Error", 3)
		return
	end
	draft[selected] = nil
	sells[entry.item] = (sells[entry.item] or 0) + 1
	selected = nil
	drawItems()
	refreshDrawer()
	setHint("Sold back when you press DONE", C.cream)
end)

------------------------------------------------------------------------
-- In and out

local function setHud(visible: boolean)
	if not visible then
		table.clear(hud)
		for _, child in UI.screen:GetChildren() do
			if child:IsA("GuiObject") and child ~= overlay and child.Name ~= "Toasts" and child.Visible then
				hud[child] = true
				child.Visible = false
			end
		end
	else
		for child in hud do
			child.Visible = true
		end
		table.clear(hud)
	end
end

-- Takes the roof off (and the awning, signs and anything else above the
-- doors or in front of the shop window), fades the walls and hides the real
-- items (we draw the draft instead), on this screen only. Words on hidden
-- parts are switched off too: a SurfaceGui still shows on an invisible part.
local guis = {} -- [SurfaceGui | BillboardGui] = true: switched off while decorating
local function hideStore(model: Model)
	local frame = PlotLayout.frame(plot)
	local function treat(p: Instance)
		if (p:IsA("SurfaceGui") or p:IsA("BillboardGui")) and p.Enabled and p.Parent and hidden[p.Parent] == 1 then
			p.Enabled = false
			guis[p] = true
			return
		end
		if not p:IsA("BasePart") then
			return
		end
		local at = frame:PointToObjectSpace(p.Position)
		local inBuilding = p:IsDescendantOf(model.Store.Building) or p:IsDescendantOf(model.Store)
		if p:IsDescendantOf(model.Store.Items) or p:IsDescendantOf(model.Store.Building.Roof)
			or (inBuilding and not p:IsDescendantOf(model.Store.Building.StaffDoor) and (at.Y > DOOR_TOP or at.Z < -1.2)) then
			p.LocalTransparencyModifier = 1
			hidden[p] = 1
		elseif inBuilding and at.Y > FLOOR + 1.5 and p.Size.Y > 2 then
			p.LocalTransparencyModifier = 0.75
			hidden[p] = 0.75
		end
		for _, gui in p:GetChildren() do
			treat(gui)
		end
	end
	for _, p in model.Store:GetDescendants() do
		treat(p)
	end
	return model.Store.DescendantAdded:Connect(treat)
end
local hideConnection = nil

local function showStore()
	for p in hidden do
		if p.Parent then
			p.LocalTransparencyModifier = 0
		end
	end
	table.clear(hidden)
	for gui in guis do
		gui.Enabled = true
	end
	table.clear(guis)
	if hideConnection then
		hideConnection:Disconnect()
		hideConnection = nil
	end
end

local function controls(enabled: boolean)
	local ok, module = pcall(function()
		return require(player.PlayerScripts:WaitForChild("PlayerModule", 2))
	end)
	if ok and module then
		local playerControls = module:GetControls()
		if enabled then
			playerControls:Enable()
		else
			playerControls:Disable()
		end
	end
end

local function frameCamera()
	local camera = workspace.CurrentCamera
	local cells = Store.BUILDINGS[stage].cells
	local frame = PlotLayout.frame(plot)
	local centre = PlotLayout.storeWorld(plot, (cells[1] + 1) / 2, (cells[2] + 1) / 2, FLOOR)
	local viewport = camera.ViewportSize
	local drawerHeight = drawer.AbsoluteSize.Y + 16
	local top = if UI.compact then 84 else 124 -- (the hint and Roblox's own buttons along the top, and room above the back wall for its wall items)
	local usable = math.max(0.3, (viewport.Y - drawerHeight - top) / viewport.Y)
	local tanHalf = math.tan(math.rad(camera.FieldOfView / 2))
	local aspect = viewport.X / math.max(1, viewport.Y)
	local depth, width = cells[2] * CELL + 3, cells[1] * CELL + 4
	local distance = math.max(depth / (2 * tanHalf * usable), width / (2 * tanHalf * aspect * 0.86)) / zoom
	-- lean back toward the road, and shift so the floor sits above the drawer
	local toRoad = -frame.ZVector
	local shift = (drawerHeight - top) / 2 / viewport.Y * 2 * distance * tanHalf
	-- (zoomed in, the view can move over the floor, but not off it)
	local reach = Vector2.new(width, depth) / 2 * (1 - 1 / zoom)
	local across, along = pan:Dot(frame.XVector), pan:Dot(frame.ZVector)
	pan = frame.XVector * math.clamp(across, -reach.X, reach.X) + frame.ZVector * math.clamp(along, -reach.Y, reach.Y)
	local target = centre + toRoad * shift + pan
	local eye = target + Vector3.new(0, distance * math.cos(TILT), 0) + toRoad * distance * math.sin(TILT)
	camera.CFrame = CFrame.lookAt(eye, target, frame.ZVector)
end

-- Studs of floor one screen pixel covers now (for dragging the view).
local function studsPerPixel(): number
	local camera = workspace.CurrentCamera
	local frame = PlotLayout.frame(plot)
	local distance = (camera.CFrame.Position.Y - FLOOR) / math.cos(TILT)
	return 2 * distance * math.tan(math.rad(camera.FieldOfView / 2)) / math.max(1, camera.ViewportSize.Y), frame
end

-- Moves the view by a drag of `delta` pixels (the floor follows your finger).
local function drag(delta: Vector2)
	local spp, frame = studsPerPixel()
	local camera = workspace.CurrentCamera
	local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z).Unit
	pan += (-right * delta.X + frame.ZVector * delta.Y) * spp
end

-- Zoomed all the way in, about 18 studs of floor (4½ rows) fill the view's
-- height in every building, so a cell is as big to tap in the Supermarket
-- as in the Corner Store.
local function maxZoom(): number
	local cells = Store.BUILDINGS[stage].cells
	return math.max(MAX_ZOOM, (cells[2] * CELL + 3) / 18)
end

local function setZoom(value: number)
	zoom = math.clamp(value, 1, maxZoom())
end

local function exit(save: boolean)
	if not active then
		return
	end
	if save then
		local payload = HttpService:JSONEncode({ items = draft, sell = sells })
		local result = StoreAction:InvokeServer("Layout", payload)
		if not result.ok then
			UI.toast(explain(result.reason, nil, nil), "Error", 4)
			return
		end
		local spent = result.result and result.result.cost or 0
		UI.toast(if spent > 0 then `Saved! Spent {UI.formatNumber(spent)}.` elseif spent < 0 then `Saved! Sold back for {UI.formatNumber(-spent)}.` else "Saved! Your store is open again.", "Good", 3)
	else
		task.spawn(StoreAction.InvokeServer, StoreAction, "Decorate", "Off")
	end
	active = false
	overlay.Visible = false
	setHud(true)
	showStore()
	controls(true)
	if touchControls then
		touchControls.Enabled = true
		touchControls = nil
	end
	if ghost then
		ghost.model:Destroy()
		ghost = nil
	end
	for _, model in itemModels do
		model:Destroy()
	end
	table.clear(itemModels)
	if view then
		view:Destroy()
		view = nil
	end
	local camera = workspace.CurrentCamera
	if savedCamera then
		camera.FieldOfView = savedCamera.fov
		-- back behind your character (the follow camera carries on from
		-- wherever it's left, and it was left high over the store)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local eye = root.Position - root.CFrame.LookVector * 14 + Vector3.new(0, 6, 0)
			camera.CFrame = CFrame.lookAt(eye, root.Position + Vector3.new(0, 2, 0))
		end
		camera.CameraType = savedCamera.type
	end
	local character = player.Character
	for _, p in (character and character:GetDescendants()) or {} do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = 0
		end
	end
end

-- Opens Decorate mode (the Store window's stamp).
function DecorateController.enter()
	if active then
		return
	end
	local state = data()
	plot = player:GetAttribute("Plot") or 0
	if not state or plot == 0 then
		return
	end
	local result = StoreAction:InvokeServer("Decorate", "On")
	if not result.ok then
		UI.toast(Reasons(result.reason) or "You can't decorate right now.", "Error", 3)
		return
	end
	UI.closePanels()
	active = true
	level = state.store.level
	stage = StoreLayout.level(level).stage
	serverLayout = state.store.layout
	table.clear(draft)
	for id, entry in serverLayout do
		draft[id] = if StoreLayout.isWall(entry) then { item = entry.item, side = entry.side, at = entry.at }
			else { item = entry.item, x = entry.x, y = entry.y, rot = entry.rot }
	end
	table.clear(sells)
	owned = table.clone(state.store.owned)
	gifts = table.clone(state.store.gifts)
	holding, selected, tab = nil, nil, "Displays"
	nextTemp = 1
	pingAt = os.clock()
	clearView()
	drawGrid()
	drawItems()
	local model = plotModel()
	if model then
		hideConnection = hideStore(model)
	end
	setHud(false)
	overlay.Visible = true
	controls(false)
	zoom, pan = 1, Vector3.zero
	local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
	if touchGui and touchGui.Enabled then
		touchGui.Enabled = false
		touchControls = touchGui
	end
	local camera = workspace.CurrentCamera
	savedCamera = { type = camera.CameraType, fov = camera.FieldOfView }
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 45
	local character = player.Character
	for _, p in (character and character:GetDescendants()) or {} do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = 0.7
		end
	end
	refreshDrawer()
	task.defer(frameCamera)
	setHint("Pick something from the drawer, or tap an item to move it", C.cream)
end

function DecorateController.isActive(): boolean
	return active
end

function DecorateController.Start()
	doneStamp.Activated:Connect(function()
		exit(true)
	end)
	cancelStamp.Activated:Connect(function()
		exit(false)
	end)
	-- taps and clicks on the floor (not on the overlay); a finger that moves
	-- drags the view instead
	local touchStart, touchLast, dragging = nil, nil, false
	UserInputService.InputBegan:Connect(function(input, processed)
		if not active or processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressAt(Vector2.new(input.Position.X, input.Position.Y))
		elseif input.UserInputType == Enum.UserInputType.Touch then
			touchStart = Vector2.new(input.Position.X, input.Position.Y)
			touchLast, dragging = touchStart, false
		elseif input.KeyCode == Enum.KeyCode.R then
			turn()
		elseif input.KeyCode == Enum.KeyCode.Escape then
			if holding then
				drop()
			else
				selected = nil
				drawItems()
				refreshDrawer()
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input, processed)
		if not active or processed or input.UserInputType ~= Enum.UserInputType.Touch or not touchStart then
			return
		end
		local at = Vector2.new(input.Position.X, input.Position.Y)
		if not dragging and (at - touchStart).Magnitude < 14 then
			pressAt(at)
		end
		touchStart, dragging = nil, false
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if not active then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement and holding and not processed then
			aim(Vector2.new(input.Position.X, input.Position.Y))
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			setZoom(zoom * 1.15 ^ input.Position.Z)
		elseif input.UserInputType == Enum.UserInputType.Touch and touchStart then
			local at = Vector2.new(input.Position.X, input.Position.Y)
			if dragging or (at - touchStart).Magnitude >= 14 then
				dragging = true
				drag(at - touchLast)
			end
			touchLast = at
		end
	end)
	local pinchFrom = 1
	UserInputService.TouchPinch:Connect(function(_, scale, _, state, processed)
		if not active or processed then
			return
		end
		if state == Enum.UserInputState.Begin then
			pinchFrom = zoom
			dragging = true -- (two fingers: never a tap)
		end
		setZoom(pinchFrom * scale)
	end)
	-- keep the camera framed (the window resizes, a phone turns) and the
	-- "Back soon" sign up (the server ends it after 5 idle minutes)
	RunService.RenderStepped:Connect(function()
		if not active then
			return
		end
		if not UserInputService:GetFocusedTextBox() then
			local keys = Vector2.new(
				(if UserInputService:IsKeyDown(Enum.KeyCode.D) then 1 else 0) - (if UserInputService:IsKeyDown(Enum.KeyCode.A) then 1 else 0),
				(if UserInputService:IsKeyDown(Enum.KeyCode.S) then 1 else 0) - (if UserInputService:IsKeyDown(Enum.KeyCode.W) then 1 else 0))
			if keys.Magnitude > 0 then
				drag(-keys * 6) -- (the view moves the way you press)
			end
		end
		frameCamera()
		for _, child in UI.screen:GetChildren() do
			if child:IsA("GuiObject") and child ~= overlay and child.Name ~= "Toasts" and child.Visible then
				hud[child] = true
				child.Visible = false
			end
		end
		if os.clock() - pingAt > 60 then
			pingAt = os.clock()
			task.spawn(StoreAction.InvokeServer, StoreAction, "Decorate", "On")
		end
	end)
	-- the server can end it (you wandered off, or 5 idle minutes)
	PlayerState.changed:Connect(function(state)
		if active and state.store.level ~= level then
			UI.toast("Your store changed level: decorate again to use the new floor.", "Announce", 4)
			exit(false)
		end
	end)
	player.CharacterRemoving:Connect(function()
		exit(false)
	end)
end

return DecorateController
