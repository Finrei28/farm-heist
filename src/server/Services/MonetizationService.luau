-- Robux purchases (docs/GameDesign.md §7; Config/Monetization,
-- Config/Cosmetics, shared/RobuxRules). Tide Market's pattern, for the farm.
--
-- Game passes: checked when a player's data loads and when they buy one in
-- game. Ownership goes in the save (data.passes, so BarnRules sees the
-- Bigger Barn) and on the player as an attribute (Pass_VIP ...: VIP's
-- +10% in DataService.Earn, the gold tag, the bat).
--
-- Developer products: Roblox calls ProcessReceipt for every purchase, and
-- again (later, or on another server) until we say it was granted. So each
-- receipt's PurchaseId is stored in the save next to the reward, the save
-- is written, and only then is it reported granted: a crash before that
-- means Roblox asks again; a receipt already saved is just acknowledged.
--
-- A bought weather goes into the buyer's barn (data.weatherTokens) and
-- starts at once if it can (one at a time, never over a better weather or
-- into the scheduled Harvest Moon: RobuxRules.canStartWeather); otherwise
-- the Robux window's Start button starts it later. Nothing bought is lost.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Config.Cosmetics)
local Monetization = require(Shared.Config.Monetization)
local Remotes = require(Shared.Remotes)
local RobuxRules = require(Shared.RobuxRules)
local Weather = require(Shared.Config.Weather)
local WeatherRules = require(Shared.WeatherRules)

local Server = script.Parent.Parent
local ActionRemote = require(Server.Util.ActionRemote)
local Analytics = require(Server.Util.Analytics)
local Notice = require(Server.Util.Notice)
local YardArt = require(Server.World.YardArt)
local CrimeService = require(script.Parent.CrimeService)
local DataService = require(script.Parent.DataService)
local FieldService = require(script.Parent.FieldService)
local PlotService = require(script.Parent.PlotService)
local StoreService = require(script.Parent.StoreService)

local MonetizationService = {}

local KEEP_PURCHASE_IDS = 50 -- receipts remembered per save
local SAVE_TIMEOUT = 30 -- seconds to wait for the save after a grant
local LOAD_TIMEOUT = 20 -- seconds to wait for a buyer's save to load
local GOLD = Color3.fromRGB(242, 179, 61)

local function isVip(player: Player): boolean
	return player:GetAttribute("Pass_VIP") == true
end

------------------------------------------------------------------------
-- Looks on the farm and the character

