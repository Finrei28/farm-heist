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
}

return function(reason: string?, extra: string?): string?
	if reason == "Locked" then
		return extra or "Needs a higher Farm Level."
	end
	return REASONS[reason or ""]
end
