# Farm Heist

A farming game for Roblox. Grow crops on your own plot (which gets bigger as you level up), pack them in your warehouse and truck them out at the global market price or sell them in your own shop at yours, hire workers, bid at the auction, trade, and defend your ripe crops with a bat. Bonk a thief, arrest them, get paid.

- Design doc: [docs/GameDesign.md](docs/GameDesign.md). §10 is the review log, §11 the build steps.
- Play-test plan: [docs/PlaytestPlan.md](docs/PlaytestPlan.md), with results in [docs/PlaytestLog.md](docs/PlaytestLog.md) and screenshots in `docs/playtest/<date>/`
- Art direction (how the world should look): [docs/ArtDirection.md](docs/ArtDirection.md)
- Design map (system diagram, game flow, world map, UI mockups): [docs/DesignMap.html](docs/DesignMap.html), open it in a browser. Its source is `docs/DesignMap.source.html`, published at https://claude.ai/artifact/5zbB8YiWAd4i67Rs4g2eU2 (private). After editing the source, run `lune run tools/designmap` to rebuild the browser copy.

## Status

Weeks 1–8 of the MVP plan (design doc §9) are built. Week 1, the farming loop: plant, water and harvest, Barley's seeds, Farm Levels, Land Permits, Home and Town, in Farm Heist's own "Kraft & Crate" interface. Week 2, selling: the Packing Shed, trucks to the City at the global market price, the Exchange. Week 3, your own store, laid out and decorated on a grid, with NPC shoppers in its aisles. Week 4, Warehouse Levels 1–20 and workers with Levels 1–10. Week 5, raids: stealing, the bat, knockouts, arrests, fines and debt (then stolen crops held up in your hands, a patch giving several crops, Field Levels, and the crops, farmhouse and barn drawn as meshes). Week 6, defences, the Sprout Shield, Trusted friends and the Watchman, with raids rebalanced and a bonked thief dropping the crop. Week 7 (built and played in Studio on 2026-11-03): day and night, the weather and mutations, the Harvest Moon, Floodlights, the Auction House with Goldie Gavel, daily quests, the login streak and the Cropdex; then the town's look (2026-11-04): the plaza and the clocktower in its fountain, the park, Barley's Seeds, the Hiring Hall and the Exchange's grain elevator. Week 8 (built and played in Studio with 2 players on 2026-11-04): the Farm Guide for new players, trading in person with a log support can undo, every server's truck sales moving the market price, leaderboards in town, and the valley's hills, tunnel, woods and back-trail cover. Every week was played in Studio as it landed (docs/PlaytestLog.md). 504 tests, no flicker, and the XP curve is tuned with a progression sim.

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
4. **The meshes** (once per place, two imports): **Home → Import 3D**, pick `art/crops/FarmHeistCrops.glb`, import with the default settings, rename the imported model **CropModels** and drag it into **ReplicatedStorage** (keep the MeshPart names); then the same with `art/props/FarmHeistProps.glb`, renamed **PropModels**. Save the place. Growing and ripe crops, what thieves carry and the produce on shelves and crates switch to the crops' meshes at the next server start, and wild land (its stump, rock, weeds, bramble and grass), tilled soil, the farmhouse's yard props, the defences (scarecrow, dog, cloche, camera, mud, the Watchman's bell and searchlight) the town's fountain, trees, flowerbeds, spire and silo caps, and the valley's hedges and tunnel arch to the props'; until then they're part-built. If a file's meshes change, delete its old model and import that file again.

**Playing:** stand on a tile and press **E** or tap the round stamp at the bottom right: it plants the seed packet picked in the hotbar (1–9), waters, or harvests, whatever the tile needs. Hold it and walk to do a whole row. Shift runs. The **Barn** crate on the left shows your crops, seeds and land. **Barley** sells seeds at his counter in town (the **TOWN** signpost takes you there in 3 s). From Farm Level 2 you get Land Permits: walk to a yellow "Clear here" sign on your field.

**Selling:** at the **Packing Shed** bench (by the driveway) pick a crop and 🚚 Truck or 🏪 Stand, each showing what it pays now, then hold the stamp and let go in the green for grade A (+15%). A truck crate goes into your arms: carry it to the dock and press E to load it, then pull the lever (or **Send now** in the Market window) to send the pickup. Prices lock as it leaves and you're paid when it reaches the City. A stand crate goes to the stockroom: hold E behind your **Farm Stand**'s counter to stock its two baskets, and set prices in the **Stand** crate's window. Shoppers come along the sidewalk while you're in the server.

**Dev commands** (Studio, typed in chat): `/coins 5000` · `/level 5` · `/xp 60` · `/grow 60` · `/grow ripe` · `/away 2` · `/restock` · `/restock full` · `/seeds Pumpkin 10` · `/seeds all 5` · `/crops Pumpkin 40` · `/truck` · `/shoppers 5` · `/store 5` · `/tp town` · `/tp barley` · `/tp exchange` · `/tp porch` · `/tp home` · `/tp shed` · `/tp store` · `/tp 3` · `/wipe`. The full list is at the top of `src/server/Services/DevCommandService.luau`.

### Walking the greybox

Everything is placed by `src/shared/PlotLayout.luau`, so a change there moves the greybox, the zones and the tests together. To check the distances feel right with real movement:

1. Play, and walk from the town spawn to Farm 1's gate (about 20 s; the design doc says 285–345 studs).
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
| `growth` | growing online and offline (25%), fresh soil, watering, regrowing crops, how many a patch gives (and a thief takes) |
| `seedstock` | Barley's restocks: the same everywhere, Commons unlimited, level locks |
| `market` | the global price: waves, Hot Crop and Glut, supply, the 0.5–2× clamp |
| `demand` | how shoppers react to your prices and your rating |
| `land` | Land Permits: earned by level, touching blocks only, fees in order; Field Levels |
| `crime` | who may steal (or grab a dropped crop), Suspects, bat hits, knockouts, arrests, every way of dodging an arrest |
| `fine` | the fine formula, repeat offenders, fleeing, debt and its expiry |
| `travel` | the Home / Town / Visit buttons: channels, no cooldowns, no escaping a raid |
| `loot`, `produce` | a stolen crop in your hands (one at a time, where it goes back to, who takes back or grabs a dropped one, only one person getting it); every crop's carried model the size it says; trucks solid |
| `meshes` | the meshes: every piece a layout names was drawn, every crop growing, ripe with any number on it, carried and on a shelf, every obstacle of wild land, built from the meshes once imported (part-built until then), never more shelf pieces than the balls they replace, nothing to bump into |
| `flicker` | no two faces fighting over one plane anywhere the server builds, at every level, every defence set out (`lune run tools/flicker` lists them) |
| `defences`, `defenceart` | buying and setting out defences, what each does, the yard spots round the field, the gate (locked, shut by the Watchman, walking out), the Trusted list, the Sprout Shield, the raid cap's dome; every defence drawn on its spot (meshes or stand-ins), the gate swinging, the gatehouse, the domes |
| `zone` | inside a farm or not: the edge, turned plots, climbing |
| `auction` | bids, quick bids, anti-snipe, the leader leaving; seeds, rare workers and defences as lots, what you can win (a defence's level, room for one more, a free slot for a rare worker) |
| `weather` | the 24-minute day, the weather's shares and where it falls, the Harvest Moon (and Heist Night), mutation odds and values, `/weather` and `/time` |
| `quests` | three quests a day for your level, claiming, the bonus, the 7-day streak, the Cropdex and what finding a rarity or a mutation set pays |
| `workers` | wages, speeds, fees, station caps |
| `pipeline` | the farm running while you're away, with nothing lost or made up |
| `progression` | the XP curve, harvest and sales XP, level-ups bringing Land Permits |
| `layout` | nothing in Cloverdale overlaps, the distances in the doc, the raid race's balance (a sharp farmer catches a fully defended raid by about a second, a slow one in town loses it), the truck's road and the shoppers' sidewalk keeping out of every farm |
| `world` | builds the greybox for real with Lune's Roblox instances and checks it matches the layout; the front boundary walled except the gate; the shed, dock, pickup and Farm Stand where the services look; every crop at every stage; the field following a save's land |
| `barn`, `plot` | crop stacks and barn capacity; which farm a joining player gets |
| `crate`, `truck`, `shop` | packing and washing to grade A (a mutated crop's crate at its multiple, by truck only); loading, the price locking at dispatch, paying once on arrival (even after you've left); the Farm Stand's shelves, prices, shoppers buying as often as `demand` says, the rating |
| `movement` | the anti-teleport check |
| `config`, `savedata` | the tables agree with each other and with the design doc; saves are DataStore-safe |

**Before publishing**, run `lune run tools/check`: it compiles every script in `src/` and runs all the tests, then says "Ready to publish" or what to fix.

**Progression sim:** `lune run tools/progression` plays 35 days of the game for a casual (45 min a day), daily (1.5 h) and keen (3 h) player with the real rules, prints when each level, Land Permit and building comes, and checks the design doc's pacing targets. Run it after changing XP, crop values, prices or fees. `lune run tools/progression daily power=2.7` tries another XP curve.

**Flicker:** `lune run tools/flicker` lists every pair of faces that would flicker (z-fight) in everything the server builds; `tests/flicker.test.luau` keeps it at none.

**Crop and prop art:** `python tools/crop_art/generate.py` draws every crop and prop as low-poly meshes (Python, numpy and Pillow): `art/crops/FarmHeistCrops.glb` and `art/props/FarmHeistProps.glb` to import (step 4 above), `src/server/World/CropMeshData.luau` (where each piece goes in a patch, in a thief's hands and on a shelf) and `PropMeshData.luau` (an overgrown block's obstacles and grass), previews of every crop's patch in `art/crops/previews/` (not in git: run it to see them) (growing, ripe, a bumper patch, close up, from the farmhouse, from above, a figure for scale), the carried loads (`previews/carried.png`), the shelf pieces (`previews/shelf.png`), the props and an overgrown block (`art/props/previews/`) and every mesh (`contact_sheet.png` in each folder). It stops if a patch spills off its tile, a load is bigger than it says or wild land leaves its block. `python tools/crop_art/generate.py Carrot Wheat` redraws just those previews; `--carried`, `--shelf` and `--props` just those sheets. **Buildings** are parts (they change with levels and farm colours); to look at one before Studio, `lune run tools/partdump farm.json [fieldLevel] [blocksOpen] [plot] [defences|dome|auction|town|valley]` dumps a farm (with every defence set out), the Auction House, the whole town or the valley round three farms, and `python tools/crop_art/partview.py farm.json out.png [gate door field above porch road gateroad backyard kennel … | spawn plaza townabove seeds hiring exchange … | tunnel woods trail crossing hedge …]` renders it with the meshes.

**Raid race:** `lune run tools/raidrace` times the design doc's worked example (§4.11) from the real layout: a thief's whole raid on a back-row Pumpkin (in, steal, out over the fence) as each defence is added, against an owner at the farmhouse door, the warehouse or in town, reacting quickly or slowly, as seconds ahead (escapes) or behind (caught).

## Layout

```
src/shared/   Config/ (Crops, Rarities, Land, Barn, Crime, Market, Shop, Warehouse, Workers, Auction, Growth, Progression, Settings)
              Rules: GrowthRules · SeedStock · BarnRules · PlotRules · MarketPrice · DemandModel · LandRules · ProgressionRules
                     CrateRules · TruckRules · ShopRules · CrimeRules · FineRules · TravelRules · ZoneRules · AuctionRules
                     WorkerRules · PipelineRules · MoveRules · Remotes
              PlotLayout (where everything in the valley and in a farm is)
src/server/   Services/ Data · Movement · Plot · Field · SeedShop · Land · Travel · Market · Warehouse · Truck · Shop · DevCommand
              World/ WorldBuilder · FarmArt (the field and crops) · FarmhouseArt (the farmhouse and barn) · Meshes (+ CropMeshData, PropMeshData, generated) · ProduceArt · YardArt (shed, dock, pickup, Farm Stand) · Parts (palette) · LightingSetup
              Util/ SaveData · Analytics · ActionRemote · Notice · Staff     Packages/ ProfileStore
src/client/   UI (the Kraft & Crate kit) · PlayerState · Reasons
              Controllers/ Hud · Hotbar · Field · SeedRack · Barn · Shed · Market · Shop · Truck · Shopper · Prompt · Sprint
tests/        *.test.luau, lib/ (harness, spec, raidrace)
tools/        check.luau · progression.luau · raidrace.luau · designmap.luau · partdump.luau · crop_art/ (Python: the meshes, partview)
art/crops/    FarmHeistCrops.glb (import in Studio) · previews/ · contact_sheet.png
art/props/    FarmHeistProps.glb (import in Studio) · previews/ · contact_sheet.png
docs/         GameDesign.md · ArtDirection.md · PlaytestPlan.md · PlaytestLog.md (+ playtest/ screenshots)
              DesignMap.source.html → DesignMap.html
```

Balancing is mostly editing `src/shared/Config/*.luau`; the config tests flag numbers that break the design (for example a crop that pays less per minute than one of a lower rarity).
