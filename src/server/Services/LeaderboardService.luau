-- The leaderboards (docs/GameDesign.md §4.15; shared/LeaderRules), on the
-- boards in town (World/BoardArt): RICHEST FARMS and TOP STORES by the
-- Exchange, SHERIFF OF THE WEEK and MOST WANTED by the Police Station.
--
-- Each player's numbers go to OrderedDataStores every 2 minutes and as they
-- leave: net worth (now), and this week's arrests, crops stolen and Store
-- Rating (stores named by the week: Sheriff_W<week> ...) with all-time ones
-- for arrests and crops stolen. Every minute the server reads each board's
-- top 10 back and writes them on the boards, with the all-time #1 under
-- Sheriff and Most Wanted, and #1's photo on the wanted poster. Where the
-- stores can't be read (Studio without API access) a board ranks the
-- players in this server instead, and says so.
--
-- The other services count things as they happen: LeaderboardService.Bump
-- (arrests that count: CrimeService; crops stolen and taken home:
-- CrimeService; shoppers served: StoreService).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local LeaderRules = require(Shared.LeaderRules)
local ShopRules = require(Shared.ShopRules)

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local WRITE_EVERY = 120
local READ_EVERY = 60
local PREFIX = "FH_"

local written = {} -- [Player] = { [store name] = value last written }
local names = {} -- [userId] = name
local boards = {} -- [boardId] = { rows, footer, photo?, ink }

-- What the stores are called now (weekly ones by the week).
local function storeNames(t: number)
	local week = LeaderRules.week(t)
	return {
		NetWorth = `{PREFIX}NetWorth_v1`,
		TopStore = `{PREFIX}TopStore_W{week}`,
		Sheriff = `{PREFIX}Sheriff_W{week}`,
		Wanted = `{PREFIX}Wanted_W{week}`,
		SheriffAll = `{PREFIX}Sheriff_All`,
		WantedAll = `{PREFIX}Wanted_All`,
	}
end

-- A player's numbers for each board now (nil: not on it).
local function scoresOf(data, t: number)
	return {
		NetWorth = LeaderRules.netWorth(data),
		TopStore = LeaderRules.storeScore(data, ShopRules.stars(data.store), t),
		Sheriff = LeaderRules.thisWeek(data, "arrests", t),
		Wanted = math.floor(LeaderRules.thisWeek(data, "stolen", t)),
		SheriffAll = data.stats.arrestsCounted or 0,
		WantedAll = math.floor(data.stats.stolenValue or 0),
	}
end

-- Adds to this week's arrests, crops stolen (coins) or shoppers.
function LeaderboardService.Bump(player: Player, stat: string, amount: number)
	local data = DataService.Get(player)
	if not data or not (amount > 0) then
		return
	end
	LeaderRules.bump(data, stat, amount, os.time())
	if stat == "arrests" then
		data.stats.arrestsCounted = (data.stats.arrestsCounted or 0) + amount
	end
end

local function ordered(name: string): OrderedDataStore?
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
	return if ok then store else nil
end

-- Writes a player's numbers (only those that changed). `scores`: worked out
-- already (as their save closes), else from their save now.
local function write(player: Player, scores)
	local t = os.time()
	if not scores then
		local data = DataService.Get(player)
		if not data then
			return
		end
		scores = scoresOf(data, t)
	end
	local mine = written[player] or {}
	written[player] = mine
	local stores = storeNames(t)
	for id, value in scores do
		local name = stores[id]
		if value and value > 0 and mine[name] ~= value then
			local store = ordered(name)
			if store and pcall(store.SetAsync, store, tostring(player.UserId), value) then
				mine[name] = value
			end
		end
	end
end

local function nameOf(userId: number): string
	local here = Players:GetPlayerByUserId(userId)
	if here then
		return here.DisplayName
	end
	if not names[userId] then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		names[userId] = if ok then name else "a farmer"
	end
	return names[userId]
end

-- The top `count` of a store: { { userId, value } }, or nil if unreadable.
local function top(name: string, count: number)
	local store = ordered(name)
	if not store then
		return nil
	end
	local ok, pages = pcall(store.GetSortedAsync, store, false, count)
	if not ok then
		return nil
	end
	local list = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(list, { userId = userId, value = entry.value })
		end
	end
	return list
