-- Laying out your store (docs/GameDesign.md §4.8): which cells an item
-- covers, the rules a layout must keep, the aisles shoppers walk, Charm,
-- and how the floor grows with Store Levels. The same checks run on the
-- client (Decorate shows green or red, with why) and the server (which
-- only saves a layout that passes). tests/storelayout.test.luau.
--
-- A layout is { ["id"] = entry }:
--   floor item  { item, x, y, rot, slots? }   (x, y: the footprint's lowest cell)
--   wall item   { item, side = "back" | "gate" | "hedge", at }   (at: the first cell along that wall)
-- rot turns an item clockwise as seen from above with the road at the bottom:
-- 0 faces the front (−y), 1 faces −x, 2 the back (+y), 3 faces +x. A
-- display or checkout's front is the row of cells it faces; shoppers stand
-- there.
--
-- The rules: items sit on the open floor and don't share cells; the cells
-- inside both doors stay clear; every display and checkout has its front
-- cells free and reachable from the door through free cells, and so is the
-- staff door; each checkout has a queue (its first front cell, then
-- QUEUE_CELLS more in a line: straight back, else turning left, else right)
-- that no other checkout uses; a Register has room behind it for whoever
-- serves at it; at least one checkout, and no more than the level allows.
-- Flat items (a rug) are walked over: they count as free.
local Store = require(script.Parent.Config.Store)

local StoreLayout = {}

local FACING = { [0] = { 0, -1 }, [1] = { -1, 0 }, [2] = { 0, 1 }, [3] = { 1, 0 } }
-- Which way the model's +X side (a shelf's first slot, a Register's till)
-- points on the grid, by rot (World/StoreArt turns models the same way).
local SIDE = { [0] = { -1, 0 }, [1] = { 0, 1 }, [2] = { 1, 0 }, [3] = { 0, -1 } }
local SIDES = { back = true, gate = true, hedge = true }

function StoreLayout.key(x: number, y: number): string
	return `{x},{y}`
end
local key = StoreLayout.key

------------------------------------------------------------------------
-- Levels and buildings

local levels = {}

-- Everything about a Store Level: { number, cost, farmLevel, floor = { w, d },
-- stage, building, stockroom, checkouts, wants = { min, max }, billboard, goldStar }.
function StoreLayout.level(number: number)
	number = math.clamp(math.floor(number), 1, #Store.LEVELS)
	if levels[number] then
		return levels[number]
	end
	local row = Store.LEVELS[number]
	local info = {
		number = number, cost = row.cost, farmLevel = row.farmLevel, floor = row.floor,
		stockroom = Store.STOCKROOM + Store.STOCKROOM_PER_LEVEL * (number - 1),
		billboard = false, goldStar = row.goldStar == true,
	}
	for stage, building in Store.BUILDINGS do
		if number >= building.from then
			info.stage, info.building, info.shoppers = stage, building, building.shoppers
		end
	end
	for _, step in Store.CHECKOUTS do
		if number >= step.from then
			info.checkouts = step.count
		end
	end
	for _, step in Store.WANTS do
		if number >= step.from then
			info.wants = { step.min, step.max }
		end
	end
	for n = 1, number do
		if Store.LEVELS[n].billboard then
			info.billboard = true
		end
	end
	levels[number] = info
	return info
end

-- What a Store Level brings, in words ({ "Farm Shop", "more floor (7×5)", ... }).
function StoreLayout.news(number: number): { string }
	local before, after = StoreLayout.level(number - 1), StoreLayout.level(number)
	local parts = {}
	if number <= 1 then
		return parts
	end
	if after.building ~= before.building then
		table.insert(parts, `a new building: the {after.building.name}` .. (if after.building.gift then ` with a free {Store.ITEMS[after.building.gift].name}` else ""))
	end
	if after.floor[1] * after.floor[2] > before.floor[1] * before.floor[2] then
		table.insert(parts, `more floor ({after.floor[1]}×{after.floor[2]})`)
	end
	if after.shoppers > before.shoppers then
		table.insert(parts, `room for {after.shoppers} shoppers at once`)
	end
	if after.checkouts > before.checkouts then
		table.insert(parts, `{after.checkouts} checkouts`)
	end
	if after.wants[2] > before.wants[2] or after.wants[1] > before.wants[1] then
		table.insert(parts, `shoppers want {after.wants[1]}–{after.wants[2]} crops`)
	end
	if after.billboard and not before.billboard then
		table.insert(parts, "a billboard: more shoppers")
	end
	for _, id in Store.ORDER do
		if Store.ITEMS[id].level == number then
			table.insert(parts, Store.ITEMS[id].name)
		end
	end
	if after.goldStar then
		table.insert(parts, "a gold star on your sign")
	end
	table.insert(parts, `stockroom {after.stockroom} crates`)
	return parts
end

-- How many cells long a wall is in a building stage.
function StoreLayout.wallLength(side: string, stage: number): number
	local cells = Store.BUILDINGS[stage].cells
	return if side == "back" then cells[1] else cells[2]
end

------------------------------------------------------------------------
-- Cells

function StoreLayout.facing(rot: number): (number, number)
	local f = FACING[rot % 4]
	return f[1], f[2]
end

-- The footprint's size on the grid (across, deep) once turned.
function StoreLayout.span(itemId: string, rot: number): (number, number)
	local size = Store.ITEMS[itemId].size
	if rot % 2 == 1 then
		return size[2], size[1]
	end
	return size[1], size[2]
end

-- The cells a floor item covers: { { x, y } }.
function StoreLayout.cells(entry)
	local w, d = StoreLayout.span(entry.item, entry.rot or 0)
	local list = {}
	for dy = 0, d - 1 do
		for dx = 0, w - 1 do
			table.insert(list, { entry.x + dx, entry.y + dy })
		end
	end
	return list
end

-- The cells in front of a floor item: { { x, y } }, in order along its front.
function StoreLayout.fronts(entry)
	local rot = (entry.rot or 0) % 4
	local w, d = StoreLayout.span(entry.item, rot)
	local list = {}
	if rot == 0 then
		for dx = 0, w - 1 do
			table.insert(list, { entry.x + dx, entry.y - 1 })
		end
	elseif rot == 2 then
		for dx = 0, w - 1 do
			table.insert(list, { entry.x + dx, entry.y + d })
		end
	elseif rot == 1 then
		for dy = 0, d - 1 do
			table.insert(list, { entry.x - 1, entry.y + dy })
		end
	else
		for dy = 0, d - 1 do
			table.insert(list, { entry.x + w, entry.y + dy })
		end
	end
	return list
end

-- The cells behind a floor item (where a Cashier stands at a Register).
function StoreLayout.behind(entry)
	return StoreLayout.fronts({ item = entry.item, x = entry.x, y = entry.y, rot = ((entry.rot or 0) + 2) % 4 })
end

-- The front cell nearest a point `along` cells to the model's +X side of its
-- middle (0: the middle).
local function frontNear(entry, along: number)
	local rot = (entry.rot or 0) % 4
	local w, d = StoreLayout.span(entry.item, rot)
	local cx = entry.x + (w - 1) / 2 + SIDE[rot][1] * along
	local cy = entry.y + (d - 1) / 2 + SIDE[rot][2] * along
	local best, bestDistance = nil, math.huge
	for _, cell in StoreLayout.fronts(entry) do
		local distance = (cell[1] - cx) ^ 2 + (cell[2] - cy) ^ 2
		if distance < bestDistance - 1e-9 then
			best, bestDistance = cell, distance
		end
	end
	return best
end

-- Where a shopper stands for slot n of a display: in front of it when the
-- slots sit side by side (a Wooden Shelf, a Chiller), else the middle.
function StoreLayout.slotFront(entry, n: number)
	local def = Store.ITEMS[entry.item]
	if def.slots and def.slots == def.size[1] and def.slots > 1 then
		return frontNear(entry, (def.slots + 1) / 2 - n)
	end
	return frontNear(entry, 0)
end

-- Where the paying shopper stands at a checkout: at a Register, by the till.
function StoreLayout.tillFront(entry)
	local def = Store.ITEMS[entry.item]
	return frontNear(entry, (def.size[1] - 1) / 2)
end

local function kindOf(entry): string?
	local def = Store.ITEMS[entry.item]
	return def and def.kind
end

function StoreLayout.isWall(entry): boolean
	return kindOf(entry) == "Wall"
end

-- Has a front shoppers use (a display or a checkout).
function StoreLayout.hasFront(entry): boolean
	local kind = kindOf(entry)
	return kind == "Display" or kind == "Checkout"
end

-- The layout's ids in a fixed order (numbers first, by value).
function StoreLayout.ids(layout): { string }
	local ids = {}
	for id in layout do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local na, nb = tonumber(a), tonumber(b)
		if na and nb then
			return na < nb
		end
		return a < b
	end)
	return ids
end

-- Ids of the items of one kind ("Display", "Checkout", ...), in order.
function StoreLayout.ofKind(layout, kind: string): { string }
	local ids = {}
	for _, id in StoreLayout.ids(layout) do
		if kindOf(layout[id]) == kind then
			table.insert(ids, id)
		end
	end
	return ids
end

-- The two cells inside the doors, which nothing may stand on.
function StoreLayout.doorCell(): (number, number)
	return Store.DOOR_X, 1
end
function StoreLayout.staffCell(): (number, number)
	return 1, Store.STAFF_Y
end

local function inFloor(level, x: number, y: number): boolean
	return x >= 1 and y >= 1 and x <= level.floor[1] and y <= level.floor[2]
end

-- Which cells things stand on: { ["x,y"] = id } (flat items left out).
function StoreLayout.occupied(layout)
	local taken = {}
	for id, entry in layout do
		if not StoreLayout.isWall(entry) and Store.ITEMS[entry.item] and not Store.ITEMS[entry.item].flat then
			for _, cell in StoreLayout.cells(entry) do
				taken[key(cell[1], cell[2])] = id
			end
		end
	end
	return taken
end

-- Free cells reachable from the door: { ["x,y"] = true }.
local function reach(level, taken)
	local doorX, doorY = StoreLayout.doorCell()
	local seen = { [key(doorX, doorY)] = true }
	local queue = { { doorX, doorY } }
	local head = 1
	while queue[head] do
		local cell = queue[head]
		head += 1
		for rot = 0, 3 do
			local dx, dy = StoreLayout.facing(rot)
			local x, y = cell[1] + dx, cell[2] + dy
			local k = key(x, y)
			if inFloor(level, x, y) and not taken[k] and not seen[k] then
				seen[k] = true
				table.insert(queue, { x, y })
			end
		end
	end
	return seen
end

-- A checkout's queue: { { x, y } × (1 + QUEUE_CELLS) } from its till's front
-- cell, avoiding `used` cells, or nil.
local function queueOf(entry, level, taken, used)
	local front = StoreLayout.tillFront(entry)
	local fx, fy = StoreLayout.facing(entry.rot or 0)
	for _, dir in { { fx, fy }, { -fy, fx }, { fy, -fx } } do
		local cells = { front }
		for i = 1, Store.QUEUE_CELLS do
			local x, y = front[1] + dir[1] * i, front[2] + dir[2] * i
			local k = key(x, y)
			local doorX, doorY = StoreLayout.doorCell()
			local staffX, staffY = StoreLayout.staffCell()
			if not inFloor(level, x, y) or taken[k] or used[k] or (x == doorX and y == doorY) or (x == staffX and y == staffY) then
				cells = nil
				break
			end
			table.insert(cells, { x, y })
		end
		if cells then
			return cells
		end
	end
	return nil
end

-- Every checkout's queue: { [id] = { { x, y } } } (nil for one without room).
function StoreLayout.queues(layout, levelNumber: number)
	local level = StoreLayout.level(levelNumber)
	local taken = StoreLayout.occupied(layout)
	local used, queues = {}, {}
	for _, id in StoreLayout.ofKind(layout, "Checkout") do
		local cells = queueOf(layout[id], level, taken, used)
		if cells then
			for _, cell in cells do
				used[key(cell[1], cell[2])] = true
			end
			queues[id] = cells
		end
	end
	return queues
end

------------------------------------------------------------------------
-- The check

-- Whether a layout keeps every rule at this Store Level. Returns true, or
-- false, a reason and the id of the item it's about:
--   TooMany · Unknown · OutOfFloor · Overlap · Doorway · WallSpace ·
--   NoCheckout · TooManyCheckouts · FrontBlocked · BehindBlocked · Unreachable · StaffDoor · NoQueue
function StoreLayout.check(layout, levelNumber: number): (boolean, string?, string?)
	local level = StoreLayout.level(levelNumber)
	local ids = StoreLayout.ids(layout)
	local floorCount, wallCount, checkouts = 0, 0, 0
	local covered = {} -- every cell an item is on, flat or not
	local walls = { back = {}, gate = {}, hedge = {} }
	local doorX, doorY = StoreLayout.doorCell()
	local staffX, staffY = StoreLayout.staffCell()

	for _, id in ids do
		local entry = layout[id]
		local def = Store.ITEMS[entry.item]
		if not def then
			return false, "Unknown", id
		end
		if def.kind == "Wall" then
			wallCount += 1
			local side = entry.side
			local length = SIDES[side] and StoreLayout.wallLength(side, level.stage)
			if not length or typeof(entry.at) ~= "number" or entry.at % 1 ~= 0 then
				return false, "WallSpace", id
			end
			for at = entry.at, entry.at + def.size[1] - 1 do
				if at < 1 or at > length then
					return false, "WallSpace", id
				end
				if side == "gate" and at == staffY then
					return false, "Doorway", id
				end
				if walls[side][at] then
					return false, "Overlap", id
				end
				walls[side][at] = id
			end
		else
			floorCount += 1
			if def.kind == "Checkout" then
				checkouts += 1
			end
			if typeof(entry.x) ~= "number" or typeof(entry.y) ~= "number" or entry.x % 1 ~= 0 or entry.y % 1 ~= 0
				or typeof(entry.rot) ~= "number" or entry.rot % 1 ~= 0 or entry.rot < 0 or entry.rot > 3 then
				return false, "OutOfFloor", id
			end
			for _, cell in StoreLayout.cells(entry) do
				local x, y = cell[1], cell[2]
				if not inFloor(level, x, y) then
					return false, "OutOfFloor", id
				end
				local k = key(x, y)
				if covered[k] then
					return false, "Overlap", id
				end
				covered[k] = id
				if not def.flat and ((x == doorX and y == doorY) or (x == staffX and y == staffY)) then
					return false, "Doorway", id
				end
			end
		end
	end
	if floorCount > Store.MAX_FLOOR_ITEMS or wallCount > Store.MAX_WALL_ITEMS then
		return false, "TooMany", nil
	end
	if checkouts == 0 then
		return false, "NoCheckout", nil
	end
	if checkouts > level.checkouts then
		return false, "TooManyCheckouts", nil
	end

	local taken = StoreLayout.occupied(layout)
	for _, id in ids do
		local entry = layout[id]
		if StoreLayout.hasFront(entry) then
			for _, cell in StoreLayout.fronts(entry) do
				if not inFloor(level, cell[1], cell[2]) or taken[key(cell[1], cell[2])] then
					return false, "FrontBlocked", id
				end
			end
		end
	end
	for _, id in ids do
		local entry = layout[id]
		if Store.ITEMS[entry.item].staffed then
			for _, cell in StoreLayout.behind(entry) do
				if not inFloor(level, cell[1], cell[2]) or taken[key(cell[1], cell[2])] then
					return false, "BehindBlocked", id
				end
			end
		end
	end
	local reached = reach(level, taken)
	for _, id in ids do
		local entry = layout[id]
		if StoreLayout.hasFront(entry) then
			for _, cell in StoreLayout.fronts(entry) do
				if not reached[key(cell[1], cell[2])] then
					return false, "Unreachable", id
				end
			end
		end
	end
	if not reached[key(staffX, staffY)] then
		return false, "StaffDoor", nil
	end
	local queues = StoreLayout.queues(layout, levelNumber)
	for _, id in StoreLayout.ofKind(layout, "Checkout") do
		if not queues[id] then
			return false, "NoQueue", id
		end
	end
	return true, nil, nil
end

------------------------------------------------------------------------
-- Walking the aisles

-- The shortest walk on free cells from one cell to another: a list of
-- cells { { x, y } } from `from` to `to`, or nil.
function StoreLayout.path(layout, levelNumber: number, from, to)
	local level = StoreLayout.level(levelNumber)
	local taken = StoreLayout.occupied(layout)
	local start, goal = key(from[1], from[2]), key(to[1], to[2])
	local cameFrom = { [start] = false }
	local queue = { from }
	local head = 1
	while queue[head] do
		local cell = queue[head]
		head += 1
		local k = key(cell[1], cell[2])
		if k == goal then
			local path = {}
			while k do
				local x, y = string.match(k, "^(-?%d+),(-?%d+)$")
				table.insert(path, 1, { tonumber(x), tonumber(y) })
				k = cameFrom[k]
			end
			return path
		end
		for rot = 0, 3 do
			local dx, dy = StoreLayout.facing(rot)
			local x, y = cell[1] + dx, cell[2] + dy
			local nk = key(x, y)
			if inFloor(level, x, y) and not taken[nk] and cameFrom[nk] == nil then
				cameFrom[nk] = k
				table.insert(queue, { x, y })
			end
		end
	end
	return nil
end

-- Whether a shopper (about `radius` cells round) can walk straight from one
-- point to another (cell units; a cell's centre is at its x, y) over free
-- cells only.
local function clear(level, taken, a, b, radius: number): boolean
	local dx, dy = b[1] - a[1], b[2] - a[2]
	local steps = math.max(1, math.ceil(math.max(math.abs(dx), math.abs(dy)) * 4))
	for i = 0, steps do
		local px, py = a[1] + dx * i / steps, a[2] + dy * i / steps
		for _, offset in { { -radius, -radius }, { radius, -radius }, { -radius, radius }, { radius, radius } } do
			local x, y = math.floor(px + offset[1] + 0.5), math.floor(py + offset[2] + 0.5)
			if not inFloor(level, x, y) or taken[key(x, y)] then
				return false
			end
		end
	end
	return true
end

-- A cell path with its corners cut where nothing's in the way, so shoppers
-- walk diagonally across open floor instead of in steps.
function StoreLayout.smooth(layout, levelNumber: number, cells)
	if #cells <= 2 then
		return cells
	end
	local level = StoreLayout.level(levelNumber)
	local taken = StoreLayout.occupied(layout)
	local points = { cells[1] }
	local i = 1
	while i < #cells do
		local j = #cells
		while j > i + 1 and not clear(level, taken, cells[i], cells[j], 0.3) do
			j -= 1
		end
		table.insert(points, cells[j])
		i = j
	end
	return points
end

-- Length of a walk in cells.
function StoreLayout.length(points): number
	local length = 0
	for i = 2, #points do
		length += math.sqrt((points[i][1] - points[i - 1][1]) ^ 2 + (points[i][2] - points[i - 1][2]) ^ 2)
	end
	return length
end

------------------------------------------------------------------------
-- Charm

-- Each item's Charm, a second copy counting half, a third a third ...
function StoreLayout.charm(layout): number
	local copies = {}
	for _, entry in layout do
		local def = Store.ITEMS[entry.item]
		if def and def.charm then
			copies[entry.item] = (copies[entry.item] or 0) + 1
		end
	end
	local total = 0
	for itemId, count in copies do
		for n = 1, count do
			total += Store.ITEMS[itemId].charm / n
		end
	end
	return total
end

-- The stars Charm adds to the rating: +0.1 for every 10, up to +1.
function StoreLayout.charmStars(layout): number
	local steps = math.floor(StoreLayout.charm(layout) / Store.CHARM_STEP + 1e-9)
	return math.min(Store.CHARM_MAX_STARS, steps * Store.CHARM_STAR_STEP)
end

------------------------------------------------------------------------
-- Owning and placing

-- Items placed, by catalog id: { [itemId] = count }.
function StoreLayout.counts(layout)
	local counts = {}
	for _, entry in layout do
		counts[entry.item] = (counts[entry.item] or 0) + 1
	end
	return counts
end

-- Whether a display can hold a crop of this rarity.
function StoreLayout.holds(itemId: string, rarity: string): boolean
	local def = Store.ITEMS[itemId]
	return def ~= nil and def.rarities ~= nil and table.find(def.rarities, rarity) ~= nil
end

-- The lowest and highest rarity order a display holds (for the cards).
function StoreLayout.rarityRange(itemId: string): (string?, string?)
	local def = Store.ITEMS[itemId]
	if not def or not def.rarities then
		return nil, nil
	end
	return def.rarities[1], def.rarities[#def.rarities]
end

-- Empty slots for a new display.
function StoreLayout.newSlots(itemId: string)
	local def = Store.ITEMS[itemId]
	if not def.slots then
		return nil
	end
	local slots = {}
	for i = 1, def.slots do
		slots[i] = { units = 0, a = 0 }
	end
	return slots
end

-- A place for an item where the layout stays valid: x, y, rot (or nil).
-- Tries the back rows first, then the hedge end, facing the front first:
-- that's where new floor opens, and it keeps the aisle by the door clear.
function StoreLayout.findSpot(layout, levelNumber: number, itemId: string): (number?, number?, number?)
	local level = StoreLayout.level(levelNumber)
	local trial = table.clone(layout)
	local probe = "?"
	for y = level.floor[2], 1, -1 do
		for x = level.floor[1], 1, -1 do
			for _, rot in { 0, 1, 3, 2 } do
				trial[probe] = { item = itemId, x = x, y = y, rot = rot }
				if StoreLayout.check(trial, levelNumber) then
					return x, y, rot
				end
			end
		end
	end
	return nil, nil, nil
end

-- When a level opens more floor at the back, things standing against the
-- old back edge move back with it (the shelves stay against the wall and
-- the aisle widens), as long as the layout stays valid. Returns whether
-- anything moved.
function StoreLayout.grow(layout, fromLevel: number, toLevel: number): boolean
	local before, after = StoreLayout.level(fromLevel), StoreLayout.level(toLevel)
	local deeper = after.floor[2] - before.floor[2]
	if deeper <= 0 then
		return false
	end
	local moved = {}
	for id, entry in layout do
		if not StoreLayout.isWall(entry) then
			local _, d = StoreLayout.span(entry.item, entry.rot or 0)
			if entry.y + d - 1 == before.floor[2] then
				moved[id] = entry.y
				entry.y += deeper
			end
		end
	end
	if next(moved) == nil then
		return false
	end
	if StoreLayout.check(layout, toLevel) then
		return true
	end
	for id, y in moved do
		layout[id].y = y
	end
	return false
end

return StoreLayout
