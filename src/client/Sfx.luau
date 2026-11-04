-- Plays sounds from Config/Sounds (Tide Market's, for the farm):
--   Sfx.play("Plant")              a one-off, straight to you
--   Sfx.play("Bonk", part)         a one-off from a place in the world
--   Sfx.play("Plant", part, 1.05)  ...at a slightly different pitch
--   Sfx.at("Bonk", position)       from a point in the world
--   Sfx.loop("Birds")              a looping Sound (volume 0; the caller fades it)
-- Silent when the sound has no id yet, or when its Settings switch (sound
-- effects, ambience or music) is off. A one-off can't play more than once
-- per 0.06 s, so a burst of events doesn't stack into noise.
--
-- Every sound is loaded once when you join (Sfx.preload) and each play is a
-- copy of that loaded Sound, so it starts at once.
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)
local SettingsRules = require(Shared.SettingsRules)
local PlayerState = require(script.Parent.PlayerState)

local Sfx = {}

local lastPlayed = {} -- [name] = os.clock()
local templates = {} -- [name] = a loaded Sound to copy

local folder = Instance.new("Folder")
folder.Name = "SfxTemplates"
folder.Parent = SoundService

local function template(name: string): Sound?
	local existing = templates[name]
	if existing then
		return existing
	end
	local sound = Sounds[name]
	if not sound or sound.id == "" then
		return nil
	end
	local instance = Instance.new("Sound")
	instance.Name = name
	instance.SoundId = sound.id
	instance.Volume = sound.volume or 0.5
	instance.Looped = sound.loop == true
	instance.Parent = folder
	templates[name] = instance
	return instance
end

-- Loads every sound in the background, so the first play has no wait.
function Sfx.preload()
	local list = {}
	for name in Sounds do
		local instance = template(name)
		if instance then
			table.insert(list, instance)
		end
	end
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, list)
	end)
end

-- Is this kind of sound switched on in Settings? ("sfx", "ambience", "music")
function Sfx.allowed(kind: string?): boolean
	local state = PlayerState.current
	return SettingsRules.get(state and state.settings, kind or "sfx") ~= false
end

function Sfx.play(name: string, at: Instance?, pitch: number?)
	local sound = Sounds[name]
	if not sound or sound.id == "" or not Sfx.allowed(sound.kind) then
		return
	end
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < 0.06 then
		return
	end
	lastPlayed[name] = now
	local source = template(name)
	if not source then
		return
	end
	local instance = source:Clone()
	instance.Looped = false
	instance.PlaybackSpeed = pitch or 1
	if at and sound.range and (at:IsA("BasePart") or at:IsA("Attachment")) then
		instance.RollOffMode = Enum.RollOffMode.InverseTapered
		instance.RollOffMinDistance = 10
		instance.RollOffMaxDistance = sound.range
		instance.Parent = at
	else
		instance.Parent = SoundService -- (not in the world: heard the same everywhere)
	end
	instance.Ended:Connect(function()
		instance:Destroy()
	end)
	instance:Play()
	Debris:AddItem(instance, 12) -- (cleaned up even if Ended never fires)
end

-- A one-off from a point in the world (an invisible anchor that goes after).
function Sfx.at(name: string, position: Vector3, pitch: number?)
	local sound = Sounds[name]
	if not sound or sound.id == "" or not Sfx.allowed(sound.kind) then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "SfxAt"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = workspace.CurrentCamera -- (on this screen only)
	Sfx.play(name, anchor, pitch)
	Debris:AddItem(anchor, 12)
end

-- A looping Sound for this sound (playing, at volume 0), or nil if it has
-- no id. Fade it towards `Sfx.loopVolume(name)`.
function Sfx.loop(name: string): Sound?
	local sound = Sounds[name]
	if not sound or sound.id == "" then
		return nil
	end
	local source = template(name)
	local instance = if source then source:Clone() else Instance.new("Sound")
	instance.Name = name
	instance.Looped = true
	instance.Volume = 0
	instance.Parent = SoundService
	instance:Play()
	return instance
end

-- The music and ambience dip for a while (the theft alarm's siren).
local duckUntil = 0
function Sfx.duck(seconds: number)
	duckUntil = math.max(duckUntil, os.clock() + seconds)
end
function Sfx.ducked(): boolean
	return os.clock() < duckUntil
end

-- The full volume for a loop, or 0 if its Settings switch is off.
function Sfx.loopVolume(name: string): number
	local sound = Sounds[name]
	if not sound or not Sfx.allowed(sound.kind) then
		return 0
	end
	return sound.volume or 0.5
end

return Sfx
