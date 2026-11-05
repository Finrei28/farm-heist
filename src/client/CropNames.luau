-- How a crop's name reads in the windows: "Giant Golden Tomato" from a barn or
-- crate key, and the colour that makes a mutated one stand out on a cream card
-- (the user, 2026-11-06: "Change the text colour for mutated names so it's
-- easier to notice"; the colours are in Config/Weather). On a Giant mutated crop
-- the mutation's colour wins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BarnRules = require(Shared.BarnRules)
local Crops = require(Shared.Config.Crops)
local Weather = require(Shared.Config.Weather)

local CropNames = {}

function CropNames.of(key: string): string
	local cropId, mutation, giant = BarnRules.parse(key)
	return `{if giant then "Giant " else ""}{if mutation then mutation .. " " else ""}{Crops.ById[cropId].name}`
end

-- nil for a plain crop, which keeps the label's own colour.
function CropNames.color(key: string): Color3?
	local _, mutation, giant = BarnRules.parse(key)
	local info = mutation and Weather.MUTATIONS[mutation]
	if info then
		return info.text
	end
	return if giant then Weather.GIANT_TEXT else nil
end

return CropNames
