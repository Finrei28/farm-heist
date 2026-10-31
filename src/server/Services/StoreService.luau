-- Your store (docs/GameDesign.md §4.8; the rules are shared/ShopRules and
-- shared/StoreLayout, the look World/StoreArt): filling displays, prices,
-- the store's name, Store Levels and new buildings going up, saving a layout
-- from Decorate mode, the staff door, and NPC shoppers while you're in the
-- server.
--
-- Shoppers are simulated here and drawn by every client from the
-- ShopperEvent remote (ShopperController): each "Path" message is a walk
-- (world points from server time `at`, at Shop.SPEED) that replaces the last
-- one. A shopper walks the sidewalk to the door, the aisles to a display for
-- each crop they want (they decide there: ShopRules.pick), then to the
-- shortest checkout queue; they pay when served (an Honour Box serves
-- itself; a Register while you stand behind it or a Cashier works it), or
-- put their basket back after Shop.PATIENCE seconds. The coins come in when
-- they pay. A Greeter brings more shoppers; Stockers fill the displays
-- (WorkerService, through StoreService.crew and StoreService.Restock).
--
-- (Shoppers only come while you're playing. Selling while you're away is
-- worked out on your return with the workers: WorkerService.)
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage.Shared
local Crops = require(Shared.Config.Crops)
local Growth = require(Shared.Config.Growth)
local Shop = require(Shared.Config.Shop)
local Store = require(Shared.Config.Store)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local ShopRules = require(Shared.ShopRules)
local StoreLayout = require(Shared.StoreLayout)

local Server = ServerScriptService.Server
local ActionRemote = require(Server.Util.ActionRemote)
local Analytics = require(Server.Util.Analytics)
local Notice = require(Server.Util.Notice)
local StoreArt = require(Server.World.StoreArt)
local StoreItems = require(Server.World.StoreItems)
local DataService = require(script.Parent.DataService)
local MarketService = require(script.Parent.MarketService)
local MovementService = require(script.Parent.MovementService)
local PlotService = require(script.Parent.PlotService)

local StoreService = {}

StoreService.REACH = 9 -- studs from a display you can fill it from
local TICK = 0.2
local RUSH_GAP = 1.5 -- seconds between shoppers during /shoppers
local STAFF_DOOR_REACH = 7
local SERVE_REACH = 0.8 -- cells from the spot behind a Register you serve from
local SIDEWALK_Y, STEP_Y = 0.3, 0.35
local FLOOR = PlotLayout.PLOT.store.floor
local LAYOUT_MAX = 20_000 -- characters of a layout from Decorate

local ShopperEvent = Remotes.event("ShopperEvent")
local tickStore -- (below)
local rng = Random.new()

local stores = {} -- [Player] = { index, shoppers = { [id] = shopper }, queues = { [checkoutId] = { shopper } }, nextAt, rush, decorating, decorateAt, soldOutTold }
local lastId = 0

-- The store's crew (WorkerService sets these):
--   cashier(player, checkoutId) → the Cashier working that Register, and
--     the seconds they take a shopper; nil if none
--   boost(player) → the Greeter's extra shoppers (a share)
--   served(player, worker, seconds) → a Cashier served a shopper
StoreService.crew = {
	cashier = function(_player: Player, _checkout: string)
		return nil, nil
	end,
	boost = function(_player: Player): number
		return 0
	end,
	served = function(_player: Player, _worker, _seconds: number) end,
}

local function now(): number
	return workspace:GetServerTimeNow()
end

------------------------------------------------------------------------
-- Drawing the store

-- "Sam's Corner Store", or the name you gave it.
function StoreService.nameOf(player: Player, store): string
	return store.name or `{player.DisplayName}'s {StoreLayout.level(store.level).building.name}`
end

local function fillPrompt(player: Player, item: Model, id: string)
	if item:FindFirstChild("FillPrompt", true) then
		return
	end
	local at = Instance.new("Attachment")
	at.Name = "PromptAt"
	at.Position = Vector3.new(0, 3, 0)
	at.Parent = item.PrimaryPart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FillPrompt"
	prompt.ActionText = "Fill"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerId", player.UserId)
	prompt.Parent = at
	prompt.Triggered:Connect(function(who)
		if who == player then
			StoreService.Fill(player, id)
		end
	end)
end

-- Redraws each display's produce and price tags, and its prompt's note.
local function drawDisplays(player: Player)
	local st, data = stores[player], DataService.Get(player)
	if not st or not data then
		return
	end
	local store = data.store
	local model = PlotService.model(st.index)
	local waiting = ShopRules.stockroomUnits(store)
	for _, id in StoreLayout.ofKind(store.layout, "Display") do
		local entry = store.layout[id]
		StoreArt.showDisplay(model, id, entry, store.prices)
		local item = model.Store.Items:FindFirstChild(id)
		local prompt = item and item:FindFirstChild("FillPrompt", true)
		if prompt then
			local def = Store.ITEMS[entry.item]
			local units, room = 0, 0
			for _, slot in entry.slots do
				units += slot.units
				room += def.units
			end
			local canFill = 0
			for cropId, n in waiting do
				if ShopRules.canHold(entry.item, cropId) then
					canFill += n
				end
			end
			prompt.ObjectText = `{def.name} {units}/{room} · stockroom {canFill}`
		end
	end
