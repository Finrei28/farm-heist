-- The movement check's maths (MovementService; tests/movement.test.luau):
-- each tick a player earns movement allowance (a little faster than
-- sprinting), saved up to a cap so lag bursts are fine, and spends it on how
-- far they moved across the ground. Rising has its own, smaller allowance;
-- falling is free. Overspending is a teleport or a speed hack.
--   local budget = MoveRules.new()
--   MoveRules.step(budget, offset, dt, scale?) -> ok: boolean, overBy: number
--     (scale: a share of the usual allowance, for someone who can't run:
--     a thief with a Loot Sack walks at 85% and can't sprint)
--   MoveRules.refill(budget)    (after a respawn or a server teleport)
local Settings = require(script.Parent.Config.Settings)

local MoveRules = {
	SPEED = Settings.RUN_SPEED * 1.25, -- studs a second across the ground, with slack
	SAVED = 60, -- the most that can build up (lag bursts; also the longest hop that goes unchecked)
	RISE_SPEED = 30, -- studs a second upwards (jumps, steps, slopes)
	RISE_SAVED = 16,
}

function MoveRules.new()
	return { across = MoveRules.SAVED, rise = MoveRules.RISE_SAVED }
end

function MoveRules.refill(budget)
	budget.across, budget.rise = MoveRules.SAVED, MoveRules.RISE_SAVED
end

-- offset: where they are now minus where they were last time it passed.
function MoveRules.step(budget, offset: Vector3, dt: number, scale: number?): (boolean, number)
	budget.across = math.min(MoveRules.SAVED, budget.across + MoveRules.SPEED * (scale or 1) * dt)
	budget.rise = math.min(MoveRules.RISE_SAVED, budget.rise + MoveRules.RISE_SPEED * dt)
	local across = math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
	local up = math.max(0, offset.Y)
	if across <= budget.across and up <= budget.rise then
		budget.across -= across
		budget.rise -= up
		return true, 0
	end
	local overBy = math.max(across - budget.across, up - budget.rise)
	-- Sent back: half an allowance to carry on with.
	budget.across, budget.rise = MoveRules.SAVED / 2, MoveRules.RISE_SAVED / 2
	return false, overBy
end

return MoveRules