end

-- The players in this server, ranked by a board (when the stores can't be read).
local function local_(id: string, count: number)
	local t, list = os.time(), {}
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		local value = data and scoresOf(data, t)[id]
		if value and value > 0 then
			table.insert(list, { userId = player.UserId, value = value })
		end
	end
	table.sort(list, function(a, b)
		return a.value > b.value
	end)
	while #list > count do
		table.remove(list)
	end
	return list
end

local function find(boardId: string)
	if boards[boardId] then
		return boards[boardId]
	end
	local model = workspace.World.Town:FindFirstChild(`Board_{boardId}`)
	local gui = model and model:FindFirstChild("Face") and model.Face:FindFirstChild("Board")
	if not gui then
		return nil
	end
	boards[boardId] = { rows = gui.Rows, footer = gui.Footer, photo = gui:FindFirstChild("Photo"), ink = gui:GetAttribute("Ink") }
	return boards[boardId]
end

local function draw(boardId: string, list, footer: string)
	local board = find(boardId)
	if not board then
		return
	end
	for _, child in board.rows:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local slots = if board.photo then 8 else LeaderRules.SIZE
	for rank, entry in list do
		if rank > slots then
			break
		end
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 1 / slots, 0)
		row.BackgroundTransparency = 1
		row.LayoutOrder = rank
		for _, part in {
			{ `{rank}. {nameOf(entry.userId)}`, Enum.TextXAlignment.Left, UDim2.fromScale(0, 0), UDim2.fromScale(0.66, 1) },
			{ LeaderRules.show(boardId, entry.value, Format.number), Enum.TextXAlignment.Right, UDim2.fromScale(0.66, 0), UDim2.fromScale(0.34, 1) },
		} do
			local text = Instance.new("TextLabel")
			text.BackgroundTransparency = 1
			text.TextScaled = true
			text.Font = if rank == 1 then Enum.Font.FredokaOne else Enum.Font.PatrickHand
			text.TextColor3 = board.ink
			text.Text = part[1]
			text.TextXAlignment = part[2]
			text.Position = part[3]
			text.Size = part[4]
			text.Parent = row
		end
		row.Parent = board.rows
	end
	if #list == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0.3, 0)
		empty.BackgroundTransparency = 1
		empty.TextScaled = true
		empty.Font = Enum.Font.PatrickHand
		empty.TextColor3 = board.ink
		empty.Text = "Nobody yet this week!"
		empty.Parent = board.rows
	end
	board.footer.Text = footer
	if board.photo then
		local first = list[1]
		local image = ""
		if first then
			local ok, url = pcall(Players.GetUserThumbnailAsync, Players, first.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			image = if ok then url else ""
		end
		board.photo.Image = image
	end
end

local function refresh()
	local t = os.time()
	local stores = storeNames(t)
	local left = LeaderRules.weekLeft(t)
	local resets = `new week in {math.floor(left / 86400)} d {math.floor(left % 86400 / 3600)} h`
	for _, def in LeaderRules.BOARDS do
		local list = top(stores[def.id], LeaderRules.SIZE)
		local footer = if def.weekly then resets else "everything a farm owns, counted"
		if not list then
			list = local_(def.id, LeaderRules.SIZE)
			footer = "(this server only: the boards can't be read here)"
		elseif def.id == "Sheriff" or def.id == "Wanted" then
			local best = top(stores[def.id .. "All"], 1)
			if best and best[1] then
				footer = `all-time #1: {nameOf(best[1].userId)} ({LeaderRules.show(def.id, best[1].value, Format.number)})`
			end
		end
		draw(def.id, list, footer)
	end
end

function LeaderboardService.Start()
	-- (as a save closes: the numbers now, written after it's gone)
	DataService.BeforeRelease(function(player, data)
		local scores = scoresOf(data, os.time())
		task.spawn(function()
			write(player, scores)
			written[player] = nil
		end)
	end)
	task.spawn(function()
		task.wait(5)
		while true do
			pcall(refresh)
			task.wait(READ_EVERY)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(WRITE_EVERY)
			for _, player in Players:GetPlayers() do
				task.spawn(write, player)
			end
		end
	end)
end

return LeaderboardService
