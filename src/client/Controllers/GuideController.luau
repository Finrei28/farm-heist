-- The Farm Guide's card (docs/GameDesign.md §4.0; Config/Guide, shared/GuideRules,
-- server GuideService): a clipboard on the right of the screen with the step
-- you're on, a line on how to do it and a box for each of the 8 steps.
--   * a gold marker bobs over the spot (the soil, the bench, the lever,
--     Barley, a display, Patty's job board), with an arrow at the screen's
--     edge while it's off your screen;
--   * the HUD button you need pulses (TOWN for the steps in town, HOME to
--     come back);
--   * ✕ hides the card (the Quests window shows it again); when the last
--     step is done the card says so, with the coins, and points at the
--     "Clear here" sign of the Land Permit the guide's XP brought.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Guide = require(Shared.Config.Guide)
local GuideRules = require(Shared.GuideRules)
local BarnRules = require(Shared.BarnRules)
local LandRules = require(Shared.LandRules)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local Store = require(Shared.Config.Store)
local StoreLayout = require(Shared.StoreLayout)
local WarehouseRules = require(Shared.WarehouseRules)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer
local GuideAction = Remotes.func("GuideAction")

local GuideController = {}

local function send(action: string)
	task.spawn(function()
		local result = GuideAction:InvokeServer(action)
		if not result.ok then
			local text = Reasons(result.reason)
			if text then
				UI.toast(text, "Error", 2.5)
			end
		end
	end)
end
GuideController.show = function()
	send("Show")
end

------------------------------------------------------------------------
-- The card: a clipboard (a wooden board, its clip, a cream sheet)

local card = make("Frame", {
	Name = "FarmGuide", AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromRGB(150, 104, 62), Visible = false, ZIndex = 5, Parent = UI.screen,
}, { UI.corner(8), UI.stroke(UI.SEAM, 3) })
local sheet = make("Frame", {
	Position = UDim2.fromOffset(6, 12), Size = UDim2.new(1, -12, 1, -18), BackgroundColor3 = C.cream, ZIndex = 6, Parent = card,
}, { UI.corner(4), UI.stroke(C.stitch, 1.5) })
make("Frame", { -- the clip
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(70, 16),
	BackgroundColor3 = Color3.fromRGB(184, 190, 196), ZIndex = 8, Parent = card,
}, { UI.corner(5), UI.stroke(Color3.fromRGB(96, 100, 106), 2) })
local title = UI.label({
	Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -60, 0, 18), Font = UI.HEAD, TextSize = 14, TextColor3 = C.red,
	Text = "📋 FARM GUIDE", ZIndex = 7, Parent = sheet,
})
local count = UI.label({
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -32, 0, 8), Size = UDim2.fromOffset(40, 18), Font = UI.HEAD, TextSize = 14,
	TextColor3 = C.soil, TextXAlignment = Enum.TextXAlignment.Right, Text = "", ZIndex = 7, Parent = sheet,
})
local close = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 5), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = C.red,
	Font = UI.HEAD, Text = "X", TextSize = 13, TextColor3 = C.cream, AutoButtonColor = false, ZIndex = 8, Parent = sheet,
}, { UI.corner(11), UI.stroke(UI.SEAM, 1.5) })
local stepText = UI.fit(UI.label({
	Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 26), Font = UI.HAND, TextSize = 24, TextColor3 = C.ink,
	Text = "", ZIndex = 7, Parent = sheet,
}), 14) -- (a long step shrinks to fit)
local hintText = UI.label({
	Position = UDim2.fromOffset(10, 54), Size = UDim2.new(1, -20, 0, 34), Font = UI.BODY, TextSize = 14, TextColor3 = C.ink,
	TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Text = "", ZIndex = 7, Parent = sheet,
})
local boxes = make("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -7), Size = UDim2.new(1, -20, 0, 12), BackgroundTransparency = 1, ZIndex = 7, Parent = sheet,
}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
local boxList = {}
for i = 1, #Guide.STEPS do
	boxList[i] = make("Frame", {
		Size = UDim2.new(1 / #Guide.STEPS, -4, 1, 0), BackgroundColor3 = C.kraft, LayoutOrder = i, ZIndex = 7, Parent = boxes,
	}, { UI.corner(3), UI.stroke(C.soil, 1) })
end
local gotIt, gotItButton = UI.button({ -- (beside the coins, so the line under them has the card's width)
	text = "Got it", kind = "green", size = UDim2.fromOffset(92, 28), anchor = Vector2.new(1, 0), position = UDim2.new(1, -8, 0, 28),
	textSize = 15, zIndex = 8, parent = sheet,
})
gotIt.Visible = false

UI.onLayout(function()
	local width = if UI.compact then 230 else 272
	card.Size = UDim2.fromOffset(width, if UI.compact then 112 else 124)
	-- (on the right, under the alerts and over the context stamp)
	card.Position = UDim2.new(1, -14, 0, if UI.compact then 64 else 150)
	hintText.TextSize = if UI.compact then 13 else 14
	stepText.UITextSizeConstraint.MaxTextSize = if UI.compact then 21 else 24
end)

------------------------------------------------------------------------
-- The marker: a gold arrow bobbing over the spot, its word under it

local anchor = make("Part", {
	Name = "GuideMarker", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one,
})
local billboard = make("BillboardGui", {
	Size = UDim2.fromOffset(120, 74), StudsOffsetWorldSpace = Vector3.new(0, 5, 0), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 2000,
	Enabled = false, Parent = anchor,
})
local bob = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = billboard })
local disc = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = C.gold,
	Font = UI.HEAD, Text = "↓", TextSize = 28, TextColor3 = UI.SEAM, Parent = bob,
}, { UI.corner(20), UI.stroke(UI.SEAM, 3) })
local word = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(120, 24), BackgroundTransparency = 1,
	Font = UI.HEAD, Text = "", TextSize = 18, TextColor3 = C.cream, TextStrokeColor3 = UI.SEAM, TextStrokeTransparency = 0, Parent = bob,
})

