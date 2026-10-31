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
