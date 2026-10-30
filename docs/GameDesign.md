# Farm Heist: Game Design Doc

_Status: concept · Last updated 2026-10-30_

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
| **Business loop** | 5–15 min | Warehouse: sort → pack → route → truck or shop → coins → workers and upgrades |
| **Session** | 15–40 min | An auction or two, a weather event, a few raids each way, one upgrade bought |
| **Daily** | 1–2 visits | Welcome-back summary (offline growth, sales, wages) → daily quests → Harvest Moon event |
| **Long-term** | weeks | Clear land to 8×8 (by Farm Level) · warehouse T3 · Supermarket · Mythic seeds · Cropdex · Sheriff and Most Wanted boards |

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

**Distances** (all in `shared/PlotLayout`, checked by `tests/layout.test.luau`): the town square is 160 studs across the radius, the ring road runs at 222, plot fronts start at 240 and backs end at 480, the back trail is at 500 and the hills begin at 530. From the town spawn to a farm's gate is 205–265 studs (about 15 s on foot). From the police porch to the back of a farm is 590–790 studs on foot (37–49 s, depending on which farm), because you have to go round the plots. Most thieves will use **Visit** instead: 3 s to the gate, then about 420 studs round the hedge to the back fence (about 30 s in all). So the walk only slows a thief down a little. The real arrest penalty is the fine and the 3-minute wait before they can steal from that farm again (§4.10). (Play-tested in Studio on 2026-10-30: 785 studs and 49.2 s to the back of the farthest farm.)

### Plot layout (160 × 240 studs, front to back)

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

- **Only two ways in:** the front gate (past the farmhouse, where the owner spawns) or over the back fence (slow and loud, but right by the field). Raids get decided by which one a thief picks. The driveway has a truck gate that only trucks pass through, and the shop's back wall closes it off from the yard, so neither is a third way in.
- The farm is one zone (`PlotZone`, a server-side box). "In your own plot" means the server's trusted position of your character is inside that box (with 1 stud of hysteresis at the edge).
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
7. **Stock your Farm Stand** and set a price
8. **Hire a Shed Hand** at the Hiring Hall (Patty: "First one's on the house!")

Steps 6–7 need a second harvest, so the card says "Plant your new seeds" in between. Farm Level 2 (needed to hire) comes at 60 XP, which the Guide reaches on its own. It also gives the first Land Permit (§4.1b), and the "all done" card points at the glowing block to clear. Finishing pays **300 coins** once. A marker and an edge arrow point to each spot, and the HUD button you need pulses.

**Sprout Shield:** your first **45 minutes of play** (`Crime.SHIELD_SECONDS`). Nobody can steal from you and you can't steal. A soft green dome sits over your field with a timer on it. When it ends you get the **Farm Rules** card: "Ripe crops can now be stolen. In your farm you hold a bat. Bonk a thief, then arrest them!" with a 15 s animated demo. You can drop the shield early (Settings) if you want to start raiding.

### 4.1 Plots
- One per player, given out on join: the free plot next to a friend if one is in the server, otherwise the nearest free plot to the highway. Your farm is saved *relative to the plot*, so it rebuilds the same on any plot in any server.
- **You join at your farmhouse door.** The first time, a short fly-over from the town to your farm shows where everything is.
- **Start:** 100 coins, 5 Carrot seeds, a 4×4 field, the free Packing Shed, a free Farm Stand, the farmhouse, a wooden back fence and an unlocked gate.
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
- **Buildings already work this way:** each warehouse and shop tier needs a Farm Level (§4.6, §4.8). With land on the same ladder, all growth is paced by level.
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

### 4.6 Distribution Warehouse
The way to sell in bulk. Crops go through stations, and **each station can be done by hand (a short minigame) or by workers**.

