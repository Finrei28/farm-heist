-- Defences (docs/GameDesign.md §4.11; shared/DefenceRules, server
-- DefenceService, World/DefenceArt). Bought with coins in the Defences
-- window from a Farm Level (never with Robux, §7), then set out on your
-- farm. None of them blocks a thief: they warn, slow or expose, and the bat
-- does the rest.
--
-- spot: where one stands (shared/PlotLayout.defenceSpots):
--   "yard"  a 12-stud spot in the ring round the field (glowing while you
--           place it: the scarecrow, the kennel, mud),
--   "tile"  an open field tile (the cloche covers its crop),
--   "gate" · "fence" · "camera" · "floods"  its own fixed place, set up as
--           you buy it.
-- max: how many a farm can have.
-- They open one at a time over the first two weeks or so of play (Farm
-- Level 5 to 24, about 3M coins for the lot: §4.11's raid race), so a
-- farm is never sealed early and a thief always has a way to a crop.
return {
	ITEMS = {
		Scarecrow = {
			name = "Scarecrow", icon = "🌾", cost = 25_000, level = 5, max = 1, spot = "yard",
			blurb = "Warns you when someone who isn't Trusted comes near your field.",
			detail = "Anyone within 25 studs of the field",
		},
		GateLock = {
			name = "Gate Lock", icon = "🔒", cost = 80_000, level = 8, max = 1, spot = "gate",
			blurb = "Only you and Trusted friends walk in. Anyone else has to climb the gate, which makes them a Suspect.",
			detail = "Climbing the gate takes 2 s · walking out is always free",
		},
		Floodlights = {
			name = "Floodlights", icon = "💡", cost = 120_000, level = 10, max = 1, spot = "floods",
			blurb = "Four lamps on posts at your field's corners. At night anyone in your field shows a red outline on your screen, and name tags on your farm show from afar, like by day.",
			detail = "On at night · without them, name tags only show within 20 studs after dark",
		},
		TallFence = {
			name = "Tall Back Fence", icon = "🪵", cost = 300_000, level = 12, max = 1, spot = "fence",
			blurb = "A close-boarded back fence, 11 studs high: a thief climbing out over it with your crop takes 3 s instead of 1.5 s.",
			detail = "Climbing in, or out empty-handed, is no slower",
		},
		GuardDog = {
			name = "Guard Dog", icon = "🐕", cost = 600_000, level = 16, max = 1, spot = "yard",
			blurb = "Lives in a kennel by the field. It barks when someone starts stealing near it, then runs at the thief once they have the crop, slowing them for 2 s.",
			detail = "Guards crops within 30 studs of its kennel · −30% speed · once every 20 s",
		},
		Cloche = {
			name = "Glass Cloche", icon = "🔮", cost = 30_000, level = 14, max = 16, spot = "tile",
			blurb = "A glass dome over one tile: stealing what grows under it takes 40% longer.",
			detail = "Put them over your rarest crops",
		},
		Camera = {
			name = "Security Camera", icon = "📹", cost = 800_000, level = 22, max = 1, spot = "camera",
			blurb = "The theft alarm shows a live picture of the thief, even when you're away, and the camera keeps a list of who came in.",
			detail = "On the barn, looking over the field",
		},
		MudPatch = {
			name = "Mud Patch", icon = "🟫", cost = 200_000, level = 24, max = 4, spot = "yard",
			blurb = "A 12 × 12 patch of thick mud: anyone but you and your Trusted friends walks through it 20% slower.",
			detail = "Put it where thieves run to the back fence",
		},
	},
	-- The order they're listed in (the Defences window), cheapest level first.
	ORDER = { "Scarecrow", "GateLock", "Floodlights", "TallFence", "Cloche", "GuardDog", "Camera", "MudPatch" },

	SCARECROW_RANGE = 25, -- studs from the field's edge
	SCARECROW_GAP = 60, -- seconds before the scarecrow warns you about the same person again
	DOG_RANGE = 30, -- studs from the kennel: thefts the dog runs at
	DOG_RUN = 32, -- studs a second, there and back
	MUD_SLOW = 0.2,
	NIGHT_TAGS = 20, -- studs: how far name tags show at night (§4.14), except on a farm with Floodlights
	VISITOR_LOG = 30 * 60, -- the camera's list of who came in: this far back ...
	VISITOR_MAX = 20, -- ... and at most this many

	TRUSTED_MAX = 10,
}
