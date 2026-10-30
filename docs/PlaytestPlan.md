# Farm Heist: Play-test plan

_Last updated 2026-10-30 · goes with [GameDesign.md](GameDesign.md) §9 (MVP weeks) and §11 (next steps). Record every session in [PlaytestLog.md](PlaytestLog.md)._

## Why play-test, and what the tests don't cover

The Lune tests (`lune run tools/check`) prove the **rules** are right: growth, prices, fines, every arrest dodge, the layout. The sims (`tools/progression`, `tools/raidrace`) prove the **numbers** add up on paper. Neither can tell us:

1. **Feel and fairness.** Is a raid fun from *both* sides? Does being bonked feel funny, not mean?
2. **Real movement and lag.** Do the raid race's seconds hold with real characters, real cameras, real latency?
3. **Clarity for kids (9–16).** Do players understand Suspect, TRESPASSING, Land Permits and truck vs shop without being told?
4. **Exploits that need two real clients.** Quitting mid-knockout, resetting, teleport buttons, staged arrests.
5. **Pacing in practice.** Real players play slower and less optimally than the sim.

So each stage below tests the riskiest assumption the build can answer by then. Each test case has a **question**, a **setup**, **steps**, **what to measure** and a **pass bar**.

## How every session runs

**Before:**
- [ ] `lune run tools/check` says "Ready to publish". Note the build: the git commit, or the date and time if there's no git yet.
- [ ] `rojo serve` running; Studio connected (Plugins → Rojo → Connect).
- [ ] Testing saves? Use a **separate store** so test data never mixes with real saves: set `PROFILE_STORE_NAME = "FarmHeist_Test_v1"` in `Config/Settings` for the session, and put it back afterwards.
- [ ] Multi-player in Studio: **Test → Clients and Servers**, pick the number of players, **Start**. Each client is its own window.
- [ ] Lag on purpose: **File → Studio Settings → Network → Incoming Replication Lag** (0.1, 0.2, 0.3 s), for the timing tests.
- [ ] A stopwatch (a phone is fine), this plan open, and [PlaytestLog.md](PlaytestLog.md) open to fill in.

**During:**
- One person plays, one watches and writes. Don't help testers unless they've been stuck for 60 s; a stuck tester *is* the finding.
- Timings: start the stopwatch on the event (alarm, hold starts), stop on the outcome. Do 3 runs, write down all three.

**After:**
- Fill in the log: cases, numbers, pass or fail, bugs, follow-ups.
- Numbers that disagree with a sim by more than the stated tolerance: change `Config/*` or `PlotLayout`, re-run `tools/raidrace` / `tools/progression` and `tools/check`, and note it in GameDesign §10.

## Dev commands each stage needs

Build them in `DevCommandService` (Studio only, plus `Util/Staff` in live servers) **before** the stage that uses them. Testing without them means waiting hours of real time.

| Command | Does | Needed from |
|---|---|---|
| `/coins N` | add coins | Stage B |
| `/level N` | set XP to reach level N (and its Land Permits) | Stage B |
| `/grow H` | fast-forward your field H hours online | Stage B |
| `/away H` | settle H hours offline (growth and workers), show the Welcome back card | Stage C |
| `/restock full` | everything in stock at Barley's until the next restock | Stage B |
| `/tp N` · `/tp town` · `/tp porch` | teleport (through `MovementService.Teleport`) | Stage A–B |
| `/stopwatch` | prints server time to Output (for timing from logs instead of a phone) | Stage A |
| `/shield off` | end your Sprout Shield and arrival grace now | Stage D |
| `/ko` · `/suspect` | knock yourself out / mark yourself a Suspect | Stage D |
| `/crimelog` | prints your visits, debts, last arrests, raid ledger | Stage D |
| `/weather X` · `/auction now` | force weather; start an auction | Stage E |
| `/wipe` | reset your save (test store only) | all |

## Stage A: walk the greybox (now: solo, Studio, ~30 min)

**Question:** do the layout's distances and sightlines feel right before anything is built on them?

There's no sprint key yet. To sprint, switch Studio's command bar to the **client** (the "Current: Client" toggle on the Test tab) and run `game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 24` (normal walking is 16). The anti-teleport check allows up to 30.

