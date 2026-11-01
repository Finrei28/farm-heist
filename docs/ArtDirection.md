# Farm Heist: Art direction (the world)

How Cloverdale should look in 3D. The UI's look ("Kraft & Crate") is in [GameDesign.md §5.1](GameDesign.md); the world uses the same colours, so the HUD and the world feel like one thing. Written after the first Studio play-test (2026-10-30). The screenshots it refers to are in [playtest/2026-10-30/](playtest/2026-10-30/).

## 1. What the greybox looks like now

The greybox does its job: the distances and the raid race hold up (PlaytestLog, 2026-10-30). As a picture, though, it shows what the art has to fix:

| # | Seen | Why it matters | Fix (section) |
|---|---|---|---|
| 1 | The Baseplate template's lighting: flat noon light, plus Bloom and **Depth of Field** ([05](playtest/2026-10-30/05-door-to-back-row.jpg)) | Looks like every new Roblox place. Depth of Field blurs the far end of the field, where thieves stand | §4 |
| 2 | A photo-like Grass texture under flat plastic boxes ([03](playtest/2026-10-30/03-farm-from-above.jpg), [07](playtest/2026-10-30/07-field-close.jpg)) | Two styles fighting | §2, §3. Done in week 1: all SmoothPlastic in this palette, a striped lawn |
| 3 | The hills are a ring of 40-stud walls ([01](playtest/2026-10-30/01-valley-from-above.jpg)) | Reads as a stadium wall, not a valley | §5 |
| 4 | The town square is a 320-stud flat disc with five small boxes; you arrive facing the Police Station ([02](playtest/2026-10-30/02-town-spawn.jpg), [12](playtest/2026-10-30/12-phone-town.jpg)) | Nothing says "town", and the first thing you see is the jail | §6 |
| 5 | Bare grass wedges between the farms, big empty yards ([01](playtest/2026-10-30/01-valley-from-above.jpg)) | Empty, and nothing to hide behind on the back trail | §5, §7 |
| 6 | The field is a flat checkerboard; on a phone, from the farmhouse door, it's a thin brown strip ([11](playtest/2026-10-30/11-phone-farm.jpg)) | The field is the heart of the game and it's the hardest thing to see | §7 |
| 7 | Fences are 5-stud brown slabs, with an invisible wall up to 11 studs ([08](playtest/2026-10-30/08-back-fence.jpg)) | You see a fence you could jump, and bump into nothing. Feels like a bug | §7. Done in the greybox: 8-stud fences of posts and rails you can see through ([13](playtest/2026-10-30/13-back-trail-rail-fence.jpg)) |
| 8 | A thief on the back row is about 10 pixels tall from the farmhouse door and the warehouse, 135–160 studs away ([05](playtest/2026-10-30/05-door-to-back-row.jpg), [06](playtest/2026-10-30/06-warehouse-to-back-row.jpg)) | Visible, but easy to miss on a phone | §7, §9 |
| 9 | All 8 farms look the same ([01](playtest/2026-10-30/01-valley-from-above.jpg)) | Hard to find your own farm, or say whose farm you're in | §7 |
| 10 | Every farm's labels stacked into one blob through the walls ([09](playtest/2026-10-30/09-back-trail-old-labels.jpg)) | Clutter | Fixed during the play-test: labels are sized in studs and hidden past 45–260 studs ([10](playtest/2026-10-30/10-back-trail-new-labels.jpg)) |

## 2. The look in one line

**A toy farm on a sunny day.** Chunky, rounded, low-poly shapes; warm, saturated colours; soft light with soft shadows; painted wooden signs. It's bright and friendly for kids. Stealing and bonking are cartoon slapstick: bonk stars, a cartoon jail with a striped wall, never anything gritty.

**Rules, most important first:**
1. **Gameplay reads first.** In order: ripe crops, thieves, your own farm, the ways in. Everything else is background.
2. **Big simple shapes** that read on a 6-inch phone at 50+ studs. Detail only where you stand close (shop counters, the barn door, signs).
3. **One material language:** SmoothPlastic and a few soft MaterialVariants (§3). No photo textures.
4. **Colour means something.** Rarity colours only on crops, seeds and their glows. The alarm red only on danger (thieves, alarms). Buildings use the matte palette.
5. **Phones first** (§10).