| Step | Station | By hand | What it does |
|---|---|---|---|
| 1 | **Intake** | Pick crops and an amount from the barn | Drops them into the intake bin |
| 2 | **Wash & Sort** | Hold to spray; let go when the meter is in the green | Grades each batch **A** (×1.15 value) or **B** (×1.0). Doing it by hand gives the best chance of an A |
| 3 | **Pack** | Swipe tape across the crate | Crates by rarity: up to 12 Commons · 10 Uncommons · 6 Rares · 4 Epics · 2 Legendaries · 1 Mythic (in a velvet case). A crate can go out part-full |
| 4 | **Route** | Set once in the Warehouse window | Each crop goes **→ Truck** or **→ My Shop** (or a split, e.g. 70/30) |
| 5 | **Load** | Carry the crate to the truck (a hand cart from T1) | Fills the truck bed |
| 6 | **Dispatch** | Pull the dock lever | The truck leaves. **The price locks now**, and you get a receipt |

- **The truck** drives the ring road and the highway into the tunnel. **You're paid when it reaches the City** (half the trip). It comes back empty at the end of the round trip. Each truck run is one `TruckRun` (`{crates, lockedPrices, departAt, arriveAt, returnAt}`) saved in your profile. If you're in the server at `arriveAt` you're paid then; if you've left, it's paid from the saved run the next time you join (any server), shown on the Welcome back card.
- **At T0 there's no Intake or route rules:** the Packing Shed bench pulls crops straight from the barn, and each crate you pack asks **Truck or Stand?** Intake and route rules come with T1.
- Crates routed to the shop go to the **Stockroom** (§4.8).
- **Tiers** (`Config/Warehouse.luau`). Building takes time (construction workers and scaffolding), runs at the same online/offline rates as growth, and the old building keeps working until the new one is done.

| Tier | Name | Cost · level | Stations | Truck(s) | Worker caps (Sorter / Packer / Loader / Driver) |
|---|---|---|---|---|---|
| T0 | Packing Shed | free | one bench (sort + pack together), a ramp | Pickup: 4 crates, 60 s round trip | 1 Shed Hand does all three |
| T1 | Distribution Warehouse | 5,000 · Lv 5 · builds in 2 min | Intake, Wash & Sort, Pack, Load, conveyors between them | Box Truck: 12 crates, 90 s | 1 / 2 / 1 / 1 |
| T2 | Big Warehouse | 40,000 · Lv 12 · 5 min | + Cold Room (holds 40 crates), second dock | 2 × Semi: 30 crates, 120 s | 2 / 3 / 2 / 2 |
| T3 | Distribution Center | 200,000 · Lv 20 · 10 min | belts ×1.5 speed; Premium contracts (Legendary and Mythic crates +10%) | 2 × Reefer: 40 crates, 100 s | 3 / 4 / 2 / 2 |

- **The Warehouse window is a clipboard** showing the pipeline: each station is a box with its queue count, worker slots (filled or empty, "2/3") and a throughput figure. **The slowest station is highlighted orange** with a tip ("Packing is your bottleneck: hire a Packer or upgrade"). Trucks show a fill bar, an ETA, and the Dispatch button with the price it would lock.

### 4.7 Global market price (the Cloverdale Exchange)
Every crop's truck price is the same on every server at any moment:

`price(crop, t) = base × wave(t) × event(t) × supply(t)`, clamped to **0.5–2.0 × base** and rounded to whole coins (`shared/MarketPrice.luau`).

- **wave(t)**: `1 + 0.12·sin(2πt/45min + φ₁) + 0.08·sin(2πt/3h + φ₂)`, with φ from a hash of the crop id. Smooth ups and downs (0.8–1.2) that are the same on every server without any messaging.
- **event(t)**: a deterministic schedule from the hour index. Each hour has one **Hot Crop** (×1.5 from :10 to :25) and one **Glut** (×0.75 from :40 to :55), two different crops and never Mythics, announced 2 minutes ahead. Seasonal festivals too (e.g. a Pumpkin Festival in October: pumpkins ×1.3 all week).
- **supply(t)**: player-driven. Each server adds the units it sold to MemoryStore counters (`Market_<crop>_<window>_<shard 1–8>`, 10-minute windows, written in batches every 30 s). `supply = clamp(1 − 0.12·log₂(1 + sold/expected), 0.7, 1.0)`. If everyone dumps carrots, carrots drop everywhere, so it pays to grow different things. If MemoryStore fails it falls back to 1.0.
- **The Exchange board** in town and the **Market** window show each crop's price, a ▲/▼ trend, a 3-hour sparkline and the current events. A scrolling ticker across the top of the HUD shows the biggest movers.
- **The price locks at dispatch.** The skill is choosing *when* to send the truck (or giving a Driver a rule for it, §4.9).

