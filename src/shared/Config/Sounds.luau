-- Sound effects, ambience and music (client/Sfx plays them; the Settings
-- window switches each kind off). Each id is either a sound from the
-- Creator Store (Toolbox > Audio: right-click > Copy Asset ID), or one of
-- our own generated files (tools/sound_art/generate.py -> art/sounds/<Name>.wav,
-- uploaded via Window > Asset Manager > Import), pasted as
-- "rbxassetid://123...". An empty id is silent until it's filled in.
--   volume  0–1 (Roblox's default is 0.5); the generated files are made
--           about as loud as each other, so these balance them by ear
--   range   for sounds from a place in the world: studs you can hear it
--           from (nil = straight to you)
--   kind    the Settings switch it follows: "sfx" (default), "ambience" or "music"
--   loop    plays on repeat (AmbienceController)
--   file    our generated file (art/sounds/<file>.wav) waiting for an id
return {
	-- The interface
	UiClick = { id = "rbxassetid://88442833509532", volume = 0.35 }, -- a button pressed (Toolbox: "ui-simple-button")
	Error = { id = "", file = "Error", volume = 0.4 }, -- something didn't work (with the red note)
	Pop = { id = "rbxassetid://132948338000932", volume = 0.45 }, -- a yellow note pinned up (Toolbox: "bubble pop")
	Buy = { id = "rbxassetid://17161225362", volume = 0.6 }, -- spent coins on something (Toolbox: "Purchase")
	QuestReward = { id = "rbxassetid://119804136935260", volume = 0.7 }, -- a quest or the streak paid out (Toolbox: "Quest Rewards")
	LevelUp = { id = "", file = "LevelUp", volume = 0.7 }, -- a Farm Level (the rosette)

	-- The field and selling
	Plant = { id = "", file = "Plant", volume = 0.7, range = 60 }, -- a seed pressed into the soil
	Water = { id = "", file = "Water", volume = 0.55, range = 60 }, -- the watering can
	Harvest = { id = "", file = "Harvest", volume = 0.75, range = 60 }, -- a ripe crop pulled up
	Tape = { id = "", file = "Tape", volume = 0.6, range = 50 }, -- a crate taped shut at the bench
	TruckHorn = { id = "", file = "TruckHorn", volume = 0.5, range = 160 }, -- a truck leaving for the City, BEEP BEEP
	CashRegister = { id = "", file = "CashRegister", volume = 0.75 }, -- a truck back with its pay (the receipt)
	Coins = { id = "rbxassetid://330274138", volume = 0.45, range = 60 }, -- a shopper paying at your checkout (Toolbox: "Coin Drop")

	-- Raids
	Siren = { id = "", file = "Siren", volume = 0.3 }, -- the theft alarm, to the farm's owner
	Swing = { id = "rbxassetid://127183292018512", volume = 0.5, range = 70 }, -- a bat swung (Toolbox: "whoosh!")
	Bonk = { id = "", file = "Bonk", volume = 0.8, range = 120 }, -- a bat on a head
	Whistle = { id = "", file = "Whistle", volume = 0.45 }, -- an arrest (the thief and the farmer hear it)
	Rustle = { id = "", file = "Rustle", volume = 0.55, range = 50 }, -- a crop being stolen shakes
	AlarmBell = { id = "", file = "AlarmBell", volume = 0.5, range = 220 }, -- the yard's alarm bell defence
	Bark = { id = "", volume = 0.7, range = 140 }, -- the guard dog (still to pick: Toolbox "dog bark", Roblox's own uploads)

	-- The auction
	AuctionBell = { id = "rbxassetid://106399723585350", volume = 0.8, range = 400 }, -- the hall's bell when an auction starts (Toolbox: "Bell Toll")
	Gavel = { id = "", file = "Gavel", volume = 0.8, range = 120 }, -- SOLD!

	-- Weather
	Thunder = { id = "rbxassetid://102164464566453", volume = 0.8 }, -- after a lightning flash (Toolbox: "thunderstorm 2")
	Rain = { id = "", file = "Rain", volume = 0.3, kind = "ambience", loop = true }, -- rain and storms

	-- Ambience (AmbienceController: by the time of day)
	Birds = { id = "", file = "Birds", volume = 0.35, kind = "ambience", loop = true }, -- songbirds and a breeze by day
	Crickets = { id = "", file = "Crickets", volume = 0.3, kind = "ambience", loop = true }, -- crickets at night

	-- Music
	FarmTheme = { id = "", file = "FarmTheme", volume = 0.25, kind = "music", loop = true }, -- a banjo rolling through G, C and D
}
