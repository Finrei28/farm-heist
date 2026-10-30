-- Clearing land with Land Permits (docs/GameDesign.md §4.1b,
-- shared/LandRules). While you have a permit, every block you could open
-- gets a "Clear here" sign: its prompt (or the Barn's Land tab, through
-- the LandAction remote) pays the fee and starts clearing. Then each of the
-- block's 4 obstacles is a 2 s hold, timed here on the server. The last one
-- opens the block, with fresh soil (+25% growth for the first crop).
--
-- The prompts carry OwnerId: the client only shows them on your own farm.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Land = require(Shared.Config.Land)
local LandRules = require(Shared.LandRules)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)

local Server = ServerScriptService.Server
local ActionRemote = require(Server.Util.ActionRemote)
local Analytics = require(Server.Util.Analytics)
local Notice = require(Server.Util.Notice)
local Parts = require(Server.World.Parts)
local FarmArt = require(Server.World.FarmArt)
local DataService = require(script.Parent.DataService)
local FieldService = require(script.Parent.FieldService)
local MovementService = require(script.Parent.MovementService)
local PlotService = require(script.Parent.PlotService)

local LandService = {}

local OBSTACLE_REACH = 12
local HOLD_SLACK = 0.25 -- seconds of lag allowed off a hold

local holdStarted = {} -- [Player] = { [ProximityPrompt] = os.clock() }

local function prompt(parent: Instance, owner: Player, props): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.RequiresLineOfSight = false
	p.MaxActivationDistance = 10
	for key, value in props do
		p[key] = value
	end
	p:SetAttribute("OwnerId", owner.UserId)
	p.Parent = parent
	return p
end

local function signsFolder(index: number): Folder
	local field = PlotService.model(index).Field
	local folder = field:FindFirstChild("LandSigns")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LandSigns"
		folder.Parent = field
	end
	return folder
end

local refresh -- (below)

-- Pays for and starts clearing a block. Returns nil, or why not.
local function startClearing(player: Player, data, block: number): string?
	local index = PlotService.plotOf(player)
	if not index then
		return "NoFarm"
	end
	if PlotService.inFarm(player) ~= index then
		return "NotHome"
	end
	local ok, reason = LandRules.canClear(data.land, data.level, data.coins, block)
	if not ok then
		return reason
	end
	local number, permit = LandRules.nextPermit(data.land)
	if not DataService.SpendCoins(player, permit.fee, Analytics.SHOP, `Land_{number}`) then
		return "TooPoor"
	end
	LandRules.startClearing(data.land, block)
	Notice.send(player, `Land Permit used! Clear the {Land.OBSTACLES} obstacles on the block (hold E on each).`, "Good")
	FieldService.Render(player)
	refresh(player)
	DataService.NotifyState(player)
	return nil
end

local function obstacleCleared(player: Player, obstacle: Model)
	local data = DataService.Get(player)
	local index = PlotService.plotOf(player)
	if not data or not index or not data.land.clearing then
		return
	end
	local block = data.land.clearing.block
	obstacle:Destroy()
	local opened = LandRules.clearObstacle(data.land)
	local overgrowth = PlotService.model(index).Field:FindFirstChild(`Overgrowth{block}`)
	if overgrowth and not opened then
		overgrowth:SetAttribute("Left", data.land.clearing.obstacles)
	end
	if opened then
		for _, tile in LandRules.tilesOf(opened) do
			data.land.fresh[tostring(tile)] = true
		end
		Analytics.step(player, data, "FirstLandCleared")
		Notice.send(player, "Land cleared! Fresh soil: the first crop on it grows 25% faster.", "Good")
		FieldService.Render(player)
	end
	refresh(player)
	DataService.NotifyState(player)
end

