-- The farm's music and ambience (Config/Sounds, client/Sfx): the banjo tune
-- out of doors in town and nowhere else (the user, 2026-11-05: "Have the theme
-- music play only in town while outside."); a short spell of songbirds by
-- day or crickets at night every minute or two, not all the time (the user,
-- 2026-11-05: "way too often and can be annoying"), only out of doors; rain
-- while it rains (SkyController.state), quieter and muffled from inside a
-- building, as it is in real life. Each loop fades towards its volume, or to
-- silence when it isn't wanted or its Settings switch is off; everything
-- dips while the theft alarm's siren sounds (Sfx.duck). Every sound is
-- preloaded here when you join.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlotLayout = require(ReplicatedStorage:WaitForChild("Shared").PlotLayout)

local Sfx = require(script.Parent.Parent.Sfx)
local RoofController = require(script.Parent.RoofController)
local SkyController = require(script.Parent.SkyController)

local AmbienceController = {}

local FADE = 0.6 -- how quickly a loop moves to its volume (share a second)
local DUCK = 0.3 -- volume share while ducked
local NATURE_FADE = 0.5 -- the birds and crickets come and go slowly
local SPELL = { 10, 16 } -- seconds they sing for ...
local QUIET = { 60, 120 } -- ... and the seconds of quiet between
local INDOOR_EASE = 3 -- how quickly the sound changes as you go in or out (share a second)
local RAIN_INDOORS = 0.55 -- the rain's volume share from inside ...
local RAIN_MID, RAIN_HIGH = -12, -32 -- ... and what the walls take off it (dB): the patter goes, the drum on the roof stays

local player = Players.LocalPlayer
local loops = {} -- [name] = Sound
local rng = Random.new()
local indoors = 0 -- 0 out of doors, 1 inside: eased, so nothing jumps at the door
local rainMuffle: EqualizerSoundEffect? = nil
local singing = false
local changeAt = os.clock() + rng:NextNumber(20, 50) -- (not the moment you join)

-- 1 during a spell of birdsong or crickets, 0 in the quiet between.
local function nature(): number
	local t = os.clock()
	if t >= changeAt then
		singing = not singing
		local range = if singing then SPELL else QUIET
		changeAt = t + rng:NextNumber(range[1], range[2])
	end
	return if singing then 1 else 0
end

-- Whether you're out of doors in town (not on a farm, not in a store or a
-- town building).
local function outdoorsInTown(): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (player:GetAttribute("InFarm") or 0) == 0 and (player:GetAttribute("InStore") or 0) == 0
		and PlotLayout.outdoorsInTown(root.Position)
end

-- Whether you're inside a building: a store, a warehouse, one of the town's.
local function inside(): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (RoofController.indoors() or PlotLayout.inTownBuilding(root.Position))
end

-- How much of each loop is wanted right now (0–1).
local function wanted(): { [string]: number }
	local sky = SkyController.state
	local wet = if sky.weather == "Rain" or sky.weather == "Thunderstorm" then sky.weight else 0
	local spell = nature() * (1 - indoors)
	return {
		FarmTheme = if outdoorsInTown() then 1 else 0,
		Birds = if sky.night then 0 else (1 - wet) * spell,
		Crickets = if sky.night then (1 - wet * 0.7) * spell else 0,
		Rain = wet * (1 - (1 - RAIN_INDOORS) * indoors),
	}
end

function AmbienceController.Start()
	Sfx.preload()
	for _, name in { "FarmTheme", "Birds", "Crickets", "Rain" } do
		loops[name] = Sfx.loop(name)
	end
	if loops.Rain then
		local muffle = Instance.new("EqualizerSoundEffect")
		muffle.LowGain, muffle.MidGain, muffle.HighGain = 0, 0, 0
		muffle.Parent = loops.Rain
		rainMuffle = muffle
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		local step = acc
		acc = 0
		indoors += ((if inside() then 1 else 0) - indoors) * math.min(1, step * INDOOR_EASE)
		if rainMuffle then
			rainMuffle.MidGain, rainMuffle.HighGain = RAIN_MID * indoors, RAIN_HIGH * indoors
		end
		local want = wanted()
		local duck = if Sfx.ducked() then DUCK else 1
		for name, sound in loops do
			local target = Sfx.loopVolume(name) * (want[name] or 0) * duck
			local rate = if name == "Birds" or name == "Crickets" then NATURE_FADE else FADE * 3
			sound.Volume += (target - sound.Volume) * math.min(1, step * rate)
		end
	end)
end

return AmbienceController
