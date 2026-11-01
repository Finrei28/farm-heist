-- The Police Desk window (docs/GameDesign.md §5.3, §4.12), opened at the desk
-- on the police porch: a case file of your debts (who you owe, how much,
-- when it's forgiven), Pay now, and your record. Half of your sales pay
-- debts off on their own; paying here is optional (PayoutService).
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crime = require(Shared.Config.Crime)
local Remotes = require(Shared.Remotes)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Reasons = require(script.Parent.Parent.Reasons)
local UI = require(script.Parent.Parent.UI)

local C = UI.C
local make = UI.make
local PoliceAction = Remotes.func("PoliceAction")

local PoliceController = {}

local MANILA = Color3.fromRGB(232, 208, 150) -- a case file folder

local panel = UI.panel("Police Desk", { accent = Color3.fromRGB(40, 64, 112), toolbar = true, width = 520, height = 380 })
panel.list.BackgroundTransparency = 0
panel.list.BackgroundColor3 = MANILA
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.list })

local function line(order: number, text: string, props)
	return UI.label({
		Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
		Font = props and props.font or UI.HAND, TextSize = props and props.size or 21, TextColor3 = props and props.color or C.ink,
		Text = text, LayoutOrder = order, ZIndex = 23, Parent = panel.list,
	})
end

local function ago(seconds: number): string
	if seconds < 3600 then
		return `{math.max(1, seconds // 60)} min ago`
	elseif seconds < 86400 then
		return `{seconds // 3600} h ago`
	end
	return `{seconds // 86400} days ago`
end

local function render()
	if not UI.isOpen(panel) then
		return
	end
	local state = PlayerState.current
	if not state then
		return
	end
	UI.clear(panel.list)
	local debts = state.debts or {}
	local total = 0
	for _, debt in debts do
		total += debt.amount
	end
	local sheet = state.rapSheet or { arrested = 0, lastArrestAt = 0 }
	panel.toolbar.Text = if sheet.arrested > 0 then `Your record: arrested {sheet.arrested} time{if sheet.arrested == 1 then "" else "s"}`
		else "Your record: clean!"
	if total <= 0 then
		line(1, "You don't owe anyone anything. 🐓 Sheriff Clucks says: keep it that way!", { size = 23 })
		line(2, "If a farmer catches you stealing, they can bonk you and arrest you. You pay a fine to them, and what you can't pay becomes a debt.", { color = C.soil })
		return
	end
	line(1, `You owe {total} coins.`, { font = UI.HEAD, size = 24, color = C.red })
	local now = os.time()
	for i, debt in debts do
		local who = debt.ownerName or "a farmer"
		local left = Crime.DEBT_EXPIRY - (now - debt.createdAt)
		line(1 + i, `• {debt.amount} coins to {who} (fined {ago(now - debt.createdAt)}; forgiven in {math.max(1, math.ceil(left / 86400))} days)`)
	end
	line(50, "Half of everything you sell goes to your debts until they're paid. Pay now to keep all your sales again.", { color = C.soil })
	local row = make("Frame", { Size = UDim2.new(1, -8, 0, 50), BackgroundTransparency = 1, LayoutOrder = 60, ZIndex = 23, Parent = panel.list },
		{ make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local payAll = math.min(total, state.coins)
	local holder, button = UI.button({ text = if payAll >= total then `Pay it all ({total})` else `Pay {payAll} now`, kind = "gold",
		size = UDim2.fromOffset(220, 46), order = 1, zIndex = 23, parent = row })
	if payAll <= 0 then
		UI.setButtonKind(holder, "cream")
		button.Text = "No coins to pay with"
	end
	button.Activated:Connect(function()
		if payAll <= 0 then
			return
		end
		local result = PoliceAction:InvokeServer("Pay", "all")
		if not result.ok then
			local text = Reasons(result.reason)
			if text then
				UI.toast(text, "Error")
			end
		end
	end)
end

function PoliceController.Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Opens") == "PoliceDesk" then
			panel.open()
		end
	end)
	panel.onOpen = render
	PlayerState.changed:Connect(render)
end

return PoliceController
