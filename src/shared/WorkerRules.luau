-- Workers (docs/GameDesign.md §4.9): how fast they go and what they cost at
-- each level, experience and training, how many each station takes, and the
-- hiring board. A worker is { type, level, xp, trait?, name, look } (in the
-- save under a uid). tests/workers.test.luau.
local Workers = require(script.Parent.Config.Workers)
local Warehouse = require(script.Parent.Config.Warehouse)

local WorkerRules = {}

local function traitOf(worker)
	return worker.trait and Workers.TRAITS[worker.trait] or {}
end

-- How far up the ladder a level is: 0 at Level 1, 1 at the top.
local function climb(level: number): number
	return (math.clamp(level, 1, Workers.MAX_LEVEL) - 1) / (Workers.MAX_LEVEL - 1)
end

-- Share of the job's full speed (40% at Level 1, 100% at Level 10).
function WorkerRules.efficiency(level: number): number
	return Workers.EFFICIENCY_MIN + (1 - Workers.EFFICIENCY_MIN) * climb(level)
end

-- Station units a minute (Config/Workers explains the units). opts: night
-- (Night Owls are quicker), conveyors (the warehouse's, for Sort, Pack and Load).
function WorkerRules.speed(worker, opts): number
	local kind = Workers.TYPES[worker.type]
	if not kind or not kind.speed then
		return 0
	end
	local trait = traitOf(worker)
	local speed = kind.speed * WorkerRules.efficiency(worker.level) * (trait.speed or 1)
	if opts and opts.night then
		speed *= trait.night or 1
	end
	if opts and opts.conveyors and (kind.station == "Sort" or kind.station == "Pack" or kind.station == "Load") then
		speed *= opts.conveyors
	end
	return speed
end

-- Coins a minute online (while you're away it's Workers.OFFLINE_RATE of this).
function WorkerRules.wage(worker): number
	local kind = Workers.TYPES[worker.type]
	local part = Workers.WAGE_MIN + (1 - Workers.WAGE_MIN) * climb(worker.level)
	return kind.wage * part * (traitOf(worker).wage or 1)
end

function WorkerRules.hireFee(worker): number
	return math.floor(WorkerRules.wage(worker) * Workers.HIRE_FEE + 0.5)
end

------------------------------------------------------------------------
-- Experience and training

-- XP from Level `level` to the next (nil at the top).
function WorkerRules.xpToNext(level: number): number?
	if level >= Workers.MAX_LEVEL then
		return nil
	end
	return math.floor(Workers.XP_BASE * Workers.XP_GROWTH ^ (level - 1) + 0.5)
end

-- Coins to train to the next level (nil at the top).
function WorkerRules.trainFee(worker): number?
	if worker.level >= Workers.MAX_LEVEL then
		return nil
	end
	local kind = Workers.TYPES[worker.type]
	return math.floor(Workers.TRAIN_BASE * (kind.wage / Workers.TRAIN_WAGE) * Workers.TRAIN_GROWTH ^ (worker.level - 1) + 0.5)
end

-- Whether the XP bar is full (the badge says Ready to train).
function WorkerRules.ready(worker): boolean
	local need = WorkerRules.xpToNext(worker.level)
	return need ~= nil and (worker.xp or 0) >= need
end

-- Adds XP from real work. The bar stops when full (it waits for Train).
-- Returns true if this filled it.
function WorkerRules.addXp(worker, amount: number): boolean
	local need = WorkerRules.xpToNext(worker.level)
	if not need or amount <= 0 then
		return false
	end
	local was = worker.xp or 0
	worker.xp = math.min(need, was + amount)
	return was < need and worker.xp >= need
end

-- Whether a worker can be trained with `coins`: nil, or why not:
-- "MaxLevel" · "NeedXp" · "NoCoins".
function WorkerRules.cannotTrain(worker, coins: number): string?
	local fee = WorkerRules.trainFee(worker)
	if not fee then
		return "MaxLevel"
	elseif not WorkerRules.ready(worker) then
		return "NeedXp"
	elseif coins < fee then
		return "NoCoins"
	end
	return nil
end

-- Up a level (the caller has taken the fee); the bar starts again.
function WorkerRules.train(worker)
	worker.level += 1
	worker.xp = 0
end

------------------------------------------------------------------------
-- What they do

-- A Sorter's (or Shed Hand's) chance of grading a batch A. washLine: the
-- warehouse has the Wash Line.
function WorkerRules.gradeAChance(worker, washLine: boolean?): number
	local chance = Workers.SORT_GRADE_A + Workers.SORT_GRADE_A_LEVEL * (worker.level - 1) + (traitOf(worker).gradeA or 0)
	if washLine then
		chance += Warehouse.WASH_LINE
	end
	return math.min(Workers.GRADE_A_MAX, chance)
end

-- How much shorter a Driver makes the round trip (0 at Level 1 up to
-- DRIVER_TRIP at Level 10).
function WorkerRules.tripShave(worker): number
	return Workers.DRIVER_TRIP * climb(worker.level)
end

-- How many more shoppers a Greeter brings (a share).
function WorkerRules.greeterBoost(worker): number
	return Workers.GREETER * WorkerRules.efficiency(worker.level)
end

-- Station speeds a minute and the crew's wages a minute. opts as for speed.
function WorkerRules.crew(workers, opts)
	local speeds, wages = {}, 0
	for _, worker in workers do
		local kind = Workers.TYPES[worker.type]
		if kind then
			speeds[kind.station] = (speeds[kind.station] or 0) + WorkerRules.speed(worker, opts)
			wages += WorkerRules.wage(worker)
		end
	end
	return speeds, wages
