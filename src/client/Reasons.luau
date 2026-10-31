-- What to tell the player when the server says no ({ ok = false, reason }).
-- nil: say nothing (they'll see why, or it doesn't matter).
local REASONS = {
	TooFar = "Get closer.",
	NoFarm = "You don't have a farm in this server.",
	NotHome = "Go to your own farm first.",
	Overgrown = "That land is overgrown. Clear it with a Land Permit.",
	Planted = "Something's already growing there.",
	NoSeeds = "No seeds of that left. Barley sells more in town!",
	NotRipe = "Not ripe yet.",
	NotNeeded = "Already watered this stage.",
	BarnFull = nil, -- (the server sends its own note)
	TooPoor = "Not enough coins.",
	SoldOut = "Sold out until Barley's next restock.",
	NoPermit = "You need a Land Permit: they come with Farm Levels.",
	NotTouching = "Clear land next to land you've already cleared.",
	Busy = "Finish clearing the block you started first.",
	AlreadyOpen = "That land is already cleared.",
	Blocked = "You can't travel right now.",
	NoCharacter = nil,
	Cooldown = nil,
	NotLoaded = "Still loading your farm...",
	NoCrops = "None of those left in your barn.",
	Carrying = "Load the crate you're carrying into the pickup first.",
	NotWashing = "Hold the stamp a little longer.",
	TruckAway = "The truck is out on the road.",
	TruckFull = "The truck is full: send it!",
	TruckEmpty = "Load some crates onto the truck first.",
	StockroomFull = "Your store's stockroom is full and your arms are too: load the pickup first.",
	NotInStore = "Walk into your store first.",
	NothingToFill = "Nothing to put out: the displays are full, or the stockroom has nothing they can hold.",
	CantHold = "That display can't hold that crop.",
	Building = "Your new building is still going up.",
	MaxLevel = "Already at the top level.",
	NeedLevel = "That needs a higher Farm Level.",
	NoCoins = "Not enough coins.",
	NeedWarehouse5 = "Splitting a crop between truck and store comes with Warehouse Level 5.",
	NeedXp = "Their XP bar isn't full yet: workers learn by working.",
	Full = "Every slot for that job is taken: higher levels open more.",
	Hired = "You've already hired them.",
	BoardChanged = "The board just changed: have another look.",
	NeedLevel2 = "Hiring workers comes with Farm Level 2.",
	NeedsFarmLevel = "Your store's next level needs a higher Farm Level.",
	BadName = "A store's name needs 3 to 24 letters.",
	FilterFailed = "That name couldn't be checked right now: try again in a moment.",
	CantSell = "You can't sell that (free items stay yours).",
}

return function(reason: string?, extra: string?): string?
	if reason == "Locked" then
		return extra or "Needs a higher Farm Level."
	end
	return REASONS[reason or ""]
end
