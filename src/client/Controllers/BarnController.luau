-- The Barn window (docs/GameDesign.md §4.5, §5.3), from the side bar:
--   Crops: what you've harvested, stacked, with the capacity bar
--   Seeds: your seed packets
--   Land:  the 4×4 block map (farmhouse at the bottom, back fence at the
--          top), Land Permits waiting, and which blocks one can go on
--          (Safer / Riskier), each with a Clear button.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BarnRules = require(Shared.BarnRules)
local Crops = require(Shared.Config.Crops)
local Land = require(Shared.Config.Land)
local LandRules = require(Shared.LandRules)
local MarketPrice = require(Shared.MarketPrice)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)
local HudController = require(script.Parent.HudController)

local C = UI.C
local make = UI.make
local LandAction = Remotes.func("LandAction")

local BarnController = {}

local panel = UI.panel("Barn", { tabs = { "Crops", "Seeds", "Land" }, accent = C.red, toolbar = true, width = 560, height = 400 })
local listLayout = make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.list })

-- A crate label: a stencilled name, a handwritten note, the count stamped
-- on the right, a band in the item's colour down the left.
local function row(order: number, icon: string, title: string, detail: string, right: string, color: Color3?)
	local frame = make("Frame", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = C.cream,
		LayoutOrder = order,
		ZIndex = 22,
		Parent = panel.list,
	}, { UI.corner(3), UI.stroke(UI.SEAM, 2) })
	make("Frame", { Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = color or C.soil, BorderSizePixel = 0, ZIndex = 23, Parent = frame })
	make("TextLabel", {
		Position = UDim2.fromOffset(14, 5), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1,
		Font = UI.HEAD, Text = icon, TextSize = 28, ZIndex = 23, Parent = frame,
	})
	UI.label({ Position = UDim2.fromOffset(60, 4), Size = UDim2.new(1, -170, 0, 22), Font = UI.HEAD, TextSize = 17, Text = string.upper(title), ZIndex = 23, Parent = frame })
	UI.fit(UI.label({ Position = UDim2.fromOffset(60, 26), Size = UDim2.new(1, -170, 0, 20), Font = UI.HAND, TextSize = 18, Text = detail, ZIndex = 23, Parent = frame }), 12)
	local count = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(76, 32),
		BackgroundColor3 = C.kraft, Rotation = -4, ZIndex = 23, Parent = frame,
	}, { UI.corner(4), UI.stroke(C.red, 2) })
	UI.label({
		Size = UDim2.fromScale(1, 1), Font = UI.HEAD, TextSize = 19, TextColor3 = C.red, TextXAlignment = Enum.TextXAlignment.Center,
		Text = right, ZIndex = 24, Parent = count,
	})
	count.Visible = right ~= ""
	return frame
end

local function cropsTab(state)
	local inventory = state.inventory
	local units, capacity = BarnRules.units(inventory), BarnRules.capacity(state.silo)
	panel.toolbar.Text = `📦 {units} / {capacity} crops{if units >= capacity then "  ·  Barn full!" else ""}`
	local keys = {}
	for key in inventory.crops do
		table.insert(keys, key)
	end
	table.sort(keys)
	if #keys == 0 then
		row(1, "🧺", "Nothing here yet", "Harvest ripe crops and they come straight to the barn.", "", C.kraft)
		return
	end
	for i, key in keys do
		local cropId, mutation, giant = BarnRules.parse(key)
		local crop = Crops.ById[cropId]
		if crop then
			local name = `{if giant then "Giant " else ""}{if mutation then mutation .. " " else ""}{crop.name}`
			row(i, crop.icon or "🌱", name, `{crop.rarity} · the truck pays {UI.formatNumber(MarketPrice.price(cropId, workspace:GetServerTimeNow()))} each now · pack it at the Packing Shed`,
				`×{inventory.crops[key]}`, Rarities.ById[crop.rarity].color)
		end
	end
end

local function seedsTab(state)
	local seeds = state.inventory.seeds
	local ids = {}
	for cropId, count in seeds do
		if count > 0 and Crops.ById[cropId] then
			table.insert(ids, cropId)
		end
	end
	table.sort(ids, function(a, b)
		return table.find(Crops.List, Crops.ById[a]) < table.find(Crops.List, Crops.ById[b])
	end)
	panel.toolbar.Text = "🌱 Pick a packet in the hotbar, then stand on empty soil"
	if #ids == 0 then
		row(1, "🌱", "No seeds", "Barley sells them at his counter in town.", "", C.kraft)
		return
	end
	for i, cropId in ids do
		local crop = Crops.ById[cropId]
		local rarity = Rarities.ById[crop.rarity]
		local lock = if state.level < rarity.seedLevel then ` · plant from Lv {rarity.seedLevel}` else ""
		row(i, crop.icon or "🌱", crop.name, `{crop.rarity}{lock}`, `×{seeds[cropId]}`, rarity.color)
	end