## 3. Palette and materials

The UI tokens (§5.1 of the design doc), plus the world's own colours:

| Surface | Colour | Material |
|---|---|---|
| Meadow (valley, hills) | `#8CC36A` | `Meadow` variant: Grass, low-contrast, large studs-per-tile |
| Lawn (inside farms) | `#7DBE5A`, mown stripes `#86C763` | SmoothPlastic |
| Path, back trail | `#D8B47A` | `Dirt` variant: Ground, soft |
| Road | `#8E8A84`, a dashed line in Cream | SmoothPlastic |
| Tilled soil | `#7A5235`, watered `#5A3A24` | `Soil` variant: Ground, with furrows |
| Overgrown land | `#6C9A44` tall grass tufts | meshes |
| Hedge | `#3F8A3A`, flowers in Hay Gold and Cream | SmoothPlastic, rounded |
| Fence paint | Cream `#FFF4DC`, posts Soil Brown `#6B4A2F` | SmoothPlastic / `Wood` variant |
| Barns, farmhouse roofs | Barn Red `#C8452D` | SmoothPlastic |
| Walls | Cream, Kraft `#D9B98A` | SmoothPlastic |
| Metal (warehouse, trucks) | `#9AA7B4` | SmoothPlastic, a little reflectance |
| Water | `#5BB6F0` | glass-like, simple |
| Inside the stores | Never near-white and never cool: the Corner Store `#E4CEA8`, the Farm Shop and Market Hall plaster `#E6D4B6`, the Supermarket khaki-sage `#BEBEA6` on a warm grey checker; floors no lighter than `#D2BE9A` | SmoothPlastic. A white wall glares under the lamps, and with the roof faded the room is lit by the open sky, which turns greys blue |
| Farm colours (§7) | 8 bright colours: Tomato `#E8533F`, Tangerine `#F2913D`, Sunflower `#F5C842`, Clover `#5CBF4A`, Teal `#2FB5A8`, Sky `#4C9BE8`, Grape `#8B6CD9`, Rose `#E86AA8` | flags and trim |

## 4. Light and sky

Set in code (`World/LightingSetup`, run by WorldBuilder) so every server looks the same and it's in git. `Lighting.Technology` isn't a choice any more: Studio no longer lists it in Properties, and scripts can't read or set it, so Roblox picks the lighting engine. Starting values to tune by eye:

| Setting | Value | Why |
|---|---|---|
| `ClockTime` | driven by the 24-minute day (§4.14) | |
| `Brightness` / `ExposureCompensation` | 2.4 / 0.1 | Bright |
| `Ambient` / `OutdoorAmbient` | `#5A5650` / `#A09A90` | Light shadows: nothing important hides in the dark |
| `ColorShift_Top` | `#FFF0D6` | Warm sun |
| `ShadowSoftness` | 0.35 | Toy-like |
| `Atmosphere` | Density 0.28, Offset 0.1, Color `#C8E1F0`, Decay `#7896AA`, Haze 1.2, Glare 0.15 | The hills fade into haze, which gives depth |
| `ColorCorrection` | Saturation +0.12, Contrast +0.06 | Punchy colours |
| `Bloom` | Intensity 0.35, Size 24, Threshold 1.6 | Only glowing things bloom (ripe sparkles, mutations, lamps) |
| `DepthOfField` | **none** | It blurs the back row, where thieves are |
| `SunRays` | Intensity 0.05 | |

- **Indoors with the roof faded** (`RoofController`): the light is never changed (it would change the whole screen, the farm outside included, where thieves must stay easy to see). Instead a stand-in for the roof, a glowing white slab, goes 800 studs along the line to the sun, so it casts the roof's shadow on the room and is lost in the sun's glare; it follows the sun and goes at night. The room is then lit like shade outdoors, which is why inside colours are warm. Store lamps are 0.45 bright, at most 6 lights a store.
- **Night** (8 of every 24 minutes): blue moonlight that's bright enough to play on a phone (OutdoorAmbient stays at least `#6A7090`). Lamps along the roads and trail, farmhouse windows lit. Name tags shrink to 20 studs (§4.14); Floodlights light your field.
- **Weather** (§4.14): rain darkens the soil and adds puddles; the Harvest Moon turns the sky violet with a huge orange moon; Golden Hour is a low orange sun.

