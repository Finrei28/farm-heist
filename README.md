# Farm Heist

A farming game for Roblox. Grow crops on your own plot (which gets bigger as you level up), pack them in your warehouse and truck them out at the global market price or sell them in your own shop at yours, hire workers, bid at the auction, trade, and defend your ripe crops with a bat. Bonk a thief, arrest them, get paid.

- Design doc: [docs/GameDesign.md](docs/GameDesign.md). §10 is the review log, §11 the build steps.
- Play-test plan: [docs/PlaytestPlan.md](docs/PlaytestPlan.md), with results in [docs/PlaytestLog.md](docs/PlaytestLog.md) and screenshots in `docs/playtest/<date>/`
- Art direction (how the world should look): [docs/ArtDirection.md](docs/ArtDirection.md)
- Design map (system diagram, game flow, world map, UI mockups): [docs/DesignMap.html](docs/DesignMap.html), open it in a browser. Its source is `docs/DesignMap.source.html`, published at https://claude.ai/artifact/5zbB8YiWAd4i67Rs4g2eU2 (private). After editing the source, run `lune run tools/designmap` to rebuild the browser copy.

## Status

Week 1 of the MVP plan (design doc §9) is in: you get a farm, plant, water and harvest, buy seeds from Barley, level up, clear land with Land Permits, and travel Home and to Town, all in Farm Heist's own "Kraft & Crate" interface. The world has its first look pass (light, the field, crops). Selling (the warehouse, the truck, the Farm Stand) is week 2. The rules are tested (203 tests), the XP curve is tuned with a progression sim, and Cloverdale is built from one layout file. Play-test Stage A passed in Studio on 2026-10-30; Stage B (the farming loop, with a real tester) is next.

## One-time setup (Windows)

The same as Tide Market:

