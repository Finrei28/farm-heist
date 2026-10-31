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
