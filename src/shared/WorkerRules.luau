-- Workers (docs/GameDesign.md §4.9): how fast they go, what they cost, and
-- how many each station takes. A worker is { type, level, trait? }.
-- tests/workers.test.luau.
local Workers = require(script.Parent.Config.Workers)

local WorkerRules = {}

local function traitOf(worker)
	return worker.trait and Workers.TRAITS[worker.trait] or {}
end

-- Station units a minute (Config/Workers explains the units). night: the
-- Night Owl trait works faster at night.
function WorkerRules.speed(worker, night: boolean?): number
	local kind = Workers.TYPES[worker.type]
	if not kind.speed then
		return 0
	end
	local trait = traitOf(worker)
	return kind.speed * Workers.LEVEL_SPEED ^ (worker.level - 1) * (trait.speed or 1) * (if night then trait.night or 1 else 1)
end

-- Coins a minute (online; offline it's Workers.OFFLINE_RATE of this).
function WorkerRules.wage(worker): number
	local kind = Workers.TYPES[worker.type]
	return kind.wage * Workers.LEVEL_WAGE ^ (worker.level - 1) * (traitOf(worker).wage or 1)
end

function WorkerRules.hireFee(worker): number
	return math.floor(WorkerRules.wage(worker) * Workers.HIRE_FEE + 0.5)
end

-- Coins to train to the next level (nil at the top level).
function WorkerRules.trainFee(worker): number?
	if worker.level >= Workers.MAX_LEVEL then
		return nil
	end
	return math.floor(WorkerRules.wage(worker) * Workers.TRAIN_FEE + 0.5)
end

-- A Sorter's chance of grading a batch A.
function WorkerRules.gradeAChance(worker): number
	return Workers.SORT_GRADE_A + Workers.SORT_GRADE_A_LEVEL * (worker.level - 1) + (traitOf(worker).gradeA or 0)
end

-- Slots for a worker type. ctx = { warehouseTier, shopTier (0–3), openTiles, level }
function WorkerRules.cap(typeName: string, ctx): number
	local kind = Workers.TYPES[typeName]
	if not kind then
		return 0
	end
	if typeName == "Farmhand" then
		return math.min(Workers.MAX_FARMHANDS, ctx.openTiles // Workers.TILES_PER_FARMHAND)
	elseif typeName == "Watchman" then
		return if ctx.level >= kind.level then 1 else 0
	end
	local tier = if kind.shop then ctx.shopTier else ctx.warehouseTier
	return kind.caps[tier + 1] or 0
end

function WorkerRules.count(workers, typeName: string): number
	local count = 0
	for _, worker in workers do
		if worker.type == typeName then
			count += 1
		end
	end
	return count
end

-- Whether another of this type can be hired. Returns ok, reason.
function WorkerRules.canHire(workers, typeName: string, ctx): (boolean, string?)
	if not Workers.TYPES[typeName] then
		return false, "Unknown"
	end
	local cap = WorkerRules.cap(typeName, ctx)
	if cap == 0 then
		return false, "Locked"
	end
	if WorkerRules.count(workers, typeName) >= cap then
		return false, "Full"
	end
	return true, nil
end

-- Building the T1 warehouse turns a Shed Hand into a Packer (same level).
function WorkerRules.promoteShedHands(workers)
	for _, worker in workers do
		if worker.type == "ShedHand" then
			worker.type = "Packer"
		end
	end
end

-- Total station speed by station, and total wages a minute, for a crew.
function WorkerRules.crew(workers, night: boolean?)
	local speeds, wages = {}, 0
	for _, worker in workers do
		local station = Workers.TYPES[worker.type].station
		speeds[station] = (speeds[station] or 0) + WorkerRules.speed(worker, night)
		wages += WorkerRules.wage(worker)
	end
	return speeds, wages
end

return WorkerRules
