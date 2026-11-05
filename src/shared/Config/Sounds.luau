-- Sound effects, ambience and music (client/Sfx plays them; the Settings
-- window switches each kind off). Each id is either a sound from the
-- Creator Store (Toolbox > Audio: right-click > Copy Asset ID), or one of
-- our own files (tools/sound_art: generate.py -> art/sounds/<Name>.wav, or
-- stock.py cutting downloaded effects -> art/sounds/stock/<Name>.wav, uploaded
-- via Window > Asset Manager > Import), pasted as "rbxassetid://123...". An
-- empty id is silent until it's filled in.
--   volume  0–1 (Roblox's default is 0.5); the generated files are made
--           about as loud as each other, so these balance them by ear
--   range   for sounds from a place in the world: studs you can hear it
--           from (nil = straight to you)
--   kind    the Settings switch it follows: "sfx" (default), "ambience" or "music"
--   loop    plays on repeat (AmbienceController)
--   file    our file (art/sounds/<file>.wav) waiting for an id
return {
	-- The interface
	UiClick = { id = "rbxassetid://88442833509532", volume = 0.35 }, -- a button pressed (Toolbox: "ui-simple-button")
	Error = { id = "rbxassetid://113054878201320", volume = 0.4 }, -- something didn't work (with the red note)
	Pop = { id = "rbxassetid://132948338000932", volume = 0.45 }, -- a yellow note pinned up (Toolbox: "bubble pop")
	Buy = { id = "rbxassetid://17161225362", volume = 0.6 }, -- spent coins on something (Toolbox: "Purchase")
	QuestReward = { id = "rbxassetid://119804136935260", volume = 0.7 }, -- a quest or the streak paid out (Toolbox: "Quest Rewards")
	LevelUp = { id = "rbxassetid://117752554651437", volume = 0.7 }, -- a Farm Level (the rosette)

	-- The field and selling
	Plant = { id = "rbxassetid://125870602927631", volume = 0.7, range = 60 }, -- a seed pressed into the soil
	Water = { id = "rbxassetid://127598229129673", volume = 0.55, range = 60 }, -- the watering can
	Harvest = { id = "rbxassetid://116296368014389", volume = 0.75, range = 60 }, -- a ripe crop pulled up
	Tape = { id = "rbxassetid://91031127833052", volume = 0.6, range = 50 }, -- a crate taped shut at the bench
	TruckHorn = { id = "rbxassetid://136188466468170", volume = 0.5, range = 160 }, -- a truck leaving for the City, BEEP BEEP
	CashRegister = { id = "rbxassetid://78098348517133", volume = 0.75 }, -- a truck back with its pay (the receipt)
	Coins = { id = "rbxassetid://330274138", volume = 0.45, range = 60 }, -- a shopper paying at your checkout (Toolbox: "Coin Drop")
	Scan = { id = "rbxassetid://92339580904806", volume = 0.45, range = 40 }, -- a thing scanned at a till (you serving, beep)
	ShopBell = { id = "rbxassetid://96498594503125", volume = 0.55, range = 70 }, -- the bell over the door: a shopper coming in
	CheckoutBell = { id = "rbxassetid://100820370804120", volume = 0.6, range = 70 }, -- a shopper waiting at a till rings its counter bell
	TillOpen = { id = "rbxassetid://78098348517133", volume = 0.6, range = 50 }, -- a shopper paid at a till: the drawer pops open

	-- Raids
	Siren = { id = "rbxassetid://74146667152417", volume = 0.5 }, -- the theft alarm, to the farm's owner
	Swing = { id = "rbxassetid://127183292018512", volume = 0.5, range = 70 }, -- a bat swung (Toolbox: "whoosh!")
	Bonk = { id = "rbxassetid://138623948792634", volume = 0.8, range = 120 }, -- a bat on a head
	Whistle = { id = "rbxassetid://122468852918635", volume = 0.45 }, -- an arrest (the thief and the farmer hear it)
	Rustle = { id = "rbxassetid://110799075723352", volume = 0.55, range = 50 }, -- a crop being stolen shakes
	AlarmBell = { id = "rbxassetid://83583675194808", volume = 0.5, range = 220 }, -- the yard's alarm bell defence
	DogAlert = { id = "rbxassetid://79380366540360", volume = 0.7, range = 140 }, -- the guard dog's alert, with the ! over its head

	-- The auction
	AuctionBell = { id = "rbxassetid://106399723585350", volume = 0.8, range = 400 }, -- the hall's bell when an auction starts (Toolbox: "Bell Toll")
	Gavel = { id = "rbxassetid://71171463585790", volume = 0.8, range = 120 }, -- going once, going twice, SOLD!
	AuctionTick = { id = "rbxassetid://97496959493956", volume = 0.5 }, -- each of a lot's last ten seconds, to anyone in the hall
	Outbid = { id = "rbxassetid://126068083170160", volume = 0.6 }, -- someone's topped your bid
	BidWon = { id = "rbxassetid://103375652197392", volume = 0.7 }, -- the lot is yours: a crowd cheers

	-- Weather
	Thunder = { id = "rbxassetid://102164464566453", volume = 0.8 }, -- after a lightning flash (Toolbox: "thunderstorm 2")
	Rain = { id = "rbxassetid://139353385715659", volume = 0.3, kind = "ambience", loop = true }, -- rain and storms, muffled indoors

	-- Ambience (AmbienceController: by the time of day)
	Birds = { id = "rbxassetid://93154868192074", volume = 0.25, kind = "ambience", loop = true }, -- songbirds and a breeze by day, a short spell now and then, out of doors
	Crickets = { id = "rbxassetid://126041966128858", volume = 0.2, kind = "ambience", loop = true }, -- crickets at night, a short spell now and then, out of doors

	-- Music
	FarmTheme = { id = "rbxassetid://122857322293981", volume = 0.25, kind = "music", loop = true }, -- a banjo rolling through G, C and D, out of doors in town
}
