# Farm Heist: Play-test log

One entry per session, newest first. Cases and pass bars are in [PlaytestPlan.md](PlaytestPlan.md). Use first names or "Tester 3"; no personal details.

## Template (copy this)

```
### YYYY-MM-DD · Stage X · build <git commit or date+time>
Testers: <who / how many> · Setup: <solo / Clients and Servers × N / private server> · Lag: <0 / 0.2 s>

| Case | Result (numbers, 3 runs) | Pass? | Notes |
|---|---|---|---|
| A1 | 14.1 / 14.6 / 14.3 s | ✓ | |

Bugs: <what, how to reproduce>
Changes made because of this session: <Config / PlotLayout values, and the new tools/raidrace or tools/progression result>
Follow-ups: <what to test next time>
```

## Sessions

### 2026-11-05 · the bat skins remade · build: uncommitted, with the fixes below
Testers: Claude, driving Studio (the published "Farm Heist" place) · Setup: solo Play; each skin built by `CrimeArt.bat` from the Server command bar and put in the character's hand, so the save wasn't touched; `Pose_slow` and a longer trail to catch the swing; Bonk events fired from the server to see the burst

| Case | Result | Pass? | Notes |
|---|---|---|---|
| Found: the Golden Bat came out lemon yellow, flat and bleaching its neighbours | Neon brightens a colour a lot, the halo sat over the bat, and the light turned the grass and the bats beside it pale ([01](playtest/2026-11-05-bat-skins/01-first-try-lemon-and-washing-out-its-neighbours.jpg)) | ✓ | fixed: three golds tried side by side ([02](playtest/2026-11-05-bat-skins/02-three-golds-side-by-side.jpg)), the warm one kept: 205, 112, 22 reads as gold on screen; the halo goes behind the bat; the light 2 → 0.8, range 12 → 8; the rings plain, so its stages show |
| Golden Bat in hand | gold over the shoulder, its crown past the head, the halo behind it, the ruby pommel at the chest ([03](playtest/2026-11-05-bat-skins/03-golden-bat-in-hand.jpg)) | ✓ | |
| Baguette in hand | reads as a loaf at once, slashes showing from every side ([04](playtest/2026-11-05-bat-skins/04-baguette-in-hand.jpg)) | ✓ | |
| Carrot Club in hand | held by the root, the fat end and its leaves over the shoulder ([05](playtest/2026-11-05-bat-skins/05-carrot-club-in-hand.jpg)) | ✓ | the crop's own meshes, already in the place |
| The swing | a broad gold sweep behind the bat all the way round ([06](playtest/2026-11-05-bat-skins/06-golden-swing-trail-slowed.jpg): slowed, with a longer trail to catch it) | ✓ | |
| The bonk | a bigger BONK! and gold sparkles out over the stars ([07](playtest/2026-11-05-bat-skins/07-golden-bonk-burst.jpg)) | ✓ | |
| At night | the best it looks: a flare behind the crown, the character lit gold, no glare ([08](playtest/2026-11-05-bat-skins/08-golden-bat-at-night.jpg)) | ✓ | |
| The Style tab | the new line fits the Golden Bat's card on two lines ([09](playtest/2026-11-05-bat-skins/09-style-tab.jpg)) | ✓ | |

Flagged: the Style tab shows an emoji for each skin, so nobody sees a bat before paying: later, a picture on each card. Both passes show Owned on the user's account, and `UserOwnsGamePassAsync` says true for both: leave, it's Roblox's real answer; a real purchase on another account is still untested. "ContentId rbxassetid://203785492" at every Play: leave, as before.