| # | Case | Steps | Measure | Pass |
|---|---|---|---|---|
| A1 | Town to a farm | Spawn → walk to Farm 1's gate, then Farm 5's | seconds, 3 runs each | 12.5–17 s (layout says 205–265 studs) |
| A2 | Back row to the fence | Stand on a back-row tile (furthest from the farmhouse) → walk straight to the back fence | seconds | about 1.5 s walking (24 studs); about 1.8 s at sack speed (13.6) |
| A3 | Owner's sprint | From the yellow Door pad, sprint (24) to the back fence behind the middle of the field | seconds | 6–7 s (`tools/raidrace`: 160 studs; ±0.7 s is fine) |
| A4 | Fences | Try to jump the back fence, each front fence stretch, the hedges | did you get over? | **never** (only the open gate lets you in) |
| A5 | Sightlines | From the farmhouse door and from the warehouse, look at the back row | can you see a player standing there? | yes from both (raid detection needs it) |
| A6 | Arrest walk | `/tp porch` → walk to the back of the farthest farm; then Visit a farm and walk round its hedge to the back fence | seconds | on foot 37–49 s (round the plots); Visit + walk about 30 s. Note if either feels too long or short |
| A7 | Getting lost | A new tester: "go to Barley's Seeds, then back to Farm 3" | time; wrong turns | finds both in under 60 s without help |

If A3 is off by more than 0.7 s, or A4 fails, fix `PlotLayout` before week 1 and re-run `tools/raidrace`.

## Stage B: the farming loop (after MVP week 1: 1 player, then 8)

**Question:** is the core loop (plant → wait → harvest → buy seeds → clear land) clear and satisfying, and does the server cope with 8 farms?

| # | Case | Steps | Measure | Pass |
|---|---|---|---|---|
| B1 | First minute | Fresh save (`/wipe`), new tester, no explanation | time to first plant; first harvest | plant < 60 s, harvest < 3 min |
| B2 | Farm Guide | Same tester, follow the Guide card to the end | time per step; where they stalled | Guide done in ≤ 15 min; no step stalls > 60 s |
| B3 | Growth timings | Plant a Carrot, a Corn and a Pumpkin; time to ripe (use `/grow` for long crops) | seconds | ±2 s of `Config/Crops` (60 / 300 / 900) |
| B4 | Watering | Water a half-grown Pumpkin | remaining time drops 10% | matches `GrowthRules.water` |
| B5 | Barley's restocks | Watch two restocks; buy out a Rare seed; rejoin | stock per player; rejoining doesn't refill | as `SeedStock` says |
| B6 | Land Permit | `/level 2`, follow the "Clear here" sign, clear a block (4 holds) | understood without help? fee 250 | clears in < 30 s; tester can say which blocks are riskier |
| B7 | Saving | Plant, harvest, leave, rejoin (API access on, test store) | everything still there; field progress kept | nothing lost |
| B8 | Offline growth | Plant a 2 h crop, `/away 2` | progress | 25% (`Growth.OFFLINE_RATE`) |
| B9 | 8 players | Clients and Servers × 8, all farming | server heartbeat (Ctrl+F6 MicroProfiler / Stats), client FPS, Network → data in/out | server ≥ 55 Hz, clients ≥ 50 FPS, < 50 KB/s per client |

## Stage C: selling, workers, coming back (after weeks 2–3)

**Question:** do players understand and enjoy the truck vs shop choice, and do workers feel worth it?