### 4.8 Own shop
Your storefront on the ring road. NPC shoppers walk in, browse your shelves and pay **the prices you set**.

| Tier | Name | Cost · level | Shelves | Checkout | Worker caps (Stocker / Cashier) |
|---|---|---|---|---|---|
| T0 | Farm Stand | free | 2 shelves × 20 units | honour box (shoppers pay themselves) | – / – |
| T1 | Farm Shop | 2,500 · Lv 3 | 6 | 1 register | 1 / 1 |
| T2 | Market Hall | 25,000 · Lv 10 | 12 | 2 registers | 2 / 2 |
| T3 | Supermarket | 150,000 · Lv 18 | 20 | 2 registers + self-checkout, a billboard on the ring road (+30% shoppers) | 3 / 2 |

- **Stock** arrives as crates in the Stockroom (routed from the warehouse). Stockers (or you, tapping a shelf) unpack them onto shelves. A shelf holds one crop.
- **Setting prices:** for each crop you set the price of one standard (grade B, no mutation) unit. Grade A and mutated units scale automatically (shown on the price tag). The allowed range is 50–300% of the reference price.
- **The shopper's decision** (`shared/DemandModel.luau`):
  - `ref = 0.5 × base + 0.5 × marketPrice(now)`: shoppers half-remember the usual price, so **when the market crashes, your shop is the better place to sell**, and when it spikes the truck is.
  - Each shopper rolls a willingness `w` (log-normal, σ = 0.2) × the rating bonus (+0% at 1★ up to +25% at 5★) × 1.15 for grade A. They buy if `yourPrice ≤ ref × w`, picking 1–4 units of 1–2 crops.
  - In practice: at the reference price ~50% of shoppers buy at 1★ and ~85% at 5★; at 1.2× the reference, ~18% at 1★ and ~58% at 5★. The window shows this as a **demand face** (😀 / 🙂 / 😐 / 😟) and "~N sales/min".
- **Shopper flow:** at 3★, one every 20 s (Farm Stand), 12 s, 8 s, then 5.2 s (Supermarket). Each star above 3 brings them 15% more often (each star below, 15% less), so a 5★ Supermarket gets one every 4 s. Buyers queue at a register. Nobody served within 20 s (patience) means they leave grumpy.
- **Shop Rating** (1–5★): a rolling score over the last 50 shoppers. Up when they buy and get served quickly; down when shelves are empty, nothing is affordable, or they wait too long. Shop decorations add up to +0.5★.
- Only NPC shoppers buy from shops. Players swap goods by trading (§4.13).
- The shop is the slow, high-margin outlet. The truck is the fast, bulk one at the market price.

### 4.9 Workers
Hired at the **Hiring Hall** in town or from the Workers window (from Farm Level 2). Each worker is a visible NPC on your farm, walking set routes between stations, carrying crates and waving at visitors.

