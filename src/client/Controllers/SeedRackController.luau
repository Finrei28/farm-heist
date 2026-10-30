-- Barley's Seed Rack (docs/GameDesign.md §4.3, §5.3): opens from the prompt
-- at his counter. Tabs by rarity; each seed packet shows its picture, grow
-- time, sell value, how many you can still buy this restock, its price tag
-- and Buy ×1 / ×5. Seeds above your level show locked. A chalkboard counts
-- down to the next restock. The stock is worked out here from the clock
-- (shared/SeedStock), the same way the server does.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crops = require(Shared.Config.Crops)
local GrowthRules = require(Shared.GrowthRules)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local SeedStock = require(Shared.SeedStock)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)

local C = UI.C
local make = UI.make
local player = Players.LocalPlayer
local SeedAction = Remotes.func("SeedAction")

local SeedRackController = {}

local WALK_AWAY = 26 -- studs from the counter that close the rack

local tabs, tabColors = {}, {}
for _, rarity in Rarities.List do
	table.insert(tabs, rarity.id)
	table.insert(tabColors, rarity.color:Lerp(Color3.new(1, 1, 1), 0.45))
end

local panel = UI.panel("Barley's Seeds", { tabs = tabs, tabColors = tabColors, tabWidth = 86, accent = C.green, toolbar = true, wood = true, width = 640, height = 430 })
make("UIGridLayout", {
	CellSize = UDim2.fromOffset(186, 156),
	CellPadding = UDim2.fromOffset(10, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = panel.list,
})

-- The chalkboard: the restock countdown.
local _, boardLabel = UI.chalkboard({ anchor = Vector2.new(1, 0), position = UDim2.new(1, -18, 0, panel.top - 30),
	size = UDim2.fromOffset(176, 30), zIndex = 23, parent = panel.frame })

local counter: BasePart? = nil

local function minutes(seconds: number): string
	if seconds < 60 then
		return `{seconds} s`
	elseif seconds < 3600 then
		return `{math.floor(seconds / 60)} min`
	end
	return `{math.floor(seconds / 360) / 10} h`
end

local function buy(cropId: string, count: number)
	local result = SeedAction:InvokeServer("Buy", `{cropId}|{count}`)
	if result.ok then
		local crop = Crops.ById[cropId]
		UI.toast(`+{count} {crop.name} seed{if count == 1 then "" else "s"}`, "Good", 2)
	else
		local text = Reasons(result.reason)
		if text then
			UI.toast(text, "Error", 2.5)
		end
	end
end

local function packet(crop, order: number, state)
	local rarity = Rarities.ById[crop.rarity]
	local locked = state.level < rarity.seedLevel
	local left = SeedStock.left(state, crop.id)
	-- a seed packet: crimped top, the rarity band, picture, name, facts
	local card = make("Frame", {
		Name = crop.id,
		BackgroundColor3 = C.cream,
		LayoutOrder = order,
		ZIndex = 22,
		Parent = panel.list,
	}, { UI.corner(3), UI.stroke(UI.SEAM, 2) })
	UI.crimp(card, C.cream, 14, 8)
	make("Frame", {
		Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = rarity.color, BorderSizePixel = 0, ZIndex = 22, Parent = card,
	})
	make("TextLabel", {
		Position = UDim2.fromOffset(8, 16), Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1,
		Font = UI.HEAD, Text = crop.icon or "🌱", TextSize = 36, ZIndex = 23, Parent = card,
	})
	UI.fit(UI.label({
		Position = UDim2.fromOffset(56, 16), Size = UDim2.new(1, -62, 0, 22), Font = UI.HEAD, TextSize = 18,
		TextColor3 = C.ink, Text = crop.name, ZIndex = 23, Parent = card,
	}), 11)
	UI.label({
		Position = UDim2.fromOffset(56, 38), Size = UDim2.new(1, -62, 0, 34), TextWrapped = true, Font = UI.HAND, TextSize = 17,
		TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 23, Parent = card,
		Text = `⏱ {minutes(crop.grow)}{if crop.regrow then ` · ×{GrowthRules.harvests(crop.id)} picks` else ""}\nsells for ~{UI.formatNumber(crop.value)}`,
	})
	-- the price tag on its string, and the stock
	UI.tag({ text = UI.formatNumber(crop.seed), coin = true, color = C.gold, size = UDim2.fromOffset(92, 26), position = UDim2.fromOffset(6, 76),
		textSize = 15, zIndex = 23, parent = card })
	UI.label({
		Position = UDim2.new(0, 104, 0, 76), Size = UDim2.new(1, -108, 0, 26), Font = UI.HAND, TextSize = 18,
		Text = if left == SeedStock.UNLIMITED then "always in" elseif left > 0 then `{left} left` else "sold out",
		TextColor3 = if left > 0 then C.green else C.red, ZIndex = 23, Parent = card,
	})
	if locked then
		UI.chalkboard({ text = `🔒 Farm Level {rarity.seedLevel}`, size = UDim2.new(1, -16, 0, 32), position = UDim2.fromOffset(8, 110),
			textSize = 19, zIndex = 23, parent = card })
		return
	end
	for i, count in { 1, 5 } do
		local canAfford = state.coins >= crop.seed * count
		local inStock = left >= count
		local holderButton, b = UI.button({
			text = `Buy ×{count}`, kind = if canAfford and inStock then "gold" else "cream", textSize = 15,
			size = UDim2.new(0.5, -12, 0, 36), position = UDim2.new((i - 1) * 0.5, 8, 0, 110), zIndex = 23, parent = card,
		})
		holderButton.Name = `Buy{count}`
		b.Activated:Connect(function()
			buy(crop.id, count)
		end)
	end
end

-- Rebuilds the packets, but only when something they show has changed
-- (the save syncs every minute: rebuilding then would make the rack blink).
local shown = ""
local function render(force: boolean?)
	local state = PlayerState.current
	if not state or not UI.isOpen(panel) then
		return
	end
	local signature = HttpService:JSONEncode({ panel.tab, state.coins, state.level, state.seedStock, SeedStock.index() })
	if signature == shown and not force then
		return
	end
	shown = signature
	UI.clear(panel.list)
	local order = 0
	for _, crop in Crops.List do
		if crop.rarity == panel.tab then
			order += 1
			packet(crop, order, state)
		end
	end
	panel.toolbar.Text = `You have {UI.formatNumber(state.coins)} coins · seeds go to your Barn`
end

local function tick()
	local left = SeedStock.nextAt() - workspace:GetServerTimeNow()
	boardLabel.Text = `Restock in {UI.formatTime(left)}`
end

function SeedRackController.Start()
	counter = workspace:WaitForChild("World"):WaitForChild("Town"):WaitForChild("SeedCounter")
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Opens") == "SeedRack" then
			panel.open()
		end
	end)
	panel.onOpen = function()
		render(true)
	end
	panel.onTab(function()
		render(true)
	end)
	PlayerState.changed:Connect(function()
		render()
	end)
	local lastIndex = SeedStock.index()
	task.spawn(function()
		while true do
			task.wait(0.5)
			if UI.isOpen(panel) then
				tick()
				if SeedStock.index() ~= lastIndex then
					lastIndex = SeedStock.index()
					render()
				end
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and counter and (root.Position - counter.Position).Magnitude > WALK_AWAY then
					panel.close()
				end
			end
		end
	end)
end

return SeedRackController