| # | Case | Steps | Measure | Pass |
|---|---|---|---|---|
| C1 | Truck | Pack 2 crates, load, dispatch | understood the locked price? | tester explains "the price locks when it leaves" |
| C2 | Truck vs shop | Tester with 40 Pumpkins; market shows ▼; ask "where would you sell?" | their choice and reason | ≥ 2 of 3 testers pick the shop *because* the market is low |
| C3 | Shop pricing | Set a price, watch shoppers for 3 min | sales/min vs the window's estimate | within ±30% of `DemandModel` |
| C4 | Bottleneck | T1 warehouse, 1 Packer, lots of Sorters | do they spot the orange station and fix it? | yes, within 2 min |
| C5 | Workers offline | Hire a full T1 crew, `/away 8` | Welcome back numbers vs `PipelineRules.settle` with the same state | within ±5% (it's the same code: a big gap is a service bug) |
| C6 | Economy pace | Two testers play 45 min from fresh | level and coins at 15 / 30 / 45 min | within ±30% of `tools/progression` (daily profile, first day) |
| C7 | Wages strike | Run coins to 0 with workers | strike shows and is understood | tester says why they stopped |

## Stage D: raids, the big one (after weeks 4–5)

**Question:** are raids fun and fair from both sides, and is every way of dodging an arrest really closed?

**D-timing** (2 clients, lag 0, then 0.2 s): run the raid race for real, 5 runs each, owner starting at the warehouse and in town:

| Case | Expected (`tools/raidrace`) | Pass |
|---|---|---|
| Thief, no defences vs owner at the warehouse | thief safe at ~5.8 s; owner in reach ~7.7 s → thief escapes | escapes ≥ 4 of 5 |
| Thief vs cloche + dog + tall fence, owner at the warehouse | caught | caught ≥ 4 of 5 |
| Same, owner in town (Home) | caught with ~1 s to spare | caught ≥ 3 of 5 at 0.2 s lag; if not, raise the tall fence climb or the dog's slow |

**D-dodges** (2–3 clients): every row of the §4.12 table is a case; all must end the way the doc says.

| # | Try to | Expected |
|---|---|---|
| D1 | Close the thief's window while knocked out as a Suspect | owner paid at once; the thief rejoins on the police porch with "You fled arrest"; fine ×1.5 (`/crimelog`) |
| D2 | Close the window with loot while the owner is within 30 studs | "Chased": fine ×1.5, loot back |
| D3 | Close the window with loot, owner far away | loot back, no fine |
| D4 | Esc → Reset while a Suspect / knocked out / carrying | reset is greyed out |
| D5 | Home / Town / Visit while a Suspect / carrying | blocked; a channel already started stops if you start a steal |
| D6 | Teleport yourself (client command bar: move your character 100 studs) | sent back; the steal or deposit fails |
| D7 | Bonk an innocent visitor again and again | 5 s down, then 6 s immune; the Leave farm button works; no arrest prompt |
| D8 | Stop the server (Studio Stop) while someone is knocked out | nobody fined |
| D9 | Thief with 0 coins gets arrested | owner gets 0 now; debt shows; the thief's next sales pay half to the owner |
| D10 | Two friends stage arrests with 20-coin loot | Sheriff board and XP don't count them |
| D11 | Steal past the raid cap (10 weight in 10 min) | blocked, and the Neighbourhood Watch dome shows |
| D12 | Climb in, then out, as an innocent visitor | climbing *out* never makes you a Suspect |

**D-fun** (4–6 friends, 30 min of free play, swapping roles): after each raid, both sides answer three questions on a 1–5 scale. "That felt **fair**." "That was **fun**." "I **knew what to do**." Also count raids and arrests.

| Measure | Pass |
|---|---|
| Fair, fun, clear: average for each role | ≥ 4.0 (any 1s: talk to that tester) |
| Arrest rate | 30–55% (design target 35–50%) |
| A thief can say what made them a Suspect | ≥ 4 of 5 testers |
| Bonked innocents who felt picked on | 0 who'd quit over it |

## Stage E: auction, weather, trading, scale (after weeks 6–7)

| # | Case | Pass |
|---|---|---|
| E1 | Auction with 4+ bidders: last-second bids | anti-snipe feels fair (ask); escrow always comes back when outbid |
| E2 | Leader leaves mid-lot | the next bidder who can pay leads; nobody charged twice |
| E3 | Thunderstorm with ripe crops: do players leave them out (🚩) and risk a raid? | ≥ half try it at least once; the aura is visible to thieves |
| E4 | Trading: lopsided offer | the red warning shows; staff `/rollback` undoes a test trade |
| E5 | **50-player test** (private server, friends and their friends) for 30 min: trade, raid, auction | no duplicated or lost items (compare `TradeLog_v1` and saves); no DataStore throttling warnings in Output; server ≥ 50 Hz |

## Stage F: new players and phones (before launch)

**Question:** can a 9–16-year-old who has never seen the game pick it up alone, on a phone?

- **Who:** 5–8 testers in the age range who haven't played. **Under-13s only with a parent present and their permission**; record only the screen, never faces or voices, unless the parent agrees. No personal details in the log, just first names or "Tester 3".
- **How:** a private server, a phone (landscape), think out loud, 20 minutes, no help unless they're stuck for 60 s.

| Measure | Pass |
|---|---|
| Finish the Farm Guide | ≥ 80% |
| First sale | < 6 min |
| Can say what the bat does and when they can be arrested | ≥ 80% |
| Tap targets missed / HUD under the thumb | none blocking (context button, side bar, hotbar) |
| "Would you play again tomorrow?" | ≥ 70% yes |

Before launch, also check Creator Analytics is receiving the onboarding funnel (`Util/Analytics` steps), economy events and the raid events (`StealStarted` … `HitRejected`) from a private test server.

## Gates: when to move on

| From | To | Gate |
|---|---|---|
| A | week 1 | A3 and A4 pass |
| B | week 2 | B1, B2, B7, B9 pass |
| C | week 4 | C2 and C6 pass (or the sim is retuned to match) |
| D | week 6 | every D-dodge case passes; D-fun averages ≥ 4.0; arrest rate 30–55% |
| E | launch prep | E5 passes |
| F | launch | all Stage F bars met |
