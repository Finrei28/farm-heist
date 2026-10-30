-- Clearing land with Land Permits (docs/GameDesign.md §4.1b). The field is
-- an 8×8 grid of tiles in 4×4 blocks (Config/Land explains the numbering).
-- The 4 start blocks are open. Each Farm Level in Land.PERMITS earns one
-- permit; using the nth permit costs the nth fee, on an overgrown block that
-- touches open land. Clearing it is OBSTACLES quick holds (or a Farmhand).
-- Permits aren't stored: they're worked out from the level and the blocks
-- already cleared, so they can't drift out of step. tests/land.test.luau.
--
-- land (in the save) = { cleared = { block numbers }, clearing = { block, obstacles }? }
local Land = require(script.Parent.Config.Land)

local LandRules = {}

local SIDE = Land.BLOCKS_PER_SIDE
local BLOCKS = SIDE * SIDE

local isStart = {}
for _, block in Land.START_BLOCKS do
	isStart[block] = true
end

-- Block number → column (1 = by the farmhouse … 4 = by the back fence), row.
function LandRules.position(block: number): (number, number)
	return (block - 1) % SIDE + 1, (block - 1) // SIDE + 1
end

function LandRules.block(column: number, row: number): number
	return (row - 1) * SIDE + column
end

-- The block a field tile (1–64, row by row, column 1 = front) sits in.
function LandRules.blockOfTile(tile: number): number
	local x = (tile - 1) % Land.GRID_TILES
	local y = (tile - 1) // Land.GRID_TILES
	return LandRules.block(x // Land.BLOCK_TILES + 1, y // Land.BLOCK_TILES + 1)
end

-- The tiles in a block.
function LandRules.tilesOf(block: number): { number }
	local column, row = LandRules.position(block)
	local tiles = {}
	for dy = 0, Land.BLOCK_TILES - 1 do
		for dx = 0, Land.BLOCK_TILES - 1 do
			local x = (column - 1) * Land.BLOCK_TILES + dx
			local y = (row - 1) * Land.BLOCK_TILES + dy
			table.insert(tiles, y * Land.GRID_TILES + x + 1)
		end
	end
	return tiles
end

function LandRules.isStart(block: number): boolean
	return isStart[block] == true
end

function LandRules.isOpen(land, block: number): boolean
	return isStart[block] == true or table.find(land.cleared, block) ~= nil
end

function LandRules.isTileOpen(land, tile: number): boolean
	return tile >= 1 and tile <= Land.GRID_TILES * Land.GRID_TILES and LandRules.isOpen(land, LandRules.blockOfTile(tile))
end

-- Open tiles (16 at the start, 64 when everything's cleared).
function LandRules.openTiles(land): number
	return (#Land.START_BLOCKS + #land.cleared) * Land.BLOCK_TILES * Land.BLOCK_TILES
end

-- Permits earned by a Farm Level.
function LandRules.permitsEarned(level: number): number
	local count = 0
	for _, permit in Land.PERMITS do
		if level >= permit.level then
			count += 1
		end
	end
	return count
end

-- Permits earned but not used yet.
function LandRules.permitsLeft(land, level: number): number
	return math.max(0, LandRules.permitsEarned(level) - #land.cleared)
end

-- The next permit to use: its number and { level, fee }, or nil once all
-- 12 are used.
function LandRules.nextPermit(land)
	local index = #land.cleared + 1
	return Land.PERMITS[index] and index, Land.PERMITS[index]
end

-- The Farm Level that earns the next permit (nil when all are earned).
function LandRules.nextPermitLevel(level: number): number?
	for _, permit in Land.PERMITS do
		if permit.level > level then
			return permit.level
		end
	end
	return nil
end

function LandRules.touchesOpen(land, block: number): boolean
	local column, row = LandRules.position(block)
	for _, offset in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local c, r = column + offset[1], row + offset[2]
		if c >= 1 and c <= SIDE and r >= 1 and r <= SIDE and LandRules.isOpen(land, LandRules.block(c, r)) then
			return true
		end
	end
	return false
end

-- "Safer" (by the farmhouse) or "Riskier" (by the back fence, where raiders
-- climb in), for the permit card.
function LandRules.risk(block: number): string
	local column = LandRules.position(block)
	return if column >= Land.RISKY_FROM_COLUMN then "Riskier" else "Safer"
end

-- Whether a block can be cleared now. Returns ok, reason.
function LandRules.canClear(land, level: number, coins: number, block: number): (boolean, string?)
	if type(block) ~= "number" or block ~= math.floor(block) or block < 1 or block > BLOCKS then
		return false, "BadBlock"
	end
	if land.clearing then
		return false, "Busy"
	end
	if LandRules.isOpen(land, block) then
		return false, "AlreadyOpen"
	end
	if LandRules.permitsLeft(land, level) < 1 then
		return false, "NoPermit"
	end
	if not LandRules.touchesOpen(land, block) then
		return false, "NotTouching"
	end
	local _, permit = LandRules.nextPermit(land)
	if coins < permit.fee then
		return false, "TooPoor"
	end
	return true, nil
end

-- Blocks a permit could go on right now (touching open land, still overgrown).
function LandRules.clearable(land): { number }
	local list = {}
	for block = 1, BLOCKS do
		if not LandRules.isOpen(land, block) and LandRules.touchesOpen(land, block) then
			table.insert(list, block)
		end
	end
	return list
end

-- Starts clearing (after canClear and charging the fee). Returns the fee.
function LandRules.startClearing(land, block: number): number
	local _, permit = LandRules.nextPermit(land)
	land.clearing = { block = block, obstacles = Land.OBSTACLES }
	return permit.fee
end

-- One obstacle pulled (a 2 s hold). Returns the block number once the last
-- one is gone (the block is then open), else nil.
function LandRules.clearObstacle(land): number?
	local clearing = land.clearing
	if not clearing then
		return nil
	end
	clearing.obstacles -= 1
	if clearing.obstacles > 0 then
		return nil
	end
	land.clearing = nil
	table.insert(land.cleared, clearing.block)
	return clearing.block
end

-- A Farmhand cleared the rest (after Land.FARMHAND_CLEAR_SECONDS). Returns
-- the block now open, or nil if nothing was being cleared.
function LandRules.finishClearing(land): number?
	local clearing = land.clearing
	if not clearing then
		return nil
	end
	clearing.obstacles = 1
	return LandRules.clearObstacle(land)
end

return LandRules
