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
local FineRules = require(Shared.FineRules)
local LandRules = require(Shared.LandRules)
local ProgressionRules = require(Shared.ProgressionRules)
local ProfileStore = require(ServerScriptService.Server.Packages.ProfileStore)

local StateChanged = Remotes.event("StateChanged")
local GetState = Remotes.func("GetState")

local SaveData = require(script.Parent.Parent.Util.SaveData)
local Analytics = require(script.Parent.Parent.Util.Analytics)
local Notice = require(script.Parent.Parent.Util.Notice)
local TEMPLATE = SaveData.TEMPLATE
local reconcile = SaveData.reconcile

local DataService = {}

local LAST_ONLINE_INTERVAL = 60

local profiles = {} -- [Player] = data
local sessions = {} -- [Player] = ProfileStore profile
local stateDirty = {} -- [Player] = true while a state sync is queued
local awaySeconds = {} -- [Player] = seconds between their last session and this one
local loadedCallbacks = {}
local levelUpCallbacks = {}
local wipedCallbacks = {}
local beforeRelease = {}
local store = nil
local shuttingDown = false

local function keyFor(player)
	return `Player_{player.UserId}`
end

local function setStat(player, name: string, value: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(name)
	if stat then
		stat.Value = value
	end
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
	SaveData.migrate(profile.Data)

	-- The session ends on leave, on shutdown, or if the save gets opened on
	-- another server (then this copy must stop being used straight away).
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		sessions[player] = nil
		awaySeconds[player] = nil
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
	-- (read now: the minute loop below moves lastOnline on once they're in)
	awaySeconds[player] = if data.lastOnline > 0 then math.max(0, os.time() - data.lastOnline) else 0

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

-- Seconds the player was away before this session (0 for a new save), for
-- offline growth and, later, the Welcome back card.
function DataService.AwaySeconds(player): number
	return awaySeconds[player] or 0
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
	setStat(player, "Coins", data.coins)
	DataService.NotifyState(player)
end

-- Adds Farm XP (shared/ProgressionRules). A level-up gets a card (with any
-- Land Permit it brings) and runs the OnLevelUp callbacks.
function DataService.AddXp(player, amount: number)
	local data = profiles[player]
	if not data or not (amount > 0) then
		return
	end
	local before, after = ProgressionRules.addXp(data, amount)
	if after ~= before then
		setStat(player, "Level", after)
		local permits = LandRules.permitsEarned(after) - LandRules.permitsEarned(before)
		Notice.send(player, `Farm Level {after}!`, "LevelUp", { level = after, permits = permits })
		for _, callback in levelUpCallbacks do
			task.spawn(callback, player, data, before, after)
		end
	end
	DataService.NotifyState(player)
end

-- Takes the share of income that pays a player's debts and returns what
-- they keep (PayoutService sets it: shared/FineRules.garnish).
DataService.Garnish = nil :: ((Player, any, number) -> number)?

-- Sales income (truck runs, your store): the coins, the last hour's
-- earnings (fines are a share of them, shared/FineRules), and sales XP when
-- the sale happens while you're playing (live), never for sales settled
-- while you were away. Someone in debt keeps half; the rest pays the owners
-- they owe (DataService.Garnish).
function DataService.Earn(player, coins: number, sku: string, live: boolean)
	local data = profiles[player]
	if not data or not (coins > 0) then
		return
	end
	FineRules.addEarnings(data.crime, os.time(), coins)
	local kept = if DataService.Garnish then DataService.Garnish(player, data, coins) else coins
	DataService.AddCoins(player, kept, Analytics.GAMEPLAY, sku)
	if live then
		DataService.AddXp(player, ProgressionRules.salesXp(coins))
	end
end

-- Calls callback(player, data, oldLevel, newLevel) after every level-up.
function DataService.OnLevelUp(callback)
	table.insert(levelUpCallbacks, callback)
end

-- Starts a player's save over (the /wipe dev command), in place, and runs
-- the OnWiped callbacks so the farm is redrawn.
function DataService.Wipe(player)
	local data = profiles[player]
	if not data then
		return
	end
	table.clear(data)
	for key, value in TEMPLATE do
		data[key] = SaveData.deepCopy(value)
	end
	SaveData.migrate(data)
	setStat(player, "Coins", data.coins)
	setStat(player, "Level", data.level)
	for _, callback in wipedCallbacks do
		task.spawn(callback, player, data)
	end
	DataService.NotifyState(player)
end

-- Calls callback(player, data) after DataService.Wipe.
function DataService.OnWiped(callback)
	table.insert(wipedCallbacks, callback)
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
		store = data.store,
		workers = data.workers,
		freeHireUsed = data.freeHireUsed,
		crew = data.crew,
		defences = data.defences,
		trusted = data.trusted,
		debts = data.crime.debts,
		rapSheet = { arrested = data.stats.timesArrested, lastArrestAt = data.crime.lastArrestAt },
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