-- Puts up the signs and prompts that match a player's land now.
function refresh(player: Player)
	local index = PlotService.plotOf(player)
	local data = DataService.Get(player)
	if not index or not data then
		return
	end
	local model = PlotService.model(index)
	local frame = PlotLayout.frame(index)
	local folder = signsFolder(index)
	folder:ClearAllChildren()

	local clearing = data.land.clearing
	if clearing then
		-- the obstacles left glow, so you can find them all
		local overgrowth = model.Field:FindFirstChild(`Overgrowth{clearing.block}`)
		if overgrowth and not overgrowth:FindFirstChildOfClass("Highlight") then
			local glow = Instance.new("Highlight")
			glow.FillColor = Parts.COLORS.hay
			glow.FillTransparency = 0.75
			glow.OutlineColor = Parts.COLORS.hay
			glow.DepthMode = Enum.HighlightDepthMode.Occluded
			glow.Parent = overgrowth
		end
		for _, obstacle in FarmArt.obstacles(model, clearing.block) do
			if obstacle.PrimaryPart and not obstacle.PrimaryPart:FindFirstChildOfClass("ProximityPrompt") then
				local p = prompt(obstacle.PrimaryPart, player, {
					Name = "ClearPrompt",
					ActionText = "Clear",
					ObjectText = obstacle.Name,
					HoldDuration = Land.OBSTACLE_HOLD,
				})
				p.PromptButtonHoldBegan:Connect(function(who)
					holdStarted[who] = holdStarted[who] or {}
					holdStarted[who][p] = os.clock()
				end)
				p.Triggered:Connect(function(who)
					local started = holdStarted[who] and holdStarted[who][p]
					if holdStarted[who] then
						holdStarted[who][p] = nil
					end
					if who ~= player or not started or os.clock() - started < Land.OBSTACLE_HOLD - HOLD_SLACK then
						return
					end
					local position = MovementService.positionOf(who)
					local part = obstacle.PrimaryPart
					if not position or not part or (position - part.Position).Magnitude > OBSTACLE_REACH then
						return
					end
					obstacleCleared(who, obstacle)
				end)
			end
		end
		return -- (one block at a time)
	end

	if LandRules.permitsLeft(data.land, data.level) < 1 then
		return
	end
	local _, permit = LandRules.nextPermit(data.land)
	for _, block in LandRules.clearable(data.land) do
		local tiles = LandRules.tilesOf(block)
		local centre = (PlotLayout.tileLocal(tiles[1]) + PlotLayout.tileLocal(tiles[4])) / 2
		local post = Parts.part({
			Name = `Sign{block}`, Size = Vector3.new(0.6, 4, 0.6),
			CFrame = frame * CFrame.new(centre + Vector3.new(0, 2.5, 0)), Color = Parts.COLORS.post, CanCollide = false,
		}, folder)
		Parts.part({
			Name = "Board", Size = Vector3.new(4, 1.8, 0.3),
			CFrame = post.CFrame * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, math.pi, 0), Color = Parts.COLORS.hay, CanCollide = false,
		}, post)
		prompt(post, player, {
			Name = "ClearLandPrompt",
			ActionText = `Clear here ({permit.fee} coins)`,
			ObjectText = `{LandRules.risk(block)}: {if LandRules.risk(block) == "Riskier" then "near the back fence" else "near the farmhouse"}`,
			HoldDuration = 0.5,
			MaxActivationDistance = 14,
		}).Triggered:Connect(function(who)
			local whoData = DataService.Get(who)
			if who ~= player or not whoData then
				return
			end
			local failure = startClearing(who, whoData, block)
			if failure == "TooPoor" then
				Notice.send(who, `Clearing this block costs {permit.fee} coins.`, "Error")
			elseif failure then
				Notice.send(who, `Can't clear that block ({failure}).`, "Error")
			end
		end)
	end
end

LandService.Refresh = refresh

local actions = {}

-- "block"
function actions.Clear(player, data, arg)
	local block = tonumber(arg)
	if not block then
		return "BadRequest"
	end
	return startClearing(player, data, block)
end

function LandService.Start()
	ActionRemote(Remotes.func("LandAction"), actions, DataService, 0.3)
	PlotService.OnAssigned(function(player)
		FieldService.Render(player) -- (so a half-cleared block has its obstacles before the prompts go on)
		refresh(player)
	end)
	PlotService.OnReleased(function(_player, index)
		signsFolder(index):ClearAllChildren()
	end)
	DataService.OnLevelUp(function(player)
		refresh(player)
	end)
	DataService.OnWiped(function(player)
		task.defer(refresh, player) -- (after FieldService has redrawn the land)
	end)
	Players.PlayerRemoving:Connect(function(player)
		holdStarted[player] = nil
	end)
end

return LandService
