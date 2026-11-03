-- How the weather shares out (shared/WeatherRules, §4.14): lune run tools/weathershares
local Harness = require("../tests/lib/harness")
Harness.reset()
Harness.fresh()
local WeatherRules = Harness.load("WeatherRules")
local Weather = Harness.load("Config/Weather")

local T = 1_762_135_200 - 1_762_135_200 % Weather.DAY
local seen, total = {}, 0
for t = T, T + 3000 * Weather.DAY - 1, 30 do
	local id = WeatherRules.weather(t).id
	seen[id] = (seen[id] or 0) + 1
	total += 1
end
for _, id in { "Clear", "Rain", "Thunderstorm", "FrostNight", "GoldenHour", "HarvestMoon" } do
	print(string.format("%-13s %5.1f%%   a crop left out through one mutates %4.0f%%", id, 100 * (seen[id] or 0) / total,
		100 * WeatherRules.chanceOver(id, Weather.TYPES[id].length or Weather.SLOT)))
end
