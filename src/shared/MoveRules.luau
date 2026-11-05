-- The movement check's maths (MovementService; tests/movement.test.luau):
-- each tick a player earns movement allowance (a little faster than
-- sprinting), saved up to a cap so lag bursts are fine, and spends it on how
-- far they moved across the ground. Rising has its own, smaller allowance;
-- falling is free. Overspending is a teleport or a speed hack.
--   local budget = MoveRules.new()
--   MoveRules.step(budget, offset, dt, scale?) -> ok: boolean, overBy: number
--     (scale: a share of the usual allowance, for someone who can't run:
--     a thief carrying a stolen crop on a farm walks at 85% and can't sprint)
--   MoveRules.refill(budget)    (after a respawn or a server teleport)
--   MoveRules.fits(budget, offset) -> whether a move is within what's saved up
--   MoveRules.hovering(budget, height, dt) -> whether they've hung in the air too long
local Settings = require(script.Parent.Config.Settings)

local MoveRules = {
	SPEED = Settings.RUN_SPEED * 1.25, -- studs a second across the ground, with slack
	SAVED = 60, -- the most that can build up (lag bursts; also the longest hop that goes unchecked)
	RISE_SPEED = 30, -- studs a second upwards (jumps, steps, slopes)
	RISE_SAVED = 16,
	-- Over a farm, nobody stands this high above what's under them (a jump
	-- tops out about 10 studs up, measured at the character's middle) ...
	HOVER_HEIGHT = 14,
	-- ... for longer than this (even a fall from a roof is over sooner).
	HOVER_SECONDS = 1.5,
}

function MoveRules.new()
	return { across = MoveRules.SAVED, rise = MoveRules.RISE_SAVED }
end

function MoveRules.refill(budget)
	budget.across, budget.rise, budget.air = MoveRules.SAVED, MoveRules.RISE_SAVED, 0
end

-- Whether a move is within what's saved up, without spending any of it (the
-- moments after a server teleport, when a client may still be saying where it
-- was: a move from anywhere else is ignored, not trusted).
function MoveRules.fits(budget, offset: Vector3): boolean
	local across = math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
	return across <= budget.across and math.max(0, offset.Y) <= budget.rise
end

-- Counts time spent `height` studs above what's under them (over a farm,
-- where it matters: a thief up there is out of the bat's reach). Returns
-- whether that's flying.
function MoveRules.hovering(budget, height: number, dt: number): boolean
	budget.air = if height > MoveRules.HOVER_HEIGHT then (budget.air or 0) + dt else 0
	return budget.air >= MoveRules.HOVER_SECONDS
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
