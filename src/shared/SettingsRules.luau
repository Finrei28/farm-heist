-- The player's settings (the ⚙️ Settings window, docs/GameDesign.md §5.6):
-- each one's default and the values it can take. The server saves only
-- values from here (SettingsService); the client reads them through
-- client/Prefs. Saved as data.settings[key].
--   switch  true / false
--   steps   one of `steps` (the window's − and + walk along them)
local SettingsRules = {}

SettingsRules.LIST = {
	{ key = "music", kind = "switch", default = true },
	{ key = "sfx", kind = "switch", default = true },
	{ key = "ambience", kind = "switch", default = true },
	-- the red edge of the theft alarm, lightning, the TRESPASSING chip, the
	-- auction clock (0 = none of it flashes)
	{ key = "flashing", kind = "steps", default = 1, steps = { 0, 0.25, 0.5, 0.75, 1 } },
	-- no bobbing markers, pulsing buttons, blur, confetti or rising numbers
	{ key = "reducedMotion", kind = "switch", default = false },
	-- the words in windows and notes (a UIScale on them: UI.setTextScale)
	{ key = "textSize", kind = "steps", default = 1, steps = { 0.8, 0.9, 1, 1.1, 1.25 } },
	{ key = "trades", kind = "switch", default = true },
	-- hides news for everyone (Hot Crop, Barley's rare seeds, someone else's
	-- auction win, the auction's call); notes about you and your farm stay
	{ key = "quiet", kind = "switch", default = false },
}

SettingsRules.BY_KEY = {}
for _, setting in SettingsRules.LIST do
	SettingsRules.BY_KEY[setting.key] = setting
end

-- A setting's value from a save's settings (its default if it isn't there
-- or isn't a value it can take).
function SettingsRules.get(settings, key: string): any
	local setting = SettingsRules.BY_KEY[key]
	if not setting then
		return nil
	end
	local value = settings and settings[key]
	if setting.kind == "switch" then
		return if type(value) == "boolean" then value else setting.default
	end
	if type(value) == "number" and table.find(setting.steps, value) then
		return value
	end
	return setting.default
end

-- "music=0", "music=1", "flashing=0.5": the key and the value to save, or
-- nil and a reason.
function SettingsRules.parse(arg: string?): (string?, any)
	local key, text = string.match(arg or "", "^(%a+)=([%d%.]+)$")
	local setting = key and SettingsRules.BY_KEY[key]
	if not setting then
		return nil, "BadRequest"
	end
	if setting.kind == "switch" then
		if text == "1" then
			return key, true
		elseif text == "0" then
			return key, false
		end
		return nil, "BadRequest"
	end
	local value = tonumber(text)
	for _, step in setting.steps do
		if value and math.abs(step - value) < 1e-6 then
			return key, step
		end
	end
	return nil, "BadRequest"
end

-- The next step up (direction 1) or down (-1) from a value, stopping at the
-- ends.
function SettingsRules.step(key: string, value: number, direction: number): number
	local setting = SettingsRules.BY_KEY[key]
	local steps = setting.steps
	local index = table.find(steps, value) or table.find(steps, setting.default)
	return steps[math.clamp(index + direction, 1, #steps)]
end

-- What a save's settings look like with every default (a new save's).
function SettingsRules.defaults()
	local settings = {}
	for _, setting in SettingsRules.LIST do
		settings[setting.key] = setting.default
	end
	return settings
end

return SettingsRules
