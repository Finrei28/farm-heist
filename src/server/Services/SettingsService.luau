-- The player's settings (the ⚙️ Settings window, docs/GameDesign.md §5.6),
-- saved with their data so they stick between visits. Only the settings
-- and values shared/SettingsRules lists are saved. (Dropping the Sprout
-- Shield is DefenceService's DropShield; the guide's card GuideService's.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SettingsRules = require(ReplicatedStorage.Shared.SettingsRules)

local ActionRemote = require(script.Parent.Parent.Util.ActionRemote)
local Analytics = require(script.Parent.Parent.Util.Analytics)
local DataService = require(script.Parent.DataService)

local SettingsService = {}

local ACTIONS = {}

-- arg: "music=0", "flashing=0.5", "textSize=1.25" ...
function ACTIONS.Set(player, data, arg)
	local key, value = SettingsRules.parse(arg)
	if not key then
		return value
	end
	data.settings[key] = value
	-- (how many turn the music off, want less flashing, bigger text...)
	Analytics.event(player, `Setting_{key}`, if type(value) == "boolean" then (if value then 1 else 0) else value)
	return nil
end

function SettingsService.Start()
	ActionRemote(Remotes.func("SettingsAction"), ACTIONS, DataService, 0.05)
end

return SettingsService