end

local function landTab(state)
	local land, level = state.land, state.level
	local permits = LandRules.permitsLeft(land, level)
	local nextLevel = LandRules.nextPermitLevel(level)
	local _, permit = LandRules.nextPermit(land)
	panel.toolbar.Text = if land.clearing then `⛏ Clearing a block: {land.clearing.obstacles} obstacle(s) left`
		elseif permits > 0 then `📜 {permits} Land Permit{if permits == 1 then "" else "s"} · next clearing: {UI.formatNumber(permit.fee)} coins`
		elseif nextLevel then `Next Land Permit at Farm Level {nextLevel}`
		else "Your whole field is cleared!"
	local clearable = {}
	for _, block in LandRules.clearable(land) do
		clearable[block] = true
	end

	local map = make("Frame", {
		Size = UDim2.new(1, 0, 0, 4 * 58 + 30),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = 22,
		Parent = panel.list,
	})
	UI.label({ Size = UDim2.new(0, 160, 0, 20), Font = UI.HEAD, TextSize = 14, Text = "⬆ back fence", ZIndex = 23, Parent = map })
	UI.label({ Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(0, 160, 0, 20), Font = UI.HEAD, TextSize = 14, Text = "⬇ farmhouse", ZIndex = 23, Parent = map })
	for block = 1, Land.BLOCKS_PER_SIDE * Land.BLOCKS_PER_SIDE do
		-- as seen from the farmhouse door: column 1 (by the farmhouse) at the
		-- bottom, the back fence at the top, row 1 (the farmhouse side) on the right
		local column, rowNumber = LandRules.position(block)
		local open = LandRules.isOpen(land, block)
		local beingCleared = land.clearing and land.clearing.block == block
		local can = clearable[block] and permits > 0 and not land.clearing
		local cell = make("Frame", {
			Position = UDim2.fromOffset((Land.BLOCKS_PER_SIDE - rowNumber) * 58, 22 + (Land.BLOCKS_PER_SIDE - column) * 58),
			Size = UDim2.fromOffset(52, 52),
			BackgroundColor3 = if open then Color3.fromRGB(104, 70, 46) elseif beingCleared or can then C.gold else Color3.fromRGB(108, 154, 68),
			ZIndex = 23,
			Parent = map,
		}, { UI.corner(6), UI.stroke(C.soil, 2) })
		UI.label({
			Size = UDim2.fromScale(1, 1), Font = UI.HEAD, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = if open then C.cream else C.ink, ZIndex = 24, Parent = cell,
			Text = if open then "🌱" elseif beingCleared then "⛏" elseif can then (if LandRules.risk(block) == "Riskier" then "Riskier" else "Safer") else "🌿",
		})
		if can then
			make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 25, Parent = cell }).Activated:Connect(function()
				local result = LandAction:InvokeServer("Clear", tostring(block))
				if result.ok then
					panel.close()
				else
					local text = Reasons(result.reason)
					if text then
						UI.toast(text, "Error", 3)
					end
				end
			end)
		end
	end
	UI.label({
		Position = UDim2.fromOffset(4 * 58 + 16, 22), Size = UDim2.new(1, -(4 * 58 + 20), 0, 4 * 58 - 8),
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextSize = 14, ZIndex = 23, Parent = map,
		Text = "Land Permits come with Farm Levels. Use one on an overgrown block next to cleared land (the gold ones), "
			.. "then clear its 4 obstacles.\n\nSafer blocks sit by the farmhouse. Riskier ones are by the back fence, where thieves climb in.\n\n"
			.. "Tap a gold block, or use the yellow sign on your field.",
	})
end

local TABS = { Crops = cropsTab, Seeds = seedsTab, Land = landTab }

-- Rebuilds the tab, but only when something it shows has changed (the
-- save syncs every minute: rebuilding then would make the window blink).
local shown = ""
local function render(force: boolean?)
	local state = PlayerState.current
	if not state or not UI.isOpen(panel) then
		return
	end
	local signature = HttpService:JSONEncode({ panel.tab, state.inventory, state.land, state.level, state.coins, state.silo })
	if signature == shown and not force then
		return
	end
	shown = signature
	UI.clear(panel.list)
	listLayout.Parent = panel.list
	TABS[panel.tab](state)
end

function BarnController.Start()
	local barn = HudController.sideButton("🏚️", "Barn", 1)
	barn.Activated:Connect(panel.toggle)
	panel.onOpen = function()
		render(true)
	end
	panel.onTab(function()
		render(true)
	end)
	PlayerState.changed:Connect(function()
		render()
	end)
end

return BarnController
