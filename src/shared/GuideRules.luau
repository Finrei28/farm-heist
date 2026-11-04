-- The Farm Guide's progress (Config/Guide), kept apart from GuideService so
-- tests can load it (tests/guide.test.luau). A player's guide is saved as
--   { done = { [stepId] = true }, planted, finished, hidden, rewarded }
-- planted: Carrots planted towards the first step; finished: every step
-- done; hidden: they closed the card; rewarded: the coins were paid (only
-- ever once, even if it's started again).
local Guide = require(script.Parent.Config.Guide)

local GuideRules = {}

local STEP_INDEX = {}
for index, step in Guide.STEPS do
	STEP_INDEX[step.id] = index
end

-- The first step not done yet (and its number), or nil when all are.
function GuideRules.current(guide)
	for index, step in Guide.STEPS do
		if not (guide and guide.done and guide.done[step.id]) then
			return step, index
		end
	end
	return nil, #Guide.STEPS + 1
end

function GuideRules.count(guide): number
	local count = 0
	for _, step in Guide.STEPS do
		if guide and guide.done and guide.done[step.id] then
			count += 1
		end
	end
	return count
end

-- Ticks a step off (any order: someone may sell before they water). Returns
-- "done" if that was new, "finished" if it was the last one, or nil if
-- nothing changed (unknown, already done, or the guide already finished).
function GuideRules.record(guide, stepId: string): string?
	if not guide or guide.finished or not STEP_INDEX[stepId] then
		return nil
	end
	guide.done = guide.done or {}
	if guide.done[stepId] then
		return nil
	end
	guide.done[stepId] = true
	if GuideRules.count(guide) == #Guide.STEPS then
		guide.finished = true
		return "finished"
	end
	return "done"
end

-- One Carrot planted: the first step is done at PLANT_COUNT, or sooner when
-- `seedsLeft` says there are none left to plant. Returns what record does.
function GuideRules.planted(guide, seedsLeft: number): string?
	if not guide or guide.finished or (guide.done and guide.done.Plant) then
		return nil
	end
	guide.planted = (guide.planted or 0) + 1
	if guide.planted >= Guide.PLANT_COUNT or seedsLeft <= 0 then
		return GuideRules.record(guide, "Plant")
	end
	return nil
end

-- Whether finishing now should pay the reward (and marks it paid).
function GuideRules.claimReward(guide): boolean
	if not guide or not guide.finished or guide.rewarded then
		return false
	end
	guide.rewarded = true
	return true
end

-- From the start again, shown (the Quests window's Farm Guide button). The
-- reward stays paid.
function GuideRules.restart(guide)
	guide.done = {}
	guide.planted = 0
	guide.finished = false
	guide.hidden = false
end

-- Whether the card shows.
function GuideRules.visible(guide): boolean
	return guide ~= nil and not guide.hidden and not guide.finished
end

return GuideRules