## 5. The valley

- **Hills:** real Terrain, rolling and grassy, built in code from `PlotLayout` (a ring of overlapping `FillBall` mounds, higher in the north). Tree clumps on the slopes. A rock cliff in the north with the **tunnel mouth**: a stone arch, lamps and a "To the City" road sign.
- **Woods in the gaps between farms** (§3 of the design doc): clumps of 3–5 low-poly trees with bushes. They stay at least 10 studs from the hedges, because the walk to the back trail goes through the gaps (PlaytestLog A6).
- **Back trail:** a dirt path with hay bales and bushes every 40–60 studs (cover for sneaking up, §3), and lamp posts for the night.
- **Ring road:** a dashed centre line, kerbs and a sidewalk for the NPC shoppers, a crossing at each farm path.

## 6. The town

The distances stay (they're timed), but the square stops being an empty disc:
- **The plaza** (radius about 60): clover-shaped paving, the **clocktower** in the middle (the landmark you can see from every farm, so you can always find town), the fountain, and benches and picnic tables (the Trade Plaza).
- **The park ring** (60–160): lawns, trees, flowerbeds and lamp posts, and 8 paths to the farms, each with a **signpost** showing the farm's number, owner name and colour.
- **The green** (160 to the ring road at 292, since the valley grew on 2026-10-31): the 8 paths carry on across it to the gates, with trees in clumps, a bench or two and a bus-stop shelter by the road, so the 130 studs between town and farms read as countryside, not an empty lawn. Nothing taller than a tree: the farms' fronts and the Supermarkets' billboards should show from the square.
- **The buildings** get façades with big painted signs and an awning in each building's own colour: Barley's Seeds (green, a wall of seed packets), the Auction House (a red barn hall with a bell tower), the Police Station (blue with a gold star, the jail porch with a bench and a striped wall), the Exchange (a tall grain elevator, the tallest building, with a flip-board of prices), and the Hiring Hall (yellow, a job board on the porch).
- **The town spawn** faces the clocktower and the Exchange (north), not the Police Station.

## 7. A farm

Front to back:
- **Gate arch:** a wooden arch with the owner's name on a plank and a flag in their **farm colour** (one of the 8 in §3, given out with the plot), plus a mailbox. When empty it says "For rent". The farm colour is also on the roof trim, the warehouse doors and the signpost in town, so you can spot your farm from the air and from the road.
- **Fences:** **8 studs tall** (`PlotLayout.FENCE_HEIGHT`, was 5), so a jump (about 7.2 studs) hits the fence you see, not thin air. The invisible wall up to 11 studs stays, and it's what really stops you: in the play-test a character climbed 3 horizontal rails like a ladder once the wall was taken away. So a fence's look is free, but it must never be the only thing in the way.
  - Front: a white picket fence (vertical pickets).
  - Back: vertical slats with gaps, so thieves can see the crops from the trail and owners can see out. It has the "Climb" prompt. (The greybox uses posts and rails for now.)
  - Tall Back Fence (the defence): 11 studs, close-boarded.
- **Hedges:** 12 studs, rounded tops, a few flowers.
- **Yard:** mown lawn with light stripes; a dirt path to the field. Anything between the farmhouse or warehouse and the field stays under 3 studs tall, so the owner can see the whole field (play-test A5).
- **The field:**
  - Each 2×2 block (24 studs) gets a low wooden edging, so the blocks read as blocks. The soil has furrows.
  - **Locked blocks:** tall wild grass, plus a rock, stump, log and bramble (the 4 obstacles you clear, §4.1b). A "Land Permit" sign stands on the next block you can open.
  - **Crops:** chunky low-poly meshes with **4 stages**: seed mound, sprout, growing, ripe.
  - **Ripe crops** stand 3–8 studs tall by rarity (Mythics tallest), bounce gently and sparkle, and have a soft glow ring on the soil in their rarity colour. Up close (40 studs) a billboard shows the rarity badge shape. A ripe field has to read from the farmhouse door on a phone.
- **Buildings** grow with their tier (Packing Shed → Warehouse; Farm Stand → Supermarket), all in the farm colour trim.

## 8. Characters

- **Workers:** blocky NPCs in a uniform for their job (`client/WorkerLooks`): Farmhand green overalls and a straw hat, Shed Hand a kraft apron and red cap, Sorter blue apron and cap, Packer brown apron, Loader orange vest with a reflective band and a hard hat, Driver a cap, Stocker a green polo and cap, Cashier a red apron, Greeter a gold sash with a rosette, Watchman a yellow raincoat and a torch (week 6). A small name-and-level tag. Hands busy at their station; on strike, sitting on a crate holding an "ON STRIKE" sign.
- **Shoppers:** varied colours, carrying baskets that fill up.
- **Town characters:** Barley (a straw hat), Patty (a clipboard) and Sheriff Clucks (a rooster in a cowboy hat with a star).

## 9. Effects and markers

- **Thieves, as the owner sees them:** a Suspect gets the red **!** (§4.12), drawn at a fixed pixel size and always on top inside your farm, so it shows at 180 studs (the warehouse to the back row), plus a red outline (`Highlight`) while the theft alarm is on. The **Loot Sack** is bigger than a head, with the crop's top sticking out.
- **Steal:** a progress ring over the crop, the crop shakes and rustles.
- **Bonk:** a star burst and a "BONK!" pop; the knocked-out player has birds circling their head.
- **Arrest:** a cartoon puff with handcuffs, then the mugshot card (UI).
- **Theft alarm:** a red light spins on the farmhouse and the gate flag flashes.
- **Ripe crop:** sparkles. **Mutations:** an aura in the mutation's colour (thieves see it too, §4.14).

## 10. Phones and performance

- **Camera:** default Roblox follow camera, FOV 70. Inside a store (and the warehouses from week 4) the roof fades on your screen so the camera can look down into the room (§4). Signs in the world have letters at least 3 studs tall (readable at 30 studs on a phone).
- **Budget:** under 4,000 parts for a fully built farm (raised from 3,000 on 2026-10-31 for the bigger stores: a Supermarket with all 100 floor items, its displays full, is about 2,600 of it), under 20,000 for the town and valley. Props are MeshParts with `CollisionFidelity = Box`, and textures are 512 px or smaller.
- **Streaming:** `StreamingEnabled`, with each farm as one atomic Model, so a far farm streams in whole, and a target radius of about 600 studs (the valley is 1,260 across), so a phone holds your farm, its neighbours and the town, not all eight. Shoppers are drawn only within 300 studs of the camera (`ShopperController`).
- **Check every look change from the same viewpoints** as this play-test (valley from above, town spawn, farm gate, farmhouse door to the back row, warehouse to the back row, the back trail, and the phone view) and compare them side by side.

## 11. Build order: the look pass

Each step has a week (design doc §9) and is checked in Studio from the viewpoints above, against this doc, **and by eye**: does it look right and make sense next to a character, close up and from across the farm, on a phone? Believable proportions, parts that meet (nothing floating, clipping or flickering), a shape that reads as what it is, this doc's colours. What looks off gets fixed before the step counts as done.

1. ✅ **Light and sky** (§4): `World/LightingSetup` (week 1).
2. ✅ **Fences, hedges and the gate arch** (week 3, with the store: the farm's front): pickets instead of the greybox's rails, rounded hedges, the arch with the name plate (§7). The back fence's slats came with its climb in week 5: wooden slats with gaps (thieves see the crops from the trail), rails and posts on the farm's side, a hand-painted "PRIVATE FARM · No climbing!" sign on the trail side; checked from the trail on 2026-11-02 ([playtest/2026-11-02-week5/05](playtest/2026-11-02-week5/05-back-fence-from-trail.jpg)). Built 2026-10-31 (`Parts.picketFence`: pointed cream pickets on two rails with posts; hedges with a rounded top and a few flowers; the arch with a name plank on chains, a flag in the farm colour and a mailbox). Checked in Studio on 2026-10-31.
3. ✅ **The field** (week 1, `World/FarmArt`): rounded soil rows, block edging, overgrowth with a stump, rock, weeds and bush on each locked block, crops at 4 stages (Carrot, Corn and Pumpkin modelled; the rest a bush with fruit in their colour), ripe glow rings and sparkles. The other crops' own models come later from a crop-art tool (design doc §11 step 7).
4. **The valley** (week 8, before the 50-player test): Terrain hills, woods in the gaps, back-trail cover, the tunnel mouth (§5).
5. ✅ **Farm colours** and name plates (week 3, §7), including the pickup and the store's awning in the farm colour. Built 2026-10-31 (`Parts.FARM_COLORS` by plot number: the gate flag, the plank's edge, the mailbox, the pickup, the store's awnings, sign frames and window boxes). Checked in Studio on 2026-10-31.
6. **The town** (week 7, with the Auction House; the Police Station's front in week 5 with arrests): plaza, clocktower, signposts, building façades (§6). The Police Station's front ✅ built in week 5 (`World/PoliceArt`): blue walls with cream trim, a gold sheriff's star over the POLICE sign, barred cells upstairs, a porch with a blue-and-cream striped awning (and a striped flap along its front, since from the square a porch roof is seen edge-on), the height chart right behind the spot where the arrested land, Sheriff Clucks (a white rooster, a red comb through his cowboy hat, a gold star) behind the police desk, a WANTED poster saying how arrests work, a bench, blue lamps by the door. Checked in Studio on 2026-11-02 from the square at eye height, from above and close up ([playtest/2026-11-02-week5/](playtest/2026-11-02-week5/)). The other façades stay in week 7.
7. ✅ **Markers** (week 5, with stealing): the Suspect **!** and outline, the sack (§9), and the back fence's slats with the climb. Built 2026-11-01 (`client/Controllers/CrimeController`, `World/CrimeArt`): the red ! in a cream ring with the name under it, a fixed size and always on top for the owner; a red "🧺 name" over anyone carrying; a ring of 20 dots over a crop being stolen, filling red (always on top and pulsing for its owner) while the crop shakes; the burlap sack snug on the back, bigger than a head, the last crop's top poking out; gold dizzy stars circling a knocked-out head, the character flat on their back; BONK! with a burst of gold stars, a white puff and BUSTED! at an arrest; the bat (a taped grip and knob, a wooden barrel with a band). Checked in Studio with 2 players on 2026-11-02; fixed there: the sack (it sat beside the character like a giant egg), the bat's length. Not done: the red outline (`Highlight` didn't draw on clients in Studio), the farmhouse's spinning alarm light and flashing gate flag (with the rest of the alarm, week 6).
8. **Selling, tier 0** (week 2, `World/YardArt`): the Packing Shed (open shed, barn-red gable roof, painted sign, the bench with a wash tub and tape), a low dock with the dispatch lever, the pickup (barn red, cream roof and tailgate, crates in the bed), a striped boom gate across the driveway, the Farm Stand (a counter in the front fence, striped awning, two wicker baskets with price tags, an honour box), the Exchange's split-flap price board, a paved sidewalk round the ring road, and blocky shoppers in varied colours. Checked in Studio on 2026-10-31 ([playtest/2026-10-31-week2/](playtest/2026-10-31-week2/)): all of it reads at a glance. Left for the farm-colour step: the pickup and the stand's awning in the farm colour. The Exchange board wraps long names (Golden Apple Tree, Phoenix Pepper) to two lines. The warehouse site is gravel with a sign until Warehouse Level 5.
9. ✅ **Your store** (week 3, design doc §4.8): the four buildings (Corner Store, Farm Shop, Market Hall, Supermarket), every catalog item (displays, checkouts, decor, wall items) at the 4-stud grid's scale next to a character, the taped-off floor, decorate mode's chalk grid and blueprint look, shoppers with baskets. Built 2026-10-31 (`World/StoreArt`, `World/StoreItems`): the Corner Store in cream timber with a false front, hand-painted sign and striped awning; the Farm Shop a red barn with white trim, a gable roof, a slid-open X-braced door and a big window; the Market Hall brick and timber with arched windows, a clock and striped awnings; the Supermarket a glass front, a band in the farm colour and a rooftop billboard. Waist-high crates and counters, head-high shelves and chillers, lamps above head height. A test keeps every item inside its cells. Checked in Studio on 2026-10-31 from the road, inside at a character's height, from above in Decorate and on a phone ([playtest/2026-10-31-week3/](playtest/2026-10-31-week3/)); fixed there: the glazed doorway, plaster inside the Farm Shop and Market Hall, lamps on cords under the barn's gable, flower boxes instead of awnings over the Market Hall's sign, a real gold star, sturdier scaffolding with its sign by the gate. **Resized the same day** (design doc §10, "bigger stores, a bigger valley"): the Corner Store 32 × 24 studs, the Farm Shop 44 × 36 (two big windows, a steeper gable), the Market Hall 60 × 44 (its arched windows and flower boxes spread along the front, a timber storey with little windows either side of the name, a clock parapet as wide as the sign), the Supermarket 80 × 56 and 18 tall (a 12-stud glass front, a deep name band, a canopy on tie rods over the door, a trolley bay on the verge, light strips across the ceiling, three roof units, a bigger billboard); lamps in a grid about 16 studs apart with at most 6 real lights a store. Checked again in Studio from the road, inside and from above with shoppers ([playtest/2026-10-31-store-sizes/](playtest/2026-10-31-store-sizes/)). **Then see-through roofs and softer light inside** (design doc §10): the roof, roof-top things and ceiling lamps fade while you're in, inside colours that don't glare (warm, for a room lit by the open sky), lamps at 0.45, and the roof's stand-in toward the sun keeping the room in shade while the light outside stays the same; compared with the roof on, side by side ([playtest/2026-10-31-roofs/](playtest/2026-10-31-roofs/)). The Supermarket's plinth no longer crosses its doorway.
10. ✅ **The warehouse and workers** (week 4, design doc §4.6, §4.9): the four buildings, the stations and conveyors, the truck for each stage (pickup, box truck, semis, reefers), workers in their outfits (§8). Built 2026-10-31 (`World/YardArt`, `WorkerController`): the warehouses in metal (`#9AA7B4`) with a warm board lining inside (with the roof faded the room is lit by the open sky), dock doors rolled up under drums in the farm colour, the building's name on a farm-colour board, a staff door with an awning on the gate side, the intake door toward the field, windows all round; inside a conveyor from the intake hopper past the Sort table (a spray arch) and the Pack table to the loading pallets, a branch into the Cold Room (frost-white walls, strip curtains, a count sign), the wash table, lamps on cords; low gable roofs (the Distribution Center flat, with skylights and air units) that fade while you're inside. A dock with a numbered lever per truck, a lane and boom per dock through the front fence. Trucks in the farm colour: the pickup, a box truck (cream box, farm-colour band), semis (a sleeper cab, exhaust stacks, a silver trailer) and reefers (a white trailer with its cooling unit), their roller doors up at the dock. Gold trim at Level 20. Tests keep every building on its side of the farm, each truck in its lane, the front fenced and every doorway clear. Checked in Studio on 2026-11-01 from outside, inside with the roof faded, from above, and with the crew at work and on strike ([playtest/2026-11-01-week4/](playtest/2026-11-01-week4/)); fixed there: the Cold Room open above with a trim round its walls (it had a solid lid), a darker base band along the bottom of the metal walls, dark letters on the gold name board at Level 20, a bigger strike sign held clear of the name tag. Trucks are persistent models, so a truck driving round the valley is always whole on every client.
11. **Defences** (week 6): the scarecrow, guard dog, floodlights, cloches, camera, the tall back fence.
12. **Weather, day and night** (week 7, §4): rain, storms, the 24-minute day, the Harvest Moon night sky.
13. **Interface polish, thumbnails and the Roblox page art** (week 9).