end

local function drawStockroom(player: Player)
	local st, data = stores[player], DataService.Get(player)
	if st and data then
		StoreArt.showStockroom(PlotService.model(st.index), data.store.stockroom, StoreLayout.level(data.store.level).stage)
	end
end

-- Everything: the building (if its level changed), items, displays, the
-- stockroom, the name, prompts.
local function redraw(player: Player)
	local st, data = stores[player], DataService.Get(player)
	if not st or not data then
		return
	end
	local store = data.store
	local model = PlotService.model(st.index)
	local building = model.Store:FindFirstChild("Building")
	if not building or building:GetAttribute("Level") ~= store.level then
		StoreArt.buildBuilding(model, store.level, StoreService.nameOf(player, store))
	else
		StoreArt.setName(model, StoreService.nameOf(player, store))
	end
	local items = StoreArt.placeItems(model, store.layout, StoreLayout.level(store.level).stage)
	for _, id in StoreLayout.ofKind(store.layout, "Display") do
		fillPrompt(player, items[id], id)
	end
	drawDisplays(player)
	drawStockroom(player)
	StoreArt.setBackSoon(model, st.decorating == true)
	if store.build then
		StoreArt.showConstruction(model, store.build.to, math.ceil(store.build.left))
	else
		StoreArt.showConstruction(model, nil)
	end
end
StoreService.Redraw = redraw

-- After crates arrive in the stockroom (WarehouseService).
function StoreService.StockroomChanged(player: Player)
	drawStockroom(player)
	drawDisplays(player)
end

------------------------------------------------------------------------
-- Shoppers: moving them

local function cellPoint(index: number, cell): Vector3
	return PlotLayout.storeWorld(index, cell[1], cell[2], FLOOR)
end

-- Where a shopper is now (world) and the cell under them.
local function positionOf(shopper, t: number): Vector3
	if not shopper.points then
		return Vector3.zero
	end
	return (PlotLayout.along(shopper.points, math.max(0, t - shopper.startAt) * Shop.SPEED))
end

local function basketUnits(shopper): number
	local units = 0
	for _, line in shopper.basket do
		units += line.units
	end
	return units
end

-- Sends a shopper on a walk (or to stand still: one point) from `startAt`.
-- extra: { face = Vector3?, say = string?, coins = number?, leave = true? }
local function send(shopper, points, startAt: number, extra)
	shopper.points = points
	shopper.startAt = startAt
	shopper.arriveAt = startAt + PlotLayout.pathLength(points) / Shop.SPEED
	local message = {
		plot = shopper.plot, id = shopper.id, look = shopper.look, at = startAt, points = points,
		face = extra and extra.face, say = extra and extra.say, coins = extra and extra.coins,
		basket = basketUnits(shopper), leave = extra and extra.leave,
	}
	shopper.last = message
	ShopperEvent:FireAllClients("Path", message)
end

