-- Loads, caches and saves player data, through ProfileStore
-- (Server/Packages/ProfileStore). ProfileStore session-locks each save: a
-- player's data is only ever open on one server at a time, so a quick server
-- hop can't load a stale copy (the duplication exploit trading would open).
-- It autosaves every 5 minutes, on leave and on shutdown.
--
-- Anything that must happen before a player's save closes (an automatic
-- arrest for leaving while knocked out, docs/GameDesign.md §4.12) registers
-- with DataService.BeforeRelease: those run first, then the session ends.
-- They're told when the server is shutting down (an update or a crash), when
-- nobody may be penalised for leaving.
--
-- In Studio without API access ProfileStore runs on a mock store: everything
-- works, but nothing is kept after you stop Play.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Settings = require(Shared.Config.Settings)
local ProfileStore = require(ServerScriptService.Server.Packages.ProfileStore)

local StateChanged = Remotes.event("StateChanged")
local GetState = Remotes.func("GetState")

local SaveData = require(script.Parent.Parent.Util.SaveData)
local Analytics = require(script.Parent.Parent.Util.Analytics)
local TEMPLATE = SaveData.TEMPLATE
local reconcile = SaveData.reconcile

local DataService = {}

local LAST_ONLINE_INTERVAL = 60

local profiles = {} -- [Player] = data
local sessions = {} -- [Player] = ProfileStore profile
local stateDirty = {} -- [Player] = true while a state sync is queued
local loadedCallbacks = {}
local beforeRelease = {}
local store = nil
local shuttingDown = false

local function keyFor(player)
	return `Player_{player.UserId}`
end

local function createLeaderstats(player, data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = data.level
	level.Parent = leaderstats
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.coins
	coins.Parent = leaderstats
	leaderstats.Parent = player
end

local function loadPlayer(player)
	-- Waits while another server still has this save open (it's asked to let
	-- go); gives up if the player leaves first.
	local profile = store:StartSessionAsync(keyFor(player), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		if player.Parent == Players then
			player:Kick("We couldn't load your save. Please rejoin in a moment.")
		end
		return
	end

	profile:AddUserId(player.UserId) -- GDPR: lets Roblox find the save for deletion requests
	reconcile(profile.Data, TEMPLATE)

	-- The session ends on leave, on shutdown, or if the save gets opened on
	-- another server (then this copy must stop being used straight away).
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		sessions[player] = nil
		if player.Parent == Players then
			player:Kick("Your save was opened on another server. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession() -- left while loading
		return
	end

	local data = profile.Data
	profiles[player] = data
	sessions[player] = profile

	createLeaderstats(player, data)
	Analytics.step(player, data, "Joined")
	DataService.NotifyState(player)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

-- Returns the live data table for a loaded player, or nil while loading.
function DataService.Get(player)
	return profiles[player]
end

-- The ProfileStore profile behind a player's data (MonetizationService saves
-- it right after granting a purchase), or nil while loading.
function DataService.GetProfile(player)
	return sessions[player]
end

-- Calls callback(player, data) for every player once their data has loaded.
function DataService.OnLoaded(callback)
	table.insert(loadedCallbacks, callback)
	for player, data in profiles do
		task.spawn(callback, player, data)
	end
end

-- Calls callback(player, data, shuttingDown) when a player leaves, before
-- their save closes (it must not yield). CrimeService uses it for automatic
-- arrests, which never happen while the server is shutting down.
function DataService.BeforeRelease(callback)
	table.insert(beforeRelease, callback)
end

function DataService.IsShuttingDown(): boolean
	return shuttingDown
end

-- kind and sku say what the coins were for (Util/Analytics: Analytics.SHOP,
-- GAMEPLAY or TIMED, and e.g. "TruckSale"), for the economy charts.
function DataService.AddCoins(player, amount: number, kind: string?, sku: string?)
	local data = profiles[player]
	if not data then
		return
	end
	data.coins += amount
	Analytics.coins(player, amount, data.coins, kind, sku)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if coins then
		coins.Value = data.coins
	end
	DataService.NotifyState(player)
end

-- Deducts coins if the player can afford it. Returns whether it succeeded.
function DataService.SpendCoins(player, amount: number, kind: string?, sku: string?): boolean
	local data = profiles[player]
	if not data or amount < 0 or data.coins < amount then
		return false
	end
	DataService.AddCoins(player, -amount, kind or Analytics.SHOP, sku)
	return true
end

-- The parts of a player's data their own client needs.
local function getPublicState(data)
	return {
		coins = data.coins,
		xp = data.xp,
		level = data.level,
		playSeconds = data.playSeconds,
		field = data.field,
		land = data.land,
		silo = data.silo,
		inventory = data.inventory,
		seedStock = data.seedStock,
		warehouse = data.warehouse,
		shop = data.shop,
		workers = data.workers,
		freeHireUsed = data.freeHireUsed,
		defences = data.defences,
		trusted = data.trusted,
		debts = data.crime.debts,
		guide = data.guide,
		quests = data.quests,
		streak = data.streak,
		settings = data.settings,
	}
end

-- Queues a state sync to the client. Several calls in the same frame send
-- one update.
function DataService.NotifyState(player)
	if stateDirty[player] then
		return
	end
	stateDirty[player] = true
	task.defer(function()
		stateDirty[player] = nil
		local data = profiles[player]
		if data and player.Parent then
			StateChanged:FireClient(player, getPublicState(data))
		end
	end)
end

function DataService.Start()
	store = ProfileStore.New(Settings.PROFILE_STORE_NAME, TEMPLATE)

	-- Players removed by a shutdown didn't choose to leave (§4.12).
	game:BindToClose(function()
		shuttingDown = true
	end)

	GetState.OnServerInvoke = function(player)
		local data = profiles[player]
		return data and getPublicState(data)
	end

	Players.PlayerAdded:Connect(loadPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end

	-- Penalties and loot returns first, then ending the session saves and
	-- releases the lock (ProfileStore also does this for everyone on shutdown,
	-- when no penalties apply: §4.12).
	Players.PlayerRemoving:Connect(function(player)
		local profile = sessions[player]
		if not profile then
			return
		end
		for _, callback in beforeRelease do
			local ok, err = pcall(callback, player, profile.Data, shuttingDown)
			if not ok then
				warn(`[DataService] BeforeRelease failed for {player.UserId}: {err}`)
			end
		end
		profile.Data.lastOnline = os.time()
		profile:EndSession()
	end)

	-- Play time adds up (the Sprout Shield and trading count it), and
	-- lastOnline (for offline growth) stays roughly current, so it's right
	-- even if the server shuts down without PlayerRemoving firing.
	task.spawn(function()
		while true do
			task.wait(LAST_ONLINE_INTERVAL)
			local now = os.time()
			for player, data in profiles do
				data.lastOnline = now
				data.playSeconds += LAST_ONLINE_INTERVAL
				DataService.NotifyState(player)
			end
		end
	end)
end

return DataService