-- The arrow at the screen's edge while the spot is off your screen
-- (drawn: a shaft and two barbs; the whole thing turns to the spot).
local edge = make("Frame", {
	Name = "GuideArrow", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(50, 50), BackgroundColor3 = C.gold, Visible = false, ZIndex = 4, Parent = UI.screen,
}, { UI.corner(25), UI.stroke(UI.SEAM, 3) })
local edgeHead = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(34, 34),
	BackgroundTransparency = 1, ZIndex = 5, Parent = edge })
make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.42, 0.5), Size = UDim2.fromOffset(20, 6), BackgroundColor3 = UI.SEAM,
	BorderSizePixel = 0, ZIndex = 5, Parent = edgeHead }, { UI.corner(3) })
for _, turn in { 40, -40 } do
	make("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.84, 0, 0.5, if turn > 0 then -4 else 4), Size = UDim2.fromOffset(14, 6),
		Rotation = turn, BackgroundColor3 = UI.SEAM, BorderSizePixel = 0, ZIndex = 6, Parent = edgeHead }, { UI.corner(3) })
end

------------------------------------------------------------------------
-- Where each step's marker goes

local function plot(): number
	return player:GetAttribute("Plot") or 0
end

local function inTown(): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and Vector3.new(root.Position.X, 0, root.Position.Z).Magnitude < PlotLayout.TOWN.radius + 40
end

local function stage(state): number
	return WarehouseRules.level(state.warehouse.level).stage or 1
end

local function benchWorld(state): Vector3
	return PlotLayout.toWorld(plot(), PlotLayout.WAREHOUSES[stage(state)].bench)
end

