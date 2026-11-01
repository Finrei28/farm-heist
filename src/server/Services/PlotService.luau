-- Gives each player a farm when their save loads (shared/PlotRules: next to
-- a friend, else nearest the highway), spawns them at its farmhouse door,
-- and gives it back when they leave (docs/GameDesign.md §4.1). Characters
-- only load once the farm is theirs, so nobody appears in town first.
--
-- It also keeps track of which farm everyone is standing in, from their
-- trusted position (MovementService) with the zone's 1-stud hysteresis
-- (shared/ZoneRules): the player attribute InFarm = plot index, or 0. A
-- farm's store is cut out of it (a public place, §4.8): InStore = the plot
-- index of the store you're in, or 0. The HUD's location chip reads them,
-- and so does CrimeService (the bat, Suspects). Someone climbing a farm's
-- back fence (Climbing = its index) is inside it for the whole climb.
--
-- Plot models (workspace.World.Plot<n>) carry OwnerId and OwnerName while
-- someone has them; players carry Plot = their plot index.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
local PlotRules = require(ReplicatedStorage.Shared.PlotRules)
local ZoneRules = require(ReplicatedStorage.Shared.ZoneRules)

local DataService = require(script.Parent.DataService)
local MovementService = require(script.Parent.MovementService)

local PlotService = {}

local ZONE_TICK = 0.25

local owners = {} -- [index] = Player
local plots = {} -- [Player] = index
local assignedCallbacks = {}
local releasedCallbacks = {}

function PlotService.plotOf(player: Player): number?
	return plots[player]
end

function PlotService.ownerOf(index: number): Player?
	return owners[index]
end

-- Every owner and their plot: { [Player] = index }.
function PlotService.owners()
	return plots
end

function PlotService.model(index: number): Model
	return workspace.World[`Plot{index}`]
end

-- The farm a player is standing in (0 = none).
function PlotService.inFarm(player: Player): number
	return player:GetAttribute("InFarm") or 0
end

-- Where the owner appears: the farmhouse door, facing the field.
function PlotService.homeFrame(index: number): CFrame
	local at = PlotLayout.spawnWorld(index) + Vector3.new(0, 3, 0)
	return CFrame.lookAt(at, at + PlotLayout.frame(index).ZVector)
end

-- Calls callback(player, index, data) when a player gets a farm (and now
-- for anyone who has one already).
function PlotService.OnAssigned(callback)
	table.insert(assignedCallbacks, callback)
	for player, index in plots do
		local data = DataService.Get(player)
		if data then
			task.spawn(callback, player, index, data)
		end
	end
end

-- Calls callback(player, index) when a farm is given back (the owner left).
function PlotService.OnReleased(callback)
	table.insert(releasedCallbacks, callback)
end

-- The name plank on the gate arch (both faces).
local function setGateLabel(index: number, text: string)
	local arch = PlotService.model(index):FindFirstChild("GateArch")
	local plank = arch and arch:FindFirstChild("NamePlank")
	for _, gui in (plank and plank:GetChildren()) or {} do
		if gui:IsA("SurfaceGui") then
			local label = gui:FindFirstChild("Text")
			if label then
				label.Text = text
			end
		end
	end
end

local function friendPlots(player: Player): { number }
	local list = {}
	for other, index in plots do
		local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
		if ok and isFriend then
			table.insert(list, index)
		end
	end
	return list
end

local function assign(player: Player, data)
	local free = {}
	for index = 1, PlotLayout.COUNT do
		if not owners[index] then
			free[index] = true
		end
	end
	local index = PlotRules.choose(free, friendPlots(player))
	if player.Parent ~= Players then
		return
	end
	if not index then
		warn(`[PlotService] no free farm for {player.Name}`)
		player:LoadCharacter() -- (in town, without a farm)
		return
	end
	owners[index] = player
	plots[player] = index
	player:SetAttribute("Plot", index)
	local model = PlotService.model(index)
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("OwnerName", player.DisplayName)
	setGateLabel(index, `{player.DisplayName}'s farm`)
	for _, callback in assignedCallbacks do
		task.spawn(callback, player, index, data)
	end
	player:LoadCharacter()
end

local function release(player: Player)
	local index = plots[player]
	if not index then
		return
	end
	plots[player] = nil
	owners[index] = nil
	local model = PlotService.model(index)
	model:SetAttribute("OwnerId", nil)
	model:SetAttribute("OwnerName", nil)
	setGateLabel(index, `Farm {index}: for rent`)
	for _, callback in releasedCallbacks do
		task.spawn(callback, player, index)
	end
end

-- Where someone spawns instead of their door, or nil: the police porch
-- after an arrest (CrimeService sets it).
PlotService.spawnOverride = nil :: ((Player) -> CFrame?)?

-- Respawning: at your door (the first spawn too), after a death.
local function onCharacter(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not root or not humanoid then
		return
	end
	local index = plots[player]
	local frame = PlotService.spawnOverride and PlotService.spawnOverride(player)
	if frame or index then
		MovementService.Teleport(player, frame or PlotService.homeFrame(index))
	end
	humanoid.Died:Connect(function()
		task.wait(Players.RespawnTime)
		if player.Parent == Players and player.Character == character then
			player:LoadCharacter()
		end
	end)
end

-- The store building's stage on a plot (World/StoreArt keeps it on the model).
local function stageOf(index: number): number
	return PlotService.model(index):GetAttribute("StoreStage") or 1
end

-- Which zone of which plot a position is in: the one it was in (with
-- hysteresis), else the first that has it. `zoneOf(index)` gives the zone.
local function find(position: Vector3, current: number, zoneOf): number
	if current > 0 and ZoneRules.inside(zoneOf(current), position, true) then
		return current
	end
	for index = 1, PlotLayout.COUNT do
		if ZoneRules.inside(zoneOf(index), position, false) then
			return index
		end
	end
	return 0
end

local function farmZone(index: number)
	return PlotLayout.zone(index, stageOf(index))
end
local function storeZone(index: number)
	return PlotLayout.storeZone(index, stageOf(index))
end

local function updateZones()
	for _, player in Players:GetPlayers() do
		local position = MovementService.positionOf(player)
		local farm, store = 0, 0
		local climbing = player:GetAttribute("Climbing") or 0
		if climbing > 0 then
			farm = climbing -- (partway over a farm's back fence, either way: inside it, §4.12)
		elseif position then
			farm = find(position, player:GetAttribute("InFarm") or 0, farmZone)
			store = find(position, player:GetAttribute("InStore") or 0, storeZone)
		end
		if farm ~= (player:GetAttribute("InFarm") or 0) then
			player:SetAttribute("InFarm", farm)
		end
		if store ~= (player:GetAttribute("InStore") or 0) then
			player:SetAttribute("InStore", store)
		end
	end
end

function PlotService.Start()
	Players.CharacterAutoLoads = false

	DataService.OnLoaded(assign)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Players.PlayerRemoving:Connect(release)

	task.spawn(function()
		while true do
			task.wait(ZONE_TICK)
			updateZones()
		end
	end)
end

return PlotService
