-- Which plot a joining player gets (docs/GameDesign.md §4.1): a free plot
-- next to a friend who's already here, otherwise the free plot nearest the
-- highway (the north gap, where you drive in from the City), so a part-full
-- server keeps its farms together. tests/plot.test.luau.
local PlotLayout = require(script.Parent.PlotLayout)

local PlotRules = {}

-- Degrees from the highway (north): plots 1 and 8 are nearest.
function PlotRules.highwayDistance(index: number): number
	local angle = PlotLayout.angle(index) % 360
	return math.min(angle, 360 - angle)
end

-- The plots either side of one.
function PlotRules.neighbours(index: number): { number }
	local count = PlotLayout.COUNT
	return { (index - 2) % count + 1, index % count + 1 }
end

local function nearestHighway(candidates: { number }): number?
	table.sort(candidates, function(a, b)
		local da, db = PlotRules.highwayDistance(a), PlotRules.highwayDistance(b)
		if da ~= db then
			return da < db
		end
		return a < b
	end)
	return candidates[1]
end

-- free: { [index] = true } for plots nobody owns; friendPlots: the plots
-- of friends in the server. Returns a plot index, or nil if all are taken.
function PlotRules.choose(free: { [number]: boolean }, friendPlots: { number }?): number?
	local besideFriends = {}
	for _, friendPlot in friendPlots or {} do
		for _, index in PlotRules.neighbours(friendPlot) do
			if free[index] and not table.find(besideFriends, index) then
				table.insert(besideFriends, index)
			end
		end
	end
	if #besideFriends > 0 then
		return nearestHighway(besideFriends)
	end
	local all = {}
	for index = 1, PlotLayout.COUNT do
		if free[index] then
			table.insert(all, index)
		end
	end
	return nearestHighway(all)
end

return PlotRules
