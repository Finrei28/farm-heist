-- The farm's music and ambience (Config/Sounds, client/Sfx): the banjo
-- tune all the time; songbirds by day and crickets at night; rain while it
-- rains (SkyController.state). Each loop fades towards its volume, or to
-- silence when it isn't wanted or its Settings switch is off; everything
-- dips while the theft alarm's siren sounds (Sfx.duck). Every sound is
-- preloaded here when you join.
local RunService = game:GetService("RunService")

local Sfx = require(script.Parent.Parent.Sfx)
local SkyController = require(script.Parent.SkyController)

local AmbienceController = {}

local FADE = 0.6 -- how quickly a loop moves to its volume (share a second)
local DUCK = 0.3 -- volume share while ducked

local loops = {} -- [name] = Sound

-- How much of each loop is wanted right now (0–1).
local function wanted(): { [string]: number }
	local sky = SkyController.state
	local wet = if sky.weather == "Rain" or sky.weather == "Thunderstorm" then sky.weight else 0
	return {
		FarmTheme = 1,
		Birds = if sky.night then 0 else 1 - wet,
		Crickets = if sky.night then 1 - wet * 0.7 else 0,
		Rain = wet,
	}
end

function AmbienceController.Start()
	Sfx.preload()
	for _, name in { "FarmTheme", "Birds", "Crickets", "Rain" } do
		loops[name] = Sfx.loop(name)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		local step = acc
		acc = 0
		local want = wanted()
		local duck = if Sfx.ducked() then DUCK else 1
		for name, sound in loops do
			local target = Sfx.loopVolume(name) * (want[name] or 0) * duck
			sound.Volume += (target - sound.Volume) * math.min(1, step * FADE * 3)
		end
	end)
end

return AmbienceController