1. **Roblox Studio**: install it from https://create.roblox.com.
2. **Rojo CLI**: with [Rokit](https://github.com/rojo-rbx/rokit) installed, in this folder run:
   ```
   rokit install
   rojo plugin install
   ```

## Running the game

1. In Studio, create a new **Baseplate** place and save it in this folder (e.g. `FarmHeist.rbxl`; it's git-ignored).
2. In a terminal here: `rojo serve`
3. In Studio: **Plugins → Rojo → Connect**, then **Play**. Cloverdale is built when the server starts (it replaces the Baseplate), you get a farm, and you appear at its farmhouse door.

**Playing:** stand on a tile and press **E** or tap the round stamp at the bottom right: it plants the seed packet picked in the hotbar (1–9), waters, or harvests, whatever the tile needs. Hold it and walk to do a whole row. Shift runs. The **Barn** crate on the left shows your crops, seeds and land. **Barley** sells seeds at his counter in town (the **TOWN** signpost takes you there in 3 s). From Farm Level 2 you get Land Permits: walk to a yellow "Clear here" sign on your field.

**Dev commands** (Studio, typed in chat): `/coins 5000` · `/level 5` · `/xp 60` · `/grow 60` · `/grow ripe` · `/away 2` · `/restock` · `/restock full` · `/seeds Pumpkin 10` · `/seeds all 5` · `/tp town` · `/tp barley` · `/tp porch` · `/tp home` · `/tp 3` · `/wipe`. The full list is at the top of `src/server/Services/DevCommandService.luau`.

### Walking the greybox

Everything is placed by `src/shared/PlotLayout.luau`, so a change there moves the greybox, the zones and the tests together. To check the distances feel right with real movement:

1. Play, and walk from the town spawn to Farm 1's gate (about 15 s; the design doc says 205–265 studs).
2. Stand on a back-row tile of any field (the tiles furthest from the farmhouse), walk to the back fence: about 24 studs.
3. From the yellow Door pad in front of the farmhouse, sprint (Shift) to the back fence: the race assumes about 6–7 s.

If anything feels off, change PlotLayout and run `lune run tools/raidrace` to see what it does to the raid race. These checks are Stage A of [docs/PlaytestPlan.md](docs/PlaytestPlan.md), which has the full list and pass bars.

Saves use **ProfileStore** (session locking), at `src/server/Packages/ProfileStore.luau`. To test saving in Studio, publish the place, then Game Settings → Security → *Enable Studio Access to API Services*. Without it everything runs on a mock store.

After publishing, set the place's **server size to 8**: there are 8 farms, one per player.

## Tests

The shared game rules (`src/shared`) have tests that run on your PC with [Lune](https://github.com/lune-org/lune), no Studio needed (Rokit installs it):

```
lune run tests/run
```

| Test | What it checks |
|---|---|
| `growth` | growing online and offline (25%), fresh soil, watering, regrowing crops |
| `seedstock` | Barley's restocks: the same everywhere, Commons unlimited, level locks |
| `market` | the global price: waves, Hot Crop and Glut, supply, the 0.5–2× clamp |
| `demand` | how shoppers react to your prices and your rating |
| `land` | Land Permits: earned by level, touching blocks only, fees in order |
| `crime` | who may steal, Suspects, bat hits, knockouts, arrests, every way of dodging an arrest |
| `fine` | the fine formula, repeat offenders, fleeing, debt and its expiry |
| `travel` | the Home / Town / Visit buttons: channels, cooldowns, no escaping a raid |
| `zone` | inside a farm or not: the edge, turned plots, climbing |
| `auction` | bids, quick bids, anti-snipe, the leader leaving |
| `workers` | wages, speeds, fees, station caps |
| `pipeline` | the farm running while you're away, with nothing lost or made up |
| `progression` | the XP curve, harvest and sales XP, level-ups bringing Land Permits |
| `layout` | nothing in Cloverdale overlaps, the distances in the doc, the raid race outcome (with at least 1 s to spare) |
| `world` | builds the greybox for real with Lune's Roblox instances and checks it matches the layout; every crop at every stage; the field following a save's land |
| `barn`, `plot` | crop stacks and barn capacity; which farm a joining player gets |
| `movement` | the anti-teleport check |
| `config`, `savedata` | the tables agree with each other and with the design doc; saves are DataStore-safe |

**Before publishing**, run `lune run tools/check`: it compiles every script in `src/` and runs all the tests, then says "Ready to publish" or what to fix.

**Progression sim:** `lune run tools/progression` plays 35 days of the game for a casual (45 min a day), daily (1.5 h) and keen (3 h) player with the real rules, prints when each level, Land Permit and building comes, and checks the design doc's pacing targets. Run it after changing XP, crop values, prices or fees. `lune run tools/progression daily power=2.7` tries another XP curve.

**Raid race:** `lune run tools/raidrace` times the design doc's worked example (§4.11) from the real layout: how long a thief needs to get a back-row Pumpkin over the fence, with and without defences, against an owner coming from the warehouse or from town.

## Layout

```
src/shared/   Config/ (Crops, Rarities, Land, Barn, Crime, Market, Shop, Warehouse, Workers, Auction, Growth, Progression, Settings)
              Rules: GrowthRules · SeedStock · BarnRules · PlotRules · MarketPrice · DemandModel · LandRules · ProgressionRules
                     CrimeRules · FineRules · TravelRules · ZoneRules · AuctionRules · WorkerRules · PipelineRules · MoveRules · Remotes
              PlotLayout (where everything in the valley and in a farm is)
src/server/   Services/ Data · Movement · Plot · Field · SeedShop · Land · Travel · DevCommand
              World/ WorldBuilder · FarmArt (the field and crops) · Parts (palette) · LightingSetup
              Util/ SaveData · Analytics · ActionRemote · Notice · Staff     Packages/ ProfileStore
src/client/   UI (the Kraft & Crate kit) · PlayerState · Reasons
              Controllers/ Hud · Hotbar · Field · SeedRack · Barn · Prompt · Sprint
tests/        *.test.luau, lib/ (harness, spec, raidrace)
tools/        check.luau · progression.luau · raidrace.luau · designmap.luau
docs/         GameDesign.md · ArtDirection.md · PlaytestPlan.md · PlaytestLog.md (+ playtest/ screenshots)
              DesignMap.source.html → DesignMap.html
```

Balancing is mostly editing `src/shared/Config/*.luau`; the config tests flag numbers that break the design (for example a crop that pays less per minute than one of a lower rarity).
