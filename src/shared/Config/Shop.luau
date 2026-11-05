-- Shoppers in your store (docs/GameDesign.md §4.8, shared/DemandModel,
-- shared/ShopRules). The store itself (grid, levels, catalog) is Config/Store.
return {
	-- Shoppers judge your price against ref = REF_BASE × base + (1 − REF_BASE) × market.
	REF_BASE = 0.5,
	-- Each shopper's willingness to pay is log-normal around 1 with this spread ...
	SIGMA = 0.2,
	-- ... times the rating bonus (0 at 1★ up to this at 5★) ...
	RATING_BONUS = 0.25,
	-- ... times the display's presentation (Config/Store) ... times this for grade A crops.
	GRADE_A = 1.15,
	PRICE_MIN = 0.5, -- allowed prices, as a share of the reference
	PRICE_MAX = 3.0,
	UNITS_PER_SHOPPER = 2.5, -- patches' worth a shopper takes of a crop, on average: 1–4 (6–24 carrots, 1–4 pumpkins)
	RATING_WINDOW = 50, -- shoppers the rating averages over
	START_STARS = 3, -- a store nobody has visited yet ...
	RATING_SETTLE = 10, -- ... counts as this many 3★ shoppers until real ones replace them
	-- What each shopper adds to the rating (1–5): they bought; everything
	-- they looked at was too dear (or sold out by the time they got there);
	-- they gave up waiting in the queue. (A store with nothing on display is
	-- closed, so nobody comes to find it empty: a new farm doesn't sink to
	-- 1★ before its first harvest.)
	SCORE_BOUGHT = 5,
	SCORE_TOO_DEAR = 2,
	SCORE_LEFT_QUEUE = 1,

	-- How often shoppers come: every INTERVAL × INTERVAL_DECAY^(Store Level − 1)
	-- seconds at 3★ (20 s at Level 1, 4 s at 20), FLOW_PER_STAR more often for
	-- each star above 3 (less below), VARIETY more for each different crop on
	-- display after the first (up to VARIETY_MAX).
	INTERVAL = 20,
	INTERVAL_DECAY = 0.92,
	FLOW_PER_STAR = 0.15,
	VARIETY = 0.05,
	VARIETY_MAX = 0.25,
	-- (How many shoppers a store holds at once grows with its building: Config/Store.BUILDINGS.)

	-- The visit (StoreService; clients draw them from ShopperEvent).
	SPEED = 8, -- studs a second
	BROWSE = 2.5, -- seconds at each display
	QUEUE_LENGTH = 4, -- shoppers waiting at a checkout, besides the one paying
	PATIENCE = 20, -- seconds a shopper waits in a queue before putting their basket back
	TILL_PATIENCE = 30, -- seconds a shopper waits at a till nobody's serving 

	-- What shoppers say in their bubble (StoreService picks one at random;
	-- the clients colour the bubble by its mood: green good, red bad). When
	-- they buy, what they took goes first ("🥕×12 What a deal!"). How a price
	-- felt is price ÷ what that shopper would pay: under BARGAIN it's a
	-- bargain, over PRICEY they grumble but buy; turned down, over RIP_OFF
	-- they're cross about it. REMARK: the share of other buyers who say
	-- something nice besides what they took.
	--
	-- Each pool has the plain lines and Kiwi slang mixed in (the user,
	-- 2026-11-05: "Instead of british slang, why not add some New Zealand
	-- slang?", then "keep the current ones, add kiwi slang as new ones"), so
	-- anyone gets the gist (the bubble's colour helps too). The Kiwi ones, for
	-- readers elsewhere: sweet as / choice / mean as = great;
	-- chur = thanks, cool; stoked = really happy; hard out = totally; tu meke =
	-- awesome (Māori, "too much"); kai = food (Māori); kia ora = hello, thanks
	-- (Māori); ka kite = see you (Māori); yeah, nah = no; spendy = expensive;
	-- far out = wow; gutted = really disappointed; eh = isn't it; bro, cuz =
	-- mate; over it = fed up.
	LINES = {
		bargain = { "What a deal!", "Bargain!", "So cheap!", "Stocking up!", "Great price!",
			"Sweet as, what a deal!", "Choice price!", "Mean as, so cheap!", "Hard out bargain!", "Tu meke, so cheap!" },
		bought = { "Lovely!", "So fresh!", "Yum!", "Perfect!", "Just what I needed!", "Looks tasty!",
			"Sweet as!", "Choice!", "Chur!", "Mean as!", "Good kai!", "Stoked!" },
		pricey = { "Pricey, but okay.", "A bit steep...", "Worth it, I guess.", "Ouch, my wallet!",
			"Bit steep, eh.", "Far out, pricey!", "Spendy, but worth it." },
		tooDear = { "Too expensive!", "Too pricey for me.", "Not at that price.", "I'll pass.", "Maybe if it was cheaper.",
			"Yeah, nah. Too pricey.", "Bit spendy for me, bro.", "Nah, I'll pass, cuz.", "Too expensive, eh." },
		ripOff = { "What a rip-off!", "Are you kidding?!", "Way too expensive!", "Who'd pay that?!", "Nope! Too much!",
			"Far out, you're joking?!", "Yeah, nah. No way!", "Who'd pay that, bro?!", "Daylight robbery!" },
		soldOut = { "Sold out?!", "Nothing left!", "Empty shelf...", "Aw, it's all gone!", "I came all this way!",
			"Sold out? Gutted!", "Aw, gutted!", "Nothing left, bro!", "Empty shelf, eh?" },
		queueLong = { "Queue's too long!", "Not waiting in that!", "Look at that line!", "I'll come back later.",
			"Yeah, nah. Huge queue.", "Not waiting in that, cuz!", "Far out, what a line!" },
		nobody = { "Hello? Anyone?", "Nobody at the till!", "Where's the cashier?!", "I can't pay anyone!",
			"Kia ora? Anyone?", "Where's the cashier, bro?", "Can't pay anyone, eh!" },
		tooSlow = { "This is taking forever!", "Too slow!", "Terrible service!", "I've waited long enough!",
			"Taking forever, eh!", "Far out, so slow!", "Hurry up, cuz!", "Over it! I'm off." },
		thanks = { "Thanks!", "See you soon!", "Great shop!", "Have a nice day!", "I'll be back!", "Love this place!",
			"Chur!", "Cheers, bro!", "Ka kite!", "Sweet as, thanks!", "Choice shop!", "Kia ora!" },
		moved = { "Oh! It's all moved.", "Huh? Where'd it go?", "They moved everything!",
			"Eh? Where'd it go?", "Huh, it's all different!" },
	},
	MOODS = { bargain = "good", bought = "good", thanks = "good", tooDear = "bad", ripOff = "bad", soldOut = "bad",
		queueLong = "bad", nobody = "bad", tooSlow = "bad" }, -- (pricey and moved: plain)
	BARGAIN = 0.65,
	PRICEY = 0.92,
	RIP_OFF = 1.6,
	REMARK = 0.5,
}
