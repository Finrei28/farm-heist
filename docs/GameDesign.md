# Farm Heist: Game Design Doc

_Status: MVP week 5 built and played in Studio, then reworked after review (stolen crops held up in your hands, the bat's hold and swing, no travel cooldowns, no flicker, solid trucks), then crops counted one by one (a patch gives several), coins ×10 and Field Levels, the crops, wild land and produce as meshes and the farmhouse and barn built (§10) · Last updated 2026-11-02_

## 1. Pitch

**Grow it. Ship it. Guard it.** Every player gets a farm on the edge of Cloverdale. You plant seeds from Barley's shop, wait for them to ripen, then run your own little food business: pack crates in your warehouse and truck them to the city at the global market price, or stock your own shop and set your own prices. Ripe crops sit in the field for anyone to grab. Leave your farm and someone might sneak in. Stay home and you can bonk them with your bat, arrest them, and get paid for your trouble.

### Pillars
1. **Your farm, your rules.** You own the plot, the prices, the workers and the bat.
2. **Every crop is a choice.** Harvest now or leave it ripe in a storm to mutate (and risk it being stolen). Truck it at the market price or sell it in your shop at yours.
3. **From muddy boots to a business.** You start by hand-picking carrots. Later you run a warehouse full of workers while you hunt Mythic seeds at the auction.
4. **Sneaky, never cruel.** Stealing is quick and funny. Losses are capped and getting caught costs the thief. No one loses anything while they're offline.

### Audience and platform
- Ages 9–16. Mobile-first, landscape. Big tap targets, the main action on one big context button, readable at phone size. Same HUD rules as Tide Market (`UI.compact` / `UI.touch`).
- Sessions of 15–40 minutes, plus a daily check-in for offline growth and the "welcome back" earnings.
- Roblox maturity: cartoon violence only (a bonk with dizzy stars, no blood or injuries). Expected label: *Mild*.
- **8 players per server** (8 plots).

## 2. Core loops

| Loop | Length | What happens |
|---|---|---|
| **Action** | 1–7 s | Plant, water, harvest · steal (hold) · swing the bat · pack a crate |
| **Crop loop** | 1 min–6 h | Buy seeds → plant → wait (do the warehouse, shop, auction, defence or a raid) → harvest |
| **Business loop** | 5–15 min | Warehouse: sort → pack → route → truck or store → coins → workers, Warehouse and Store Levels, decor |
| **Session** | 15–40 min | An auction or two, a weather event, a few raids each way, one upgrade bought |
| **Daily** | 1–2 visits | Welcome-back summary (offline growth, sales, wages) → daily quests → Harvest Moon event |
| **Long-term** | weeks | Clear land to 8×8 (by Farm Level) · Warehouse and Store Level 20 · a decorated Supermarket · a Level 10 crew · Mythic seeds · Cropdex · Sheriff, Most Wanted and Top Store boards |

```
            ┌──────────── Seeds (Barley's shop · auction · trades) ◀──────────────┐
            ▼                                                                       │
 Plant ─▶ Grow (online 100% · offline 25%) ─▶ Ripe ─┬─▶ Harvest ─▶ Barn inventory     │
                                                     │                  │            │
                                    steal ◀──────────┘                  ▼            │
                     (held over the thief's head → their barn) Warehouse: Intake → Sort → Pack
                                                                     │         │
                                                          route ─────┤         │
                                                                     ▼         ▼
                                                           Truck (global price) / Own shop (your price)
                                                                     │
                                                                     └──▶ Coins ──▶ seeds, workers, buildings,
                                                                                    defences, auction bids ──┘
```

## 3. The world: Cloverdale

A round green valley with hills all round and a tunnel in the north cliff where trucks drive out to "the City". Built by `WorldBuilder` from `PlotLayout`, like Tide Market.

**From the centre outwards:**
1. **Town square (the hub).** You join at your own farm (§4.1); the town is where you shop, bid, trade and get hired help. A clover-shaped plaza with a clocktower and a fountain. Around it:
   - **Barley's Seeds** (seed shop, Barley the shopkeeper, a seed-packet rack wall and a restock chalkboard)
   - **Cloverdale Auction House** (red barn hall with a bell tower; a stage, a lot display, bidder benches)
   - **Police Station** (Sheriff Clucks, a rooster in a hat; the jail porch where arrested players appear, the Most Wanted and Sheriff boards, the mugshot wall)
   - **Cloverdale Exchange** (a tall grain elevator with a giant flip-board of crop prices)
   - **Hiring Hall** (Patty at the job board; worker candidates wait on the porch)
   - **Trade Plaza** (benches and picnic tables round the fountain; trading works anywhere, but this is where people meet)
2. **Ring Road.** A loop road around the town. NPC shoppers walk its sidewalks to the plot shops, and trucks drive it to the highway.
3. **8 plots** facing the ring road, at 22.5° + 45° × n, so the north gap is free for the highway. The gaps between plots widen outwards and are filled with woods. The side boundaries are **tall hedges that can't be climbed**.
4. **Back Trail.** A dirt path circling behind every plot's back fence, with bushes and hay bales to hide behind (the sneaky way in).
5. **Highway** north from the ring road to the **tunnel**. Trucks drive out of sight and come back empty.

**Distances** (all in `shared/PlotLayout`, checked by `tests/layout.test.luau`): the town square is 160 studs across the radius, the ring road runs at 302, plot fronts start at 320 and backs end at 572, the back trail is at 596 and the hills begin at 630. (The valley grew on 2026-10-31 so each farm's front has room for a real Supermarket, §4.8: farms are 220 studs wide, and a front radius of 320 is the least that keeps the two farms beside the highway clear of it, with 36 studs of woods between neighbours.) The town kept its size, so its own walks didn't change; between the square and the ring road is a 130-stud green with a path to each farm's gate, room for the town's look pass (ArtDirection §6). From the town spawn to a farm's gate is 285–345 studs (18–21.5 s on foot; Visit and Home take 3 s). From the police porch to the back of a farm is 735–910 studs on foot (46–57 s, depending on which farm), because you have to go round the plots. Most thieves will use **Visit** instead: 3 s to the gate, then about 500 studs round the hedge to the back fence (about 34 s in all). So the walk only slows a thief down a little. The real arrest penalty is the fine and the 3-minute wait before they can steal from that farm again (§4.10). (Play-tested in Studio on 2026-10-30, in the smaller valley: 785 studs and 49.2 s to the back of the farthest farm.)

### Plot layout (220 × 252 studs, front to back)

```
 ═══════════════════ Ring Road (NPC shoppers, trucks) ═══════════════════
  sidewalk ─────────────────────────────────────────────────────────────
 ┌────────────────────┬───────┬──────────────────────────────────────┐
 │  OWN SHOP          │ GATE  │  DRIVEWAY ▸ truck bay                │  ← plot boundary starts here
 │  (storefront faces │ + gate│                                      │
 │   the road)        │ house │  WAREHOUSE  [Intake][Sort][Pack]     │
 ├────────────────────┘       │             [Load ▸ dock]            │
 │                            └──────────────────────────────────────┤
 │  FARMHOUSE + BARN (owner spawn)                                    │
 │                                                                    │
 │  ┌──────── FIELD (4×4 at start → 8×8 as you level up) ───────────┐ │
 │  │ ▢ ▢ ▢ ▢ ▢ ▢ ▢ ▢     tiles 12 studs; scarecrow, sprinklers,    │ │
 │  │ ▢ ▢ ▢ ▢ ▢ ▢ ▢ ▢     cloches, floodlights, the guard dog's     │ │
 │  │ ...                 kennel                                    │ │
 │  └────────────────────────────────────────────────────────────────┘ │
 ╞═══════════ BACK FENCE (climbable: 1.5 s, noisy) ═══════════════════╡
   tall hedges on both sides (can't be climbed)
 ─────────────────────────── Back Trail ───────────────────────────────
```

- **Across the front, from the store's side:** a 7-stud side yard by the hedge, the store's lot (83 studs: the Supermarket and its walls), a 6-stud strip of yard to the gate (the way to the staff door), the gate (18), the gatehouse and the driveway, then 72 studs of yard to the other hedge, kept for the warehouse to grow into (week 4: bigger trucks, a second and third dock). **Front to back:** the store and its stockroom (to 64), an 8-stud yard, the farmhouse (72–114), the field (138–234) and the back fence at 252.
- **Only two ways in:** the front gate (past the farmhouse, where the owner spawns) or over the back fence (slow and loud, but right by the field). Raids get decided by which one a thief picks. The driveway has a truck gate that only trucks pass through, and the shop's back wall closes it off from the yard, so neither is a third way in.
- The farm is one zone (`PlotZone`, a server-side box). "In your own plot" means the server's trusted position of your character is inside that box (with 1 stud of hysteresis at the edge). **Your store's building is cut out of it** (§4.8): it's a public place on the road, entered from the sidewalk, and its staff door into the yard only opens for you. The cut-out changes only when the store becomes a bigger building. (The stockroom behind the store is the farm's.)
- A plot only exists in the server while its owner is there. When they leave it's packed away (saved) and the plot goes back to "For Rent".

## 4. Systems

### 4.0 Farm Guide (new players)
A skippable checklist card, the same idea as Tide Market's Angler's Guide. Each step is ticked off by the server when it's really done:
1. **Plant** your 5 free Carrot seeds (the field tiles glow; Plant with no seed in hand opens the seed picker: tap the Carrots)
2. **Water** them (the watering can, hotbar slot 2)
3. **Harvest** when they pop (ripe crops bounce and sparkle)
4. **Pack a crate** at the Packing Shed bench (the pack minigame)
5. **Load & dispatch** the pickup (the receipt shows the price you locked)
6. **Buy seeds** from Barley in town (the **Home** button brings you back)
7. **Stock your store**: pack a crate with 🏪 Store, press **Stock** at a display and pick the crop, set a price
8. **Serve a shopper at your counter**: in by the staff door, behind the Shop Counter, hold the prompt on the counter to check them out (added 2026-11-04)
9. **Hire a Shed Hand** at the Hiring Hall (Patty: "First one's on the house!")

Steps 6–7 need a second harvest, so the card says "Plant your new seeds" in between. Farm Level 2 (needed to hire) comes at 60 XP, which the Guide reaches on its own. It also gives the first Land Permit (§4.1b), and the "all done" card points at the glowing block to clear. Finishing pays **3,000 coins** once. A marker and an edge arrow point to each spot, and the HUD button you need pulses.

**Sprout Shield:** your first **45 minutes of play** (`Crime.SHIELD_SECONDS`). Nobody can steal from you and you can't steal. A soft green dome sits over your field with a timer on it. When it ends you get the **Farm Rules** card: "Ripe crops can now be stolen. In your farm you hold a bat. Bonk a thief, then arrest them!" with a 15 s animated demo. You can drop the shield early (the 🛡️ Defend window's **Drop it now**, until Settings is built) if you want to start raiding.

### 4.1 Plots
- One per player, given out on join: the free plot next to a friend if one is in the server, otherwise the nearest free plot to the highway. Your farm is saved *relative to the plot*, so it rebuilds the same on any plot in any server.
- **You join at your farmhouse door.** The first time, a short fly-over from the town to your farm shows where everything is.
- **Start:** 1,000 coins, 5 Carrot seeds, a 4×4 field, the Packing Shed (Warehouse Level 1), a Corner Store (Store Level 1) with its starter kit, the farmhouse, a wooden back fence and an unlocked gate.
- **Land:** the field is an 8×8 grid, but at the start only the 4×4 corner by the farmhouse is cleared. The rest is overgrown and opens up as you level up (§4.1b).
- **Trusted list:** up to 10 players (friends first in the picker). Trusted players can walk in and out freely, **water and harvest for you** (the crops go to your barn), can't be hit by your bat, and can't steal from you.
- **Arrival grace:** for 1 minute after you join a server your field is protected (the same dome as the Sprout Shield), so you can harvest what ripened while you were away. During it you can't steal either.
- **When an owner leaves**, their farm closes: anyone inside gets "This farm just closed" and is moved to the sidewalk, any steal holds are cancelled, Suspect marks for that farm are cleared and anyone knocked out there wakes up.

### 4.1b Clearing land (unlocks by progress)
Your farm grows with you. The field's 8×8 grid starts with only the 4×4 corner by the farmhouse cleared. The other **12 blocks** (2×2 tiles each) are overgrown with tall grass, rocks and stumps. Coins alone can't open them: land opens with **Farm Level** (`Config/Land.luau`).

| Land Permit | Farm Level | Clearing fee | Field after |
|---|---|---|---|
| 1 | 2 | 2,500 | 20 tiles |
| 2 | 4 | 20,000 | 24 |
| 3 | 6 | 40,000 | 28 |
| 4 | 8 | 70,000 | 32 |
| 5 | 10 | 120,000 | 36 |
| 6 | 12 | 200,000 | 40 |
| 7 | 14 | 350,000 | 44 |
| 8 | 17 | 550,000 | 48 |
| 9 | 20 | 850,000 | 52 |
| 10 | 24 | 1,300,000 | 56 |
| 11 | 28 | 1,900,000 | 60 |
| 12 | 32 | 2,500,000 | 64 (the full 8×8) |