-- The gold "⭐ VIP" tag over a VIP's head (everyone sees it).
local function tagCharacter(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("VIPTag")
	if not isVip(player) then
		if old then
			old:Destroy()
		end
		return
	end
	if old then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VIPTag"
	gui.Size = UDim2.fromOffset(78, 26)
	gui.StudsOffset = Vector3.new(0, 2.7, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(74, 50, 32) -- (dark, so the gold star and letters show)
	label.Font = Enum.Font.FredokaOne
	label.Text = "⭐ VIP"
	label.TextColor3 = GOLD
	label.TextScaled = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = head
end

-- The farm's trucks in the paint worn (or VIP Gold), and the VIP's gold
-- awning; the bat's skin.
local function applyLooks(player: Player)
	local data = DataService.Get(player)
	local index = PlotService.plotOf(player)
	if not data or not index then
		return
	end
	local model = PlotService.model(index)
	local vip = isVip(player)
	local paint = RobuxRules.worn(data, "truck", vip)
	local look = paint and Cosmetics.ById[paint].look
	local truckPaint, truckMaterial = look and look.body or nil, look and look.material or nil
	if model:GetAttribute("TruckPaint") ~= truckPaint or model:GetAttribute("TruckMaterial") ~= truckMaterial then
		model:SetAttribute("TruckPaint", truckPaint)
		model:SetAttribute("TruckMaterial", truckMaterial)
		YardArt.paintTrucks(model)
	end
	local storePaint = if vip then Cosmetics.VIP_AWNING else nil
	if model:GetAttribute("StorePaint") ~= storePaint then
		model:SetAttribute("StorePaint", storePaint)
		StoreService.Repaint(player)
	end
	CrimeService.RefreshBat(player)
end

------------------------------------------------------------------------
-- Passes

local function setPass(player: Player, data, passId: string, owned: boolean)
	data.passes[passId] = if owned then true else nil
	if player:GetAttribute(`Pass_{passId}`) == (owned or nil) then
		return
	end
	player:SetAttribute(`Pass_{passId}`, owned or nil)
	tagCharacter(player)
	applyLooks(player)
	DataService.NotifyState(player)
end

local function checkPasses(player: Player, data)
	-- (what the save last knew straight away, then Roblox's answer)
	for passId in data.passes do
		player:SetAttribute(`Pass_{passId}`, true)
	end
	for _, pass in Monetization.Passes do
		if pass.passId ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.passId)
			if ok then
				setPass(player, data, pass.id, owns)
			else
				warn(`[MonetizationService] Couldn't check {pass.name} for {player.Name}: {owns}`)
			end
		elseif not RunService:IsStudio() then
			setPass(player, data, pass.id, false) -- (not on sale: nobody has it)
		end
	end
end

------------------------------------------------------------------------
-- Weather for the server

local function clearWeather()
	for _, key in { "WeatherForce", "WeatherForceUntil", "WeatherForceFrom", "WeatherBoughtBy" } do
		ReplicatedStorage:SetAttribute(key, nil)
	end
end

-- Starts a weather the player has in their barn: nil, or why not.
local function startWeather(player: Player, data, weatherId: string): string?
	if not Weather.TYPES[weatherId] or weatherId == "Clear" then
		return "BadRequest"
	end
	if not (data.weatherTokens and (data.weatherTokens[weatherId] or 0) > 0) then
		return "NoWeather"
	end
	local t = WeatherRules.now()
	-- (a bought weather that's over leaves the attributes behind: clear them)
	if (ReplicatedStorage:GetAttribute("WeatherForceUntil") or 0) <= t then
		clearWeather()
	end
	local why = RobuxRules.canStartWeather(weatherId, WeatherRules.weather(t), t, WeatherRules.nextMoon(t))
	if why then
		return why
	end
	RobuxRules.takeToken(data, weatherId)
	ReplicatedStorage:SetAttribute("WeatherForce", weatherId)
	ReplicatedStorage:SetAttribute("WeatherForceFrom", t)
	ReplicatedStorage:SetAttribute("WeatherForceUntil", t + Monetization.WEATHER_SECONDS)
	ReplicatedStorage:SetAttribute("WeatherBoughtBy", player.DisplayName)
	local product = Monetization.weatherProduct(weatherId)
	local kind = Weather.TYPES[weatherId]
	-- (the sky's own note says what the weather does: this says who to thank)
	Notice.all(`{kind.icon} {player.DisplayName} bought a {product and product.name or kind.name} for everyone! ({Monetization.WEATHER_SECONDS // 60} minutes)`, "Announce")
	Analytics.event(player, `WeatherStarted_{weatherId}`)
	return nil
end

------------------------------------------------------------------------
-- Products

local function grant(player: Player, data, product)
	local reward = product.grant
	if reward.weather then
		RobuxRules.addToken(data, reward.weather)
		local why = startWeather(player, data, reward.weather)
		if why then
			Notice.send(player, `Thanks! Your {product.name} is in your barn: it can't start right now ({if why == "MoonSoon" or why == "MoonNow" then "the Harvest Moon" else "another weather is on"}). Start it from the Robux window.`, "Good")
		end
	elseif reward.boostSeconds then
		RobuxRules.addBoost(data, reward.boostSeconds)
		Notice.send(player, `🚀 Thanks! Your field grows ×{Monetization.BOOST} as fast for {math.ceil(data.boostLeft / 60)} minutes of play.`, "Good")
		FieldService.Render(player)
	elseif reward.cosmetic then
		local item = Cosmetics.ById[reward.cosmetic]
		if RobuxRules.unlock(data, reward.cosmetic) then
			RobuxRules.equip(data, item.kind, item.id, isVip(player)) -- (worn straight away)
			Notice.send(player, `{item.icon} Thanks! The {item.name} is yours, and on. (Robux > Style to change it)`, "Good")
			applyLooks(player)
		else
			-- bought twice (two prompts open at once): the Robux are spent,
			-- so some Growth Boost instead of nothing
			RobuxRules.addBoost(data, Monetization.BOOST_SECONDS)
			Notice.send(player, `You already had the {item.name}, so here's {Monetization.BOOST_SECONDS // 60} minutes of Growth Boost instead.`, "Good")
			FieldService.Render(player)
		end
	end
	DataService.NotifyState(player)
end

local function waitForProfile(player: Player)
	local deadline = os.clock() + LOAD_TIMEOUT
	while player.Parent == Players and os.clock() < deadline do
		local profile = DataService.GetProfile(player)
		if profile and DataService.Get(player) then
			return profile
		end
		task.wait(0.5)
	end
	return nil
end

-- Waits until the save has been written (true), or gives up (false).
local function saveNow(profile): boolean
	local saved = false
	local connection = profile.OnAfterSave:Connect(function()
		saved = true
	end)
	profile:Save()
	local deadline = os.clock() + SAVE_TIMEOUT
	while not saved and profile:IsActive() and os.clock() < deadline do
		task.wait(0.2)
	end
	connection:Disconnect()
	return saved
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local product = Monetization.ProductsByProductId[info.ProductId]
	if not player or not product then
		if not product then
			warn(`[MonetizationService] Receipt for unknown product {info.ProductId}: add its id to Config/Monetization.`)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = waitForProfile(player)
	if not profile or not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = profile.Data
	if table.find(data.purchaseIds, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- (already given)
	end
	grant(player, data, product)
	table.insert(data.purchaseIds, info.PurchaseId)
	while #data.purchaseIds > KEEP_PURCHASE_IDS do
		table.remove(data.purchaseIds, 1)
	end
	Analytics.funnel(player, "RobuxShop", 4, "Bought", product.id)
	return if saveNow(profile) then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

------------------------------------------------------------------------
-- The Robux window's actions

local ACTIONS = {}

-- Start a weather from your barn.
function ACTIONS.StartWeather(player, data, arg)
	return startWeather(player, data, arg or "")
end

-- "bat|GoldenBat", "truck|" (the plain one)
function ACTIONS.Equip(player, data, arg)
	local kind, id = string.match(arg or "", "^(%a+)|(%w*)$")
	if not kind then
		return "BadRequest"
	end
	local why = RobuxRules.equip(data, kind, if id == "" then nil else id, isVip(player))
	if why then
		return why
	end
	applyLooks(player)
	return nil
end

-- The shop's funnel in Creator Analytics (the RobuxFunnel remote):
-- "Opened", "Tab:<name>", or "Prompt:<item>" (the purchase prompt shown).
-- The receipt logs "Bought". A few a second at most per player.
local funnelAt = {} -- [Player] = os.clock() of the last note
local function funnelNote(player: Player, arg)
	if typeof(arg) ~= "string" or os.clock() - (funnelAt[player] or 0) < 0.1 then
		return
	end
	funnelAt[player] = os.clock()
	local step, item = string.match(arg, "^(%a+):?([%w_]*)$")
	if step == "Opened" then
		Analytics.funnel(player, "RobuxShop", 1, "Opened")
	elseif step == "Tab" and item ~= "" then
		Analytics.funnel(player, "RobuxShop", 2, "Looked", item)
	elseif step == "Prompt" and (Monetization.ProductsById[item] or Monetization.PassesById[item]) then
		Analytics.funnel(player, "RobuxShop", 3, "Prompted", item)
	end
end

-- Studio only: an item with no id yet "bought" without a purchase, so the
-- window can be tried before the Creator Dashboard is set up.
function ACTIONS.DevBuy(player, data, arg)
	if not RunService:IsStudio() then
		return "BadRequest"
	end
	local pass = Monetization.PassesById[arg or ""]
	if pass then
		setPass(player, data, pass.id, true)
		Notice.send(player, `{pass.icon} (Studio) You have {pass.name} now.`, "Good")
		return nil
	end
	local product = Monetization.ProductsById[arg or ""]
	if not product then
		return "BadRequest"
	end
	grant(player, data, product)
	return nil
end

-- Dev commands (DevCommandService): a pass on or off, a product's reward.
function MonetizationService.DevSetPass(player: Player, passId: string, owned: boolean): boolean
	local data = DataService.Get(player)
	if not data or not Monetization.PassesById[passId] then
		return false
	end
	setPass(player, data, passId, owned)
	return true
end

function MonetizationService.DevGrant(player: Player, productId: string): boolean
	local data = DataService.Get(player)
	local product = Monetization.ProductsById[productId]
	if not data or not product then
		return false
	end
	grant(player, data, product)
	return true
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	ActionRemote(Remotes.func("RobuxAction"), ACTIONS, DataService, 0.3)
	Remotes.event("RobuxFunnel").OnServerEvent:Connect(funnelNote)
	Players.PlayerRemoving:Connect(function(player)
		funnelAt[player] = nil
	end)

	DataService.OnLoaded(function(player, data)
		task.spawn(checkPasses, player, data)
		player.CharacterAdded:Connect(function()
			task.defer(tagCharacter, player)
		end)
		tagCharacter(player)
	end)
	PlotService.OnAssigned(function(player)
		task.defer(applyLooks, player)
	end)
	PlotService.OnReleased(function(_player, index)
		local model = PlotService.model(index)
		model:SetAttribute("TruckPaint", nil)
		model:SetAttribute("TruckMaterial", nil)
		model:SetAttribute("StorePaint", nil)
		YardArt.paintTrucks(model)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local data = DataService.Get(player)
		for _, pass in Monetization.Passes do
			if pass.passId == passId and data then
				setPass(player, data, pass.id, true)
				Notice.send(player, `{pass.icon} Thanks for buying {pass.name}! {table.concat(pass.perks, " · ")}.`, "Good")
				Analytics.funnel(player, "RobuxShop", 4, "Bought", pass.id)
			end
		end
	end)

	-- a bought weather that has ended: its attributes go (the schedule's back)
	task.spawn(function()
		while true do
			task.wait(5)
			local untilAt = ReplicatedStorage:GetAttribute("WeatherForceUntil")
			if untilAt and untilAt <= WeatherRules.now() and ReplicatedStorage:GetAttribute("WeatherBoughtBy") then
				clearWeather()
			end
		end
	end)
end

return MonetizationService