-- A walk on the floor from one cell to another, as world points (corners
-- cut where the floor's open), or nil if there's no way.
local function aisle(index: number, store, from, to)
	local cells = StoreLayout.path(store.layout, store.level, from, to)
	if not cells then
		return nil
	end
	local points = {}
	for _, cell in StoreLayout.smooth(store.layout, store.level, cells) do
		table.insert(points, cellPoint(index, cell))
	end
	return points
end

-- The free cell nearest a point on the floor (cell units), for a shopper
-- whose spot just got furniture put on it.
local function nearestFree(store, cx: number, cy: number)
	local level = StoreLayout.level(store.level)
	local taken = StoreLayout.occupied(store.layout)
	local best, bestDistance = { Store.DOOR_X, 1 }, math.huge
	for y = 1, level.floor[2] do
		for x = 1, level.floor[1] do
			if not taken[StoreLayout.key(x, y)] then
				local distance = (x - cx) ^ 2 + (y - cy) ^ 2
				if distance < bestDistance then
					best, bestDistance = { x, y }, distance
				end
			end
		end
	end
	return best
end

local function remove(st, shopper)
	st.shoppers[shopper.id] = nil
	if shopper.checkout then
		local queue = st.queues[shopper.checkout]
		local at = queue and table.find(queue, shopper)
		if at then
			table.remove(queue, at)
		end
	end
end

-- Out through the door and off along the sidewalk.
local function leave(st, shopper, startAt: number, say: string?, score: number?)
	local data = DataService.Get(shopper.owner)
	if data and score then
		ShopRules.addScore(data.store, score)
	end
	local queue = shopper.checkout and st.queues[shopper.checkout]
	local at = queue and table.find(queue, shopper)
	if at then
		table.remove(queue, at)
	end
	shopper.checkout = nil
	local doorX, doorY = StoreLayout.doorCell()
	local points = (data and aisle(st.index, data.store, shopper.cell, { doorX, doorY })) or { cellPoint(st.index, shopper.cell) }
	table.insert(points, PlotLayout.storeWorld(st.index, doorX, 0.5, FLOOR))
	local outside = PlotLayout.storeApproach(st.index, rng:NextInteger(0, 1) * 2 - 1, shopper.lane)
	for i = #outside, 1, -1 do
		local p = outside[i]
		table.insert(points, Vector3.new(p.X, if i == #outside then STEP_Y else SIDEWALK_Y, p.Z))
	end
	shopper.stage = "out"
	send(shopper, points, startAt, { say = say, leave = true })
end

local function displayCentre(index: number, store, id: string): Vector3?
	local entry = store.layout[id]
	if not entry then
		return nil
	end
	local w, d = StoreLayout.span(entry.item, entry.rot)
	return PlotLayout.storeWorld(index, entry.x + (w - 1) / 2, entry.y + (d - 1) / 2, FLOOR + 3)
end

-- A spot in a checkout's queue: 1 is paying at the till, the rest every
-- half cell back along the queue's line.
local function queueSpot(index: number, cells, spot: number): Vector3
	local first, second = cells[1], cells[2]
	local along = (spot - 1) * 0.5
	return PlotLayout.storeWorld(index, first[1] + (second[1] - first[1]) * along, first[2] + (second[2] - first[2]) * along, FLOOR)
end

-- Sends everyone in a queue to their spot (after someone leaves it).
local function shuffle(st, store, checkout: string, t: number)
	local queue = st.queues[checkout]
	local cells = StoreLayout.queues(store.layout, store.level)[checkout]
	if not queue or not cells then
		return
	end
	local face = displayCentre(st.index, store, checkout)
	for spot, shopper in queue do
		if shopper.spot ~= spot and (shopper.stage == "queued" or shopper.stage == "toQueue") then
			shopper.spot = spot
			shopper.cell = cells[math.clamp(math.floor((spot - 1) * 0.5 + 0.5) + 1, 1, #cells)]
			local to = queueSpot(st.index, cells, spot)
			send(shopper, { positionOf(shopper, t), to }, t, { face = face })
			shopper.stage = "toQueue"
		end
	end
end

-- What a shopper does next from where they're standing (at `startAt`): the
-- next crop they want, else a checkout with their basket, else home.
local function goNext(st, shopper, startAt: number, say: string?)
	local data = DataService.Get(shopper.owner)
	if not data then
		return
	end
	local store = data.store
	if st.decorating then
		table.clear(shopper.wants) -- ("Back soon": finish up)
	end
	while #shopper.wants > 0 do
		local cropId = table.remove(shopper.wants, 1)
		local id = ShopRules.displayWith(store, cropId, rng)
		local entry = id and store.layout[id]
		if entry then
			local slotIndex = 1
			for n, slot in entry.slots do
				if slot.crop == cropId and slot.units > 0 then
					slotIndex = n
					break
				end
			end
			local cell = StoreLayout.slotFront(entry, slotIndex)
			local points = aisle(st.index, store, shopper.cell, cell)
			if points then
				shopper.cell = cell
				shopper.target = { display = id, crop = cropId }
				shopper.stage = "toDisplay"
				send(shopper, points, startAt, { say = say, face = displayCentre(st.index, store, id) })
				return
			end
		end
	end
	if #shopper.basket == 0 then
		-- (nothing they'd pay for, or it sold out before they got there; no
		-- score if they were hurried out by "Back soon")
		leave(st, shopper, startAt, say, if st.decorating then nil else Shop.SCORE_TOO_DEAR)
		return
	end
	-- the shortest queue
	local queues = StoreLayout.queues(store.layout, store.level)
	local best, length = nil, math.huge
	for _, checkout in StoreLayout.ofKind(store.layout, "Checkout") do
		local waiting = #(st.queues[checkout] or {})
		if queues[checkout] and waiting < length then
			best, length = checkout, waiting
		end
	end
	if not best or length >= 1 + Shop.QUEUE_LENGTH then
		for _, line in shopper.basket do
			ShopRules.putBack(store, line)
		end
		table.clear(shopper.basket)
		drawDisplays(shopper.owner)
		leave(st, shopper, startAt, "Queue's too long!", Shop.SCORE_LEFT_QUEUE)
		return
	end
	st.queues[best] = st.queues[best] or {}
	table.insert(st.queues[best], shopper)
	shopper.checkout = best
	shopper.spot = #st.queues[best]
	local cells = queues[best]
	local to = queueSpot(st.index, cells, shopper.spot)
	local tail = cells[math.clamp(math.floor((shopper.spot - 1) * 0.5 + 0.5) + 1, 1, #cells)]
	local points = aisle(st.index, store, shopper.cell, tail) or { cellPoint(st.index, shopper.cell) }
	table.insert(points, to)
	shopper.cell = tail
	shopper.stage = "toQueue"
	send(shopper, points, startAt, { say = say, face = displayCentre(st.index, store, best) })
end

-- A new shopper sets off from the woods along the sidewalk.
local function spawn(player: Player, st, store, t: number)
	local wants = ShopRules.wants(store, rng)
	if #wants == 0 then
		return
	end
	lastId += 1
	local shopper = {
		id = lastId, owner = player, plot = st.index, look = rng:NextInteger(1, 1000), wants = wants, basket = {},
		lane = rng:NextNumber(-1, 1), stage = "enter",
	}
	local doorX, doorY = StoreLayout.doorCell()
	shopper.cell = { doorX, doorY }
	st.shoppers[shopper.id] = shopper
	local points = {}
	local approach = PlotLayout.storeApproach(st.index, rng:NextInteger(0, 1) * 2 - 1, shopper.lane)
	for i, p in approach do
		table.insert(points, Vector3.new(p.X, if i == #approach then STEP_Y else SIDEWALK_Y, p.Z))
	end
	table.insert(points, PlotLayout.storeWorld(st.index, doorX, 0.5, FLOOR))
	table.insert(points, cellPoint(st.index, shopper.cell))
	send(shopper, points, t)
end

-- At a display: they decide, then browse a moment and move on.
local function atDisplay(st, shopper, t: number)
	local player = shopper.owner
	local data = DataService.Get(player)
	local target = shopper.target
	shopper.target = nil
	local say = nil
	if data and target then
		local result, line = ShopRules.pick(data.store, target.display, target.crop, rng, MarketService.priceAt())
		local crop = Crops.ById[target.crop]
		if result == "Bought" then
			table.insert(shopper.basket, line)
			say = `{crop.icon or ""}×{line.units}`
			drawDisplays(player)
			if not ShopRules.isOpen(data.store) and not st.soldOutTold then
				st.soldOutTold = true
				Notice.send(player, if #data.store.stockroom > 0
					then "Your store sold out! Fill the displays from the stockroom."
					else "Your store sold out! Send it more crates from the Packing Shed.")
			end
		elseif result == "TooDear" then
			say = `Too dear!`
			shopper.disappointed = true
		else
			say = "Sold out!"
			shopper.disappointed = true
		end
	end
	goNext(st, shopper, t + Shop.BROWSE, say)
end

-- Whether a checkout can serve right now, and how long a shopper takes: a
-- Register while you stand behind it or while a Cashier works it (slower
-- until they're trained), and the Cashier if it's theirs.
local function canServe(st, store, checkout: string): (boolean, number?, any)
	local entry = store.layout[checkout]
	local def = entry and Store.ITEMS[entry.item]
	if not def then
		return false
	end
	if not def.staffed then
		return true, def.serve
	end
	local owner = PlotService.ownerOf(st.index)
	local position = owner and MovementService.positionOf(owner)
	if position and (owner:GetAttribute("InStore") or 0) == st.index then
		local cx, cy = PlotLayout.storeCellAt(st.index, position)
		for _, cell in StoreLayout.behind(entry) do
			if math.abs(cx - cell[1]) <= SERVE_REACH and math.abs(cy - cell[2]) <= SERVE_REACH then
				return true, def.serve
			end
		end
	end
	if owner then
		local cashier, seconds = StoreService.crew.cashier(owner, checkout)
		if cashier then
			return true, math.max(def.serve, seconds), cashier
		end
	end
	return false
end

local function pay(st, shopper, t: number)
	local player = shopper.owner
	local data = DataService.Get(player)
	local coins = 0
	for _, line in shopper.basket do
		coins += line.coins
	end
	table.clear(shopper.basket)
	local checkout = shopper.checkout
	if data and coins > 0 then
		DataService.Earn(player, coins, "StoreSale", true)
		Analytics.step(player, data, "FirstShopSale")
	end
	leave(st, shopper, t, nil, Shop.SCORE_BOUGHT)
	ShopperEvent:FireAllClients("Paid", { plot = st.index, id = shopper.id, coins = coins })
	if data then
		shuffle(st, data.store, checkout, t)
	end
end

local function giveUp(st, shopper, t: number, why: string)
	local data = DataService.Get(shopper.owner)
	if data then
		for _, line in shopper.basket do
			ShopRules.putBack(data.store, line)
		end
		drawDisplays(shopper.owner)
	end
	table.clear(shopper.basket)
	local checkout = shopper.checkout
	leave(st, shopper, t, why, Shop.SCORE_LEFT_QUEUE)
	if data and checkout then
		shuffle(st, data.store, checkout, t)
	end
end

-- Everyone inside heads out, putting their baskets back (the layout just
-- changed under them). Shoppers still on the sidewalk carry on in.
local function clearOut(player: Player, st, t: number)
	local data = DataService.Get(player)
	for _, shopper in st.shoppers do
		if shopper.stage ~= "out" and shopper.stage ~= "enter" then
			if data then
				for _, line in shopper.basket do
					ShopRules.putBack(data.store, line)
				end
				local cx, cy = PlotLayout.storeCellAt(st.index, positionOf(shopper, t))
				shopper.cell = nearestFree(data.store, cx, cy)
			end
			table.clear(shopper.basket)
			table.clear(shopper.wants)
			shopper.checkout = nil
			leave(st, shopper, t, "Oh! It's all moved.", nil)
		end
	end
	table.clear(st.queues)
end

-- Dev command /shoppers N: the next N shoppers come one after another.
function StoreService.Rush(player: Player, count: number)
	local st = stores[player]
	if st then
		st.rush = count
		st.nextAt = now()
	end
end

local function tickShoppers(player: Player, st, t: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local store = data.store
	-- someone new?
	if t >= (st.nextAt or 0) then
		local inside = 0
		for _ in st.shoppers do
			inside += 1
		end
		if ShopRules.isOpen(store) and not st.decorating and inside < StoreLayout.level(store.level).shoppers then
			spawn(player, st, store, t)
			if (st.rush or 0) > 0 then
				st.rush -= 1
				st.nextAt = t + RUSH_GAP
			else
				st.nextAt = t + ShopRules.interval(store) / (1 + StoreService.crew.boost(player)) * rng:NextNumber(0.75, 1.25)
			end
		else
			st.nextAt = t + 1
		end
	end
	-- arrivals
	for _, shopper in st.shoppers do
		if t >= shopper.arriveAt then
			if shopper.stage == "enter" then
				shopper.stage = "inside"
				goNext(st, shopper, t)
			elseif shopper.stage == "toDisplay" then
				atDisplay(st, shopper, t)
			elseif shopper.stage == "toQueue" then
				shopper.stage = "queued"
				shopper.joinedAt = shopper.joinedAt or t
			elseif shopper.stage == "out" then
				remove(st, shopper)
			end
		end
	end
	-- checkouts
	for checkout, queue in st.queues do
		local head = queue[1]
		if head and head.stage == "queued" and head.spot == 1 then
			local ok, seconds, cashier = canServe(st, store, checkout)
			if ok then
				head.stage = "paying"
				head.payAt = t + seconds
				head.cashier = cashier
				head.serveSeconds = seconds
			end
		end
		if head and head.stage == "paying" and t >= head.payAt then
			if head.cashier then
				StoreService.crew.served(player, head.cashier, head.serveSeconds)
			end
			pay(st, head, t)
		end
		for i = #queue, 1, -1 do
			local shopper = queue[i]
			if shopper.stage == "queued" and t - shopper.joinedAt > Shop.PATIENCE then
				local def = store.layout[checkout] and Store.ITEMS[store.layout[checkout].item]
				giveUp(st, shopper, t, if def and def.staffed and not canServe(st, store, checkout) then "Nobody at the till!" else "Too slow!")
			end
		end
	end
end

------------------------------------------------------------------------
-- Levels and buildings

local function moveOutOfWalls(index: number, stage: number)
	local box = PlotLayout.storeBox(stage)
	local frame = PlotLayout.frame(index)
	for _, other in Players:GetPlayers() do
		local position = MovementService.positionOf(other)
		if position then
			local p = frame:PointToObjectSpace(position)
			local inside = p.X > box.min.X - 1.5 and p.X < box.max.X + 1.5 and p.Z > box.min.Z - 1.5 and p.Z < box.max.Z + 1.5
			local onFloor = p.X > box.min.X + 1.5 and p.X < box.max.X - 1.5 and p.Z > box.min.Z + 1.5 and p.Z < box.max.Z - 1.5
			if inside and not onFloor then
				local at = PlotLayout.storeWorld(index, Store.DOOR_X, -1.2, 3)
				MovementService.Teleport(other, CFrame.lookAt(at, PlotLayout.storeWorld(index, Store.DOOR_X, 2, 3)))
			end
		end
	end
end

local function levelUp(player: Player, data, to: number)
	local store = data.store
	local from = store.level
	StoreLayout.grow(store.layout, from, to)
	store.level = to
	store.build = nil
	local before, after = StoreLayout.level(from), StoreLayout.level(to)
	local st = stores[player]
	if after.building ~= before.building then
		if st then
			moveOutOfWalls(st.index, after.stage)
		end
		local gift = after.building.gift
		if gift then
			store.owned[gift] = (store.owned[gift] or 0) + 1
			store.gifts[gift] = (store.gifts[gift] or 0) + 1
			local x, y, rot = StoreLayout.findSpot(store.layout, to, gift)
			if x then
				local id = tostring(store.nextId)
				store.nextId += 1
				store.layout[id] = { item = gift, x = x, y = y, rot = rot, slots = StoreLayout.newSlots(gift) }
			end
			Notice.send(player, if x then `A free {Store.ITEMS[gift].name} is waiting in your new {after.building.name}!`
				else `A free {Store.ITEMS[gift].name} is in My items: place it in Decorate.`, "Good")
		end
	end
	redraw(player)
	Notice.send(player, `Store Level {to}! {table.concat(StoreLayout.news(to), " · ")}`, "Good")
	DataService.NotifyState(player)
end

-- Dev command /store N: straight to Store Level N (up only), buildings done.
function StoreService.SetLevel(player: Player, to: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	to = math.clamp(math.floor(to), 1, #Store.LEVELS)
	data.store.build = nil
	while data.store.level < to do
		levelUp(player, data, data.store.level + 1)
	end
	redraw(player)
end

-- A Stocker's round: up to `units` from the stockroom onto the emptiest
-- displays (not while you're decorating). Returns units moved.
function StoreService.Restock(player: Player, units: number): number
	local st = stores[player]
	local data = DataService.Get(player)
	if not st or not data or st.decorating or units < 1 then
		return 0
	end
	local moved = ShopRules.restockDisplays(data.store, MarketService.priceAt(), units)
	if moved > 0 then
		drawDisplays(player)
		drawStockroom(player)
		DataService.NotifyState(player)
	end
	return moved
end

-- Whether you're decorating (the crew stays out of the way).
function StoreService.IsDecorating(player: Player): boolean
	local st = stores[player]
	return st ~= nil and st.decorating == true
end

-- Redraws the displays and the stockroom (after the offline settlement).
function StoreService.Redraw(player: Player)
	redraw(player)
end

-- Fills one display from the stockroom (the prompt at it, or the Stock tab).
function StoreService.Fill(player: Player, id: string): string?
	local data, st = DataService.Get(player), stores[player]
	if not data or not st then
		return "NoFarm"
	end
	local store = data.store
	if not store.layout[id] then
		return "BadRequest"
	end
	if #store.stockroom == 0 then
		Notice.send(player, "The stockroom is empty. Pack crates at the bench and send them to your Store.", "Error")
		return "Empty"
	end
	local moved = ShopRules.fill(store, id, MarketService.priceAt())
	if moved == 0 then
		Notice.send(player, "Nothing to put out here: it's full, or the stockroom has nothing this display can hold.", "Error")
		return "Full"
	end
	st.soldOutTold = nil
	drawDisplays(player)
	drawStockroom(player)
	DataService.NotifyState(player)
	return nil
end

------------------------------------------------------------------------
-- Actions (the Store window and Decorate)

local actions = {}

local function atHome(player: Player, index: number): boolean
	return PlotService.inFarm(player) == index or (player:GetAttribute("InStore") or 0) == index
end

-- "cropId|coins"
function actions.Price(player, data, arg)
	local cropId, coinsText = string.match(arg or "", "^(%w+)|(%d+)$")
	local coins = tonumber(coinsText)
	if not Crops.ById[cropId] or not coins then
		return "BadRequest"
	end
	ShopRules.setPrice(data.store, cropId, coins, MarketService.price(cropId))
	drawDisplays(player)
	return nil
end

-- "id": one display (at it); "all": every display (in your store)
function actions.Fill(player, data, arg)
	local st = stores[player]
	if not st then
		return "NoFarm"
	end
	if arg == "all" then
		if (player:GetAttribute("InStore") or 0) ~= st.index then
			return "NotInStore"
		end
		if ShopRules.fillAll(data.store, MarketService.priceAt()) == 0 then
			return "NothingToFill"
		end
		st.soldOutTold = nil
		drawDisplays(player)
		drawStockroom(player)
		return nil
	end
	local entry = data.store.layout[arg or ""]
	if not entry then
		return "BadRequest"
	end
	local position = MovementService.positionOf(player)
	local item = PlotService.model(st.index).Store.Items:FindFirstChild(arg)
	if not position or not item or (position - item:GetPivot().Position).Magnitude > StoreService.REACH then
		return "TooFar"
	end
	local failure = StoreService.Fill(player, arg)
	return if failure == "Empty" or failure == "Full" then nil else failure
end

-- "id|slot|cropId" or "id|slot|Auto"
function actions.SetSlot(player, data, arg)
	local id, slotText, cropId = string.match(arg or "", "^(%w+)|(%d+)|(%w+)$")
	if not id then
		return "BadRequest"
	end
	local failure = ShopRules.setSlot(data.store, id, tonumber(slotText) :: number, if cropId == "Auto" then nil else cropId)
	if failure then
		return failure
	end
	drawDisplays(player)
	drawStockroom(player)
	return nil
end

function actions.Upgrade(player, data)
	local store = data.store
	local st = stores[player]
	if not st then
		return "NoFarm"
	end
	if store.build then
		return "Building"
	end
	if store.level >= #Store.LEVELS then
		return "MaxLevel"
	end
	local next = StoreLayout.level(store.level + 1)
	if data.level < next.farmLevel then
		return "NeedsFarmLevel"
	end
	if not DataService.SpendCoins(player, next.cost, Analytics.SHOP, "StoreLevel") then
		return "TooPoor"
	end
	local current = StoreLayout.level(store.level)
	if next.building ~= current.building and next.building.buildSeconds > 0 then
		store.build = { to = next.number, left = next.building.buildSeconds }
		StoreArt.showConstruction(PlotService.model(st.index), next.number, next.building.buildSeconds)
		Notice.send(player, `The builders are on it: your {next.building.name} is ready in {next.building.buildSeconds // 60} minutes. Your {current.building.name} stays open meanwhile.`, "Good")
	else
		levelUp(player, data, next.number)
	end
	return nil
end

-- Your store's name ("" goes back to the default).
function actions.Name(player, data, arg)
	local text = string.gsub(string.gsub(arg or "", "[%c]", ""), "^%s*(.-)%s*$", "%1")
	if text == "" then
		data.store.name = nil
		redraw(player)
		return nil
	end
	if utf8.len(text) == nil or (utf8.len(text) :: number) < 3 or (utf8.len(text) :: number) > Store.NAME_MAX then
		return "BadName"
	end
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(text, player.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or typeof(filtered) ~= "string" or filtered == "" then
		return "FilterFailed"
	end
	data.store.name = filtered
	redraw(player)
	return nil, filtered
end

-- "On": the "Back soon" sign goes up while you rearrange; "Off" when you're done.
function actions.Decorate(player, _data, arg)
	local st = stores[player]
	if not st then
		return "NoFarm"
	end
	if arg == "On" then
		if not atHome(player, st.index) then
			return "NotHome"
		end
		st.decorating = true
		st.decorateAt = now()
	else
		st.decorating = false
	end
	StoreArt.setBackSoon(PlotService.model(st.index), st.decorating)
	return nil
end

-- A layout from Decorate (JSON): { items = { [id] = { item, x, y, rot } |
-- { item, side, at } }, sell = { [itemId] = count } }. Ids already in your
-- layout keep what's on them; new ones are given ids here. Buys what the
-- layout needs that you don't own, sells back what you asked to, and saves
-- it if it passes StoreLayout.check.
function actions.Layout(player, data, arg)
	local st = stores[player]
	if not st then
		return "NoFarm"
	end
	if not atHome(player, st.index) then
		return "NotHome"
	end
	if #(arg or "") > LAYOUT_MAX then
		return "BadRequest"
	end
	local ok, request = pcall(HttpService.JSONDecode, HttpService, arg)
	if not ok or typeof(request) ~= "table" or typeof(request.items) ~= "table" then
		return "BadRequest"
	end
	local store = data.store
	local layout, count = {}, 0
	for id, raw in request.items do
		count += 1
		if typeof(id) ~= "string" or #id > 8 or not string.match(id, "^%w+$") or typeof(raw) ~= "table" or count > 150 then
			return "BadRequest"
		end
		local def = Store.ITEMS[raw.item]
		if not def then
			return "BadRequest"
		end
		if def.kind == "Wall" then
			if typeof(raw.side) ~= "string" or typeof(raw.at) ~= "number" then
				return "BadRequest"
			end
			layout[id] = { item = raw.item, side = raw.side, at = raw.at }
		else
			if typeof(raw.x) ~= "number" or typeof(raw.y) ~= "number" or typeof(raw.rot) ~= "number" then
				return "BadRequest"
			end
			layout[id] = { item = raw.item, x = raw.x, y = raw.y, rot = raw.rot }
		end
	end
	local passes, reason = StoreLayout.check(layout, store.level)
	if not passes then
		return reason
	end
	-- what to buy and sell
	local need = StoreLayout.counts(layout)
	local sell = {}
	if typeof(request.sell) == "table" then
		for itemId, n in request.sell do
			if not Store.ITEMS[itemId] or typeof(n) ~= "number" or n % 1 ~= 0 or n < 0 then
				return "BadRequest"
			end
			sell[itemId] = n
		end
	end
	local cost, buys = 0, {}
	for itemId, def in Store.ITEMS do
		local owned, gifts, selling = store.owned[itemId] or 0, store.gifts[itemId] or 0, sell[itemId] or 0
		if selling > owned - gifts or (selling > 0 and (need[itemId] or 0) > owned - selling) then
			return "CantSell"
		end
		local buy = math.max(0, (need[itemId] or 0) - owned)
		if buy > 0 and def.level > store.level then
			return "Locked"
		end
		buys[itemId] = buy
		cost += buy * def.cost - selling * math.floor(def.cost * Store.SELL_BACK)
	end
	if cost > 0 and not DataService.SpendCoins(player, cost, Analytics.SHOP, "StoreDecor") then
		return "TooPoor"
	elseif cost < 0 then
		DataService.AddCoins(player, -cost, Analytics.GAMEPLAY, "StoreSellBack")
	end
	for itemId in Store.ITEMS do
		local owned = (store.owned[itemId] or 0) + buys[itemId] - (sell[itemId] or 0)
		store.owned[itemId] = if owned > 0 then owned else nil
	end
	-- goods on displays that are going (or changing) go back to the stockroom
	for id, entry in store.layout do
		local kept = layout[id]
		if entry.slots and (not kept or kept.item ~= entry.item) then
			ShopRules.empty(store, id)
		end
	end
	local final = {}
	for id, entry in layout do
		local old = store.layout[id]
		if old and old.item == entry.item then
			entry.slots = old.slots
			final[id] = entry
		else
			entry.slots = StoreLayout.newSlots(entry.item)
			final[tostring(store.nextId)] = entry
			store.nextId += 1
		end
	end
	store.layout = final
	st.decorating = false
	clearOut(player, st, now())
	redraw(player)
	return nil, { cost = cost }
end

------------------------------------------------------------------------

local function startStore(player: Player, index: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	stores[player] = { index = index, shoppers = {}, queues = {}, nextAt = now() + 5 }
	-- a building that went up while you were away (at the offline rate)
	local build = data.store.build
	if build then
		build.left -= DataService.AwaySeconds(player) * Growth.OFFLINE_RATE
		if build.left <= 0 then
			levelUp(player, data, build.to)
		end
	end
	redraw(player)
end

local function stopStore(player: Player, index: number?)
	local st = stores[player]
	stores[player] = nil
	if st then
		ShopperEvent:FireAllClients("Clear", { plot = st.index })
	end
	if index then
		local model = PlotService.model(index)
		model.Store.Items:ClearAllChildren()
		StoreArt.showConstruction(model, nil)
		StoreArt.setBackSoon(model, false)
		StoreArt.build(model)
	end
end

function StoreService.Start()
	StoreItems.buildCatalog()
	ActionRemote(Remotes.func("StoreAction"), actions, DataService, 0.1)

	PlotService.OnAssigned(function(player, index)
		startStore(player, index)
	end)
	PlotService.OnReleased(function(player, index)
		stopStore(player, index)
	end)
	-- Baskets go back on the shelves before the save closes (§4.8: nothing lost).
	DataService.BeforeRelease(function(player, data)
		local st = stores[player]
		for _, shopper in (st and st.shoppers) or {} do
			for _, line in shopper.basket do
				ShopRules.putBack(data.store, line)
			end
			table.clear(shopper.basket)
		end
	end)
	DataService.OnWiped(function(player)
		local st = stores[player]
		if st then
			table.clear(st.shoppers)
			table.clear(st.queues)
			ShopperEvent:FireAllClients("Clear", { plot = st.index })
			redraw(player)
		end
	end)
	-- Players who join see the shoppers already walking.
	Players.PlayerAdded:Connect(function(newcomer)
		newcomer.CharacterAdded:Wait()
		for _, st in stores do
			for _, shopper in st.shoppers do
				if shopper.last then
					ShopperEvent:FireClient(newcomer, "Path", shopper.last)
				end
			end
		end
	end)

	task.spawn(function()
		local lastSecond = now()
		while true do
			task.wait(TICK)
			local t = now()
			local second = t - lastSecond >= 1
			if second then
				lastSecond = t
			end
			for player, st in stores do
				local data = DataService.Get(player)
				if data then
					-- (one store's trouble mustn't stop everyone else's shoppers)
					local ok, err = pcall(tickStore, player, st, data, t, second)
					if not ok then
						warn(`[StoreService] {player.Name}'s store: {err}`)
					end
				end
			end
		end
	end)
end

-- Every TICK for each store: shoppers, the staff door, decorating, a
-- building going up (`second`: a whole second has passed).
function tickStore(player: Player, st, data, t: number, second: boolean)
	tickShoppers(player, st, t)
	local model = PlotService.model(st.index)
	-- the staff door opens for you
	local position = MovementService.positionOf(player)
	local door = model.Store:FindFirstChild("Building") and model.Store.Building:FindFirstChild("StaffDoor")
	local near = position and door and (position - door.Leaf.Position).Magnitude < STAFF_DOOR_REACH
	StoreArt.setStaffDoor(model, near == true)
	-- decorating ends if you wander off or leave it for 5 minutes
	if st.decorating and (not atHome(player, st.index) or t - st.decorateAt > Store.BACK_SOON_IDLE) then
		st.decorating = false
		StoreArt.setBackSoon(model, false)
		Notice.send(player, "Decorating ended: your store is open again.")
	end
	-- a building going up
	local build = data.store.build
	if second and build then
		build.left -= 1
		if build.left <= 0 then
			levelUp(player, data, build.to)
		else
			StoreArt.showConstruction(model, build.to, math.ceil(build.left))
		end
	end
end

return StoreService
