# Farm Heist: Art direction (the world)

How Cloverdale should look in 3D. The UI's look ("Kraft & Crate") is in [GameDesign.md §5.1](GameDesign.md); the world uses the same colours, so the HUD and the world feel like one thing. Written after the first Studio play-test (2026-10-30). The screenshots it refers to are in [playtest/2026-10-30/](playtest/2026-10-30/).

## 1. What the greybox looks like now

The greybox does its job: the distances and the raid race hold up (PlaytestLog, 2026-10-30). As a picture, though, it shows what the art has to fix:

| # | Seen | Why it matters | Fix (section) |
|---|---|---|---|
| 1 | The Baseplate template's lighting: flat noon light, plus Bloom and **Depth of Field** ([05](playtest/2026-10-30/05-door-to-back-row.jpg)) | Looks like every new Roblox place. Depth of Field blurs the far end of the field, where thieves stand | §4 |
| 2 | A photo-like Grass texture under flat plastic boxes ([03](playtest/2026-10-30/03-farm-from-above.jpg), [07](playtest/2026-10-30/07-field-close.jpg)) | Two styles fighting | §2, §3 |
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
| Farm colours (§7) | 8 bright colours: Tomato `#E8533F`, Tangerine `#F2913D`, Sunflower `#F5C842`, Clover `#5CBF4A`, Teal `#2FB5A8`, Sky `#4C9BE8`, Grape `#8B6CD9`, Rose `#E86AA8` | flags and trim |

## 4. Light and sky

Set in code (`World/LightingSetup`, run by WorldBuilder) so every server looks the same and it's in git. The one exception is `Technology`: scripts can't set it (the play-test's command bar couldn't even read it), so it's set by hand in Studio and saved in the place. Starting values to tune by eye:

| Setting | Value | Why |
|---|---|---|
| `Lighting.Technology` (by hand) | ShadowMap | Soft sun shadows, cheap on phones |
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

- **Workers:** blocky NPCs in a uniform for their job: Farmhand green overalls, Sorter blue apron, Packer brown apron, Loader orange vest, Driver a cap, Stocker a green polo, Cashier a red apron, Watchman a yellow raincoat and a torch. A small name-and-level tag.
- **Shoppers:** varied colours, carrying baskets that fill up.
- **Town characters:** Barley (a straw hat), Patty (a clipboard) and Sheriff Clucks (a rooster in a cowboy hat with a star).

## 9. Effects and markers

- **Thieves, as the owner sees them:** a Suspect gets the red **!** (§4.12), drawn at a fixed pixel size and always on top inside your farm, so it shows at 160 studs, plus a red outline (`Highlight`) while the theft alarm is on. The **Loot Sack** is bigger than a head, with the crop's top sticking out.
- **Steal:** a progress ring over the crop, the crop shakes and rustles.
- **Bonk:** a star burst and a "BONK!" pop; the knocked-out player has birds circling their head.
- **Arrest:** a cartoon puff with handcuffs, then the mugshot card (UI).
- **Theft alarm:** a red light spins on the farmhouse and the gate flag flashes.
- **Ripe crop:** sparkles. **Mutations:** an aura in the mutation's colour (thieves see it too, §4.14).

## 10. Phones and performance

- **Camera:** default Roblox follow camera, FOV 70. Signs in the world have letters at least 3 studs tall (readable at 30 studs on a phone).
- **Budget:** under 3,000 parts for a fully built farm, under 20,000 for the town and valley. Props are MeshParts with `CollisionFidelity = Box`, and textures are 512 px or smaller.
- **Streaming:** `StreamingEnabled`, with each farm as one atomic Model, so a far farm streams in whole.
- **Check every look change from the same viewpoints** as this play-test (valley from above, town spawn, farm gate, farmhouse door to the back row, warehouse to the back row, the back trail, and the phone view) and compare them side by side.

## 11. Build order: the look pass

Each step is checked in Studio from the viewpoints above, against this doc.

1. **Light and sky** (§4).
2. **Fences, hedges and the gate arch:** pickets and slats instead of the greybox's rails, rounded hedges, the arch with the name plate (§7).
3. **The field:** block edging, locked-land overgrowth, and crop stages for week 1's crops (Carrot, Corn, Pumpkin). The other crops come later from a crop-art tool (design doc §11 step 7).
4. **The valley:** Terrain hills, woods in the gaps, back-trail cover, the tunnel mouth (§5).
5. **Farm colours** and name plates (§7).
6. **The town:** plaza, clocktower, signposts, building façades (§6).
7. **Markers:** the Suspect **!** and outline, the sack (§9). These come with the stealing week.
