-- The Farm Guide for new players (docs/GameDesign.md §4.0, shared/GuideRules):
-- a checklist card ticked off by the server as each step is really done,
-- with a marker over the spot and the HUD button you need pulsing
-- (client GuideController). Finishing pays REWARD_COINS once.
return {
	REWARD_COINS = 3_000,
	PLANT_COUNT = 5, -- the free Carrot seeds (Config/Settings.START_SEEDS)

	-- In order; `where` is what the marker points at (GuideController).
	STEPS = {
		{ id = "Plant", text = "Plant your 5 free Carrot seeds", hint = "Stand on the open soil, press Plant and pick your Carrot seeds.", where = "soil" },
		{ id = "Water", text = "Water them", hint = "Stand on a seedling and press Water: it grows faster.", where = "seedling" },
		{ id = "Harvest", text = "Harvest when they pop", hint = "Ripe crops bounce and sparkle. Press Harvest.", where = "ripe" },
		{ id = "Pack", text = "Pack a crate at the Packing Shed", hint = "Pick 🚚 Truck, then hold WASH and let go in the green.", where = "bench" },
		{ id = "Dispatch", text = "Send your pickup to the City", hint = "Load the crate on the truck and pull the lever.", where = "lever" },
		{ id = "Seeds", text = "Buy seeds from Barley in town", hint = "Press TOWN, then talk to Barley at the seed rack. HOME brings you back.", where = "barley" },
		{ id = "Store", text = "Stock your store", hint = "Pack a crate for 🏪 Store, then press Stock at a display and pick your crop.", where = "display" },
		{ id = "Serve", text = "Serve a shopper at your counter", hint = "Step in by the staff door, behind the counter: press Scan for each thing, then take the coins.", where = "till" },
		{ id = "Hire", text = "Hire your first worker", hint = "Patty's job board at the Hiring Hall, in town. The first one's free!", where = "jobboard" },
	},
}