end

------------------------------------------------------------------------
-- Slots

-- How many of a type you can have. ctx = { warehouseLevel, storeLevel,
-- openTiles, registers, trucks } (trucks: at the warehouse's level).
function WorkerRules.slots(typeName: string, ctx): number
	local kind = Workers.TYPES[typeName]
	if not kind then
		return 0
	elseif typeName == "Farmhand" then
		return math.min(Workers.MAX_FARMHANDS, ctx.openTiles // Workers.TILES_PER_FARMHAND)
	elseif typeName == "Driver" then
		return if ctx.warehouseLevel >= Workers.DRIVERS_FROM then ctx.trucks else 0
	elseif typeName == "Cashier" then
		return ctx.registers
	end
	if kind.untilLevel and ctx.warehouseLevel >= kind.untilLevel then
		return 0
	end
	local at = kind.slots.warehouse or kind.slots.store
	local level = if kind.slots.warehouse then ctx.warehouseLevel else ctx.storeLevel
	local count = 0
	for _, from in at do
		if level >= from then
			count += 1
		end
	end
	return count
end

-- What opens the next slot of a type, for a greyed slot: "Warehouse Level 8",
-- "Store Level 2", "32 cleared tiles", "a Register in your store"; nil if none will.
function WorkerRules.nextSlot(typeName: string, ctx): string?
	local kind = Workers.TYPES[typeName]
	local have = WorkerRules.slots(typeName, ctx)
	if typeName == "Farmhand" then
		return if have < Workers.MAX_FARMHANDS then `{(have + 1) * Workers.TILES_PER_FARMHAND} cleared tiles` else nil
	elseif typeName == "Driver" then
		if ctx.warehouseLevel < Workers.DRIVERS_FROM then
			return `Warehouse Level {Workers.DRIVERS_FROM}`
		end
		for level = ctx.warehouseLevel + 1, #Warehouse.LEVELS do
			if (Warehouse.LEVELS[level].trucks or 0) > ctx.trucks then
				return `Warehouse Level {level}`
			end
		end
		return nil
	elseif typeName == "Cashier" then
		return "a Register in your store"
	end
	if kind.untilLevel and ctx.warehouseLevel >= kind.untilLevel then
		return nil
	end
	local at = kind.slots.warehouse or kind.slots.store
	local from = at[have + 1]
	if not from or (kind.untilLevel and from >= kind.untilLevel) then
		return nil
	end
	return `{if kind.slots.warehouse then "Warehouse" else "Store"} Level {from}`
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

-- Whether another of this type can be hired. Returns ok, reason ("Unknown" ·
-- "Locked" · "Full").
function WorkerRules.canHire(workers, typeName: string, ctx): (boolean, string?)
	if not Workers.TYPES[typeName] then
		return false, "Unknown"
	end
	local slots = WorkerRules.slots(typeName, ctx)
	if slots == 0 then
		return false, "Locked"
	elseif WorkerRules.count(workers, typeName) >= slots then
		return false, "Full"
	end
	return true, nil
end

-- The Distribution Warehouse turns Shed Hands into Packers (same level and XP).
function WorkerRules.promoteShedHands(workers)
	for _, worker in workers do
		if worker.type == "ShedHand" then
			worker.type = "Packer"
		end
	end
end

------------------------------------------------------------------------
-- The hiring board

-- The traits a job's candidates can have (only ones that help that job).
function WorkerRules.traitsFor(typeName: string): { string }
	local kind = Workers.TYPES[typeName]
	local list = {}
	for _, id in Workers.TRAIT_ORDER do
		local need = Workers.TRAITS[id]["for"]
		if need == nil or (need == "speed" and kind.speed ~= nil) or (need == "grade" and (typeName == "Sorter" or typeName == "ShedHand")) then
			table.insert(list, id)
		end
	end
	return list
end

-- The board's window number at unix time t (a new board every BOARD_SECONDS).
function WorkerRules.boardWindow(t: number): number
	return t // Workers.BOARD_SECONDS
end

-- Seconds until the next board.
function WorkerRules.boardLeft(t: number): number
	return Workers.BOARD_SECONDS - t % Workers.BOARD_SECONDS
end

-- A player's candidates for one type in one window: BOARD_SIZE workers
-- { type, level, xp, trait, name, look, fee, id }, the same every time
-- (seeded by the player, the window and the type), so nothing is saved but
-- who was hired from it.
function WorkerRules.candidates(userId: number, window: number, typeName: string)
	local typeIndex = table.find(Workers.ORDER, typeName) or 0
	local rng = Random.new((userId % 1_000_003) * 7919 + window * 104_729 + typeIndex * 613)
	local traits = WorkerRules.traitsFor(typeName)
	local list = {}
	for slot = 1, Workers.BOARD_SIZE do
		local roll, level = rng:NextNumber(), 1
		for index, weight in Workers.HIRE_LEVELS do
			if roll < weight then
				level = index
				break
			end
			roll -= weight
		end
		local worker = {
			type = typeName,
			level = level,
			xp = 0,
			trait = traits[rng:NextInteger(1, #traits)],
			name = Workers.NAMES[rng:NextInteger(1, #Workers.NAMES)],
			look = rng:NextInteger(1, 8), -- skin tone and hair (shared with the shoppers' looks)
			id = `{window}:{typeName}:{slot}`,
		}
		worker.fee = WorkerRules.hireFee(worker)
		table.insert(list, worker)
	end
	return list
end

return WorkerRules
