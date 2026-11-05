# Farm Heist's Roblox page and launch to-do

Everything the game's page on Roblox needs (design doc §7, §9 week 9, §11 step 7), and the things only the game's owner can do on the Creator Dashboard. The code is ready for each one: until an id is pasted in, an item is hidden in the live game (and free to try in Studio), and a sound is silent.

## Publishing as a community

Farm Heist is published by a community (Roblox's new name for a group), so the page shows the community as its creator. Do this first: passes, products, sounds and the game's settings all belong to the game, so they're made after it's published.

1. **Make the community:** on roblox.com, Communities > Create Community, named **Farm Heist**, with `art/page/community_emblem.png` as its emblem and a description (a one-time fee in Robux, shown on that screen). You're its owner. Then Configure Community > Information > Cover Photo: `art/page/community_cover.png`.
2. **Publish into it:** with `FarmHeist.rbxl` open and `lune run tools/check` passing, File > Publish to Roblox As… > Create new experience, and change **Creator** from your name to the community before Create (left on your name, the game lands on your profile).
   - Already published under your own account? Creator Hub > Creations > the game > Configure > Settings > Initiate ownership transfer, pick the community and accept on its side. The game goes private and its servers close while it moves; make it public again after.
3. **Set the game up:** Game Settings > Security > Enable Studio Access to API Services, and the server size of 8 (README).
4. **Make everything below as the community:** switch Creator Hub to the community before making passes and products or uploading sounds and art. Audio uploaded to your own account is private to you and won't play in the community's game. The Robux from passes and products goes to the community's funds; pay yourself from there (the community's Revenue > Payouts).
5. **Staff:** in live servers the community's owner can use `/trades` and `/rollback` (`src/server/Util/Staff.luau`). To let a role in too (moderators), set `Staff.GROUP_RANK` to that role's rank (the community's Roles settings show it), or add people by user id to `Staff.USER_IDS`.

## The page

**Name:** Farm Heist

**Description** (Creator Dashboard > the experience > Basic Settings; under Roblox's 1,000 characters):

> 🌾 Grow your farm... and guard it! 🌾
>
> 🥕 Plant 22 crops, from Carrots to the Mythic Dragon's Eye Pumpkin. Rare crops grow slowly and pay big.
> 🚚 Wash, pack and truck them to the City at the market price, or sell them in your very own store. Build it, decorate it, and watch the shoppers queue.
> 👷 Hire workers, level up your warehouse and your store, and clear more land.
> 🏃 Sneak onto other farms and steal their ripe crops: carry them home over your head!
> 🏏 Someone stealing yours? BONK them with your bat, then arrest them. The thief pays you!
> 🛡️ Scarecrows, guard dogs, floodlights and a locked gate keep your farm safe.
> 🔨 Bid on Mythic seeds at the Auction House, trade with friends, and climb the leaderboards.
> 🌧️ Rain, storms and the Harvest Moon change everything. Crops left out can turn Golden, Frosted or Moonlit!
>
> New farmers are safe for their first 45 minutes. Have fun, farmer!

**Genre:** Simulation (Tycoon). **Devices:** phone, tablet and computer (the HUD is made for a phone held sideways).

**Maturity questionnaire** (§11 step 7): cartoon bonks with no blood or injury, and a cartoon arrest. Aim for *Mild*.

## The art (`tools/page_art/stage.py`, then `compose.py`)

The icon and thumbnails are staged renders in the style of the top Roblox games' page art: big characters in the middle of the action, a bright sky, the background out of focus, dark outlines and a rim light. They star two characters made up for the page, in Roblox's blocky shape:

- **Sly**, the thief: a black beanie and mask, a striped shirt, a cheeky grin (or a sly smirk).
- **Farmer Hank**: a straw hat, a red plaid shirt, blue overalls and a big moustache; shouting, gritting his teeth or beaming.

`python tools/page_art/stage.py` renders each scene into `art/page/renders/` from the game's own parts and meshes (`lune run tools/partdump` dumps the farm, the Auction House, the farm with its Level 20 warehouse, and a Market Hall full of produce; the dumps are made for you and git-ignored), with the faces and clothes drawn as pictures on the characters' blocks. Then `python tools/page_art/compose.py` hangs the signs and writes `art/page/icon.png` (512 × 512) and the thumbnails (1920 × 1080). Each scene's camera, poses and touches (sparkles, glow, sweat, the bat's swing) are in `stage.py`'s `SCENES`.

| Piece | The scene | Its line |
|---|---|---|
| `icon` | Sly running at the camera with a glowing pumpkin held up on his head, sweating, eyes on Hank; Hank behind him in the field, bat raised. No words, like the top games' icons: the characters say what the game is | none |
| `farm` | Hank in his field hoisting a giant carrot, beaming, the barn and farmhouse behind him; Sly peeking out of the corn | the FARM HEIST sign, "GROW CROPS · RUN YOUR FARM" |
| `raid` | The icon's chase, wider, with the farm round them | "STEAL CROPS · BONK THIEVES!" (at the top) |
| `store` | Hank beaming at the till of a Level 14 Market Hall, coins flying out of it; shoppers queueing along the belt with full baskets, Sly among them with one carrot (he's buying: only fields can be raided); racks of produce behind them. The Market Hall, not the Supermarket: its checked floor and plaster are far warmer than the Supermarket's greys. Every display, tag and price is the game's own, on a layout `StoreLayout.check` passes. The camera's past the front wall on a long lens (25°), so the produce behind fills the picture | "BUILD YOUR OWN STORE" |
| `auction` | Sly (paddle 13, smirking) and Hank (paddle 7, teeth set) bidding against each other across the aisle; the Mythic Dragon's Eye Pumpkin glowing on the pedestal, Goldie Gavel at her podium | "BID ON RARE SEEDS" |
| `trucks` | Hank carrying a crate of carrots out past the semis' red cabs, lined up at the Distribution Center | "SHIP TO THE CITY" |
| `pass_vip` | Hank with his arms out in front of his VIP Gold semi, coins coming down round him. 512 × 512, everything that matters inside the circle Roblox shows it in | the game's gold ⭐ VIP tag over his head |
| `pass_barn` | The barn, its doors slid open on a heap of pumpkins, melons and more, the hayloft full too. 512 × 512, the same | "×2.5" on a gold board |
| `community_emblem` | None: drawn by the script (512 × 512). The plain bat and a carrot crossed, outlined like stickers, on barn-red planks with a stitched cream edge and a gold sparkle; no words, so it still reads at the 40-odd pixels Roblox shows emblems at in lists | none |
| `community_cover` | The `farm` shot's right three quarters (1440 × 456, the 60:19 Roblox asks for, about 1:1 from the shot): the barn and farmhouse in the top half on the left. Roblox fades the cover's bottom into the page and puts the emblem and the name over its lower left, so nothing that matters is there | the FARM HEIST sign, hung on the right |

Made on 2026-11-04 (in `art/page/`): `icon.png`, `farm.png`, `raid.png`, `auction.png`, `trucks.png` (staged renders, each judged at full size and at the sizes Roblox shows them: the icon at 150 and 64 px, the thumbnails at 240 px), `community_emblem.png`, `community_cover.png` (the community's two judged on a mock of the community page, light and dark, desktop and phone: the cover photo's size is from a DevForum answer, Dec 2025, as Roblox's docs don't give one). The cover photo is still from a Studio shot (`art/page/shots/farm.jpg`), as are the first icon and thumbnails' shots kept there. `store.png` followed on 2026-11-05, judged the same way, at full size and at 240 px beside the other four; then `pass_vip.png` and `pass_barn.png`, judged in a circle at 420, 150, 90 and 56 px.

Upload: Creator Dashboard > the experience > Places > the start place > Thumbnails (the farm first); the icon under the experience's Basic Settings.

## Passes and products (Creator Dashboard > Monetization)

Make each one with this name and price, then paste its id into the file named. Then `lune run tools/check`.

**Passes** (`src/shared/Config/Monetization.luau`, `passId`). Roblox always lists passes: they show in its Shop and outside the game (the homepage, search), so each needs its picture, and a category, which sorts it in the Shop. It shows a pass's picture as a circle, up to 512 × 512, so both are made to fit one.

| Id in the code | Name | Robux | Picture |
|---|---|---|---|
| `VIP` | VIP | 199 | `art/page/pass_vip.png` |
| `BiggerBarn` | Bigger Barn | 99 | `art/page/pass_barn.png` |

VIP's description:

> ⭐ Farm in style and earn more!
>
> 💰 +10% coins from every truck and store sale
> 🏷️ A gold VIP tag over your head and in chat
> 🚚 VIP Gold paint for your trucks (pick it in the Robux shop's Style tab)
> 🏪 A gold awning on your store
>
> Yours forever. It never helps in a raid: just more coins and a lot more shine.

Bigger Barn's description:

> 🌾 Run out of room? Not any more!
>
> 📦 Your barn holds 2.5× as many crops
> 🚜 Fewer trips to the warehouse when your field is big
> 🏗️ Works on top of every Silo upgrade
>
> Yours forever.

**Developer products** (`productId`: the weathers and the boost in `Config/Monetization.luau`, the looks in `Config/Cosmetics.luau`). No pictures needed: leave each one **Not Listed** (Monetization > Shop; new products start that way) and it's only sold from the game's own Robux shop, which draws its own icons. A Listed product shows in Roblox's Shop and outside the game too, with Roblox's default icon if it has no picture, so one would need a picture first; and the weathers are made to be bought in a server, where they start at once.

| Id in the code | Name | Robux |
|---|---|---|
| `RainDance` | Rain Dance | 49 |
| `Thunderstorm` | Thunderstorm | 79 |
| `GoldenHour` | Golden Hour | 99 |
| `HarvestMoon` | Harvest Moon | 149 |
| `GrowthBoost` | Growth Boost | 79 |
| `GoldenBat` | Golden Bat | 149 |
| `Baguette` | Baguette | 79 |
| `CarrotClub` | Carrot Club | 79 |
| `CherryPaint` | Cherry Red truck paint | 49 |
| `MintPaint` | Mint Green truck paint | 49 |
| `MidnightPaint` | Midnight Blue truck paint | 49 |

Check after: buy one of each in a published test server (each item's price is spent on your account; the purchase comes back as a receipt in the game's Output), that a pass shows as Owned after a rejoin, and that Monetization > Shop has the passes in sensible categories and the products Not Listed.

## Sounds (`tools/sound_art/generate.py` → `art/sounds/`)

Upload each `.wav` (Studio: Window > Asset Manager > Import, or Creator Dashboard > Development Items > Audio), then paste its id as `"rbxassetid://..."` next to the same name in `src/shared/Config/Sounds.luau`. They're silent until then.

Error · Plant · Water · Harvest · CashRegister · Scan · ShopBell · LevelUp · Tape · TruckHorn · Siren · Bonk · Whistle · Rustle · AlarmBell · Gavel · Rain · Birds · Crickets · FarmTheme

(`TillOpen` uses the CashRegister file: paste CashRegister's id into both.)

Still to pick from the Creator Store (Toolbox > Audio, one Roblox uploaded so anyone may use it): **Bark**, the guard dog.

## Before launch (PlaytestPlan Stage F)

- Creator Analytics shows the onboarding funnel, the Robux shop's funnel, the economy and the raid events from a private test server.
- The crop and prop meshes are imported into the published place (README step 4).
- Stage E's 50-player test and Stage F's new players on phones have passed.
