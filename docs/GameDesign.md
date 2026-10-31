# Farm Heist: Game Design Doc

_Status: MVP week 2 built · Last updated 2026-10-31_

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
                     (thief's Loot Sack → their barn)        Warehouse: Intake → Sort → Pack
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
 │  FARMHOUSE + BARN (owner spawn, deposit point)                     │
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
1. **Plant** your 5 free Carrot seeds (the field tiles glow)
2. **Water** them (the watering can, hotbar slot 2)
3. **Harvest** when they pop (ripe crops bounce and sparkle)
4. **Pack a crate** at the Packing Shed bench (the pack minigame)
5. **Load & dispatch** the pickup (the receipt shows the price you locked)
6. **Buy seeds** from Barley in town (the **Home** button brings you back)
7. **Stock your store**: pack a crate with 🏪 Store, press Fill at a display, set a price
8. **Hire a Shed Hand** at the Hiring Hall (Patty: "First one's on the house!")

Steps 6–7 need a second harvest, so the card says "Plant your new seeds" in between. Farm Level 2 (needed to hire) comes at 60 XP, which the Guide reaches on its own. It also gives the first Land Permit (§4.1b), and the "all done" card points at the glowing block to clear. Finishing pays **300 coins** once. A marker and an edge arrow point to each spot, and the HUD button you need pulses.

**Sprout Shield:** your first **45 minutes of play** (`Crime.SHIELD_SECONDS`). Nobody can steal from you and you can't steal. A soft green dome sits over your field with a timer on it. When it ends you get the **Farm Rules** card: "Ripe crops can now be stolen. In your farm you hold a bat. Bonk a thief, then arrest them!" with a 15 s animated demo. You can drop the shield early (Settings) if you want to start raiding.

### 4.1 Plots
- One per player, given out on join: the free plot next to a friend if one is in the server, otherwise the nearest free plot to the highway. Your farm is saved *relative to the plot*, so it rebuilds the same on any plot in any server.
- **You join at your farmhouse door.** The first time, a short fly-over from the town to your farm shows where everything is.
- **Start:** 100 coins, 5 Carrot seeds, a 4×4 field, the Packing Shed (Warehouse Level 1), a Corner Store (Store Level 1) with its starter kit, the farmhouse, a wooden back fence and an unlocked gate.
- **Land:** the field is an 8×8 grid, but at the start only the 4×4 corner by the farmhouse is cleared. The rest is overgrown and opens up as you level up (§4.1b).
- **Trusted list:** up to 10 players (friends first in the picker). Trusted players can walk in and out freely, **water and harvest for you** (the crops go to your barn), can't be hit by your bat, and can't steal from you.
- **Arrival grace:** for 2 minutes after you join a server your field is protected (the same dome as the Sprout Shield), so you can harvest what ripened while you were away. During it you can't steal either.
- **When an owner leaves**, their farm closes: anyone inside gets "This farm just closed" and is moved to the sidewalk, any steal holds are cancelled, Suspect marks for that farm are cleared and anyone knocked out there wakes up.

### 4.1b Clearing land (unlocks by progress)
Your farm grows with you. The field's 8×8 grid starts with only the 4×4 corner by the farmhouse cleared. The other **12 blocks** (2×2 tiles each) are overgrown with tall grass, rocks and stumps. Coins alone can't open them: land opens with **Farm Level** (`Config/Land.luau`).

| Land Permit | Farm Level | Clearing fee | Field after |
|---|---|---|---|
| 1 | 2 | 250 | 20 tiles |
| 2 | 4 | 2,000 | 24 |
| 3 | 6 | 4,000 | 28 |
| 4 | 8 | 7,000 | 32 |
| 5 | 10 | 12,000 | 36 |
| 6 | 12 | 20,000 | 40 |
| 7 | 14 | 35,000 | 44 |
| 8 | 17 | 55,000 | 48 |
| 9 | 20 | 85,000 | 52 |
| 10 | 24 | 130,000 | 56 |
| 11 | 28 | 190,000 | 60 |
| 12 | 32 | 250,000 | 64 (the full 8×8) |

- **Permits come from levelling up.** Reaching each level in the table gives one Land Permit, with a level-up fanfare and a "Land Permit!" card. An unused permit shows as a badge on the Barn button and a glowing "Clear here" sign on the field. The level is what unlocks the land; the fee is a coin sink. Permit 1 costs only 250 because the Guide ends by pointing at it, and a new player has about 600 coins at that point.
- **Clearing:** use a permit on any overgrown block **touching land you've already cleared**. Pay the fee, then clear its 4 obstacles (a stump, a rock, weeds and a bush): each is a 2 s hold with the hoe, with a satisfying pop. A Farmhand clears them in 30 s. Fresh soil gives the first crop planted there +25% growth.
- **Which block is a real choice.** Blocks towards the back fence are nearer where raiders climb in (see the raid race in §4.11). Blocks beside the farmhouse are safer, but there are only a few of them. The permit card labels each block it can go on: "Safer: near the farmhouse" or "Riskier: near the back fence".
- **Why level, not coins.** Coins can arrive all at once from a lucky Mythic or a trade. Levels only come from playing: harvesting, shipping, selling, arrests and the Cropdex. Tying land to level keeps the field the size a player has learned to run and defend, so nobody skips the early game with one big trade, and a new player is never left guarding a huge field.
- **Buildings already work this way:** each Warehouse and Store Level needs a Farm Level (§4.6, §4.8). With land on the same ladder, all growth is paced by level.
- **Pacing targets** (to be tuned with a progression sim, like Tide Market's `tools/progression`): permit 1 in the first session (Lv 2 comes during the Farm Guide), permit 6 (Lv 12) around day 3, the full 8×8 around weeks 3–4 for a daily player.
- Land Permits are never sold for Robux, and you can't trade them.

### 4.2 Crops and growth
- **6 rarities** (`Config/Rarities.luau`):

| Rarity | Colour | Grow time (online) | Steal hold | Sack weight | Seed stock chance |
|---|---|---|---|---|---|
| Common | grey | 1–2.5 min | 1.0 s | 1 | always |
| Uncommon | green | 4–6 min | 1.5 s | 1 | 85% |
| Rare | blue | 12–20 min | 2.5 s | 2 | 55% |
| Epic | purple | 40–60 min | 3.5 s | 3 | 25% |
| Legendary | gold | 2–3 h | 5.0 s | 5 | 8% |
| Mythic | pink, rainbow shimmer | 6 h | 7.0 s | 5 | 2% (mostly from auctions) |

- **Growth stages:** seed → sprout → growing → ripe (each has its own model, so a field reads at a glance). Ripe crops bounce gently and sparkle in their rarity colour. Mythics glow and can be seen from the ring road.
- **Online** growth runs at 100%. **Offline** growth runs at **25%** (`Growth.OFFLINE_RATE`), so a 6 h Mythic takes 24 h if you're away the whole time. Growth is stored as `progress` (0–1) plus `lastUpdate`, banked when you leave and settled when you join, so it costs nothing while you're gone. Online-only growth bonuses (weather, sprinklers, Growth Boost) don't apply offline.
- **Speed-ups:** watering (once per crop per stage: −10% of the time that stage has left), Sprinklers (an area +20%), Fertilizer (one tile ×2 for 10 min, consumable), weather (§4.14), the Growth Boost product (§7).
- **Regrowing crops** (tomato, strawberry, blueberry, grape, golden apple) give several harvests. After each harvest the plant goes back to "growing" for its regrow time. Thieves only take the fruit; the plant stays.
- **Mutations** (§4.14) can appear on **ripe crops left in the field** during weather. Leaving them in the ground is a gamble: they might mutate or they might get stolen. Tap a tile and choose 🚩 **Leave in field** so Farmhands skip it.
- **Giant crops:** Rare and above have a 1% chance to ripen as a Giant (×3 value, 2.5× the model size). Great to show off, and a magnet for thieves.

### 4.3 Barley's Seeds (seed shop)
- Barley stands behind the counter. Talk to him (E) to open the **Seed Rack** window.
- **Restock every 5 minutes on the clock**, the same on every server (a seeded roll, like Tide Market's `BaitStock`). Commons are always in, with no limit (a field of 1-minute Carrots needs a lot of seed). Every other seed rolls its rarity's stock chance, then comes in packs: 1–5 packs of 5 (Uncommon), 1–4 of 3 (Rare), 1–2 of 2 (Epic), 1 seed (Legendary, Mythic). Each player has **their own** stock, so buying never takes from anyone else. It's saved per restock, so rejoining doesn't refill it. A Legendary or Mythic in stock is announced to the server ("Barley just got a Moonmelon seed in!").
- Farmhands replant from your seed stock, so someone still has to come to town for seeds.
- Seeds above your Farm Level show locked ("Lv 10"), so players can see what's coming.
- Buying needs you to be at the counter (server distance check). Leaving your farm to shop is a small risk, on purpose.

### 4.4 Cloverdale Auction House
- **A live auction every 8 minutes** on the clock (:00, :08, :16 …), with a 1-minute warning toast that has a **Town** button.
- **3 lots per auction**, about 60 s each. Each server rolls its own lots from the pool (`Config/Auction.luau`): Epic seed 30% · Legendary seed 20% · Mythic seed 8% · golden tool 12% (Golden Watering Can, Golden Hoe) · rare worker contract 15% · defence item 10% · cosmetic 5%.
- **Opening bid** is 40% of the lot's estimated value. The **minimum raise** is 5% (at least 10 coins). Quick-bid buttons: **+5% · +10% · +25%**.
- **Anti-snipe:** a bid in the last 10 s puts the clock back to 10 s.
- **Escrow:** bidding moves the coins out of your wallet. If someone outbids you, they come back straight away. Winning spends them (a coin sink) and the item goes into your inventory, saved immediately.
- **You must be inside the hall to place a bid** (trusted position). Holding a bid doesn't need you to stay. If the leading bidder leaves the server, their bid is cancelled and the highest earlier bidder who can still pay takes the lead.
- The auctioneer (**Goldie Gavel**) calls it: "Going once… going twice… SOLD to Sam!" with the gavel, confetti and the lot flying to the winner.
- **v1.1: Auction Board.** Players list their own items across all servers (MemoryStore), with a reserve price, 1 h listings and a 5% fee (a coin sink).

### 4.5 Inventory (the Barn)
- Harvesting a crop puts it **straight into your Barn inventory** (a pop and a +1 in a little basket). Tabs: **Crops · Seeds · Items · Workers · Land** (the block map, permits waiting, and the blocks each one can go on).
- Crops stack by crop + mutation (+ Giant). Capacity is **200 crop units** at the start. The Silo upgrades raise it to 500 / 1,500 / 5,000 (2,000 / 20,000 / 120,000 coins). When it's full, harvesting stops ("Barn full!" and the Farmhands stop with it).
- **Returns and deposits always fit.** Loot returned to an owner, or emptied from a sack into your own barn, goes in even past capacity. The barn then shows "Over capacity" and harvesting waits until you've sold some.
- **The Loot Sack is separate.** Stolen crops go in the thief's sack, not their inventory. They become the thief's only when the sack is emptied at the thief's **own barn** (hold E, 1 s). If anything goes wrong before that (§4.12), the loot goes back to the owner.

### 4.6 Warehouse (Warehouse Level 1–20)
The way to sell in bulk. Crops go through stations, and **each station can be done by hand (a short minigame) or by workers**. The warehouse grows by **Warehouse Level** (1–20). Every level adds one thing you can feel: a bigger truck, a quicker trip, a worker slot, more room, a new tool. Four of them (1, 5, 10, 15) are a new building.

| Step | Station | By hand | What it does |
|---|---|---|---|
| 1 | **Intake** | (the crew's: routed crops flow in from the barn) | The intake hopper at the back door, toward the field |
| 2 | **Wash & Sort** | Hold to spray at the **wash table**; let go when the meter is in the green | Grades each batch **A** (×1.15 value) or **B** (×1.0). Doing it by hand gives the best chance of an A |
| 3 | **Pack** | (by hand the same hold packs it: one hold a crate, as at the shed) | Crates by rarity: up to 12 Commons · 10 Uncommons · 6 Rares · 4 Epics · 2 Legendaries · 1 Mythic (in a velvet case). A crate can go out part-full by hand; the crew packs full ones |
| 4 | **Route** | Set once in the Warehouse window | Each crop goes **→ Truck**, **→ Store** or **✋ Keep** (the crew leaves it in the barn for you), or a split, e.g. 70/30, from Level 5 |
| 5 | **Load** | "Load crates" at a truck's dock: the **hand cart** takes 4 at a time from the Cold Room | Fills that truck's bed |
| 6 | **Dispatch** | Pull the dock's lever, or **Send now** in the Market window (every truck home and loaded) | The truck leaves. **The price locks now**, and you get a receipt |

- **Routes from Level 1:** the Shed Hand (§4.9) needs to know what to pack, so the Routes tab is there from the start: Truck, Store or Keep for each crop (new crops go by truck); splits come with Level 5. **By hand in the warehouses** you use the wash table, the shed's bench grown up: one hold washes and packs a crate (one hold a crate is enough on a phone), and a truck crate rides the conveyor to the Cold Room instead of into your arms. Loaders, or you with the hand cart, put Cold Room crates on the trucks; store crates go to the stockroom on the conveyor.
- **The Packing Shed (Levels 1–4) has no Intake:** its bench pulls crops straight from the barn. Each barn stack has two buttons with what each pays right now, **🚚 Truck 21** (today's market price) and **🏪 Store 24** (your price there), so you choose with both numbers in front of you. Then you **hold to wash** and let go in the green for grade A; the crate packs itself (the tape swipe is the Pack station's job from Level 5; one hold per crate is enough on a phone). A truck crate goes **into your arms**: carry it to the dock and "Load crate". A store crate goes to your store's stockroom (§4.8). (`WarehouseService`, `shared/CrateRules`.)
- **Nothing gets lost on the way to the truck.** If you leave your farm, travel, respawn or quit while carrying a crate, it's set down at the dock, and "Load crate" takes from that pile too.
- **The truck** backs up to the dock at the top of the driveway. "Send the pickup" is the lever on the dock, or **Send now** in the Market window from anywhere (so you can watch the prices and send at the right moment). It drives out through a striped boom gate (people can't pass it), round the ring road the short way and up the highway into the tunnel; the crates ride along until they're sold, and it comes back empty. A paper receipt lists each crate and the price it locked. **You're paid when it reaches the City** (half the trip). Each run is a saved `TruckRun`: if you've left by then, it's paid the next time you join (any server), shown on the Welcome back card. (`TruckService`, `shared/TruckRules`; clients drive the truck from its `DepartAt`/`ArriveAt`/`ReturnAt` attributes.)
- **The Cold Room** holds packed crates waiting for a truck (at the Packing Shed it's the rack on the dock). When it's full, packing pauses. It's what lets you **hold crates for a better price**: wait for ▲ on the board, or give your Driver a price rule (§4.9).
- **Levelling up:** the Warehouse window's **Upgrade** tab is a blueprint with the level ladder: where you are, the next level's card (cost, Farm Level needed, what it adds) and **Upgrade**. Ordinary levels are instant. The four building levels take time to build (builders and scaffolding, at the same online/offline rates as growth) and the old building keeps working until the new one is done. Levels never go down. From Level 5 the warehouse buildings are enclosed, so they get the store's see-through roof (§4.8): an `Interior` box beside the `Roof` model.

| Lv | Cost | Farm Lv | Truck(s) | New at this level |
|---|---|---|---|---|
| 1 | free | 1 | Pickup: 4 crates, 60 s | **Packing Shed**: the bench, the dock, the lever, a dock rack for 6 crates (the Shed Hand stacks crates there while the pickup is out; a crate you set down always fits); 1 Shed Hand |
| 2 | 800 | 2 | 5 crates | |
| 3 | 2,000 | 3 | 50 s round trip | dock rack holds 10 |
| 4 | 3,500 | 4 | 6 crates | 2 Shed Hands |
| 5 | 8,000 | 5 | Box Truck: 12 crates, 90 s | **Distribution Warehouse** (builds in 2 min): Intake, Wash & Sort, Pack and Load stations on conveyors, a hand cart, route rules, Cold Room 20 crates. Sorter 1 · Packer 1 · Loader 1 · Driver 1 (Shed Hands become Packers) |
| 6 | 12,000 | 6 | 14 crates | Packer 2 |
| 7 | 18,000 | 7 | | conveyors ×1.1 · Cold Room 30 |
| 8 | 26,000 | 8 | 75 s round trip | Sorter 2 |
| 9 | 36,000 | 10 | 16 crates | Loader 2 |
| 10 | 60,000 | 12 | 2 × Semi: 24 crates, 120 s | **Big Warehouse** (5 min): a second dock and truck · Driver 2 · Packer 3 · Cold Room 50 |
| 11 | 80,000 | 13 | 26 crates | |
| 12 | 105,000 | 14 | | conveyors ×1.2 · Sorter 3 · **Wash Line**: Sorters' grade A chance +5% |
| 13 | 135,000 | 16 | 28 crates | Packer 4 · Cold Room 70 |
| 14 | 175,000 | 18 | 30 crates, 110 s | |
| 15 | 250,000 | 20 | 2 × Reefer: 34 crates, 100 s | **Distribution Center** (10 min): **Premium contracts** (Legendary and Mythic crates +10%) · conveyors ×1.35 · Loader 3 · Cold Room 100 |
| 16 | 340,000 | 22 | | Packer 5 |
| 17 | 450,000 | 24 | 38 crates | |
| 18 | 600,000 | 26 | 80 s round trip (the **Express lane**) | Sorter 4 |
| 19 | 780,000 | 28 | 40 crates | conveyors ×1.5 · Cold Room 150 |
| 20 | 1,000,000 | 30 | 3 × Reefer | a third truck and Driver 3 · gold trim on the building |

The whole ladder costs about 4.1 million. In the progression sim (§6.2, `lune run tools/progression`) a daily player reaches Level 5 on day 2, Level 10 on day 9 and Level 15 on day 22; a casual one Level 10 on day 15; Level 20 is a goal for the second month. Each truck has its own dock, lever and lane through the front fence (a striped boom each): the docks at 29, 55 and 81 across, the buildings growing from the Packing Shed's corner toward the hedge and the field (`PlotLayout.WAREHOUSES`). (Built in week 4: `shared/WarehouseRules`, `WarehouseService`, `World/YardArt`.)

- **The Warehouse window is a clipboard** with three tabs (🏭 on the side bar). **Pipeline:** each station is a box with its queue, worker slots ("2/3", and which level opens the next) and a throughput figure in crates a minute. **The slowest station is highlighted orange** with a tip ("Pack is your bottleneck: hire another Packer or train yours"). Each truck shows a fill bar, an ETA and **Send** with the price it would lock, and the Drivers' rule. **Routes:** crop → Truck / Store / Keep / split. **Upgrade:** the level ladder above.

### 4.7 Global market price (the Cloverdale Exchange)
Every crop's truck price is the same on every server at any moment:

`price(crop, t) = base × wave(t) × event(t) × supply(t)`, clamped to **0.5–2.0 × base** and rounded to whole coins (`shared/MarketPrice.luau`).

- **wave(t)**: `1 + 0.12·sin(2πt/45min + φ₁) + 0.08·sin(2πt/3h + φ₂)`, with φ from a hash of the crop id. Smooth ups and downs (0.8–1.2) that are the same on every server without any messaging.
- **event(t)**: a deterministic schedule from the hour index. Each hour has one **Hot Crop** (×1.5 from :10 to :25) and one **Glut** (×0.75 from :40 to :55), two different crops and never Mythics, announced 2 minutes ahead. Seasonal festivals too (e.g. a Pumpkin Festival in October: pumpkins ×1.3 all week).
- **supply(t)**: player-driven. Each server adds the units it sold to MemoryStore counters (`Market_<crop>_<window>_<shard 1–8>`, 10-minute windows, written in batches every 30 s). `supply = clamp(1 − 0.12·log₂(1 + sold/expected), 0.7, 1.0)`. If everyone dumps carrots, carrots drop everywhere, so it pays to grow different things. If MemoryStore fails it falls back to 1.0.
- **The Exchange board** in town (a split-flap board on the grain elevator's face) and the **Market** window (a chalkboard, from the side bar or the Exchange desk) show each crop's price, a ▲/▼ trend over the last 10 minutes, a 3-hour sparkline and this hour's events. A chalk ticker under the purse cycles through the live events and the crops in your barn. The clients work all of it out from `shared/MarketPrice` and the server clock: the same numbers the server locks. Until the supply factor arrives (week 7) supply counts as 1.
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

**Decorating.** **Decorate** in the Store window (on your farm or in your store) lifts the camera over the store with the grid in chalk, the roof off and the walls faded. A drawer of item cards (Displays · Checkouts · Decor · Wall · My items) runs along the bottom. Tap a card, then a cell: the item shows green where it fits and red where it doesn't (with why). ⟳ turns it, ✓ (or a second tap) places it. Tap a placed item to move, turn, put it away (it stays yours) or sell it back for half. On a computer: it follows the mouse, a click places it, R turns it. Pinch (or the mouse wheel) zooms in and a drag (or WASD) moves the view, for the bigger buildings on a phone. **It's a plan until you press DONE**: then the server checks the whole layout once, buys what's new (the total is shown under DONE all along) and saves it; ✕ leaves your store as it was. So you can try things out freely, and nothing moves under a shopper's feet until you're done.
- **The rules** (`shared/StoreLayout`, the same check on the client and the server): items sit inside the open floor and don't overlap (a Rug is walked over, but nothing stands on it). The cells inside the front door and the staff door stay clear. Every display and checkout has a front, and the cells in front of it must be free. **Every one of those front cells must be reachable from the door** through free cells, and so must the staff door. Each checkout needs a queue: its till's front cell and 2 more free cells in a line (straight back, or turning left or right), not shared with another checkout. A Register needs the cells behind it free, for whoever serves. At least one checkout, and no more than the level allows. A move that breaks a rule is refused with why: "This would block the aisle to your Pumpkin shelf". Wall items hang on the back and side walls (the front is the shop window), never over the staff door.
- While you decorate, the store hangs a **"Back soon"** sign: no new shoppers come in, and those inside skip the rest of their list and go to pay. Anyone still inside when you press DONE puts their basket back and leaves (no rating score). Leaving your farm and store, or 5 minutes without changing anything, ends it.
- **Your store starts furnished:** an Honour Box, 2 Produce Crates, a Wooden Shelf and a Potted Plant, already placed. Decorating is never required to sell. (On the 6×4 floor: the shelf, crates and plant along the back wall facing the door, the aisle in front of them, the Honour Box in the corner by the door with its queue up the side wall, and the middle of the floor free: room for 3 or 4 new displays before the first upgrade.)
- At most 100 floor items and 40 wall items, which keeps a full store's parts in check on phones (a full display is about 25 parts with its produce; streaming will load far farms whole, ArtDirection §10).

**The catalog** (`Config/Store`). Items are bought once with coins and kept ("My items"). Selling one back pays half. Free items (the starter kit and each new building's gift) can be put away but not sold.

| Displays | Size | Holds (slots × units) | Crops | Shoppers pay | Cost | Store Lv |
|---|---|---|---|---|---|---|
| Produce Crate | 1×1 | 1 × 12 | Common–Uncommon | ×1.00 | 150 | 1 |
| Wooden Shelf | 2×1 | 2 × 15 | Common–Rare | ×1.00 | 600 | 1 |
| Bulk Bin | 1×1 | 1 × 40 | Common | ×0.95 | 900 | 3 |
| Tiered Produce Rack | 2×1 | 3 × 15 | Common–Rare | ×1.05 | 2,500 | 5 |
| Chiller Cabinet | 2×1 | 2 × 12 | Uncommon–Epic | ×1.10 | 8,000 | 8 |
| Glass Showcase | 1×1 | 1 × 4 | Rare–Mythic | ×1.15 | 25,000 | 10 |
| Velvet Pedestal | 1×1 | 1 × 1 | Legendary–Mythic | ×1.25 | 120,000 | 15 |

"Shoppers pay" is the display's presentation: it multiplies what shoppers are willing to pay for what's on it (§4.8 shoppers). A slot holds one crop.

| Checkouts | Size | Serves | Needs | Cost | Store Lv |
|---|---|---|---|---|---|
| Honour Box | 1×1 | a shopper every 6 s (they pay themselves) | nothing | free (a second: 500) | 1 |
| Register | 2×1 | a Cashier's speed (§4.9), or a shopper every 3 s while you stand behind it | a Cashier or you | 3,000 | 3 |
| Self-checkout | 1×1 | a shopper every 4 s | nothing | 60,000 | 15 |

Checkouts allowed: 1 (Levels 1–2), 2 (from 3), 3 (from 10), 4 (from 15). Each has a queue of 4; a shopper who waits 20 s puts their basket back and leaves.

| Decor (Charm) | Size | Charm | Cost | Store Lv |
|---|---|---|---|---|
| Potted Plant · Hay Bale Seat | 1×1 | 2 | 200 · 400 | 1 |
| Flower Barrel | 1×1 | 3 | 500 | 2 |
| Pumpkin Pile | 1×1 | 3 | 800 | 3 |
| Painted Sign · Chalk Board · Clock (wall) | wall | 3 | 1,000 · 600 · 2,000 | 4 |
| Lamp Post · Rug | 1×1 | 4 · 3 | 1,500 · 1,200 | 5 |
| Fairy Lights (wall) · Fruit Cart (2×1) | | 5 · 6 | 3,000 · 5,000 | 6 |
| Bench (2×1) · Mural (wall, 2 wide) | | 4 · 8 | 2,500 · 20,000 | 9 |
| Fountain (2×2) | 2×2 | 12 | 40,000 | 10 |
| Flower Arch (2×1) · Neon Sign (wall) | | 10 · 8 | 30,000 · 25,000 | 12 |
| Golden Scarecrow statue | 1×1 | 20 | 250,000 | 17 |

**Charm** is your decor added up: each item's Charm, but a second copy of the same item counts half, a third a third and so on (so 10 Potted Plants are worth about 6, not 20: variety wins). **Every 10 Charm adds +0.1★ to your Store Rating, up to +1★ at 100 Charm.** Displays add a little Charm too (Tiered Rack 1, Showcase 2, Pedestal 4). Decor takes floor cells that could hold displays: that's the trade-off.

**Stock.** Crates you send to the store wait in its **stockroom** (the back room): 6 crates at Level 1, +2 a level, 44 at Level 20. When it's full, the bench and the Route rules send new crates to the truck instead (and say so). Putting goods out:
- **By hand:** stand at a display and hold **E: Fill** (it tops up each slot from the stockroom, grade A first, emptying the smallest crates first so they free up room), or **Fill all** in the Store window while you're in your store. A slot is kept to a crop, or **Auto** (a crop the display can hold that isn't out anywhere yet, then the one with most waiting); the Store window's Stock tab changes it.
- **Only crops your store can show go there:** at the Packing Shed bench the 🏪 Store button says "Store Lv 8" for an Epic until a Chiller Cabinet is unlocked (and "Full" when the stockroom is), so nothing gets stuck in the stockroom.
- **Stockers** (§4.9) refill any slot below half, the emptiest first.
- Putting a display away sends its goods back to the stockroom (even past full, like the barn), never lost.

**Prices** are as before: one price per crop for a standard unit (grade A ×1.15, mutations by their multiplier, shown on the tag), 50–300% of the reference `ref = ½ base + ½ market` (`shared/DemandModel`). The Store window shows what shoppers expect, what the truck pays now, the demand face (😀 🙂 😐 😟), the % that buy and about how many sell a minute. A crop going out for the first time is priced at the reference.

**Shoppers** (`shared/ShopRules`, `ShopService`; the clients draw them walking).
- **How often:** one every `20 × 0.92^(Level − 1)` seconds at 3★: 20 s at Level 1, 14 s at 5, 9 s at 10, 6 s at 15, 4 s at 20. Each star above 3 brings them 15% more often (each below, 15% less). **Variety:** each different crop on display after the first brings 5% more, up to +25%. A Greeter adds up to 25% more (§4.9); the Supermarket's billboard 15%.
- **What they want:** 1 crop at Levels 1–4, 1–2 at 5–9, 1–3 at 10–14, 2–3 at 15–20 (bigger stores, bigger baskets), each a crop on display (crops on more displays get picked more often).
- **How many at once** grows with the building: 8 in the Corner Store, 12 in the Farm Shop, 16 in the Market Hall and 24 in the Supermarket, counting those on the sidewalk (a full store makes the next one wait). A bigger store has longer aisles, so each visit takes longer (about a minute in a Supermarket); without more room the late levels' shoppers couldn't all fit. Each player's screen only draws shoppers within 300 studs, which keeps eight busy stores cheap on a phone.
- **The visit:** along the sidewalk and in through the door, along the aisles (the shortest path on the grid, cutting corners across open floor) to a display with each crop they want, standing in front of the slot that has it. There they roll a willingness `w` (log-normal, σ = 0.2) × the rating bonus (0 at 1★ to +25% at 5★) × the display's presentation, and take 1–4 units if `your price ≤ ref × w` (grade A first, at ×1.15), saying so in a bubble ("🥕×3", "Too dear!", "Sold out!"). Then to the shortest checkout queue, pay when they reach the till (a coin pop), and out. A shopper who gives up in the queue puts the basket back on the display. Nothing they wanted was affordable (or it sold out before they got there) → they leave without queueing.
- **Store Rating** (1–5★): the average of the last 50 shoppers' scores (5 bought · 2 too dear · 1 left the queue), a new store counting 10 shoppers at 3★ until real ones replace them, **plus Charm** (up to +1★), at most 5★. A store with nothing on display is closed: nobody comes to find it empty.
- **While you're away** shoppers keep coming at 25% (the Honour Box and Self-checkouts serve on their own; Registers need a Cashier; Stockers keep filling), worked out with the warehouse when you return (`shared/PipelineRules`, the Welcome back card).

**Store Levels** (the Store window's **Upgrade** tab: the same level ladder as the warehouse's). Every level opens floor, stockroom space or something new:

| Lv | Cost | Farm Lv | Floor | New at this level |
|---|---|---|---|---|
| 1 | free | 1 | 6×4 | **Corner Store**, starter kit, Honour Box, stockroom 6, 8 shoppers at once |
| 2 | 300 | 1 | 7×4 | Stocker 1 · Flower Barrel |
| 3 | 900 | 3 | 7×5 | **Register** and Cashier · 2 checkouts · Bulk Bin · Pumpkin Pile |
| 4 | 2,500 | 4 | 8×6 | the whole Corner Store · wall items: Painted Sign, Chalk Board, Clock |
| 5 | 6,000 | 5 | 9×7 | **Farm Shop** (+ a free Tiered Produce Rack) · 12 shoppers at once · Lamp Post · Rug · shoppers want 1–2 crops |
| 6 | 10,000 | 6 | 10×7 | Fairy Lights · Fruit Cart |
| 7 | 16,000 | 7 | 10×8 | |
| 8 | 24,000 | 8 | 11×8 | **Chiller Cabinet** (Epic crops) · Greeter · Stocker 2 |
| 9 | 35,000 | 10 | 11×9 | the whole Farm Shop · Bench · Mural |
| 10 | 55,000 | 12 | 12×10 | **Market Hall** (+ a free Glass Showcase) · 16 shoppers at once · Fountain · 3 checkouts · shoppers want 1–3 |
| 11 | 75,000 | 13 | 13×10 | |
| 12 | 100,000 | 14 | 14×10 | Flower Arch · Neon Sign |
| 13 | 130,000 | 16 | 14×11 | |
| 14 | 170,000 | 18 | 15×11 | the whole Market Hall · Stocker 3 |
| 15 | 240,000 | 20 | 16×12 | **Supermarket** (+ a free Self-checkout) · 24 shoppers at once · Velvet Pedestal · 4 checkouts · billboard (+15% shoppers) · shoppers want 2–3 |
| 16 | 330,000 | 22 | 17×12 | |
| 17 | 440,000 | 24 | 17×13 | Golden Scarecrow statue |
| 18 | 580,000 | 26 | 18×13 | |
| 19 | 760,000 | 28 | 19×13 | |
| 20 | 1,000,000 | 30 | 20×14 | the whole lot · a gold star on the sign and a Hall of Fame plaque |

Every level also brings shoppers a little more often (the formula above) and 2 more stockroom crates. The ladder costs about 3.9 million, plus whatever you spend on decor. In the progression sim a daily player reaches Level 5 on day 2, 10 around day 11 and 15 around day 29.

- **The Store window** (a shop counter with price tags): a header with your store's name (Rename), its rating with Charm and **why** ("3 shoppers gave up in the queue: open another checkout"), and a big **Decorate** stamp; then **Prices** (above) · **Stock** (Fill all while you're in the store, the stockroom's crates, each display's slots with their fill and Auto or a crop) · **Upgrade** (the next level on blueprint paper: cost, Farm Level, what it brings, Upgrade; then the next few levels).
- **Epics need a Chiller (Level 8)** and Legendaries a Showcase (Level 10): until then those crops go by truck. The Store window says so on the Prices tab, which keeps the store a step behind the field on purpose: a reason to upgrade.
- The store is the slow, high-margin outlet; the truck is the fast, bulk one at the market price. When the market's down (▼) shoppers still expect the usual price, so the store pays better; when it's up, the truck does.

### 4.9 Workers
Hired at the **Hiring Hall** in town or from the Workers window (from Farm Level 2). Each worker is a visible NPC on your farm or in your store, walking set routes between stations, carrying crates and waving at visitors. **Every worker has a level, 1–10**: a new hire works at **40%** of the job's full speed, and a worker at Level 10 at **100%**.

| Worker | Where | What they do | Slots (from) | Full speed (Lv 10) | Full wage / min |
|---|---|---|---|---|---|
| **Farmhand** | Field | Harvest ripe crops, replant with the seed you chose (same seed · cheapest · don't replant). Skips tiles flagged 🚩 *Leave in field* (§4.2). Out of seeds → stops and shows "Out of Carrot seeds" on the Barn button | 1 per 16 open tiles (max 4) | 30 tiles | 10.5 |
| **Shed Hand** | Packing Shed (Warehouse Lv 1–4) | Sort + pack + load. Becomes a Packer (same level and XP) at Warehouse Level 5 | 1, 2 (WH 4) | 8 crates | 8.75 |
| **Sorter** | Wash & Sort | Grade batches: grade A chance 40% at Lv 1, +5% a level (85% at Lv 10; +5% more with the Wash Line) | 1–4 (WH 5, 8, 12, 18) | 60 units | 8.75 |
| **Packer** | Pack | Pack crates | 1–5 (WH 5, 6, 10, 13, 16) | 15 crates | 8.75 |
| **Loader** | Load | Move crates from the Cold Room to the trucks (store crates ride the conveyor to the stockroom) | 1–3 (WH 5, 9, 15) | 20 crates | 8.75 |
| **Driver** | Truck | **Auto-dispatch** when the truck is full, or **only when the price is ≥ X% of base** (your rule). Their level shaves up to 10% off the round trip. The first Driver drives truck 1, the second truck 2 ... | 1 per truck (WH 5) | – | 14 |
| **Stocker** | Store | Refill displays from the stockroom, the emptiest first | 1–3 (Store 2, 8, 14) | 80 units | 8.75 |
| **Cashier** | Store register | Serve the queue | 1 per Register | 12 shoppers | 10.5 |
| **Greeter** | Store door | Welcome shoppers in: up to +25% shoppers (× their efficiency) | 1 (Store 8) | – | 8.75 |
| **Watchman** | Gatehouse (Farm Lv 8) | Rings the bell when a theft starts, shines a spotlight on the thief and shuts the gate **to Suspects** (15 s at Lv 1 up to 30 s at Lv 10; they have to climb out; everyone else still walks through). **Never knocks anyone out**. *Comes with the defences in week 6 (there are no thefts to watch for before week 5)* | 1 | – | 17.5 |

**Levels and efficiency.**
- **Efficiency** = 40% at Level 1, +6.7% a level, 100% at Level 10. Speed = the full speed × efficiency. Wages grow slower than skill: 60% of the full wage at Level 1 up to 100% at Level 10, so a levelled worker is quicker *and* cheaper per job (a new hire costs 1.5× as much per crate as a Level 10).
- **Experience:** workers earn XP by working: 10 XP a minute of real work (shown as a bar on their badge), 2.5 a minute while you're away. An idle worker (nothing to do) learns nothing, and XP only counts real work (a crate moves on, a shopper is served).
- **Training:** when the bar is full (it stops there: XP doesn't pile up past a level), the badge says **Ready to train**, and **Train** (coins) takes them up a level. XP needed: 600 × 1.5^(Level − 1) (an hour of work for Level 2, about 26 hours for Level 10; about 75 hours in all). Fee: 250 × (full wage ÷ 8.75) × 1.9^(Level − 1) (250 coins for Level 2, about 42,000 for Level 10; about 89,000 in all for a typical worker). So levelling takes both time and coins, and a full crew is a long-term goal: in the progression sim a daily player's workers average Level 6 by day 14 and 7 by day 28, the first hires Level 8 (offline they only learn while crates really move, so the slowest station sets the pace); a keen player's reach 9 by day 28. A first hire is ready to train after an hour of work, in the first session.
- **Hiring:** the board shows 3 candidates per type, changing every 10 min (each player's own board, the same all through the 10 minutes, so nothing about it is saved but who you took). Each has a level (1–3), a trait (**Speedy** +20% speed · **Careful** +10% grade A · **Night Owl** +30% at night · **Frugal** −20% wage) and a hire fee (40 minutes of their wage). Your first hire is free, at any Farm Level (the Guide's "First one's on the house!"); after that, hiring needs Farm Level 2. A Sorter's grade A chance stops at 95%.
- **Rare workers** come from auction contracts at Level 6–8 with a unique trait (e.g. *Grandma Rose, Legendary Packer*: Careful and **Tireless**, working at 50% instead of 25% while you're away).
- **Wages** come out of your coins every minute (a coin sink: under 13% of income on any day in the progression sim). If you can't pay, workers **go on strike** (sitting on crates with signs) until you can.
- **Slots** limit how many of each worker you can have; they open with Warehouse and Store Levels. The Workers window shows each station's slots (e.g. Packer 2/3), and greyed slots say what opens them ("Warehouse Level 10").
- **The Workers window** (👷 on the side bar; the Hiring Hall's job board in town opens it on the Hire tab) is a corkboard of ID badges: photo, name, type, level and efficiency (e.g. "Lv 4 · 60%"), the XP bar, the trait, the wage, **Train** when ready, and Let go (tap twice); the Farmhands' replanting at the top. The Drivers' rule is in the Warehouse window, by the trucks.
- **On the farm** each worker is a blocky NPC in their job's outfit with a name-and-level tag, busy at their station; Farmhands walk to the tiles they harvest, Loaders carry crates to the trucks, Drivers wait by their truck and go with it. On strike they sit on a crate holding a sign.
- **Offline:** workers keep going at **25% speed for up to 8 hours**, paid at 25% wages (a strike starts when the coins run out and ends when a sale brings some in). `shared/PipelineRules.simulate(state, seconds, rate)` runs the whole chain (Farmhands harvest and replant using offline growth → stations → trucks at the deterministic market price with supply = 1 → Stockers and store sales at 25% shopper flow). It's worked out in one go when you return (`WorkerService`; offline growth moved there from the field so crops never grow twice) and shown on the **Welcome back** card: time away, crops harvested, crates packed, trucks sent and coins (and still on the road), store sales, wages, any strike, and who's ready to train. Workers learn from what they did (2.5 XP a minute of it).
- Workers can't be hit, stolen or traded.

### 4.10 Stealing
- **What can be stolen:** only **ripe crops in someone else's field**. Never the barn inventory, crates, trucks or shelves. For regrowing plants only the fruit is taken.
- **How:** walk up to a ripe crop and **hold [E] Steal** (1 s Common up to 7 s Mythic, ×2 under a cloche, −25% on a Harvest Moon). A progress ring shows over the crop for everyone. The crop shakes and rustles.
- **The moment the hold starts:** the thief becomes a **Suspect** (§4.12) and the owner gets the **theft alarm** (§5.4).
- **Races:** if two thieves hold the same crop, the first to finish gets it and the other's hold is cancelled. If the owner (or a Trusted friend or Farmhand) harvests it mid-hold, the hold is cancelled and the thief is still a Suspect. Harvesting fast is the owner's quickest counter.
- **The Loot Sack** holds **5 weight** (Common/Uncommon 1, Rare 2, Epic 3, Legendary/Mythic 5, so one Legendary or Mythic fills it). Everyone walks at 16 studs/s and sprints at 24 (Shift / the Run button). With a sack on your back you walk **15% slower** (13.6), can't sprint, can't use any teleport (Home, Town, Visit), and your name tag turns red with a 🧺.
- **Getting away:** leave the plot (through the gate, or over the back fence: 1.5 s) and the owner's bat can't reach you. Walk home and empty the sack at your barn.
- **Limits that keep it fair** (`Config/Crime.luau`):
  - **Sprout Shield** (first 45 min of play, §4.0) and **arrival grace** (2 min after joining).
  - **Same-farm cooldown:** after leaving a farm with loot, or being arrested there, you can't steal from that farm for 3 minutes.
  - **Raid cap:** a farm loses at most **10 sack weight per 10 minutes** to all thieves together. After that it gets a *Neighbourhood Watch* dome for the rest of the window.
  - Sprout Shield and arrival grace work both ways: while you're protected you can't steal.
  - **Offline players can't be robbed:** their plot isn't in the server.
  - Trusted players can't steal from you.
- Farmhands harvesting quickly is a defence too: crops that aren't in the field can't be taken.

### 4.11 Defending your farm
The owner's main tool is the **bat** (§4.12). Everything else **slows, warns or exposes**. Nothing blocks a thief completely, so raids stay possible.

| Defence | Cost · level | Effect |
|---|---|---|
| **Bat** | free | Only while you're inside your own farm. Bonk → 5 s knockout |
| **Gate Lock** | 1,500 · Lv 3 | Only Trusted players can walk in. Anyone else has to climb the gate (2 s), which makes them a Suspect. A **"Private farm"** sign says so, and the first time someone starts climbing in they get a confirm ("Climbing in counts as trespassing"). Walking *out* is always free |
| **Tall Back Fence** | 3,000 · Lv 4 | Climbing takes 3.5 s instead of 1.5 s |
| **Scarecrow** | 800 · Lv 2 | Early warning: "Someone is near your crops" when a non-Trusted player comes within 25 studs of the field |
| **Floodlights** | 2,500 · Lv 5 | At night, anyone in your field gets a red outline and a name tag on your screen |
| **Guard Dog** | 6,000 · Lv 6 | Lives in a kennel by the field. When a theft starts within 30 studs it barks and runs at the thief, who is **slowed 40% for 3 s** (once per 20 s) |
| **Glass Cloche** | 400 each · Lv 7 | Covers one tile: stealing from it takes twice as long |
| **Security Camera** | 4,000 · Lv 8 | The alarm shows a live picture-in-picture of the thief, even when you're away. Adds the Farm Log's visitor list |
| **Mud Patch** | 1,200 · Lv 9 | A 12 × 12-stud patch (up to 4) that slows walkers 30% |
| **Watchman** | worker · Lv 8 | See §4.9 |

- **The raid race (a worked example, from the real layout: `lune run tools/raidrace`).** A thief takes a Rare Pumpkin from the back row (24 studs from the back fence). The owner needs to get within bat reach (7 studs):
  - **No defences:** hold 2.5 s + run 1.8 s + climb 1.5 s = safe after **5.8 s**.
  - **With a cloche, the dog and the tall fence:** hold 5 s + run 2.9 s (slowed) + climb 3.5 s = **11.4 s**, and someone climbing out still counts as inside.
  - **The owner at the warehouse** (1 s to notice + 180 studs of sprint from the middle of the warehouse site) is in reach at **8.2 s**.
  - **The owner in town** (1 s + Home 3 s + 153 studs from the farmhouse door) is in reach at **10.4 s**.
  
  So with no defences, a quick back-row thief beats anyone who isn't already near the field. With them, the owner catches the thief even from town, with about a second to spare. Defences and the scarecrow's early warning buy the seconds; they don't block. This is what the numbers are tuned around, and `tests/layout.test.luau` fails if a change breaks it.
- **Travel buttons** (all a 3 s channel, cancelled if you move; done by the server through `MovementService.Teleport`):
  - **Home** → your farmhouse door. 60 s cooldown. Also on the theft alarm.
  - **Town** → the town square. 30 s cooldown. Also on the "auction starting" toast.
  - **Visit** → the sidewalk outside any farm's gate (from the player list). 30 s cooldown.
  - All of them are off while you're a Suspect, knocked out or carrying a sack.

### 4.12 Bat, knockout and arrest
**The bat**
- It appears in hotbar slot 1 **the moment you step inside your own farm** and disappears when you step out (the server adds and removes the Tool, checked 4× a second from your trusted position). The server ignores a hit from a bat it didn't give you.
- **Swing:** tap or click (the context button says **Swing** when someone is within 10 studs). 0.8 s cooldown, on the server.
- **A hit counts only if** (`shared/CrimeRules.validHit`): the attacker owns the plot and is inside it · the target is inside the same plot · within 7 studs (+1 for lag) using trusted positions · inside a 100° arc in front of the attacker · a clear line between them · the target isn't Trusted and isn't immune.

**Knockout (anyone).** A bat hit on **any** non-owner inside your farm knocks them out for **5 seconds**, but only Suspects can be arrested (below). Dizzy stars, the character flops over, "BONK!". The server anchors them and takes network ownership of their character, so exploits can't move them. If they were carrying a sack, **the loot goes straight back to the owner's barn** ("Recovered: 2 Pumpkins"). Each sack item remembers which farm it came from: it goes back to that farm's owner, or, if that owner has left the server, to the owner who stopped the thief. A knockout also cancels any trade or steal hold in progress.
- After waking: **6 s of knockout immunity** (a hit only nudges them), so nobody can be stun-locked.
- A knocked-out visitor who isn't a Suspect sees **"You're just stunned. You did nothing wrong."** and a **Leave farm** button that puts them on the sidewalk outside when they wake. Knocking out innocent visitors pays the owner nothing.

**Suspect.** You become a Suspect *of that farm* when you:
- start a steal hold,
- carry a Loot Sack inside it (even loot from another farm: being caught with stolen goods counts),
- climb *in* over its back fence or locked gate. Climbing *out* never makes anyone a Suspect.

It lasts while you're inside that farm and for 60 s after your last suspicious act (so popping out and back in doesn't clear it). Suspects show a red **!** to the owner.

**Arrest (Suspects only).** While a Suspect is knocked out, the owner sees **[E] Arrest** (hold 1 s, within 8 studs). Then:
1. The thief sees the **BUSTED!** mugshot card (2.5 s: their avatar in front of a height chart holding a number board, the charge, the fine and who it's paid to).
2. The thief is teleported to the **Police Station porch**.
3. The owner gets the compensation, a siren-and-cash sound, and +1 on the Sheriff board.
4. If the owner doesn't arrest within the 5 s, the thief wakes up (sack already returned) with their 6 s of immunity.

**The fine (compensation)** (`shared/FineRules.luau`)
- `fine = max(floor, 8% × the thief's earnings in the last 60 min) × repeatMultiplier`
- `floor = max(25, 1.5 × the market value of the loot)` (the sack, plus the crop they were holding if they were mid-steal).
- Why 1.5×: with the loot returned and a 1.5× floor, a raid on a defended farm roughly breaks even at a ~40% arrest rate (`0.6 × loot − 0.4 × 1.5 × loot = 0`). Raiding an unwatched farm pays; raiding a guarded one doesn't. For rich thieves the 8% term is bigger, so they lose a lot for stealing carrots from small farms.
- `repeatMultiplier` = 1 for the first arrest in 30 min, 1.5 for the second, 2 for the third and after.
- **Earnings** means sales income (truck and shop), kept as 12 five-minute buckets in the save. Trades and refunds don't count here (for collecting debt, auction refunds do; see Debt).
- **Paid from the thief's wallet. Whatever's missing becomes debt** (below). **The owner gets exactly what's collected**, so no coins are created from nothing.

**Debt.** Unpaid fines are owed to that owner. **50% of the thief's future sales income** goes to their debts (oldest first) until they're paid. The thief can also pay early at the police desk. Payments reach the owner straight away if they're in the same server; otherwise they go into the owner's **payout queue** (DataStore `Payouts_v1`, key `Owner_<userId>`; each record has an id so it's only ever claimed once), delivered when they next join or via MessagingService to their server. Payments are batched per debtor and owner (at most one payout record every 5 minutes), which keeps DataStore writes low. Debt older than 7 days is forgiven. Players in debt can't put coins into trades. Auction refunds count as income, so coins parked in a bid still pay the debt.

**Stopping people dodging an arrest** (`CrimeService`, tests in `tests/crime.test.luau`):

| Bypass attempt | Counter |
|---|---|
| **Leaving the game while knocked out** (quit, crash, Alt+F4, joining a friend) as a Suspect | `PlayerRemoving` → **automatic arrest**: the fine ×1.5 ("Fled arrest"), the loot back to the owner, applied *before* the profile session ends. Next join within 2 min starts on the police porch with a "You fled arrest" note |
| **Leaving while being chased** (a Suspect with a sack, the owner within 30 studs or swung at them in the last 10 s) | Treated the same: the fine ×1.5, the loot back. Leaving *without* a chase just returns the loot, no fine (it could be a real disconnect) |
| Leaving while carrying loot (no chase) | The sack goes back to the owner. Loot never saves to the thief until it's deposited |
| Leaving while knocked out but **not** a Suspect | Nothing happens (they did nothing wrong) |
| **Resetting the character** | The reset button is off while you're a Suspect, knocked out or carrying a sack (`ResetButtonCallback = false`). If the character dies or is removed while knocked out → automatic arrest |
| Teleporting away (Home, Town, Visit) | All game teleports are off while knocked out, a Suspect or carrying a sack |
| Exploit-moving while knocked out | The server anchors them and owns the character's network |
| Speed or teleport exploits to steal or escape | Trusted positions (`MovementService`, the Tide Market pattern). Every distance and zone check uses them |
| Faking "steal finished" or "deposit" | The server times every hold (start → finish ≥ the hold time, still in range, the crop still ripe, the sack has room) and checks the barn distance |
| Faking bat hits or arrests | `validHit` above. Arrests need the target knocked out, a Suspect, and within 8 studs |
| Spending everything before a raid | The fine comes from earnings, not the wallet. Unpaid fines become debt |
| Giving coins away to dodge debt | No coins in trades while in debt; debt is collected from income |
| An alt account getting arrested on purpose to farm fines | The owner only receives what's collected, so an empty alt pays nothing |
| Luring people in to arrest them | Only Suspects can be arrested. Innocent visitors can be knocked out but pay nothing |
| Friends staging arrests to farm the Sheriff board or arrest XP | Only arrests with loot worth ≥ 50 coins count, and at most 3 per thief–owner pair per day |
| Juggling a thief's coins through the auction (bid, get outbid) to dodge a fine | Refunds count as income for debt (above) |
| Stun-locking a visitor | 6 s immunity after each knockout and a Leave farm button |
| Standing on the plot edge | Zone check with 1 stud of hysteresis. Someone climbing *in* counts as inside from the start of the climb; someone climbing *out* counts as inside until they're over |
| Server shutdown (an update or a crash) | No penalties during `BindToClose`; loot goes back to owners |

### 4.13 Trading
- **In person:** within 20 studs (`TradeRules.NEAR_DISTANCE`), and walking more than 40 apart cancels it. The **Trade** button lists nearby players; or press **T** next to someone.
- **A structured UI** (no chat needed): each side offers up to **8 stacks** (crops, seeds, auction items) and coins. Both press **Ready** → a **5 s countdown** (any change resets it) → both **Confirm** → an **atomic swap** (all or nothing), saved straight away.
- **Safety:** unlocks after **1 h of play**. Both sides see the market value of every stack and each side's total, with a red warning when you'd give 3× or more what you get. Every trade is logged (`TradeLog_v1`) and staff can roll one back (`/trades`, `/rollback`, the Tide Market pattern).
- **Not tradeable:** anything bought with Robux, workers, Land Permits, placed defences, loot still in a sack, coins while in debt, and store items bought with coins (selling back pays half; trading them would undercut that). Decor won at the auction can be traded once it's put away.
- ProfileStore session locking, so server hopping can't duplicate items.

### 4.14 Weather, day and night, events
Shared by the whole server (`Config/Weather.luau`). A 24-minute day (16 min day, 8 min night).

| Weather | Share · length | Growth | Mutation on ripe crops left in the field (chance per 30 s roll) | Look |
|---|---|---|---|---|
| Clear | 55% | ×1 | any weather: **Golden** ×2 (0.5%), **Rainbow** ×8 (0.05%) | sunny |
| Rain | 20% · 4 min | ×1.5 | **Wet** ×1.3 (3%) | rain, puddles, rainbow afterwards |
| Thunderstorm | 8% · 3 min | ×1.5 | **Shocked** ×3 (1.5%) | lightning, sparks on the crops |
| Frost Night | 7% · 4 min (night only) | ×0.75 | **Frosted** ×2.5 (2%) | frost on the ground, breath puffs |
| Golden Hour | 7% · 3 min (dusk) | ×1 | **Golden** ×2 (5%, ten times the usual) | low orange sun, gold dust |
| **Harvest Moon** | scheduled 3× a day · 6 min | ×2 | **Moonlit** ×5 (2%) | a huge orange moon; **Heist Night**: steal holds −25% |

- **How mutations work:** every 30 s, each ripe crop still in the field rolls the current weather's mutation and the any-weather ones. A crop gets one mutation at most. Roughly: a crop left out through a whole Rain has a 1 in 5 chance of Wet; through a Harvest Moon, about 1 in 5 of Moonlit. Mutated crops get a coloured aura, **which thieves can see too**. That's the core gamble: leave it out for a mutation, or harvest it safe.
- **Night:** players' name tags only show within 20 studs (sneakier raids). Floodlights cancel that on your farm.
- **Harvest Moon** at 01:00, 12:00 and 19:00 UTC with a 5-minute warning. The sky turns to night for it, whatever the time of day. Big growth, the best mutation, and the most raids. Appointment play.

### 4.15 Progression
- **Farm Level 1–50** from XP (`Config/Progression`, `shared/ProgressionRules`). Total XP for level L = 60 × (L − 1)^2.65, so Lv 2 is 60 XP and Lv 32 about 537,000. XP comes only from playing; **nothing earns XP while you're offline**:
  - **Harvesting:** XP per minute the crop grew (3 a minute for Commons up to 5.5 for Mythics), so slow crops aren't worse for XP than Carrots. A Farmhand's pick while you're online gives half.
  - **Selling** (truck or shop, while online): 1 XP per 50 coins.
  - **Arrests:** +50 (only arrests that count for the Sheriff board). **Cropdex:** +25 per new entry.
  - The progression sim (`lune run tools/progression`) plays the game with the real rules. A daily player (1.5 h a day) reaches Lv 12 on day 3 and Lv 32 (the full 8×8) on day 23; a casual player (45 min) has 11 of 12 permits by day 35; a keen one (3 h) finishes the land on day 12. It unlocks seed tiers in Barley's shop (Uncommon Lv 2 · Rare Lv 5 · Epic Lv 10 · Legendary Lv 16 · planting Mythics Lv 20), **Land Permits** (12, from Lv 2 to Lv 32, §4.1b), buildings, defences and worker types.
- **Upgrades:** clearing land, the Silo, Warehouse Levels and Store Levels (1–20 each), store decor, truck paint, defences, worker training (Levels 1–10).
- **Cropdex:** every crop × every mutation, with Giant records (the biggest of each). Rewards for each rarity tier (coins, a free seed), a badge per mutation set.
- **Leaderboards** (OrderedDataStores, weekly and all-time; boards at the police station and the Exchange):
  - **Net Worth**: coins + the value of inventory and buildings
  - **Sheriff**: arrests made this week (only arrests with loot worth ≥ 50, at most 3 per thief–owner pair per day; the same rule applies to arrest XP)
  - **Most Wanted**: crop value stolen this week (a cartoon wanted poster of #1)
  - **Top Store**: the best Store Rating with at least 200 shoppers this week
- **Server announcements:** a Mythic ripening ("✨ A Crystal Rose just ripened on Alex's farm!": the owner gets a private 60 s warning first), a Mythic harvested, a Giant crop, an arrest of the server's Most Wanted.

### 4.16 Quests, streaks and the Farm Log
- **3 daily quests** from a pool (harvest N, ship N crates, earn N in your shop, make an arrest, get a mutation, win an auction lot, deposit stolen crops), 200–1,000 coins each, plus a bonus for all three.
- **7-day login streak** with seeds, coins and a decoration on day 7.
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
- **Toasts:** paper notes pinned with a coloured tack, slightly crooked, in handwriting, at the top right. Announcements are on yellow paper.

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
- **Top centre** (the "purse"): a wooden sign hung on ropes from the top of the screen with your coins, the Farm Level rosette and the XP rail. Under it the **location chip**, a price tag:
  - 🟢 **Your Farm** (green)
  - 🟡 **Visiting Sam's farm** (gold)
  - 🏪 **Sam's Corner Store** (green when it's yours, gold when it isn't)
  - 🔴 **TRESPASSING** (red, pulsing, once you're a Suspect)
  - ⚪ **Town**
  It's at the top centre, not top left, because Roblox's chat window lives top left on computers (found in week 1). The top right is Roblox's player list.
- **Beside it:** the clock, the weather and the next event's countdown (weather week). **Under the purse:** the market ticker, a chalk strip (week 2).
- **Top right:** the alert stack (theft alarms, auction starting, truck paid, Hot Crop).
- **Left side bar:** Barn · Warehouse · Store · Workers · Market · More (Cropdex, Trade, Trusted, Farm Log, Robux shop, Settings). Badges show counts (crates waiting, crops ripe, a worker ready to train, an upgrade you can afford). On phones the crates are smaller (58×52) and sit in **2 columns of 3**, above the thumbstick (play-test 2026-10-31). (Built so far: Barn · Store · Market.)
- **Bottom:** the hotbar of **seed packets** (the picked one stands up). The bat 🏏 joins it as slot 1, only inside your farm. There's no watering-can slot: the context stamp waters. The **Home** and **Town** signposts sit above it.
- **Bottom right:** the **context stamp**, with a chalkboard above saying what's on the tile and how long it has left. It changes to whatever you can do right now: Plant · Water · Harvest · Steal (red, hold) · Swing · Arrest (red, hold) · Deposit · Pack. One press does one action. Hold it and walk to repeat that same action on every tile you cross (plant a row, harvest a row), never a different one.

### 5.3 Windows

| Window | Theme | Main parts |
|---|---|---|
| **Packing Shed bench** | crate labels, then the wash | Each barn stack with 🚚 Truck and 🏪 Store buttons showing what each pays now ("Store Lv 8" or "Full" when it can't go there). Then a crate, a water meter with the green band, and a big **HOLD TO WASH** stamp; grade A wins a gold rosette |
| **Seed Rack** (Barley) | wooden rack of seed packets | Tabs by rarity. Each packet: picture, grow time, sell value, stock "×3", price tag, Buy ×1/×5. A restock countdown on a chalkboard. Locked packets say "Lv 10" |
| **Barn** | barn doors open | Crops · Seeds · Items · Workers · Land tabs; a capacity bar; Send to warehouse; Hold (for planting). The Land tab shows the 4×4 block map, permits waiting, and each clearable block marked Safer or Riskier |
| **Warehouse** | a clipboard | **Pipeline:** Intake → Sort → Pack → Route → Load → Truck as a row of station cards (queue, worker slots, speed). The bottleneck is orange. Truck cards with a fill bar, the price it would lock and **Send**. **Routes** (crop → Truck / Store / split). **Upgrade**: the level ladder on blueprint paper, the next level's card and **Upgrade**. On phones the pipeline wraps into 2 rows of 3 |
| **Store** | a shop counter with price tags | A header: your store's name (Rename), rating with Charm and why ("3 shoppers gave up in the queue: open another checkout"), a big **Decorate** stamp. **Prices:** each crop's reference, the truck price now, **your price** (− +), the demand face, % that buy, ~sales/min, and which rarities your displays can't hold yet. **Stock:** **Fill all**, the stockroom, each display's slots (fill, Auto or a crop). **Upgrade:** the next level on blueprint paper and the ladder |
| **Decorate** | blueprint paper over your store | Your store from above, roof off, walls faded, the chalk grid with DOOR and STAFF marked; the drawer of item cards (Displays · Checkouts · Decor · Wall · My items) with a 3D picture, size, what each does and its price ("Yours ×2", 🔒 Store Lv 5); green/red placing with the reason; Move · Turn · Put away · Sell; **DONE** with the total under it, ✕ to leave it as it was |
| **Workers / Hiring Hall** | ID badges on a corkboard | Station slots ("Packer 2/3", greyed ones saying which level opens them). Candidate badges: photo, name, type, level and efficiency, trait, wage, hire fee, **Hire**. Your workers: level and efficiency ("Lv 4 · 60%"), the XP bar, **Train** when it's full, fire, the Driver's rule |
| **Market** (Exchange) | a chalkboard | Each crop: price, ▲/▼, a 3 h sparkline, events (Hot Crop, Glut, festivals) with timers. Main button: **Dispatch truck now** (if one is loaded) at the prices shown |
| **Auction** | red velvet with a gold frame | The lot's 3D picture, its estimated value, the current bid and leader, a timer ring (it flashes on anti-snipe), **+5% / +10% / +25%** bid buttons, your escrow, the next lots |
| **Trade** | two crates side by side | Your offer and theirs (8 slots + coins), the value of each side, a red warning bar, Ready → countdown → Confirm |
| **Defences** | a blueprint | Owned items, placing mode with glowing spots, Trusted list |
| **Police desk** | a case file | Your debts (to whom, how much, payment progress), Pay now, your rap sheet |

### 5.4 Theft alarm (owner)
- A **red pulse round the screen edges** (scaled by the Flashing setting), a siren chirp, and a top-right alarm card: **"🚨 Sam is stealing your Pumpkin!"** with:
  - an arrow at the screen edge pointing at the thief
  - the security-camera picture-in-picture (if you own one)
  - **[🏠 Home 3s]**, or **[Go get them!]** if you're already on the farm
- The crop being stolen flashes on your screen, and its progress ring shows how long you have.
- A softer amber card for early warnings ("Someone is near your crops", from the scarecrow).

### 5.5 Thief screens
- **Steal hold:** a ring over the crop and a **sack meter** (🧺 3/5) next to the context button.
- **Carrying:** the "TRESPASSING" chip, the name tag turns red, and a compass arrow points to your own barn ("Get home!").
- **Knocked out:** a dizzy wobble, the screen goes grey and blurry with stars, and a 5 s countdown ring. A Suspect sees **"The farmer can arrest you!"**. Anyone else sees **"You're just stunned"** and the **Leave farm** button.
- **BUSTED!** a mugshot card (avatar headshot, height chart, the charge "Crop theft: 1 Pumpkin", the fine, "paid to Alex", any debt), then a fade to the police porch.
- **Got away:** "Safe! Empty your sack at your barn" when you leave the plot. On deposit: "+2 Pumpkins (stolen)" and coins burst into a 🧺.

### 5.6 Small things that matter
- Every number change floats up (+18 🪙, +1 🥕).
- A ripe crop's bounce is in time with the music beat. Satisfying harvest pops.
- **Settings:** music, SFX, Flashing effects (0–100%), Reduced motion, text size (80–125%), Trade requests on/off, Quiet mode, Drop Sprout Shield early.
- Prompts use the Tide Market small wooden chip style ("[E] Steal").

## 6. Economy

### 6.1 Crops (`Config/Crops.luau`, base market values)

| Crop | Rarity | Seed | Grow | Base value | Regrows | ~Profit per tile-minute |
|---|---|---|---|---|---|---|
| Carrot | Common | 10 | 1 min | 18 | – | 8 |
| Wheat | Common | 15 | 1.5 min | 27 | – | 8 |
| Potato | Common | 25 | 2 min | 42 | – | 8.5 |
| Lettuce | Common | 30 | 2.5 min | 52 | – | 8.8 |
| Corn | Uncommon | 90 | 5 min | 145 | – | 11 |
| Onion | Uncommon | 110 | 6 min | 175 | – | 10.8 |
| Strawberry | Uncommon | 120 | 4 min | 70 | ×3, every 3 min | 12.3 |
| Tomato | Uncommon | 150 | 5 min | 90 | ×3, every 4 min | 12.4 |
| Bell Pepper | Rare | 350 | 12 min | 520 | – | 14.2 |
| Pumpkin | Rare | 400 | 15 min | 610 | – | 14 |
| Watermelon | Rare | 550 | 20 min | 830 | – | 14 |
| Blueberry Bush | Rare | 700 | 12 min | 260 | ×4, every 8 min | 13.6 |
| Pineapple | Epic | 2,000 | 45 min | 2,900 | – | 20 |
| Cocoa Pod | Epic | 2,400 | 50 min | 3,400 | – | 20 |
| Dragonfruit | Epic | 3,000 | 60 min | 4,200 | – | 20 |
| Grape Vine | Epic | 4,000 | 45 min | 1,500 | ×4, every 30 min | 21 |
| Moonmelon | Legendary | 12,000 | 2 h | 15,600 | – | 30 |
| Starfruit | Legendary | 15,000 | 2.5 h | 19,500 | – | 30 |
| Golden Apple Tree | Legendary | 25,000 | 2 h | 7,000 | ×5, every 90 min | 29.8 |
| Crystal Rose | Mythic | auction (~40k) | 6 h | 60,000 | – | ~55 |
| Phoenix Pepper | Mythic | auction (~42k) | 6 h | 64,000 | – | ~60 |
| Dragon's Eye Pumpkin | Mythic | auction (~48k) | 6 h | 70,000 | – | ~60 |

Before the market wave (0.8–1.2), events, grade A (×1.15), mutations (×1.3–×8), Giant (×3) and shop markups. Mythic profit is shown at the usual winning bid; bidding wars pull it down towards ~45. Rarer crops pay more per minute but take longer, need you around, and are what thieves want, so the risk grows with the reward.

### 6.2 Sources and sinks

| Sources | Sinks |
|---|---|
| Truck sales (global price) | Seeds |
| Shop sales (your price) | Worker hire fees, wages and training |
| Fines received (moved from thieves, never created) | Land clearing fees (once a permit is earned), the Silo, **Warehouse and Store Levels** (about 4 million each for the whole ladder) |
| | **Store decor and displays** (open-ended; selling back pays half) |
| Quests, streak, Cropdex rewards | Defences |
| | Auction wins (the coins are spent) |
| | Auction Board 5% fee (v1.1) |

**Rules**
- Robux never buys stealing power or defence power (§7).
- Fines only move coins between players. Debts expire after 7 days rather than creating coins.
- Watch weekly: total coins, median Net Worth, Mythics in circulation, average fine, raids per hour per server, % of raids ending in an arrest (aim for 35–50%).
- **Late-game sinks, mostly solved by levels.** Before the store and level ladders, a daily player had bought all the land and buildings by day 23 and piled up about 4 million coins by day 35 (earning 500,000–700,000 a day). With Warehouse and Store Levels and worker training, `tools/progression` (the real tables since week 4; it checks these targets): a daily player sinks about 3.8 million by day 35 and holds about 0.6 million; reaches Warehouse and Store Level 5 on day 2, Level 10 on day 9 and Level 15 on days 22 (warehouse) and 27 (store); workers average Level 6 by day 14 and 7 by day 28 (the first hires 8); wages peak at 8–9% of income; the land targets still pass (the full 8×8 on day 24). A casual player reaches Warehouse Level 10 on day 15 and ends day 35 at Farm Level 28 with Warehouse 13 and Store 14. Not in the run: store sales (they'd speed it up) and decor (it slows it down). Level 20 of both ladders is a second-month goal. What's still open is the very long tail after that (§11 step 6).

## 7. Monetization
Rule: **no paid power in the PvP**. Robux buys comfort, shared moments, space and looks.

| Item | Type | Robux | What it does |
|---|---|---|---|
| VIP | Pass | 199 | +10% sale income, a gold name tag, a VIP truck paint and shop awning |
| Bigger Barn | Pass | 99 | Barn capacity ×2.5 |
| Rain Dance / Thunderstorm / Golden Hour / Harvest Moon | Product | 49 / 79 / 99 / 149 | That weather **for the whole server** for 5 min (Tide Market totem rules: one at a time, never over a better weather, never into the scheduled Harvest Moon). A Harvest Moon bought is a Heist Night for everyone |
| Growth Boost | Product | 79 | Your field grows ×2 for 30 min (online only) |
| Cosmetics | Products | 25–249 | Bat skins (Golden Bat, Baguette, Carrot Club: **same stats**), truck paint jobs, store decor sets and awnings (**looks only**: a Robux item's Charm is the same as the cheapest coin item of its size, and it can't be sold back for coins), farmhouse styles, scarecrow skins, sack skins, funny mugshot frames |

- **Never sold:** Land Permits (land opens by level only), defences, steal speed, sack size, bat reach, knockout length or immunity, more worker slots than a station's cap, Warehouse or Store Levels, worker XP or training.
- Nothing bought with Robux can be traded (so regional pricing can't be resold).
- Receipts de-duplicated by PurchaseId and saved before granting (the Tide Market pattern).

## 8. Technical architecture

```
src/shared/   Config/  Crops · Rarities · Growth · Land · Warehouse · Shop · Store · Workers · Auction
                       Market · Crime · Progression · Settings   (to come: Weather · Mutations · Defences · Monetization)
              Rules:   GrowthRules · SeedStock · MarketPrice · DemandModel · LandRules · ProgressionRules
                       CrimeRules · FineRules · TravelRules · ZoneRules · AuctionRules · WorkerRules
                       PipelineRules · MoveRules · BarnRules · PlotRules · CrateRules · TruckRules
                       ShopRules · StoreLayout   (to come: TradeRules)
src/server/   Services/ Data · Plot · Field · SeedShop · Auction · Market · Warehouse · Truck
                        Store (shoppers too) · Worker · Crime (steal, sack, bat, knockout, arrest)
                        Police · Payout · Movement · Trade · Weather · Quest · Leaderboard
                        Analytics · DevCommand
              World/    WorldBuilder · Parts · FarmArt (the field) · YardArt (shed, dock, pickup)
                        StoreArt (the store's buildings) · StoreItems (the catalog's models)
                        LightingSetup   (PlotLayout lives in shared/)
src/client/   UI (Kraft & Crate theme, HUD in code) · Controllers/ Field · Warehouse · Store
              Decorate · Shopper · Workers · Market · Auction · Crime (alarm, KO, mugshot) · Trade · Weather
```

- **Server-authoritative.** The client sends intents (plant, harvest, steal start/finish, swing, arrest, bid, set price, dispatch). The server checks and owns all state.
- **Workers and shoppers are simulated as data on the server** (state + timestamps per worker: "carrying crate to Load, arrives at t"). Clients draw the NPCs walking set routes from replicated attributes, so 8 farms × 15 NPCs stays cheap. No pathfinding at runtime: each plot has a fixed waypoint graph.
- **Saved data (v1, ProfileStore, session-locked):**

```lua
{
  coins, xp, level, playSeconds,
  field = { [tile] = { seedId, progress, lastUpdate, harvestsLeft, mutation?, giant? } },
  land = { cleared = { blockNumbers }, clearing? }, silo, -- permits are worked out from the level, never stored
  inventory = { crops = { [stackKey] = count }, seeds = { [seedId] = n }, items = {...} },
  warehouse = { level, buildingUntil?, bed = { crate }, dock = { crate }, coldRoom = { crate },
                routes = { [cropId] = share }, trucks = { TruckRun } },
  store = { level, build? = { to, left }, name?, started, nextId,
            layout = { ["id"] = { item, x, y, rot, slots? = { { set?, crop?, units, a } } }
                                | { item, side, at } },   -- wall items
            owned = { [itemId] = count }, gifts = { [itemId] = count },
            stockroom = { crate }, prices = { [cropId] = coins }, rating = { scores = { 1–5 } } },
  workers = { [uid] = { type, level, xp, trait, station, hiredAt } },
  defences = { placed = {...}, owned = {...} }, trusted = { userIds },
  crime = { earnBuckets = {12}, arrests = {timestamps}, debts = { {ownerId, amount, createdAt} },
            lastArrestAt, fled? },
  payoutsClaimed = { [payoutId] = true }, seedStock = { restockId, bought = {...} },
  cropdex = {...}, quests = {...}, streak = {...}, stats = {...}, settings = {...},
  receipts = {...}, lastOnline,
}
```

- **Saving:** autosave every 5 min, on leave and on shutdown. Crime penalties are applied in `PlayerRemoving` *before* `profile:EndSession()`.
- **Anti-cheat** (the client is never trusted):
  - **Movement:** `MovementService` + `MoveRules` (from Tide Market): a speed allowance per tick, rejections send you back, and every distance or zone check uses the trusted position. The game's own teleports go through `MovementService.Teleport`.
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
| 5 | Stealing, the sack, deposit, bat, knockout, Suspect, arrest, Police Station, fines and debt, every bypass counter + tests. **Look:** Suspect markers, the sack, the back fence's slats and climb, the Police Station's front | Raids feel fun on both sides; nobody can dodge an arrest |
| 6 | Defences, theft alarm, Home, Sprout Shield, arrival grace, raid caps, Trusted list (and the staff door for Trusted friends), MovementService. **Look:** the defences | A defended farm catches most raids; an undefended one still survives |
| 7 | Auction House, weather and mutations, Harvest Moon, Cropdex, quests. **Look:** the town (plaza, clocktower, building fronts), weather, day and night | Auction rooms fill up on the bell |
| 8 | Trading with logs and rollback, the MemoryStore supply factor, leaderboards (Top Store), the Farm Guide. **Look:** the valley (Terrain hills, woods, back-trail cover, the tunnel mouth) | 50-player test with no duplication or lost items |
| 9 | Kraft & Crate UI polish, mobile layout, analytics, monetization, thumbnails and the Roblox page art | Launch with a small sponsored-ad budget |

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
| ✓ | Auction pacing | 3 lots every 8 min ≈ 22 lots/h per server, ~1.8 Mythic seeds/h |

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
| The farmhouse | No | No interior: you deposit at the door |
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
4. ✅ **Greybox Cloverdale and time the raid race.** The layout, the greybox and the race from real distances are done and tested (5.8 s without defences, 11.4 s with them; the tall fence went to 3.5 s). Walked in Studio on 2026-10-30 (play-test Stage A, §10): the distances hold. Still open from Stage A: A7 (finding your way) needs a new tester.
5. **MVP weeks 1–4 (§9)**, play-tested as they land (PlaytestPlan Stages A–D). ✅ Week 1 (the farming loop, with its dev commands and the first look pass: light, fences, the field and crops). ✅ Week 2 (selling: the Packing Shed, the pickup, the market, the Farm Stand), played in Studio on 2026-10-31. ✅ Week 3 (your store: the building and its 4 stages, Store Levels, Decorate, shoppers in the aisles), played in Studio on 2026-10-31; then the stores and the valley were made bigger (§10), so a Supermarket is 80 × 56 studs and each farm is 220 wide. ✅ Week 4 (Warehouse Levels 1–20, workers with Levels 1–10, the Hiring Hall, the Welcome back card, the sim with the real tables), played in Studio on 2026-11-01 (§10). Next: Stage B with testers, then Stage C (PlaytestPlan), and week 5 (raids). The look pass ([ArtDirection.md](ArtDirection.md) §11) carries on alongside. The raid stage measures the arrest rate (target 35–50%) and whether raids feel fun from both sides before defences are built in week 6.
6. **Late-game coin sinks** (found by the sim). Mostly answered by Warehouse and Store Levels, store decor and worker Levels 1–10 (§6.2): coins now level off through the first month. Still open: the very long tail once both ladders are done (around day 50 for a daily player). Ideas: bigger auction lots and a weekly "Grand Auction", a coin-bought prestige ("Harvest Festival") that resets land for a permanent bonus, seasonal decor sets, costly seasonal seeds. Decide with live data after launch.
7. **Content and policy checks before launch.** Run the maturity questionnaire with the bonk and arrest content (aim for *Mild*), name the crops and NPCs, and plan the low-poly crop mesh pipeline (like Tide Market's `tools/plant_art`).
