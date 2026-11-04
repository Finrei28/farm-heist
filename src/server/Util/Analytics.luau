-- Roblox Creator Analytics (Creator Dashboard > your game > Analytics):
--   * the onboarding funnel: how far new players get (Funnels > Onboarding),
--     each step logged once per player, ever (data.onboarded);
--   * the coin economy: where coins come from and go (Economy), logged by
--     DataService.AddCoins / SpendCoins from the reason each caller gives;
--   * progression (Progression): Farm, Warehouse and Store Levels reached;
--   * funnels (Funnels > Custom): the Robux shop (opened → a tab → the
--     purchase prompt → bought);
--   * custom events (Custom): raids, knockouts, arrests, rejected hits,
--     trades, auctions, weather bought, settings switched off.
-- Robux purchases are tracked by Roblox already. Events from Studio aren't
-- recorded. Every call is pcall'd: analytics must never break the game.
local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

-- The onboarding steps, in the order the Farm Guide meets them.
Analytics.STEPS = {
	"Joined",
	"FirstPlant",
	"FirstHarvest",
	"FirstCrate",
	"FirstDispatch",
	"FirstSeedBuy",
	"FirstShopSale",
	"FirstHire",
	"GuideDone",
	"FirstLandCleared",
}
local STEP_INDEX = {}
for index, name in Analytics.STEPS do
	STEP_INDEX[name] = index
end

-- Kinds of coin flow (Enum.AnalyticsEconomyTransactionType names).
Analytics.SHOP = "Shop" -- seeds, buildings, defences, land clearing
Analytics.GAMEPLAY = "Gameplay" -- truck and shop sales, fines received, quest rewards
Analytics.TIMED = "TimedReward" -- the daily streak

-- Logs an onboarding step the first time this player reaches it.
function Analytics.step(player: Player, data, name: string)
	local index = STEP_INDEX[name]
	if not (data and index) then
		return
	end
	data.onboarded = data.onboarded or {}
	if data.onboarded[name] then
		return
	end
	data.onboarded[name] = true
	pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, index, name)
end

-- Logs coins gained (amount > 0) or spent (amount < 0). balance: coins after.
-- kind: Analytics.SHOP / GAMEPLAY / TIMED; sku: what it was for ("TruckSale",
-- "Seed_Carrot", "Land_3", ...).
function Analytics.coins(player: Player, amount: number, balance: number, kind: string?, sku: string?)
	if amount == 0 or amount ~= amount then
		return
	end
	local flow = if amount > 0 then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
	pcall(AnalyticsService.LogEconomyEvent, AnalyticsService, player, flow, "Coins", math.abs(amount), math.max(0, balance),
		kind or Analytics.GAMEPLAY, sku or "Other")
end

-- A level reached on a ladder: "FarmLevel", "WarehouseLevel", "StoreLevel".
-- (Roblox wants the level's name too: an empty one is logged as an error,
-- seen in Studio 2026-11-04. "StoreLevel" 3 is named "Store Level 3".)
function Analytics.progress(player: Player, path: string, level: number)
	local name = `{(string.gsub(path, "(%l)(%u)", "%1 %2"))} {level}`
	pcall(function()
		AnalyticsService:LogProgressionCompleteEvent(player, path, level, name)
	end)
end

-- A step of a custom funnel (Funnels in Creator Analytics), e.g. the Robux
-- shop: 1 Opened · 2 Looked (a tab) · 3 Prompted · 4 Bought. Each visit to
-- the shop is one funnel session per player (a new one each time step 1 is
-- logged). item: what the step was about, as a custom field.
local funnelSessions = {} -- ["userId|funnel"] = session id
function Analytics.funnel(player: Player, funnel: string, step: number, stepName: string, item: string?)
	local key = `{player.UserId}|{funnel}`
	if step == 1 or not funnelSessions[key] then
		funnelSessions[key] = `{player.UserId}-{os.time()}-{math.random(1, 1e6)}`
	end
	pcall(function()
		local fields = if item then { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = item } else nil
		AnalyticsService:LogFunnelStepEvent(player, funnel, funnelSessions[key], step, stepName, fields)
	end)
end

-- A one-off event worth counting (value: optional number to sum or average).
-- Raids: StealStarted, StealDeposited, Knockout, Arrest, FledArrest,
-- HitRejected, MovementRejected.
function Analytics.event(player: Player, name: string, value: number?)
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value or 1)
end

return Analytics