- **Permits come from levelling up.** Reaching each level in the table gives one Land Permit, with a level-up fanfare and a "Land Permit!" card. An unused permit shows as a badge on the Barn button and a glowing "Clear here" sign on the field. The level is what unlocks the land; the fee is a coin sink. Permit 1 costs only 2,500 because the Guide ends by pointing at it, and a new player has about 6,000 coins at that point.
- **Clearing:** use a permit on any overgrown block **touching land you've already cleared**. Pay the fee, then clear its 4 obstacles (a stump, a rock, weeds and a bush): each is a 2 s hold with the hoe, with a satisfying pop. A Farmhand clears them in 30 s. Fresh soil gives the first crop planted there +25% growth.
- **Which block is a real choice.** Blocks towards the back fence are nearer where raiders climb in (see the raid race in §4.11). Blocks beside the farmhouse are safer, but there are only a few of them. The permit card labels each block it can go on: "Safer: near the farmhouse" or "Riskier: near the back fence".
- **Why level, not coins.** Coins can arrive all at once from a lucky Mythic or a trade. Levels only come from playing: harvesting, shipping, selling, arrests and the Cropdex. Tying land to level keeps the field the size a player has learned to run and defend, so nobody skips the early game with one big trade, and a new player is never left guarding a huge field.
- **Buildings already work this way:** each Warehouse and Store Level needs a Farm Level (§4.6, §4.8). With land on the same ladder, all growth is paced by level.
- **Pacing targets** (to be tuned with a progression sim, like Tide Market's `tools/progression`): permit 1 in the first session (Lv 2 comes during the Farm Guide), permit 6 (Lv 12) around day 3, the full 8×8 around weeks 3–4 for a daily player.
- Land Permits are never sold for Robux, and you can't trade them.

### 4.1c Field Levels (better soil, more from every patch)
Your field has its own level ladder, like the warehouse and the store (`Config/Land.FIELD_LEVELS`, `shared/LandRules`): better soil makes every patch you plant give more, and each level changes how the whole field looks.

| Field Level | The field | Crops from every patch | Farm Lv | Cost |
|---|---|---|---|---|
| 1 | Tilled rows | ×1.0 (6 carrots) | 1 | free |
| 2 | **Composted soil**: darker, richer earth, a compost bin by the field | ×1.1 (6 or 7 carrots) | 5 | 50,000 |
| 3 | **Raised beds**: timber walls round every block, a post where they meet | ×1.2 (7 or 8) | 10 | 500,000 |
| 4 | **Drip lines**: a black pipe down every furrow, a tap on each block | ×1.35 (8 or 9) | 18 | 3,000,000 |
| 5 | **Prize beds**: gold-capped walls, a PRIZE FIELD sign with a blue rosette | ×1.5 (9) | 26 | 12,000,000 |

- **How the extra works:** a patch gives its crop's count (§6.1) × the level's multiplier: the whole part always, and what's after the point as the chance of one more, rolled when it's planted (a Level 4 carrot patch: 8 carrots, and 9 one time in ten; a pumpkin patch grows a second pumpkin 35% of the time). The patch shows it as it grows, so you (and thieves) see what's coming. Crops already in the ground keep what they were planted with.
- **Why a ladder here:** the field is where players spend most of their time, and it was the one part of the farm with nothing to spend coins on. More crops push on the warehouse and store ladders, and a high-level farm is the prize for raiders, while a new player's Level 1 field isn't worth the risk.
- **Why only five levels, up to +50%:** land (16 → 64 patches) and rarer seeds (about 8× the earnings a minute) already grow the field a lot; a third big multiplier would race players past every other ladder. Even +10–35% compounds (more coins, warehouse levels sooner, more sold while you're away), so Warehouse and Store Levels 6–20 now cost twice what they did (`tools/progression`, §6.2). Five levels are each a makeover you can see from the ring road.
- **Why more crops, not faster growth:** a 1-minute carrot is busy enough, and speed is what the Growth Boost sells for Robux (§7); the two stay apart.
- **The Barn window's Field tab**: the next level on blueprint paper (its name, "+10% crops from every patch you plant: 6 or 7 carrots a patch, 1 pumpkin, sometimes 2", the Farm Level it needs, **Upgrade**) and the ladder. (Built 2026-11-02: `LandService` UpgradeField, `FarmArt.applyFieldLevel`; `/field N` in Studio.)

### 4.2 Crops and growth

**Digging up a crop** (the user, 2026-11-06: "Allow players to remove existing planted crops as they may want to plant a new crop"; `actions.Dig`): on a growing crop in your own farm a smaller stamp over the big one says **HOLD TO DIG UP** (F; B on a gamepad). Hold it for 0.8 s, as it can't be undone, and the tile's empty again. The seed is lost, so digging up can't re-roll a yield. A ripe crop you harvest instead: the stamp doesn't show on one, and the server refuses it. A friend helping on your farm can't dig.
- **6 rarities** (`Config/Rarities.luau`):

| Rarity | Colour | Grow time (online) | Steal hold | Raid weight | Seed stock chance |
|---|---|---|---|---|---|
| Common | grey | 1–2.5 min | 1.0 s | 1 | always |
| Uncommon | green | 4–6 min | 1.5 s | 1 | 85% |
| Rare | blue | 12–20 min | 2.5 s | 2 | 55% |
| Epic | purple | 40–60 min | 3.5 s | 3 | 25% |
| Legendary | gold | 2–3 h | 5.0 s | 5 | 8% |
| Mythic | pink, rainbow shimmer | 6 h | 7.0 s | 5 | never: auction only |

- **A patch gives several** (`perPatch` in `Config/Crops`, §6.1): a tile is a patch 12 studs across, so you harvest a bed of plants, not one: 6 carrots, 10 potatoes, 4 lettuces, 6 cobs, 4 punnets of strawberries a picking, one big pumpkin or melon, one Mythic. The ripe patch shows every one of them in rows on its ridges (what you see is what you harvest), the harvest pops "+6 🥕" and the tile's line says "🥕 6 carrots · Ripe!". Big crops are one a patch, so a thief can hold a whole patch over their head and a shopper buys 1–4 of them; the Field Level adds more (§4.1c). One seed plants a whole patch.
- **Growth stages:** seed → sprout → growing → ripe (each has its own model, so a field reads at a glance). Ripe crops bounce gently and sparkle in their rarity colour. Mythics glow and can be seen from the ring road.
- **Online** growth runs at 100%. **Offline** growth runs at **25%** (`Growth.OFFLINE_RATE`), so a 6 h Mythic takes 24 h if you're away the whole time. Growth is stored as `progress` (0–1) plus `lastUpdate`, banked when you leave and settled when you join, so it costs nothing while you're gone. Online-only growth bonuses (weather, sprinklers, Growth Boost) don't apply offline.
- **Speed-ups:** watering (once per crop per stage: −10% of the time that stage has left), Sprinklers (an area +20%), Fertilizer (one tile ×2 for 10 min, consumable), weather (§4.14), the Growth Boost product (§7).
- **Regrowing crops** (tomato, strawberry, blueberry, grape, golden apple) give several harvests. After each harvest the plant goes back to "growing" for its regrow time. Thieves only take the fruit; the plant stays.
- **Mutations** (§4.14) can appear on **ripe crops left in the field** during weather. Leaving them in the ground is a gamble: they might mutate or they might get stolen. Tap a tile and choose 🚩 **Leave in field** so Farmhands skip it. A mutated crop keeps its own barn stack ("Wet Carrot ×6") and **goes by truck** at its multiplier: you wash it at the wash table by hand (the crew leaves it), and the store doesn't take it (week 7: shelves for mutated crops can come later if testers want them). Farmhands pick mutated crops like any other while you're here; while you're away they leave them in the field.
- **Giant crops:** Rare and above have a 1% chance to ripen as a Giant (×3 value, 2.5× the model size). Great to show off, and a magnet for thieves. *Not built yet* (week 7 left them out: a Giant patch of 4 bell peppers at 2.5× doesn't fit its tile, so how a Giant looks needs deciding first; the Cropdex's Giant records come with them).

### 4.3 Barley's Seeds (seed shop)
- Barley stands behind the counter. Talk to him (E) to open the **Seed Rack** window.
- **Restock every 5 minutes on the clock**, the same on every server (a seeded roll, like Tide Market's `BaitStock`). Commons are always in, with no limit (a field of 1-minute Carrots needs a lot of seed). Every other seed rolls its rarity's stock chance, then comes in packs: 1–5 packs of 5 (Uncommon), 1–4 of 3 (Rare), 1–2 of 2 (Epic), 1 seed (Legendary). **Barley never sells Mythic seeds: they only come from the Auction House** (§4.4; his rack has no Mythic tab, and the server refuses one with "they only come up at the Auction House"). Each player has **their own** stock, so buying never takes from anyone else. It's saved per restock, so rejoining doesn't refill it. A Legendary in stock is announced to the server ("Barley just got a Moonmelon seed in!").
- Farmhands replant from your seed stock, so someone still has to come to town for seeds.
- Seeds above your Farm Level show locked ("Lv 10"), so players can see what's coming.
- Buying needs you to be at the counter (server distance check). Leaving your farm to shop is a small risk, on purpose.

### 4.4 Cloverdale Auction House
- **A live auction every 8 minutes** on the clock (:00, :08, :16 …), with a 1-minute warning toast that has a **Town** button.
- **5 lots per auction**, about 60 s each, 10 s apart (about 6 minutes of the 8). Each server rolls its own lots from the pool (`Config/Auction.luau`), **the rarer, the less often**: Uncommon seed 30% · Rare seed 26% · Epic seed 17% · Legendary seed 7% · Mythic seed 3% · rare worker contract 10% (Speedy Sam twice as often as Grandma Rose: §4.9) · defence 7% (a Glass Cloche 3 in 6, a Guard Dog 2 in 6, a Security Camera 1 in 6; worth its shop price, and it still needs its Farm Level and room for one more). A seed lot is one seed, each crop of its rarity as likely. No Commons (Barley always has them). The auction is the only place to get Mythic seeds (§4.3): about 1 auction in 7 has one. Golden tools and cosmetics aren't lots: the cosmetics are in the Robux shop (§7), and the tools have no designed effect.
- **Opening bid** is 40% of the lot's estimated value, so every lot opens below what it costs elsewhere (a seed's estimate is Barley's price, a defence's its shop price). The **minimum raise** is 5%, and at least one bid step. Bids go in steps that suit the lot (10 coins under 1,000, 50 under 10,000, 100 from there), so a 360-coin Corn seed's quick bids are 380 · 400 · 450, not three 500s. Quick-bid buttons: **+5% · +10% · +25%**.
- **Anti-snipe:** a bid in the last 10 s puts the clock back to 10 s.
- **Escrow:** bidding moves the coins out of your wallet. If someone outbids you, they come back straight away. Winning spends them (a coin sink) and the item goes into your inventory, saved immediately. The coins a lead holds are written in your save too (`auctionHeld`), so a server that closes mid-lot (an update) can't lose them: they're back on your next join.
- **You must be inside the hall to place a bid** (trusted position). Holding a bid doesn't need you to stay. If the leading bidder leaves the server, their bid is cancelled (their coins go back into their save before it closes) and the highest earlier bidder who can still pay takes the lead. You can't bid on a lot you couldn't take home (a defence below its Farm Level or one too many, a rare worker with no free slot for their job): the card says why instead of showing the buttons.
- **The hall** (`World/AuctionArt`): a red barn hall with white trim, a slate roof and a bell tower that rings when an auction starts; its big doors stand open to the square. Inside, benches face a stage with the lot board (a chalkboard between red velvet curtains), the lot floating over a pedestal, and the auctioneer, **Goldie Gavel** (a golden hen in a red waistcoat and bow tie), at her podium. She calls it in a speech bubble: "Going once… going twice… SOLD to Sam!", with confetti over the pedestal.
- **The room, like a real auction** (added 2026-11-04): everyone in the hall holds a **bidder paddle** with their number (10–99, theirs for the server's life) in their right hand, up in front of their chest. **A bid raises it**: it snaps up over your head with a shake while your call pops up over you in a speech bubble ("52,000!"), then comes down. **Goldie works the room by paddle number** (`AuctionRules.patter`): "Lot 2: Moonmelon seed! Who'll start me at 48,000?" · "48,000 from paddle 47! Do I hear 50,400?" · "50,400 from paddle 12! Back to you, paddle 47: 53,000?" · "I have 50,400 from paddle 12. 53,000, anyone?" · "Going once at 50,400..." · "Going twice..." · "SOLD! To paddle 12, Sam, for 50,400!". She turns her head to whoever just bid and nods as she talks; her gavel comes down on going once, going twice and SOLD (with its sound). The winner hops and waves their paddle overhead, the other arm up. **You can sit on the benches** (five places on each of the six, facing the stage): **Sit** (E, or the prompt's button), then watch and bid from your seat, paddle and all; jump to stand up. Only the prompt seats you (walking along a row doesn't), a taken place hides its prompt, and not with your hands full. (Animated on every screen from the server's attributes: `PoseController` for the arms, `AuctionController` for the bubbles and Goldie; no animation assets.)
- **Bidding** (`AuctionController`): inside the hall during a lot, a red velvet card in a gold frame on the right of the screen (smaller and in the top right corner on phones) shows the lot, your paddle number, about what it's worth, the top bid and whose paddle has it, a clock that flashes when a late bid puts it back, a big **🙋 RAISE PADDLE** button for what Goldie's asking (the next step up; the opening price before anyone bids) and two small **+10% / +25%** jump bids, whether you're the top bid, your coins and the lots to come. Outbid on a lot you'd bid on, the paddle button pulses ("back to you!"). Outbid, a note says your coins are back. A note a minute before each auction and one as it starts (saying what's up) carry a **Town** button.
- **v1.1: Auction Board.** Players list their own items across all servers (MemoryStore), with a reserve price, 1 h listings and a 5% fee (a coin sink).

### 4.5 Inventory (the Barn)
- Harvesting a crop puts it **straight into your Barn inventory** (a pop and a +1 in a little basket). Tabs: **Crops · Seeds · Items · Workers · Land** (the block map, permits waiting, and the blocks each one can go on).
- Crops stack by crop + mutation (+ Giant), counted one by one (126 carrots, 3 pumpkins). Capacity is **1,200 crops** at the start (about 200 patches' worth). The Silo upgrades raise it to 3,000 / 9,000 / 30,000 (20,000 / 200,000 / 1,200,000 coins). When it's full, harvesting stops ("Barn full!" and the Farmhands stop with it).
- **Returns and deposits always fit.** Loot returned to an owner, or a stolen crop carried home to your own barn, goes in even past capacity. The barn then shows "Over capacity" and harvesting waits until you've sold some.
- **Stolen crops aren't inventory.** A stolen crop is held up in the thief's hands, not put in their barn. It becomes the thief's only when they carry it **back into their own farm** (through its gate or over its back fence), where it goes straight into their barn. If anything goes wrong before that (§4.12), the loot goes back to the owner.

### 4.6 Warehouse (Warehouse Level 1–20)
The way to sell in bulk. Crops go through stations, and **each station can be done by hand (a short minigame) or by workers**. The warehouse grows by **Warehouse Level** (1–20). Every level adds one thing you can feel: a bigger truck, a quicker trip, a worker slot, more room, a new tool. Four of them (1, 5, 10, 15) are a new building.

| Step | Station | By hand | What it does |
|---|---|---|---|
| 1 | **Intake** | (the crew's: routed crops flow in from the barn) | The intake hopper at the back door, toward the field |
| 2 | **Wash & Sort** | Hold to spray at the **wash table**; let go when the meter is in the green | Grades each batch **A** (×1.15 value) or **B** (×1.0). Doing it by hand gives the best chance of an A |
| 3 | **Pack** | (by hand the same hold packs it: one hold a crate, as at the shed) | Crates by crop (`Config/Crops`): 12 patches' worth of a Common, 10 of an Uncommon, 6 of a Rare, 4 of an Epic, 2 of a Legendary, 1 Mythic (in a velvet case): 72 carrots, 60 tomatoes, 6 pumpkins, 8 pineapples (a few rounded down to look like a real crate: 100 potatoes, 24 lettuces, 24 punnets). A crate can go out part-full by hand; the crew packs full ones |
| 4 | **Route** | Set once in the Warehouse window | What the **crew** does with each crop once it's packed: **→ Truck** (loads it), **→ Store** (puts it out) or **✋ Keep** (leaves it in the barn for you), or a split, e.g. 70/30, from Level 5. By hand any crate goes either way |
| 5 | **Load** | "Load crates" at a truck's dock opens the **dock window**: pick what goes on, from your packed crates (the **hand cart** takes 4 at a time), and take crates back off while it's home | Fills that truck's bed |
| 6 | **Dispatch** | Pull the dock's lever, or **Send now** in the Market window (every truck home and loaded) | The truck leaves. **The price locks now**, and you get a receipt |

- **Routes from Level 1:** the Shed Hand (§4.9) needs to know what to do, so the Routes tab is there from the start: Truck, Store or Keep for every crop you've unlocked, and anything else you have (new crops go by truck, so you can set one before its first harvest); splits come with Level 5. A route only tells the crew what to do. **By hand in the warehouses** you use the wash table, the shed's bench grown up: one hold washes and packs a crate (one hold a crate is enough on a phone).
- **The Packing Shed (Levels 1–4) has no Intake:** its bench pulls crops straight from the barn. Each barn stack shows what it pays right now, **🚚 31 · 🏪 34 coins each** (today's market price for one, and your price in the store), and one **📦 Pack** button. You **hold to wash** and let go in the green for grade A; the crate packs itself (the tape swipe is the Pack station's job from Level 5; one hold per crate is enough on a phone). (`WarehouseService`, `shared/CrateRules`.)
- **Packed crates are one stock, for the truck and the store alike** (the user, 2026-11-05: "Make it so that packed create/produce can be used for both the truck and the store"; `shared/PackRules`). However a crate is packed, it waits there until you, or the crew by its route, put it on a truck or a display. It holds what the dock rack or Cold Room and the store's stockroom hold together (12 at the start), so either upgrade adds to it. **When it's full, packing stops** and the crew waits for space (they say so, once): a crop routed to the store is never pushed onto a truck (that was the bug: "the packing shed worker packs for the truck even though it was routed for the store"). That goes for every crop, whatever its route: nothing new is packed until a crate leaves the stock. Crates already in it for the truck still get loaded, and that makes room. Mutated crates stay in the stock but only go by truck. You see them where they'd be used: those for the store in the stockroom, the rest on the rack or in the Cold Room, with the Cold Room's sign counting them all.
- **Crops for the store don't wait for a full crate** (the user, 2026-11-06: "Workers seems to be not packing for the store"; `PackRules.readyToPack`): a crop for the truck waits in the barn for a crate's worth, as a trip is paid by what's on it. A crop ticked for the store goes out part-full as soon as it's in the barn, or it would sit there while the shelves run out. A split waits for a full crate, as half of it is for the truck.
- **Crates get where they're going** (the user, 2026-11-06: "The packing workers should also bring the crates to their destination instead of just teleport the crates to their place"; `WorkerService.carryToStock`, `PackRules.pickUp`): a crate shows at its place as it arrives. A Shed Hand carries one to the rack, a Packer puts one on the belt to the Cold Room, and either walks one for the store round to the stockroom, by its side open to the yard. They pack nothing more until they're back, so the long way to the store takes as long as it takes, and what's in the barn by then goes on the next trip. A crate on its way is in your save (`warehouse.carried`) and keeps its place in the stock, so nothing's lost if the server closes: it joins the stock on your next join. A crate you pack by hand still goes straight to the stock.
- **Crates combine in the stock** (the user, 2026-11-06: "If there a crate with 10 crops and another of the same crop crate with 10 crops, just combine them into one in the stock room"; `PackRules.stow`, `combine`): a crate joining the stock tops up a part-full one first, up to a crate's worth. They must be the same crop, mutation and grade, and the crew must be doing the same thing with both, so a crate you sent to the stockroom stays apart from one for the truck, and grade A keeps its price. Coming back from your time away, the whole stock is combined.
- **Sending crates to the stockroom** (the user, 2026-11-05: "interact with the packed crates at the packing shed that opens up a panel where they can select crates they can send to the stockroom"; client `RackController`, `PackRules.send`): **Send to stockroom** at the rack (the Cold Room's sign from Warehouse Level 5) opens a window of the crates there, alike ones together, with **Send**, and what's in the stockroom already. A crate sent is the store's, whatever its crop's route, even on ✋ Keep: the crew won't load it, and a Stocker puts it out. The stockroom's own size is the limit (6 + 2 a Store Level). Mutated crates stay: they only go by truck. By hand you can still load a sent crate at the dock.
- **Mutated names stand out** (the user, 2026-11-06: "Change the text colour for mutated names so it's easier to notice"; client `CropNames`, `Config/Weather`): in the Barn, the wash table, the dock, the packed crates window, the Stock tab, the Routes tab and the trade window, a mutated crop's whole name is in its mutation's colour, and a Giant's in green. The auras are too pale to read on a cream card, so each mutation has a darker colour for text: Wet blue, Frosted teal, Golden dark gold, Shocked orange, Moonlit purple, Rainbow pink.
- **Mutated and Giant crops wait for you unless you say so** (the user, 2026-11-05: "Allow selecting which mutated produce to pack or not pack"; `PackRules.crewTakes`, `warehouse.packs`). The Routes tab lists each kind with 📦 Pack or ✋ Keep, Keep to start with. A kind on Pack is packed by the crew as it comes, in part-full crates since they come a few at a time, and goes by truck. For a crop on 🏪 Store it's packed all the same and waits at the dock for you to load: a mutated crate can't go in the store, and the crew never loads a crop ticked for it (the user, 2026-11-06: "The packers don't seem to be packing mutated crops now"). On ✋ Keep it stays in the barn. A Giant mutated crop needs both picked. It's only while you're here: time away leaves them in the barn. By hand you can always pack any stack.
- **The truck** backs up to the dock at the top of the driveway. "Send the pickup" is the lever on the dock, or **Send now** in the Market window from anywhere (so you can watch the prices and send at the right moment). It drives out through a striped boom gate (people can't pass it), round the ring road the short way and up the highway into the tunnel; the crates ride along until they're sold, and it comes back empty. A paper receipt lists each crate and the price it locked. **You're paid when it reaches the City** (half the trip). Each run is a saved `TruckRun`: if you've left by then, it's paid the next time you join (any server), shown on the Welcome back card. (`TruckService`, `shared/TruckRules`; clients drive the truck from its `DepartAt`/`ArriveAt`/`ReturnAt` attributes.)
- **The dock window** (the user, 2026-11-05: "Allow selecting which crates/produce goes on the truck"; client `DockController`): the truck's load and **Send**, your packed crates (alike ones together, with what each pays by truck and in your store) with **Load**, and what's on the truck with **Take off**. What you hold back waits in the stock for a better price, or for your store: that's how you **hold crates for a better price**: wait for ▲ on the board, or give your Driver a price rule (§4.9).
- **Levelling up:** the Warehouse window's **Upgrade** tab is a blueprint with the level ladder: where you are, the next level's card (cost, Farm Level needed, what it adds) and **Upgrade**. Ordinary levels are instant. The four building levels take time to build (builders and scaffolding, at the same online/offline rates as growth) and the old building keeps working until the new one is done. Levels never go down. From Level 5 the warehouse buildings are enclosed, so they get the store's see-through roof (§4.8): an `Interior` box beside the `Roof` model.

| Lv | Cost | Farm Lv | Truck(s) | New at this level |
|---|---|---|---|---|
| 1 | free | 1 | Pickup: 4 crates, 60 s | **Packing Shed**: the bench, the dock, the lever, a dock rack for 6 crates (room in your packed crates, with the stockroom's); 1 Shed Hand |
| 2 | 8,000 | 2 | 5 crates | |
| 3 | 20,000 | 3 | 50 s round trip | dock rack holds 10 |
| 4 | 35,000 | 4 | 6 crates | 2 Shed Hands |
| 5 | 80,000 | 5 | Box Truck: 12 crates, 90 s | **Distribution Warehouse** (builds in 2 min): Intake, Wash & Sort, Pack and Load stations on conveyors, a hand cart, route rules, Cold Room 20 crates. Sorter 1 · Packer 1 · Loader 1 · Driver 1 (Shed Hands become Packers) |
| 6 | 240,000 | 6 | 14 crates | Packer 2 |
| 7 | 360,000 | 7 | | conveyors ×1.1 · Cold Room 30 |
| 8 | 520,000 | 8 | 75 s round trip | Sorter 2 |
| 9 | 720,000 | 10 | 16 crates | Loader 2 |
| 10 | 1,200,000 | 12 | 2 × Semi: 24 crates, 120 s | **Big Warehouse** (5 min): a second dock and truck · Driver 2 · Packer 3 · Cold Room 50 |
| 11 | 1,600,000 | 13 | 26 crates | |
| 12 | 2,100,000 | 14 | | conveyors ×1.2 · Sorter 3 · **Wash Line**: Sorters' grade A chance +5% |
| 13 | 2,700,000 | 16 | 28 crates | Packer 4 · Cold Room 70 |
| 14 | 3,500,000 | 18 | 30 crates, 110 s | |
| 15 | 5,000,000 | 20 | 2 × Reefer: 34 crates, 100 s | **Distribution Center** (10 min): **Premium contracts** (Legendary and Mythic crates +10%) · conveyors ×1.35 · Loader 3 · Cold Room 100 |
| 16 | 6,800,000 | 22 | | Packer 5 |
| 17 | 9,000,000 | 24 | 38 crates | |
| 18 | 12,000,000 | 26 | 80 s round trip (the **Express lane**) | Sorter 4 |
| 19 | 15,600,000 | 28 | 40 crates | conveyors ×1.5 · Cold Room 150 |
| 20 | 20,000,000 | 30 | 3 × Reefer | a third truck and Driver 3 · gold trim on the building |

The whole ladder costs about 81 million (Levels 6–20 cost twice what they did before the Field Levels, §4.1c). In the progression sim (§6.2, `lune run tools/progression`) a daily player reaches Level 5 on day 2, Level 10 on day 8 and Level 15 on day 22; a casual one Level 10 on day 18; Level 20 is a goal for the second month. Each truck has its own dock, lever and lane through the front fence (a striped boom each): the docks at 29, 55 and 81 across, the buildings growing from the Packing Shed's corner toward the hedge and the field (`PlotLayout.WAREHOUSES`). (Built in week 4: `shared/WarehouseRules`, `WarehouseService`, `World/YardArt`.)

- **The Warehouse window is a clipboard** with three tabs (🏭 on the side bar). **Pipeline:** each station is a box with its queue, worker slots ("2/3", and which level opens the next) and a throughput figure in crates a minute. **The slowest station is highlighted orange** with a tip ("Pack is your bottleneck: hire another Packer or train yours"). Each truck shows a fill bar, an ETA and **Send** with the price it would lock, and the Drivers' rule. **Routes:** crop → Truck / Store / Keep / split. **Upgrade:** the level ladder above.

### 4.7 Global market price (the Cloverdale Exchange)
Every crop's truck price is the same on every server at any moment:

`price(crop, t) = base × wave(t) × event(t) × supply(t)`, clamped to **0.5–2.0 × base** and rounded to whole coins (`shared/MarketPrice.luau`).

- **wave(t)**: `1 + 0.12·sin(2πt/45min + φ₁) + 0.08·sin(2πt/3h + φ₂)`, with φ from a hash of the crop id. Smooth ups and downs (0.8–1.2) that are the same on every server without any messaging.
- **event(t)**: a deterministic schedule from the hour index. Each hour has one **Hot Crop** (×1.5 from :10 to :25) and one **Glut** (×0.75 from :40 to :55), two different crops and never Mythics, announced 2 minutes ahead. Seasonal festivals too (e.g. a Pumpkin Festival in October: pumpkins ×1.3 all week).
- **supply(t)**: player-driven. Each server adds the crops it sold to MemoryStore counters (`Market_<crop>_<window>_<shard 1–8>`, 10-minute windows, written in batches every 30 s). `supply = clamp(1 − 0.12·log₂(1 + sold/expected), 0.7, 1.0)` (expected: a rarity's patches' worth × the crop's count a patch). If everyone dumps carrots, carrots drop everywhere, so it pays to grow different things. If MemoryStore fails it falls back to 1.0.
- **The Exchange board** in town (a split-flap board on the grain elevator's face) and the **Market** window (a chalkboard, from the side bar or the Exchange desk) show each crop's price, a ▲/▼ trend over the last 10 minutes, a 3-hour sparkline and this hour's events. A chalk ticker under the purse cycles through the live events and the crops in your barn. The clients work all of it out from `shared/MarketPrice` and the server clock: the same numbers the server locks. The supply factor came in week 8: `MarketService` keeps the counters in one MemoryStore sorted map (`<window>|<crop>|<shard>`, so a server reads a whole window in one call), counts what each truck takes at dispatch (when its price locks), weighs the window before as the current one fills, and publishes each crop's supply as `ReplicatedStorage.MarketSupply`'s attributes, which the clients' `MarketPrice.supplyOf` reads. The Market window says "lots sold lately −8%" under a crop it's pulling down.
- **The price locks at dispatch.** The skill is choosing *when* to send the truck (or giving a Driver a rule for it, §4.9).
- **You never have to go to town to see prices.** The **📈 Market** crate on the side bar opens the Market window anywhere (and so does tapping the ticker under the purse), with **Send now** for your truck. The Exchange board and desk in town are there for the look and for players passing by. (Built in week 2.)

### 4.8 Your Store (Store Level 1–20)
Every farm has its own store on the road, from the first minute: NPC shoppers walk in from the sidewalk, browse what you've put out and pay **the prices you set**. You lay it out and decorate it yourself, staff it, and grow it from a little corner store into a supermarket. (It replaces the Farm Stand of week 2, which was the plan's tier 0; the old plan's four fixed tiers had a set number of shelves and no decorating.)

**The building.** It stands on the shop lot at the front of the farm (83 × 64 studs: from the strip of yard by the gate toward the hedge, and back to 8 studs short of the farmhouse; the storefront on the sidewalk). Inside is a grid of **4-stud floor cells** that opens a row or a column at every level (both at Levels 4, 5, 10, 15 and 20), inside a building that's rebuilt bigger at Levels 5, 10 and 15. Each building is clearly bigger than the last, from a corner shop you see all at once to a supermarket wider than the farmhouse:

| Store Levels | Building | Floor (cells) | Looks like |
|---|---|---|---|
| 1–4 | **Corner Store** (32 × 24 studs) | 6×4 → 8×6 | a timber shop with a striped awning and a hand-painted sign with your store's name |
| 5–9 | **Farm Shop** (44 × 36, builds in 2 min) | 9×7 → 11×9 | a red barn with two big windows, a barn door and a hayloft, lamps on cords under the gable |
| 10–14 | **Market Hall** (60 × 44, 5 min) | 12×10 → 15×11 | brick below with arched windows and flower boxes, a timber storey above with little windows, a clock on the parapet |
| 15–20 | **Supermarket** (80 × 56, 10 min) | 16×12 → 20×14 | 18 studs tall: a glass front, a deep band with its name, a canopy over the door, a trolley bay, light strips across the ceiling, a billboard on the roof |

Floor not open yet is bare concrete, taped off in yellow and black with a stack of "Next level!" boxes, so the next expansion is right there to see. The part of the lot the building doesn't cover yet is yard, behind the front fence. **When a level opens floor at the back, everything standing against the old back edge moves back with it** (if the layout still works), so the shelves stay against the wall and the aisle widens instead of a new row being walled off. At 20×14 (Level 20: 80 × 56 studs, 280 cells, plus the walls and a 6-stud back room for the stockroom) the Supermarket fills the lot: from the strip by the gate (kept clear: the way to the staff door) to a 7-stud side yard by the hedge, and back to an 8-stud yard in front of the farmhouse. Every farm's lot is the same, and neighbouring farms are 36 studs apart at the front, so every player has the same room (`tests/layout.test.luau`; `tests/world.test.luau` builds each building at its biggest on a farm and checks it stays on its lot with the front still closed). When a new building goes up, anyone standing where its walls will be is moved out to the sidewalk or the yard first. **Each new building comes with a free display, already placed in the new space** (Farm Shop: a Tiered Produce Rack · Market Hall: a Glass Showcase · Supermarket: a Self-checkout), so a store grows even for players who never decorate.

**Whose space it is.** The store is a public place on the road, **not part of your farm's zone** (§3): anyone can walk in from the sidewalk and look around (a nice way to show off your store), the bat doesn't come out in it, and nothing in it can be stolen. Only NPC shoppers buy; players swap goods by trading (§4.13). A **staff door** in the side wall facing the gate leads straight into your yard, and it only opens for you (and Trusted friends from week 6, §4.11): it swings open as you come near, and it's a wall to everyone else, so the store is never a way into the farm. The **stockroom** is a lean-to behind the back wall, on the farm's side and open to the yard, with a crate in it for every crate waiting there. The location chip says "🏪 Sam's Corner Store". You name your store in the Store window (3–24 letters, filtered for everyone with Roblox's text filter; if the filter can't be reached, it keeps the name it had and asks you to try again).

**Seeing in.** While you're inside a store (yours or anyone's), its roof, with what stands on it and the ceiling lamps, fades away on your screen only, so the camera can rise over the walls and look down at your displays, price tags and queues instead of being pushed up behind your head by the ceiling. The room stays out of the sun as if the roof were there (a stand-in for the roof far off in the sky, lost in the sun's glare, casts its shadow), so nothing glares, and **the light everywhere else stays exactly as it is**: from inside your store you still see your field in full daylight, thieves included. The roof comes back as you step out, and nobody else's view changes (`RoofController`, §10).

**Decorating** (on a keyboard each button shows its key: **E** moves the item under the mouse, or the one you've picked, and places (a moved item stays picked; with a new item in hand that can't go there, E picks up what you're pointing at); **R** turns, **F** puts away, **G** sells, **Q** cancels; a **double click** on an item moves it too; the user, 2026-11-05). **Decorate** in the Store window (on your farm or in your store) lifts the camera over the store with the grid in chalk, the roof off and the walls faded. A drawer of item cards (Displays · Checkouts · Decor · Wall · My items) runs along the bottom. Tap a card, then a cell: the item shows green where it fits and red where it doesn't (with why). ⟳ turns it, ✓ (or a second tap) places it. Tap a placed item to move, turn, put it away (it stays yours) or sell it back for half. On a computer: it follows the mouse, a click places it, R turns it. Pinch (or the mouse wheel) zooms in and a drag (or WASD) moves the view, for the bigger buildings on a phone. **It's a plan until you press DONE**: then the server checks the whole layout once, buys what's new (the total is shown under DONE all along) and saves it; ✕ leaves your store as it was. So you can try things out freely, and nothing moves under a shopper's feet until you're done.
- **The rules** (`shared/StoreLayout`, the same check on the client and the server): items sit inside the open floor and don't overlap (a Rug is walked over, but nothing stands on it). The cells inside the front door and the staff door stay clear. Every display and checkout has a front, and the cells in front of it must be free. **Every one of those front cells must be reachable from the door** through free cells, and so must the staff door. Each checkout needs a queue: its till's front cell and 2 more free cells in a line (straight back, or turning left or right), not shared with another checkout. A Register needs the cells behind it free, for whoever serves. At least one checkout, and no more than the level allows. A move that breaks a rule is refused with why: "This would block the aisle to your Pumpkin shelf". Wall items hang on the back and side walls (the front is the shop window), never over the staff door.
- While you decorate, the store hangs a **"Back soon"** sign: no new shoppers come in, and those inside skip the rest of their list and go to pay. Anyone still inside when you press DONE puts their basket back and leaves (no rating score). Leaving your farm and store, or 5 minutes without changing anything, ends it.
- **Your store starts furnished:** a Shop Counter, 2 Produce Crates, a Wooden Shelf and a Potted Plant, already placed. Decorating is never required to sell. (On the 6×4 floor: the shelf, crates and plant along the back wall facing the door, the aisle in front of them, the Shop Counter just inside the staff door (you step in from the yard and you're behind it) with its queue across the floor in front of the front door, and the rest of the floor free: room for 3 or 4 new displays before the first upgrade.)
- At most 100 floor items and 40 wall items, which keeps a full store's parts in check on phones (a full display is about 25 parts with its produce; streaming will load far farms whole, ArtDirection §10).

**The catalog** (`Config/Store`). Items are bought once with coins and kept ("My items"). Selling one back pays half. Free items (the starter kit and each new building's gift) can be put away but not sold.

| Displays | Size | Holds (slots × patches' worth) | Crops | Shoppers pay | Cost | Store Lv |
|---|---|---|---|---|---|---|
| Produce Crate | 1×1 | 1 × 12 (72 carrots) | Common–Uncommon | ×1.00 | 1,500 | 1 |
| Wooden Shelf | 2×1 | 2 × 15 | Common–Rare | ×1.00 | 6,000 | 1 |
| Bulk Bin | 1×1 | 1 × 40 | Common | ×0.95 | 9,000 | 3 |
| Tiered Produce Rack | 2×1 | 3 × 15 | Common–Rare | ×1.05 | 25,000 | 5 |
| Chiller Cabinet | 2×1 | 2 × 12 | Uncommon–Epic | ×1.10 | 80,000 | 8 |
| Glass Showcase | 1×1 | 1 × 4 | Rare–Mythic | ×1.15 | 250,000 | 10 |
| Velvet Pedestal | 1×1 | 1 × 1 (1 Moonmelon, 5 golden apples) | Legendary–Mythic | ×1.25 | 1,200,000 | 15 |

"Shoppers pay" is the display's presentation: it multiplies what shoppers are willing to pay for what's on it (§4.8 shoppers). A slot holds one crop, as many as its patches' worth of that crop (a Produce Crate: 72 carrots or 60 tomatoes; a Wooden Shelf slot: 90 carrots or 15 pumpkins). The drawer's card shows it with the first crop the display takes ("1×72🥕").

| Checkouts | Size | Serves | Needs | Cost | Store Lv |
|---|---|---|---|---|---|
| Shop Counter | 1×1 | you, holding the prompt (below), or a Cashier's speed (§4.9, never quicker than one every 4 s) | you or a Cashier | free (a second: 5,000) | 1 |
| Register | 2×1 | you, holding the prompt, or a Cashier's speed (never quicker than one every 3 s) | you or a Cashier | 30,000 | 3 |
| Self-checkout | 1×1 | a shopper every 4 s | nothing | 600,000 | 15 |

Checkouts allowed: 1 (Levels 1–2), 2 (from 3), 3 (from 10), 4 (from 15). Each has a queue of 4; a shopper who waits 20 s in the queue puts their basket back and leaves.

**Serving at your till** (the user, 2026-11-04: "There is no real checkout in the shop. Players will need to do the checkout job when customers pay before they can hire workers who does that for them."). The Shop Counter and the Register are **tills**: a shopper who reaches one waits there for whoever serves it, and rings its bell. If you're not in your store you get a note ("🛎️ A shopper is waiting at your counter!", at most every 25 s), and a 🛎️ "Serve me!" chalk sign bobs over the till on your screen until you're behind it. Behind the till (the Shop Counter's is the cell inside the staff door), a **prompt comes up on the counter** ("🧾 3 things · 540 coins / Check out"): **hold E** (or the sign, on a phone) to check them out, and a strip of till roll by the stamp shows what they're buying (the user, 2026-11-05: it was E twice on the stamp at the bottom right, hard to see; then, mid-check: "The check out prompt should appear at the checkout counter when the player is at the counter when a customer goes to the checkout to pay.": over the customer, Roblox hid it whenever they were off screen). It beeps as you start; when it's done the till's drawer pops open, the shopper says "Thanks!" and the coins come in. A shopper waits 30 s at an unserved till before putting the basket back ("Nobody at the till!"). **Shoppers never go behind a till**: the cells behind the Shop Counter and Registers are staff only, so no shopper walks, queues or stands there, and a display whose front would be there is refused in Decorate as out of shoppers' reach (`StoreLayout.staffOnly`; the user, mid-check: "Customers should not go behind the counter."). **Cashiers** take over from **Store Level 3** (one per till, §4.9): they serve at their own speed and you're free to farm. A Self-checkout (Store Level 15) serves itself. Until then your store only sells while you serve it, and while you're away it sells only through Cashiers. (Built: `StoreService` Serve action, client `CheckoutController`; the old Honour Box, which served itself, became a Shop Counter in every save.)

| Decor (Charm) | Size | Charm | Cost | Store Lv |
|---|---|---|---|---|
| Potted Plant · Hay Bale Seat | 1×1 | 2 | 2,000 · 4,000 | 1 |
| Flower Barrel | 1×1 | 3 | 5,000 | 2 |
| Pumpkin Pile | 1×1 | 3 | 8,000 | 3 |
| Painted Sign · Chalk Board · Clock (wall) | wall | 3 | 10,000 · 6,000 · 20,000 | 4 |
| Lamp Post · Rug | 1×1 | 4 · 3 | 15,000 · 12,000 | 5 |
| Fairy Lights (wall) · Fruit Cart (2×1) | | 5 · 6 | 30,000 · 50,000 | 6 |
| Bench (2×1) · Mural (wall, 2 wide) | | 4 · 8 | 25,000 · 200,000 | 9 |
| Fountain (2×2) | 2×2 | 12 | 400,000 | 10 |
| Flower Arch (2×1) · Neon Sign (wall) | | 10 · 8 | 300,000 · 250,000 | 12 |
| Golden Scarecrow statue | 1×1 | 20 | 2,500,000 | 17 |

**Charm** is your decor added up: each item's Charm, but a second copy of the same item counts half, a third a third and so on (so 10 Potted Plants are worth about 6, not 20: variety wins). **Every 10 Charm adds +0.1★ to your Store Rating, up to +1★ at 100 Charm.** Displays add a little Charm too (Tiered Rack 1, Showcase 2, Pedestal 4). Decor takes floor cells that could hold displays: that's the trade-off.

**Stock.** Your packed crates (§4.6) are what you put out: one stock with the trucks. The Store window's **Stock** tab lists them: how many crates of how many you can hold, then each kind with its amount. The store's **stockroom** (the back room) adds room for 6 crates at Level 1, +2 a level, 44 at Level 20. Putting goods out:
- **By hand:** press **E: Stock** at a display (a tap) and the **shelf panel** opens (since 2026-11-05, the user: "players should be able to press E to open a panel that shows all the produce they have unlocked, with options to fill that shelf with the selected produce or show out of stock"; client `ShelfController`): a seed-packet tab for each of the display's slots (none for a one-slot crate), then **Auto** and a card for every crop you've unlocked (its rarity's seed level, the one that gates planting) and anything else you hold, each with how many are in the stockroom and your price, and **FILL** (TOP UP for the one on the slot), **OUT OF STOCK**, or, greyed, the display that holds it ("Needs a Chiller Cabinet"). The card the slot is kept to has a gold edge. Picking one keeps the slot to it (what was on it goes back to the stockroom) and fills the display (`StoreAction` "Stock"; it tops up each slot from the stockroom, grade A first, emptying the smallest crates first so they free up room); a one-slot display's panel closes once filled, and walking away closes it. Or **Fill all** in the Store window while you're in your store. A slot is kept to a crop, or **Auto** (a crop the display can hold that isn't out anywhere yet, then the one with most waiting); the Store window's Stock tab changes it too.
- **Taking crops off:** with crops on a slot, the shelf panel's first card is **Take off** (the user, 2026-11-06: "Allow players to remove topped up crops on a shelf"; `ShopRules.takeOff`). They go back to your packed crates, grade A kept, and always fit, even past full. The slot then stays empty, Stockers and Fill all included, or a Stocker would only put them straight back, until you pick a crop or Auto for it. The Store window's Stock tab says **Left empty**.
- **Only crops your store can show go on a display:** the bench says "from Store Level 8" for an Epic until a Chiller Cabinet is unlocked. Its crates can go by truck meanwhile, so nothing gets stuck.
- **Stockers** (§4.9) refill any slot below half, the emptiest first.
- Putting a display away sends its goods back to the stockroom (even past full, like the barn), never lost.

**Prices** are as before: one price per crop for a standard unit (grade A ×1.15, mutations by their multiplier, shown on the tag), 50–300% of the reference `ref = ½ base + ½ market` (`shared/DemandModel`). The Store window shows what shoppers expect, what the truck pays now, the demand face (😀 🙂 😐 😟), the % that buy and about how many sell a minute. A crop going out for the first time is priced at the reference.

**Shoppers** (`shared/ShopRules`, `ShopService`; the clients draw them walking).
- **How often:** one every `20 × 0.92^(Level − 1)` seconds at 3★: 20 s at Level 1, 14 s at 5, 9 s at 10, 6 s at 15, 4 s at 20. Each star above 3 brings them 15% more often (each below, 15% less). **Variety:** each different crop on display after the first brings 5% more, up to +25%. A Greeter adds up to 25% more (§4.9); the Supermarket's billboard 15%.
- **What they want:** 1 crop at Levels 1–4, 1–2 at 5–9, 1–3 at 10–14, 2–3 at 15–20 (bigger stores, bigger baskets), each a crop on display (crops on more displays get picked more often).
- **How many at once** grows with the building: 8 in the Corner Store, 12 in the Farm Shop, 16 in the Market Hall and 24 in the Supermarket, counting those on the sidewalk (a full store makes the next one wait). A bigger store has longer aisles, so each visit takes longer (about a minute in a Supermarket); without more room the late levels' shoppers couldn't all fit. Each player's screen only draws shoppers within 300 studs, which keeps eight busy stores cheap on a phone.
- **The visit:** along the sidewalk and in through the door, along the aisles (the shortest path on the grid, cutting corners across open floor) to a display with each crop they want, standing in front of the slot that has it. There they roll a willingness `w` (log-normal, σ = 0.2) × the rating bonus (0 at 1★ to +25% at 5★) × the display's presentation, and take 1–4 patches' worth if `your price ≤ ref × w` (6–24 carrots, 1–4 pumpkins; grade A first, at ×1.15), saying so in a bubble: what they took, sometimes with what they thought of the price ("🥕×12 What a deal!" when it's far under what they'd pay, "🥕×12 A bit steep..." when it's close), or why not ("Too expensive!", "Yeah, nah. Too pricey.", "What a rip-off!" at over 1.6× what they'd pay, "Sold out? Gutted!"; plain lines and Kiwi slang mixed); a pleased bubble is green, a cross one red, and they keep facing the shelf until they walk off (Config/Shop `LINES`, 2026-11-05). Then to the shortest checkout queue, pay when they reach the till (a coin pop), and out. A shopper who gives up in the queue puts the basket back on the display. Nothing they wanted was affordable (or it sold out before they got there) → they leave without queueing.
- **Store Rating** (1–5★): the average of the last 50 shoppers' scores (5 bought · 2 too dear · 1 left the queue), a new store counting 10 shoppers at 3★ until real ones replace them, **plus Charm** (up to +1★), at most 5★. A store with nothing on display is closed: nobody comes to find it empty.
- **While you're away** shoppers keep coming at 25% (Self-checkouts serve on their own; tills need a Cashier; Stockers keep filling), worked out with the warehouse when you return (`shared/PipelineRules`, the Welcome back card).

**Store Levels** (the Store window's **Upgrade** tab: the same level ladder as the warehouse's). Every level opens floor, stockroom space or something new:

| Lv | Cost | Farm Lv | Floor | New at this level |
|---|---|---|---|---|
| 1 | free | 1 | 6×4 | **Corner Store**, starter kit, Shop Counter (you serve), stockroom 6, 8 shoppers at once |
| 2 | 3,000 | 1 | 7×4 | Stocker 1 · Flower Barrel |
| 3 | 9,000 | 3 | 7×5 | **Register** and **Cashiers** · 2 checkouts · Bulk Bin · Pumpkin Pile |
| 4 | 25,000 | 4 | 8×6 | the whole Corner Store · wall items: Painted Sign, Chalk Board, Clock |
| 5 | 60,000 | 5 | 9×7 | **Farm Shop** (+ a free Tiered Produce Rack) · 12 shoppers at once · Lamp Post · Rug · shoppers want 1–2 crops |
| 6 | 200,000 | 6 | 10×7 | Fairy Lights · Fruit Cart |
| 7 | 320,000 | 7 | 10×8 | |
| 8 | 480,000 | 8 | 11×8 | **Chiller Cabinet** (Epic crops) · Greeter · Stocker 2 |
| 9 | 700,000 | 10 | 11×9 | the whole Farm Shop · Bench · Mural |
| 10 | 1,100,000 | 12 | 12×10 | **Market Hall** (+ a free Glass Showcase) · 16 shoppers at once · Fountain · 3 checkouts · shoppers want 1–3 |
| 11 | 1,500,000 | 13 | 13×10 | |
| 12 | 2,000,000 | 14 | 14×10 | Flower Arch · Neon Sign |
| 13 | 2,600,000 | 16 | 14×11 | |
| 14 | 3,400,000 | 18 | 15×11 | the whole Market Hall · Stocker 3 |
| 15 | 4,800,000 | 20 | 16×12 | **Supermarket** (+ a free Self-checkout) · 24 shoppers at once · Velvet Pedestal · 4 checkouts · billboard (+15% shoppers) · shoppers want 2–3 |
| 16 | 6,600,000 | 22 | 17×12 | |
| 17 | 8,800,000 | 24 | 17×13 | Golden Scarecrow statue |
| 18 | 11,600,000 | 26 | 18×13 | |
| 19 | 15,200,000 | 28 | 19×13 | |
| 20 | 20,000,000 | 30 | 20×14 | the whole lot · a gold star on the sign and a Hall of Fame plaque |

Every level also brings shoppers a little more often (the formula above) and 2 more stockroom crates. The ladder costs about 79 million (Levels 6–20 doubled with the Field Levels, §4.1c), plus whatever you spend on decor. In the progression sim a daily player reaches Level 5 on day 2, 10 around day 9 and 15 around day 24.

- **The Store window** (a shop counter with price tags): a header with your store's name (Rename), its rating with Charm and **why** ("3 shoppers gave up in the queue: open another checkout"), and a big **Decorate** stamp; then **Prices** (above) · **Stock** (Fill all while you're in the store, the stockroom's crates, each display's slots with their fill and Auto or a crop) · **Upgrade** (the next level on blueprint paper: cost, Farm Level, what it brings, Upgrade; then the next few levels).
- **Epics need a Chiller (Level 8)** and Legendaries a Showcase (Level 10): until then those crops go by truck. The Store window says so on the Prices tab, which keeps the store a step behind the field on purpose: a reason to upgrade.
- The store is the slow, high-margin outlet; the truck is the fast, bulk one at the market price. When the market's down (▼) shoppers still expect the usual price, so the store pays better; when it's up, the truck does.

### 4.9 Workers
Hired at the **Hiring Hall** in town or from the Workers window (from Farm Level 2). Each worker is a visible NPC on your farm or in your store, walking set routes between stations, carrying crates and waving at visitors. **Every worker has a level, 1–10**: a new hire works at **40%** of the job's full speed, and a worker at Level 10 at **100%**.

| Worker | Where | What they do | Slots (from) | Full speed (Lv 10) | Full wage / min |
|---|---|---|---|---|---|
| **Farmhand** | Field | Harvest ripe crops, replant with the seed you chose (same seed · cheapest · don't replant). Skips tiles flagged 🚩 *Leave in field* (§4.2). Out of seeds → stops and shows "Out of Carrot seeds" on the Barn button | 1 per 16 open tiles (max 4) | 30 tiles | 105 |
| **Shed Hand** | Packing Shed (Warehouse Lv 1–4) | Sort + pack + load. Becomes a Packer (same level and XP) at Warehouse Level 5 | 1, 2 (WH 4) | 8 crates | 87.5 |
| **Sorter** | Wash & Sort | Grade batches: grade A chance 40% at Lv 1, +5% a level (85% at Lv 10; +5% more with the Wash Line) | 1–4 (WH 5, 8, 12, 18) | 60 patches' worth | 87.5 |
| **Packer** | Pack | Pack crates | 1–5 (WH 5, 6, 10, 13, 16) | 15 crates | 87.5 |
| **Loader** | Load | Move the crates routed to the truck onto the trucks | 1–3 (WH 5, 9, 15) | 20 crates | 87.5 |
| **Driver** | Truck | **Auto-dispatch** when the truck is full, or **only when the price is ≥ X% of base** (your rule). Their level shaves up to 10% off the round trip. The first Driver drives truck 1, the second truck 2 ... | 1 per truck (WH 5) | – | 140 |
| **Stocker** | Store | Refill displays with the crates routed to the store, the emptiest first | 1–3 (Store 2, 8, 14) | 80 patches' worth | 87.5 |
| **Cashier** | A till (Shop Counter or Register) | Serve the queue, so you don't have to; with no one at their own till, walk to one with a shopper waiting | 1 per till, from Store Level 3 | 12 shoppers | 105 |
| **Greeter** | Store door | Welcome shoppers in: up to +25% shoppers (× their efficiency) | 1 (Store 8) | – | 87.5 |
| **Watchman** | Gatehouse (Farm Lv 20) | Rings the bell and shines a spotlight on the thief when the alarm goes off. **Once the thief has the crop** he shuts the gate on them (10 s at Lv 1 up to 20 s at Lv 10; once per theft, so it never shuts again unless they steal again; they have to climb out; everyone else, and a Suspect with empty hands, still walks through). **Never knocks anyone out**. He stands at his gatehouse's window by the gate (it goes up when you hire him) and learns while he's on watch. *Built with the defences in week 6* | 1 (Farm Lv 20) | – | 175 |

**Levels and efficiency.**
- **Efficiency** = 40% at Level 1, +6.7% a level, 100% at Level 10. Speed = the full speed × efficiency. Wages grow slower than skill: 60% of the full wage at Level 1 up to 100% at Level 10, so a levelled worker is quicker *and* cheaper per job (a new hire costs 1.5× as much per crate as a Level 10).
- **Experience:** workers earn XP by working: 10 XP a minute of real work (shown as a bar on their badge), 2.5 a minute while you're away. An idle worker (nothing to do) learns nothing, and XP only counts real work (a crate moves on, a shopper is served).
- **Training:** when the bar is full (it stops there: XP doesn't pile up past a level), the badge says **Ready to train**, and **Train** (coins) takes them up a level. XP needed: 600 × 1.5^(Level − 1) (an hour of work for Level 2, about 26 hours for Level 10; about 75 hours in all). Fee: 2,500 × (full wage ÷ 87.5) × 1.9^(Level − 1) (2,500 coins for Level 2, about 420,000 for Level 10; about 890,000 in all for a typical worker). So levelling takes both time and coins, and a full crew is a long-term goal: in the progression sim a daily player's workers average Level 6 by day 14 and 7 by day 28, the first hires Level 8 (offline they only learn while crates really move, so the slowest station sets the pace); a keen player's reach 9 by day 28. A first hire is ready to train after an hour of work, in the first session.
- **Hiring:** the board shows 3 candidates per type, changing every 10 min (each player's own board, the same all through the 10 minutes, so nothing about it is saved but who you took). Each has a level (1–3), a trait (**Speedy** +20% speed · **Careful** +10% grade A · **Night Owl** +30% at night · **Frugal** −20% wage) and a hire fee (40 minutes of their wage). Your first hire is free, at any Farm Level (the Guide's "First one's on the house!"); after that, hiring needs Farm Level 2. A Sorter's grade A chance stops at 95%.
- **Rare workers** come from auction contracts at Level 6–8 with a trait the hiring board never offers (`Config/Workers.CONTRACTS`): *Grandma Rose, Legendary Packer* (Level 8, **Tireless**: works at 50% instead of 25% while you're away) and *Speedy Sam, Rare Farmhand* (Level 7, Speedy). They join your crew if you have a free slot for their job (you can't bid without one). **Night Owls** get their +30% at night (from week 7).
- **Wages** come out of your coins every minute (a coin sink: under 10% of income on any day in the progression sim). If you can't pay, workers **go on strike** (sitting on crates with signs) until you can.
- **Slots** limit how many of each worker you can have; they open with Warehouse and Store Levels. The Workers window shows each station's slots (e.g. Packer 2/3), and greyed slots say what opens them ("Warehouse Level 10").
- **The Workers window** (👷 on the side bar; the Hiring Hall's job board in town opens it on the Hire tab) is a corkboard of ID badges: photo, name, type, level and efficiency (e.g. "Lv 4 · 60%"), the XP bar, the trait, the wage, **Train** when ready, and Let go (tap twice); the Farmhands' replanting at the top. The Drivers' rule is in the Warehouse window, by the trucks.
- **On the farm** each worker is a blocky NPC in their job's outfit with a name-and-level tag, busy at their station; Farmhands walk from crop to crop, nearest first, the crop coming up as they reach it (2026-11-05, the user: "sometimes he harvests even though he's not on the plot and he teleports"), and back to their post after 4 s with nothing to do; Shed Hands and Loaders carry each crate out through the dock door, the crate showing on the truck as they reach it, and a Driver waits for the last one; Stockers carry crates along the aisles from display to display, each to a different one, and the stock goes on as they get there; workers at a station stand 3.4 studs apart (2026-11-05, the user: "make sure all other workers are functioning properly, this includes visually too", "The workers are going through the wall"), Loaders carry crates to the trucks, Drivers wait by their truck and go with it. On strike they sit on a crate holding a sign. **A Farmhand's pace goes with their level** (the user, 2026-11-05: "they can outrun someone trying to steal a crop", "increase the speed ... by their levels", "at max, they can outpace a running thief"; `WorkerRules.walkSpeed`): 8 studs a second at Level 1, slower than a thief with their hands full, +2 a level, so Level 5 matches a player walking (16), Level 9 one running (24) and Level 10 beats them (26). They no longer hurry to keep up their crops a minute, so a long walk takes as long as it takes. Training a Farmhand is a defence in its own right.
- **Offline:** workers keep going at **25% speed for up to 8 hours**, paid at 25% wages (a strike starts when the coins run out and ends when a sale brings some in). `shared/PipelineRules.simulate(state, seconds, rate)` runs the whole chain (Farmhands harvest and replant using offline growth → stations → trucks at the deterministic market price with supply = 1 → Stockers and store sales at 25% shopper flow). It's worked out in one go when you return (`WorkerService`; offline growth moved there from the field so crops never grow twice) and shown on the **Welcome back** card: time away, crops harvested, crates packed, trucks sent and coins (and still on the road), store sales, wages, any strike, and who's ready to train. Workers learn from what they did (2.5 XP a minute of it).
- Workers can't be hit, stolen or traded.

### 4.10 Stealing
- **What can be stolen:** only **ripe crops in someone else's field**. Never the barn inventory, crates, trucks or shelves. For regrowing plants only the fruit is taken.
- **How:** walk up to a ripe crop and **hold [E] Steal** (1 s Common up to 7 s Mythic, ×1.4 under a cloche, −25% on a Harvest Moon). A progress ring shows over the crop for everyone. The crop shakes and rustles.
- **The moment the hold starts:** the thief becomes a **Suspect** (§4.12) and the owner gets the **theft alarm** (§5.4).
- **Races:** if two thieves hold the same crop, the first to finish gets it and the other's hold is cancelled. If the owner (or a Trusted friend or Farmhand) harvests it mid-hold, the hold is cancelled and the thief is still a Suspect. Harvesting fast is the owner's quickest counter.
- **You carry what you steal in your hands, held up over your head** (the user, 2026-11-02: "farmers will be able to tell instantly by looking at the crop"). A steal takes **the whole patch** (6 carrots, a basket of 6 tomatoes, 4 punnets of strawberries), but the big ones **one at a time**: you can carry one pumpkin or melon, so a bumper patch's second stays ripe for the owner (or the next thief). It's what you'd carry out of a field (`World/ProduceArt`): carrots or corn tied in a bunch, onions on a string, sheaves of wheat tied together, potatoes in a little crate, lettuces in a shallow one, punnets on a tray, tomatoes, peppers, cocoa pods, dragonfruit, grapes, starfruit or golden apples in a basket, pineapples side by side, a whole pumpkin or melon; Rare crops and up sparkle in their rarity's colour. Both hands are on it (`client/PoseController`), so **one patch at a time**: stealing another says **HANDS FULL** until you've taken it home. The STEAL stamp says how many you'd get ("🥕 ×6"); the sign over your hotbar, what you're carrying ("🥕 6 carrots · Get home!"). Everyone walks at 16 studs/s and sprints at 24 (Shift / the Run button). Carrying a stolen crop you walk **15% slower** (13.6), can't sprint, can't use any teleport (Home, Town, Visit), can't hold a bat, and your name tag turns red with the crop's icon. **Off farmland you can run** (the user, 2026-11-05: "Allow running after leaving the victims land because no one can stop the thief anyways at that point"; `LootRules.slowed`): the crop only slows you on a farm, the one you stole from or any other you cross, where a bat can reach you. The raid race (below) is untouched: it ends at the fence.
- **Getting away:** leave the plot (through the gate, or over the back fence: press **Climb** next to it and you're lifted up and over in 1.5 s, the crop still held up; 3 s out over a Tall Back Fence) and the owner's bat can't reach you. Walk home: the crop goes into your barn as soon as you're back in your own farm.
- **Limits that keep it fair** (`Config/Crime.luau`):
  - **Sprout Shield** (first 45 min of play, §4.0) and **arrival grace** (1 min after joining).
  - **Same-farm cooldown:** after leaving a farm with loot, or being arrested there, you can't steal from that farm for 3 minutes.
  - **Raid cap:** a farm loses at most **10 raid weight per 10 minutes** to all thieves together (Common/Uncommon 1, Rare 2, Epic 3, Legendary/Mythic 5). After that it gets a *Neighbourhood Watch* dome for the rest of the window.
  - Sprout Shield and arrival grace work both ways: while you're protected you can't steal.
  - **Offline players can't be robbed:** their plot isn't in the server.
  - Trusted players can't steal from you.
- Farmhands harvesting quickly is a defence too: crops that aren't in the field can't be taken.

### 4.11 Defending your farm
The owner's main tool is the **bat** (§4.12). Everything else **slows, warns or exposes**. Nothing blocks a thief completely, so raids stay possible.

| Defence | Cost · level | Effect |
|---|---|---|
| **Bat** | free | Only while you're inside your own farm. Bonk → 5 s knockout |
| **Gate Lock** | 80,000 · Lv 8 | Only Trusted players can walk in. Anyone else has to climb the gate (2 s), which makes them a Suspect. A **"Private farm"** sign says so, and the first time someone starts climbing in they get a confirm ("Climbing in counts as trespassing"). Walking *out* is always free |
| **Tall Back Fence** | 300,000 · Lv 12 | Climbing **out with a stolen crop** takes 3 s instead of 1.5 s (in, or out empty-handed, is no slower) |
| **Scarecrow** | 25,000 · Lv 5 | Early warning: "Someone is near your crops" when a non-Trusted player comes within 25 studs of the field |
| **Floodlights** | 120,000 · Lv 10 | Four lamps on posts just off the field's corners, lit at night. At night anyone in your farm who isn't Trusted gets a red outline on your screen, and name tags on your farm show from afar, like by day (without them, name tags only show within 20 studs after dark) |
| **Guard Dog** | 600,000 · Lv 16 | Lives in a kennel by the field. It sounds the alert, with a gold **!** over its head, when someone starts stealing within 30 studs, then **runs at the thief once they have the crop**, who is **slowed 30% for 2 s** (once per 20 s). It never stops them |
| **Glass Cloche** | 30,000 each · Lv 14 | Covers one tile (up to 16): stealing from it takes 40% longer |
| **Security Camera** | 800,000 · Lv 22 | The alarm shows a live picture-in-picture of the thief, even when you're away. Adds the Farm Log's visitor list |
| **Mud Patch** | 200,000 each · Lv 24 | A 12 × 12-stud patch (up to 4) that slows anyone but you and your Trusted friends 20% |
| **Watchman** | worker · Lv 20 | See §4.9 |

- **When they open** (changed 2026-11-02, §10): one at a time from Farm Level 5 to 24, about 3 million coins for the lot, so a daily player has them all around day 13 and a farm is never sealed while it's new. Each one's level and price are in `Config/Defences`.

- **Where they go** (week 6, §10): the scarecrow, the kennel and mud patches each take one of 26 **yard spots**, 12 studs square, in a ring 3 studs off the field (its sides and the strip behind it by the back fence). Cloches go over open tiles. The Gate Lock, the Tall Back Fence and the camera (on the barn's back corner) have their own place and go up as you buy them; anything can be put away and set out again. The dog runs at thefts within 30 studs of its kennel, so a kennel behind the field covers the back rows.

- **The raid race (a worked example, from the real layout: `lune run tools/raidrace`).** A thief takes a Rare Pumpkin from the back row (24 studs from the back fence) and runs back over the fence with it. They come in over the back fence (the alarm goes off as they start climbing) or, with no Gate Lock, walk in through the gate (no alarm until they start stealing), whichever leaves the owner less time. The owner reacts in 1 s (watching) or 2.5 s (busy), then sprints from the farmhouse door, the warehouse, or town (Home's 3 s, then the door), and needs to be within bat reach (7 studs) before the thief is over the fence (someone climbing out still counts as inside). The thief's lead in seconds (+ escapes, − caught):

  | Defences | Door | Warehouse | Town | Busy owner: door / warehouse / town |
  |---|---|---|---|---|
  | None (in through the gate) | +1.6 | +2.5 | +1.6 | +3.1 / +4.0 / +3.1 |
  | Gate Lock (Lv 8) | −0.8 | +0.1 | −0.8 | +0.7 / +1.6 / +0.7 |
  | + Tall Back Fence (Lv 12) | −2.3 | −1.4 | −2.3 | −0.8 / +0.1 / −0.8 |
  | + a cloche on that crop (Lv 14) | −3.3 | −2.4 | −3.3 | −1.8 / −0.9 / −1.8 |
  | + the guard dog (Lv 16) | −3.8 | −2.9 | −3.8 | −2.3 / −1.4 / −2.3 |
  | + mud on the way out (Lv 24) | −4.2 | −3.4 | −4.2 | −2.7 / −1.9 / −2.7 |

  (Since 2026-11-05 Home is instant, except during a raid, when it takes 3 s: so the balance below still holds. See §10.)

  With everything: climb in 1.5 s + run in 1.0 + steal 3.5 + run out 2.6 (slowed) + climb out 3.0 = over the fence 11.6 s after the alarm. So with no defences a quick thief beats anyone who isn't at the field. Fully defended, the farmer is favoured (the user: "favour the farmers slightly more than a thief overall but if a farmer is slow then a thief should be able to run away with the crop"): a watching farmer catches the thief even from town, by about a second; a busy one in town loses them; a busy one at home still catches them. Defences and the scarecrow's early warning buy the seconds; they don't block. This is what the numbers are tuned around, and `tests/layout.test.luau` fails if a change breaks it.
- **Why thieves leave over the back fence, not through the gate** (checked 2026-11-03, kept as it is, §10). Carrying a crop (13.6 studs/s, no sprinting), the time out of the farm from the middle of the field:

  | Column | Back fence (1.5 s climb) | Tall Back Fence (3 s) | Front gate | Gate shut by the Watchman (+2 s climb) |
  |---|---|---|---|---|
  | 1 (front, by the house) | 9.3 | 10.8 | 10.6 | 12.6 |
  | 4 (a new farm's back edge) | 6.6 | 8.1 | 13.2 | 15.2 |
  | 8 (back) | 3.1 | 4.6 | 16.8 | 18.8 |

  The two would only take the same time from in front of the field (with the Tall Back Fence, the front column is about even), and crops on the warehouse side are further from the gate still; going out the front also means walking towards the farmhouse door and the warehouse, where the farmer usually is. On an undefended farm (in through the open gate, out the back) a Rare's thief escapes a sharp farmer from the back row (+1.6 / +2.5 / +4.6 s, door / warehouse / town), is caught from the farmhouse door or the warehouse at a new farm's back edge (−1.9 / −1.0, escaping only from town, +1.1), and is caught from the front row everywhere (−4.5 / −3.6 / −1.5).

  Kept on purpose: one predictable exit favours the farmer (they know where to run); the Tall Back Fence, the dog behind the field and mud all have a clear job; and the field has a risk gradient, so where you plant rare crops and which blocks you open next are real choices (the start blocks by the house are hard to rob, the back blocks are where raids happen). Making the gate a match would mean slowing the back or speeding up the front, handing thieves a second route to cover. Two side effects: the Watchman's gate shut is a backstop for thieves who try the front (his bell and spotlight are his worth; looked at again with night in week 7), and a front-row Mythic can't really be stolen from a farmer who's online and watching (thieves go for back rows and away farmers).
- **Travel buttons** (instant since 2026-11-05, the user: "Remove the wait on the teleport, make it instant."; done by the server through `MovementService.Teleport`). **The one wait:** Home takes **3 s while a thief is on your farm** (a Suspect inside it or climbing in; a bar says "Thief on your farm! Heading home..."; you can move while it runs; the user: "wait if being raided"). Fully instant, a slow farmer in town caught everyone, which broke the rule that a slow farmer can lose the thief. **No cooldowns** (changed 2026-11-02, §10): what stops travel being an escape is that it's off for raiders. A cooldown only got in an owner's way, rushing home twice.
  - **Home** → your farmhouse door. Also on the theft alarm.
  - **Town** → the town square. Also on the "auction starting" toast.
  - **Visit** → the sidewalk outside any farm's gate (from the player list).
  - All of them are off while you're a Suspect, knocked out or carrying a stolen crop (the signs show 🚫). A thief stays a Suspect 60 s after their last suspicious act, which already does a cooldown's job for them, but reaching your own farm frees you to travel at once (the user, 2026-11-05: you've got away; `CrimeRules.holdsTravel`). The mark itself stays: walk back into that farm within the 60 s and you're a Suspect there.

### 4.12 Bat, knockout and arrest
**The bat**
- It appears in hotbar slot 1 **the moment you step inside your own farm** and disappears when you step out (the server adds and removes the Tool, checked 4× a second from your trusted position), or while your hands are full (a stolen crop, a crate). The server ignores a hit from a bat it didn't give you.
- **How it's held:** in your right hand by the taped grip, the bat leaning back over your right shoulder, ready.
- **Swing:** tap or click (the context button says **Swing** when a Suspect or someone carrying a stolen crop is within 10 studs, or anyone once the bat is in your hand). A swing turns you to face the nearest person in reach, lifts the bat back behind your head, brings it over the top and **level out in front** (the hit, 0.22 s in), on down across to your left, and back to your shoulder (0.75 s in all). Everyone sees it: yours plays the moment you press, others' when the server hears of the swing (the character's `SwingAt`). 0.8 s cooldown, on the server.
- **A hit counts only if** (`shared/CrimeRules.validHit`): the attacker owns the plot and is inside it · the target is inside the same plot · within 7 studs (+1 for lag) using trusted positions · inside a 100° arc in front of the attacker (or within 3 studs, where a swing reaches round you) · a clear line between them · the target isn't Trusted and isn't immune.

**Knockout (anyone).** A bat hit on **any** non-owner inside your farm knocks them out for **5 seconds**, but only Suspects can be arrested (below). Dizzy stars, the character flops over, "BONK!". The server anchors them and takes network ownership of their character, so exploits can't move them. If they were carrying a stolen crop, it **drops on the ground** past their head, for anyone to pick up (below). A knockout also cancels any trade, steal or pick-up hold in progress.

**A dropped crop** (the user, 2026-11-02: "the crop drops on the ground for anyone to pick up when you bonk the thief"; "farmers should hold take back too like anyone else"). It lies where it fell (inside the farm, this side of any wall) with a **"Dropped! 🎃 ×1"** label and a bar running down 30 s. Standing within 6 studs, the context stamp says what you can do; both are **1.5 s holds**, and if two people hold at once the first to finish gets it, like a steal race:
- **TAKE BACK** (green) for the crop's owner, the owner of the farm it lies in, and anyone either of them trusts: it goes into the crop's owner's barn ("Taken back: 🎃 1 pumpkin"), or, if that owner has left the server, the farm owner's.
- **GRAB** (red) for anyone else, the thief who dropped it too once they wake: like a steal (inside the farm, awake, not protected, empty hands, not on that farm's cooldown), it makes you a Suspect and sets off the alarm ("🚨 Sam is grabbing the dropped 🎃 Pumpkin!"); finished, the crop is in your hands as stolen loot, the dog runs and the Watchman shuts the gate as for a steal. It doesn't count against the raid cap again.
- **Nobody picks it up in 30 s:** it goes back to its owner's barn by itself (or the farm owner's). If its owner or the farm's owner leaves the server, it goes back at once.
- An arrest still fines for what they had when they were bonked, wherever the crop is now. So the farmer has the knockout's 5 s to arrest (1 s) and take it back (1.5 s); a farmer who stands and watches can lose it to a second thief, or to the first one waking up.
- While the thief who just woke up is immune (6 s), the farmer's stamp offers TAKE BACK before SWING (a bonk would only nudge them), and a pick-up hold keeps the stamp until it's done (play-test 2026-11-02).
- After waking: **6 s of knockout immunity** (a hit only nudges them), so nobody can be stun-locked.
- A knocked-out visitor who isn't a Suspect sees **"You're just stunned. You did nothing wrong."** and a **Leave farm** button that puts them on the sidewalk outside when they wake. Knocking out innocent visitors pays the owner nothing.

**Suspect.** You become a Suspect *of that farm* when you:
- start a steal hold,
- carry a stolen crop inside it (even one from another farm: being caught with stolen goods counts),
- climb *in* over its back fence or locked gate. Climbing *out* never makes anyone a Suspect.

It lasts while you're inside that farm and for 60 s after your last suspicious act (so popping out and back in doesn't clear it). Suspects show a red **!** to the owner.

**Arrest (Suspects only).** While a Suspect is knocked out, the owner sees **[E] Arrest** (hold 1 s, within 8 studs). Then:
1. The thief sees the **BUSTED!** mugshot card (2.5 s: their avatar in front of a height chart holding a number board, the charge, the fine and who it's paid to).
2. The thief is teleported to the **Police Station porch**.
3. The owner gets the compensation, a siren-and-cash sound, and +1 on the Sheriff board.
4. If the owner doesn't arrest within the 5 s, the thief wakes up (the crop already returned) with their 6 s of immunity.

**The fine (compensation)** (`shared/FineRules.luau`)
- `fine = max(floor, 8% × the thief's earnings in the last 60 min) × repeatMultiplier`
- `floor = max(250, 1.5 × the market value of the loot)` (the crop in their hands, plus the one they were halfway through stealing).
- Why 1.5×: with the loot returned and a 1.5× floor, a raid on a defended farm roughly breaks even at a ~40% arrest rate (`0.6 × loot − 0.4 × 1.5 × loot = 0`). Raiding an unwatched farm pays; raiding a guarded one doesn't. For rich thieves the 8% term is bigger, so they lose a lot for stealing carrots from small farms.
- `repeatMultiplier` = 1 for the first arrest in 30 min, 1.5 for the second, 2 for the third and after.
- **Earnings** means sales income (truck and shop), kept as 12 five-minute buckets in the save. Trades and refunds don't count here (for collecting debt, auction refunds do; see Debt).
- **Paid from the thief's wallet. Whatever's missing becomes debt** (below). **The owner gets exactly what's collected**, so no coins are created from nothing.

**Debt.** Unpaid fines are owed to that owner. **50% of the thief's future sales income** goes to their debts (oldest first) until they're paid. The thief can also pay early at the police desk. Payments reach the owner straight away if they're in the same server; otherwise they go into the owner's **payout queue** (DataStore `Payouts_v1`, key `Owner_<userId>`; each record has an id so it's only ever claimed once), delivered when they next join or via MessagingService to their server. Payments are batched per debtor and owner (at most one payout record every 5 minutes), which keeps DataStore writes low. Debt older than 7 days is forgiven. Players in debt can't put coins into trades. Auction refunds count as income, so coins parked in a bid still pay the debt.

**Stopping people dodging an arrest** (`CrimeService`, tests in `tests/crime.test.luau`):

| Bypass attempt | Counter |
|---|---|
| **Leaving the game while knocked out** (quit, crash, Alt+F4, joining a friend) as a Suspect | `PlayerRemoving` → **automatic arrest**: the fine ×1.5 ("Fled arrest"), the loot back to the owner, applied *before* the profile session ends. Next join within 2 min starts on the police porch with a "You fled arrest" note |
| **Leaving while being chased** (a Suspect carrying a stolen crop, the owner within 30 studs or swung at them in the last 10 s) | Treated the same: the fine ×1.5, the loot back. Leaving *without* a chase just returns the loot, no fine (it could be a real disconnect) |
| Leaving while carrying loot (no chase) | The crop goes back to the owner. Loot never saves to the thief until it's deposited |
| Bonked, waking up and grabbing the crop you dropped | Allowed, as a fresh theft: a Suspect again, the alarm, the dog and the Watchman. The farmer had the 5 s knockout to arrest you or take it back |
| Leaving the game while a crop you dropped lies there | It isn't yours any more: it waits for its 30 s (or its owner or the farm's owner leaving), then goes back |
| Leaving while knocked out but **not** a Suspect | Nothing happens (they did nothing wrong) |
| **Resetting the character** | The reset button is off while you're a Suspect, knocked out or carrying a stolen crop (`ResetButtonCallback = false`). If the character dies or is removed while knocked out → automatic arrest |
| Teleporting away (Home, Town, Visit) | All game teleports are off while knocked out, a Suspect or carrying a stolen crop |
| Exploit-moving while knocked out | The server anchors them and owns the character's network |
| Speed or teleport exploits to steal or escape | Trusted positions (`MovementService`, the Tide Market pattern). Every distance and zone check uses them. Just after a server teleport, a climb or a knockout a move from too far off is ignored, never trusted: you walk on from where the server put you |
| Walking or flying through fences, hedges, the store's walls or the staff door | A step across a farm's edge anywhere but the gateway is sent back (`PlotLayout.wallCrossing`), at any height; the staff door lets through only the owner and Trusted friends. Only the server's climbs go over |
| Hovering over a farm, out of the bat's reach | More than 1.5 s over 14 studs above what's under you sends you back down (`MoveRules.hovering`), and a crop can only be taken from within 11 studs above it (`CrimeRules.inReach`) |
| Dying, moving the body and stealing with it | A dead character has no position, so nothing is in reach (`MovementService.positionOf`) |
| Faking "steal finished" or "deposit" | The server times every hold (start → finish ≥ the hold time, still in range, the crop still ripe, empty hands) and checks you're in your own farm (the server's zone) |
| Faking bat hits or arrests | `validHit` above. Arrests need the target knocked out, a Suspect, and within 8 studs |
| Spending everything before a raid | The fine comes from earnings, not the wallet. Unpaid fines become debt |
| Giving coins away to dodge debt | No coins in trades while in debt; debt is collected from income |
| An alt account getting arrested on purpose to farm fines | The owner only receives what's collected, so an empty alt pays nothing |
| Luring people in to arrest them | Only Suspects can be arrested. Innocent visitors can be knocked out but pay nothing |
| Friends staging arrests to farm the Sheriff board or arrest XP | Only arrests with loot worth ≥ 500 coins count, and at most 3 per thief–owner pair per day |
| Juggling a thief's coins through the auction (bid, get outbid) to dodge a fine | Refunds count as income for debt (above) |
| Stun-locking a visitor | 6 s immunity after each knockout and a Leave farm button |
| Standing on the plot edge | Zone check with 1 stud of hysteresis. Someone climbing *in* counts as inside from the start of the climb; someone climbing *out* counts as inside until they're over |
| Server shutdown (an update or a crash) | No penalties during `BindToClose`; loot goes back to owners |

### 4.13 Trading
- **In person:** within 20 studs (`TradeRules.NEAR_DISTANCE`), and walking more than 40 apart cancels it. The **Trade** button lists nearby players; or press **T** next to someone.
- **A structured UI** (no chat needed): each side offers up to **8 stacks** (crops, seeds, auction items) and coins. Both press **Ready** → a **5 s countdown** (any change resets it) → both **Confirm** → an **atomic swap** (all or nothing), saved straight away.
- **Safety:** unlocks after **1 h of play**. Both sides see the market value of every stack and each side's total, with a red warning when you'd give 3× or more what you get. Every trade is logged (`TradeLog_v1`) and staff can roll one back (`/trades`, `/rollback`, the Tide Market pattern).
- **Not tradeable:** anything bought with Robux, workers, Land Permits, defences (decided in week 8: a defence won at the auction goes onto your farm like a bought one, and each farm's maximum and Farm Levels would make trading them muddled; seeds won at the auction trade like any seeds), a stolen crop not yet taken home, coins while in debt, and store items bought with coins (selling back pays half; trading them would undercut that). Decor won at the auction can be traded once it's put away (when cosmetic lots come).
- **The receiver's barn** must have room for the crops coming in (deposits and returned loot ignore the barn's size, but nothing makes you take a trade).
- ProfileStore session locking, so server hopping can't duplicate items.

### 4.14 Weather, day and night, events
The same in every server, worked out from the time (`Config/Weather`, `shared/WeatherRules`, like Barley's restocks). A 24-minute day (16 min of daylight, 06:00 to 18:00 on the sky's clock, then 8 min of night). The weather can change every **4-minute slot** (6 a day: 4 by day, 2 by night), rolled from the slot's number: a Frost Night fills a night slot, Golden Hour the last 3 minutes before sunset, Rain a whole slot and a Thunderstorm 3 minutes of one. Measured over 3,000 days (`lune run tools/weathershares`): Clear 55%, Rain 21%, Thunderstorm 9%, Frost Night 7%, Golden Hour 7%, Harvest Moon 1%.

| Weather | Share · length | Growth | Mutation on ripe crops left in the field (chance per 30 s roll) | Look |
|---|---|---|---|---|
| Clear | 55% | ×1 | any weather: **Golden** ×2 (0.5%), **Rainbow** ×8 (0.05%) | sunny |
| Rain | 20% · 4 min | ×1.5 | **Wet** ×1.3 (3%) | rain, puddles, rainbow afterwards |
| Thunderstorm | 8% · 3 min | ×1.5 | **Shocked** ×3 (1.5%) | lightning, sparks on the crops |
| Frost Night | 7% · 4 min (night only) | ×0.75 | **Frosted** ×2.5 (2%) | frost on the ground, breath puffs |
| Golden Hour | 7% · 3 min (dusk) | ×1 | **Golden** ×2 (5%, ten times the usual) | low orange sun, gold dust |
| **Harvest Moon** | scheduled 3× a day · 6 min | ×2 | **Moonlit** ×5 (2%) | a huge orange moon; **Heist Night**: steal holds −25% |

- **How mutations work:** every 30 s, each ripe crop still in the field rolls the current weather's mutation and the any-weather ones. A crop holds one mutation at a time, and **one already mutated keeps rolling: it takes a new mutation only if it's worth more** (a Wet crop left out into a Thunderstorm can turn Shocked, then Moonlit under a Harvest Moon; it never goes back down). Growing crops and crops in the barn never roll. Roughly: a crop left out through a whole Rain has a 1 in 5 chance of Wet; through a Harvest Moon, about 1 in 5 of Moonlit. Mutated crops get a coloured aura, **which thieves can see too**. That's the core gamble: leave it out for a mutation, or harvest it safe.
- **Night:** players' name tags only show within 20 studs (sneakier raids). Floodlights cancel that on your farm. The farmhouse windows and porch lantern light up (a farm nobody has stays dark).
- **Harvest Moon** at 01:00, 12:00 and 19:00 UTC with a 5-minute warning. The sky turns to night for it, whatever the time of day. Big growth, the best mutation, and the most raids. Appointment play.
- **Rain** falls as blue-grey streaks round the camera (none under a roof); a mutated crop has a soft haze of its colour rising off it, as well as motes and a light, so it stands out from ripe sparkles.
- **On screen** (`SkyController`): a **sky dial** hangs left of the purse: the weather's icon (a moon on a clear night), the clock under it (in the 5 minutes before a Harvest Moon, its countdown in gold), and a badge with what it does to growth (×1.5 green, ×0.75 blue) while that isn't ×1. Tap it for what the weather does, how long it has left, when night falls and when the next Harvest Moon is. A note says what each new weather does as it comes, and one goes up 5 minutes before a Harvest Moon. Once a ripe crop mutates, its owner gets a note and its tile line says "✨ 6 Wet carrots · worth ×1.3!". Ripe times on tiles count down at the weather's speed.

### 4.15 Progression
- **Farm Level 1–50** from XP (`Config/Progression`, `shared/ProgressionRules`). Total XP for level L = 60 × (L − 1)^2.65, so Lv 2 is 60 XP and Lv 32 about 537,000. XP comes only from playing; **nothing earns XP while you're offline**:
  - **Harvesting:** XP per minute the crop grew (3 a minute for Commons up to 5.5 for Mythics), so slow crops aren't worse for XP than Carrots. A Farmhand's pick while you're online gives half.
  - **Selling** (truck or shop, while online): 1 XP per 500 coins.
  - **Arrests:** +50 (only arrests that count for the Sheriff board). **Cropdex:** +25 per new entry.
  - The progression sim (`lune run tools/progression`) plays the game with the real rules. A daily player (1.5 h a day) reaches Lv 12 on day 3 and Lv 32 (the full 8×8) on day 23; a casual player (45 min) has 11 of 12 permits by day 35; a keen one (3 h) finishes the land on day 12. It unlocks seed tiers in Barley's shop (Uncommon Lv 2 · Rare Lv 5 · Epic Lv 10 · Legendary Lv 16 · planting Mythics Lv 20), **Land Permits** (12, from Lv 2 to Lv 32, §4.1b), buildings, defences and worker types.
- **Upgrades:** clearing land, the Silo, Warehouse Levels and Store Levels (1–20 each), store decor, truck paint, defences, worker training (Levels 1–10).
- **Cropdex** (`shared/QuestRules`, the Quests window's Cropdex tab): every crop, plain and with each mutation (22 × 7 = 154 entries), recorded when it reaches your barn (picked, a Farmhand's, a stolen one taken home). A new entry is +25 XP. Every crop of a rarity found pays coins (Common 2,000 up to Mythic 2M) and one seed of the next rarity's cheapest crop (a Legendary set gives a Mythic seed). Every crop with one mutation is a badge and 100,000 coins. Giant records come with Giants.
- **Leaderboards** (OrderedDataStores, weekly and all-time; boards at the police station and the Exchange):
  - **Net Worth**: coins + the value of inventory and buildings
  - **Sheriff**: arrests made this week (only arrests with loot worth ≥ 500, at most 3 per thief–owner pair per day; the same rule applies to arrest XP)
  - **Most Wanted**: crop value stolen this week (a cartoon wanted poster of #1)
  - **Top Store**: the best Store Rating with at least 200 shoppers this week
- **Server announcements:** a Mythic ripening ("✨ A Crystal Rose just ripened on Alex's farm!": the owner gets a private 60 s warning first), a Mythic harvested, a Giant crop, an arrest of the server's Most Wanted.

### 4.16 Quests, streaks and the Farm Log
- **3 daily quests** from a pool (harvest N, ship N crates, earn N in your shop, make an arrest, get a mutation, win an auction lot, deposit stolen crops), 2,000–10,000 coins each, plus a bonus for all three (10,000). New at midnight UTC, the same all day on any server (`Config/Quests`, `shared/QuestRules`, `QuestService`). They grow with your Farm Level: from Level 8 the targets are bigger and the coins ×4, from Level 20 ×15, so they still matter late. Raid quests only come once your Sprout Shield is over, the auction one from Farm Level 8; arrests count only if they'd count for the Sheriff board. Claimed in the **Quests** window (a side bar crate with a green ! while something is waiting).
- **7-day login streak** with seeds, coins and a decoration on day 7, claimed when you join (a note says what you got): 2,000 coins · 3 Corn seeds · 5,000 · a Pumpkin seed · 10,000 · a Pineapple seed · 20,000 and a Flower Barrel for your store. Coins grow with your level like the quests'. Miss a day and it starts again at day 1.
- **Farm Log** (from the Barn window): visitors, thefts (who, what), arrests, truck receipts, worker strikes, debt payments received.
- **Welcome back card** on join: offline growth ("6 crops ripened"), offline worker earnings, wages paid, payouts received, and anything that happened to a truck run in progress.

## 5. GUI and UI design

### 5.1 Look: "Kraft & Crate"
The UI looks like things you'd find on a farm: kraft paper, crate labels, seed packets, painted wood signs, chalkboards. It's Farm Heist's own look. It doesn't borrow Tide Market's (no dark walnut pills, awnings or round black buttons). The kit is `src/client/UI.luau`, and every HUD piece and window is built from it:
- **Wood** (`UI.wood`): boards with dark seams, across for signs, up and down for crates. **Crates** (`UI.crate`) are the side-bar buttons: boards, rails and a cream stencilled label.
- **Panels:** kraft-paper cards with a stitched inner border, over a dimmed backdrop (tap outside to close). The Seed Rack is a rack of boards instead.
- **Header:** a painted wooden sign hung on two ropes with nails, the title in cream with a dark outline. A round red **stamp** closes the window.
- **Tabs:** seed packets with a crimped top and a band of colour. The chosen one stands up.
- **Stamps** (`UI.stamp`): round rubber-stamp buttons with an inner ring: the big context button and the Run button.
- **Chalkboards** (`UI.chalkboard`): dark green in a wooden frame, in chalk handwriting: the tile you're on, Barley's restock countdown, locked seeds.
- **Rosettes** (`UI.rosette`): county-fair prize ribbons: your Farm Level in the HUD and the level-up card.
- **Coins** are drawn (a gold disc with a rim and a shine). Roblox can't show the 🪙 emoji, or anything newer than Unicode 12.
- **Buttons:** chunky, with a darker 4 px bottom edge that squashes when pressed. **Green** = confirm/do it, **gold** = spend coins, **red** = steal/danger/alarm, **blue** = info/go somewhere, **Robux green with the R$ icon**.
- **Item cards:** a crate-label strip with a 3D picture on the left (`ItemPreview`), the name in its rarity colour, small tags (Ripe, Wet, Giant, ×12), a detail line, and buttons on the right.
- **Price tags** (`UI.tag`): tags with a pointed end, a hole and a string: prices, and the location chip.
- **Toasts:** paper notes pinned with a coloured tack, slightly crooked, in handwriting, in the middle of the screen under the purse and the ticker (since 2026-11-05, the user: the top right was "hard to see and players may not notice it"). While a window or the Welcome Back letter is up they go to the very top of the screen, so they don't sit on what you're about to press, and they draw over the prompts. Announcements are on yellow paper.

**Tokens** (`UI.C` in `client/UI.luau`):

| Token | Hex | Used for |
|---|---|---|
| Barn Red | `#C8452D` | headers, danger, the theft alarm |
| Hay Gold | `#F2B33D` | coins, buy buttons, highlights |
| Leaf Green | `#4E9F3D` | confirm, "Your Farm", growth |
| Soil Brown | `#6B4A2F` | wood, outlines, text on kraft |
| Kraft | `#D9B98A` | panel body |
| Cream | `#FFF4DC` | cards, text on wood |
| Ink | `#3A2A1C` | body text |
| Sky Blue | `#5BB6F0` | info and travel buttons |
| Alarm Red | `#E8352B` | Suspect, red edge pulse |

**Rarity colours:** Common `#B8B8B8` · Uncommon `#5CC75C` · Rare `#3E8EF0` · Epic `#A05CF0` · Legendary `#F5B323` · Mythic `#F04FA8` (with a rainbow gradient sweep). Each rarity also has its own **badge shape** (circle, leaf, diamond, star, crown, flower), so colour is never the only cue.

**Fonts:** `Enum.Font.FredokaOne` for headers, numbers and buttons; `BuilderSans` for body text; `PatrickHand` for anything handwritten (notes, chalk). At least 14 px on phones.

### 5.2 HUD (landscape phone)

```
┌───────────────────────────────────────────────────────────────────────────────┐
│ (Roblox chat)        ║ (●) 12,450 ║(Lv 7)   ☀ 14:20 · Rain in 2:10     🔔 notes  │
│                      ╚═▓▓▓▓░░═════╝ ribbon                                        │
│                         ◁ Your Farm ]   ◀ 🥕 Carrot 21 ▲ · 🎃 Pumpkin 640 ▼ ▶      │
│ ┌────┐                                                                      ┌────┐│
│ │Barn│                                                       (toasts stack) │    ││
│ │Ware│                                                                      │    ││
│ │Shop│                                                                      │    ││
│ │Work│                                                                      │    ││
│ │Mkt │                                                                      │    ││
│ │More│                                       ┌───────────┐                       │
│ └────┘      ◁ HOME ][ TOWN ▷                 ( HARVEST ) ← the context stamp      │
│          [ 🏏 | 🥕 ×12 | 🌽 ×4 | 🎃 ×1 ]  (seed packets)   (jump stays clear)  │
└───────────────────────────────────────────────────────────────────────────────┘
```
- **Top centre** (the "purse"): a wooden sign hung on ropes from the top of the screen with your coins (from a million, shortened: "12.3M"), the Farm Level rosette and the XP rail. Under it the **location chip**, a price tag:
  - 🟢 **Your Farm** (green)
  - 🟡 **Visiting Sam's farm** (gold)
  - 🏪 **Sam's Corner Store** (green when it's yours, gold when it isn't)
  - 🔴 **TRESPASSING** (red, pulsing, once you're a Suspect)
  - ⚪ **Town**
  It's at the top centre, not top left, because Roblox's chat window lives top left on computers (found in week 1). The top right is Roblox's player list.
- **Beside it, on the left:** the sky dial (week 7, §4.14): the weather's icon, the clock under it, the growth badge. **Under the purse:** the market ticker, a chalk strip (week 2).
- **Top right:** the theft alarm card. The notes (auction starting, truck paid, Hot Crop) are in the middle (§5.1).
- **Top bar, at the right of Roblox's own row:** the 👥 Invite, 💎 Robux and ⚙️ Settings signs. Invite opens Roblox's own window for inviting friends (`InviteController`), or says so if this player or device can't send one.
- **Left side bar:** Barn · Warehouse · Store · Workers · Market · More (Cropdex, Trade, Trusted, Farm Log, Robux shop, Settings). Badges show counts (crates waiting, crops ripe, a worker ready to train, an upgrade you can afford). On phones the crates are smaller (58×52) and sit in **2 columns** from the top of the screen, above the thumbstick (3 columns if a short screen needs them; play-tests 2026-10-31 and 2026-11-03); a computer window too short for one column gets the same. (Built: Barn · Store · Market · Warehouse · Workers · Defend · Quests · Trade as crates, each one tap, instead of a More crate; **Robux and Settings** are wooden signs at the right end of Roblox's own top bar (week 9: as two more crates they pushed a phone's side bar to three columns over the sky dial).)
- **Switching seeds** (the user, 2026-11-06: "Find a way that makes it easy and convenient for players to plant and switch their seeds"; `shared/HotbarRules`, `FieldController`): on empty soil with a seed in hand and another kind to change to, the smaller stamp says **CHANGE SEED** (F; B on a gamepad) and opens the seed picker, and what you pick is planted there. With more seeds than the bar holds, its last place is an **ALL** packet that opens the picker from anywhere. The seed in your hand always keeps a place on the bar, so you can put it away, and it's ringed in gold in the picker. Before, a seed picked from past the end of a full bar wasn't on it, so it couldn't be put away, and with one in hand E only ever planted it.
- **Bottom:** the hotbar of **seed packets** (the picked one stands up, and a chalkboard over the Home and Town boards says what it is: "🥕 Carrot seeds ×3"; the user, 2026-11-05, as a packet's picture alone doesn't say). Tap the one you're holding (or its key) again to put it away; running out of a seed leaves your hand empty, never another seed. **Plant with no seed in hand opens the seed picker**: every seed you have as a big packet (the ones you can't plant yet greyed with their level), tap one and it's planted (added 2026-11-04). The bat 🏏 joins it as slot 1, only inside your farm. There's no watering-can slot: the context stamp waters. The **Home** and **Town** signposts sit above it.
- **Bottom right:** the **context stamp**, with a chalkboard above saying what's on the tile and how long it has left. It changes to whatever you can do right now: Plant · Water · Harvest · Steal (red, hold) · Swing · Arrest (red, hold) · Take back (green, hold) or Grab (red, hold) by a dropped crop · Deposit · Pack. A key cap on its rim says which key presses it (E; the gamepad's button; none on a phone). One press does one action. Hold it and walk to repeat that same action on every tile you cross (plant a row, harvest a row), never a different one.

### 5.3 Windows

| Window | Theme | Main parts |
|---|---|---|
| **Packing Shed bench** | crate labels, then the wash | Each barn stack with what it pays by 🚚 truck and in your 🏪 store, and 📦 Pack; then the wash: hold the stamp, let go in the green. The toolbar counts your packed crates |
| **Dock** | a load sheet | The truck's load and Send; your packed crates, alike ones together, each with Load; what's on the truck with Take off |
| **Seed Rack** (Barley) | wooden rack of seed packets | Tabs by rarity. Each packet: picture, grow time, sell value, stock "×3", price tag, Buy ×1/×5. A restock countdown on a chalkboard. Locked packets say "Lv 10" |
| **Barn** | barn doors open | Crops · Seeds · Items · Workers · Land tabs; a capacity bar; Send to warehouse; Hold (for planting). The Land tab shows the 4×4 block map, permits waiting, and each clearable block marked Safer or Riskier |
| **Warehouse** | a clipboard | **Pipeline:** Intake → Sort → Pack → Route → Load → Truck as a row of station cards (queue, worker slots, speed). The bottleneck is orange. Truck cards with a fill bar, the price it would lock and **Send**. **Routes** (crop → Truck / Store / split). **Upgrade**: the level ladder on blueprint paper, the next level's card and **Upgrade**. On phones the pipeline wraps into 2 rows of 3 |
| **Store** | a shop counter with price tags | A header: your store's name (Rename), rating with Charm and why ("3 shoppers gave up in the queue: open another checkout"), a big **Decorate** stamp. **Prices:** each crop's reference, the truck price now, **your price** (− +), the demand face, % that buy, ~sales/min, and which rarities your displays can't hold yet. **Stock:** **Fill all**, the stockroom, each display's slots (fill, Auto or a crop). **The shelf panel** (E at a display, §4.8): the display's name on the sign, a tab per slot, Auto and a card per unlocked crop (stock, price, FILL / OUT OF STOCK / the display that holds it). **Upgrade:** the next level on blueprint paper and the ladder |
| **Decorate** | blueprint paper over your store | Your store from above, roof off, walls faded, the chalk grid with DOOR and STAFF marked; your coins on a plate over what the draft costs, by DONE (the user, 2026-11-06: "Show players coins in shop decoration mode"), as the HUD's off in here; the drawer of item cards (Displays · Checkouts · Decor · Wall · My items) with a 3D picture, size, what each does and its price ("Yours ×2", 🔒 Store Lv 5); green/red placing with the reason; Move · Turn · Put away · Sell; **DONE** with the total under it, ✕ to leave it as it was |
| **Workers / Hiring Hall** | ID badges on a corkboard | Station slots ("Packer 2/3", greyed ones saying which level opens them). Candidate badges: photo, name, type, level and efficiency, trait, wage, hire fee, **Hire**. Your workers: level and efficiency ("Lv 4 · 60%"), the XP bar, **Train** when it's full, fire, the Driver's rule |
| **Market** (Exchange) | a chalkboard | Each crop: price, ▲/▼, a 3 h sparkline, events (Hot Crop, Glut, festivals) with timers. Main button: **Dispatch truck now** (if one is loaded) at the prices shown |
| **Auction** | red velvet with a gold frame | The lot's 3D picture, its estimated value, the current bid and leader, a timer ring (it flashes on anti-snipe), **+5% / +10% / +25%** bid buttons, your escrow, the next lots |
| **Trade** | two crates side by side | Your offer and theirs (8 slots + coins), the value of each side, a red warning bar, Ready → countdown → Confirm |
| **Defences** (🛡️ Defend) | blueprint paper | Your Sprout Shield's time left (**Drop it now**). A card per defence: what it does, its price and Farm Level, how many are out, **Buy · Place · Put away**. Place shows your field from above with a green spot wherever it can go, the dog's reach and the scarecrow's line drawn on the ground. **Trusted:** your list (Remove) and the players here, friends first (Trust). **Camera:** who came in, in the last half hour |
| **Police desk** | a case file | Your debts (to whom, how much, payment progress), Pay now, your rap sheet |

### 5.4 Theft alarm (owner)
- A **red pulse round the screen edges** (scaled by the Flashing setting), a siren chirp, and a top-right alarm card: **"🚨 Sam is stealing your Pumpkin!"** with:
  - an arrow at the screen edge pointing at the thief
  - the security-camera picture-in-picture (if you own one)
  - **[🏠 Home 3s]**, or **[Go get them!]** if you're already on the farm
- The crop being stolen flashes on your screen, and its progress ring shows how long you have.
- A softer amber card for early warnings ("Someone is near your crops", from the scarecrow).
- When you bonk a thief carrying your crop: "Sam dropped 🎃 1 pumpkin: hold TAKE BACK before someone grabs it!", and **TAKE BACK** on the stamp beside it. Someone grabbing it sets the alarm off again ("🚨 Sam is grabbing the dropped 🎃 Pumpkin!"). The Watchman's line ("🔔 Your Watchman shut the gate on Sam for 15 s.") joins the alarm card once the thief has the crop.

### 5.5 Thief screens
- **Steal hold:** a ring over the crop (the crop's icon in the middle) and the hold bar on the context button. Before the first steal the stamp warns "Stealing makes you a Suspect"; once you are one, "Hold 2.5 s, then carry them home over your head", and the stamp shows how many you'd get ("🥕 ×6").
- **Carrying:** the "TRESPASSING" chip, the name tag turns red, and a compass arrow points to your own farm ("Get home!").
- **Knocked out:** a dizzy wobble, the screen goes grey and blurry with stars, and a card: **You got knocked out...** and **You are down for 5 seconds**, counting down to 1. A Suspect sees **"The farmer can arrest you!"**. Anyone else sees **"You're just stunned"** and the **Leave farm** button.
- **BUSTED!** a mugshot card (avatar headshot, height chart, the charge "Crop theft: 1 Pumpkin", the fine, "paid to Alex", any debt), then a fade to the police porch.
- **Carrying:** the crop held up over your head, a sign over the hotbar ("🎃 Pumpkin · Get home!") with an arrow to your farm, and **HANDS FULL** on the context button over another ripe crop.
- **Bonked with a crop:** it falls past your head with a "Dropped!" label; awake again, **GRAB** on the stamp beside it ("A thief dropped it. Grabbing it makes you a Suspect").
- **Got away:** "Safe! Now get it home: it's yours as soon as you're back in your own farm." when you leave the plot. Back in your farm: "+🎃 Pumpkin (stolen) in your barn" and the crop's icon floats up.

### 5.6 Small things that matter
- Every number change floats up (+180 🪙, +6 🥕).
- A ripe crop's bounce is in time with the music beat. Satisfying harvest pops.
- **Settings:** music, SFX, Flashing effects (0–100%), Reduced motion, text size (80–125%), Trade requests on/off, Quiet mode, Drop Sprout Shield early (in the Defend window until Settings is built). Built in week 9 as the ⚙️ Settings sign in the top bar (`shared/SettingsRules`, `SettingsService`, client `SettingsController`), with ambience as its own switch and the Farm Guide's card shown or hidden: switches drawn as switches, − and + for the steps. Flashing scales the theft alarm's red edge and lightning's flash and steadies the TRESPASSING chip and the auction clock; Reduced motion stops the guide's bobbing marker and pulse, the lot's bob, confetti, the knockout blur and rising numbers; text size is a UIScale on windows and notes (they keep their room on screen); Quiet mode hides notes sent to everyone (`Notice.all`, someone else's auction win, the auction's calls).
- **Prompts are our own** (2026-11-04; Roblox's grey ones before): every ProximityPrompt is drawn as a little wooden sign with a cream key cap ("E", the gamepad's button, or 👆 on a phone), what it is in small letters over what pressing does; holding fills the key cap with gold, and it pops in and squashes when it fires (`PromptController`; Roblox still picks which prompt shows and handles the keys). It's drawn on the screen over the thing it's for, above the HUD (a sign in the world went under the market ticker and the HOME/TOWN signs on a phone), and hides while a window is open.

## 6. Economy

### 6.1 Crops (`Config/Crops.luau`, base market values)

| Crop | Rarity | Seed | Grow | A patch gives | Each | Crate | Regrows | ~Profit per tile-minute |
|---|---|---|---|---|---|---|---|---|
| Carrot | Common | 100 | 1 min | 6 | 30 | 72 | – | 80 |
| Wheat | Common | 150 | 1.5 min | 3 sheaves | 90 | 24 | – | 80 |
| Potato | Common | 250 | 2 min | 10 | 42 | 100 | – | 85 |
| Lettuce | Common | 300 | 2.5 min | 4 | 130 | 24 | – | 88 |
| Corn | Uncommon | 900 | 5 min | 6 cobs | 240 | 60 | – | 108 |
| Onion | Uncommon | 1,100 | 6 min | 7 | 250 | 70 | – | 108 |
| Strawberry | Uncommon | 1,200 | 4 min | 4 punnets a picking | 175 | 24 | ×3, every 3 min | 123 |
| Tomato | Uncommon | 1,500 | 5 min | 6 a picking | 150 | 60 | ×3, every 4 min | 124 |
| Bell Pepper | Rare | 3,500 | 12 min | 4 | 1,300 | 24 | – | 142 |
| Pumpkin | Rare | 4,000 | 15 min | 1 | 6,100 | 6 | – | 140 |
| Watermelon | Rare | 5,500 | 20 min | 1 | 8,300 | 6 | – | 140 |
| Blueberry Bush | Rare | 7,000 | 12 min | 4 punnets a picking | 650 | 24 | ×4, every 8 min | 136 |
| Pineapple | Epic | 20,000 | 45 min | 2 | 14,500 | 8 | – | 200 |
| Cocoa Pod | Epic | 24,000 | 50 min | 4 pods | 8,500 | 16 | – | 200 |
| Dragonfruit | Epic | 30,000 | 60 min | 3 | 14,000 | 12 | – | 200 |
| Grape Vine | Epic | 40,000 | 45 min | 3 bunches a picking | 5,000 | 12 | ×4, every 30 min | 212 |
| Moonmelon | Legendary | 120,000 | 2 h | 1 | 156,000 | 2 | – | 300 |
| Starfruit | Legendary | 150,000 | 2.5 h | 3 | 65,000 | 6 | – | 300 |
| Golden Apple Tree | Legendary | 250,000 | 2 h | 5 golden apples a picking | 14,000 | 10 | ×5, every 90 min | 298 |
| Crystal Rose | Mythic | auction (~400k) | 6 h | 1 | 600,000 | 1 | – | ~550 |
| Phoenix Pepper | Mythic | auction (~420k) | 6 h | 1 | 640,000 | 1 | – | ~600 |
| Dragon's Eye Pumpkin | Mythic | auction (~480k) | 6 h | 1 | 700,000 | 1 | – | ~600 |

**A patch gives several, counted one by one** (the user, 2026-11-02: "1 farm plot shouldn't produce 1 carrot or 1 tomato"). How many is what you'd pick from a patch 12 studs across and what the ripe patch can show: small crops many, big crops one (so a thief can hold a whole patch over their head and a shopper buys 1–4 of them), berries and grapes by the punnet and bunch, the way shops sell them. *Each* is one crop's base value: the old patch value ÷ the count, so profit per tile-minute didn't move (corn is 0.7% off). **Coins went ×10** at the same time (seeds, prices, levels, wages, fines, the starting coins): split six ways, a carrot would have been 3 coins, prices could only have moved in thirds, and the store's pricing would have had three usable prices for the first crop everyone sells; now every crop is worth 30 or more, so a coin is at most a 3% step. A crate holds 12 patches' worth of a Common, 10 of an Uncommon, 6 of a Rare, 4 of an Epic, 2 of a Legendary, 1 Mythic (a few rounded down to look like a real crate), so trucks, the Cold Room and the crew carry what they did. Everything else that counts crops (store slots, shoppers' baskets, the Sorter and Stocker, market supply) counts patches' worth too, shown as the crops themselves. Field Levels add ×1.1 to ×1.5 (§4.1c).

Before the market wave (0.8–1.2), events, grade A (×1.15), mutations (×1.3–×8), Giant (×3) and shop markups. Mythic profit is shown at the usual winning bid; bidding wars pull it down towards ~450. Rarer crops pay more per minute but take longer, need you around, and are what thieves want, so the risk grows with the reward.

### 6.2 Sources and sinks

| Sources | Sinks |
|---|---|
| Truck sales (global price) | Seeds |
| Shop sales (your price) | Worker hire fees, wages and training |
| Fines received (moved from thieves, never created) | Land clearing fees (once a permit is earned), the Silo, **Warehouse and Store Levels** (about 80 million each for the whole ladder), **Field Levels** (about 16 million) |
| | **Store decor and displays** (open-ended; selling back pays half) |
| Quests, streak, Cropdex rewards | Defences |
| | Auction wins (the coins are spent) |
| | Auction Board 5% fee (v1.1) |

**Rules**
- Robux never buys stealing power or defence power (§7).
- Fines only move coins between players. Debts expire after 7 days rather than creating coins.
- Watch weekly: total coins, median Net Worth, Mythics in circulation, average fine, raids per hour per server, % of raids ending in an arrest (aim for 35–50%).
- **Late-game sinks, mostly solved by levels.** (Amounts at today's scale: coins ×10 since 2026-11-02.) Before the store and level ladders, a daily player had bought all the land and buildings by day 23 and piled up about 40 million coins by day 35 (earning 5–7 million a day). With Warehouse, Store and Field Levels and worker training, `tools/progression` (the real tables; it checks these targets): a daily player sinks about 84 million by day 35 and holds about 16 million; reaches Warehouse and Store Level 5 on day 2, Level 10 on days 8 (warehouse) and 9 (store) and Level 15 on days 22 and 24; Field Level 2 on day 2, 3 on day 5 and 4 on day 17 (Level 5, at Farm Level 26 for 12 million, is a second-month goal); workers average Level 6 by day 14 and 7 by day 28 (the first hires 8); wages peak at about 6% of income; the land targets still pass (the full 8×8 on day 22). The Field Levels' extra crops compound (more coins, warehouse levels sooner, more sold while you're away), so Warehouse and Store Levels 6–20 cost twice what they did to keep those days. A casual player reaches Warehouse Level 10 on day 18 and ends day 35 at Farm Level 29 with Field 4, Warehouse 14 and Store 13. Not in the run: store sales (they'd speed it up) and decor (it slows it down). Level 20 of both ladders is a second-month goal. What's still open is the very long tail after that (§11 step 6).

## 7. Monetization
Rule: **no paid power in the PvP**. Robux buys comfort, shared moments, space and looks.

| Item | Type | Robux | What it does |
|---|---|---|---|
| VIP | Pass | 199 | +10% sale income, a gold name tag, a VIP truck paint and shop awning |
| Bigger Barn | Pass | 99 | Barn capacity ×2.5 |
| Rain Dance / Thunderstorm / Golden Hour / Harvest Moon | Product | 49 / 79 / 99 / 149 | That weather **for the whole server** for 5 min (Tide Market totem rules: one at a time, never over a better weather, never into the scheduled Harvest Moon). A Harvest Moon bought is a Heist Night for everyone |
| Growth Boost | Product | 79 | Your field grows ×2 for 30 min (online only) |
| Cosmetics | Products | 25–249 | Bat skins (Golden Bat, Baguette, Carrot Club: **same stats**), truck paint jobs, store decor sets and awnings (**looks only**: a Robux item's Charm is the same as the cheapest coin item of its size, and it can't be sold back for coins), farmhouse styles, scarecrow skins, sack skins, funny mugshot frames |

- **Never sold:** Land Permits (land opens by level only), defences, steal speed, how much a thief can carry, bat reach, knockout length or immunity, more worker slots than a station's cap, Warehouse or Store Levels, worker XP or training.
- Nothing bought with Robux can be traded (so regional pricing can't be resold).
- Receipts de-duplicated by PurchaseId and saved before granting (the Tide Market pattern).

**Built in week 9** (`Config/Monetization`, `Config/Cosmetics`, `shared/RobuxRules`, `MonetizationService`, client `RobuxController`: the 💎 Robux sign in the top bar, tabs Passes · Weather · Boost · Style, every price on a green button with the Robux sign): VIP (+10% in `DataService.Earn`, so truck and store sales and offline store sales; a gold ⭐ VIP tag over the head and [VIP] in chat; VIP Gold truck paint; a gold store awning), Bigger Barn (×2.5, `BarnRules.capacityOf`), the four weathers, the Growth Boost, and two kinds of looks: bat skins (Golden Bat 149, Baguette 79, Carrot Club 79: drawn by `CrimeArt.bat`, each its own shape, about the same length and the same swing) and truck paints (Cherry Red, Mint Green, Midnight Blue, 49 each; `YardArt.paintTrucks`). A bought weather goes into your barn and starts at once if it can, or from the Weather tab later (its card says so before you buy, naming the weather that's in the way): never over a better weather (Rain < Frost Night = Thunderstorm < Golden Hour < Harvest Moon), never while another bought one is on, never on or into the scheduled Harvest Moon; it's on every player's sky through the same `WeatherForce` attributes as `/weather`, with who bought it. The Growth Boost's 30 minutes count only while you play. A look bought twice gives 30 minutes of Growth Boost instead. Every id is 0 until the passes and products are made on the Creator Dashboard ([RobloxPage.md](RobloxPage.md)); in Studio, items with no id are granted without a purchase (`/pass`, `/buy` too). Not built yet: store decor sets and awnings for Robux, farmhouse styles, scarecrow skins and mugshot frames (sack skins went with the sack in the carry rework).

## 8. Technical architecture

```
src/shared/   Config/  Crops · Rarities · Growth · Land · Warehouse · Shop · Store · Workers · Auction
                       Market · Crime · Defences · Progression · Settings · Weather · Quests · Guide · Monetization · Cosmetics · Sounds
              Rules:   GrowthRules · SeedStock · MarketPrice · DemandModel · LandRules · ProgressionRules
                       CrimeRules · FineRules · TravelRules · ZoneRules · AuctionRules · WorkerRules · WeatherRules · QuestRules
                       PipelineRules · MoveRules · BarnRules · PlotRules · CrateRules · TruckRules
                       ShopRules · StoreLayout · LootRules · PayoutRules · DefenceRules · GuideRules · TradeRules · LeaderRules
                       SettingsRules · RobuxRules
src/server/   Services/ Data · Plot · Field · SeedShop · Auction · Market · Warehouse · Truck
                        Store (shoppers too) · Worker · Crime (steal, carrying, bat, knockout, arrest)
                        Payout (debts, the payout queue, the police desk) · Defence (defences, Trusted, the shield,
                        the domes, the dog, the Watchman) · Movement · Trade · Weather
                        Quest · Guide · Leaderboard · Settings · Monetization (Robux: receipts, passes, weather, looks)
                        Analytics · DevCommand
              World/    WorldBuilder · Parts · FarmArt (the field) · YardArt (shed, dock, pickup)
                        StoreArt (the store's buildings) · StoreItems (the catalog's models)
                        CrimeArt (the bat, the stolen crop held up) · ProduceArt (each crop as carried)
                        PoliceArt (the Police Station's front) · DefenceArt (the fences, the gate, the defences, the domes)
                        AuctionArt (the Auction House: the hall, the stage, Goldie Gavel)
                        PlazaArt (the plaza, the clocktower in the fountain, the park, signposts, the green, street lamps)
                        TownArt (Barley's Seeds, the Hiring Hall, the Exchange and its grain elevator, Barley, Patty)
                        BoardArt (the leaderboards) · ValleyArt (the hills, the tunnel, the woods, the back trail's cover, the road's paint)
                        LightingSetup   (PlotLayout lives in shared/)
src/client/   UI (Kraft & Crate theme, HUD in code) · Controllers/ Field · Warehouse · Store
              Decorate · Shopper · Workers · Market · Auction · Crime (alarm, KO, mugshot) · Police (the desk)
              Pose (arms on carried things, the bat's hold and swing: IKControls) · Truck (trucks wait for people)
              Defence (the Defend window, setting out) · Gate (gateways on your screen, mud) · Watch (the dog, lights)
              Trade · Weather · Guide (the Farm Guide's card) · Settings · Robux (the Robux shop, the VIP chat tag)
              Ambience (music, birdsong, crickets, rain) · Sfx (plays Config/Sounds)
```

- **Server-authoritative.** The client sends intents (plant, harvest, steal start/finish, swing, arrest, bid, set price, dispatch). The server checks and owns all state.
- **Workers and shoppers are simulated as data on the server** (state + timestamps per worker: "carrying crate to Load, arrives at t"). Clients draw the NPCs walking set routes from replicated attributes, so 8 farms × 15 NPCs stays cheap. No pathfinding at runtime: each plot has a fixed waypoint graph.
- **Saved data (v2 since 2026-11-02, ProfileStore `FarmHeist_Profiles_v2`, session-locked; v1's test saves start over: coins ×10, crops counted one by one):**

```lua
{
  coins, xp, level, playSeconds,
  field = { [tile] = { seedId, progress, lastUpdate, harvestsLeft, yield, mutation?, giant? } }, -- yield: how many it gives
  land = { cleared = { blockNumbers }, clearing?, fresh, fieldLevel }, silo, -- permits are worked out from the level, never stored
  inventory = { crops = { [stackKey] = count }, seeds = { [seedId] = n }, items = {...} },
  warehouse = { level, build?, beds = { { crate } }, sorted = { batch },
                routes = { [cropId] = share }, trucks = { TruckRun } },
  store = { level, build? = { to, left }, name?, started, nextId,
            layout = { ["id"] = { item, x, y, rot, slots? = { { set?, crop?, units, a } } }
                                | { item, side, at } },   -- wall items
            owned = { [itemId] = count }, gifts = { [itemId] = count },
            stockroom = { crate }, prices = { [cropId] = coins }, rating = { scores = { 1–5 } } },
  workers = { [uid] = { type, level, xp, trait, station, hiredAt } },
  defences = { placed = {...}, owned = {...} }, trusted = { userIds },
  crime = { earnBuckets = {12}, arrests = {timestamps}, debts = { {ownerId, ownerName, amount, createdAt} },
            lastArrestAt, fled?, board = { day, pairs = { [thiefId] = n } } },   -- board: arrests that count today
  payoutsClaimed = { [payoutId] = true }, auctionHeld (coins a lead holds), seedStock = { restockId, bought = {...} },
  cropdex = {...}, quests = {...}, streak = {...}, stats = {...}, settings = {...},
  receipts = {...}, lastOnline,
}
```

- **Saving:** autosave every 5 min, on leave and on shutdown. Crime penalties are applied in `PlayerRemoving` *before* `profile:EndSession()`.
- **Anti-cheat** (the client is never trusted):
  - **Movement:** `MovementService` + `MoveRules` (from Tide Market): a speed allowance per tick, rejections send you back, and every distance or zone check uses the trusted position. The game's own teleports go through `MovementService.Teleport`. Steps through a farm's edge and hanging in the air over a farm are sent back too, and characters don't collide with each other.
  - **Crime:** every hold is timed on the server; `validHit` (§4.12); knocked-out characters are anchored with server network ownership.
  - **Economy:** every price, payout, fine and trade is worked out on the server. Remotes check types, ownership, cooldowns and distances.
  - **Logging (no auto-bans):** Analytics custom events `StealStarted`, `StealDeposited`, `Knockout`, `Arrest`, `FledArrest`, `HitRejected`, `MovementRejected`.
- **Tests** with Lune, like Tide Market (`lune run tests/run`): growth (online/offline), market price (wave, events, clamp), demand model, pipeline simulate, crime state machine (every bypass in the §4.12 table), fines and debt, land permits (level gates, blocks must touch cleared land), auction rules (anti-snipe, escrow, leader leaves), trade rules.

## 9. MVP plan (9 weeks)

Each week builds its features *and* their look ([ArtDirection.md](ArtDirection.md) §11 has every look step with its week). Art counts as done only once it looks right to the eye and makes sense in Studio: next to a character, close up and from across the farm, on a phone.

| Week | Build | Done when |
|---|---|---|
| 1 ✅ | Plots and zones, field (plant, water, grow, harvest), Barn inventory, Barley's shop with restocks, saving, offline growth. Farm Level and XP, Land Permits and clearing (moved up from week 2: their rules were done, and Stage B tests them). Travel (Home, Town, Visit), dev commands, the Kraft & Crate HUD, the first look pass. Greybox Cloverdale | 8 players can farm for 15 min without bugs (Stage B9) |
| 2 ✅ | Packing Shed and the pickup truck, the market price (wave + events), Exchange board, Farm Stand with shoppers and pricing. Also the Market window with Send now, the ticker, the receipt, and dev commands for selling (built and played in Studio 2026-10-31) | Players argue about truck vs shop |
| 3 ✅ | **Your Store** (§4.8): the building and its 4 stages, Store Levels 1–20, Decorate mode with the catalog and `shared/StoreLayout`, the stockroom, Fill and Set crops, shoppers walking the aisles, checkouts and queues, the rating with Charm, the store's name, the store cut out of the farm zone. The Farm Stand's code becomes the displays. **Look:** the store's buildings and items, farm colours and name plates, the gate arch, picket fences. (Built and played in Studio 2026-10-31) | Testers decorate a store on a phone and get it selling without help |
| 4 ✅ | **Warehouse Levels 1–20** (§4.6: stations, conveyors, Cold Room, routes, the second and third truck), **every worker type with Levels 1–10** (§4.9: XP, training, efficiency; the Watchman moves to week 6), wages and strikes, the Hiring Hall, offline settlement with the store and the Welcome back card; the progression sim updated with the real tables. **Look:** the warehouse's buildings and trucks, worker outfits. (Built 2026-10-31, played in Studio 2026-11-01) | Testers come back the next day to collect, and level a worker on purpose |
| 5 ✅ | Stealing, the sack, deposit, bat, knockout, Suspect, arrest, Police Station, fines and debt, every bypass counter + tests. The theft alarm's card and red edge came forward from week 6 (a raided farm's owner must know). **Look:** Suspect markers, the sack, the back fence's slats and climb, the Police Station's front. (Built 2026-11-01, played in Studio with 2 players 2026-11-02) | Raids feel fun on both sides; nobody can dodge an arrest |
| 6 ✅ | Defences, theft alarm, Home, Sprout Shield, arrival grace, raid caps, Trusted list (and the staff door for Trusted friends), MovementService, the Watchman (from week 4). Floodlights move to week 7, with night. **Look:** the defences (Built and played in Studio with 2 players 2026-11-02) | A defended farm catches most raids; an undefended one still survives |
| 7 | Auction House, weather and mutations, Harvest Moon, Cropdex, quests. **Look:** the town (plaza, clocktower, building fronts), weather, day and night. Built 2026-11-03 with week 6's Floodlights and played in Studio the same day (2 players); the town's look built and checked in Studio 2026-11-04 | Auction rooms fill up on the bell |
| 8 | Trading with logs and rollback, the MemoryStore supply factor, leaderboards (Top Store), the Farm Guide. **Look:** the valley (Terrain hills, woods, back-trail cover, the tunnel mouth). Built and checked in Studio 2026-11-04 (§10; 2 players) | 50-player test with no duplication or lost items |
| 9 | Kraft & Crate UI polish, mobile layout, analytics, monetization, thumbnails and the Roblox page art. Settings, sounds and music, the Robux shop, analytics and the page art built and checked in Studio 2026-11-04 (§10; every window on a phone; the icon and five thumbnails made, the store's on 2026-11-05) | Launch with a small sponsored-ad budget |

## 10. Design review log

The whole flow was walked through three times after the first draft. The fixes are already in the sections above. This log records what each pass found.

### Pass 1: the player's journey (join → guide → first sale → warehouse → workers → shield ends → raids both ways → auction → trade)

| # | Found | Fix |
|---|---|---|
| 1 | The town was called "spawn", but the Guide starts with planting on your farm | You join at your farmhouse door (first time: a fly-over); the town is the hub (§3, §4.1) |
| 2 | No starting coins or seeds were stated | 100 coins + 5 Carrot seeds (§4.1) |
| 3 | The first harvest is 5 carrots but a crate holds 12, so the Guide's pack step could jam | Crates can go out part-full (§4.6) |
| 4 | T0 had no way to send a crate to the Farm Stand (route rules are a T1 thing) | At T0 every packed crate asks "Truck or Stand?"; the bench pulls straight from the barn (§4.6) |
| 5 | The Guide's "hire a worker" step needs Lv 2 and a 200-coin fee a new player might not have | Lv 2 at 60 XP (reached during the Guide); the first hire is free (§4.0, §4.9) |
| 6 | Steps 6–7 needed crops the player had already shipped | The card adds "Plant your new seeds" between them (§4.0) |
| 7 | A full barn could block a thief's deposit (stuck with a sack, unable to teleport) or a returned sack | Deposits and returns always fit, even over capacity (§4.5) |
| 8 | The Watchman's gate lock made innocent visitors climb out, which made them Suspects | Climbing *out* is never suspicious; the Watchman's lock only stops Suspects (§4.9, §4.12) |
| 9 | Climbing a locked gate makes you a Suspect, which a kid might not expect | A "Private farm" sign and a one-time confirm (§4.11) |
| 10 | "Go", "Home" and "Rush Home" were used for travel without rules | Three travel buttons (Home, Town, Visit), each with a 3 s channel, a cooldown, and off while a Suspect (§4.11) |
| 11 | Farmhands with no seeds left would silently stop | "Out of Carrot seeds" status on the Barn button (§4.9) |
| 12 | Plot assignment claimed friends would end up as neighbours, but the rule didn't do that | You get the free plot next to a friend if one is in the server (§4.1) |

### Pass 2: exploits and edge cases (every remote and state change: plant, harvest, steal, deposit, hit, arrest, leave, reset, teleport, trade, bid, debt, offline settlement, plot unload)

| # | Found | Fix |
|---|---|---|
| 1 | Two thieves on one crop, or the owner harvesting mid-steal, weren't defined | First to finish wins; harvesting cancels the hold (the thief stays a Suspect) (§4.10) |
| 2 | A thief with loot from farm A knocked out in farm B: whose loot? | Each sack item remembers its farm; it goes back to that owner, or to B if A has left (§4.12) |
| 3 | Knocking out a player mid-trade wasn't handled | A knockout cancels trades and steal holds (§4.12) |
| 4 | An owner leaving with thieves or knocked-out players inside their farm | The farm closes: visitors are moved out, holds cancelled, Suspect marks cleared, anyone knocked out wakes (§4.1) |
| 5 | Arrival grace could be used to raid others while your own field was protected | No stealing during arrival grace or the Sprout Shield (§4.1, §4.10) |
| 6 | "The server pays the truck at `arriveAt` even if you leave" can't work: the profile session has ended | The run is saved; paid at arrival if you're here, otherwise at your next join (§4.6) |
| 7 | A debtor could park coins in auction escrow (bid, get outbid) to keep them away from the fine | Auction refunds count as income for debt (§4.12) |
| 8 | Friends staging arrests to top the Sheriff board and farm arrest XP | Only arrests with loot ≥ 50 count, at most 3 per thief–owner pair per day (§4.12, §4.15) |
| 9 | Leaving while knocked out but innocent wasn't stated | Nothing happens (§4.12 table) |
| 10 | Debt payouts to owners in other servers could mean lots of DataStore writes | Batched per debtor and owner, at most one record every 5 minutes (§4.12) |
| 11 | Trusted friends couldn't help at all | They can water and harvest for you, and the crops go to your barn (§4.1) |
| — | *Accepted:* a friend could "steal" 10 weight to trigger your Neighbourhood Watch dome | It costs you those crops (they only come back by a logged trade, after 1 h of play), so it isn't free protection. Watch the analytics |
| — | *Accepted:* leaving with a sack when nobody is chasing only loses the loot, with no fine | A real disconnect looks the same. The chase rule covers the dodge that matters |

### Pass 3: balance numbers and UI clarity

| # | Found | Fix |
|---|---|---|
| 1 | With a 2× loot fine floor, a raid on a defended farm lost money even at a 35% arrest rate, so raiding would die out | Floor lowered to 1.5×: break-even at a ~40% arrest rate, the middle of the 35–50% target (§4.12, §6.2) |
| 2 | Farmhands would harvest everything at once, so the "leave it out to mutate" choice was gone for anyone with workers | 🚩 *Leave in field* tile flag that Farmhands skip (§4.2, §4.9) |
| 3 | Mutation odds disagreed (Golden 1% in one place, 0.5% in another) and weathers had no length | One table with the per-roll chance and the length; checked it gives about 1 in 5 for a crop left out through a whole Rain or Harvest Moon (§4.14) |
| 4 | "Rows of 4 tiles" don't fit a 4×4 → 8×8 square, and only 7 of the 12 prices were listed | 2×2 blocks, all 12 prices (§4.1b; since then each block also needs a Land Permit) |
| 5 | The Warehouse pipeline (6 stations in a row) is too wide for a phone | It wraps into 2 rows of 3 on phones (§5.3) |
| 6 | The Market window had nothing to *do* | Main button: Dispatch truck now (§5.3) |
| 7 | Mythic profit (~55–60) was above the ~45 target | Shown at the usual winning bid; bidding wars bring it towards 45. Re-check with live auction data (§6.1) |
| 8 | What happens to the Shed Hand at T1 wasn't said | They become a Packer at the same level (§4.9) |
| 9 | It wasn't clear whether players can buy from each other's shops | NPC shoppers only; players trade (§4.8) |
| ✓ | Wages vs income | T1 farm: 9 workers × ~6 = ~54/min against ~450/min income (12%). T3: 21 workers × ~8–14 against ~2,000+/min (10–15%) |
| ✓ | Truck capacity vs field output | The pickup ships 48 Commons a minute (more than a 16-tile field grows); a T1 box truck ships 8 crates/min (more than 64 Common tiles) |
| ✓ | Auction pacing | 5 lots every 8 min ≈ 37 lots/h per server, ~1.1 Mythic seeds/h (the only Mythics since 2026-11-04) |

### Change after review: land unlocks by progress
Field expansion used to be bought with coins at any time. Now each of the 12 blocks needs a **Land Permit earned at a Farm Level** (Lv 2 up to Lv 32) plus a clearing fee (§4.1b). I walked it through the same three passes:
- **Journey:** the first permit arrives during the Farm Guide (Lv 2), so a new player expands within the first session. The Guide's last card points at the block to clear.
- **Exploits:** permits can't be bought with Robux or traded. Coins from a lucky Mythic or a big trade can't jump the ladder. Blocks must touch cleared land, so nobody opens a lone tile in the far corner.
- **Balance and raids:** the field's size now tracks the level of the player defending it. Choosing between back-fence blocks (riskier) and farmhouse blocks (safer) ties land into the raid race. Farmhand caps (1 per 16 tiles) still line up: 4 Farmhands at the full 64 tiles.

### Final polish pass

| # | Found | Fix |
|---|---|---|
| 1 | The Guide ends by pointing at the first land block, but Permit 1 cost 1,000 coins and a new player has about 600 then | Permit 1's fee is now 250 (§4.1b) |
| 2 | There was nowhere to see your permits or plan which block to clear | A **Land** tab in the Barn window (§4.5, §5.3) |
| 3 | The plot diagram put the gatehouse by the farmhouse, but the map has it at the gate | Moved to the gate (§3) |
| 4 | The reset button was "off in all farms", which would also trap players who are really stuck | Off only while you're a Suspect, knocked out or carrying a sack (§4.12) |
| 5 | Harvest Moon at 12:00 UTC would mean a moon in daylight | The sky turns to night for it (§4.14) |
| 6 | "Earnings" for the fine left out refunds, but debt counted them, which read like a contradiction | Spelled out: the fine uses sales only; debt collection also takes refunds (§4.12) |
| 7 | Small slips: the 🚩 flag pointed at §4.14 instead of §4.2, `TruckRun` said boxes instead of crates, the mud patch size was in no unit, Land Permits weren't on the can't-trade list, the HUD sketch had no Town button | All fixed |

### Found while building the rules (next steps 1–2)
Writing the rule modules and their tests turned up four things the doc had wrong or left open:

| # | Found | Fix |
|---|---|---|
| 1 | The supply factor was clamped to 0.7–1.05, but the formula can never go above 1, so the 1.05 did nothing | Clamp 0.7–1.0 (§4.7) |
| 2 | Commons were "always in" but limited to a few packs, which would starve a field of 1-minute Carrots | Commons have no limit; other seeds come in packs of a set size (§4.3) |
| 3 | "+20% speed a level" could be read as adding or multiplying | Multiplying (×1.2 speed, ×1.15 wage), which matches the Hiring Hall mockup's numbers (§4.9) |
| 4 | Storing a permit count in the save could drift out of step with the level | Permits are worked out from the level and the blocks cleared; only the cleared blocks are saved (§8) |

Also settled in code: the Hot Crop and Glut times (:10 and :40), shopper intervals per shop tier, and that offline shops above the Farm Stand need a Cashier.

### Review of steps 1–2

| # | Found | Fix |
|---|---|---|
| 1 | A server shutting down removes everyone, so `PlayerRemoving` would have fined people knocked out at that moment, which §4.12 says must never happen | `DataService` notes `BindToClose` and tells the leave hooks the server is shutting down |
| 2 | Loot that went back to the farm still counted against the raid cap | Each sack item keeps its ledger entry; returning the loot removes it (`CrimeRules.raidRemove`) |
| 3 | The "rejoin within 2 min starts on the police porch" rule had no code | `CrimeRules.startsOnPorch` |
| 4 | A Farmhand clearing land (§4.1b) had no path | `LandRules.finishClearing` |
| 5 | The offline settle only covered the workers' 8 hours, so crops would have stopped growing after that | `PipelineRules.settle`: workers for 8 h, then growth for the rest of the time away |
| 6 | Many small growth steps added up a hair short of ripe (floating point) | Growth snaps to ripe within 1e-9; a test caught it |
| 7 | Mythic seeds at Barley's had no level lock, though §4.3 locks every seed above your level | Locked until Lv 20, like planting; auction lots stay unlocked |

### Step 3: progression

Added `Config/Progression`, `shared/ProgressionRules` (with tests) and `tools/progression`, which plays 35 days for a casual, a daily and a keen player with the real rules. A curve power of 2.65 meets every pacing target in §4.1b: permit 1 in the first session, Lv 12 on day 3, the full 8×8 on day 23. 2.55 finished the land on day 17 (too soon); 2.75 pushed Lv 12 to day 4.

The review of this step found:
- **Wages** are 5–8% of income, not the 8–12% the doc said. Fixed in §4.9.
- **Late-game sinks are missing.** Coins pile up once the land is done. Logged in §6.2 and added to §11.

### Step 4: the greybox and the raid race

Added `shared/PlotLayout` (every position in the valley and inside a farm, in one place), `server/World/WorldBuilder` (the greybox, built at every server start), `tests/layout.test.luau`, `tests/world.test.luau` (runs the builder for real with Lune's Roblox instances) and `tools/raidrace`. The review of this step found:

| # | Found | Fix |
|---|---|---|
| 1 | The doc's raid race assumed the back row was 34 studs from the fence; the farm's own layout puts it at 24 | Re-timed from the layout (§4.11). The same outcome, with different numbers |
| 2 | With real distances, an owner coming from town caught a defended thief with only 0.6 s to spare, which lag or a slow reaction would flip | The Tall Back Fence climb is now 3.5 s (1.1 s to spare). A test keeps at least 1 s |
| 3 | The layout's town was half the size of the design map's, leaving a 120-stud empty belt | Town enlarged to match the map (radius 160) |
| 4 | Plot fronts at 250 studs (the map) or less would put the corners of farms 1 and 8 on the highway | Fronts at 240 leave 6 studs of clearance; the test checks it |
| 5 | The driveway and the shop were gaps in "only two ways in" | A trucks-only gate on the driveway; the shop's back wall closes the yard (§3) |
| 6 | The doc's walking distances (200 and 400 studs) didn't match any layout | Replaced with the real ranges (§3) |

Not done here: walking the race in Studio with real movement (README, "Walking the greybox").

**Found while writing the play-test plan:** the fences were 5 studs tall, but a Roblox character jumps about 7.2. So anyone could hop the back fence without the climb, and the front fence was a third way in. Every fence now has an invisible wall up to 11 studs; the open gate is the only gap, and climbing (week 4) is the only other way over. `tests/world.test.luau` checks it.

### Play-test 1: walking the greybox in Studio (Stage A)

The first time anyone played Cloverdale: walks timed in Studio with real movement, plus a look round every part of the world for the art (results in [PlaytestLog.md](PlaytestLog.md), 2026-10-30). The town-to-farm walk, the back row to the fence, the owner's sprint and the fences all passed. Found:

| # | Found | Fix |
|---|---|---|
| 1 | The walk from the police porch to the back of a farm is 590–790 studs (49.2 s to the farthest farm). §3 said 385–580, because it measured straight lines through the plots | §3 corrected. `tests/layout.test.luau` now measures walking routes round the plots (and the Visit-then-walk route, about 30 s) |
| 2 | With Visit, an arrested thief is back at the same farm in about 30 s. Nothing stopped them stealing there again at once | §4.10: the same-farm cooldown (3 min) now also starts after an arrest |
| 3 | 5-stud fences under an 11-stud invisible wall: you jump, clear the fence you see, and bump into thin air | Fences are 8 studs, posts and rails you can see through. The invisible wall stays: without it, a character climbs the rails like a ladder |
| 4 | Every farm's labels piled up through the walls | Labels sized in studs and hidden beyond 45–260 studs |
| 5 | As a picture, the greybox is the Baseplate's lighting (its Depth of Field blurs the back row, where thieves stand), a hill wall, an empty town and 8 identical farms | [ArtDirection.md](ArtDirection.md): the world's look, written from the play-test screenshots |

### MVP week 1: the farming loop

Built: `PlotService` (farms handed out, spawn at the door, the InFarm zone), `FieldService` (plant, water, harvest, growth online and offline), `SeedShopService` (Barley's counter, rare-seed announcements), `LandService` ("Clear here" signs, obstacles timed on the server), `TravelService`, `DevCommandService`, `World/FarmArt` (tilled rows, block edging, overgrowth with its 4 obstacles, crops at 4 stages) and `World/LightingSetup`. Shared: `BarnRules`, `PlotRules`, `PlotLayout.tileAt`. The client: the Kraft & Crate kit and the HUD, hotbar, field stamp, Seed Rack, Barn and Run controllers. 203 tests. Played in Studio: plant, water, harvest, buy seeds, level up, clear a block, travel home, on desktop and phone emulation. The review found:

| # | Found | Fix |
|---|---|---|
| 1 | §9 put Farm Level and Land Permits in week 2, but Stage B (after week 1) tests them | Built in week 1; §9 updated |
| 2 | The first HUD copied Tide Market's shapes (rounded pills and buttons, square slots, a black Run circle) | Farm Heist's own kit: wood, crates, seed packets, tags, stamps, chalkboards, rosettes, handwritten notes (§5.1). The user asked for it |
| 3 | Roblox's chat window sits over the top-left HUD on computers | The coins, level and location hang top centre (§5.2) |
| 4 | Roblox shows 🪙, 🪪, 🫑 and 🫐 as blanks (Unicode 13 and later) | Coins are drawn; 📜 for permits; Bell Pepper 🌶️, Blueberry Bush 🌳, Phoenix Pepper 🔥 |
| 5 | One long press harvested, replanted and watered a tile, spending a seed you didn't mean to | A press does one action; holding repeats only that action across tiles (§5.2) |
| 6 | The watering can as a hotbar slot is a step too many on a phone | The context stamp waters; no can slot (§5.2) |
| 7 | Nothing showed where a half-cleared block's other obstacles were | They glow gold, and the chalkboard says "hold E on each glowing obstacle" |
| 8 | The Land map was mirrored compared with standing at the farmhouse door | Drawn as seen from the door (farmhouse side on the right) |
| 9 | Tilled tiles read as wooden planks; the farm path, driveway and lawn stripes flickered (two surfaces at one height); windows blinked on every save sync | Rounded soil rows; ground in layers (`WorldBuilder`'s note); windows only redraw when what they show changes |
| 10 | `lastOnline` moves on every minute, so a slow join could lose offline growth | `DataService.AwaySeconds` reads it the moment the save loads |

Left for later weeks, as planned: the Farm Guide (week 7), the Welcome back card (week 3, a note for now), the Sprout Shield dome and arrival grace (week 5), Trusted friends (week 5), a farm closing on its visitors when the owner leaves (week 4). A half-cleared block shows its last obstacles after a rejoin, which may not be the ones that were left (cosmetic).

### MVP week 2: selling

Built: `MarketService` (prices, Hot Crop and Glut announcements, the Exchange desk), `WarehouseService` (the Packing Shed bench, carrying crates, the dock pile), `TruckService` (loading, sending, the receipt, payouts, saved runs), `ShopService` (stocking, prices, shoppers, the rating), `World/YardArt` (the shed, dock and lever, the pickup, the boom gate, the Farm Stand), a sidewalk round the ring road, and `DataService.Earn` (sales income: coins, the last hour's earnings for fines, sales XP). Shared: `CrateRules`, `TruckRules`, `ShopRules`, `PlotLayout.truckRoute` / `shopperRoute`. The client: the bench window, the Market window, the Exchange's flip-board, the ticker, the Farm Stand window, the receipt slip, trucks driving and shoppers walking. Dev commands `/crops`, `/truck`, `/shoppers`, `/tp exchange · shed · stand`. 239 tests. Played in Studio on 2026-10-31 (desktop and phone emulation, [PlaytestLog](PlaytestLog.md)): packing, washing, carrying, loading, sending, the drive, the payout, the board, the windows and the shoppers all worked. The review and the play-test found:

| # | Found | Fix |
|---|---|---|
| 1 | §4.6 had each crate ask "Truck or Stand?" after packing: a crate with nowhere to go if the window closed, and the choice made without the numbers | You pick 🚚 Truck or 🏪 Stand on the stack's row, each button showing what it pays right now, then wash (§4.6) |
| 2 | At T0 the bench would have needed two minigames per crate (spray, then the tape swipe) | One hold per crate: washing grades it and it packs itself; the swipe is the T1 Pack station's (§4.6) |
| 3 | A crate being carried could vanish if you walked out, travelled, respawned or quit | It's set down at the dock, and "Load crate" takes from that pile (§4.6) |
| 4 | Empty-shelf visits scoring 1★ would sink every new stand before its first harvest | A stand with nothing on its shelves is closed: no shoppers, no score (§4.8, `Config/Shop`) |
| 5 | "1–4 units of 1–2 crops" didn't match `PipelineRules` and `DemandModel.salesPerMinute`, which assume one crop per shopper | One crop per shopper; a test checks the live buy rate against `DemandModel` (play-test C3's bar) |
| 6 | The price could only be locked at the dock, so timing the market meant standing at your farm | **Send now** in the Market window works anywhere (§5.3 already listed it) |
| 7 | The truck had no way out (the front fence crossed the driveway) and the Farm Stand opened a gap in the fence | A striped boom gate across the driveway and a counter with an invisible wall behind it: still only the gate and the back fence get you in (`tests/world.test.luau` checks the whole front) |
| 8 | Sending the truck cleared its bed at once, so it drove off empty | The crates ride along until they're sold in the City; it comes back empty |
| 9 | A run arriving while you're away would have given XP | Coins only: nothing earns XP while you're offline (§4.15) |
| 10 | Play-test: a stand with only Carrots filled one basket and left the other empty | The rest fills the empty basket (a different crop on each while there are different ones) |
| 11 | Play-test: one unlucky first shopper took a new stand from 3★ to 2★ | A new stand counts 10 shoppers at 3★ that the real ones replace (`Shop.RATING_SETTLE`) |
| 12 | Play-test: the stand's prompt showed a stale stockroom count; the Stand window cut off its notes; the Market window went quiet after the hour's Hot Crop | Fixed (PlaytestLog 2026-10-31) |
| 13 | Play-test: on a phone the side bar's third crate sat on the thumbstick | Smaller crates on phones; with more buttons coming (Warehouse, Workers, More) the side bar will need two columns or a "More" crate on phones |

Left for later, as planned: shoppers and Driver runs while you're away (week 3, `PipelineRules.settle` with the Welcome back card), paying debts from sales income (`FineRules.garnish`, week 4 with the payout queue: there can't be debts before then), the MemoryStore supply factor (week 7), festivals such as the Pumpkin Festival (week 6, with the events), the Farm Guide steps for packing and the stand (week 7), the pickup in your farm colour (look pass step 5).

### MVP week 3: your store (built 2026-10-31)

Built: `shared/StoreLayout` (cells, fronts, queues, the layout check, aisles with corners cut, Charm, the floor growing, a spot for a new building's gift), `Config/Store` (the grid, 4 buildings, 20 levels, 27 catalog items, the starter kit), `ShopRules` reworked for displays and slots (fill, Auto, set crops, wants, picks, baskets put back, the rating with Charm), `StoreService` (shoppers in the aisles and queues, Fill, prices, the name, levels and new buildings going up, saving a layout from Decorate, the staff door), `World/StoreArt` (the Corner Store, Farm Shop, Market Hall and Supermarket; the taped-off floor; the stockroom with its crates; scaffolding; "Back soon"), `World/StoreItems` (every catalog item, built once into `ReplicatedStorage.StoreCatalog` for the clients), the store cut out of the farm's zone (`PlotLayout.zone` with holes, an `InStore` attribute), farm colours, the gate arch with its name plank, picket fences and rounded hedges, old saves' Farm Stand goods moved into the store. The client: the Store window, Decorate mode, shoppers walking the aisles, the side bar in 2 columns on phones, the 🏪 location chip. Dev commands `/store N` and `/tp store`. 281 tests. The review found:

| # | Found | Fix |
|---|---|---|
| 1 | Placing items one at a time on the server would move furniture under shoppers' feet, and a half-finished layout would be live | Decorate edits a plan; **DONE** saves it in one go (one check, one purchase); "Back soon" hurries shoppers inside to pay; anyone still in when you save puts their basket back (§4.8) |
| 2 | A staff door "at the back" would open into the stockroom: either a bat-free room inside the farm or a door into a room | The staff door is in the side wall facing the gate, straight into the yard; the stockroom is a lean-to on the farm's side, open to the yard, showing your crates (§4.8) |
| 3 | When the floor gets deeper, the starter's shelves along the back would wall off the new row | Things against the back edge move back with it, if the layout still works (`StoreLayout.grow`) |
| 4 | A Register had nowhere for whoever serves to stand, and a 2-wide checkout had no "till end" | Its back cells must stay free; its queue starts at the till (`StoreLayout.tillFront`); in week 3 it serves while you stand behind it (Cashiers come in week 4) |
| 5 | Shoppers would stand anywhere in front of a 2-slot shelf | They stand in front of the slot with their crop (`StoreLayout.slotFront`) |
| 6 | Epic crops sent to the store before a Chiller would sit in the stockroom for good | The bench's 🏪 button says "Store Lv 8" (or "Full") and won't send them; the Prices tab says which rarities wait for which display |
| 7 | "5×3 is the smallest floor" for the starter kit isn't true under the final rules | Kept 5×3 (it leaves room for the first new items), wording fixed |
| 8 | The store's front door is a gap in the front boundary | It leads into the store, which isn't the farm: `tests/world.test.luau` allows the gate and the store's door, and invisible walls on the store's outline (the staff door's only for you) keep the store from being a way in |
| 9 | A starter layout in the save template would come back after you sold something (missing keys get filled in on load) | The kit is laid out once by `SaveData.migrate`, which also moves old Farm Stand goods, prices and rating into the store |
| 10 | Two catalog models stuck out of their cells (the Bulk Bin's lid, the Golden Scarecrow's arms) | Fixed; a test now checks every item's corners against its cells |
| 11 | Wall items on the front wall would cover the shop windows | Back and side walls only |
| 12 | A shopper who finds their crop sold out had no score | It counts like "too dear" (2): nothing they could buy |
| 13 | Six side-bar crates on a phone | Two columns of three (a grid layout on phones) |

Played in Studio on 2026-10-31 (desktop and phone emulation, [PlaytestLog](PlaytestLog.md), screenshots in [playtest/2026-10-31-week3/](playtest/2026-10-31-week3/)): the farm's front, the store inside and out, the staff door, the stockroom, Fill, shoppers in the aisles and the queue, the Store window, levelling up through a new building, Decorate, all four buildings, the phone. It found:

| # | Found | Fix |
|---|---|---|
| 14 | The doorway was glazed (the wall builder sorted its openings in place) | It sorts a copy |
| 15 | Shoppers' bubbles were inside the ceiling | Lower, just over their heads |
| 16 | The construction countdown errored every second and stopped every store's shoppers | Fixed; each store's tick runs on its own |
| 17 | Decorate: the ghost a row off, the awning over the front row, the Highlight not drawn, the grid invisible on white, DONE under the toasts, the camera left overhead | `ScreenPointToRay`, everything over the doors hidden, a glowing footprint, a blue grid, DONE bottom right, the camera back behind you |
| 18 | On a phone the floor was too small to tap | Pinch or wheel to zoom, drag or WASD to move the view (§4.8 Decorating) |
| 19 | Red walls inside the Farm Shop, lamps floating under its gable, awnings over the Market Hall's sign, a square "star" | Plaster inside, lamps on cords, flower boxes, a gold ★ |

Left for later, as planned: Stockers, Cashiers and the Greeter (week 4, with every worker), shoppers while you're away (week 4, the Welcome back card), Trusted friends through the staff door (week 6), the bat and crime around the store (week 5). Still to try with people: C9 (decorate on a real phone, with pinch).

### Change after review: the store keeps growing to Level 18 (2026-10-31)

The user asked for the store to keep expanding with its level as players add more to it, and for a check that every player's plot has room for it. What the check found: the floor stopped growing at Level 13 (12×8, 96 cells) and Levels 14–20 opened none, while the catalog keeps unlocking items to Level 17 and players keep buying displays and decor; with aisles and queues, 96 cells hold only about 45 items, so a late store fills up while its levels keep going. The plot had room to spare: the biggest store used x −71…−21 and z −1…40 of the plot, leaving 8 studs to the hedge and 20 studs of yard before the farmhouse. Every farm's layout is the same, and neighbouring farms are 24 studs apart at the front, so there's no overlap between players.

| Found | Fix |
|---|---|
| No floor from Level 14 to 20 | The floor opens a row or a column at every level up to 18: 12×9, 13×9, 13×10, 14×10, 14×11 (154 cells, +60%). The Market Hall is 12×9 and the Supermarket 14×11; layouts carry over (cells are counted from the door's corner) |
| Where the room comes from | The store's lot runs to the hedge and back to 8 studs short of the farmhouse (`PlotLayout.PLOT.shop`); the strip by the gate stays clear (the way to the staff door, the construction sign) |
| The Supermarket reaches the hedge, leaving a 1-stud gap where the picket fence was | A fence post and its invisible wall close it |
| Nothing checked that a building fits its plot once built | `tests/world.test.luau` builds each building at its biggest on a farm: every part on the lot (eaves and trim within half a stud), the front still closed but for the gate and the store's door. `tests/layout.test.luau` checks the gate strip (6 studs or more), the farmhouse yard (8 or more), the hedge, and that neighbouring farms stay apart |

Levels 19 and 20 open no floor (the lot is full); they bring stockroom space, shoppers and the gold star. A bigger floor is also a bigger coin sink late on (more displays and decor to buy, §6.2).

### Change after review: bigger stores, a bigger valley (2026-10-31)

The user asked for a fresh look at how big the store should be at the start and what a supermarket should be like, with leave to make the world bigger as long as everything still fits. Seen in Studio (week 3's shots), the stores read small. Level 1 was 5×3 cells (20 × 12 studs): a one-cell aisle that the Honour Box's queue ran along, with 2–3 cells to spare. The Supermarket, at 56 × 44 studs and 14 tall, was barely bigger than the 44 × 42 farmhouse, and from the road it looked like a shop window, not a supermarket. Its 154 cells hold only about 75 items with aisles, under the 80 a store allows. This replaces the entry above: the store still grows at every level, but on a bigger plot.

| Looked at | Change |
|---|---|
| The start | Level 1 is 6×4 in an 8×6 Corner Store: the starter kit along the back wall, an aisle in front, the Honour Box's queue up the side wall (no longer along the aisle) and the middle of the floor free for 3–4 new displays (a test places them) |
| The buildings | Corner Store 8×6 (32 × 24 studs), Farm Shop 11×9 (44 × 36), Market Hall 15×11 (60 × 44), Supermarket 20×14 (80 × 56, 280 cells, 1.8× the old one), each clearly bigger than the last. Taller too: the Supermarket 18 studs (was 14), the Market Hall 15, the Farm Shop 12 with a 9.5-stud gable |
| The ladder | Every level opens floor: a row or a column, and both at Levels 4, 5, 10, 15 and 20 (19 steps from 6×4 to 20×14). Each building's whole floor is open by its last level (tested) |
| What a supermarket is | A tall glass front, a deep name band, a canopy over the door, a trolley bay, light strips across the ceiling and a bigger billboard outside; inside, room for long aisles of shelves, a row of checkouts and chillers along the back |
| Room for it | The plot is 220 × 252 studs (was 160 × 240). The store's lot is 83 × 64, with a 7-stud side yard by the hedge, the 6-stud strip by the gate and an 8-stud yard before the farmhouse; the farmhouse and the field moved back 12. The other side of the front gets 72 studs of yard for week 4's warehouse. Eight farms that wide need a front radius of 320 (was 240) to keep the two by the highway clear of it, so the ring road, sidewalk, back trail, valley and hills moved out with them. The town kept its size, so its walks are the same; the green between it and the ring road is 130 studs (ArtDirection §6 now plans it) |
| Walks | Town spawn to a gate 285–345 studs (18–21.5 s, was 13–17 s); police porch to the back of a farm 735–910 (46–57 s); Visit, then round the hedge, about 500 (34 s). The raid race holds: the owner at the warehouse is in reach at 8.1 s (was 7.7; the thief with every defence is safe at 11.4 s), and from town still with 1.1 s to spare, because the farmhouse moved back with the field |
| Shoppers | A bigger store and a longer sidewalk make each visit longer (about a minute in a Supermarket), so 12 at once would have held the late levels back: now 8 / 12 / 16 / 24 by building, and the level-up card says so. Each screen only draws shoppers within 300 studs |
| Items | At most 100 floor items (was 80), so a full Supermarket doesn't run out of items with floor to spare. ArtDirection's part budget goes to 4,000 a farm, with streaming at about 600 studs |
| Decorate | Zoomed all the way in, 18 studs of floor fill the view's height in every building, so the Supermarket's cells are as big to tap as the Corner Store's |

Checked in Studio on 2026-10-31 ([playtest/2026-10-31-store-sizes/](playtest/2026-10-31-store-sizes/)): every building from the road and inside, the stockroom and yards from behind, the farm from above, the farms from the town, Decorate on the Supermarket, and shoppers walking the longer sidewalk, browsing, queueing and paying in it. 288 tests. Not checked: a real phone (the tap size, and the part budget with several full Supermarkets in view).

### Change after review: see-through roofs, with the same light inside (2026-10-31)

The user asked whether roofs should go invisible while players are inside a building like the store, so the roof doesn't block the view, and which buildings should do it. Then, seeing the shots, that the stores were really bright inside, and whether the light could be the same with and without the roof. Then that darkening the outside while you're inside isn't acceptable: an owner in the store must still see thieves on the farm, so the outside has to look the same whether you're inside or not.

**Why it's worth it.** Roblox's follow camera sits about 12.5 studs behind and above your head and jumps in front of anything solid in the way. Under the Corner Store's 10-stud ceiling it's forced right up behind your head; in any store, zooming out to see your displays, price tags, queues and shoppers' bubbles hits the ceiling. Fading the roof on your own screen lets the camera rise over the walls and look down into the room, the way Decorate already does. It's client-only and changes nothing in the game.

| Building | See-through roof? | Why |
|---|---|---|
| Your store, all four buildings, yours or anyone's | **Yes** (now) | You spend time inside filling displays, serving and watching shoppers; visitors come to look around. Corner Store ceilings are 10 studs |
| The warehouses from Warehouse Level 5 (week 4) | **Yes**, when they're built | Enclosed, and you work their stations inside |
| The Packing Shed | No | Open on three sides: the camera is never trapped, and its roof is what makes it read as a shed at the bench |
| The farmhouse | No | No interior |
| The town's buildings | No | Barley's, the Exchange desk, the Hiring Hall's board and the police porch are all used from outside. The Auction House hall (week 7) is 26 studs tall, so the camera fits; decide when it's built |
| The stockroom lean-to | No | It's outside the store's walls, open to the yard |

**How:** a building opts in with an invisible `Interior` part (the room's box) beside its `Roof` model. `RoofController` fades the roof, what stands on it and the ceiling lamps over a quarter of a second as you step in (0.3 studs past the walls), turns the words on its signs off, and brings it all back once you're a stud outside (no flicker in the doorway). A faded roof doesn't stop the camera. Decorate hides the roof its own way, so the controller waits while it's open and hides the roof again if you're still inside when it closes.

**The light inside.** Two problems, found in the shots:

| Found | Fix |
|---|---|
| Even with the roof on, the stores were glaring inside: near-white walls (the Corner Store cream inside and out, plaster 246, the Supermarket white) under up to 6 lamps each as bright as 0.9 | Every building has its own inside colour, none near-white: the Corner Store buttermilk, the Farm Shop and Market Hall warm plaster, the Supermarket pale sage; the lightest floor tiles a step darker (the Supermarket a grey checker, the Market Hall's cream a sandier one); lamps 0.45 |
| With the roof faded, the sun pours in (an invisible part casts no shadow) and the room glares, with sun patches and hard wall shadows a roofed room never has | See below: a stand-in for the roof far toward the sun |

**Keeping the sun out without touching the light.** Roblox's lighting is one setting for the whole screen, so anything done with it reaches the farm outside too. Compared in Studio from the same spots:

| Tried | Inside | Outside | Verdict |
|---|---|---|---|
| (1) Darken the exposure while you're in | dimmer, but the sun patches stay | darker | no |
| (2) Keep the roof but nearly invisible, for its shadow | sunlit: even 97% invisible, a part casts no shadow | same | impossible |
| (3) Your screen lit as indoors (no sun, no sky light) | the same as with the roof | **overcast: it hides thieves in the field** | dropped (built first, then replaced) |
| (4) **A stand-in for the roof far along the line to the sun** | shaded like the roofed room, lit by the open sky | **exactly the same** | **chosen** |

How (4) works: the sun's rays are parallel, so a copy of the roof moved along the line toward the sun casts the roof's own shadow on the room and nowhere else. It's added on your screen only, while the roof is faded (and on your own store while Decorate is open), follows the sun as it moves, and goes at night. How far: Roblox drew the shadow from 600 to 1,500 studs away and not from 3,000, so it sits at 800; a grey copy there showed as a patch in front of the sun, a glowing white one is smaller than the sun's glare and vanishes into it, even looking straight at the sun, and at sunset. Because the room still sees the sky, it's lit like shade outdoors: grey and sage turned blue-white, so the Supermarket's inside went warm (a khaki-sage wall, a warm grey checker), after which it matches the roofed room side by side. Never tried: a ceiling visible only from below (Roblox's runtime meshes, with unproven shadows and ID-verification rules for creators).

**Also found:** the Supermarket's glass front stood on a plinth that ran straight across the doorway, a 1.2-stud ledge that characters stalled at (the user saw it). It stops either side of the door now, and `tests/world.test.luau` checks that nothing solid stands in any building's doorway above the floor.

Checked in Studio on 2026-10-31 ([playtest/2026-10-31-roofs/](playtest/2026-10-31-roofs/)): walking into and out of each building, the camera rising over the walls, Decorate opened and closed inside, each building shaded and with its roof on side by side, the stand-in on and off, looking straight at the sun, a low evening sun, the farm through the windows and over the walls in full daylight, and the stand-in gone when you leave. 288 tests (`tests/world.test.luau` checks the Interior box covers each building's floor, the lamps are in the Roof model, and the doorways are clear). Not checked: a real phone (shadows there, at low graphics, are drawn shorter or not at all: then the roof casts none either, so it still matches), and the night (§4.14 isn't built yet).

### MVP week 4: warehouse levels and workers (built 2026-10-31)

Built: `Config/Warehouse` (Levels 1–20 as a table of what each changes; 4 buildings) and `shared/WarehouseRules` (levels added up, what's new at each, upgrading, buildings going up, routes, old saves); `Config/Workers` and `shared/WorkerRules` rewritten for §4.9 (efficiency 40–100%, wages 60–100%, XP and training, slots by Warehouse and Store Level, the hiring board); `shared/TruckRules` for up to 3 trucks with a bed each; `shared/PipelineRules` with several trucks, the Cold Room's limit, kept crops, grade A shares, Premium contracts, the Greeter, strikes and worker XP; `ShopRules` Stocker rounds and offline sales. Server: `WarehouseService` (levels, the wash table, routes, the Drivers' rule), `TruckService` (a dock, lever and lane per truck), the new `WorkerService` (hiring, training, letting go, the crew at work each second, wages and strikes, the time away and the Welcome back card), Cashiers and the Greeter in `StoreService`, Farmhands in `FieldService`, the Hiring Hall's job board. Client: the Warehouse and Workers windows, the Welcome back card, worker NPCs in their outfits, several trucks driving. Look: the Distribution Warehouse, Big Warehouse and Distribution Center (metal walls, a warm board lining, dock doors in the farm colour, a staff door, the intake door toward the field, windows; stations on a conveyor, a Cold Room, the wash table; see-through roofs), docks with a lever each, a lane and boom per truck, the box truck, semis and reefers. Dev commands: `/warehouse N`, `/hire`, `/crew N`, `/workers N`, `/trainxp`, `/away` (now the real settlement), `/tp hiring`, `/tp dock`. 331 tests; `tools/progression` meets its targets.

Review against §4.6 and §4.9, and what changed:

| Found | Change |
|---|---|
| The Shed Hand (Levels 1–4) has to know what to pack, but routes came with Level 5 | Routes from Level 1 (Truck · Store · Keep); splits from Level 5 (§4.6) |
| Nothing said what workers leave alone | ✋ **Keep**: the crew never takes that crop from the barn |
| The Pack station's tape swipe would be a second minigame per crate on a phone | By hand, one hold at the wash table washes and packs, as at the shed; the crew splits the work into Sort and Pack (§4.6) |
| The Express lane at Level 18 had no meaning | It's the 80-second trip that comes with it (§4.6 table) |
| A Loader feeding the stockroom too would make a store crate wait for a Loader | Store crates ride the conveyor; Loaders load trucks (§4.9) |
| Which Driver drives which truck, which Cashier works which Register | In hiring order: the first Driver truck 1, the first Cashier the first Register |
| Careful (+15% grade A) on a Level 10 Sorter with the Wash Line passed 100% | Careful +10%, and the chance stops at 95% |
| The Watchman watches for Suspects, who only exist from week 5 | He comes with the defences in week 6 (§9) |
| XP kept piling up past a full bar, so a worker could be trained several levels at once | The bar stops when full and waits for Train: levelling is on purpose |
| Offline growth was in the field's join, the crew's settlement would grow crops a second time | The settlement grows them (one place, `WorkerService`) |
| The progression sim's 'workers average 7 by day 14, 9 by day 28' came from a scratch run that gave XP for every minute | With XP only for real work the sim gives 6 and 7 (the first hires 8); kept the rule (it's the anti-busywork guard) and wrote the sim's numbers in (§4.9, §6.2) |
| The warehouse to the back row (raid race) | Measured from the bigger site's middle: 8.2 s (was 8.1); the race comes out the same (the undefended thief escapes, the defended one is caught) |

Not built: rare workers (week 7, with auctions), Night Owls' bonus (needs night, week 7), waving at visitors.

**Played in Studio on 2026-11-01** (PlaytestLog, [playtest/2026-11-01-week4/](playtest/2026-11-01-week4/)): hiring, the Shed Hand, every level by hand and by command, each building inside and out, a full crew and its bottleneck, routes, two and three trucks driving, a strike, the Welcome back card, the store's crew. Fixed there: a level-up that stopped halfway (the Cold Room's sign), trucks streaming in part by part after a rebuild (now persistent models), traits on jobs they don't help (a Careful Farmhand), the Hire buttons below Farm Level 2, a "bottleneck" at the one-station shed, the ladder's tiny milestone text, the Cold Room's lid, plain metal walls (a base band), cream letters on gold, a strike sign hidden by the name tag. Then, at the user's ask, **every screen read again as a new player would**: plain words instead of jargon in the Warehouse and Workers windows ("1 of 2 Sorters · more at Warehouse Level 8", "47% speed", "paid 5.4 coins/min", "🐢 Slowest step", "room for a 2nd Driver"), a first row explaining the pipeline, every choice of the Drivers' rule and the Farmhands' replanting on show as buttons, routes labelled in words, signs over the stations, the job in each name tag, a ⭐ / ! badge on the Workers crate, and the side bar's "WAREHOUSE" no longer cut off (PlaytestLog).

### MVP week 5: raids (built 2026-11-01, played 2026-11-02)

Built: `shared/SackRules` (the Loot Sack: weight, room, value, where loot goes back to) and `shared/PayoutRules` (the payout queue's records, claims and batching), `PlotLayout.climbAt` / `climbPath` (the back fence), a speed share in `MoveRules` (a thief with a sack can't outrun the movement check). Server: `CrimeService` (steal holds timed on the server, the sack and depositing at your door, the bat as a Tool only inside your own farm, swings judged by the server, knockouts with the character anchored and owned by the server, Suspects, arrests and fines, climbing the back fence, the theft alarm, a farm closing when its owner leaves, and every way of leaving: quitting, dying, a shutdown), `PayoutService` (half of a debtor's sales to the owners they owe, the DataStore queue for owners in other servers, the police desk's Pay), hooks in `TravelService` (no travel as a Suspect, knocked out or carrying; a steal stops a channel), `PlotService` (the police porch as the spawn for 2 minutes after an arrest; climbers count as inside), `DataService.Earn` (garnishing) and `FieldService` (a thief takes a ripe crop). Client: `CrimeController` (Steal, Swing, Arrest and Climb on the context stamp with a hold bar; the ring over a crop being stolen; the red ! over Suspects, the red 🧺 name over carriers, dizzy stars; the sack's sign and arrow home; the knockout screen with Leave farm; the BUSTED! mugshot; the theft alarm card and red edge; BONK!, boing and the arrest puff; the reset button off), `PoliceController` (the Police Desk window), the bat in the hotbar, TRESPASSING on the location tag, a slower walk with a sack. Look: the bat, the sack, the back fence's slats with a sign on the trail side and the climb, the Police Station's front (`World/PoliceArt`: blue walls, a gold sheriff's star, barred cells upstairs, a porch with a striped awning, the height chart where the arrested land, Sheriff Clucks at the police desk, a WANTED poster that says how arrests work). Dev commands: `/ko [suspect]`, `/suspect`, `/sack`, `/debt`, `/earn`, `/crimelog`, `/plant`, `/tp back`, `/tp field`, `/tp police`. 351 tests.

Review against §4.10–4.12 and §5.4–5.5, and what changed:

| Found | Change |
|---|---|
| Emptying the sack had no action of its own; a button you must find at your barn while being chased is one more thing to learn | The sack empties on its own when you reach your farmhouse door (`Crime.DEPOSIT_RANGE`), with "+🎃 Pumpkin ×2 (stolen) in your barn" (§4.10) |
| A climb you hold for 1.5 s could be let go halfway, leaving someone on top of the fence | One press: the server lifts you up, over and down in 1.5 s; you can't move meanwhile, and a bonk knocks you back down on the farm's side (§4.10) |
| An owner standing on a ripe crop with a friend beside them would only ever see SWING | The stamp says SWING for a Suspect (or a sack carrier) near you; for anyone else only while the bat is in your hand (§4.12) |
| The bat only hit in front of you, and in the play-test most swings at a thief beside or behind the owner missed (a kid pressing a button that names the target won't understand a miss) | A swing turns you to face the nearest person in reach first and lands after a short wind-up; within 3 studs (`Crime.HIT_CLOSE`) it hits whichever way you face. The server still checks the reach, the line and the arc beyond 3 studs (§4.12) |
| A thief being arrested could be bonked again during the BUSTED! card and arrested twice | Nobody can be hit on their way to the police |
| The theft alarm is in week 6, but without one the owner of a raided farm never knows | Built the core now: the alarm card ("🚨 Sam is stealing your 🎃 Pumpkin!", with Go home when you're away), the red edge, the red ! seen from anywhere. The edge arrow, the camera picture, the scarecrow's warning and the farmhouse light stay in week 6 (§5.4) |
| Debt payments arrived as silent coins | Notes to both, at most every 30 s (store sales come every few seconds) |
| Owners need debtors' names at the desk, but other servers' players can't be looked up by id in Studio | Each debt keeps the owner's display name |
| The Police and Payout services had one job between them | One `PayoutService` (debts, the queue, the desk) (§8) |

Not built yet (by plan): the Sprout Shield, arrival grace, the raid cap's dome (the cap itself works), Trusted friends (week 6); cloches and the Harvest Moon's quicker holds (weeks 6–7); the Sheriff and Most Wanted boards (week 8; arrests already count per pair per day); coins in trades while in debt (week 8); auction refunds paying debts (week 7); sounds (the siren and cash, week 9).

**Played in Studio on 2026-11-02** (PlaytestLog, [playtest/2026-11-02-week5/](playtest/2026-11-02-week5/)), solo for the art and with a 2-player local server for raids: steals and the alarm, the sack and its walk home, bonks on a Suspect and on an innocent visitor (Leave farm), arrests (paid, and into debt), half of a debtor's sale paid to the owner, the police desk, climbing in as a Suspect, quitting while knocked out (fled: fined ×1.5, the owner paid at once), Home refused to a Suspect, Respawn greyed out. Fixed there: the hold bar under the chalkboard, the alarm's red edge never fading, swings missing a thief beside or behind you, the knockout card's Suspect line; by eye the sack (an egg beside the character → snug on the back), the bat's length, the porch roof (a flat navy slab → a striped awning with a striped flap along its front, since from the square the roof is seen edge-on), Sheriff Clucks' comb and eyes, the poster behind the bench, the door lamps; and in plain words the refusals and notes a new player would meet (PlaytestLog). Not covered: leaving with loot (chased and not), dying while knocked out, rejoining on the porch (Studio can't rejoin), the payout queue between servers, lag, a phone, 8 players.

### MVP week 6: defences (built 2026-11-02)
Built: `Config/Defences`, `shared/DefenceRules` (buying, where each defence stands, what it does, the Trusted list, whether a gate stops someone), `CrimeRules.shieldLeft` and `raidFreeAt`; server `DefenceService` (buy, place, put away, Trust, Untrust, Drop shield, the camera's visitor list; the Sprout Shield and arrival grace as ShieldUntil/GraceUntil; the domes; the gate; the scarecrow; the dog; the Watchman's bell, spotlight and gate), wired into `CrimeService` (protection, Trusted, cloches, the Tall Back Fence's climb, climbing a locked gate, the alarm), `FieldService` (Trusted friends water and harvest), `StoreService` (the staff door opens for Trusted friends), `WorkerService` (the Watchman); `World/DefenceArt` (the back fence both ways, gate leaves on every farm, the alarm light, the kennel, the gatehouse, the domes, every defence) and the meshes in `tools/crop_art/defences.py`; client `DefenceController` (the 🛡️ Defend window, setting things out, the scarecrow's card, the Farm Rules card), `GateController` (gateways and the staff door on your own screen, mud), `WatchController` (the dog, the alarm light and flag, the spotlight and bell, the dome timers), and in `CrimeController` the alarm's edge arrow, the camera's live picture, the Watchman's line, why you can't steal (a shield, the Neighbourhood Watch) and climbing a locked gate. Dev: `/shield off|on`, `/defences all|none`, `/trust Name`.

Decided while building (each a small call the doc left open):

| Question | Decision |
|---|---|
| Floodlights only work at night, and night comes in week 7 | They come with night (week 7, ArtDirection §11 step 12): selling something that does nothing yet would be a trap |
| Where do defences go? ("placing mode with glowing spots", §5.3) | 26 **yard spots**, 12 studs square, in a ring 3 studs off the field (its two sides and the strip behind it, by the back fence): the scarecrow, the kennel and mud patches each take one. Cloches go over open tiles. The Gate Lock, the Tall Back Fence and the camera have their own place and go up as you buy them. Setting out shows your field from above with a green spot wherever it can go; tap one to set it there, tap your own to put it away |
| The dog's 30 studs: from what? | From its kennel, so where you put the kennel is the choice (behind the field covers the back rows, where the raid race's thief steals). Its reach is drawn as a gold ring while you place it |
| How many cloches? | Up to 16 (a quarter of a full field): enough for your rarest crops, not a glass farm |
| Whom does mud slow? | Anyone but you and your Trusted friends: it's your yard |
| Does the scarecrow say who? | Yes ("👀 Sam is near your crops"), unless you're close enough to see them yourself; once a minute per person |
| The Watchman's gatehouse | It goes up when you hire one (the cream cube on every farm is gone); he stands at its window over the gate. He learns while he's on watch (your farm only exists while you're in the server, so not while you're away) |
| The scarecrow, kennel and gatehouse stand-ins | Gone: they only appear once bought. Every farm now has real gate leaves, standing open against the yard, swung shut with a padlock and a PRIVATE FARM sign by the Gate Lock |
| Dropping the Sprout Shield early ("Settings", §5.6) | There's no Settings window yet: the Defend window shows the shield's time left with **Drop it now** (tap twice) |
| Trusted friends harvesting for you | The crops go to your barn; you get a Farmhand's share of the XP (half), they get none (no farming XP off friends) |

**Played in Studio the same day** (PlaytestLog, solo and with 2 players: a raid on a defended farm): everything works as written. Fixed there: the placing spots couldn't be pressed, the HUD covered the placing view, the alarm's edge arrow was a blank circle, the camera's picture too wide to see the thief, the scarecrow's card on top of the alarm, the Farm Rules card's last line over its pictures, three dev commands reading the wrong word, and by eye the mud's puddle, the dome poking out through the back fence and the camera too small. Not covered: the Camera tab's list, a phone, 8 players (Stage D).

### Change after review: raids rebalanced, and a bonked thief drops the crop (2026-11-02)

The user: "I noticed there are a lot of defences to stop someone stealing a crop successfully such as the gate auto locking by the watchman. Determine if it is too difficult for someone to steal and escape and any measures to this." "And determine if it is too easy to get those defences." Then the rule to tune to: "The game should favour the farmers slightly more than a thief overall but if a farmer is slow then a thief should be able to run away with the crop. Because if thieves can steal a farmers crop too easily, farmers will get too frustrated". And: "Make it so that the crop drops on the ground for anyone to pick up when you bonk the thief", "farmers should hold take back too like anyone else".

| Found | Change |
|---|---|
| With everything set out, a Rare thief lost to a farmer reacting in 1 s by 8.2 s (door), 7.3 (warehouse), 5.2 (town): no raid could work, even on a slow farmer | Re-timed (the table in §4.11): fully defended, a watching farmer in town wins by 1.2 s, a busy one in town loses by 0.3 s, a busy one at home still wins by 1.9 s |
| The Tall Back Fence slowed climbing **in** as well as out (+4 s a raid) | Only climbing out with a stolen crop: 3 s (was 3.5 both ways) |
| The race never counted that climbing in alarms the farmer before any steal (with a Gate Lock, every way in does) | `tests/lib/raidrace` now times the whole raid from the first step in: climb in, run, steal, run out, climb out, for each set of defences, and the farmer from the door, the warehouse or town, sharp or slow; five tests hold the target |
| A cloche doubled a steal | ×1.4 |
| The dog grabbed during the steal hold, so its slow mostly ran out before the thief ran | It barks as the steal starts and runs at the thief once they have the crop: 30% slower for 2 s (was 40% for 3 s, wasted) |
| The Watchman shut the gate on every alarm, climbing in included, 15–30 s, on any Suspect | Once per theft, as the thief takes the crop, 10–20 s, only on that farm's Suspects carrying a stolen crop; when it lifts they walk out |
| Mud slowed 30% | 20% |
| Every defence opened by Farm Level 9 (about 2.5 h of play) for about 265,000 coins; the Gate Lock and Tall Fence during the Sprout Shield | One at a time from Level 5 to 24, about 3M coins (§4.11's table); the Watchman at Farm Level 20 |
| A bonked thief's crop went straight back to the barn: no scramble, nothing for a second thief | It drops on the ground for 30 s: TAKE BACK (owners and their Trusted friends) or GRAB (anyone else), 1.5 s holds, first to finish wins (§4.12) |

Built: `Crime.GRAB_HOLD`, `DROP_REACH`, `DROP_SECONDS`; `LootRules.dropRole`, `CrimeRules.canGrab`; `CrimeService` drops the crop (`CrimeArt.dropped`, tagged `DroppedCrop`), the `PickUpStart` / `PickUp` / `PickUpCancel` actions, the 30 s return and what happens when an owner leaves; `DefenceService.OnTheft` (the dog's run, the Watchman's gate) apart from `OnSteal` (the bark); `DefenceRules.fenceClimb` by direction and hands, `gateBlocks` with `carrying`; the client's TAKE BACK / GRAB stamp, the dropped crop's label, the grab alarm and the Watchman's line once the gate shuts; the Farm Rules card ("they drop your crop", "Then TAKE BACK your crop!"). Tests: the dropped crop's roles and the grab's checks, the fence by direction, the gate with empty hands, the new prices and levels in order, and the raid race's target.

**Played in Studio the same day** (PlaytestLog, [playtest/2026-11-02-drop/](playtest/2026-11-02-drop/), solo and with 2 players twice): the drop, its label and the 30 s return, TAKE BACK after a bonk and after an arrest, GRAB by the woken thief with the farmer's alarm and the Watchman, a 3.5 s cloched steal, and the Tall Back Fence timed at 1.5 s in and 3.0 s out with a crop all work as written. Fixed there: the label floated over the character beside it; "🎃 ×1" sat on "BACK" in the stamp (and on HANDS FULL's); Take back's bar filled red; the thief read "A thief dropped it" about their own crop; and the one that mattered: as the thief woke up beside their crop the farmer's stamp said SWING, though for 6 s a bonk only nudges them, which hid TAKE BACK just as the thief could grab it (SWING now drops below TAKE BACK while someone's immune, and says why; a pick-up hold keeps the stamp). In passing: no more ARREST over a thief already arrested (a `Busted` attribute). The next day (the user: "Can't you give yourself commands to unlock those areas and levels so you can test it?", "Make sure only one person can get it"), with a new `/land all` opening the whole field: the dog barked as a back-row steal started, ran the moment the thief had the crop and slowed them 30% for 2 s half a second later; and two clients finishing a pick-up at the same server moment (3–4 ms apart, twice) gave the crop to exactly one of them each time, the other getting "Gone" (the claim is one explicit step now, `LootRules.takeDrop`, with a test).

### Review: the back fence and the front gate as ways out (2026-11-03, no change)

The user: "So a thief can escape from the back fence and the front gate right? Which way is quicker?", then "Determine if escaping from the back and front needs rebalancing". Timed from the layout for every column of the field, normal and Tall Back Fence, with and without the Watchman shutting the gate, and on an undefended farm against a sharp and a slow farmer (the table and reasons in §4.11, "Why thieves leave over the back fence"). The gate is never the quicker way out, and that stays: one predictable exit favours the farmer, gives the back-fence defences their job and makes the field's front-to-back risk a planting choice. Noted for week 7: the Watchman's gate shut only catches thieves who try the front, so his worth is the bell and the spotlight, to be judged again once night makes the spotlight matter.

### MVP week 7: weather, night, the Auction House, quests (built 2026-11-03)
Built: `Config/Weather` and `shared/WeatherRules` (the 24-minute day, the weather in 4-minute slots, the Harvest Moon, mutation rolls and values, Heist Night; `tools/weathershares` measures the shares), the weather in `FieldService` (growth at its speed, a mutation roll on every ripe crop left out every 30 s, mutated barn stacks), `CrateRules` (a mutated crate sells at its multiple, by truck only), `LootRules` (a stolen mutated crop is worth its multiple for the fine, and says so), Heist Night in `CrimeService`, Night Owls in `WorkerService`; client `SkyController` (the light from day to night and each weather's look, rain, frost and gold dust round the camera, lightning, the Harvest Moon's violet sky and huge orange moon, lamps and windows at night, name tags at night, the Floodlights' outlines, the sky dial and the weather's notes) and a mutation's aura in `FarmArt`. Floodlights (`Config/Defences`, `DefenceArt`: four lamp posts at the field's corners). The Auction House: `World/AuctionArt` (the hall), `AuctionService`, `AuctionRules.describe` and `canWin`, `AuctionController` (the bid card, the board, Goldie's calls, the bell, confetti, the notes with a Town button), rare workers (`Config/Workers.CONTRACTS`, the Tireless trait). Quests: `Config/Quests`, `shared/QuestRules`, `QuestService` (hooked into harvests, trucks, the store, arrests, stolen crops taken home and auction wins), `QuestsController` (the Quests window: Today and Cropdex). Dev: `/weather X`, `/time`, `/auction now`, `/tp auction`. 469 tests, no flicker.

Decided while building (each a small call the doc left open):

| Question | Decision |
|---|---|
| Is the weather each server's own? | Worked out from the time, the same everywhere (like the restocks): every player's sky matches, the client needs no messages, and "Rain at :20" is the same for friends in other servers |
| How does a schedule give the doc's shares? | 4-minute slots, each rolling its weather from its number: odds per slot that give Clear 55%, Rain 20%, Thunderstorm 8%, Frost Night and Golden Hour 7% each (measured 55/21/9/7/7); a crop left out through a whole Rain still turns Wet about 1 time in 5 |
| How do mutated crops sell? | By truck only, at their multiple, washed at the wash table by hand (the crew sticks to plain stacks, so their numbers stay simple). Store shelves would need each slot to track mutations: later, if testers miss it |
| Giant crops | Left out: a Giant whole patch at 2.5× doesn't fit its tile. Decide what a Giant looks like first (one huge fruit for single crops?), then build them with their Cropdex records |
| Golden tools and cosmetics at the auction | Not yet: the tools have no designed effect and the cosmetics come with week 9's cosmetics. Their share went to the other lots, Mythic seeds keeping 8%. Defence lots are worth their real price now (the dog 600,000, the camera 800,000), not the old estimates |
| A lot you can't take home (a defence too early or too many, no slot for a rare worker) | You can't bid on it: the card says why. If it still can't go home when it's won (you bought one meanwhile), the coins come back |
| Floodlights' price and level | 120,000 at Farm Level 10, between the Gate Lock and the Tall Back Fence: night comes from day 1, so the counter shouldn't wait for late game |
| "Anyone in your field" for the Floodlights' outline | Anyone in your farm who isn't Trusted, at night: a thief at the warehouse matters as much |
| Quest rewards late in the game | Targets and coins grow by Farm Level tier (×4 from Level 8, ×15 from 20): 2,000 coins means nothing at Level 30. Re-check with live data |
| Where are quests and the Cropdex? | One **Quests** crate on the side bar, two tabs (Today, Cropdex), a green ! while something is waiting. The streak is claimed when you join (no button to miss) |
| The town's look (week 7's other half) | After a play-test of the systems: the plaza, clocktower, façades, park and lamps are a big art job of their own |

**Played in Studio the same day** (PlaytestLog, solo and with 2 players: two bidders; the Floodlights and night name tags): it all works as written. Fixed there: the sky dial sliding under the coin sign, rain you couldn't see (and rain falling inside the Auction House), a mutated crop lost among ripe Rare sparkles (a haze of its colour now), the Harvest Moon a dull disc in the haze and in the south (drawn over the haze now, hidden behind anything solid, in the north), Golden Hour turning the hall's red walls neon, Goldie's floating name over the lot board (on her podium now), the lot drifting off its pedestal and over the board, the confetti, the bid card silent when you're short of coins or of a slot for a rare worker, the same lot twice in one auction, numbers without commas, the 🪙 emoji Roblox can't draw, the Cropdex's "???" (unfound crops now show their names in grey), a mutated harvest not counting the plain crop, and the hotbar crashing with two kinds of seed (a week 1 bug the auction's seeds set off). Then the parts left over (the next PlaytestLog entry: storms, frost, the 1-minute note, quests' arrests and stolen crops taken home, a leading bidder leaving, a phone, 8 players) all work. Fixed there: a storm's flash alone looked like a glitch (a forked bolt strikes off to one side with each one now), frost you couldn't see, notes with a button gone before you could press them (12 s now), the bid card over the Town signpost on phones (smaller, top right), the seventh side-bar crate on the thumbstick, amounts without commas in the fine, debt, payout, truck and strike notes, the level-up hidden under the ARRESTED card, and a leading bid's coins at a server shutdown (the hold is in the save now: §4.4). Left for testers: a several-bidder auction with 8 players.

Not built (by plan or left): the town's look (built the next day: the next entry), rain darkening the soil, puddles and the rainbow after, sparks on crops in a storm, frost on the ground and breath puffs, the lot flying to the winner, sounds (the bell, thunder: week 9), Giant crops, mutated crops in the store, golden tools and cosmetic lots, the Farm Log, leaderboards (week 8), server announcements for Mythic ripening.

### Change after review: a real auction room, paddles and patter (2026-11-04)
The user: "I also need you to make auctions more fun and interactive. Allow players to hold a number sign for bidding, when they bid, they hold their sign out and call their bid. Make it like how a real auction goes." Then: "Add some animations too".

| Question | Decision |
|---|---|
| The number sign | A **bidder paddle** (`World/AuctionArt.paddle`: a wooden handle, a cream disc with the number in red on both faces), in the right hand of everyone inside the hall (`AuctionService`, every 0.2 s from the trusted position; gone when you leave, or carry something) |
| Whose number | 10–99, shuffled per server (`AuctionRules.paddleNumbers`), handed out as people first come in, kept for the server's life (the player's `Paddle` attribute) |
| Holding it out and calling the bid | A bid sets the character's `PaddleUp` and `PaddleCall`: every screen raises that paddle overhead with a shake (`PoseController`, an IK like the bat's; your own at once) and pops a speech bubble over them with the amount (`AuctionController`) |
| Like a real auction | Goldie's patter by paddle number (`AuctionRules.patter`): she opens each lot asking for the opening bid, takes each bid ("48,000 from paddle 47! Do I hear 50,400?"), turns to the bidder who was just outbid ("Back to you, paddle 47"), keeps asking when it goes quiet, then going once, going twice, SOLD to the paddle. The card's big button is RAISE PADDLE for what she's asking; +10% and +25% are jump bids |
| Animations | No animation assets (they'd need uploading): the arms are IKs every client drives (paddle up, the winner waving it with the other arm up and a hop), Goldie's head and gavel are her own parts turned on each screen (turning to the bidder, nodding as she talks, the gavel coming down on going once, twice and SOLD), the call bubbles pop in and fade |
| Quiet settings | Reduced motion: no pop, no nod, no hop, no pulsing button |
| Sitting (the user, the same day: "Allow players to sit down on the benches and bid too.") | Five invisible Seats on each bench, facing the stage (`World/AuctionArt`), each with a **Sit** prompt (only the nearest one shows); `AuctionService` seats you (off your old place first, so you can move along a row), hides a taken place's prompt, and says no with your hands full. You bid from your seat as standing (the hall check is your position; `MovementService` already trusts a seated player); the paddle's IK raises it from the sitting pose. A note the first time: "Take a seat! Raise your paddle from the card to bid. Jump to stand up." `tests/world.test.luau` checks 30 places, invisible, untouchable, on a bench, facing the stage. Played in Studio the same day: sat down with E, bid from the seat (the paddle up from the sitting pose), stood up with a jump, no movement-check warnings |

Checked: `tests/auction.test.luau` (paddle numbers 10–99, each once, shuffled; Goldie's opening ask, her repeat, "any bids?"; a bid taken by paddle number with the next step; "back to you"; "I have ..."; going once and twice with the gavel). Played in Studio the same day (PlaytestLog, solo): the paddle, a bid, Goldie's whole patter with her head and gavel, a win, the card, 5 lots, Barley's rack. Fixed there: the paddle held over the face (beside the head now), the call bubble hiding the raised paddle (beside the head, on the bidder's other side), the IK unable to point a paddle up from an arm overhead (the IK places the hand; the paddle is hung from the upper torso at that spot, each part at its `Grip`), the raised arm across the face (up beside the head). The poses can be tried from the command bar (`workspace:SetAttribute("Pose_paddle_up_hand", ...)`, `Pose_slow`). Still to try with two players: "Back to you", someone else's paddle going up.

### Change after review: 5 lots, rarer is rarer, Mythics only at the auction (2026-11-04)
The user: "lets make auctions auction 5 items per auction. Add rare + uncommon stuff too, they should start at a lower price than the shopkeeper. Make rarer stuff more rare." Then, seeing Barley's Mythic tab: "You can see the price going out of it's own price tag. The shopkeeper shouldn't sell super rare seeds at all, they should only appear at the auction."

| Question | Decision |
|---|---|
| How many lots? | 5 (`Auction.LOTS`): 5 × 60 s and 10 s gaps is about 6 minutes of the 8, so the schedule stays |
| What's new in the pool? | Uncommon (30%) and Rare (26%) seeds. Not Commons: Barley always has them |
| Rarer is rarer | Epic 37% → 17%, Legendary 25% → 7%, Mythic 8% → 3%, rare workers 18% → 10% (Speedy Sam twice as often as Grandma Rose), defences 12% → 7% (Cloche 3 : Guard Dog 2 : Camera 1). With 5 lots, an auction has a Mythic about 1 time in 7 (was 2 in 9), a Legendary 3 in 10 (was 6 in 10) |
| Cheaper than the shopkeeper | Every lot opens at 40% of its estimate, which for a seed is Barley's price (a test checks every seed and defence opens below its price) |
| Cheap lots' bids | Steps that suit the lot (10 / 50 / 100 coins by size), so a Corn seed's three quick bids are different amounts (380 · 400 · 450) instead of three 500s |
| Which seeds leave Barley's? | Mythic only (`Rarities.atBarleys = false`): no Mythic tab, never in stock (not even with the dev full-stock switch), and a buy is refused ("AuctionOnly"). Legendary stays at Barley's (8% of restocks): it's 7% of auction lots now, too rare to be the only source for Lv 16+ farms |
| The price tag | It was 92 px wide whatever the price, so 6-figure prices ran off it; it grows to fit now, with the stock beside it |
| The "auction's on" note | Lists five icons and names the star lot (the one worth most), instead of five names |
| After the last lot | Says when the next auction really starts (it said "in 8 minutes" though the next one starts at the next 8-minute mark) |

Checked: `tests/auction.test.luau` (5 lots; no Commons; shares fall with rarity; Mythic ≈ 3%; the item weights; every seed and defence opens below its price; a cheap lot's bid steps) and `tests/seedstock.test.luau` (no Mythic ever, even with the full-stock switch; "AuctionOnly"; Legendaries locked to Lv 16). `tools/progression` still meets every target; late income is lower (the casual player's Lv 28 on day 34, was 31), partly because the sim leaves auctions out, now the only Mythic source. Not checked in Studio yet (the auction window with 5 lots, Barley's rack without the Mythic tab and its wider tags).

### Change before publishing: staff in a community's game (2026-11-04)
The user asked how to publish the game as a community (group), like other games are. Steps in [RobloxPage.md](RobloxPage.md) ("Publishing as a community"). The review found one thing in the code: `Util/Staff` only counted the owner when a user owns the game, so under a community nobody could use the support commands (`/trades`, `/rollback`) in a live server.

| Question | Decision |
|---|---|
| Who's staff in a community's game? | Anyone ranked `Staff.GROUP_RANK` or higher in that community: 255 (its owner only) until a role is chosen, plus `Staff.USER_IDS` and everyone in Studio, as before |
| Roblox can't be asked for the rank | Not staff that time (no error); Roblox keeps a player's rank while they're in the server |

Checked: `tests/staff.test.luau` (a user's game, a community's owner and its other members, someone whose user id is the community's id, a lowered `GROUP_RANK`, the rank lookup failing, `USER_IDS`, Studio). Not checked in a live server (it needs the game published to the community).

### Change after review: a mutated crop can upgrade (2026-11-04)
The user asked whether crops mutate while growing or once ripe, and whether a better mutation replaces one already on a crop. Ripe only (every 30 s while left in your field, while you're playing); and no, a crop kept the first mutation it got, so a crop that turned Wet early could never become Moonlit. The user: "let a crop upgrade to a better mutation when it gets one; This way it allows players to decide whether they harvest now or wait for a better mutation but also at the risk of it being stolen away."

| Question | Decision |
|---|---|
| Which mutations replace which? | Only one worth more (`WeatherRules.better`, by `Weather.MUTATIONS[].value`): Wet ×1.3 < Golden ×2 < Frosted ×2.5 < Shocked ×3 < Moonlit ×5 < Rainbow ×8. A lesser roll changes nothing, so leaving a crop out never makes it worth less |
| What does the owner see? | The aura changes colour, and a note says what it was and what it is now ("Your 🥕 6 Wet carrots turned Shocked: worth ×3 now!") |
| The risk | Unchanged: a mutated crop is still a ripe crop, with its aura showing thieves it's worth more, and a thief takes it with its mutation |

Checked: the rule in `tests/weather.test.luau` (only up, never down, a roll of nothing changes nothing, a crop climbing Wet → Shocked → Moonlit through a run of rolls). Not checked in Studio (the same roll loop and drawing as before).

### Play-test notes from the user, 2026-11-04: the staff door, seeds in hand, E, our own prompts, the paths, a real checkout

The user played and sent a short recording and five screenshots with six problems, asking to follow the standing rules for each. What was wrong, and what changed:

| # | Found | Change |
|---|---|---|
| 1 | "The shops door keeps opening and closing" (the recording: the STAFF ONLY door flapping twice a second with the owner beside it) | The server measured the owner's distance to the door's **leaf**, which swings 100° away as it opens, so opening it put you "out of reach" and it shut again. It now measures across the ground to the doorway (which doesn't move), and once open it stays open 2 studs farther out (`StoreService`, `STAFF_DOOR_SLACK`) |
| 2 | "A player cannot unhold a seed. If a player is trying to plant without holding a seed, open an interface where players can select their seeds." | Tap the seed you hold (or its key) to put it away; no seed is picked for you at the start or when one runs out. Plant with nothing in hand opens the **seed picker** (every seed as a big packet, locked ones greyed with their level) and plants what you pick (`HotbarController.openPicker`, `FieldController`); the guide's first hint says so (§5.2) |
| 3 | "There is no indication that you can press E to plant or water." | A key cap on the context stamp's rim: E on a keyboard, the button's picture on a gamepad, nothing on a phone (`UI.keycap`, `UI.setKey`). E also no longer stops working beside another player (their [T] Trade prompt counted as "a prompt is showing") |
| 4 | "Are we going to have our own custom gui prompt?" | Yes: every prompt is drawn Kraft & Crate (a wooden sign, the same key cap, gold fill as you hold, a tap or click works too) (§5.6, `PromptController`) |
| 5 | "The props are good-looking, however the pathway looks too plain." | The farm lanes and each farm's gate-to-field path are dressed with low-poly tiles: two worn ruts in broken lengths, dirt spilling into the grass with a wavy, bitten edge and grass growing at it, pebbles, and grass clumps, wildflowers and stones along the verges (`World/PathArt`; `PathWear1–3` and `PathEdge1–3` in `tools/crop_art/valley.py`, in the props file: **re-import PropModels**). A first try in parts (straight tongues and strips) read as planks laid beside the path in the preview, so it was redrawn as meshes before Studio |
| 6 | "There is no real checkout in the shop. Players will need to do the checkout job when customers pay before they can hire workers who does that for them." | The Honour Box (which served itself) became the **Shop Counter**, a till you serve at: Scan each thing, then Take the coins; Cashiers from Store Level 3 (§4.8 "Serving at your till", §4.9). It stands just inside the staff door. Old saves: each Honour Box turns into a counter where it stood if there's room behind it, else on the starter spot (`SaveData`, tested). A new Farm Guide step, "Serve a shopper at your counter" (§4.0). Sounds: `Scan` and `ShopBell` generated (silent until uploaded, like the others) |

Checked before Studio: 545 tests (the counter's layout and queue, the migration both ways, Cashiers from Store Level 3, the guide's nine steps), no flicker, the paths in `partview` (views `path`, `pathside`, `lane`, `laneside`). The pacing sim leaves store sales out, so its targets don't move; the store now earns only while you (or a Cashier) serve, which is the point.

Noticed in passing (left for later, not asked): the seed isn't shown in the character's hand (only the packet standing up in the hotbar shows what you hold); a held seed bag would match how most Roblox farming games show it.

**Checked in Studio on 2026-11-05** (PlaytestLog, [playtest/2026-11-05-checkout/](playtest/2026-11-05-checkout/), 18 shots; solo and on an emulated phone): the staff door stays open (0 flips in 9 s), the picker plants what you pick, E and taps on our prompts, the paths by eye (farm path and lane), serving start to finish (scan, take, the drawer, the next shopper, "Serve me!" when you step away), a Cashier taking over at Store Level 3 and handing it back when let go. The user added two things mid-check, both done in it:

| Asked or found | Change |
|---|---|
| "Customers should not go behind the counter." (their walks could cross the cell inside the staff door) | Staff-only cells behind every till (`StoreLayout.staffOnly` / `closedToShoppers`): shoppers' walks, corner-cutting, queues and fallback spots avoid them, and Decorate refuses a display whose front is one; a test walks every cell. In Studio: 0 of 1,092 samples behind the counter |
| "Customer needs new art." | New shoppers (ArtDirection §8): Roblox-shaped, with faces, hair and hats, six outfits, kids and old-timers, a wicker basket showing their crop, arms swinging; the server sends the basket's crop with each walk |
| The path's straight edge showed inside the spilt dirt, and the ruts read as boards | The dirt 0.05 under the path's top, darker palette colours, flat ruts (props re-imported) |
| On a phone the prompt sat under the HUD, out of reach | Prompts drawn on the screen above the HUD, hidden behind windows |
| The receipt ran into the purse and rosette on a phone; the picker was a big window for one row and stayed open after walking off; the E cap on a device with no keyboard; an error from a prompt's late reset; analytics logged every level-up as an error (no level name) | The receipt at the right edge on touch screens (168 wide on a phone); the picker as tall as its rows and closing when you leave the soil; no cap without a keyboard; the reset holds its own reference; level-ups named ("Store Level 3") |

Left: workers keep the old blocky body (the user asked whether they have their own art: their uniforms, yes; the body, not yet; done the same day, below). Shoppers in a queue stand close enough that baskets touch the next person.

### Change after review: what shoppers say, which way they face, the HUD's ropes (2026-11-05)

The user: "Can you adjust the customers comments? What does "Too dear!" mean? Add some more, including negative ones too", "I noticed an issue with the customers where they will face the checkout counter when they are buying; The process needs to be smooth.", "The ropes holding the time and coins are not starting at the very top."

| Asked | Change |
|---|---|
| "Too dear!" (British for "too expensive") wasn't clear, and shoppers said little | Pools of plain lines (`Config/Shop.LINES`), one picked at random: a bargain, a nice remark or a grumble about the price when they buy (by how the price felt: your price ÷ what that shopper would pay, which `ShopRules.pick` now returns), "Too expensive!" or, far over, "What a rip-off!" when they won't, "Sold out?!", "Queue's too long!", "Hello? Anyone?" at an empty till, "Terrible service!" when it's slow, "Thanks!" at the till, "Huh? Where'd it go?" after a re-decorate. Bubbles are green when pleased, red when cross |
| They turned to the till while still picking at a shelf | The server sends their next walk (to the queue) the moment they choose, to start after they've browsed; the client turned them to its end straight away. Now they keep facing the shelf until the walk starts, and every turn is gradual (540° a second) instead of a snap: arriving, at corners, in the queue (`ShopperController`) |
| The ropes stopped short of the top | The coin sign's and the sky dial's ropes run up off the top of the screen on any screen (400 px; 60 stopped below Roblox's top bar) |
| "Instead of british slang, why not add some New Zealand slang?", then "keep the current ones, add kiwi slang as new ones" | Every pool keeps its plain lines and gains Kiwi ones: "Sweet as, what a deal!", "Choice!", "Chur!", "Good kai!", "Yeah, nah. Too pricey.", "Bit spendy for me, bro.", "Sold out? Gutted!", "Kia ora? Anyone?", "Far out, so slow!", "Ka kite!" (what they mean is noted in `Config/Shop`) |
| "Just make sure all those scenarios do come up so the comments are used." | Checked every one. The price reactions come from how the price felt (`ShopRules.reaction`); at the price a store starts with, of every shopper looking at a shelf about 6% call it a bargain, 25% say something nice, 16% grumble it's pricey and 28% won't pay; priced at 1.3× about 6% call it a rip-off, at 1.6× 28%, at 2× 72%; at 0.7× 58% call it a bargain. One was nearly never said: "sold out" only came when someone else emptied the shelf while a shopper walked to it; a shopper who wanted a crop that had already sold out skipped it without a word. Now they say so. The rest each have their moment: a full queue, an unserved till, a slow one, paying at a till, a re-decorate. A test sweeps prices for every reaction and checks every pool is said somewhere |
| Checked in Studio the same day (PlaytestLog, [playtest/2026-11-05-shopper-lines/](playtest/2026-11-05-shopper-lines/)) | Every kind came up in play, logged line by line; the ropes, the facing and the bubbles' colours by eye. The user asked mid-check whether goods go back when a shopper leaves without paying: yes (85 on the shelf, 30 bought, 44 put back by three who gave up: 99). Found there and fixed: a level-up card that came up while decorating was put back on at DONE after its timer had run, and stayed on screen for good (`DecorateController`: DONE brings back only what was showing before; the level-up card shows over Decorate) |

### Change after review: the workers get the shoppers' body (2026-11-05)

The user, after asking whether workers have their own art (their uniforms did; the body was the old one with a ball head): "continue with the art for the workers".

| Asked | Change |
|---|---|
| Workers in the new shoppers' body | One body for every NPC (`client/People`): the classic head with a face, blocky arms and legs with hands and shoes, hair as a shell over the top and back. Shoppers are built from it unchanged (the same person for the same look). Workers wear their uniform over it (ArtDirection §8, `client/WorkerLooks`): Farmhand green dungarees and a straw hat, Shed Hand a kraft bib apron and red cap, Sorter a blue apron, cap and yellow rubber gloves, Packer a brown apron, Loader a hi-vis vest with two bands, a hard hat and work gloves, Driver a work shirt with a collar and a red cap, Stocker a green polo and cap, Cashier a red apron with a name badge, Greeter a gold sash with a rosette, Watchman a yellow raincoat, a guard's cap and a torch (the art doc said so; the Watchman had a navy shirt and sash) |
| (with it) | Skin from the worker's look as before; hair (short, a bob, a bun, a ponytail, curls; a few going grey or bald) from their look and their own id, so two with the same look aren't twins. Legs and arms swing from the hip and shoulder: walking, carrying a crate between their hands, busy at their station, sitting on a crate on strike with the sign held up. Moved all at once (`BulkMoveTo`), as shoppers are; workers keep their shadows (they work out in the sun) |

Checked before Studio: 552 tests (every job and look, and 100 shoppers, build with limbs on pivots, feet on the ground, under 6.5 studs), no flicker, every job, the shoppers and the four poses rendered in `partview` (`lune run tools/peopledump`, views `crew1`–`crew4`, `people`, `peopleback`, `shoppers`, `poses`, `posesside`).

**Checked in Studio the same day** (PlaytestLog, [playtest/2026-11-05-worker-art/](playtest/2026-11-05-worker-art/)): a gallery of every job and capped shoppers in edit mode, then seven hired in Play, stand-ins for the strike and the walks. Found and fixed there:

| Found | Change |
|---|---|
| Caps, beanies and the hard hat hid the eyes (shoppers' too), a bun poked out of the top of a cap | They sit higher, tipped back 10°, the front edge over the eyes; under any hat a bun sits low at the nape |
| The Stocker stood in the Cashier behind the Shop Counter (the start layout puts the Cashier in the staff doorway; the Stockers' spot was 2 studs off), arms through each other, name tags over each other | Stockers wait on a free cell by the staff door (`StoreLayout.stockerSpot`: nothing on it, not behind a till, not a door, not a display's front or a queue; outside the staff door if the floor round it is full), their tag a line over the Cashier's |
| (reading the code for it) The crew wasn't moved after Decorate or a Store Level up: a Cashier stood where the till had been | Both move the crew now (`StoreService.crew.moved` → `WorkerService.ShowCrew`) |
| Every walk showed the crate both ways | The crate goes the way the work does: a Loader's out to the truck, a Farmhand's harvest on the way back (`back` on the walk) |

Tests: 554 (the Stockers' spot in the start layout and an empty one, three of them apart; outside when the floor is full).

### Change after review: Barley and Patty on the shared body, and the shelf panel (2026-11-05)

The user, on the two things noticed while checking the workers: "Fix the first issue. In the case of choosing what goes on a shelf, players should be able to press E to open a panel that shows all the produce they have unlocked, with options to fill that shelf with the selected produce or show out of stock. What do you think?"

| Asked | Change |
|---|---|
| Barley and Patty still had the old ball heads | The body moved to `shared/PeopleArt` so the server can build people too (the clients' `client/People` dresses shoppers and crews on it); Barley and Patty stand in it (`World/TownArt`): Barley in his red shirt and denim dungarees, a straw hat with a green band, white hair, a white beard round his chin under the face's smile, the seed packet held out over his counter; Patty in a teal cardigan over a white blouse, auburn hair in a bun, the clipboard of jobs held up in both hands. Their parts are in the flicker check: every clothing layer now stands 0.05 off what it covers (a belt 2.1 wide on a 2-wide torso, straps from the bib's top over the shoulder; the shoppers' and workers' the same) |
| E at a shelf opens a panel of your unlocked produce: fill it with one, or out of stock | Agreed, with four additions (said to the user): a tab per slot on displays with more than one, greyed crops the display can't hold (with the display that can), Auto kept as the first card, and each card's stockroom count and price. "Unlocked": the rarity's seed level (what gates planting), plus anything you hold. §4.8 "By hand", §5 Store; `ShelfController`, `StoreAction` "Stock", the display prompt now a tap ("Stock"); the guide's words follow |

Checked before Studio: 554 tests, no flicker; Barley and Patty rendered (`partdump … town`, views `barleyclose`, `pattyclose`; the face's stand-in eyes and smile drawn by `partdump`).

**Checked in Studio the same day** (PlaytestLog, [playtest/2026-11-05-shelf-panel/](playtest/2026-11-05-shelf-panel/)): Barley and Patty close up; the panel at a Produce Crate and the Wooden Shelf with carrots and Bell Peppers in the stockroom (fill, out of stock, can't hold, the slot tabs), and on a phone. Fixed there: Barley's moustache sat on the face's smile (the real smile is higher than the renders' stand-in), so he has a beard under it and no moustache; the cards are shorter so two rows show on a short screen; "Empty. Pick a crop to fill it." on a one-slot display; the out-of-stock tip says "No carrots".

### Change after review: every bat skin gets its own shape (2026-11-05)

The user asked if the skins were made from scratch. They weren't: all three were the plain bat in new colours with small add-ons, so the Baguette and Carrot Club kept a bat's knob and handle. Then, on the Golden Bat: "the most expensive at R$149 and it looks like a rip off. Make it worth its price."

| Skin | Now |
|---|---|
| Golden Bat (149) | A king's sceptre: a crimson grip bound in gold wire, a ruby in the pommel, a gold collar, a barrel turned in three widening stages with rubies round its head, a crown of gold points round a big ruby. It glows (the user: "make the golden bat glow or shine golden"): the gold is Neon, the darker rings aren't so its stages still show, a soft halo pulses behind its head and it lights what's near it. It sparkles, a swing leaves a gold trail, and its bonk is a bigger BONK! with a burst of gold sparkles (`skin` on the Bonk event, `CrimeController`). Sparkles, not coins: a bonk pays nothing, and coins would say it does |
| Baguette (79) | A real loaf: a straight middle, long tapered ends browned at the tips, three rows of slanted slashes with pale crumb in them, so some show whichever way it's turned. No knob, no handle |
| Carrot Club (79) | The crop's own `Carrot` and `CarrotTop` meshes (no new import), stretched to a bat's length, held by the root with the leaves at the swinging end. Rings narrowing to the root until the meshes are imported |

Still looks only: every skin is within 0.8 studs of the plain bat's length and swings and bonks the same (the hit is the server's, by distance, and never reads the tool). The handle's hidden inside each shape. Truck paints stay paint: they're sold as that.

Tests: 559 (`bats`: every skin with and without the meshes, every piece welded with nothing to bump into, about the plain bat's length, no bat under the shapes, the Golden Bat's effects).

**Checked in Studio the same day** (PlaytestLog, [playtest/2026-11-05-bat-skins/](playtest/2026-11-05-bat-skins/)): all three in hand, the swing's trail, the bonk's burst, the Golden Bat by day and night, the Style tab.

| Found | Change |
|---|---|
| The Golden Bat came out lemon yellow and flat, its halo washed over it, and its light bleached the grass and whatever stood beside it | Neon brightens a colour a lot: three golds tried side by side and 205, 112, 22 kept, which reads as gold on screen. The halo is behind the bat (`ZOffset`), the light down from 2 to 0.8 and range 12 to 8, the rings plain so its stages show |

### Change after review: the user's play-test notes, travel, the till, bubbles, hiring (2026-11-05)

| Note | Change |
|---|---|
| "There is a green wheel at the warehouse, remove it or keep it?" | Removed: the Packing Shed's hose reel, a bare green disc that did nothing |
| "Remove the wait on the teleport, make it instant." | Home, Town and Visit go at once. The rules are `TravelRules.check`; the stand-still bar and its cancelling are gone |
| "The nature sounds like the bird sounds like way too often and can be annoying." | The birds chirped every 3 to 4 seconds, for ever, and the crickets never stopped. Now each comes in a spell of 10 to 16 s, fading in and out, with 60 to 120 s of quiet between, a little softer than before (`AmbienceController`) |
| "birds and crickets should only be played when outdoors. Rain sound can be played inside but should sound like when the player is indoors just like in real life." | Inside a store, an enclosed warehouse or a town building the birds and crickets fade out, and the rain drops to about half and goes muffled: an `EqualizerSoundEffect` takes 12 dB off its middle and 32 dB off its top, so the patter goes and the low drum on the roof stays. Eased over about a second, so nothing jumps at the door. The open Packing Shed counts as outdoors |
| "Have the theme music play only in town while outside. Do not play indoors like in the auction house." | The banjo fades in out of doors in town (where the location sign says Town) and out everywhere else: farms, stores and the town's buildings (`PlotLayout.outdoorsInTown`, `AmbienceController`). The Settings line says so |
| "wait if being raided" (the choice after instant travel took 3 s off an owner in town: a slow owner, everything set out, went from +0.3 s to −2.7 s, always catching the thief) | Home takes 3 s while a thief is on your farm (`TravelRules.waitFor`, `TravelService.raided`), and the raid race is back to the numbers it was tuned for |
| "Instead of press E twice to checkout a customer where the button is hard to see at the bottom right. Show the customer gui prompt and let the player hold it with E" | The prompt on the counter (§4.8), one 0.8 s hold. SCAN, TAKE and `Shop.SCAN_GAP` are gone |
| "Speech bubbles are being hidden through walls" | `client/Bubbles`: Goldie's, bidders' and shoppers' bubbles draw over everything, so nothing behind the speaker cuts them off, and hide while something solid is between you and them, so none shows through a wall from outside |
| "The players sign is also slightly being covered." | The location sign sat under the rosette's ribbons and, with a long store name, under the sky clock's tag: it's 8 px lower (the ticker too), and a long name slides right, clear of the clock |
| "Logs should also appear in the middle of the screen and not on the top right as it's hard to see and players may not notice it." | The notes moved to the middle: centred, under the purse and the ticker, so the big cards in the very middle (a level-up, an arrest) keep their place |
| "Is the number on the buttons at the packing shed the price or the quantity?" | It was the price, for one crop. The buttons now read "🚚 Truck / 35 coins each" and "🏪 Store / 20 coins each" |
| (Found in the Studio check, 2026-11-05) Walking straight in and behind the counter left the camera inside the Corner Store's awning, which isn't solid, so the whole screen went one colour | The awnings and the valance are part of the roof now: they fade with it while you're inside |
| "The farm worker is glitching, sometimes he harvests even though he's not on the plot and he teleports." | The server took the crop the moment he set off and only then drew his walk, and every new job started him again from his post. Now the harvest happens when he arrives, he goes from crop to crop, and a walk always starts from where he is. A good worker hurries to keep to their speed; the server's 1 s tick can still cost the very fastest a little while you play |
| "The on strike sign is also bugged out." | It was held out to one side, 3.3 studs from the worker, so by a wall it went through it and "ON" was cut off. It's a banner on two sticks now, both hands up, right over their head and no wider than they are, with the words on both sides |
| "Make the workers on strike stand around the middle of the plot, above the spawn point, next to the farm." | They walk out of their buildings by the doors to a picket line on the lawn between your door and the field, stand there facing the door with their banners up (no crates; no name tags: they ran together), and walk back when the strike ends (`PlotLayout.picketLocal`, `WorkerService` wayOut) |
| "After fixing the farm worker, make sure all other workers are functioning properly, this includes visually too." "The workers are going through the wall" | Every job watched in Studio. Loaders cut through the wall beside the dock door and floated 1.5 studs over the dock: they go through the middle of the door now and stand on it. Crates reached the truck before the Loader did, and Shed Hands and Stockers never moved at all: they carry crates now, and things appear as they arrive. Workers at a station overlapped at 2.6 studs apart: 3.4 now, Loaders away from the pallets. A Farmhand whose post moves walks there |
| "Instead of showing \"free\" for hiring which can be misleading, show the rate." | The first hire's button shows their wage ("Hire · 105/min"); the note, the empty crew card, the toast and the Hiring Hall's board all say there's no *fee* on your first hire, not that it's free |

**Instant travel moves the raid balance.** Nothing's changed for an owner at home, but one in town is now as near as one at their door, 3 s better. With everything set out, a slow owner in town catches the thief by 2.7 s where they lost them by 0.3 s, so the rule from week 6 ("if a farmer is slow then a thief should be able to run away with the crop") now only holds on lightly defended farms. The layout tests were changed to what's true now; `lune run tools/raidrace` has the numbers. Waiting on the user's call.

### Change after review: stock sounds, a door bell and the dog's alert (2026-11-05)

The user picked downloaded effects for the sounds that didn't work: "Some audios needs to change especially the bonk, cash register, harvest, plant, level up, shop bell and siren. Add a unique bell sound for the checkout when there is a customer. Make a unique sound for the guard dog from the alerte sound file." `tools/sound_art/stock.py` cuts them: trimmed, faded, mono, and about as loud as what they replace; the downloads and the results stay out of the public repository.

| Sound | Now |
|---|---|
| Bonk, CashRegister (and `TillOpen`), Harvest, LevelUp, Siren | Cut from the user's files. The Siren is two of the alarm's bursts, 3 s |
| Plant | The first rustle of the Harvest file, slowed and darkened, so the two differ |
| ShopBell | Now the bell over the door: it rings as a shopper comes in (`ShopperController`, no more than once every 4 s a store), three rings of a door bell |
| CheckoutBell (new) | One ring of a counter bell, when a shopper stands waiting at a till you serve at. That was ShopBell's job |
| Gavel | One strike of the user's file: Goldie bangs once for each call |
| AuctionTick, Outbid, BidWon (new; the user: "Yes add those as well as a successful bid win.") | Our own, from `generate.py`. A wooden tick for each of a lot's last ten seconds, higher for the last three, heard in the hall; a falling wah-wah when someone tops your bid; just after the gavel when the lot is yours (not if it couldn't be delivered: it's the server's `AuctionWon`), a crowd cheer: "I want it to be a cheer instead" of the fanfare I made, then "Can you make a unique sound with the applause and the yay for the cheer together?". `BidWon` (3.3 s, `stock.py`): the children's yay, again a little higher and a little lower just behind it, so it's a crowd, over the applause, which carries on after the yay and dies away |
| DogAlert (was Bark, never filled in) | The Alerte file, trimmed. The user tried barks made from it first, then: "the dog sound should just be an alert sound with a exclamation mark on top of them". so the dog's WOOF! is gone: a gold ! pops up over its head and goes where it goes (gold, as the red ! marks a Suspect) |
| The dog's legs (the user: "the dogs limbs are not connected") | They stopped short of the body at the hips. The hips moved in under it and the legs stretch 1.3× up inside it, so a swing opens no gap: the same mesh, nothing to import again. Checked in Studio, standing and running (PlaytestLog) |

### MVP week 9: settings, sounds, the Robux shop, analytics, the page art (built 2026-11-04)
The user: "continue" (after week 8 was pushed). Built as §5.6, §7 and §8 describe (each in its section):

- **Settings** (§5.6): the ⚙️ crate and window.
- **Sounds and music** (`Config/Sounds`, client `Sfx` and `AmbienceController`; Tide Market's pattern): a click on every button, tab and crate, a soft buzz with a red note and a pop with a yellow one, plant, water and harvest from the patch, tape at the bench, a truck's horn as it leaves (and BEEP BEEP), the cash register with its pay, coins at your own checkout, the level-up fanfare, quest rewards, the siren once per thief (the music and ambience dip under it), a whoosh for every swing, BONK, the police whistle at an arrest (and the cash when the fine is yours), leaves rustling as a crop is stolen, the yard's alarm bell, the auction's bell and gavel, thunder after each flash (later the farther the strike); a banjo tune, birdsong by day, crickets at night and rain. Eight are Creator Store sounds Tide Market already uses; the other eighteen are synthesised by `tools/sound_art/generate.py` (no licences) into `art/sounds/` and stay silent until they're uploaded and their ids pasted in (RobloxPage.md). The guard dog's bark is still to pick.
- **The Robux shop** (§7).
- **Analytics** (`Util/Analytics`): Farm, Warehouse and Store Levels as progression events, the Robux shop as a funnel (opened, a tab, the prompt, bought), and custom events for bids, weather started, workers trained and every setting changed. Found while adding them: the warehouse's levels and a worker's training were logged as onboarding steps the funnel doesn't have (so Roblox dropped them), and the funnel's GuideDone step was never logged; fixed.
- **The page art** (`tools/page_art/compose.py`): the 512 × 512 icon and five 1920 × 1080 thumbnails from Studio shots, in the Kraft & Crate look (the title on a red board hung on ropes, a line on a wooden board under each picture, Roblox's own Fredoka One from Studio's install). Tried on old shots: fixed there planks poking out past the board's outline and a shadow cut off square. The page's words, the shots to take and the dashboard's to-do are in [RobloxPage.md](RobloxPage.md).

Decided while building:

| Question | Decision |
|---|---|
| A More crate (§5.2) or a crate each? | A crate each, one tap; Robux and Settings went to the top bar in the Studio check (below) |
| What's the Robux button called? | "Robux" with 💎: a "Shop" beside your own "Store" would muddle the two |
| A bought weather that can't start (a better one on, the Harvest Moon near) | It waits in your barn with a Start button (and says why not yet): nothing bought is lost or wasted |
| Weather ranks | By what a crop left out gains on average: Rain < Frost Night = Thunderstorm < Golden Hour < Harvest Moon (Frost Night isn't sold: night only) |
| The Growth Boost's clock | Counts only while you play (§4.2's offline 25% never gets it) |
| Text size (80–125%) | Windows and notes keep their size on screen and their insides are drawn bigger or smaller (a UIScale): every window stays on a phone's screen |
| VIP and fines | VIP's +10% counts in the hour's earnings a fine is worked out from: a VIP thief pays a little more, never less |
| The sounds | Synthesised in code (no licences), checked by their levels, loop seams and spectrograms, loudness balanced in `Config/Sounds` |

Checked: 525 tests (settings parsed and stepped, the catalogue only selling weather, growth and looks at the doc's prices, a weather never over a better one or into the Harvest Moon, the boost counting only time played, looks worn only when owned, the Bigger Barn's room), no flicker (the bat's three skins added to the flicker world; the plain bat's band moved 0.05 proud of the barrel); the bats judged in a render (`partdump … bats`, `partview` view bats), the sounds by their levels, their loops' seams and spectrograms (fixed there a hiss after the gavel's knock and a breathy whistle). Then in Studio the same day (PlaytestLog): Settings, the Robux shop's every tab, VIP on the farm, the Golden Bat, every window on an emulated iPhone, 2 players for the raid's shots; the page's icon and four thumbnails made from shots there (`art/page/`). Fixed there:

| Seen | Changed |
|---|---|
| On a phone, ten crates went to three columns and the third covered the sky dial | Robux and Settings are wooden signs at the right end of Roblox's top bar (`HudController.topButton`, a ScreenGui with TopbarSafeInsets); in its middle they sat over the purse's ropes |
| The first Buy did nothing: the funnel's analytics note and the purchase went through one action remote 0.3 s apart, and the purchase hit the cooldown silently | The funnel has its own fire-and-forget remote (`RobuxFunnel`); the settings remote's cooldown is 0.05 s |
| "1 in your barn: not now…" shrank to 8 px under the buy button | A strip along the card's foot: Start now, or when it can start, naming the weather and who bought it; shown before buying too when it couldn't start now |
| The boost's time left stood still between the server's minute updates | It counts down on screen |
| Two notes said the same when a weather was bought | The announcement says who bought it; the sky's own note says what it does |
| The VIP tag's ⭐ vanished on its gold pill | A dark tag with gold letters, just above the Roblox name others see |
| VIP Gold in Metal looked dull olive at noon | A warm gold on the plain finish |

Not checked yet: hearing the sounds (they need uploading), a real purchase prompt on the published game (the passes and products need making), the Baguette and Carrot Club in Studio. (Since done: the store's thumbnail on 2026-11-05, [RobloxPage.md](RobloxPage.md); the skins, remade and checked the same day.)

### MVP week 8: the Farm Guide, trading, the market's supply, leaderboards, the valley (built 2026-11-04)
The user: "continue" (after the town's look was pushed). Built as §4.0, §4.7, §4.13, §4.15 and ArtDirection §5 and §11 step 4 describe:

- **The Farm Guide** (`Config/Guide`, `shared/GuideRules`, `GuideService`, client `GuideController`): a clipboard on the right of the screen with the step you're on, how to do it and a box per step; a gold marker bobs over the spot with an arrow at the screen's edge while it's off screen, and TOWN or HOME pulses when the step is elsewhere. The services tick the steps off where they already logged first-time analytics. X hides it (the Quests window brings it back, or reads it again once done); the last step pays 3,000 coins once and points at the "Clear here" sign of the Land Permit the guide's XP brought. `/guide` starts it again.
- **Trading** (`shared/TradeRules`, `TradeService`, client `TradeController`; Tide Market's pattern, for stacks instead of fish): the 🤝 Trade crate lists the players near you, or press T by someone; two crates side by side with the value of every stack and a red bar at 3×; Ready → 5 s → Confirm → the swap, both saves written at once, logged in `TradeLog_v1`; `/trades` and `/rollback` for support.
- **The supply factor** (`MarketService`, §4.7).
- **Leaderboards** (`shared/LeaderRules`, `LeaderboardService`, `World/BoardArt`): RICHEST FARMS and TOP STORES either side of the Exchange's walk, SHERIFF OF THE WEEK and MOST WANTED (a wanted poster with #1's photo) either side of the Police Station's. OrderedDataStores: net worth now, this week's arrests, crops stolen and Store Rating (stores named by the week), all-time arrests and crops stolen; written every 2 minutes and as you leave, read every minute.
- **The valley's look** (`World/ValleyArt`; meshes in `tools/crop_art/valley.py`: `HedgeSection`, `TunnelArch`): Terrain hills in two rings of mounds, higher toward the north; a rock cliff with the stone arch where the highway goes in (dark inside, lamps, a THE CITY sign); oaks, firs and bushes down the middle of every gap between farms; hay bales, bushes and lamp posts along the back trail; a dashed line, kerbs and zebra crossings on the ring road; the hedges as leafy sections with flowers.

Decided while building:

| Question | Decision |
|---|---|
| Which first-time events tick the guide's steps, since week 4 changed selling? | Pack: any crate packed (the Packing Shed's bench or a warehouse's wash table); Dispatch: any truck sent; Store: a display filled; Hire: your first hire. Between Seeds and Store, if your barn and stockroom are empty, the card says to plant and harvest the new seeds first |
| Does a returning player's guide catch up from their save? | No: the game hasn't launched, so every save starts it fresh. It's skippable |
| Can defences won at the auction be traded? | No (§4.13): seeds won there can |
| What happens when you close the Trade window? | The trade is cancelled (it says so); nothing has moved |
| Which sales count toward supply? | Truck runs, at dispatch (when the price locks); offline settlement's simulated runs don't |
| "There is an issue where the packing shed worker packs for the truck even though it was routed for the store." | A full stockroom sent the crate to the truck, on purpose, online and offline. It can't happen now: packing only fills the one stock, and when that's full the crew waits. Also found: the crew was packing mutated stacks (meant to wait for you), and a Store-routed crop at the front of the queue held up everything behind it |
| "Allow selecting which crates/produce goes on the truck." | The dock window (§4.6). "Load crates" used to take the next crate; now you pick, and can take one back off |
| "Make it so that packed create/produce can be used for both the truck and the store." | One stock (`shared/PackRules`, `store.stockroom`; the old `warehouse.dock` moves into it on load). The bench lost its Truck and Store buttons for one Pack, and with them the crate in your arms: you load at the dock instead. Routes now say what the crew does |
| "Allow running after leaving the victims land ..." | Slowed only on a farm (§4.10). Any farm, not just the victim's: another farmer can still bonk you for it (said to the user) |
| "... slow down the farm worker ..." · "... increase the speed of farm workers by their levels ..." · "... at max, they can outpace a running thief." | 8 to 26 studs a second by level (§4.9). The hurry and the 6 s limit on a walk are gone for them |
| "Fix any issues you've found" | The flags from the play-tests. Phones: the hotbar fits between the thumbstick and the stamp with as many packets as fit, and the Farm Guide hangs clear of the chalkboard. The 🪙 that Roblox doesn't draw is the word coins (Defend, the shelf panel, a quest's reward), and floats say coins. The Guide's first step counts Carrots, an empty truck's lever no longer hides Load crates, a receipt's mutated names are coloured, the Stock tab says when crates for the store are waiting for room, a bid that leaves less than a minute's wages warns you, and the seed picker's taller |
| "Allow players to remove existing planted crops as they may want to plant a new crop." | HOLD TO DIG UP, a smaller stamp over the big one (§4.2). The seed is lost, or digging up would be a free yield re-roll |
| "...the selected seed stays on and players are unable to select a new seed..." | A seed from past the end of a full bar wasn't on it, so it couldn't be put away. It keeps a place on the bar now, an ALL packet opens the picker, and CHANGE SEED on the soil opens it with a seed in hand (§5.2) |
| "The packers don't seem to be packing mutated crops now." | My fix for store crops went too far: it stopped the crew packing a mutated crop of anything on Store, even with Pack ticked, and left those stacks in the barn. They're packed now and wait at the dock, and the crew still never loads them |
| "The packing workers should also bring the crates to their destination instead of just teleport the crates to their place." | They do now (§4.6): in their hands to the rack or the stockroom, on the belt to the Cold Room, which the conveyor already ran to |
| Found in a play-test, 2026-11-06: the Barn's truck price | It left out the mutation's bonus, so a Frosted Carrot read 30 when the truck paid 75. It now reads what the Packing Shed reads |
| "Show players coins in shop decoration mode" | The HUD's hidden in Decorate, so you couldn't see what you could afford. A coin plate sits over the draft's cost by DONE, with the exact number so it reads against the cost |
| "Change the text colour for mutated names so it's easier to notice" | Each mutation has a text colour now (§4.6), with at least 3:1 contrast on a cream card. The truck receipt is the one list left plain |
| "Workers seems to be not packing for the store, find the issue and fix it directly. Make sure the process works correctly and smoothly." | The crew only packed a crate's worth, so a store crop with less than that stayed in the barn while the shelves ran out: 48 corn on Store sat there for 2 minutes in a play-test (a crate is 60). Now it goes part-full, and crates combine in the stock so small ones don't fill it (§4.6) |
| "just allow combining the crates... Wouldn't this be more efficient?" | Yes: it replaced my first fix, one part-full crate of a crop at a time, which held crops in the barn for nothing. A trip carries more too, as a truck's load is counted in crates (§4.6) |
| "There are crops missing in the warehouse.routes page." and "The worker keeps packing corn onto the truck" | One bug: Corn had no row, so it stayed on Truck and couldn't be changed. The tab only listed what was in the barn or in seeds. A crop still growing, or all packed, had no row, and with no row it stayed on Truck: its first harvest went by truck before you could tick it. Now it lists everything you've unlocked, and anything you hold |
| "Allow players to remove topped up crops on a shelf." | A Take off card in the shelf panel (§4.8). The slot's left empty until you pick something, or the crew would refill it at once |
| "Workers are still packing crates onto the truck even though it's ticked for the store." | Reproduced with a Shocked Tomato: a mutated crate always went by truck, tick or no tick. Plain crops on Store never did. Now a crop ticked for the store is never loaded by the crew, mutated or not, and its mutated stacks aren't packed for you: by hand they wait at the dock |
| "Allow players to interact with the packed crates at the packing shed that opens up a panel where they can select crates they can send to the stockroom." | The window above (§4.6), which also gives the stockroom a job of its own again: it's where you decide which crates are the store's |
| "I can go through the packed crates, fix that" | Crates were all decoration. Those on the rack and in the Cold Room are solid now. Crates on a truck and in the back room aren't: nobody walks there |
| "Wording is out" (the wash screen, "Shocked Tomato ×6") | A long name ran off the crate's label: it shrinks to fit now. It also said "for your truck or store" for a mutated crop, which only goes by truck: it says so now |
| "I still can't access the teleports after reaching home, fix that" | A thief stays a Suspect for 60 s after their last act, and that kept Home and Town off even at home. Home now frees you to travel at once, for good until your next suspicious act |
| "make the customer speech bubbles a bit smaller and add a coin icon when it shows the + coins" | Bubbles are 4.6 × 1.2 studs, down from 6 × 1.6, with a little room at each end. What a shopper pays shows on a shorter bubble with a drawn coin (Roblox can't show the coin emoji) |
| "Yes, change the wording" (what's the stockroom for now?) | Packed crates are one stock, so the display prompt, Fill all, the sold-out note, the Prices tab and a Store Level's news say "packed" now, not "stockroom". The back room stays: it's the room a Store Level adds, and where the crates for the store show |
| "The shed worker still puts crates on the truck when the storeroom is full" | They did, by my mistake: a crop routed to the truck went straight on with the stock full, and every crop starts on Truck, against "stop packing and wait for space ... and not just pack for the truck". A full stock now stops all packing, as time away already did. Crates already packed for the truck still get loaded: that's what the Truck route means |
| "I want to be able to check how much stock I have in the storeroom." | The Stock tab squeezed it into one line, and left mutated crates out. It now lists every kind on its own row, with how many crates (`PackRules.stacks`, as the dock window does) |
| "The icons are not centered in the card panels." | The job icons on the Workers window's badges, and the crop icons in the Warehouse, Store, Packing Shed, Dock and Market rows, used a label that lines up left. All centred |
| "The cashier doesn't go to their new checkout site ... this resulted in 2 checkouts with only 1 worker." | A Cashier was tied to one till by hire order, while shoppers took the shortest queue, so they waited at the empty till. Now a Cashier who isn't in the middle of a sale walks to whoever's waited longest at a till nobody's at, round the counters, and stays there; of two equal queues shoppers pick the one being served. Studio found two gaps: a layout could shut a till's back cells in (a Cashier walked through things to reach them: `NoWayBehind` refuses that now, and with no way round they don't go), and a queue at their own till kept them from ever leaving. A second Cashier can still only be hired once the till's built, then takes the free one (`WorkerRules.tills`, `crew.call`) |
| "Reduce the "just arrived" shield to 1 minute" | `Crime.ARRIVAL_GRACE` 120 → 60 |
| "Currently, all types including mutated crops are packed. Allow selecting which mutated produce to pack or not pack." | The live build's crew packed any stack with a crate's worth. 53be864 stopped that; now each kind has 📦 Pack or ✋ Keep in the Routes tab (§4.6). A mutated batch mid-wash at logout also came back plain after time away: it now keeps its mutation |
| "... pressing E the second time to move a shelf doesn't go through." | Three ways a press could be lost, all closed; not yet reproduced in Studio. E only asked the floor, so the top of a tall shelf missed (`itemAt` now tests what's drawn). A moved item lost its pick, so a second E did nothing with the mouse elsewhere (it stays picked, and what you point at comes first). With the next new item in hand, E tried to place that on the shelf you pointed at (it picks that shelf up now). A press with nothing to move says so |
| "Yes, add it" (an Invite Friends button) | New games only reach under-16s after 250 highly engaged players have played them, or an R$50,000 review, and the game had 5 visits. A 👥 Invite sign in the top bar (§5) lets players bring friends. No reward for inviting yet |
| "The arm twitches when holding a stolen crop." | Seen in Studio: an IKControl solved the arm afresh every frame, from wherever the animation had it, and a hand could turn 125° in one frame standing still. A crop is welded to the torso, so the arm's pose never changes against it: it's worked out once (`shared/ArmPose`) and set on the joints each frame after the Animator (`PoseController`) |
| "The display in the store flickers when the stocker stocks up." | Every change wiped and rebuilt every display. A heap now only changes at its end (`Meshes.settle`), and crates in the stockroom, on the rack and on a truck stay put unless they change (`YardArt.stack`) |
| "For the knocked out card show: You got knocked out... You are down for 5 4 3 2 1 second(s)" | The card says that now (§5). BONK! stays as the pop-up in the world |
| Found by Studio's crop count, 2026-11-05 | Time away lost what Stockers put out: it came off once in the sum and again when it really went on the shelves (1,326 + 78 harvested came back as 1,164). The old code did it too. Now the settlement adds what was packed for the store (`report.forStore`), and 720 crops stay 720 |
| Found clicking the dock window with a crew at work | Rows rebuilt every time a crate moved, so a press could lose its button. Rows now stay and only their words change, and buttons say how many crates they really move (`Load 2`, `Take off 4`) |
| [the player list showing Level 3.8M, Coins 2] | Roblox's own player list, since its 2025 update, can show stats under the wrong headings. Coins now comes first by every order it might use, with `IsPrimary` and `Priority`. It also sorts the list by coins |
| "I'm stuck on the loading screen now." (Studio Play with the published game still open: a save opens in one place at a time) | Nothing was broken, but the loading screen said nothing. After 8 s it now adds "Still opening your farm. If you've just left another server, this can take up to a minute.", which also covers a quick rejoin or a crash |
| "How come theres a farm with 89 mill" | It was a Studio test player: Studio writes to the same boards as the live game, and that test save had been given 90 million coins. Test players (negative ids) aren't written any more, and any already stored are passed over when the boards are read (`LeaderRules.counts`) |
| Weekly and all-time on the boards | Each board shows this week's top 10 (RICHEST FARMS: now); Sheriff and Most Wanted show the all-time #1 under them |
| The boards in Studio without API access | They rank the players in this server and say so |
| The woods' clearance | 12 studs from every hedge (the doc's 10, with room for a trunk) and from the highway; a test checks every tree |
| Cover on the back trail | Every 5° (52 studs) on its outer verge, every fourth just behind the back fences; lamps every 7.5°, glowing at night (no real lights) |

Checked: 504 tests (2,000 random trades with nothing copied or lost, the guide's steps and reward, net worth and the weeks, prices reading the supply hook, the woods clear of hedges and highway, the trail's cover off the trail, the trucks' way into the tunnel, the boards), no flicker; the hedge, the arch, the woods, the trail, a crossing and the boards judged in renders (`partdump … valley`, `partview` views tunnel, woods, trail, crossing, hedge, valleyabove, exboards, policeboards): fixed there a notch where the arch sprang (the spring moved onto a course line) and a hedge that read as a flat dark wall (lumps out of both faces and a crested top). Then in Studio the same day (PlaytestLog; the props file imported again), solo through the whole guide and with 2 players trading. Fixed there:

| Seen | Changed |
|---|---|
| Terrain's grass blades grew up through every lawn, the plaza and the back trail (the Terrain floor under the valley sprouted them; scripts can't turn Terrain's decoration off) | No Terrain under the ground: the valley's disc reaches out under the hills, which rise from it in its green |
| The tunnel's cliff was a hard-edged block of rock in the hills | Rock only round and behind the arch with rounded shoulders, grassy hill over and beside it, the hills allowed up to the highway |
| The hills can be climbed (the old greybox hills were solid blocks) | An invisible wall at their crest keeps everyone in the valley |
| The guide's done card cut its line off; markers picked the first patch in the field, not yours; the pickup step pointed at the lever with the crate still in your hands; with an empty barn it said to plant while ripe patches waited; TOWN's pulse was too slight to see | Got it beside the coins; the nearest patch; the truck's load spot until a crate's on it, then the lever; "harvest your ripe crops first"; a bigger pulse with a gold ring |
| A tap on the gap between the trade's crates closed the window and cancelled the trade: taps on a window's own paper fell through to the backdrop (in every window) | Every window's paper catches its own taps (`UI.panel`); only a tap outside closes it. The picker closes after an add, "+ Add" goes once you're Ready, phones say "tap Trade" |

Not checked yet: MemoryStore and the OrderedDataStores in a live server, the trade log and `/rollback` (API access), the 50-player test (Stage E).

### MVP week 7's other half: the town's look (built 2026-11-04)
The user: "continue" (the next step after week 7's play-tests). Built as ArtDirection §6 and §11 step 6 describe: `World/PlazaArt` (the plaza with a four-leaf clover set in it, the clocktower rising out of the fountain with four clocks that show the sky's time, benches, picnic tables, the park with walks, avenues, the walk round the town, trees, flowerbeds and lamps, a signpost where each farm's path leaves town, the green's tree clumps and benches, street lamps along the ring road), `World/TownArt` (Barley's Seeds, the Hiring Hall, the Exchange's trading hall and grain elevator, Barley and Patty), meshes in `tools/crop_art/town.py` (the fountain's basin, an oak, a fir, a bush, a flowerbed, a pyramid and a cone for roofs). `PlotLayout.TOWN` gains `radius` (160, the town's edge; `plazaRadius` is the paved plaza now, 60), `walkRadius` (150) and `spawnLook`. The price board is `Town.Exchange.PriceBoard` (34 × 24 studs; `MarketController` fits its grid to it), `SkyController` turns the clocks' hands, `PlotService` writes owners on the signposts. `partdump … town` and `partview`'s town views render it.

Decided while building:

| Question | Decision |
|---|---|
| Where do the farm paths start? | At a walk round the town behind the buildings (radius 150), reached from the plaza by five avenues between the buildings: straight paths from the plaza to Farms 2 and 7 would run through the Auction House and Barley's |
| Where's the fountain, with the clocktower in the middle? | The tower rises out of it (one landmark in the middle; the clover round the basin) |
| The spawn | Beside the clocktower at (12, −26), facing the Exchange's board (was (0, −30) facing north): from straight behind the tower, it filled the screen and hid the Exchange. Every gate stays 285–345 studs off (§3) |
| The bus-stop shelter in ArtDirection §6 | Left out: a bus stop with no bus has a new player waiting for nothing |
| The Exchange's price board | Smaller than the old building's whole front (34 × 24, was 40 × 40), the words 20% smaller; the grain elevator behind it is what you see from across the square |
| Real lights at night | Only the plaza's ten lamps; every other lamp, the clocks and the shop windows glow (phones) |

Checked: 471 tests (the town's clocks, signposts and boards, the elevator the tallest thing in town, the spawn's view of the Exchange clear of the tower), no flicker (25 kinds found and fixed: lamp frames level with their glass, bench backs in the plane of their legs, sills that didn't reach their glass, the seed shop's roof ending in its false front's face, the porch roof level with the corner boards). Judged in renders (ArtDirection §11 step 6 lists the fixes). Then in Studio the same day (PlaytestLog), with the props file imported again: the signs, the clocks keeping the game's time, the price board readable from its walk by day, at night and on a phone, 60 fps in town as at the farm. Fixed there:

| Seen | Changed |
|---|---|
| Arriving in town, the camera kept the angle it had at the farm: you landed facing the Exchange but looked back at the Police Station | After Home or Town, the camera turns to look the way you land facing (`HudController`, when the character jumps more than 30 studs during the trip) |
| The fountain's jets were a few faint sparkles | Thicker, longer arcs that land inside the rim, and a splash where each lands |
| A porch post stood in front of the Hiring Hall's job board, cutting its header | The middle posts frame the door (the step between them), clear of the board and the window |

### Change after review: a stolen crop is yours once you're back in your farm (2026-11-03)

The user: "Currently, the player only successfully steals a crop by going on their spawn point right? Allow a successful steal if they reach their farm plot." Right: it went into the thief's barn only within 12 studs of their farmhouse door (`Crime.DEPOSIT_RANGE`).

| Seen | Changed |
|---|---|
| The last stretch to the door was a walk for nothing: in your own farm nobody can stop you (only a farm's owner has a bat there, and it's you) | The crop goes into your barn the moment you're back in your own farm, by any way in: the gate, or over your back fence (`CrimeService`, the server's InFarm zone). `Crime.DEPOSIT_RANGE` is gone |
| The carry sign said "· to your door!" once you were home | Only "Get home!" (with the arrow to your farm); "Safe! Now get it home: it's yours as soon as you're back in your own farm." when you leave the farm you stole from |

Balance: the raid race isn't touched (it ends when the thief leaves the farm they stole from, where the owner's bat stops). The walk home gets shorter, so a thief spends less time crossing other farms, whose owners could bonk them; a thief who lives next door can now come home over their own back fence. `/carry` now puts the crop straight in your barn when you're in your own farm: use it outside.

Checked in Studio on 2026-11-04 (PlaytestLog): carried in through the front gate it went into the barn 88 studs from the door, over the back fence 162 studs from it.

### Change after review: the farmhouse and barn, wild land and produce drawn (2026-11-02)

The user: "Now that the art for our crops is done, Go over all the visuals in our game and determine what other arts need 3D meshes so their appearance looks good and is polished, this should include the unfinished buildings. Determine if these shoud be done now or in a later planned week." Then, to the three due now: "Yes, start now".

The review, from the code and every play-test shot: buildings stay parts (they change size with levels, carry the farm's colour, fade their roofs and are checked for flicker; the stores, warehouses, trucks, Packing Shed and Police Station already look finished); meshes for anything round, living or lumpy. Due now, on screen every session on every farm and in no later week: the farmhouse and barn (a cream box), the locked land's obstacles (cylinders, wedges and green eggs next to the new crops), produce on displays and crates (coloured balls). Later, with the week that builds them (ArtDirection §11 steps 4, 6 and 11): the defences in week 6 (scarecrow, guard dog, cloche, camera, mud patch as meshes; kennel, floodlights, tall fence and the Watchman's gatehouse in parts), the town in week 7 (façades in parts, fountain, trees, flowerbeds, the auction bell, Barley and Patty), the valley in week 8 (Terrain hills; trees, bushes, hay bales, the tunnel arch and the hedges as meshes).

Built: `World/FarmhouseArt` (the farmhouse and barn in parts, ArtDirection §7); `tools/crop_art/props.py` and `wild.py` (stump, rock, weeds, bramble, grass patches and tufts, wildflowers, hay bale, milk churn, wheelbarrow, weathervane: 13 meshes in `art/props/FarmHeistProps.glb`, imported as ReplicatedStorage.PropModels, README step 4; an overgrown block's layout in `World/PropMeshData`); `shelves.py` (each crop's piece on a shelf, with a carrot bunch and two filled punnets added to the crops' file, in `World/CropMeshData`); `World/Meshes` (was CropMeshes: places both files' meshes, heaps a crop's pieces into display regions, wild land's obstacles and grass) used by FarmArt, StoreArt, YardArt, StoreItems and FarmhouseArt, each with its part-built stand-in until the import; `tools/partdump` + `partview.py` to render a farm's parts before Studio. `tests/meshes` (was cropmesh) checks the new layouts, that displays never show more pieces than the balls they replace, crates fill as full as they are, and wild land stays on its tiles. 387 tests, no flicker.

| Found | Change |
|---|---|
| The farmhouse and barn were one cream box with a floating label, where every owner appears | A cream farmhouse with a porch over the door (the deposit point) and a red barn with a gambrel roof, the farm's colour on the door, shutters and the barn quilt |
| Locked land's obstacles were primitives beside meshed crops; the bush a green egg (the "boulder" the crops had) | A stump with roots, a boulder, a clump of weeds, a bramble with canes, in rough grass |
| A carrot in the field was an orange ball on the shelf | Every display, crate, Pumpkin Pile and Fruit Cart shows the crops' own pieces, never more than the balls were |
| A building could only be judged in Studio | `partdump` + `partview` render it with the meshes first |

**Played in Studio on 2026-11-02** (PlaytestLog, [playtest/2026-11-02-farmhouse/](playtest/2026-11-02-farmhouse/)): both files imported, then Play from the gate, the porch, the field, above, at wild land, inside the Corner Store with its displays filled and at the dock with crates. Not covered: the bigger displays (Tiered Rack, Chiller, Showcase, Pedestal) in Studio (the tests build every one), a phone's frame rate, night (the lantern doesn't light yet).

Then two things the play-test noticed in passing (the user: "if you see anything wrong or needs improvements of any element/aspect even if it's something we are not currently building during play-testing, point it out and determine if it needs working on"), fixed at once on the user's word: tilled soil read as a raft of logs (smooth cylinders) → the props' furrowed soil, one mesh a tile instead of three cylinders; the doormat was a yellow slab that read as a spawn pad → coir with WELCOME on it, edged in the farm colour. The rest went to their weeks or stays (PlaytestLog).

### Change after review: the crops drawn as low-poly meshes (2026-11-02)

The user: "currently the crops do not look impressive; Can you draw the art yourself whichever way gives the best results. Each piece of art you draw, make sure to check it for any issues and polish it as much as you can so it looks right to the eye."

Built: `tools/crop_art/` (Python with numpy and Pillow, like Tide Market's `tools/plant_art`): a mesh kit (lathes, tubes, leaves, palmate leaves, lumpy clumps), a small renderer with sun shadows that culls back faces as Roblox does, the 22 crops at every stage, their fruit and the containers they're carried in (63 meshes, 29,500 triangles, one palette texture) in `art/crops/FarmHeistCrops.glb`; every patch layout (growing, and ripe with 1 up to a Field Level 5 bumper count) and carried load written to `World/CropMeshData`; `World/CropMeshes` places them from ReplicatedStorage.CropModels (imported once, README step 4), and FarmArt and ProduceArt fall back to the part-built crops without them. The generator stops if a patch spills off its tile or a load is bigger than it says; `tests/cropmesh` checks every layout and builds every patch and load from stand-in meshes. 381 tests.

| Found | Change |
|---|---|
| Crops built from spheres, cylinders and blocks read as blobs and rods from the farmhouse | Each crop drawn as its plant: fronds, strap leaves, stakes and trusses, vines with palmate leaves, ribbed and striped fruit, flat-shaded in a soft palette |
| Fruit on part-built bushes sank into them | Fruit is its own mesh, hung from points the generator puts out in the open |
| A part-built patch was ~20 parts, more for the big crops | 5–25 mesh parts a patch, the same few meshes repeated (cheap to draw) |
| Checking art meant a Studio session each time | Previews of every patch and load on disk, judged and fixed before Studio |

**Played in Studio on 2026-11-02** (PlaytestLog, [playtest/2026-11-02-crop-meshes/](playtest/2026-11-02-crop-meshes/)): imported, an edit-mode gallery of all 22 crops sprouting, growing, ripe and bumper and every carried load, then Play: a ripe tomato field from the farmhouse side and up close, a tray of punnets held overhead. Not covered: every crop in Play (the gallery uses the same FarmArt), a phone's frame rate with a full field of meshes, the locked land's overgrowth (still part-built).

### Change after review: a patch gives several, coins ×10, Field Levels (2026-11-02)

The user: "1 farm plot shouldn't produce 1 carrot or 1 tomato right? Does each farm plot produce a fixed number of goods or should we have a leveling system on the farm so that each level improves the farm efficiency just like other aspects of the game. How many produce of each type should go in a batch or crate?" Worked out and agreed in chat, then built ("be strict on the art").

Built: `perPatch`, `crate`, `carry` and units on every crop (`Config/Crops`, `Crops.count`: "6 carrots", "4 punnets of strawberries"); every coin amount ×10 (`Config/*`, a new `FarmHeist_Profiles_v2` save store); a tile's `yield` rolled at planting (`GrowthRules.rollYield`, `yieldOf`, `carryOf`, `take`); harvests, Farmhands, thieves, the barn (1,200 crops), crates, store slots (`ShopRules.slotRoom`), shoppers' baskets, the Sorter and Stocker, market supply and the offline pipeline counting crops one by one but working in patches' worth (`CrateRules.patches`); Field Levels (`Config/Land.FIELD_LEVELS`, `LandRules`, `LandService` UpgradeField, the Barn window's Field tab, `/field N`); `FarmArt` redrawn (§4.2, ArtDirection §7) with the Field Level looks; `ProduceArt` building as many as a thief carries; the purse shortening big amounts; seed cards, the tile line, the harvest pop, the carry sign and the STEAL stamp saying how many. 375 tests; `tools/progression` buys Field Levels and checks them.

| Found | Change |
|---|---|
| A patch is 12 studs across, more than two avatars end to end, but gave "+1 🥕" | It gives what you'd pick from a bed that size and what it shows: 6 carrots, 10 potatoes, 4 lettuces, 6 cobs, 4 punnets a picking, 1 pumpkin, 1 Mythic (§4.2, §6.1) |
| Split six ways, a carrot would be 3 coins: prices could only move in thirds, the store's pricing would have three usable prices | Every coin amount ×10, before launch (no saves to convert): the balance doesn't move, every crop is worth 30 or more |
| Everything that counted units (crates, shelves, baskets, the crew, supply) would have shrunk sixfold | Each keeps counting the same patches' worth, shown as items: a crate is 12 patches of a Common (72 carrots), a shopper takes 1–4 patches' worth (6–24 carrots, 1–4 pumpkins) |
| A thief holding three pumpkins overhead | Big crops are one a patch, and a thief carries one at a time: a bumper patch's second pumpkin stays for the owner |
| The field was the one place with nothing to spend coins on | Field Levels 1–5, up to +50% crops, each a new look (§4.1c) |
| Even +10–35% compounds (more coins, warehouse levels sooner, more sold while you're away): the daily player reached Warehouse Level 10 on day 6, 15 on day 15 | Warehouse and Store Levels 6–20 cost twice what they did; Field Levels gated at Farm Levels 5 / 10 / 18 / 26 for 50k / 500k / 3M / 12M; every target passes again (§6.2) |
| A ripe patch's glow ring was a puddle under the rows | Sparkles rising from the whole patch |

**Played in Studio on 2026-11-02** (PlaytestLog, [playtest/2026-11-02-yield/](playtest/2026-11-02-yield/)): all 22 ripe patches (and bumper ones) and their carried loads in an edit-mode gallery, fixed by eye until each reads as its crop (wheat four times over, ending as sheaves of crossing stalks); Field Levels 2–5 on a farm in Play; a Field Level 2 harvest of 7 carrots; the Barn's Field tab and a real upgrade; Barley's seed cards; 6 carrots, a tray of 4 punnets, 10 potatoes and 4 peppers held overhead. Not covered: a real steal with 2 players (the STEAL count, a bumper pumpkin left behind), the offline Welcome back counts, a phone, a full 8×8 field's part count on a phone.

### Change after review: stolen crops in your hands, the bat, travel, flicker and trucks (2026-11-02)

The user, after week 5: carry the stolen crop instead of a sack ("farmers will be able to tell instantly by looking at the crop"); fix how the bat is held and swung; "what's the point of having cooldowns for the home and town button?"; the Packing Shed flickers ("make sure no flickering ever happens anywhere in the world"); "I can go through the truck"; and everything players touch must look right and be at least somewhat realistic.

Built: `shared/LootRules` (was SackRules: one crop at a time, HandsFull) and `raidWeight` on rarities for the raid cap; `World/ProduceArt` (all 22 crops as you'd carry them out of a field, 1.2× when carried); `CrimeArt.showCarried` (the crop held over the head, hand spots on its sides placed within the character's reach); `client/PoseController` (IKControls: both hands on a carried crop or crate; the bat's rest and swing as a moving target for the right hand, `SwingAt` on characters so everyone sees swings); the StolenCrop player attribute (the warehouse's Carrying is a crate); no bat while your hands are full; `TravelRules` without cooldowns; `tests/lib/zfight` + `tests/flicker.test` (every visible face in everything the server builds, at every level: none may share a plane with another facing the same way) and `tools/flicker`; trucks with solid bodies, and `TruckController` stopping a driving truck for anyone in its way ("BEEP BEEP!") and making the time up after. 358 tests.

| Found | Change |
|---|---|
| A sack hid what was stolen: the owner saw a bag, not their crop | The crop itself, held up over the head where it's seen from behind and across a farm, its rarity's sparkle on it (§4.10) |
| Holding a crop overhead in both hands leaves none for a second | One crop at a time: HANDS FULL until it's home. A raid is now a run per crop; the raid cap still counts by rarity (raid weight) |
| The bat was held out like a sword and swung with Roblox's tool slash | It leans back over the shoulder; the swing goes back, over the top, level in front, down across, back (§4.12) |
| Setting joints in PreSimulation was overwritten (something rewrites Transform after) | IKControls for the bat too, the Animator applies them after its animations; the target moves each frame |
| IK gives up near full stretch, leaving arms hanging under a tall crop (carrots, the Crystal Rose) | Hand spots within 80% of the arm's reach, on the server and again on each client for its own avatar |
| The bat could stay in hand while carrying a crate or a stolen crop | No bat while your hands are full |
| The travel cooldowns only got in an owner's way (rushing home twice); the 3 s stand-still and the raiders' block already stop escapes | No cooldowns (§4.11) |
| Flicker: the Packing Shed's back posts in the wall's planes, warehouse wall bands, belt rails, sign frames, truck tailgates, the police cornice, store items' layers 0.02 apart, Sheriff Clucks' tail feathers | Every face pair separated by 0.05 or more, or tucked inside; the test keeps it at zero |
| Trucks were decoration you walked through | Solid bodies; a driving truck waits for people in its way, and keeps its trip on the client while late so it never jumps home through someone |
| "Carrying" on players already meant a crate (the warehouse) | Stolen crops use StolenCrop |

**Played in Studio on 2026-11-02** (PlaytestLog, [playtest/2026-11-02-carry/](playtest/2026-11-02-carry/)), solo and with a 2-player local server: every crop's model by eye and fixed (carrots, the potato crate, baskets with staves, strawberries, the bell pepper, corn kernels, the dragonfruit's scales, the golden apple, the starfruit and the Phoenix Pepper shaded, the Dragon's Eye's eye); carrying overhead from the front, side and behind and while walking and climbing; a crate in both hands; the bat's rest and swing (slowed down to check each pose); the farmer's view of a thief carrying a pumpkin; a bonk dropping the crop back to the barn; HANDS FULL; Home then Town then Home straight away; walking into a parked pickup; a returning pickup stopping and beeping for someone in its lane; the shed's back corners. Not covered: R6 avatars (they keep Roblox's own animations: keep Game Settings → Avatar on R15), a phone, 8 players.

### Change after review: your own store, and levels for the warehouse, the store and workers (2026-10-31)

The user asked for four things: their own store instead of the stand, decorated freely with racks and shelves, with workers and a way to grow it; workers that level from low to high efficiency; a warehouse that levels up for more capacity and features; and market prices on a button instead of only in town. What the plan had: the Farm Stand was the shop's tier 0 (not a test stand), followed by three fixed shop tiers with a set number of shelves and no decorating; four warehouse tiers, all bought by day 10 in the sim; worker levels 1–5 bought with coins only; and the Market window already on the side bar (built in week 2). What changed:
- **§4.8 Your Store:** a store from the first minute, laid out and decorated on a grid (displays that differ by size, crops and presentation; checkouts; decor with Charm; wall items), Store Levels 1–20 inside 4 buildings, stock, shoppers walking the aisles, queues, the rating with Charm, a public building cut out of the farm zone.
- **§4.6 Warehouse Levels 1–20** inside the same 4 buildings as before, with the Cold Room for holding crates for a better price.
- **§4.9 worker Levels 1–10:** efficiency 40% → 100%, XP from real work, training with coins when the bar is full, wages that grow slower than skill; a Greeter for the store.
- **§4.7:** says plainly that the Market window opens anywhere (and from the ticker).
- **§9:** the MVP is 9 weeks (the store is week 3; warehouse levels and workers week 4; raids move to week 5).

Three review passes, as in the first design:

| Pass | Found | Fix |
|---|---|---|
| Journey | A 4×3 starter floor couldn't hold the starter kit plus an aisle and a checkout queue | Level 1 is 5×3 (worked out cell by cell); every floor size moved up a step (§4.8) |
| Journey | A player who never decorates would get empty floor and nothing better from each new building | Each new building comes with a display already placed (§4.8) |
| Journey | The Guide's "stock your store" step needed a store crate the earlier steps don't make | The step says to pack a crate with 🏪 Store first (§4.0) |
| Journey | New rarities would outrun the store | On purpose: Epics need a Chiller (Store Level 8), Legendaries a Showcase (10); the truck sells them until then, and the Prices tab says so |
| Exploits | Visitors browsing a store inside the farm zone could be bonked, and a store open to the road could be a way into the farm | The store is cut out of the farm zone (no bat, nothing to steal); its staff door only opens for the owner and Trusted friends (§3, §4.8) |
| Exploits | Furniture moving under walking shoppers | "Back soon" while decorating: no new shoppers until you're done (§4.8) |
| Exploits | Spamming one cheap decoration for Charm | Each extra copy counts less (1/2, 1/3...); Charm caps at +1★; Robux decor has the Charm of the cheapest coin item its size and can't be sold for coins (§4.8, §7) |
| Exploits | Selling the free starter kit and the new buildings' gifts for coins | Free items can be put away but not sold |
| Exploits | A stockroom with no limit would be a second barn; putting a display away could lose goods | The stockroom has a size per level; goods from a display put away always fit (§4.8) |
| Exploits | Worker XP farmed by busywork | XP only for real work (a crate moves on, a shopper is served); idle workers learn nothing (§4.9) |
| Exploits | The audit of 2026-11-05: "nan" at the police desk made a purse that passed every price check | `FineRules.payAmount` takes real amounts only, `DataService` refuses anything else, and a save loaded with such a purse is emptied |
| Exploits | The audit: the seconds after any server move trusted wherever the client said, so a thief could climb out and appear at home with the crop | The server's spot stays trusted; moves from too far off are ignored (§4.12) |
| Exploits | The audit: a client can fake the "pass bought" signal | Roblox is asked whether they own it (`UserOwnsGamePassAsync`) before it counts |
| Exploits | The audit: a client can trigger a prompt from anywhere: the Auction House's benches moved you to the seat | Benches check you're close, and free to go |
| Exploits | The audit: Visit on your own farm skipped Home's 3 s wait in a raid | It is Home now |
| Exploits | The audit: a long enough text could stall a server in a string pattern | Remotes take 200 characters (`ActionRemote`; a layout 20,000, a store name 200), and renames and layouts one a second |
| Exploits | The audit: hiring the same candidate twice by writing the board's number differently ("0012") | A hire is remembered by its numbers (`WorkerRules.hireKey`) |
| Exploits | The audit: two players joining at once could be given one farm (and its bat) | The free farms are counted after the wait for Roblox's friends list |
| Exploits | The audit: characters pushing each other is how an exploit flings people, and how anyone could block a doorway | Characters don't collide with each other (the "Players" collision group) |
| Exploits | A new building's walls appearing on top of a player | Anyone in the way is moved out first (§4.8) |
| Balance | Old Sorter numbers (+8% grade A a level) reach 112% over 10 levels | +5% a level, 85% at Level 10 (§4.9) |
| Balance | With every bonus stacked, a Level 20 store would bring ~46 shoppers a minute | Slower curve (4 s at Level 20) and at most 12 shoppers inside (§4.8) |
| Balance | Costs had to fit the economy | A scratch run of the progression sim with all three ladders: Level 5 of both on day 2, Level 10 on days 11–12, Level 15 on days 29–30 for a daily player; coins level off (0.5 million on day 35 instead of 4 million); land pacing still passes (§6.2) |
| UI | 6 side-bar crates don't fit a phone's left edge in one column (the week 2 play-test already hit 3) | 2 columns of 3 on phones (§5.2) |
| UI | Two level systems could look different | One blueprint level ladder in both the Warehouse and Store windows (§5.3) |
| Names | "Shop" and "Store" were both used | Players see **Store** (Store Level, Store Rating, Top Store); the code can keep `shop` |

Left open: the very long tail once both ladders are done (§11 step 6), and whether players can visit and "like" each other's stores (a Coziest Store board): a v1.1 idea, since likes from alt accounts would need guarding.

### Checklist against the original brief

| Requirement | Where |
|---|---|
| Players get their own plot | §3, §4.1 |
| Farm land unlocks by progress (added later) | §4.1b |
| Buy seeds from a shopkeeper | §4.3 (Barley) |
| Rare items and seeds from an auction | §4.4 |
| Grow time by rarity, offline growth much slower | §4.2 (25% offline) |
| Harvested crops go to the inventory | §4.5 |
| Buildable warehouse with every packing step, onto a truck or into your own shop | §4.6, §4.8 |
| Truck sales at a global market price, your shop at your own price | §4.7, §4.8 |
| Hire workers split by job, with a limit per station | §4.9 |
| Players can steal crops; ways to defend the farm | §4.10, §4.11 |
| A bat inside your own plot, gone outside it | §4.12 |
| Bat hit in someone else's farm → 5 s knockout; the owner can arrest; they appear outside the police station; compensation is a small % of their revenue | §4.12 (anyone is knocked out, only Suspects can be arrested, 8% of 60-min earnings) |
| Counters to quitting before an arrest, and other bypasses | §4.12 table |
| Trading | §4.13 |
| The game's own GUI and UI design | §5 |
| Your own store, decorated with racks and shelves, with workers and upgrades (added 2026-10-31) | §4.8 |
| Workers level up from low to high efficiency (added) | §4.9 |
| The warehouse levels up for more capacity and features (added) | §4.6 |
| Market prices from a button anywhere, not only in town (added; built in week 2) | §4.7, §5.2 |

## 11. Next steps

In order. Each one makes the next one cheaper. Every step ends with a review against this doc (logged in §10) before the next one starts. Play-testing runs alongside from now on: [PlaytestPlan.md](PlaytestPlan.md) has a stage after each block of MVP weeks, with pass bars and gates.

1. ✅ **Set up the project.** Rojo + Rokit, ProfileStore, `DataService` (with a hook that runs automatic arrests before a save closes), `MovementService` / `MoveRules`, Analytics, the Lune test harness and `tools/check`, all from Tide Market. Still to port: the UI helpers (`UI.compact`, `UI.touch`, panels, item cards) re-skinned to Kraft & Crate, and the dev-command service; both come with week 1.
2. ✅ **Write the shared rules with Lune tests.** `GrowthRules`, `SeedStock`, `MarketPrice`, `DemandModel`, `LandRules`, `CrimeRules` (every bypass in the §4.12 table), `FineRules`, `TravelRules`, `ZoneRules`, `AuctionRules`, `WorkerRules`, `PipelineRules.simulate`, plus config checks: 155 tests, all passing (`lune run tools/check`).
3. ✅ **Build a progression sim.** `lune run tools/progression`: the XP curve is tuned so every permit target is met, and wages stay at 5–8% of income. It also showed that coins pile up late (see step 6).
4. ✅ **Greybox Cloverdale and time the raid race.** The layout, the greybox and the race from real distances are done and tested (5.8 s without defences; re-timed for every defence with the week 6 rebalance, §4.11). Walked in Studio on 2026-10-30 (play-test Stage A, §10): the distances hold. Still open from Stage A: A7 (finding your way) needs a new tester.
5. **MVP weeks 1–5 (§9)**, play-tested as they land (PlaytestPlan Stages A–D). ✅ Week 1 (the farming loop, with its dev commands and the first look pass: light, fences, the field and crops). ✅ Week 2 (selling: the Packing Shed, the pickup, the market, the Farm Stand), played in Studio on 2026-10-31. ✅ Week 3 (your store: the building and its 4 stages, Store Levels, Decorate, shoppers in the aisles), played in Studio on 2026-10-31; then the stores and the valley were made bigger (§10), so a Supermarket is 80 × 56 studs and each farm is 220 wide. ✅ Week 4 (Warehouse Levels 1–20, workers with Levels 1–10, the Hiring Hall, the Welcome back card, the sim with the real tables), played in Studio on 2026-11-01 (§10). ✅ Week 5 (raids: stealing, the bat, knockouts, arrests, fines and debt, the Police Station), played in Studio with 2 players on 2026-11-02 (§10); then reworked after review the same day: stolen crops held up in your hands, the bat's hold and swing, no travel cooldowns, no flicker anywhere, solid trucks (§10); and then a patch gives several, coins ×10 and Field Levels 1–5 (§4.1c, §10), the crops drawn as low-poly meshes (§10), and after a review of every visual the farmhouse and barn, wild land and produce on shelves (§10; what's left goes with weeks 6–8, ArtDirection §11). ✅ Week 6 (defences, the rest of the theft alarm, the Sprout Shield and arrival grace, the Trusted list, the Watchman), built and played in Studio with 2 players on 2026-11-02 (§10). Week 7 (weather and night, mutations, the Harvest Moon, Floodlights, the Auction House, quests, the streak and the Cropdex) built and played in Studio with 2 players on 2026-11-03 (§10), and the town's look built and checked in Studio on 2026-11-04 (§10). Week 8 (the Farm Guide, trading, the market's supply factor, leaderboards, the valley) built and checked in Studio with 2 players on 2026-11-04 (§10). Week 9 (settings, sounds and music, the Robux shop, analytics, the page art) built and checked in Studio on 2026-11-04 (§10). Stage D with testers alongside, then Stage E after week 8 (PlaytestPlan). The look pass ([ArtDirection.md](ArtDirection.md) §11) carries on alongside. The raid stage measures the arrest rate (target 35–50%) and whether raids feel fun from both sides before defences are built in week 6.
6. **Late-game coin sinks** (found by the sim). Mostly answered by Warehouse and Store Levels, store decor and worker Levels 1–10 (§6.2): coins now level off through the first month. Still open: the very long tail once both ladders are done (around day 50 for a daily player). Ideas: bigger auction lots and a weekly "Grand Auction", a coin-bought prestige ("Harvest Festival") that resets land for a permanent bonus, seasonal decor sets, costly seasonal seeds. Decide with live data after launch.
7. **Content and policy checks before launch.** Run the maturity questionnaire with the bonk and arrest content (aim for *Mild*), name the crops and NPCs, and import the crop meshes into the published place (`tools/crop_art`, README step 4; done 2026-11-02 in the local place). From week 9 ([RobloxPage.md](RobloxPage.md)): publish the game to its community first, then make the passes and products on the Creator Dashboard and paste their ids into `Config/Monetization` and `Config/Cosmetics`, upload the generated sounds and paste theirs into `Config/Sounds`, upload the icon and thumbnails, and fill in the page's description.