| Worker | Station | What they do | Cap (by building tier) | Wage / min (Lv 1) |
|---|---|---|---|---|
| **Farmhand** | Field | Harvest ripe crops, replant with the seed you chose (same seed · cheapest · don't replant). Skips tiles flagged 🚩 *Leave in field* (§4.2). Out of seeds → stops and shows "Out of Carrot seeds" on the Barn button | 1 per 16 tiles (max 4) | 6 |
| **Shed Hand** | Packing Shed (T0 only) | Sort + pack + load. Becomes a Packer (same level) when the T1 warehouse is built | 1 | 5 |
| **Sorter** | Wash & Sort | Grade batches (A chance rises with level) | 1 / 2 / 3 | 5 |
| **Packer** | Pack | Pack crates | 2 / 3 / 4 | 5 |
| **Loader** | Load | Move crates to the truck or the Stockroom | 1 / 2 / 2 | 5 |
| **Driver** | Truck | **Auto-dispatch** when the truck is full, or **only when the price is ≥ X% of base** (your rule) | 1 per truck | 8 |
| **Stocker** | Shop shelves | Unpack crates onto the emptiest shelves | 1 / 2 / 3 | 5 |
| **Cashier** | Register | Serve the queue | 1 per register | 6 |
| **Watchman** | Gatehouse (Lv 8) | Rings the bell when a theft starts, shines a spotlight on the thief and shuts the gate **to Suspects** for 30 s (they have to climb out; everyone else still walks through). **Never knocks anyone out** | 1 | 10 |

- **Hiring:** the board shows 3 candidates per type, changing every 10 min. Each has a level (1–3), a trait (**Speedy** +20% speed · **Careful** +grade A chance · **Night Owl** +30% at night · **Frugal** −20% wage) and a hire fee (40× their per-minute wage). Your first hire is free.
- **Levels 1–5:** train them with coins (60 minutes of their current wage per level). Each level multiplies speed by 1.2 and the wage by 1.15.
- **Rare workers** come from auction contracts (e.g. *Grandma Rose, Legendary Packer*: ×2 speed, the Careful trait, a unique look).
- **Wages** come out of your coins every minute (a coin sink: 5–8% of income in the progression sim, at most 8% on any day). If you can't pay, workers **go on strike** (sitting on crates with signs) until you can.
- **Station caps** limit how many workers each station takes. The Workers window shows each station's slots (e.g. Packer 2/3), and greyed slots say what unlocks them ("T2 warehouse").
- **Offline:** workers keep going at **25% speed for up to 8 hours**, paid at 25% wages. `shared/PipelineRules.simulate(state, seconds, rate)` runs the whole chain (Farmhands harvest and replant using offline growth → stations → trucks at the deterministic market price with supply = 1 → shop sales at 25% shopper flow; the Farm Stand's honour box sells on its own, bigger shops need a Cashier). It's worked out in one go when you return and shown on the **Welcome back** card.
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
  - **The owner at the warehouse** (1 s to notice + 160 studs of sprint) is in reach at **7.7 s**.
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
- **Not tradeable:** anything bought with Robux, workers, Land Permits, placed defences, loot still in a sack, and coins while in debt.
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
- **Upgrades:** clearing land, the Silo, warehouse and shop tiers, truck paint, defences, worker training.
- **Cropdex:** every crop × every mutation, with Giant records (the biggest of each). Rewards for each rarity tier (coins, a free seed), a badge per mutation set.
- **Leaderboards** (OrderedDataStores, weekly and all-time; boards at the police station and the Exchange):
  - **Net Worth**: coins + the value of inventory and buildings
  - **Sheriff**: arrests made this week (only arrests with loot worth ≥ 50, at most 3 per thief–owner pair per day; the same rule applies to arrest XP)
  - **Most Wanted**: crop value stolen this week (a cartoon wanted poster of #1)
  - **Top Shop**: the best rating with at least 200 shoppers
- **Server announcements:** a Mythic ripening ("✨ A Crystal Rose just ripened on Alex's farm!": the owner gets a private 60 s warning first), a Mythic harvested, a Giant crop, an arrest of the server's Most Wanted.

### 4.16 Quests, streaks and the Farm Log
- **3 daily quests** from a pool (harvest N, ship N crates, earn N in your shop, make an arrest, get a mutation, win an auction lot, deposit stolen crops), 200–1,000 coins each, plus a bonus for all three.
- **7-day login streak** with seeds, coins and a decoration on day 7.
- **Farm Log** (from the Barn window): visitors, thefts (who, what), arrests, truck receipts, worker strikes, debt payments received.
- **Welcome back card** on join: offline growth ("6 crops ripened"), offline worker earnings, wages paid, payouts received, and anything that happened to a truck run in progress.

## 5. GUI and UI design

### 5.1 Look: "Kraft & Crate"
The UI looks like things you'd find on a farm: kraft paper, crate labels, seed packets, painted wood signs, chalkboards.
- **Panels:** kraft-paper cards with a stitched (dashed) inner border, 14 px corners, a soft drop shadow, over a dimmed backdrop (tap outside to close).
- **Header:** a painted wooden sign hung from two nails, with the title in cream and a brown outline.
- **Tabs:** seed-packet tabs along the top. The chosen one is coloured and raised.
- **Buttons:** chunky, with a darker 4 px bottom edge that squashes when pressed. **Green** = confirm/do it, **gold** = spend coins, **red** = steal/danger/alarm, **blue** = info/go somewhere, **Robux green with the R$ icon**.
- **Item cards:** a crate-label strip with a 3D picture on the left (`ItemPreview`), the name in its rarity colour, small tags (Ripe, Wet, Giant, ×12), a detail line, and buttons on the right.
- **Price tags:** cream tags on a string (the shop and the seed rack).
- **Toasts:** paper notes pinned with a tack, sliding in at the top right.

**Tokens** (`client/UI/Theme.luau`):

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

**Fonts:** `Enum.Font.FredokaOne` for headers, numbers and buttons; `BuilderSans` for body text. At least 14 px on phones.

### 5.2 HUD (landscape phone)

```
┌───────────────────────────────────────────────────────────────────────────────┐
│ 🪙 12,450   Lv 7 ▓▓▓▓░░    ☀ 14:20 · Rain in 2:10 · 🌕 Harvest Moon 3:45   🔔 alerts │
│ [Your Farm 🟢]           ◀ 🥕 Carrot 21 ▲ · 🎃 Pumpkin 640 ▼ · 🍇 Grape 1,620 ▲ ▶   │
│ ┌────┐                                                                      ┌────┐│
│ │Barn│                                                       (toasts stack) │    ││
│ │Ware│                                                                      │    ││
│ │Shop│                                                                      │    ││
│ │Work│                                                                      │    ││
│ │Mkt │                                                                      │    ││
│ │More│                                       ┌───────────┐                       │
│ └────┘   [🏠 Home] [🏘 Town]                 │  HARVEST  │ ← big context button │
│          [ 🏏 | 🚿 | 🌱 Carrot ×12 | 🌱 Corn ×4 | 🧪 ]  │  (hold)   │   (jump stays clear)  │
└───────────────────────────────────────────────────────────────────────────────┘
```
- **Top left:** coins and Farm Level. Below it, the **location chip**:
  - 🟢 **Your Farm** (green)
  - 🟡 **Visiting Sam's farm** (amber)
  - 🔴 **TRESPASSING** (red, pulsing, once you're a Suspect)
  - ⚪ **Town**
- **Top centre:** the clock, the weather and the next event's countdown; under it the **market ticker**.
- **Top right:** the alert stack (theft alarms, auction starting, truck paid, Hot Crop).
- **Left side bar:** Barn · Warehouse · Shop · Workers · Market · More (Cropdex, Trade, Trusted, Farm Log, Store, Settings). Badges show counts (crates waiting, crops ripe).
- **Bottom:** the hotbar. The bat 🏏 is slot 1 only inside your farm, then the watering can, then seed stacks. The **Home** and **Town** travel buttons sit above it.
- **Bottom right:** the **context button**. It changes to whatever you can do right now: Plant · Water · Harvest · Steal (red, hold) · Swing · Arrest (red, hold) · Deposit · Pack.

### 5.3 Windows

| Window | Theme | Main parts |
|---|---|---|
| **Seed Rack** (Barley) | wooden rack of seed packets | Tabs by rarity. Each packet: picture, grow time, sell value, stock "×3", price tag, Buy ×1/×5. A restock countdown on a chalkboard. Locked packets say "Lv 10" |
| **Barn** | barn doors open | Crops · Seeds · Items · Workers · Land tabs; a capacity bar; Send to warehouse; Hold (for planting). The Land tab shows the 4×4 block map, permits waiting, and each clearable block marked Safer or Riskier |
| **Warehouse** | a clipboard | Pipeline: Intake → Sort → Pack → Route → Load → Truck as a row of station cards (queue, worker slots, speed). The bottleneck is orange. A truck card with a fill bar, the price it would lock and **Dispatch**. A Routes tab (crop → Truck / Shop / split). An Upgrade tab. On phones the pipeline wraps into 2 rows of 3 |
| **Shop** | shop counter with price tags | Each crop: shelf stock, the reference price, **your price** (slider + − buttons), the demand face, ~sales/min. Shop Rating stars and why ("3 shoppers left: empty shelves"). Stockroom count. Upgrade tab |
| **Workers / Hiring Hall** | ID badges on a corkboard | Station slots ("Packer 2/3"). Candidate badges: photo, name, type, level, trait, wage, hire fee, **Hire**. Your workers: train, fire, assign, the Driver's rule |
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
| Fines received (moved from thieves, never created) | Land clearing fees (once a permit is earned) and buildings: the Silo, warehouse and shop tiers |
| Quests, streak, Cropdex rewards | Defences |
| | Auction wins (the coins are spent) |
| | Auction Board 5% fee (v1.1) |

**Rules**
- Robux never buys stealing power or defence power (§7).
- Fines only move coins between players. Debts expire after 7 days rather than creating coins.
- Watch weekly: total coins, median Net Worth, Mythics in circulation, average fine, raids per hour per server, % of raids ending in an arrest (aim for 35–50%).
- **Open: late-game sinks.** In the progression sim a daily player has bought all the land and buildings by day 23, then piles up coins (about 4 million by day 35, earning 500,000–700,000 a day). The sim leaves out auctions, defences and the shop, which use some of that, but not enough. Before launch the game needs long-term coin sinks (see §11).

## 7. Monetization
Rule: **no paid power in the PvP**. Robux buys comfort, shared moments, space and looks.

| Item | Type | Robux | What it does |
|---|---|---|---|
| VIP | Pass | 199 | +10% sale income, a gold name tag, a VIP truck paint and shop awning |
| Bigger Barn | Pass | 99 | Barn capacity ×2.5 |
| Rain Dance / Thunderstorm / Golden Hour / Harvest Moon | Product | 49 / 79 / 99 / 149 | That weather **for the whole server** for 5 min (Tide Market totem rules: one at a time, never over a better weather, never into the scheduled Harvest Moon). A Harvest Moon bought is a Heist Night for everyone |
| Growth Boost | Product | 79 | Your field grows ×2 for 30 min (online only) |
| Cosmetics | Products | 25–249 | Bat skins (Golden Bat, Baguette, Carrot Club: **same stats**), truck paint jobs, shop signs and awnings, farmhouse styles, scarecrow skins, sack skins, funny mugshot frames |

- **Never sold:** Land Permits (land opens by level only), defences, steal speed, sack size, bat reach, knockout length or immunity, more worker slots than a station's cap.
- Nothing bought with Robux can be traded (so regional pricing can't be resold).
- Receipts de-duplicated by PurchaseId and saved before granting (the Tide Market pattern).

## 8. Technical architecture

```
src/shared/   Config/  Crops · Rarities · Growth · Land · Warehouse · Shop · Workers · Auction · Market
                       Crime · Progression · Settings   (to come: Weather · Mutations · Defences · Monetization)
              Rules:   GrowthRules · SeedStock · MarketPrice · DemandModel · LandRules · ProgressionRules
                       CrimeRules · FineRules · TravelRules · ZoneRules · AuctionRules · WorkerRules
                       PipelineRules · MoveRules   (to come: TradeRules)
src/server/   Services/ Data · Plot · Field · SeedShop · Auction · Market · Warehouse · Truck
                        Shop · Shopper · Worker · Crime (steal, sack, bat, knockout, arrest)
                        Police · Payout · Movement · Trade · Weather · Quest · Leaderboard
                        Analytics · DevCommand
              World/    WorldBuilder · PlotLayout · TownBuilder
src/client/   UI (Kraft & Crate theme, HUD in code) · Controllers/ Field · Warehouse · Shop
              Workers · Market · Auction · Crime (alarm, KO, mugshot) · Trade · Weather
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
  warehouse = { tier, buildingUntil?, queues = {...}, routes = {...}, trucks = { TruckRun? } },
  shop = { tier, shelves = {...}, stockroom = {...}, prices = { [cropId] = coins }, rating = {...} },
  workers = { [uid] = { type, level, trait, station, hiredAt } },
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

## 9. MVP plan (8 weeks)

| Week | Build | Done when |
|---|---|---|
| 1 | Plots and zones, field (plant, water, grow, harvest), Barn inventory, Barley's shop with restocks, saving. Greybox Cloverdale | 8 players can farm for 15 min without bugs |
| 2 | Farm Level and XP, Land Permits and clearing, Packing Shed and the pickup truck, the market price (wave + events), Exchange board, Farm Stand with shoppers and pricing | Players argue about truck vs shop |
| 3 | T1 warehouse and Farm Shop, all worker types, wages and strikes, offline growth and worker settlement, Welcome back card | Testers come back the next day to collect |
| 4 | Stealing, the sack, deposit, bat, knockout, Suspect, arrest, Police Station, fines and debt, every bypass counter + tests | Raids feel fun on both sides; nobody can dodge an arrest |
| 5 | Defences, theft alarm, Home, Sprout Shield, arrival grace, raid caps, Trusted list, MovementService | A defended farm catches most raids; an undefended one still survives |
| 6 | Auction House, weather and mutations, Harvest Moon, Cropdex, quests | Auction rooms fill up on the bell |
| 7 | Trading with logs and rollback, the MemoryStore supply factor, leaderboards, the Farm Guide | 50-player test with no duplication or lost items |
| 8 | Kraft & Crate UI polish, mobile layout, analytics, monetization, store art, thumbnails | Launch with a small sponsored-ad budget |

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

## 11. Next steps

In order. Each one makes the next one cheaper. Every step ends with a review against this doc (logged in §10) before the next one starts. Play-testing runs alongside from now on: [PlaytestPlan.md](PlaytestPlan.md) has a stage after each block of MVP weeks, with pass bars and gates.

1. ✅ **Set up the project.** Rojo + Rokit, ProfileStore, `DataService` (with a hook that runs automatic arrests before a save closes), `MovementService` / `MoveRules`, Analytics, the Lune test harness and `tools/check`, all from Tide Market. Still to port: the UI helpers (`UI.compact`, `UI.touch`, panels, item cards) re-skinned to Kraft & Crate, and the dev-command service; both come with week 1.
2. ✅ **Write the shared rules with Lune tests.** `GrowthRules`, `SeedStock`, `MarketPrice`, `DemandModel`, `LandRules`, `CrimeRules` (every bypass in the §4.12 table), `FineRules`, `TravelRules`, `ZoneRules`, `AuctionRules`, `WorkerRules`, `PipelineRules.simulate`, plus config checks: 155 tests, all passing (`lune run tools/check`).
3. ✅ **Build a progression sim.** `lune run tools/progression`: the XP curve is tuned so every permit target is met, and wages stay at 5–8% of income. It also showed that coins pile up late (see step 6).
4. ✅ **Greybox Cloverdale and time the raid race.** The layout, the greybox and the race from real distances are done and tested (5.8 s without defences, 11.4 s with them; the tall fence went to 3.5 s). Walked in Studio on 2026-10-30 (play-test Stage A, §10): the distances hold. Still open from Stage A: A7 (finding your way) needs a new tester.
5. **MVP weeks 1–4 (§9)**, play-tested as they land (PlaytestPlan Stages A–D). Week 1 needs the Stage B dev commands (`/coins`, `/level`, `/grow`, `/restock`, `/tp`, `/wipe`) built with it. The look pass ([ArtDirection.md](ArtDirection.md) §11) runs alongside: light, fences and the field with week 1's crops first, so the farming loop has something to look at. The raid stage measures the arrest rate (target 35–50%) and whether raids feel fun from both sides before defences are built in week 5.
6. **Late-game coin sinks** (found by the sim). Ideas to choose from: bigger auction lots and a weekly "Grand Auction", worker training past level 5, farm decorations that raise the Shop Rating cap, a coin-bought prestige ("Harvest Festival") that resets land for a permanent bonus, and costly seasonal seeds. Re-run the sim to see coins level off.
7. **Content and policy checks before launch.** Run the maturity questionnaire with the bonk and arrest content (aim for *Mild*), name the crops and NPCs, and plan the low-poly crop mesh pipeline (like Tide Market's `tools/plant_art`).