-- The tile nearest you that `wanted(tile, planted)` says yes to (so standing
-- on one, the marker's over your own feet).
local function tileWhere(state, wanted): Vector3?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local best, bestDistance = nil, math.huge
	for tile = 1, 64 do
		if LandRules.isTileOpen(state.land, tile) and wanted(tile, state.field[tostring(tile)]) then
			local at = PlotLayout.tileWorld(plot(), tile)
			local distance = if root then (at - root.Position).Magnitude else tile
			if distance < bestDistance then
				best, bestDistance = at, distance
			end
		end
	end
	return best
end

local function planted(_, tile)
	return tile ~= nil
end

local function ripe(_, tile)
	return tile ~= nil and tile.progress >= 1
end

-- With nothing in the barn: where your next crops are (ripe ones to pick
-- first, else seeds to plant, else ones still growing), and what to say.
local function growMore(state, then_: string): (Vector3?, string, string)
	local at = tileWhere(state, ripe)
	if at then
		return at, "Harvest", `Harvest your ripe crops first, then {then_}.`
	end
	local seeds = 0
	for _, count in state.inventory.seeds do
		seeds += count
	end
	if seeds > 0 then
		return tileWhere(state, function(_, tile)
			return tile == nil
		end), "Plant", `Plant your seeds and harvest them, then {then_}.`
	end
	return tileWhere(state, planted), "Wait", `Your crops are growing: when they're ripe, harvest them, then {then_}.`
end

local function firstDisplay(state): Vector3?
	local storeStage = StoreLayout.level(state.store.level).stage
	local best, bestId = nil, nil
	for id, entry in state.store.layout do
		if entry.slots and #entry.slots > 0 and (not bestId or tonumber(id) < bestId) then
			best, bestId = entry, tonumber(id)
		end
	end
	return best and PlotLayout.storeItemFrame(plot(), best, storeStage).Position
end

-- The spot behind your first till (where you serve from), and whether
-- anything's on display (shoppers only come to a store with something out).
local function tillSpot(state): (Vector3?, boolean)
	local best, bestId = nil, nil
	local stocked = false
	for id, entry in state.store.layout do
		local def = Store.ITEMS[entry.item]
		if def and def.staffed and (not bestId or (tonumber(id) or 0) < bestId) then
			best, bestId = entry, tonumber(id) or 0
		end
		for _, slot in entry.slots or {} do
			if (slot.units or 0) > 0 then
				stocked = true
			end
		end
	end
	local cell = best and StoreLayout.behind(best)[1]
	return cell and PlotLayout.storeWorld(plot(), cell[1], cell[2], PlotLayout.PLOT.store.floor + 2.5), stocked
end

-- (where, the marker's word, the hint, the HUD button to pulse) for a step.
local function target(step, state): (Vector3?, string, string, string?)
	local where = step.where
	local hint = step.hint
	local town = where == "barley" or where == "jobboard"
	if town and not inTown() then
		return nil, "", hint, "Town"
	elseif not town and inTown() then
		return nil, "", hint, "Home"
	end
	if where == "soil" then
		return tileWhere(state, function(_, tile)
			return tile == nil
		end) or tileWhere(state, planted), "Plant", hint, nil
	elseif where == "seedling" then
		return tileWhere(state, function(_, tile)
			return tile ~= nil and not tile.watered and tile.progress < 1
		end) or tileWhere(state, planted), "Water", hint, nil
	elseif where == "ripe" then
		return tileWhere(state, ripe) or tileWhere(state, planted), "Harvest", hint, nil
	elseif where == "bench" then
		if BarnRules.units(state.inventory) == 0 then
			local at, label, text = growMore(state, "pack them at the Packing Shed")
			return at, label, text, nil
		end
		return benchWorld(state), "Pack here", hint, nil
	elseif where == "lever" then
		-- (the crate goes on the truck first, then the lever)
		local dock = PlotLayout.WAREHOUSES[stage(state)].docks[1]
		local bed = state.warehouse.beds[1] or {}
		if #bed == 0 then
			return PlotLayout.toWorld(plot(), PlotLayout.loadLocal(dock)), "Load here", "Carry your crate to the truck and press Load, then pull the lever.", nil
		end
		return PlotLayout.toWorld(plot(), PlotLayout.leverLocal(dock)), "Pull the lever", "Pull the lever to send it: the price locks now.", nil
	elseif where == "barley" then
		return PlotLayout.frontOf("Seeds", 4), "Barley", hint, nil
	elseif where == "display" then
		if #state.store.stockroom > 0 then
			return firstDisplay(state), "Fill", "Your crate's in the store's stockroom: press Fill at a display.", nil
		elseif BarnRules.units(state.inventory) == 0 then
			local at, label, text = growMore(state, "pack a crate for 🏪 Store")
			return at, label, text, nil
		end
		return benchWorld(state), "Pack here", "Pack a crate and pick 🏪 Store, then press Fill at a display.", nil
	elseif where == "till" then
		local at, stocked = tillSpot(state)
		if not stocked then
			if #state.store.stockroom > 0 then
				return firstDisplay(state), "Fill", "Shoppers only come when something's out: press Fill at a display.", nil
			end
			return benchWorld(state), "Pack here", "Pack a crate and pick 🏪 Store, then press Fill at a display: shoppers come for it.", nil
		end
		return at, "Serve here", hint, nil
	elseif where == "jobboard" then
		return (PlotLayout.buildingFrame("HiringHall") * CFrame.new(-9.7, 5.4, 0.6)).Position, "Job board", hint, nil
	end
	return nil, "", hint, nil
end

-- The "Clear here" sign of the first block you can clear (the done card).
local function landSign(): Vector3?
	local farm = workspace:FindFirstChild("World") and workspace.World:FindFirstChild(`Plot{plot()}`, true)
	local signs = farm and farm:FindFirstChild("LandSigns", true)
	for _, sign in if signs then signs:GetChildren() else {} do
		if sign:IsA("BasePart") then
			return sign.Position
		elseif sign:IsA("Model") then
			return sign:GetPivot().Position
		end
	end
	return nil
end

------------------------------------------------------------------------
-- The pulsing HUD button

local pulsing: GuiObject? = nil
local function pulse(name: string?)
	local holder = nil
	if name then
		local travel = UI.screen:FindFirstChild("Travel")
		holder = travel and travel:FindFirstChild(name)
	end
	if holder == pulsing then
		return
	end
	if pulsing then
		for _, name in { "GuidePulse", "GuideRing" } do
			local old = pulsing:FindFirstChild(name, true)
			if old then
				old:Destroy()
			end
		end
	end
	pulsing = holder
	if holder then
		make("UIScale", { Name = "GuidePulse", Parent = holder })
		make("Frame", { -- (a gold ring round the sign, breathing with it)
			Name = "GuideRing", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 10, 1, 10),
			BackgroundTransparency = 1, ZIndex = 4, Parent = holder,
		}, { UI.corner(6), make("UIStroke", { Color = C.gold, Thickness = 3 }) })
	end
end

------------------------------------------------------------------------

local spot: Vector3? = nil
local doneUntil = 0 -- the done card shows until "Got it" (or 30 s)
local wasFinished = nil

local function draw(state)
	local guide = state.guide
	if wasFinished == false and guide.finished then
		doneUntil = os.clock() + 30
	end
	wasFinished = guide.finished
	local showingDone = guide.finished and os.clock() < doneUntil
	card.Visible = GuideRules.visible(guide) or showingDone
	gotIt.Visible = showingDone
	close.Visible = not showingDone
	for i, step in Guide.STEPS do
		boxList[i].BackgroundColor3 = if guide.done[step.id] then C.green else C.kraft
	end
	count.Text = `{GuideRules.count(guide)} / {#Guide.STEPS}`
	if showingDone then
		title.Text = "🎉 FARM GUIDE DONE"
		stepText.Text = `+{UI.formatNumber(Guide.REWARD_COINS)} coins!`
		local sign = landSign()
		hintText.Text = if sign then "You've a Land Permit too: clear the block with the \"Clear here\" sign." else "Your farm's yours now. Grow, sell, and watch for thieves!"
		boxes.Visible = false
		spot = sign
		word.Text = "Clear here"
		pulse(nil)
		return
	end
	boxes.Visible = true
	title.Text = "📋 FARM GUIDE"
	local step = GuideRules.current(guide)
	if not step or not card.Visible then
		spot = nil
		pulse(nil)
		return
	end
	local where, label, hint, button = target(step, state)
	local extra = ""
	if step.id == "Plant" then
		extra = ` ({guide.planted or 0} of {Guide.PLANT_COUNT})`
	end
	stepText.Text = step.text .. extra
	hintText.Text = hint
	spot, word.Text = where, label
	pulse(button)
end

local function update()
	local state = PlayerState.current
	if state then
		draw(state)
	end
	billboard.Enabled = spot ~= nil
	if spot then
		anchor.Position = spot
		anchor.Parent = workspace.CurrentCamera
	end
end

-- The edge arrow, while the spot's off your screen (every frame).
local function updateEdge()
	local camera = workspace.CurrentCamera
	if not spot then
		edge.Visible = false
		return
	end
	local point, onScreen = camera:WorldToViewportPoint(spot + Vector3.new(0, 5, 0))
	local size = camera.ViewportSize
	if onScreen and point.X > 40 and point.X < size.X - 40 and point.Y > 40 and point.Y < size.Y - 40 then
		edge.Visible = false
		return
	end
	local dx, dy = point.X - size.X / 2, point.Y - size.Y / 2
	if point.Z < 0 then
		dx, dy = -dx, -dy -- (behind you: the projection flips)
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
	edge.Position = UDim2.fromOffset(cx + dx * scale - inset.X, cy + dy * scale - inset.Y)
	edgeHead.Rotation = math.deg(math.atan2(dy, dx))
	edge.Visible = true
end

function GuideController.Start()
	close.Activated:Connect(function()
		send("Hide")
	end)
	gotItButton.Activated:Connect(function()
		doneUntil = 0
		update()
	end)
	PlayerState.observe(function()
		update()
	end)
	RunService.RenderStepped:Connect(function()
		updateEdge()
		local t = os.clock()
		bob.Position = UDim2.fromOffset(0, if UI.calm then 0 else math.sin(t * 4) * 6)
		if pulsing then
			local scale = pulsing:FindFirstChild("GuidePulse")
			if scale then
				local beat = if UI.calm then 1 else 0.5 + 0.5 * math.sin(t * 6) -- (Reduced motion: the ring stays, nothing throbs)
				scale.Scale = if UI.calm then 1 else 1 + 0.14 * beat
				local ring = pulsing:FindFirstChild("GuideRing")
				if ring then
					ring.UIStroke.Transparency = 0.7 * (1 - beat)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			update()
		end
	end)
end

return GuideController
