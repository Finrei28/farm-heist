-- Barley's Seeds (docs/GameDesign.md §4.3). The stock comes from
-- shared/SeedStock (the same on every server, from the clock; the client
-- works it out too, for the Seed Rack and its countdown). Buying goes
-- through the SeedAction remote and needs you at the counter (trusted
-- position). A Legendary or Mythic seed coming in is announced to everyone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local BarnRules = require(Shared.BarnRules)
local Crops = require(Shared.Config.Crops)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local SeedStock = require(Shared.SeedStock)

local Server = ServerScriptService.Server
local ActionRemote = require(Server.Util.ActionRemote)
local Analytics = require(Server.Util.Analytics)
local Notice = require(Server.Util.Notice)
local DataService = require(script.Parent.DataService)
local MovementService = require(script.Parent.MovementService)

local SeedShopService = {}

SeedShopService.COUNTER_REACH = 18 -- studs from Barley's counter you can buy from
local MAX_BUY = 50

local counter: BasePart? = nil

local actions = {}

-- "cropId|count"
function actions.Buy(player, data, arg)
	local cropId, countText = string.match(arg or "", "^(%w+)|(%d+)$")
	local count = tonumber(countText)
	local crop = Crops.ById[cropId]
	if not crop or not count or count < 1 or count > MAX_BUY then
		return "BadRequest"
	end
	local position = MovementService.positionOf(player)
	if not counter or not position or (position - counter.Position).Magnitude > SeedShopService.COUNTER_REACH then
		return "TooFar"
	end
	local ok, reason = SeedStock.canBuy(data, cropId, count, data.level)
	if not ok then
		return reason
	end
	if not DataService.SpendCoins(player, crop.seed * count, Analytics.SHOP, `Seed_{cropId}`) then
		return "TooPoor"
	end
	SeedStock.record(data, cropId, count)
	BarnRules.addSeeds(data.inventory, cropId, count)
	Analytics.step(player, data, "FirstSeedBuy")
	return nil
end

-- "Barley just got a Moonmelon seed in!" for each rare seed in a new restock.
local function announce(index: number)
	local stock = SeedStock.stock(index)
	for _, crop in Crops.List do
		local rarity = Rarities.ById[crop.rarity]
		if rarity.order >= 5 and (stock[crop.id] or 0) > 0 then
			Notice.all(`Barley just got a {crop.name} seed in! ({rarity.id})`, "Announce")
		end
	end
end

function SeedShopService.Start()
	counter = workspace.World.Town:FindFirstChild("SeedCounter")
	if counter then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SeedRackPrompt"
		prompt.ActionText = "Seed Rack"
		prompt.ObjectText = "Barley's Seeds"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Opens", "SeedRack") -- (the client opens the window)
		prompt.Parent = counter
	else
		warn("[SeedShopService] no SeedCounter in the town")
	end

	ActionRemote(Remotes.func("SeedAction"), actions, DataService, 0.15)

	task.spawn(function()
		local last = SeedStock.index()
		while true do
			task.wait(1)
			local index = SeedStock.index()
			if index ~= last then
				last = index
				announce(index)
			end
		end
	end)
end

return SeedShopService