### 2026-11-05 · Barley and Patty on the shared body, the shelf panel · build: uncommitted, with the fixes below
Testers: Claude, driving Studio (the published "Farm Heist" place) · Setup: solo Play; `/tp barley`, Patty from the Hiring Hall's porch, close cameras from the command bar; a crate of carrots (72) and one of Bell Peppers (24, a Rare) put in the store's stockroom with `/crops` and the bench's own Wash and Pack; E at a Produce Crate and the Wooden Shelf (walked to with `Humanoid:MoveTo`); Studio's phone view (iPhone 17 Pro, landscape) for the panel · Lag: 0 (local) · Screenshots: [playtest/2026-11-05-shelf-panel/](docs/playtest/2026-11-05-shelf-panel/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| Barley | at his counter: straw hat with the green band, white hair and beard, red shirt and denim dungarees, the packet held out ([01](docs/playtest/2026-11-05-shelf-panel/01-barley-at-his-counter.jpg)) | ✓ | |
| Found: his moustache sat on the smile | the face's smile is higher than the stand-in in the renders: the moustache covered its top, its corners poking out ([02](docs/playtest/2026-11-05-shelf-panel/02-moustache-on-the-smile.jpg)) | ✓ | fixed: no moustache; the beard sits under the smile ([03](docs/playtest/2026-11-05-shelf-panel/03-barley-beard-under-the-smile.jpg)) |
| Patty | auburn bun, a smile, teal cardigan over a white blouse, the clipboard in both hands beside the job board ([04](docs/playtest/2026-11-05-shelf-panel/04-patty-at-the-job-board.jpg)) | ✓ | |
| E at a Produce Crate | the panel: "Produce Crate" on its sign, no tabs, Auto with the gold edge, Carrot 72 in stock at 20 with FILL, the other unlocked crops OUT OF STOCK, Bell Pepper greyed "Needs a Wooden Shelf" ([05](docs/playtest/2026-11-05-shelf-panel/05-panel-produce-crate.jpg)); Carrot filled it ("72 carrots out on your Produce Crate!") and the panel closed, the prompt reading "Produce Crate 72/72 · stockroom 0" ([06](docs/playtest/2026-11-05-shelf-panel/06-crate-filled-panel-closed.jpg)) | ✓ | the prompt reaches 8 studs: from the middle of the cell in front it's 8.8 away, so you step up to the display (as before) |
| E at the Wooden Shelf | two slot tabs ([07](docs/playtest/2026-11-05-shelf-panel/07-panel-wooden-shelf-slot-tabs.jpg)); the out-of-stock Carrot gave the tip; Bell Pepper filled Slot 1, the panel stayed open, its tab got a 🌶, the card the gold edge ([08](docs/playtest/2026-11-05-shelf-panel/08-out-of-stock-tip-and-bell-peppers-filled.jpg)); Slot 2 empty, Bell Pepper not listed there (out of stock, and Rares not unlocked at Farm Level 2) ([09](docs/playtest/2026-11-05-shelf-panel/09-slot-2.jpg)) | ✓ | |
| Found: polish | the second row's tags were cut off in Studio's 490-pixel view; "It: empty." on a one-slot crate; "No Carrot in your stockroom" | ✓ | fixed: cards 132 tall (were 152), "Empty. Pick a crop to fill it.", "No carrots in your stockroom" |
| On a phone | fits the screen: tabs, the slot's line, a full row and the next one peeking in ([10](docs/playtest/2026-11-05-shelf-panel/10-phone-panel.jpg)); a tap switches the tab ([11](docs/playtest/2026-11-05-shelf-panel/11-phone-slot-2-tapped.jpg)); walking away closes it ([12](docs/playtest/2026-11-05-shelf-panel/12-phone-walked-away-closed.jpg)) | ✓ | |

Noticed in passing: while the shelf was full a shopper waited at the counter with the "Serve me!" bell (no Cashier: as built). XD2MUCH's save: 72 carrots on a Produce Crate and 24 Bell Peppers on the Wooden Shelf (some sold since), both from crops added with `/crops`; the Wooden Shelf's slot 1 is kept to Bell Pepper, the crate to Carrot.

### 2026-11-05 · the workers on the shoppers' body · build: uncommitted, with the fixes below
Testers: Claude, driving Studio (the published "Farm Heist" place) · Setup: an edit-mode gallery from the command bar (every job's worker in a row and ten shoppers in caps or beanies, `client/People` cloned so nothing was cached; removed after); then solo Play with seven hired by `/hire` (Farmhand, Shed Hand, Driver, Stocker, Cashier, Greeter, Watchman: the Sorter, Packer and Loader have no warehouse on this farm to stand at); stand-in workers sent to my client only from the server's command bar (`WorkerEvent` "Crew" and "Do": one on strike, the warehouse jobs, walks with and without a crate), so the save never went on strike; the seven let go after (`WorkerAction` "Fire") · Lag: 0 (local) · Screenshots: [playtest/2026-11-05-worker-art/](docs/playtest/2026-11-05-worker-art/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| Every job by eye, in Studio's light | each uniform reads at a glance from a player's height ([06](docs/playtest/2026-11-05-worker-art/06-every-job-from-player-height.jpg)); the Watchman's raincoat, guard's cap and badge at the gatehouse window ([05](docs/playtest/2026-11-05-worker-art/05-watchman-greeter-cashier.jpg), [08](docs/playtest/2026-11-05-worker-art/08-watchman-at-the-gatehouse.jpg)); Daisy the Farmhand at the back of the field ([07](docs/playtest/2026-11-05-worker-art/07-farmhand-in-the-field.jpg)) | ✓ | |
| Found: caps and the hard hat hid the eyes | only the smile showed under a cap (shoppers' too, and their beanies), and a bun poked out of the top of a cap like a ball ([01](docs/playtest/2026-11-05-worker-art/01-caps-hid-the-eyes.jpg)) | ✓ | fixed: caps, beanies and hard hats sit higher and tipped back 10°, a bun goes low at the nape under any hat ([02](docs/playtest/2026-11-05-worker-art/02-caps-raised-eyes-show.jpg), [03](docs/playtest/2026-11-05-worker-art/03-loader-driver-after.jpg), [04](docs/playtest/2026-11-05-worker-art/04-shoppers-caps-beanies-after.jpg)). From above the hard hat's brim still shades the eyes, as a brim does |
| Found: the Stocker stood in the Cashier | behind the Shop Counter, arms through each other and the two name tags printed over each other ([09](docs/playtest/2026-11-05-worker-art/09-stocker-on-the-cashier.jpg)) | ✓ | fixed: Stockers wait on a free cell by the staff door (`StoreLayout.stockerSpot`: not on a thing, behind a till, a door, a display's front or a queue; outside the staff door if none), their tag a line higher: the corner by the front wall in the start layout ([10](docs/playtest/2026-11-05-worker-art/10-stocker-in-the-corner.jpg)) |
| Found while reading the code: the crew didn't move after Decorate | a Cashier kept standing where the till used to be until something else redrew the crew | ✓ | fixed: DONE in Decorate and a Store Level up move the crew (`StoreService.crew.moved`) |
| On strike | sitting on the crate, the ON STRIKE sign held up ([11](docs/playtest/2026-11-05-worker-art/11-on-strike.jpg)) | ✓ | |
| Found: carrying on the wrong leg | the crate showed both ways on every walk | ✓ | fixed: a Loader carries the crate out and walks back empty ([12](docs/playtest/2026-11-05-worker-art/12-loader-carrying-out.jpg)); a Farmhand walks out empty and brings the harvest back ([13](docs/playtest/2026-11-05-worker-art/13-farmhand-walking-out-empty.jpg) → [14](docs/playtest/2026-11-05-worker-art/14-farmhand-carrying-back.jpg)) |
| Studio | a walk sent to start in the future is dropped by the client (it reads as already over): send `at` = now | ✓ | (only from the command bar; the server always sends now) |

Noticed in passing: Barley and Patty in town still have the old ball heads (offered to the user). XD2MUCH's save: seven workers hired and let go (a few minutes' wages), nothing else.

### 2026-11-05 · what shoppers say (plain and Kiwi), which way they face, the HUD's ropes · build: uncommitted, with the fix below
Testers: Claude, driving Studio (the published "Farm Heist" place) · Setup: solo Play; a client hook printing every line a shopper said in my store with its mood (`ShopperEvent` "Path" with `say`); carrots packed for the store by the WarehouseAction remote, `StoreAction Fill all`, `Price Carrot|20 / 60 / 27 / 32`, `/shoppers N`, `/hire Cashier`, the Workers window's Let go, Decorate → DONE from the Store window; the shelf's stock read off its Fill prompt · Lag: 0 (local) · Screenshots: [playtest/2026-11-05-shopper-lines/](docs/playtest/2026-11-05-shopper-lines/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| The ropes | the coin sign's and the clock's ropes run off the top of the screen ([01](docs/playtest/2026-11-05-shopper-lines/01-ropes-to-the-top.jpg)) | ✓ | |
| Facing | a shopper picking at the shelf faces the shelf, not the till, while their bubble shows ([02](docs/playtest/2026-11-05-shopper-lines/02-facing-the-shelf-while-picking.jpg), [03](docs/playtest/2026-11-05-shopper-lines/03-green-bubble-stoked.jpg)); turns ease round | ✓ | |
| Every kind of line, in play | over 100 lines logged: bargain ("Tu meke, so cheap!", "Choice price!", "Hard out bargain!", "So cheap!"), a remark ("Lovely!", "Stoked!", "Good kai!", "Just what I needed!", "Chur!"), pricey ("Ouch, my wallet!", "Far out, pricey!", "A bit steep...", "Pricey, but okay."), too dear ("Not at that price.", "Yeah, nah. Too pricey.", "Nah, I'll pass, cuz.", "Maybe if it was cheaper."), rip-off at 60 ("What a rip-off!", "Far out, you're joking?!", "Are you kidding?!", "Who'd pay that?!"), queue too long ("Not waiting in that, cuz!", "I'll come back later."), nobody at the till ("Hello? Anyone?", "Kia ora? Anyone?", "Where's the cashier, bro?", "I can't pay anyone!"), too slow while I stood behind the till ("I've waited long enough!", "Too slow!"), thanks at the till ("Great shop!", "Chur!", "Ka kite!", "Cheers, bro!", "Choice shop!", "Love this place!"), sold out with 18 carrots out and six shoppers in ("Sold out? Gutted!", "I came all this way!", "Empty shelf...", "Nothing left, bro!"), moved, pressing DONE with shoppers waiting at an unserved till ("Eh? Where'd it go?", "Huh? Where'd it go?") ([07](docs/playtest/2026-11-05-shopper-lines/07-log-52-lines.jpg), [08](docs/playtest/2026-11-05-shopper-lines/08-log-pricey-and-thanks.jpg), [09](docs/playtest/2026-11-05-shopper-lines/09-log-sold-out.jpg), [10](docs/playtest/2026-11-05-shopper-lines/10-log-moved-after-decorate.jpg)) | ✓ | "moved" needs shoppers still inside at DONE: with a Cashier they'd all paid and gone (Decorate's "Back soon" sends them to pay) |
| Bubbles | pleased ones pale green ([04](docs/playtest/2026-11-05-shopper-lines/04-green-bubbles-good-kai-lovely.jpg), [05](docs/playtest/2026-11-05-shopper-lines/05-so-cheap-with-basket.jpg)), cross ones pink ([06](docs/playtest/2026-11-05-shopper-lines/06-red-bubble-maybe-if-cheaper.jpg)), the rest cream | ✓ | |
| The user, mid-check: "Do products get returned to the shelves when they leave without paying?" | yes: the shelf held 85, two shoppers took 30 while three gave up at the unserved till, and it read 99 after: their 44 went back ([11](docs/playtest/2026-11-05-shopper-lines/11-stock-before-give-ups.jpg) → [12](docs/playtest/2026-11-05-shopper-lines/12-stock-after-give-ups.jpg)) | ✓ | back onto the display they came from if it still holds that crop and has room, the rest to the stockroom |
| Found: the Farm Level 2 card stuck on screen | it came up just as I opened Decorate; Decorate hid it, then put it back on at DONE (after its own 5 s timer had already run) and it never went | ✓ | fixed: DONE only brings back what was on screen before Decorate opened; the level-up card shows over Decorate like notes. Checked: a slip shown mid-decorate stays off after DONE, the hotbar comes back |
| Studio | the first click on DONE after using the command bar only focuses the game window (not the game) | ✓ | |

Noticed in passing: the market ticker under the purse hides when your barn is empty and no market event is on (as built). XD2MUCH's save took Farm Level 2 from the sales; Carrot is priced at 20 in the store again; a Cashier (Abe) hired and let go.

### 2026-11-05 · the user's play-test notes: the staff door, seeds, E, our prompts, the paths, the checkout; then new customers · build: uncommitted, with the fixes below
Testers: Claude, driving Studio (the published "Farm Heist" place, now a live editing session) · Setup: solo Play, then the same on an emulated iPhone 17 Pro; props GLB re-imported twice (the path tiles, then their tweak); `/time noon`, `/tp field 1`, `/tp shed`, `/tp store`, `/crops Carrot`, packing by the WarehouseAction remote, `StoreAction Fill all`, `/shoppers N`, `/store 3`, `/hire Cashier 3`; shoppers' positions sampled from the command bar · Lag: 0 (local) · Screenshots: [playtest/2026-11-05-checkout/](docs/playtest/2026-11-05-checkout/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| The staff door | walking about inside it and back and forth through the doorway for 9 s: it opened once and stayed open (0 flips) | ✓ | the recording showed it flapping twice a second |
| Seeds | nothing in hand at the start; on empty soil the stamp says PLANT · Pick seed with an E cap ([01](docs/playtest/2026-11-05-checkout/01-plant-pick-seed-with-E.jpg)); E opens the picker (Carrot ×4, the locked ones greyed with their level: [02](docs/playtest/2026-11-05-checkout/02-seed-picker.jpg)); tapping Carrot planted it at once, the packet standing up and the stamp on WATER ([03](docs/playtest/2026-11-05-checkout/03-picked-and-planted.jpg)); its key or a tap puts it away and takes it back out | ✓ | fixed: the picker was a big window with one row in it (now as tall as its rows); it stayed open when you walked off (now it closes) |
| E | the cap on the stamp's rim on a computer | ✓ | fixed: it showed on the emulated phone too (now hidden when there's no keyboard; Studio's emulator still has one) |
| Our prompts | the wooden sign with the E cap, "Packing Shed" over "Wash & pack" ([04](docs/playtest/2026-11-05-checkout/04-our-prompt-wash-and-pack.jpg)); E and a tap both work | ✓ | fixed: on the phone it sat under the market ticker and the HOME/TOWN signs, out of reach (a sign in the world draws under the HUD); now drawn on the screen over its thing, above the HUD, hidden while a window is open ([17](docs/playtest/2026-11-05-checkout/17-phone-prompt-over-hud.jpg)); a tap then logged an error from a reset that ran after the sign was gone (fixed) |
| The paths | the farm path ([14](docs/playtest/2026-11-05-checkout/14-farm-path.jpg)) and Farm 1's lane from town ([15](docs/playtest/2026-11-05-checkout/15-farm-lane-from-town.jpg)): wavy dirt edges, darker ruts in broken lengths, pebbles, tufts and flowers | ✓ | fixed: in the first import the path's own straight edge showed as a pale line inside the spilt dirt, and the ruts came out lighter than the path, with dark sides, like boards ([11](docs/playtest/2026-11-05-checkout/11-path-first-try-pale-edge.jpg)); the dirt now sits 0.05 under the path's top, the colours are darker (Studio draws palette colours lighter than parts) and the ruts have no sides |
| The checkout | the Shop Counter inside the staff door ([05](docs/playtest/2026-11-05-checkout/05-shop-counter.jpg)); the save's Honour Box became it (item 5); a shopper at it: SCAN 🥕 ×11 with E, the receipt "Carrot ×11 · Scanned 0 of 1" ([06](docs/playtest/2026-11-05-checkout/06-scan-receipt.jpg)); scanned: "✓ Carrot ×11 · 473, TOTAL 473 coins", the gold TAKE ([07](docs/playtest/2026-11-05-checkout/07-take-coins.jpg)); taking: the coins, the drawer slides out toward you and back ([08](docs/playtest/2026-11-05-checkout/08-till-drawer-open.jpg)), the next shopper steps up; stepping away: 🛎️ "Serve me!" over the counter ([09](docs/playtest/2026-11-05-checkout/09-serve-me-bell.jpg)) | ✓ | |
| Cashiers | at Store Level 3 a hired Cashier (Rosie) stands behind the counter and serves on her own; "Serve me!" goes; let go from the Workers window, the till is yours again | ✓ | she still has the old faceless worker look ([10](docs/playtest/2026-11-05-checkout/10-cashier-at-store-level-3.jpg)): the user asked whether workers have their own art |
| The receipt on a phone | first above the stamp: it ran into the purse and the level rosette | ✓ | fixed: on a touch screen it's against the right edge over the jump button, 168 wide on a phone ([18](docs/playtest/2026-11-05-checkout/18-phone-receipt.jpg)) |
| The user, mid-check: "Customers should not go behind the counter." | the cells behind every till are now staff only: shoppers never walk, queue or stand there (`StoreLayout.staffOnly`, `closedToShoppers`); a display whose front is there is refused as unreachable; sampled every 0.2 s for 30 s with shoppers coming and going: 0 of 1,092 samples behind the counter | ✓ | |
| The user, mid-check: "Customer needs new art." | Roblox-shaped people: the classic head with a face, hair (short, bob, bun, ponytail, curls) and maybe a cap, sun hat or beanie; tees, open jackets, dresses, dungarees, hoodies and old-timers' cardigans; hands, shoes, kids and grey-haired elders; a wicker basket with a handle showing the crop they picked; arms swinging as they walk ([12](docs/playtest/2026-11-05-checkout/12-new-customers-queue.jpg), [13](docs/playtest/2026-11-05-checkout/13-new-customer-close.jpg)) | ✓ | the queue is tight: baskets touch the next person in line (left) |
| The phone | the picker fits on one row ([16](docs/playtest/2026-11-05-checkout/16-phone-seed-picker.jpg)); the Workers window and the shed window fine | ✓ | Roblox's jump button sits over the Workers window's bottom-right corner (Roblox's own control; left) |
| Errors | fixed: analytics logged an error on every level-up ("levelName is empty"): level-ups are named now ("Store Level 3") | ✓ | |

Noticed in passing: in this place Ctrl+S closed and reopened it as a live editing session (it's the published "Farm Heist" now, not the local file), so this session's changes save to the cloud on their own; the test made real changes to XD2MUCH's save there (Store Level 3, carrots added and sold, Carrot priced at 20 in the store, a Cashier hired and let go).

### 2026-11-04 · the auction room: paddles, Goldie's patter, 5 lots, Barley's rack · build: uncommitted, with the fixes below
Testers: Claude, driving Studio · Setup: solo Play; `/coins`, `/tp auction`, `/auction now`, `/tp barley`; bids from the card and from the command bar; the paddle's raise and cheer also set off on my own screen (the character's `PaddleUp` / `Cheer`) and slowed with `Pose_slow`; a rival's bid faked on my screen only to see the full card · Lag: 0 (local) · Screenshots: [playtest/2026-11-04-auction-room/](docs/playtest/2026-11-04-auction-room/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| The paddle in hand | a numbered paddle in the right hand in the hall, held up beside the head with the number upright and facing out ([01](docs/playtest/2026-11-04-auction-room/01-paddle-at-rest.jpg)); a new number each server (87, 21, 10) | ✓ | fixed: first held in front of the face (rest pose moved out beside the head); then, aimed from the hand, it pointed out in front or down (the hand's position is read a frame before its IK, and a cache of the server's weld offsets keyed by the weld lost entries and piled offsets up): the paddle hangs from the upper torso at the spot the hand goes to, each part at its `Grip` attribute |
| A bid | the paddle goes up over the head, the call pops up beside the head ("480!", "60,000!") ([02](docs/playtest/2026-11-04-auction-room/02-bid-raised-and-called.jpg)), the card says you're the top bid | ✓ | fixed: the bubble over the head hid the raised paddle (it sits beside the head on the bidder's other side now); an arm over the head can't turn its wrist far enough to point a paddle up (the IK only places the hand now); the raised arm crossed the face (up beside the head now: [03](docs/playtest/2026-11-04-auction-room/03-raised-beside-head.jpg)) |
| Goldie | opens each lot ("Lot 1: Bell Pepper seed! Who'll start me at 1,400?": [05](docs/playtest/2026-11-04-auction-room/05-goldie-opens-lot.jpg)), takes the bid by paddle ("1,400 from paddle 10! Do I hear 1,500?") turning her head to the bidder ([06](docs/playtest/2026-11-04-auction-room/06-goldie-turns-to-bidder.jpg)), "I have 1,400 from paddle 10. 1,500, anyone?", "Going once…" with the gavel down ([07](docs/playtest/2026-11-04-auction-room/07-going-once-gavel.jpg)), "Going twice…", "SOLD! To paddle 10, XD2MUCH, for 1,400!" ([08](docs/playtest/2026-11-04-auction-room/08-sold-to-paddle.jpg)); with no bids, "36,000, anyone? It's worth 90,000!" | ✓ | |
| Winning | confetti, the winner hops, waves the paddle overhead with the other arm up ([04](docs/playtest/2026-11-04-auction-room/04-winner-cheer.jpg)); the seed in the hotbar | ✓ | |
| The card | "LOT 2 OF 5 · PADDLE 10", RAISE PADDLE 1,600 · +10% 1,700 · +25% 1,900 ([09](docs/playtest/2026-11-04-auction-room/09-bid-card-raise-paddle.jpg)); before any bid, one RAISE PADDLE for the opening price | ✓ | |
| 5 lots | the note: "The auction's on! 5 lots: ⭐ 🎃 … · the star lot: ⭐ Starfruit seed"; Uncommon and Rare lots open under Barley's price (Strawberry 480, Pumpkin 1,600, Bell Pepper 1,400) | ✓ | |
| Barley's rack | no Mythic tab; six-figure tags fit with "sold out" beside them ([10](docs/playtest/2026-11-04-auction-room/10-barley-legendary-tags.jpg)) | ✓ | |
| Sitting (added after) | one "Bench · Sit" prompt (the nearest); E seats you, with the note "Take a seat! …" ([11](docs/playtest/2026-11-04-auction-room/11-sat-down-note.jpg)); seated, the paddle rests beside the head and the card shows ([12](docs/playtest/2026-11-04-auction-room/12-seated-with-paddle-and-card.jpg)); RAISE PADDLE bids from the seat, the call pops up ([13](docs/playtest/2026-11-04-auction-room/13-seated-bid-called.jpg)), the paddle goes up from the sitting pose ([14](docs/playtest/2026-11-04-auction-room/14-seated-paddle-raised.jpg)); a jump stands you up and the place's prompt comes back ([15](docs/playtest/2026-11-04-auction-room/15-stood-up-prompt-back.jpg)); no movement-check warnings | ✓ | seated, the next place's Sit prompt shows beside you: kept, it's how you move along a row |
| Errors | none from the game | ✓ | not tried: two players bidding (the "Back to you, paddle 47" line and seeing someone else's paddle go up), a phone |

### 2026-11-04 · week 9: Settings, the Robux shop, the phone layout, the page's shots · build: week 9 (uncommitted), with the fixes below
Testers: Claude, driving Studio · Setup: solo Play (the Robux items granted in Studio with no ids yet: the shop's Buy, `/pass`, `/buy`), Studio's iPhone 17 Pro emulation, then Server & Clients × 2 for the raid's shots; `/time`, `/weather`, `/plant`, `/grow ripe`, `/field 3`, `/store 12`, `/warehouse 10`, `/tp auction`, `/auction now`, `/suspect`, `/carry Pumpkin` to stage the page's shots · Lag: 0 (local) · Screenshots: [playtest/2026-11-04-week9/](docs/playtest/2026-11-04-week9/) · The sounds weren't heard: the generated ones aren't uploaded yet, and Studio's Output showed no failed sound load for the Creator Store ones

| Check | Result | OK? | Notes |
|---|---|---|---|
| Settings | the window ([01](docs/playtest/2026-11-04-week9/01-settings-window.jpg)): switches drawn as switches, Reduced motion on, Flashing down to 75%, text size up to 110% and 125% (the window keeps its room on screen, all inside it bigger: [02](docs/playtest/2026-11-04-week9/02-settings-text-size-125.jpg)), the Sprout Shield's countdown with Drop it now, the guide's Hide it; every change saved (an analytics event each) and the window following the server's copy | ✓ | fixed: the settings remote's cooldown dropped to 0.05 s, so a quick double tap on + isn't lost |
| The Robux shop | Passes ([03](docs/playtest/2026-11-04-week9/03-robux-shop-passes.jpg)) with the Robux sign on every price, VIP bought → Owned ✓ and the thank-you note; Style: the Golden Bat bought and worn at once, VIP Gold worn; Weather: a Thunderstorm bought and started for everyone ([11](docs/playtest/2026-11-04-week9/11-thunderstorm-bought-two-notes.jpg)), a Rain Dance bought during it kept in the barn and started later with Start now ([13](docs/playtest/2026-11-04-week9/13-weather-in-barn-strip-start-now.jpg)); Boost: on, 30:00 of play ([15](docs/playtest/2026-11-04-week9/15-growth-boost-on.jpg)) | ✓ | fixed: the first Buy did nothing (the funnel's note and the purchase went through one action remote 0.3 s apart and the purchase hit its cooldown: the funnel has its own remote now); "1 in your barn: not now…" in 8 px writing under the button ([12](docs/playtest/2026-11-04-week9/12-weather-in-barn-text-too-small.jpg)) became a strip along the card's foot, also shown before buying when it couldn't start, naming the weather and who bought it ([14](docs/playtest/2026-11-04-week9/14-weather-not-right-now-names-it.jpg)); the boost's countdown stood still between the server's minute updates (counts down on screen now); two notes said the same at a weather bought (the announcement now just says who to thank) |
| VIP on the farm | a gold store awning ([07](docs/playtest/2026-11-04-week9/07-vip-gold-awning.jpg)); the tag over the head ([05](docs/playtest/2026-11-04-week9/05-vip-tag-dark-with-gold.jpg)), seen by the other player above their Roblox name ([06](docs/playtest/2026-11-04-week9/06-vip-tag-over-the-name-seen-by-others.jpg)) | ✓ | fixed: the tag's ⭐ vanished on its gold pill ([04](docs/playtest/2026-11-04-week9/04-vip-tag-star-lost-on-gold.jpg): dark tag, gold letters now); VIP Gold in Metal looked dull olive at noon ([09](docs/playtest/2026-11-04-week9/09-vip-gold-metal-looked-olive.jpg)): a warm gold, plain finish ([10](docs/playtest/2026-11-04-week9/10-vip-gold-warm-gold.jpg)) |
| The Golden Bat | on the shoulder, gold with its red grip, next to the character ([08](docs/playtest/2026-11-04-week9/08-golden-bat-in-hand.jpg)) | ✓ | the Baguette and Carrot Club judged in a render only |
| A phone (iPhone 17 Pro) | ten crates went to three columns and the third covered the sky dial and its ×1.5 badge ([16](docs/playtest/2026-11-04-week9/16-phone-third-column-hid-the-sky-dial.jpg)) | ✓ | fixed: Robux and Settings moved to wooden signs in Roblox's top bar (TopbarSafeInsets), at its right end (in the middle they sat over the purse's ropes: [17](docs/playtest/2026-11-04-week9/17-phone-top-bar-over-the-purse.jpg), [18](docs/playtest/2026-11-04-week9/18-phone-top-bar-right.jpg)); the side bar is two crates wide again. Then every window on the phone: Barn ([19](docs/playtest/2026-11-04-week9/19-phone-barn.jpg)), Store, Market, Warehouse, Workers, Defend, Quests, Trade, Robux ([20](docs/playtest/2026-11-04-week9/20-phone-robux-style.jpg)), Settings ([21](docs/playtest/2026-11-04-week9/21-phone-settings.jpg)): all fit and read |
| A computer | the top-bar signs at the top right, the side bar one column in a tall window ([22](docs/playtest/2026-11-04-week9/22-desktop-top-bar-and-side-bar.jpg)), two in a short one | ✓ | |
| The page's shots | the farm at Golden Hour over ripe corn, the Big Warehouse's semis, the Auction House on a Golden Apple Tree seed's lot, a raid with 2 players (the thief holding a stolen pumpkin up with the red !, the farmer behind with the bat): `art/page/` icon and four thumbnails | ✓ | a store full of goods and shoppers needs a long staging run: its thumbnail is still to take (made 2026-11-05 as a staged render instead: [RobloxPage.md](RobloxPage.md)) |
| Errors | none from the game (a Roblox avatar asset's "Asset type does not match" warning isn't ours) | ✓ | |

Seen and left: the first click on a sign or crate right after typing in the command bar only focuses the game view (Studio's, not the game's); the auction hall's roof is plain grey from inside (it reads as a ceiling); notes still pass over the guide card for a few seconds. Not covered: hearing the sounds (upload first), a real purchase prompt (the passes and products need making on the Creator Dashboard), the Baguette and Carrot Club in Studio.

### 2026-11-04 · week 8: the Farm Guide, trading, the boards, the valley · build: week 8 (uncommitted), with the fixes below
Testers: Claude, driving Studio · Setup: the props file imported again (31 meshes: the hedge and the tunnel arch new), solo Play on a new save (the guide from step 1, `/grow ripe`, `/tp shed` · `dock` · `store`, the remotes for paced plants and packs), Server & Clients × 2 (both to town, [T], the Trade window), Studio's iPhone emulation, `/time noon` · night · rain · Lag: 0 (local) · Screenshots: [playtest/2026-11-04-week8/](docs/playtest/2026-11-04-week8/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| The ground | Terrain's grass blades grew up through every lawn, the plaza and the back trail ([02](docs/playtest/2026-11-04-week8/02-terrain-grass-through-the-lawns.jpg), [03](docs/playtest/2026-11-04-week8/03-boards-buried-in-terrain-grass.jpg)): the Terrain floor under the valley sprouted them, and scripts can't turn Terrain's decoration off | ✓ | fixed: no Terrain under the ground; the valley's disc reaches out under the hills (980), the hills rise from it in its own green |
| The tunnel's cliff | a hard-edged block of rock sticking out of the hills ([04](docs/playtest/2026-11-04-week8/04-first-cliff-a-block-of-rock.jpg)) | ✓ | fixed: rock only round and behind the arch with rounded shoulders, grassy hill over and either side, the hills allowed up to the highway ([05](docs/playtest/2026-11-04-week8/05-cliff-and-tunnel-fixed.jpg), at night [09](docs/playtest/2026-11-04-week8/09-tunnel-at-night.jpg)) |
| The hills | rolling, higher in the north, the trail's cover and lamps along their foot ([06](docs/playtest/2026-11-04-week8/06-hills-and-back-trail.jpg)) | ✓ | they're climbable: an invisible wall at their crest (720) keeps everyone in the valley (the old block hills did) |
| Hedges and woods | leafy hedges with flowers, firs and oaks down each gap, the lanes along the hedges clear ([07](docs/playtest/2026-11-04-week8/07-leafy-hedges-and-woods.jpg)); the trail's hay bales, bushes and lamps ([08](docs/playtest/2026-11-04-week8/08-back-trail-cover-and-lamps.jpg), at night [23](docs/playtest/2026-11-04-week8/23-trail-lamps-at-night.jpg)) | ✓ | |
| The Farm Guide | on a new farm: the card, "0 / 8", the marker over the soil and the edge arrow ([01](docs/playtest/2026-11-04-week8/01-guide-card-on-a-new-farm.jpg)); Plant counted 1 of 5 ([10](docs/playtest/2026-11-04-week8/10-guide-plant-1-of-5.jpg)), Water ticked out of order, Harvest ([11](docs/playtest/2026-11-04-week8/11-guide-harvest-step.jpg)), Pack, Send the pickup ([12](docs/playtest/2026-11-04-week8/12-guide-send-the-pickup.jpg)), Seeds in town (TOWN, then HOME), Store, Hire; the last paid 3,000 coins and pointed at the "Clear here" sign ([14](docs/playtest/2026-11-04-week8/14-guide-done-card-clear-here.jpg)) | ✓ | fixed: the done card's line was cut off (Got it beside the coins now); markers go to the patch nearest you (they picked the first in the field); the pickup step points at the truck's load spot until a crate's on it, then the lever; with an empty barn the card sent you to plant while four ripe patches were waiting ([13](docs/playtest/2026-11-04-week8/13-guide-grow-more-first.jpg)): it says harvest those first; TOWN and HOME pulse bigger with a gold ring (the pulse was too slight to see) |
| Trading | [T] by the other player; the request as a note with Trade ([15](docs/playtest/2026-11-04-week8/15-trade-request-and-t-prompt.jpg)); two crates, the picker, the value of each stack ([16](docs/playtest/2026-11-04-week8/16-trade-window-both-sides.jpg)); Ready → "Confirm opens in 3..." → CONFIRM ([17](docs/playtest/2026-11-04-week8/17-trade-countdown.jpg)); the swap: 2 Carrot seeds for 100 coins, 3,000 → 3,100 and 5 → 3 seeds on one side, 3,000 → 2,900 and 5 → 7 on the other ([18](docs/playtest/2026-11-04-week8/18-trade-done-both-sides.jpg)); the red bar at 50× ([19](docs/playtest/2026-11-04-week8/19-trade-lopsided-warning.jpg)); X cancels for both, with a note each | ✓ | fixed: a tap on the gap between the crates closed the window and cancelled the trade (the tap fell through to the backdrop): every window's paper now catches its own taps, only a tap outside closes it (checked); the picker closes after an add so you see your crate; "+ Add" goes once you're Ready; a phone says "tap Trade", not "press T" |
| The boards | RICHEST FARMS ranks both players by net worth (3,600 and 3,400) and says it's this server only ([20](docs/playtest/2026-11-04-week8/20-richest-farms-board.jpg)); TOP STORES "Nobody yet this week!"; readable at night ([24](docs/playtest/2026-11-04-week8/24-board-at-night.jpg)) | ✓ | a board refreshes every minute (one read before the login streak's coins showed 1,500) |
| A phone | the guide card fits on the right, clear of the stamp and jump button ([21](docs/playtest/2026-11-04-week8/21-phone-guide-card.jpg)); the Trade window ([22](docs/playtest/2026-11-04-week8/22-phone-trade-window.jpg)) | ✓ | |
| Errors | none in the Output (server or clients) | ✓ | |

Seen and left: notes and the truck's receipt pass over the guide card for a few seconds (they matter more right then); some dark rock shows through the grass where the cliff meets the hills (it reads as rock); the Trade window's two-crate layout wasn't seen on a phone with a second player. Not covered here: MemoryStore and the OrderedDataStores (they need a live server), the trade log and `/rollback` (the log store needs API access), walking apart mid-trade, the 50-player test (Stage E).

### 2026-11-04 · the town's look, by eye · build: week 7 + the town's look (uncommitted), with the fixes below
Testers: Claude, driving Studio · Setup: the props file imported again (29 meshes, the town's 7 new), solo Play, TOWN from the farm, `/weather clear`, `/time noon` · `night`, a Scriptable camera at the render views (spawn, plaza, fountain, tower, Barley's, the Hiring Hall, the Exchange, the elevator, a signpost, the green, above), Studio's iPhone emulation · Lag: 0 (local) · Screenshots: [playtest/2026-11-04-town/](playtest/2026-11-04-town/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| Arriving in town | the character lands on the spawn facing the Exchange, but the camera kept its old angle: you looked back at the Police Station and the Hiring Hall, the character's face to you ([01](playtest/2026-11-04-town/01-arrival-camera-faced-backwards.jpg)) | ✓ | fixed: after Home or Town the camera turns to look the way you arrive facing: the tower, the Exchange behind it, Barley's and the Auction House either side ([21](playtest/2026-11-04-town/21-arrival-camera-faces-the-exchange.jpg)) |
| The spawn's view, the plaza | the tower in the fountain, the elevator and price board beside it, the clover, benches, lamps, flowerbeds ([02](playtest/2026-11-04-town/02-spawn-view-tower-exchange-barleys.jpg), [03](playtest/2026-11-04-town/03-plaza-from-above.jpg), [04](playtest/2026-11-04-town/04-fountain-and-clover.jpg)) | ✓ | |
| The clocks | at game time 13.38 the hands say 1:23 ([06](playtest/2026-11-04-town/06-clock-shows-game-time-1-23.jpg)); the minute hand moves with the sky's clock | ✓ | |
| The fountain | its spouts gave a few faint sparkles, hardly water ([07](playtest/2026-11-04-town/07-fountain-jets-too-faint.jpg)) | ✓ | fixed: thicker, longer arcs that land inside the rim, a splash where each lands ([22](playtest/2026-11-04-town/22-fountain-jets-fixed.jpg)) |
| The price board | every crop and price reads from the walk in front ([08](playtest/2026-11-04-town/08-exchange-board-reads.jpg)), by night too ([19](playtest/2026-11-04-town/19-exchange-board-at-night.jpg)), and on a phone from the desk ([20](playtest/2026-11-04-town/20-phone-board-from-the-desk.jpg)) | ✓ | |
| Barley's Seeds | the sign, the motto, packets in the windows, Barley at the SEED RACK, the "FRESH SEEDS new stock every 5 min" easel ([09](playtest/2026-11-04-town/09-barleys-seeds.jpg), [10](playtest/2026-11-04-town/10-barley-at-the-seed-rack.jpg)) | ✓ | |
| The Hiring Hall | a porch post stood in front of the job board, cutting "first hire free!" ([11](playtest/2026-11-04-town/11-hiring-hall.jpg), [12](playtest/2026-11-04-town/12-porch-post-cuts-the-job-board.jpg)) | ✓ | fixed: the middle posts frame the door, the step as wide as the gap between them ([23](playtest/2026-11-04-town/23-hiring-hall-fixed.jpg), [24](playtest/2026-11-04-town/24-job-board-clear-of-the-posts.jpg)) |
| The elevator, the signposts, the green, from above | CLOVERDALE on the elevator; "FARM 1 / XD2MUCH" on its signpost, the others "for rent"; the walk round the town and the farm paths ([13](playtest/2026-11-04-town/13-grain-elevator.jpg), [14](playtest/2026-11-04-town/14-signpost-farm-1-owner.jpg), [15](playtest/2026-11-04-town/15-the-green.jpg), [16](playtest/2026-11-04-town/16-town-from-above.jpg)) | ✓ | |
| Night | the plaza's lamps light the paving, the clocks, the park lamps and the shop windows glow ([17](playtest/2026-11-04-town/17-plaza-at-night.jpg), [18](playtest/2026-11-04-town/18-spawn-view-at-night.jpg)) | ✓ | |
| Frame rate | 60 fps (Studio's cap) at the farm and in town; Studio's memory 2,636 → 2,641 MB; 1,944 parts in the town on the client | ✓ | a phone's frame rate needs a real phone (Stage D) |
| Errors | none in the Output | ✓ | |

Seen and left: on a phone at the spawn the HUD covers most of the screen and the camera sits close (week 9's mobile layout); from the spawn the coin sign hangs over the far price board (you read it from its walk, or MARKET); the plaza is mostly open paving (room for 8 players to meet and trade); the green past the walk is plain lawn and trees (the valley's woods come in week 8).

### 2026-11-04 · a stolen crop is yours once you're back in your farm · build: week 7 + this change (uncommitted)
Testers: Claude, driving Studio · Setup: solo Play, `/tp town` + `/carry Pumpkin`, a pathfinding walk home, then `/tp back` + `/carry Pumpkin` + Climb; a client logger printing the farm you're in and the crop in your hands, with the distance to your farmhouse door · Lag: 0 (local) · Screenshots: [playtest/2026-11-04-home-in-farm/](playtest/2026-11-04-home-in-farm/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| Carrying from town | the sign "🎃 1 pumpkin · Get home!" with its arrow; the note "Walk into your own farm to put them in your barn" ([01](playtest/2026-11-04-home-in-farm/01-carrying-in-town-get-home.jpg)) | ✓ | |
| In through the front gate | into my farm 88 studs from the door, and the pumpkin went into the barn 0.1 s later (before: only within 15 studs of the door) | ✓ | |
| In over the back fence | CLIMB in at my own back fence ([02](playtest/2026-11-04-home-in-farm/02-own-back-fence-climb-in.jpg)); landed 162 studs from the door, the pumpkin in the barn at once: "🎃 1 pumpkin (stolen) in your barn" ([03](playtest/2026-11-04-home-in-farm/03-over-the-fence-stolen-in-your-barn.jpg)), the bat back in the hotbar ([04](playtest/2026-11-04-home-in-farm/04-in-your-farm-bat-back.jpg)) | ✓ | |

Not covered here: "Safe!…" when a real thief leaves the farm they stole from (needs two players; only its wording changed).

### 2026-11-03 · week 7, the parts left over: storms, frost, the auction's clock, quests' crimes, a phone, 8 players · build: week 7 (uncommitted), with the fixes below
Testers: Claude, driving Studio · Setup: solo Play (`/weather thunderstorm` · `frostnight`, `/time night`, `/auction soon`, `/tp auction`), Studio's iPhone emulation, Server & Clients × 2 (`/shield off`, `/plant Pumpkin`, `/grow ripe`, `/quests Arrest Deposit Auction`, `/tp field`, `/ko suspect`, `/coins`, `/level 22`, `/auction now`, `/state`), Server & Clients × 8, then × 2 again to check the fixes · Lag: 0 (local) · Screenshots: [playtest/2026-11-03-week7/](playtest/2026-11-03-week7/) (30 on)

| Check | Result | OK? | Notes |
|---|---|---|---|
| Thunderstorm | the flash comes every 6–14 s (5 in 45 s, counted), with its second flicker | ✓ | fixed: a brightening alone read as the screen glitching: a jagged white bolt with a fork now strikes 200–320 studs off with each flash ([33](playtest/2026-11-03-week7/33-lightning-bolt-first-look.jpg)), 12–35° to the side of where you look (at up to 50° it struck behind the side bar; dead ahead it hides behind you) ([44](playtest/2026-11-03-week7/44-lightning-bolt-final.jpg)); the flash lasts a little longer |
| Frost Night | the ❄️ dial and its ×0.75 badge | ✓ | fixed: hardly a crystal to see, and the grass as green as any clear night: 220 bigger crystals a second drifting down past the camera, and a colder, greyer look ([34](playtest/2026-11-03-week7/34-frost-night-crystals.jpg)) |
| The 1-minute note | 70 s after `/auction soon`: "The auction starts in 1 minute…" with TOWN; TOWN, "Heading to town... (stand still)", the town square ([31](playtest/2026-11-03-week7/31-auction-in-1-minute-note-town-button.jpg), [32](playtest/2026-11-03-week7/32-town-button-took-me-to-the-square.jpg)); the auction started on the moved clock | ✓ | fixed: notes with a button went after 8 s, too soon to press: they stay 12 s |
| A phone (Studio's iPhone) | the HUD, the sky dial, the Quests and Cropdex windows fit; tabs and buttons work by tap ([36](playtest/2026-11-03-week7/36-phone-cropdex.jpg)) | ✓ | fixed: the bid card covered the Town signpost and ran under the jump button ([30](playtest/2026-11-03-week7/30-phone-bid-card-over-the-town-sign.jpg)): 80% and up in the top right corner on phones ([35](playtest/2026-11-03-week7/35-phone-card-top-right-side-bar-clear.jpg)); the seventh side-bar crate (Quests) sat on the thumbstick: the crates start at the top now (three columns if a short screen needs them) |
| Quests: a stolen crop home | Player2 stole a pumpkin from Player1's field and walked it home (37 s): "Take a stolen crop home 1/1 · CLAIM 8,000" ([37](playtest/2026-11-03-week7/37-deposit-quest-done.jpg)) | ✓ | |
| Quests: an arrest | Player1 stole from Player2, was knocked out, Player2 held ARREST: "Quest done: Arrest a thief!" ([38](playtest/2026-11-03-week7/38-arrest-quest-done-level-up-under-the-card.jpg)) | ✓ | fixed: the arrest card's amounts had no commas (nor the police desk's, the debt and payout notes, the truck's, the strike note): every amount goes through one formatter now ([42](playtest/2026-11-03-week7/42-arrest-card-with-commas.jpg)); the level-up the arrest gave hid under the ARRESTED card: it waits and shows after ([43](playtest/2026-11-03-week7/43-level-up-after-the-arrest-card.jpg)) |
| A leading bidder leaves | Player1 bid 320,000, Player2 336,000, then Player2 closed their window: Player1 got "Player2 left: you lead the Security Camera again at 320,000" ([39](playtest/2026-11-03-week7/39-player2-left-you-lead-again.jpg)), the server "Player2 left leading the Security Camera: 336,000 back in their save" ([40](playtest/2026-11-03-week7/40-server-log-leaver-refund.jpg)); Player1 won it | ✓ | |
| A leading bidder at a shutdown | can't be seen in Studio: the server's window closes with the session | ✗ → fixed | reading the code: the refund only ran as the player left, and at a shutdown ProfileStore can save and close the save first, so a server update mid-lot could lose the leader's coins. The coins a lead holds are written in the save now (`auctionHeld`) and come back on the next join; checked with `/state`: 240,000 held on bidding, 0 once outbid, 0 once won (spent) |
| 8 players | every farm taken (Plot1–8, one each), each farmhouse its colour ([41](playtest/2026-11-03-week7/41-eight-clients.jpg)); the sky the same on the server and a client (Clear, 09:12 on both); the server at 60 steps a second, its worst 19 ms, 2.1 GB | ✓ | the machine was down to 0.5 GB free with 8 clients, so a several-bidder auction is left for testers |

Noticed in passing (any part of the game, with a verdict):

| Seen | Verdict |
|---|---|
| A computer window under about 560 px tall cut the seventh crate (Quests) off the bottom of the side bar | Fixed now: such windows get the phones' two columns at the top |
| `/ko` (dev) named the thief's own farm in the dropped crop's note ("bonked on Player1's farm") | Fixed now: as if the farm's owner swung |
| In a narrow window the level-up card and the bid card overlap for 5 s | Leave: brief, and apart on a real screen |
| A "ContentId rbxassetid://203785492 failed" warning at every start | Leave: it's not ours (not in the place or the code) |
| The town square is bare: a spawn pad, the Exchange board, the hall | Next: the town's look |
| A several-bidder auction with 8 players | Stage E with testers |

### 2026-11-03 · week 7: weather, night, the Auction House, quests · build: week 7 (uncommitted), with the fixes below
Testers: Claude, driving Studio · Setup: solo Play (dev commands `/weather`, `/time`, `/auction now`, `/tp auction`, `/land all`, `/defences all`, `/plant`, `/grow ripe`), then Server & Clients × 2 (two bidders; the Floodlights and night name tags), then solo again to check the fixes · Lag: 0 (local) · Screenshots: [playtest/2026-11-03-week7/](playtest/2026-11-03-week7/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| The sky dial | the weather's icon, the clock, the growth badge (×1.5 in rain, ×2 under the Harvest Moon), a moon on a clear night; the Harvest Moon's tag violet at 00:00 | ✓ | fixed: it slid under the coin sign at Studio's size ([01](playtest/2026-11-03-week7/01-golden-hour-sky-dial-touching-the-purse.jpg)): it hangs from the purse's own frame now ([16](playtest/2026-11-03-week7/16-sky-dial-hung-from-the-purse.jpg)) |
| Weather notes and mutations | the note for each new weather; 64 ripe pumpkins in rain: 6 turned Wet in about two minutes, "3 of your ripe crops mutated!"; the tile says "✨ 1 Wet pumpkin · worth ×1.3!"; harvested: the quest done and "New in your Cropdex: Wet Pumpkin" ([14](playtest/2026-11-03-week7/14-wet-pumpkin-harvested-quest-done-cropdex.jpg)); at the wash table "WET PUMPKIN · ✨ ×1.3 by truck" with only the Truck button ([15](playtest/2026-11-03-week7/15-wet-pumpkin-truck-only-at-the-bench.jpg)) | ✓ | fixed: a Wet crop didn't stand out (ripe Rare crops already sparkle blue: [09](playtest/2026-11-03-week7/09-wet-pumpkins-lost-among-rare-sparkles.jpg)): a soft haze of its colour rises off it now ([10](playtest/2026-11-03-week7/10-wet-haze-test.jpg), [20](playtest/2026-11-03-week7/20-wet-haze-by-day-in-rain.jpg)); a mutated harvest now also finds the plain crop for the Cropdex |
| Rain | | ✓ | fixed: invisible ([08](playtest/2026-11-03-week7/08-night-rain-invisible-windows-lit.jpg)): 600 tiny pale drops over 110 × 110 studs; now 1,500 a second over 64 × 64, bigger blue-grey streaks lit by nothing ([17](playtest/2026-11-03-week7/17-rain-streaks-visible.jpg)); it rained inside the Auction House: none falls while the camera is under a solid roof (the Sprout Shield's dome and leaves don't count) |
| Night | windows and the porch lantern lit on owned farms, dark on farms for rent; the Floodlights' lenses glow and light the field ([07](playtest/2026-11-03-week7/07-auction-house-at-night.jpg), [25](playtest/2026-11-03-week7/25-farmhouse-under-the-harvest-moon.jpg)) | ✓ | the night is dark blue but every farm and path still reads |
| Golden Hour | | ✓ | fixed: the hall's red walls went neon orange in it ([03](playtest/2026-11-03-week7/03-hall-neon-orange-in-golden-hour.jpg)): less saturation and tint; outdoors now a warm late afternoon ([21](playtest/2026-11-03-week7/21-golden-hour-calmer.jpg)) |
| The Harvest Moon | ×2 badge, 00:00 on a violet tag, the scene tinted violet | ✓ | fixed: the moon was a dull brown disc in a navy sky, and in the south ([11](playtest/2026-11-03-week7/11-harvest-moon-dull-navy-sky.jpg)): bigger, brighter, a soft glow, in the north (+Z, the highway's way), drawn over the haze (it was lost in it) and hidden whenever something solid stands in front (checked behind the farmhouse); the haze more violet ([26](playtest/2026-11-03-week7/26-harvest-moon-orange-violet-sky.jpg)) |
| The Auction House | a red barn hall that reads from the square by day and night, open X-braced doors, the sign, the bell tower; inside the stage, the chalk lot board, curtains, Goldie at her podium, benches, lamps ([04](playtest/2026-11-03-week7/04-hall-from-the-benches-name-tag-over-the-board.jpg), [27](playtest/2026-11-03-week7/27-hall-by-day-grandma-rose-lot.jpg)) | ✓ | fixed: Goldie's floating name hid the board from the benches (her name is on the podium's plate now); the lot floated to one side of its pedestal ([06](playtest/2026-11-03-week7/06-lot-icon-off-to-the-side-of-its-pedestal.jpg): the pedestal's top is a cylinder on its side and Roblox applies the "world" offset in its own frame) and covered the board's bid line: an upright attachment, the pedestal at the stage's front edge, the lot just above it; `/tp auction` landed in the doorway ([02](playtest/2026-11-03-week7/02-auction-on-tp-lands-in-the-doorway.jpg)): behind the benches now |
| An auction, one bidder | the auction on the clock with its note and TOWN button; the card's lot, worth, opening bid, BID; a bid held the coins; Goldie's "Going twice...", "SOLD to …!" in her bubble (to her right now); SOLD to you, the Glass Cloche and Speedy Sam delivered ("they've joined your crew") ([05](playtest/2026-11-03-week7/05-sold-to-you-goldies-bubble.jpg), [28](playtest/2026-11-03-week7/28-speedy-sam-sold-joined-your-crew.jpg)); no bids: "back to the vault" | ✓ | fixed: with too few coins the card said nothing (now "You need 9,600 coins to bid on this one"); two identical Glass Cloches in one auction (never the same lot twice now); the confetti was a few pale sparkles gone in a second (four bursts in solid colours now, falling over the stage: [29](playtest/2026-11-03-week7/29-confetti.jpg)); a rare worker's card showed BID though you had no slot for their job (the server refused it: now the card knows your slots too) |
| Two bidders | Player1 bid 16,000; Player2 +5% (16,800); Player1 got "Outbid…: your coins are back" and their purse back, with the next steps on the card ([22](playtest/2026-11-03-week7/22-two-players-outbid-coins-back.jpg)); a bid with 4 s left put the clock back to 10 and flashed it on the other screen; SOLD to Player1 for 17,700, Player2's coins all back ([23](playtest/2026-11-03-week7/23-two-players-sold-hotbar-error.jpg)) | ✓ | fixed: the notes' amounts had no commas |
| Floodlights and name tags at night (2 players) | Player2 in Player1's floodlit field: red outline on Player1's screen ([24](playtest/2026-11-03-week7/24-floodlit-farm-thief-outlined.jpg)), name shown from 100 studs; Player2 on their own farm (no Floodlights): no outline, name only within 20 studs | ✓ | |
| Quests and the Cropdex | the streak's Day 1 ticked; three quests with bars; the green ! on the crate when one is done | ✓ | fixed: 🪙 isn't in Roblox's emoji (days 3 and 5 blank, the coins' buttons bare: 💰 now); "1500" without its comma; the Cropdex's mutation chips wrapped and every crop read "❓ ???" ([13](playtest/2026-11-03-week7/13-cropdex-chips-wrap-question-marks.jpg)): two rows of chips, unfound crops by name in grey ([18](playtest/2026-11-03-week7/18-quests-fixed.jpg), [19](playtest/2026-11-03-week7/19-cropdex-fixed.jpg)) |

Noticed in passing (any part of the game, with a verdict):

| Seen | Verdict |
|---|---|
| The hotbar crashed as soon as you held two kinds of seed (`Rarities.ById[crop]` for `Rarities.ById[crop.rarity]`, since week 1): an auction seed made it happen ([23](playtest/2026-11-03-week7/23-two-players-sold-hotbar-error.jpg)) | Fixed now (blocking): every packet shows again |
| The auction's card covers about half of a narrow window (a phone in landscape is wider, but not by much) | Week 9 (mobile layout): a smaller card on phones |
| The hall's red walls inside are strong under the lamps | Leave: it reads as a barn by day; look again with the town's look |
| The Sprout Shield's sign shows over the town at night from far off | Leave: it's in the world over your own field |
| Not covered: a lot won by someone who left, a leaver's escrow at shutdown (the rules are tested), thunderstorm flashes, frost, the 1-minute warning (seen only as code), quests' arrests and deposits, a phone, 8 players | Covered the same day (the entry above), but for a several-bidder auction (Stage E) |

### 2026-11-02 · dropped crops and the raid rebalance · build: week 6 + the rebalance (uncommitted), with the fixes below
Testers: Claude, driving Studio · Setup: solo Play on my own field (`/carry Pumpkin`, `/ko`), then Server & Clients × 2 twice (Player2 the farmer on Farm 8 with `/defences all`, a Level 5 Watchman and a ripe pumpkin field; Player1 the thief), the second time after fixing what the first found · Lag: 0 (local) · Screenshots: [playtest/2026-11-02-drop/](playtest/2026-11-02-drop/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| A bonked thief's crop on the ground | the pumpkin lands past their head, on the soil, with a "Dropped! 🎃 ×1" label and a bar running down ([01](playtest/2026-11-02-drop/01-dropped-pumpkin.jpg)); left alone it went back by itself after 30 s ("Nobody picked up 🎃 1 pumpkin: it's back in your barn") | ✓ | fixed: the label floated 5 studs up, over the character beside it (just over the crop now) |
| TAKE BACK | on my own dropped crop, and the farmer's after a bonk and an arrest: a green 1.5 s hold, "Taken back: 🎃 1 pumpkin. It's in your barn." ([06](playtest/2026-11-02-drop/06-take-back-green-bar.jpg)) | ✓ | fixed: the crop line sat on top of "BACK" in the stamp ([02](playtest/2026-11-02-drop/02-first-take-back-stamp-overlap.jpg); two-word stamps have no crop line now, it's in the hint; the steal's HANDS FULL had the same overlap), the hold bar filled red like a crime (green now) |
| The bonk on a carrier | "Player1 dropped 🎃 1 pumpkin: hold TAKE BACK before someone grabs it!", ARREST first on the stamp ([03](playtest/2026-11-02-drop/03-bonk-drops-it-arrest-first.jpg)); arresting still fined for the pumpkin on the ground | ✓ | |
| GRAB by the thief who dropped it, once awake | GRAB on their stamp; the farmer's alarm "Player1 is grabbing the dropped 🎃 Pumpkin!", then "grabbed your dropped 🎃 1 pumpkin!" and the Watchman shut the gate again ([04](playtest/2026-11-02-drop/04-thief-grabs-farmer-alarmed.jpg), [05](playtest/2026-11-02-drop/05-grabbed-watchman-shuts-gate.jpg)) | ✓ | fixed: the thief read "A thief dropped it" about their own crop ("You dropped it! Grabbing it back makes you a Suspect again…") |
| The farmer beside the dropped crop as the thief wakes | was: SWING on the stamp, though for 6 s a bonk only nudges them, so TAKE BACK was hidden just when the thief could grab | ✗ → ✓ | fixed: while someone's immune SWING drops below TAKE BACK and says why ("Player1 just woke up: for a few seconds a bonk only nudges them") ([07](playtest/2026-11-02-drop/07-immune-thief-take-back-first.jpg)); a pick-up hold keeps the stamp while it runs (my press landed as the immunity ended and swung instead) |
| The Watchman | shut the gate once the thief had the crop (14 s at Level 5), the line joining the alarm card; not when they climbed in | ✓ | |
| A cloche, the Tall Back Fence | a cloched pumpkin: 3.5 s ([08](playtest/2026-11-02-drop/08-cloche-steal-3-5-s.jpg)); timed on the Climbing attribute: over the tall fence in, with a pumpkin, 1.50 s; out with it 3.00 s ([09](playtest/2026-11-02-drop/09-tall-fence-climb-timer.jpg)) | ✓ | |
| The Farm Rules card's new words | "SWING to bonk them: they drop your crop." · "They're fined. Then TAKE BACK your crop!" ([10](playtest/2026-11-02-drop/10-farm-rules-card.jpg)) | ✓ | |

Noticed in passing (any part of the game, with a verdict):

| Seen | Verdict |
|---|---|
| During the 2.5 s mugshot the farmer's stamp still said ARREST over the arrested thief (from week 5) | Fixed now: a `Busted` attribute takes them off it |
| The dog never ran: at Field Level 1 the open crops are 72 studs from the kennel spot behind the field that `/defences all` uses (the back half is wild land) | Done next day (below), with a new `/land all` |
| Two players racing for one dropped crop at once | Done next day (below) |
| The two last fixes (pick-up keeps the stamp, no ARREST after an arrest) | Not played again |

**Then, 2026-11-03** (the user: "Can't you give yourself commands to unlock those areas and levels so you can test it?" and "Make sure only one person can get it"): a new dev command `/land all` opens every block of your field ([13]({D}13-land-all-whole-field.jpg)); Server & Clients × 2 again (Player1 the farmer on Farm 1 with `/land all`, `/defences all`, a Watchman; Player2 the thief).

| Check | Result | OK? | Notes |
|---|---|---|---|
| Two people finishing a pick-up at the same moment | both clients ran a script that, 6 s after the drop, called PickUpStart then PickUp through the real remote at the same server time. Race 1: started 4 ms apart, the thief's GRAB finished first and had the pumpkin, the farmer's TAKE BACK got "Gone" and nothing reached the barn ([11]({D}11-race-1-grab-wins-take-back-gone.jpg)). Race 2: started 3 ms apart, the farmer's won, the thief got "Gone" with empty hands ([12]({D}12-race-2-take-back-wins-grab-gone.jpg)) | ✓ | one crop, one winner, either way. The claim is now one explicit step (`LootRules.takeDrop`, tested) |
| The guard dog's new timing | a back-row pumpkin 15 studs from the kennel: BARK as the steal started; the dog ran the moment the thief had the crop (0.00 s), barking again; the thief slowed 30% 0.50 s later (its run) for 1.98 s; WOOF! and "The guard dog is at your heels: you're slowed!" on the thief's screen ([14]({D}14-dog-at-the-thiefs-heels.jpg), [15]({D}15-dog-timing.jpg)) | ✓ | |

### 2026-11-02 · week 6: defences · build: week 6 (uncommitted), with the fixes below
Testers: Claude, driving Studio · Setup: `art/props/FarmHeistProps.glb` imported again (the defences' meshes); solo Play to look at everything, then Server & Clients × 2 (Player2 the farmer on Farm 8 with `/defences all`, a Watchman, a ripe pumpkin field; Player1 the thief), then solo again to check the fixes · Lag: 0 (local) · Screenshots: [playtest/2026-11-02-week6/](playtest/2026-11-02-week6/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| The defences in Studio's light | the scarecrow ([01](playtest/2026-11-02-week6/01-scarecrow.jpg)), the kennel with REX over the door, the dog, mud and the tall fence ([02](playtest/2026-11-02-week6/02-kennel-dog-mud-tall-fence.jpg)), glass cloches you see the tile through ([04](playtest/2026-11-02-week6/04-glass-cloches.jpg)), the camera on the barn ([05](playtest/2026-11-02-week6/05-camera-on-the-barn.jpg)), the locked gate ([06](playtest/2026-11-02-week6/06-locked-gate-from-the-road.jpg)), the gatehouse ([07](playtest/2026-11-02-week6/07-watchmans-gatehouse.jpg), [08](playtest/2026-11-02-week6/08-gatehouse-from-the-road.jpg)), the tall fence from the trail ([09](playtest/2026-11-02-week6/09-tall-fence-from-the-trail.jpg)) | ✓ | fixed: the mud's puddle read as ice (darker now), the camera too small to read from the yard (1.6×), the shield dome poking out through the back fence ([03](playtest/2026-11-02-week6/03-back-of-the-field-under-the-shield-dome.jpg), [09](playtest/2026-11-02-week6/09-tall-fence-from-the-trail.jpg); smaller now) |
| The Sprout Shield | a faint green dome over the field with its timer; the Defend window's card with the time left and Drop it now; dropping it brings the Farm Rules card ([11](playtest/2026-11-02-week6/11-farm-rules-card.jpg)) | ✓ | fixed: the card's last line sat over its pictures |
| Buying and setting out | Buy → placing view from above, green spots, the dog's gold ring, Move, put away ([10](playtest/2026-11-02-week6/10-setting-out-the-dog.jpg)) | ✓ | fixed: the spots couldn't be pressed (a billboard needs Active), the HUD over the view (it steps aside now, every frame), the view too low for the back spots, the bar's words once a one-of is out, the ring hidden under the tiles, the camera left up in the sky after DONE |
| A raid on a defended farm (2 players) | the scarecrow's amber card as the thief came near; on the steal the alarm with the Watchman's line and the camera's live picture, the dog at the thief's heels (WOOF!, slowed), TRESPASSING ([12](playtest/2026-11-02-week6/12-raid-alarm-camera-and-dog.jpg)) | ✓ | fixed: the edge arrow was a blank red circle (➤ isn't in the game's fonts: drawn now, and kept below the coin sign), the camera's picture too wide to see the thief (it zooms on them now, [14](playtest/2026-11-02-week6/14-climbing-the-gate-arrow-and-camera.jpg)), the scarecrow's card on top of the alarm (the alarm replaces it) |
| The Gate Lock | walking out free; walking in stopped in the gateway; the first climb asks first ([13](playtest/2026-11-02-week6/13-climb-a-locked-gate-asks-first.jpg)); climbing in 2 s, a Suspect, the owner alarmed ([14](playtest/2026-11-02-week6/14-climbing-the-gate-arrow-and-camera.jpg)) | ✓ | the confirm's buttons only missed when the click came before Studio's mouse had settled (a test-driving quirk, not the game) |
| The Watchman | shut the gate on the Suspect for 21 s (Level 5): walking out stopped, "climb out!" ([15](playtest/2026-11-02-week6/15-watchman-shut-the-gate-climb-out.jpg)); after the 21 s the gate opened for them to walk out | ✓ | the bell's swing and the spotlight weren't looked at closely (daylight) |
| The Tall Back Fence, mud | climbing it took 3.5 s ([18](playtest/2026-11-02-week6/18-climbing-the-tall-fence.jpg)); on mud a stranger walked 11.2 instead of 16 | ✓ | |
| Trusted | Trust from the Defend window; the friend is told; no Steal on their farm, the stamp says what they can do; harvesting under a cloche sent the pumpkin to the farmer's barn ([16](playtest/2026-11-02-week6/16-trusted-tab-and-friend-told.jpg), [17](playtest/2026-11-02-week6/17-friend-harvests-under-a-cloche.jpg)) | ✓ | fixed: `/shield on`, `/defences none` and `/trust Name` read the wrong word of the command |

Noticed in passing (any part of the game, with a verdict):

| Seen | Verdict |
|---|---|
| Roblox's chat box, once used, sits over the top-left of an open window (the Defend window's tabs) and takes the clicks | Week 9 (interface polish): keep windows' tabs clear of the chat's corner on computers |
| The yellow sill under the gate read oddly beside the new leaves | Fixed now: the path's colour |
| A Watchman's wage is a big share of a new player's coins (the test farm's 1,000 went in minutes) | Leave: he opens at Farm Level 8, when income is far higher (the progression sim's wages stay under 10%) |
| The Sprout Shield's sign floats behind the coin sign from the farmhouse door | Leave: it's in the world, 30 studs over the field; it moves as you do |
| Not covered here: the Camera tab's visitor list, a cloche doubling a steal's time (the rule is tested), the Floodlights (week 7, with night), a phone, 8 players | Stage D with testers |

### 2026-11-02 · tilled soil and the doormat · build: this session's fixes after the farmhouse
Testers: Claude, driving Studio · Setup: `art/props/FarmHeistProps.glb` imported again (with the `Furrows` mesh); solo Play, a Scriptable camera; the character walked off the doormat to read it · Lag: 0 (local) · Screenshots: [playtest/2026-11-02-farmhouse/](playtest/2026-11-02-farmhouse/) 12–15

| Check | Result | OK? | Notes |
|---|---|---|---|
| Tilled soil | lumpy ridges of turned soil with clods, from the farmhouse and close up ([12](playtest/2026-11-02-farmhouse/12-tilled-soil-from-the-farmhouse.jpg), [13](playtest/2026-11-02-farmhouse/13-tilled-soil-close.jpg)) | ✓ | was three smooth cylinders a tile that read as logs ([06](playtest/2026-11-02-farmhouse/06-wild-land-from-the-farmhouse.jpg)) |
| The doormat | coir in the farm colour's edge, WELCOME read from the path ([15](playtest/2026-11-02-farmhouse/15-doormat.jpg)) | ✓ | the word first ran up the mat toward the house ([14](playtest/2026-11-02-farmhouse/14-doormat-word-the-wrong-way.jpg)) |

Noticed in passing (any part of the game, with a verdict):

| Seen | Verdict |
|---|---|
| The scarecrow is a bare post, the kennel a red box and the gatehouse a cream cube on every farm, bought or not | Week 6 (the defences replace them; ArtDirection §11 step 11) |
| The town's buildings are white boxes; the Exchange's tower shows from every farm | Week 7 (§11 step 6) |
| The hedges are flat green walls, the valley's rim a ring of flat green walls | Week 8 (§11 step 4) |
| "ContentId rbxassetid://203785492 failed … asset type does not match" on every Play | Leave: tagged Studio, not in the game's code (Studio or a plugin) |
| "Roblox API services unavailable – data will not be saved" | Leave: local Studio without API access; turn it on in Game Settings only to test saving across sessions |
| The farmhouse's cream walls look white in the sun | Leave: right for a farmhouse, no glare |

### 2026-11-02 · the farmhouse and barn, wild land, produce on shelves · build: this session's art
Testers: Claude, driving Studio · Setup: `art/crops/FarmHeistCrops.glb` imported again as ReplicatedStorage.CropModels (for the carrot bunch and punnets) and `art/props/FarmHeistProps.glb` as PropModels; solo Play, a Scriptable camera from the client command bar, the Corner Store's displays filled and crates put on the dock rack from the server command bar (`StoreArt.showDisplay`, `YardArt.showHold`) · Lag: 0 (local) · Screenshots: [playtest/2026-11-02-farmhouse/](playtest/2026-11-02-farmhouse/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| The imports | 66 crop meshes and 13 props, each file its own model (the props first came in named CropModels: the generator now names each file's scene) | ✓ | |
| The farmhouse and barn from the gate, porch, field and above | reads as a farmhouse with a porch and a red barn; the door and doormat are what you see when you appear; the barn quilt, weathervane, hayloft and X-braced doors show from the road and the field ([01](playtest/2026-11-02-farmhouse/01-from-the-gate.jpg)–[05](playtest/2026-11-02-farmhouse/05-farm-from-above.jpg)) | ✓ | the barn's wall by the farmhouse was bare red → battens ([04](playtest/2026-11-02-farmhouse/04-barn-side-battens.jpg)); cream walls read white in the sun, like a farmhouse should |
| Wild land | rough grass, stumps, boulders, weeds and brambles; reads as wild from the farmhouse ([06](playtest/2026-11-02-farmhouse/06-wild-land-from-the-farmhouse.jpg), [08](playtest/2026-11-02-farmhouse/08-wild-land-close.jpg)) | ✓ | the rock's moss went lime in Studio's sun ([07](playtest/2026-11-02-farmhouse/07-rock-moss-before.jpg)) → plain mid-grey stone |
| Produce on the shelves and crates | carrots, punnets of strawberries and blueberries, potatoes, corn, pumpkins, tomatoes ([10](playtest/2026-11-02-farmhouse/10-shelf-carrot-bunches.jpg), [11](playtest/2026-11-02-farmhouse/11-crates-at-the-dock.jpg)) | ✓ | single carrots two to a shelf looked bare ([09](playtest/2026-11-02-farmhouse/09-shelf-single-carrots-before.jpg)) → bunches of three |

Not covered: the bigger displays in Studio (the tests build every one), a phone's frame rate, night, 8 players.

### 2026-11-02 · the crops as meshes · build: this session's crop meshes
Testers: Claude, driving Studio · Setup: `art/crops/FarmHeistCrops.glb` imported (Import 3D, default settings) as ReplicatedStorage.CropModels; an edit-mode gallery built by the real FarmArt and ProduceArt (every crop sprouting, growing, ripe as it comes and on a bumper patch; every carried load), then solo Play (`/plant Tomato`, `/grow ripe`, `/tp field`, `/carry Strawberry`) · Lag: 0 (local) · Screenshots: [playtest/2026-11-02-crop-meshes/](playtest/2026-11-02-crop-meshes/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| The import | 63 MeshParts, each the size the generator drew it, in studs, no turn on the part; one texture | ✓ | the importer turned every mesh round inside its part (glTF faces +Z): found by comparing two meshes' offsets, fixed in the generator, imported again |
| Every patch in Studio's light | carrots, sheaves, potatoes in the furrows, lettuces, corn, onions, strawberries (white flowers while growing), staked tomatoes, peppers, pumpkins and melons on their vines, pineapples, the cocoa tree, the dragonfruit cactus, grapes on the trellis, the Moonmelon's glowing stripes, the fruit trees, the Crystal Rose, the Phoenix Pepper's glowing tip, the Dragon's Eye's glowing eye ([01](playtest/2026-11-02-crop-meshes/01-studio-common.jpg)–[06](playtest/2026-11-02-crop-meshes/06-studio-mythic-bumper.jpg)) | ✓ | the blueberry bush and the starfruit and apple crowns read as green boulders in Studio's sun → a darker leafy core with leaves sticking out ([03](playtest/2026-11-02-crop-meshes/03-studio-rare-epic.jpg)) |
| Carried loads | all 22 the right way round: bunches, crates, punnets on trays, baskets, the big crops alone ([07](playtest/2026-11-02-crop-meshes/07-studio-carried.jpg)) | ✓ | |
| In Play | a ripe tomato field from the farmhouse side and from beside the plants; "🍅 6 tomatoes · Ripe!" ([08](playtest/2026-11-02-crop-meshes/08-play-tomato-field.jpg), [09](playtest/2026-11-02-crop-meshes/09-play-tomatoes-close.jpg)) | ✓ | the locked land's stumps, rocks and weed blobs are still part-built and look plain beside the crops |
| Held up in Play | a tray of 4 punnets of strawberries over the head, both hands on it ([10](playtest/2026-11-02-crop-meshes/10-play-carry-punnets.jpg)) | ✓ | |

Not covered: every crop in Play (the gallery runs the same FarmArt), a phone's frame rate with a full field of meshes, 8 players.

### 2026-11-02 · a patch gives several, coins ×10, Field Levels · build: this session's yield change
Testers: Claude, driving Studio · Setup: edit mode for a gallery of all 22 crops ripe on a tilled tile (as a patch comes, and a bumper patch) and what a thief carries, then solo Play on a fresh v2 save (`/level 32`, `/field 1–5`, `/plant`, `/grow ripe`, `/carry`) · Lag: 0 (local) · Screenshots: [playtest/2026-11-02-yield/](playtest/2026-11-02-yield/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| Every ripe patch, by eye | rows on the ridges, every crop it gives shown ([01](playtest/2026-11-02-yield/01-patches-common.jpg), [02](playtest/2026-11-02-yield/02-patches-uncommon.jpg), [03](playtest/2026-11-02-yield/03-patches-rare.jpg), [04](playtest/2026-11-02-yield/04-patches-epic.jpg), [05](playtest/2026-11-02-yield/05-patches-legendary-mythic.jpg)) | ✓ | fixed: the ripe glow ring (a puddle of white or rarity colour under the rows → sparkles from the whole patch), wheat (walls of bread → baguettes → yellow figures → sheaves of crossing stalks pinched at the twine), cobs like bananas (→ out of green husks, tassels), peppers hidden in green balls, melons with no stripes (built across the wrong axis), the Moonmelon blown white, tiny blueberries and strawberries, pale onions like garlic, small lettuces, the Crystal Rose and Phoenix Pepper too small for Mythics (the pepper a stack of cylinders → a long chilli curling to its glowing tip); bushes and canopies now leafy clumps, not balls |
| What a thief carries | a whole patch: 6 carrots tied, 3 sheaves, 10 potatoes in a crate, 4 lettuces, 6 cobs, 7 onions on a string, 4 punnets on a tray, baskets of tomatoes, peppers, pods, dragonfruit, grapes, starfruit, golden apples; 2 pineapples; a pumpkin on its own ([06](playtest/2026-11-02-yield/06-carried-common-uncommon.jpg), [07](playtest/2026-11-02-yield/07-carried-rare-epic.jpg)) | ✓ | peppers tumbled like bananas → standing up; the corn bunch's cream twine like a plate → brown |
| Held up in Play | 6 carrots, a tray of 4 punnets, 10 potatoes, 4 peppers over an R15 avatar's head, both hands on them; the sign says how many ([17](playtest/2026-11-02-yield/17-carry-6-carrots.jpg), [18](playtest/2026-11-02-yield/18-carry-strawberry-tray.jpg)) | ✓ | "4 punnets of strawberries · Get home!" wrapped: the sign is wider |
| Field Levels 2–5 | composted soil and the compost bin, raised beds, drip lines and taps, gold caps and the PRIZE FIELD sign ([08](playtest/2026-11-02-yield/08-field-level-2-compost.jpg)–[14](playtest/2026-11-02-yield/14-compost-bin.jpg)) | ✓ | grass showed between patches inside the beds → soil under them; the compost heap was black |
| Harvest | a Field Level 2 carrot patch: "🥕 7 carrots · Ripe!", the Barn then 7 / 1,200 crops, "the truck pays 29 each now" | ✓ | (6 × 1.1: the extra rolled) |
| The Barn's Field tab | Level 1: the next level's card ("+10% crops from every patch you plant: 6 or 7 carrots a patch, 1 pumpkin, sometimes 2"), Upgrade 50,000, the ladder; Upgrade spent 50,000 and said "Field Level 2: Composted soil! Crops you plant from now on give 10% more."; the soil darkened ([15](playtest/2026-11-02-yield/15-barn-field-tab.jpg), [16](playtest/2026-11-02-yield/16-field-upgraded.jpg)); at Level 5 "the top … (9 carrots a patch)" ([20](playtest/2026-11-02-yield/20-field-tab-top.jpg)) | ✓ | "12,000,000" overflowed its stamp: it shrinks to fit |
| Barley's seeds | "🥕×6 a patch · ~30 each", "×3 a patch · ~90 each" (wheat) under each seed | ✓ | (small text on the card, readable) |
| The purse | 1,000 coins on a new save; 51,000 after `/coins` | ✓ | big amounts shorten ("12.3M") from a million |

Not covered: the STEAL stamp's count and a real steal (2 players), a bumper pumpkin left behind for the owner, the offline Welcome back counts, a phone, a full 8×8 field's part count on a phone.

**Would a new player understand it?**

| What a new player saw | Now |
|---|---|
| "+1 🥕" from a patch the size of a room | "+7 🥕", and seven carrots were there to see |
| A carrot seed "sells for ~18" | "🥕×6 a patch · ~30 each": one seed plants the whole patch |
| One field forever | a Field tab with the next soil, what it gives in carrots and pumpkins, and its price |

### 2026-11-02 · carrying stolen crops, the bat, travel, flicker, trucks · build: this session's rework of week 5
Testers: Claude, driving Studio · Setup: edit mode for a gallery of all 22 carried crops, solo Play for poses (one avatar, R15), then **Server & Clients with 2 players** (right the farmer, left the thief) · Lag: 0 (local) · Screenshots: [playtest/2026-11-02-carry/](playtest/2026-11-02-carry/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| The 22 carried crops | laid out in a row in edit mode and looked at three at a time ([01](playtest/2026-11-02-carry/01-produce-commons.jpg), [02](playtest/2026-11-02-carry/02-produce-uncommon-rare.jpg), [03](playtest/2026-11-02-carry/03-produce-epic-mythic.jpg)) | ✓ | fixed by eye: the carrots (a cream disc for twine, paper-flat leaves, roots splayed like stool legs → a slim tie, feathery fronds, the tips leaning in), the potatoes' and tomatoes' baskets (flat plates → deeper; then pancake-like bands → upright staves; the potatoes in a slatted crate), corn (eggs → kernel rows, longer husks), strawberries (upside down, then radishes → broad shoulders to a point, green stars: [04](playtest/2026-11-02-carry/04-strawberry-punnet.jpg)), the bell pepper's lid, the dragonfruit's paddles → scales on the skin, the golden apple, starfruit and Phoenix Pepper (flat Neon blobs → shaded; the pepper red to yellow: [05](playtest/2026-11-02-carry/05-golden-apple.jpg)), the Dragon's Eye's eye (buried in the pumpkin) |
| Holding a crop up | both arms up, hands on its sides, over the head, from the front, side and behind and walking ([06](playtest/2026-11-02-carry/06-carry-pumpkin-front.jpg), [07](playtest/2026-11-02-carry/07-carry-potato-crate.jpg), [08](playtest/2026-11-02-carry/08-carry-tomato-basket.jpg), [11](playtest/2026-11-02-carry/11-carry-walking-from-behind.jpg)) | ✓ | tall crops (carrots, the Crystal Rose) left the arms hanging: an IK target near full stretch is dropped, so hand spots now sit within 80% of the arm's reach ([09](playtest/2026-11-02-carry/09-carry-carrots.jpg), [10](playtest/2026-11-02-carry/10-carry-crystal-rose.jpg)); a crop sent before its hand spots arrived left the arms down: tried again each frame; all a bit small to spot across a farm: 1.2× |
| Climbing with a crop | up and over the back fence in 1.5 s, the crop held up throughout | ✓ | (a cartoon hop: no hands free for the fence) |
| A crate in your arms | both hands on its sides, close to the body ([12](playtest/2026-11-02-carry/12-crate-in-both-hands.jpg)); the bat leaves the hotbar while you carry it | ✓ | a crate's Carrying attribute was the same name as the new stolen-crop one (crate carriers would have looked like thieves): stolen crops use StolenCrop |
| The bat at rest | in the right hand by the grip, leaning back over the shoulder ([13](playtest/2026-11-02-carry/13-bat-rest-front.jpg), [14](playtest/2026-11-02-carry/14-bat-rest-side.jpg)) | ✓ | setting the arm's joints each frame was overwritten after the script ran: the hand follows an IK target instead |
| The swing | slowed ten times to see each pose: back behind the head, over the top, level out in front ([15](playtest/2026-11-02-carry/15-bat-hit-level.jpg)), down across, back | ✓ | the bat pointed down at the hit and sideways halfway (a turn from back to front has no single way round): poses over the top and up in front added, and each pose says which way the forearm comes in |
| Raids with 2 players | the steal ring and alarm ([16](playtest/2026-11-02-carry/16-steal-and-alarm.jpg)); the farmer sees the thief's arms up holding the pumpkin under the red ! ([17](playtest/2026-11-02-carry/17-farmer-sees-thief.jpg)); a bonk drops it back to the barn ([18](playtest/2026-11-02-carry/18-bonk-crop-returned.jpg)); HANDS FULL on a second crop ([19](playtest/2026-11-02-carry/19-hands-full.jpg)); the thief's screen shows the farmer's bat and swing | ✓ | in the farmer's own field the giant ripe pumpkins hide a carried one; the ! does the work there, and outside the field the crop overhead stands alone |
| Travel | Home, then Town at once, then Home at once: each starts its 3 s channel; no countdown on the signs ([22](playtest/2026-11-02-carry/22-travel-no-cooldown.jpg)) | ✓ | |
| Trucks | walking into the parked pickup stops at its tailgate; standing in its lane, the returning pickup backs in, stops 6 studs short with BEEP BEEP! ([20](playtest/2026-11-02-carry/20-truck-beep.jpg)), and parks once you step aside | ✓ | the first try went through: the server clears a trip's times when it's due, and the late truck jumped home; the client now keeps the trip until its truck is done |
| Flicker | the Packing Shed's back corners from outside, two frames a second apart, the same ([21](playtest/2026-11-02-carry/21-shed-back-corner.jpg)) | ✓ | the test finds none anywhere the server builds |

Not covered: R6 avatars (no poses; keep Game Settings → Avatar on R15), a phone, 8 players, lag on the swing (others see it from when the server hears of it).

**Would a new player understand it?**

| What a new player saw | Now |
|---|---|
| A stolen crop vanishing into a sack | the crop held up over the thief's head, the farm's own pumpkin, seen from anywhere |
| STEAL on a second crop after the first | HANDS FULL with the crop in hand: "You can carry one crop at a time: take the Pumpkin home first" |
| What to do with it: "🧺 2/5 · Get home!" | "🎃 Pumpkin · Get home!", then "· to your door!" in your own farm |
| The STEAL stamp once you're a Suspect: "Hold 2.5 s · 🧺 0/5" | "Hold 2.5 s, then carry it home over your head" |
| A truck driving through you | it stops and beeps until you move |
| Home greyed out with a countdown after using it | Home and Town always work (unless you're a raider) |

### 2026-11-02 · week 5 smoke test (raids) · build: this session's week 5
Testers: Claude, driving Studio (the chat's dev commands, the command bar for camera views) · Setup: solo Play for the art, then **Server & Clients with 2 players** side by side (left the farmer, right the thief), three sessions (fixes between them) · Lag: 0 (local) · Screenshots: [playtest/2026-11-02-week5/](playtest/2026-11-02-week5/)

Before playing: Studio's Rojo plugin was linked to another project's server (port 34872), which had synced that project's scripts into this place in memory (a loading folder in ReplicatedFirst, a Health script, streaming off). Farm Heist's own Rojo server ran on port 34873 for the session; the stray instances were removed in memory only (the saved place file is older and clean).

| Check | Result | OK? | Notes |
|---|---|---|---|
| The bat | the first packet in the hotbar inside your own farm (gone outside it); 1 takes it in hand; a taped grip, a knob, a wooden barrel | ✓ | a little long: shortened ([18](playtest/2026-11-02-week5/18-bat-in-hand.jpg)) |
| Steal | on someone else's ripe crop the stamp says STEAL with the crop, and the chalkboard warns that stealing makes you a Suspect; holding it fills a ring of dots over the crop for everyone, the crop shakes; 2.5 s for a Pumpkin, then it's in your sack | ✓ | the hold bar over the stamp was half hidden under the chalkboard: moved ([08](playtest/2026-11-02-week5/08-steal-ring-mid-hold.jpg)) |
| The alarm | the owner: a red pulse round the screen, "🚨 Player1 is stealing your 🎃 Pumpkin! Run over and press SWING…", a red ! over the thief seen from anywhere in the farm; the thief's tag turns red: TRESPASSING ([07](playtest/2026-11-02-week5/07-alarm-and-trespassing.jpg)) | ✓ | the red edge never faded (a reversing tween ends where it began): fixed |
| The sack | on the thief's back with the Pumpkin's top poking out; "2/5 · Get home!" over the hotbar with an arrow to your barn; the travel signs hidden; walking at 13.6 studs a second (157 studs in 11.5 s); emptied at your door ([09](playtest/2026-11-02-week5/09-stolen-get-home.jpg)) | ✓ | the sack was huge and sat beside the character like an egg: smaller and snug on the back ([06](playtest/2026-11-02-week5/06-sack-on-back.jpg)) |
| Bonk a Suspect | "BONK!" and gold stars; the thief flat on their back with dizzy stars, their screen grey and blurred: "You're a Suspect: the farmer can arrest you!"; the owner: "Recovered from Player1: 🎃 Pumpkin ×2. It's back in your barn." and an ARREST stamp ([10](playtest/2026-11-02-week5/10-bonk-suspect-recovered.jpg)) | ✓ | swings missed when the thief stood beside or behind the owner: the swing now turns you to face the nearest person in reach, waits a beat (the wind-up) so the server sees the turn, and anyone within 3 studs is hit whichever way you face |
| Arrest | hold ARREST 1 s: the thief's BUSTED! card (their avatar in front of a height chart, a number board, the charge, the fine and who it's paid to), then the police porch; the owner's "🚔 ARRESTED!"; coins 100 → 75 and 100 → 125 ([11](playtest/2026-11-02-week5/11-busted-and-arrested.jpg)) | ✓ | |
| Into debt | a thief with 0 coins: fine 1,131 (1.5 × a Hot Crop Pumpkin), all of it owed; both cards say so ([14](playtest/2026-11-02-week5/14-busted-into-debt.jpg)) | ✓ | "paid 0 of their fine" read oddly: "had no coins, so they owe you…" |
| Debt paid from sales | `/earn 200` while owing: the thief kept 100, the farmer 100 → 200 | ✓ | nobody was told why: notes for both now ("100 coins of your sales went to your debts", "💰 Player1 paid you 100 coins of their fine"), at most every 30 s |
| Police desk | the station's desk with Sheriff Clucks, E: the Police Desk window (record, "You owe 1131 coins", to whom and when it's forgiven, Pay) ([15](playtest/2026-11-02-week5/15-police-desk-window.jpg)) | ✓ | "forgiven in 6 days" a minute after the fine: rounds up now (7) |
| An innocent visitor | bonked: "You're just stunned. You did nothing wrong." and Leave farm → "You'll wake up outside", then on the sidewalk outside the gate; the owner's stamp said "only visiting (bonking pays nothing)" ([12](playtest/2026-11-02-week5/12-innocent-stunned-leave-farm.jpg), [13](playtest/2026-11-02-week5/13-woke-up-outside.jpg)) | ✓ | |
| Travel as a Suspect | Home: refused | ✓ | the refusal said only "You can't travel right now": now "No travel while you're a Suspect or carrying stolen crops: walk!", and the signs show 🚫 meanwhile ([20](playtest/2026-11-02-week5/20-travel-blocked.jpg)) |
| Climbing | CLIMB at a back fence, red with "Climbing into Player2's farm makes you a Suspect!" from the trail; the character goes up and over in 1.5 s; the owner: "🚨 Player1 is climbing over your back fence!" ([16](playtest/2026-11-02-week5/16-climbing-in-alarm.jpg)) | ✓ | |
| Quitting while knocked out as a Suspect | the thief's window closed during the knockout: "🚔 Player1 fled arrest! Fined 56 (×1.5): +56 coins." to the owner ([17](playtest/2026-11-02-week5/17-fled-arrest.jpg)) | ✓ | 25 × 1.5 (second arrest) × 1.5 (fled) = 56. A first try closed the window after the knockout had ended: no fine, which is right (awake and empty-handed) |
| Reset | Roblox's Respawn greyed out while a Suspect; back once you're not | ✓ | |
| The same-farm cooldown | after an arrest the thief couldn't steal there again (3 min) | ✓ | |

Bugs found and fixed in the session: the hold bar under the chalkboard, the alarm's red edge stuck on, missed swings beside or behind you, the knockout card's Suspect line set once (a late attribute showed the innocent text: it updates live now). By eye: the sack's size and place, the bat's length, the porch roof (a heavy navy slab → blue and cream stripes with a striped flap along the front, since from the square the roof is seen edge-on: [01](playtest/2026-11-02-week5/01-police-station-eye-level.jpg), [02](playtest/2026-11-02-week5/02-police-awning-from-above.jpg)), Sheriff Clucks looked like a snowman (a red comb through his hat, bigger eyes: [03](playtest/2026-11-02-week5/03-sheriff-clucks-desk.jpg)), the rules poster half behind the bench ([04](playtest/2026-11-02-week5/04-rules-poster.jpg)), the door lamps glowing white, the knockout card covering your own knocked-out character (it sits higher now: [19](playtest/2026-11-02-week5/19-knocked-out-pose.jpg)); anything in hand drops on a knockout.
Not covered: leaving with loot while chased (D2) and without (D3), dying while knocked out, rejoining within 2 minutes (Studio can't rejoin a closed client), the payout queue across servers (needs API access), a server shutdown (D8), lag (0.2 s), a phone, 8 players, the raid race with real timings (Stage D, after week 6's defences).

**Would a new player understand it?**

| What a new player saw | Now |
|---|---|
| STEAL with no warning of what follows | the chalkboard: "Stealing makes you a Suspect: the farmer can bonk and arrest you!" (once a Suspect: the hold time and the sack) |
| SWING next to a visitor who'd done nothing | "Player1 is only visiting (bonking pays nothing)"; next to a Suspect "Player1 is a Suspect: bonk, then arrest!" (and SWING only offers itself near a visitor when the bat's already in your hand) |
| A Suspect pressing HOME: "You can't travel right now." | the reason, and 🚫 on the signs while it lasts |
| The farmer's coins going up from a debt with no word | "💰 Player1 paid you … of their fine" (and the debtor is told where half their sales went) |
| "Player1 paid 0 of their 1131-coin fine to you" | "Player1 had no coins, so they owe you their 1131-coin fine: half of their sales come to you until it's paid" |
| The back fence: can you get over? | the CLIMB stamp beside it, and a hand-painted "PRIVATE FARM · No climbing!" sign on the trail side |
| How do arrests work? | the WANTED poster by the police station's door: "Bonk them with your bat, then ARREST them. Their fine is yours!" |

### 2026-11-01 · week 4 smoke test (warehouse levels and workers) · build: this session's week 4
Testers: Claude, driving Studio (the chat's dev commands, the command bar for camera views) · Setup: solo Play, desktop, two fresh Play sessions (the second after the fixes below) · Lag: 0 · Screenshots: [playtest/2026-11-01-week4/](playtest/2026-11-01-week4/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| The first hire | the Hire tab's board, 3 candidates a job, "Your first hire is free!"; Eli the Shed Hand hired free; the board then says hiring more needs Farm Level 2 | ✓ | Farmhands were offered Careful (+grade A, useless to them): traits now only come on jobs they help. The Hire buttons now look disabled below Level 2 |
| The Shed Hand | with 60 carrots in the barn he packed 5 crates: 4 into the pickup, the fifth onto the dock's rack (1/6); 3 of 4 came out grade A (50% with Careful) | ✓ | wages came out each minute (100 → 93) |
| Levels by hand | Upgrade tab: Level 1 → 4 instant, Level 5 started the Distribution Warehouse (2:00, scaffolding round the new walls, "the old building keeps working") | ✓ | a milestone's long list of news shrank to tiny text in the ladder: those rows are taller now |
| The new building | the Distribution Warehouse went up when the timer ran out; outside: metal walls, a low roof, the name board and dock door in the farm colour, the staff door with its awning; inside (roof faded while you're in): the conveyor from the intake hopper past the Sort and Pack tables to the pallets, the Cold Room, the wash table | ✓ | **bug**: the Cold Room's count sign looked for its label in the wrong place, and the error stopped the level-up halfway (no toast, no dock prompts, the crew not moved). Fixed and tested. The Cold Room's top trim was a solid lid: now a trim round its walls, open above. A darker base band added to the walls |
| A full crew | `/crew 3`: a Farmhand, Sorter, Packer, Loader and Driver at their stations in their outfits (the Loader's hi-vis vest and hard hat, the Driver's cap by the box truck's cab); the Pipeline tab marked Wash & Sort orange as the bottleneck (2.7 crates a minute) with its tip | ✓ | at the Packing Shed (one station) it no longer calls the bench a bottleneck |
| Routes | 🚚 / 🏪 / ✋ and − + for a split: 80% · 20% shown | ✓ | |
| Several trucks | Level 10: two semis at numbered docks, a lane and boom each; Semi 1 sent from the window drove out of its lane and up the ring road, its receipt shown | ✓ | **bug** in the first session: after the warehouse was rebuilt while the pickup was out, its parts streamed in late and landed 170 studs off when it came home (StreamingEnabled). Trucks are now persistent models (always whole on every client), booms atomic; the second session's semi drove out and back cleanly through a rebuild |
| Level 20 | the Distribution Center: flat roof with skylights and air units, gold trim, docks 1–3, three reefers | ✓ | the name was cream on gold: now dark letters on the gold board |
| Strike | coins below a minute's wages: "on strike" toast, everyone sitting on a crate holding a sign; `/state` shows strike true; coins back → "Wages paid: your crew is back at work" | ✓ | the sign was small and the name tag hid it: bigger, held higher, the tag lifted while striking |
| Welcome back | `/away 8`: away 8 h, crops kept growing, 49 crates packed, 1 truck sent +8,724, wages −6,090, +2,634 | ✓ | the numbers match the crew's wages (51 a minute × 25% × 480) |
| The store's crew | Store Level 8, carrots routed to the store: the Stockers (green polos) filled the displays without a hand from me, the Greeter (gold sash) by the door, shoppers buying | ✓ | no Register placed, so no Cashier tried (the next session) |
| The Workers window | badges: photo, name, job, level and speed, wage, the XP bar (a Packer's filled from work while "away"), Train with its fee, Let go | ✓ | |

Bugs found and fixed in the session: the level-up stopping halfway (the Cold Room sign), trucks streaming in part by part. Also polished: traits by job, the disabled Hire buttons, the bottleneck at the shed, the ladder's milestone rows, the Cold Room's open top, the base band, the gold sign's ink, the strike sign. Added `/state` (prints the save's warehouse and crew to the Output: the command bar can't read the live save).
Not covered: a Cashier at a Register, a Farmhand harvesting a real field, the hand cart at the warehouses, the Drivers' price rule, a real absence (Studio's mock save keeps nothing), a phone, 8 players.

**Would a new player understand it?** (asked by the user during the session; every screen looked at again as a first-time player, fixed, then checked in a third Play: [12](playtest/2026-11-01-week4/12-tags-signs-badge.jpg), [13](playtest/2026-11-01-week4/13-pipeline-plain-words.jpg))

| What a new player saw | Now |
|---|---|
| The side bar said "WAREHOUSI" (cut off) | crate labels shrink to fit: "WAREHOUSE" |
| "Sorters 1/1 (next: Warehouse Level 8)", "228 units", "tiles a minute", "replant: same" | "1 of 1 Sorters · more at Warehouse Level 8", "228 crops waiting", "crops a minute", "they replant the same seed", and a first row saying how crops flow from the field to the trucks |
| "…is your bottleneck" | "🐢 Slowest step: hire another Sorter, or train yours to speed it up" |
| Routes as bare emoji (🚚 🏪 ✋: what's ✋?) | "🚚 Truck", "🏪 Store", "✋ Keep", and the line above says Keep leaves it in the barn |
| "Change" buttons cycling through choices you couldn't see (the Drivers' rule, the Farmhands' replanting) | every choice is a button, the current one green ("When full · 90%+ · 100%+ …"; "Same seed · Cheapest · Nothing"), with a line on what it means |
| "47%", "wage 5.4/min" on badges and candidates | "47% speed", "paid 5.4 coins/min", "learns by working" on the XP bar |
| "0/0 · next slot: Warehouse Level 5" on the Hire tab | "🔒 opens at Warehouse Level 5", "2 of 3 hired", "full · more at …", "🔒 needs a Register in your store" |
| Ladder news: "a Sorter", "Driver 2", "conveyors ×1.1", "50 s round trip" | "room for a Sorter", "room for a 2nd Driver", "conveyors 10% faster", "trips take 50 s", "a new building: the … (2 min to build)" |
| Tables inside the warehouse all looked alike (only the intake had a sign) | hanging signs: WASH & SORT, PACK, LOAD THE TRUCKS |
| Name tags "Daisy · Lv 3": who's she? | "Daisy · Packer Lv 3"; workers side by side get their tags at different heights so they don't overlap |
| Nothing on screen once the "ready to train" or "on strike" toast had gone | a badge on the Workers crate: a green ⭐ when someone's ready to train, a red ! during a strike |

### 2026-10-31 · see-through roofs and the light inside (check by eye) · build: this session's week 3 + the resize
Testers: Claude, driving Studio (the chat's dev commands; the command bar for the lighting comparisons and to zoom the follow camera out) · Setup: solo Play, desktop · Lag: 0 · Screenshots: [playtest/2026-10-31-roofs/](playtest/2026-10-31-roofs/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| Walking in | the roof, the false front and the ceiling lamps fade as you pass the door; the sign's words go with them | ✓ | Corner Store, Farm Shop (its gable too), Market Hall, Supermarket |
| The camera | zoomed out inside, it rises over the walls and looks down into the room (it stopped at the ceiling before) | ✓ | |
| Walking out | the roof and signs come back a stud outside the door; the stand-in toward the sun is gone (1 inside, 0 outside); Brightness and OutdoorAmbient never changed | ✓ | |
| Decorate inside | opens and closes normally; the roof stays hidden while you're still inside; the plan view is shaded, the yard round it sunny | ✓ | |
| The light | the stores were glaring inside (white walls, 6 bright lamps; then the sun once the roof faded). New inside colours and lamps at 0.45; then the indoor-light mode (it darkened the farm outside: dropped at the user's word); then the roof's stand-in 800 studs toward the sun: each building shaded, close to its roofed look side by side once the Supermarket's colours were warmed | ✓ | the farm through the windows and over the walls in full daylight |
| The stand-in | its shadow works from 600 to 1,500 studs (not 3,000); at 800 a glowing white one can't be seen even looking straight at the sun, nor at sunset (sun 5.5° up) | ✓ | grey, at 600, it showed in front of the sun |
| The doorway | the Supermarket's character walked straight in (0.8 s from the sidewalk) | ✓ | it stalled at a plinth across the door before (the user spotted it) |

Bugs found and fixed in the session: the glare (above); the Supermarket's plinth across its doorway (a 1.2-stud ledge), now stopped either side and tested. Tried and dropped: darkening the exposure inside, a nearly invisible roof for its shadow (a 97% invisible part casts none), indoor light on your screen (darkens the outside).
Not covered: a real phone (lower graphics draw shadows shorter or not at all), the night (§4.14 isn't built yet).

### 2026-10-31 · bigger stores, a bigger valley (check by eye) · build: this session's week 3 + the resize
Testers: Claude, driving Studio (the chat's dev commands, the command bar for camera views) · Setup: solo Play, desktop · Lag: 0 · Screenshots: [playtest/2026-10-31-store-sizes/](playtest/2026-10-31-store-sizes/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| Level 1 | a 6×4 floor in an 8×6 Corner Store (34 studs of frontage): the starter kit on the back wall, the middle of the floor free, the taped-off column and row with the "Next level!" boxes | ✓ | |
| Level 4 | the whole Corner Store open, the back row moved back to the wall | ✓ | |
| Farm Shop (Level 9) | the red barn, two windows with the name over them, the barn door and hayloft; inside 11×9 with cord lamps and its free Tiered Rack | ✓ | |
| Market Hall (Level 14) | four arched windows with flower boxes, the timber storey with little windows either side of the name, the clock parapet; inside 15×11 | ✓ | |
| Supermarket (Level 20) | 80 studs of glass front, the name band, the canopy, the trolley bay, the billboard and gold star; inside 20×14 under light strips | ✓ | |
| Fit | from above: the side yard by the hedge, the strip by the gate, the yard before the farmhouse, the stockroom lean-to open to it; the highway clear between Farms 1 and 8 | ✓ | |
| From town | the farms' fronts and stores along the ring road, a wide green between | ✓ | the green is bare until the town's look pass (ArtDirection §6) |
| Shoppers | 12 called with `/shoppers`: along the longer sidewalk, in through the door, browsing the back wall, queueing up the side wall at the Honour Box, paying (100 → 604 coins) | ✓ | |
| Decorate | frames the whole Supermarket; zooms in further on a big building | ✓ | |

Bugs found and fixed in the session: none in the game. The canopy's posts would have stood on the sidewalk, so it hangs from the name band on tie rods instead. Studio crashed once before the session (a graphics driver "device removed" error) and updated itself on reopening.

Not covered: a real phone (the tap size zoomed in, and frame rate with several full Supermarkets in view), 8 players.
Follow-ups: C9 on a real phone in a Supermarket; the part budget with full stores once streaming is on.

### 2026-10-31 · week 3 smoke test (your store) · build: this session's week 3
Testers: Claude, driving Studio (keyboard and mouse, the chat's dev commands, the command bar for camera views and walking) · Setup: solo Play, desktop and iPhone 17 Pro emulation · Lag: 0 · Screenshots: [playtest/2026-10-31-week3/](playtest/2026-10-31-week3/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| The farm's front | picket fences, rounded hedges, the gate arch with "XD2MUCH's farm" on its plank (both sides), a red flag and mailbox in Farm 1's colour; the Corner Store on the road with its hand-painted name and striped awning | ✓ | |
| Into the store | through the door from the sidewalk; the chip says "🏪 XD2MUCH's Corner Store"; the shelf, crates, plant, Honour Box, ceiling lamps and the taped-off floor with its "Next level!" boxes | ✓ | the doorway was glazed: fixed (1) |
| Staff door | out to the yard by the gate (the chip goes back to "Your Farm"); the door swings open as you come and shuts behind you | ✓ | |
| Stockroom | bench: 🏪 Store with the store's price, "Stockroom 1/6 crates", "Crate sent to your store's stockroom"; the lean-to behind the store shows each crate (crop on top, grade A sticker) | ✓ | |
| Fill | "Fill all" in the Stock tab put 48 units out (a different crop on each Auto slot); E at a display: "Fill · Produce Crate 0/12 · stockroom 0" | ✓ | |
| Shoppers | in from the sidewalk, along the aisle to the slot with their crop, bubbles ("🥕×2", "Too dear!"), baskets that fill, a queue at the Honour Box, "+66" when they pay; coins 100 → 845 in a rush of 8 | ✓ | bubbles were inside the ceiling: fixed (2) |
| Store window | name and Rename, rating with Charm and why, Prices, Stock, Upgrade (the next level on blueprint paper and the ladder) | ✓ | the ✎ glyph didn't draw: "Rename" (3) |
| Upgrade | Levels 2–4 straight away; Level 5: 6,000 paid, "the builders are on it", scaffolding round the new footprint and a countdown sign by the gate; two minutes later the Farm Shop with its free Tiered Produce Rack, the shelves moved back with the floor | ✓ | an error every second in the countdown stopped every store's shoppers: fixed (4) |
| Decorate | top-down plan, the drawer with 3D pictures, green/red with why ("That's in front of your Produce Crate", "Leave the space in front of it free"), turn, place, move, put away (refused for the last checkout), DONE refused with too few coins, then "Saved! Spent 150"; a Clock hung on the back wall | ✓ | eight look and feel fixes (5) |
| Buildings | Corner Store, Farm Shop (red barn, gable roof, barn door, hayloft), Market Hall (brick and timber, arched windows, clock), Supermarket (glass front, name band, rooftop billboard, the Level 20 star) | ✓ | three look fixes (6) |
| Phone | the side bar in two columns above the thumbstick; the Store window fits; Decorate with the touch buttons hidden | ✓ | the store was too small to tap: zoom and pan added (7) |

Bugs found and fixed in the session:
1. The wall builder sorted its list of openings in place, so the glass meant for the big window went into the doorway (nobody could get in) and that window had no glass.
2. Shoppers' bubbles floated 10.75 studs up, inside a Corner Store's 10-stud ceiling: now 7.5, above their heads.
3. "✎", "⟳" and "✕" don't draw in FredokaOne: the buttons say Rename, Turn and Cancel.
4. The construction countdown looked for its label in the wrong place and errored every second inside the store loop, which stopped every store's shoppers: fixed, and each store's tick now runs on its own (one store's error is logged, the rest carry on).
5. Decorate: mouse positions leave out Roblox's top bar, so the ghost sat a row off (now `ScreenPointToRay`); the awning, signs and false front still covered the front row (everything above the doors or in front of the window is hidden, and so are the words on them); the ticker came back over the view; the cards' detail line ran under the price tag; the ghost's Highlight didn't draw (a glowing green or red footprint instead, gold for a picked item); the white grid vanished on white tiles (blueprint blue); DONE sat under the toasts (now bottom right, tools on the left); Esc opens Roblox's menu (the hint no longer offers it); the camera stayed overhead afterwards (it goes back behind your character); the hint hid wall items on the back wall (more room at the top).
6. Inside the Farm Shop the walls were barn red and the lamps floated under the gable (cream plaster inside, lamps on cords with shades); the Market Hall's striped window awnings hid its name sign (flower boxes in the farm colour instead); the Level 20 star was a plain square (a big gold ★).
7. On a phone the floor was about 75 points tall: pinch (and the mouse wheel) zooms, a drag (or WASD) moves the view, the touch buttons hide, and the drawer and top margin are smaller.

Not covered: pinch on a real phone (the emulator has no pinch), a Register with you behind it (it needs Store Level 3 and standing at the till), selling an item back, 8 players, saving across sessions (API access is off), new testers (C9 wants real people).
Follow-ups: Stage B and C with testers; C9 (decorate on a phone) on a real phone.

### 2026-10-31 · week 2 smoke test (selling) · build: this session's week 2
Testers: Claude, driving Studio (keyboard and mouse, the chat's dev commands, the command bar for camera views) · Setup: solo Play, desktop and iPhone 17 Pro emulation · Lag: 0 · Screenshots: [playtest/2026-10-31-week2/](playtest/2026-10-31-week2/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| Bench | E at the bench opens it; each stack shows 🚚 Truck and 🏪 Stand with today's prices (Pumpkin 573 / 592, Carrot 19 / 19) | ✓ | |
| Wash | let go at 1.1 s → gold "A" rosette; at 0.3 s → "Grade B" tag | ✓ | the server's timing agreed with the meter every time |
| Carry and load | crate in the arms (carrots on top), "Load crate" at the dock: Pickup 1/4 → 2/4 | ✓ | |
| Set down | travelling to town with a crate: "You set the crate down at the dock"; later "Load crate" took it from the pile | ✓ | |
| Send | Send now in the Market window from town: receipt slip (each crate, its locked price, 464 total); the lever too | ✓ | |
| Drive | out through the boom gate (it lifts and drops), round the ring road, up the highway into the tunnel; back down the highway, backing up to the dock | ✓ | from Farm 1 the trip to the tunnel takes about 12 s |
| Payout | +464 coins as it reached the City (30 s), "back at the dock" at 60 s | ✓ | |
| Exchange board | 22 crops, split-flap prices, ▲/▼, readable from the plaza | ✓ | long names wrap to two lines |
| Market window | prices, ▲/▼, sparklines, the Glut with its countdown | ✓ | the next hour's Hot Crop wasn't shown once this hour's was over: fixed |
| Stand | "Stock shelves" fills the baskets; price tags everyone can read ("🎃 595"); shoppers walk the sidewalk, buy grade A at ×1.15 (684 for a 595 Pumpkin); bubbles "🧺 🥕×2 +46" and "😟 🥕 too dear!"; "sold out" note | ✓ | four things fixed, below |
| Prices | − / + move the price a step (17 → 20); the face and "% buy · ~N a minute" follow | ✓ | |
| Sales XP | selling a crate of grade A Pumpkins took a new save to Farm Level 2 | ✓ | |
| Phone | the purse, ticker, signposts and windows fit | ✓ | the side bar's third crate sat on the thumbstick: fixed |

Bugs found and fixed in the session:
1. The stand's "Stock shelves" prompt said "Stockroom: 0" after crates arrived from the bench (it only refreshed on stocking): the bench now refreshes it.
2. A stand with only Carrots put them on one basket and left the other empty (one crop per shelf, no repeats): the rest now fills the empty basket; the window's sales estimate counts a crop's baskets.
3. The rating jumped from 3★ to 2★ on the first unlucky shopper: a new stand counts 10 shoppers at 3★ that real ones replace (`Shop.RATING_SETTLE`).
4. The Stand window cut off its notes (the empty-stockroom line, the "Truck or stand?" tip): notes use the whole row.
5. The Market window had nothing to say once the hour's Hot Crop had ended: it shows the next hour's.
6. On a phone the side bar's third crate sat on the thumbstick: smaller crates on phones (58×52).

Not covered: 8 players, saving across sessions (API access is off), a new tester (C1–C3 want real people), offline selling (week 3).
Follow-ups: Stage B and Stage C with testers. Testing note: a client-side teleport from the command bar gets you sent back by MovementService (as it should), and the dock then refuses; walk or use `/tp`.

### 2026-10-30 · week 1 smoke test (not Stage B yet) · build: this session's week 1
Testers: Claude, driving Studio (keyboard, the chat's dev commands, the command bar) · Setup: solo Play, desktop and iPhone emulation · Lag: 0 · Screenshots: [playtest/2026-10-30-week1/](playtest/2026-10-30-week1/)

| Check | Result | OK? | Notes |
|---|---|---|---|
| Join | spawned at your farmhouse door, facing the field, after the "Farm Heist" sign | ✓ | |
| Plant · water · harvest | the stamp changes with the tile; growth timer right; `/grow ripe` then one press harvests | ✓ | a long press used to harvest, replant and water: fixed |
| Hold and walk | plants every tile crossed | ✓ | |
| Barley's | `/tp barley`, E opens the rack, Buy ×5 and ×1 take 50 and 10 coins, seeds arrive | ✓ | |
| Level up | `/level 2`: the rosette card with the Land Permit line; yellow signs on the field | ✓ | the note sat under the rosette's tails: fixed |
| Clear land | sign (250 coins) → 4 holds of 2 s → tilled fresh soil (+25%) | ✓ | nothing showed where the far obstacles were: they glow now |
| Home | 3 s bar, teleport, cooldown on the sign | ✓ | |
| Phone layout | purse top centre, crates top left, stamp beside the jump button, boot Run stamp above it | ✓ | |

Bugs fixed during the session: see GameDesign §10 "MVP week 1". Not covered: 8 players (B9), saving across sessions (B7 needs API access on), a new tester (B1).
Follow-ups: Stage B with a real tester.

### 2026-10-30 · Stage A · build 0795bb8 + this session's changes
Testers: Claude, driving Studio (walks scripted with `Humanoid:MoveTo`, timed every 0.25 s; screenshots in [playtest/2026-10-30/](playtest/2026-10-30/)) · Setup: solo Play · Lag: 0

| Case | Result | Pass? | Notes |
|---|---|---|---|
| A1 | Farm 1: 14.8 s (235 studs) · Farm 5: 12.8 s (204 studs) | ✓ | One run each. Farm 5 is the nearest farm to the town spawn, so the bar is now 12.5–17 s |
| A2 | 1.3 s walking (20 studs) · 1.6 s at sack speed | ✓ | |
| A3 | 6.7 s (158 studs), sprinting at 24 | ✓ | `tools/raidrace` assumes 160 studs |
| A4 | Back fence, hedge, front fence: all blocked | ✓ | The first runs never really jumped: the player controls reset `Humanoid.Jump` every frame. Re-run with forced jumps: the highest the character got was 10.4–10.5 studs (root), a normal jump. Without the invisible wall, the new rail fence gets climbed like a ladder, so the wall stays |
| A5 | You can see a player on the back row from the farmhouse door and from the warehouse | ✓ (barely) | They're about 10 px tall at 135–160 studs, and the rocks on locked land hide some of the back row. Needs the Suspect "!" ([ArtDirection §9](ArtDirection.md)) |
| A6 | 49.2 s, 785 studs (police porch → behind Farm 1, the farthest) | ✗ against 24–36 s | The plan's bar came from straight lines through the plots. On real routes it's 590–790 studs (37–49 s); with Visit and a walk round the hedge, about 30 s. Doc, test and bar corrected |
| A7 | Not run | — | Needs a new human tester |

Bugs: none in the code. Walking from Farm 5's gate straight to the police porch runs into the back of the Police Station; players walk round it (the town's paths will lead the way, ArtDirection §6). ProfileStore ran on its mock store (API access is off), which Stage A doesn't need; B7 does.

Changes made because of this session:
- GameDesign §3 and `tests/layout.test.luau`: the arrest walk is measured along real routes; §4.10: the same-farm cooldown also starts after an arrest.
- PlaytestPlan: A1 bar 12.5–17 s; A6 redone.
- WorldBuilder: labels sized in studs and hidden beyond 45–260 studs; fences 8 studs, posts and rails (`PlotLayout.FENCE_HEIGHT` 5 → 8), invisible walls kept.
- `tools/raidrace` unchanged: 5.8 / 11.4 s for the thieves, 7.7 / 10.4 s for the owner.
- New: [ArtDirection.md](ArtDirection.md), written from this session's screenshots.

Follow-ups: A7 with a new tester; walk A1 and A3 by hand with the keyboard to feel them (3 runs each); then the look pass and week 1.
