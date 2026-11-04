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

## The art (`tools/page_art/compose.py`)

Take each shot in Studio (Play, graphics quality at its highest, the HUD hidden: with the command bar on the client, `game.Players.LocalPlayer.PlayerGui.FarmHeistHUD.Enabled = false`), save it as `art/page/shots/<name>.png`, then run `python tools/page_art/compose.py`. It writes `art/page/icon.png` (512 × 512) and the thumbnails (1920 × 1080).

| Piece | The shot | Its line |
|---|---|---|
| `icon` | Made from the `raid` shot, cropped to the two characters | the FARM HEIST sign |
| `farm` | A full farm at Golden Hour from above the gate: the field ripe, the farmhouse and barn, the store and the warehouse | the FARM HEIST sign, "GROW CROPS · RUN YOUR FARM" |
| `raid` | Two players (Server & Clients): the thief holding a stolen pumpkin up, the red ! over them, the farmer behind with the bat, ripe pumpkins round them | "STEAL CROPS · BONK THIEVES!" (at the top) |
| `store` | Inside a Supermarket full of displays and shoppers queueing at the checkouts | "BUILD YOUR OWN STORE" |
| `auction` | The Auction House during a lot: Goldie Gavel, the lot over its pedestal, the board | "BID ON RARE SEEDS" |
| `trucks` | A semi leaving the warehouse's dock, crates in the Cold Room, workers at the line | "SHIP TO THE CITY" |
| `community_emblem` | None: drawn by the script (512 × 512). The plain bat and a carrot crossed, outlined like stickers, on barn-red planks with a stitched cream edge and a gold sparkle; no words, so it still reads at the 40-odd pixels Roblox shows emblems at in lists | none |
| `community_cover` | The `farm` shot's right three quarters (1440 × 456, the 60:19 Roblox asks for, about 1:1 from the shot): the barn and farmhouse in the top half on the left. Roblox fades the cover's bottom into the page and puts the emblem and the name over its lower left, so nothing that matters is there | the FARM HEIST sign, hung on the right |

Made on 2026-11-04 (in `art/page/`, shots in `art/page/shots/`): `icon.png`, `farm.png`, `raid.png`, `auction.png`, `trucks.png`, `community_emblem.png`, `community_cover.png` (the community's two judged on a mock of the community page, light and dark, desktop and phone: the cover photo's size is from a DevForum answer, Dec 2025, as Roblox's docs don't give one). Still to take: `store` (a Supermarket full of displays and shoppers takes a long staging run). Studio's game view is 1920 × 822 at most on this screen, so each shot is taken in four quarters and stitched, and thumbnails are scaled up from about 1460 × 820.

Upload: Creator Dashboard > the experience > Places > the start place > Thumbnails (the farm first); the icon under the experience's Basic Settings.

## Passes and products (Creator Dashboard > Monetization)

Make each one with this name, price and picture (a crop's icon from the game works), then paste its id into the file named. Then `lune run tools/check`.

**Passes** (`src/shared/Config/Monetization.luau`, `passId`):

| Id in the code | Name | Robux | Description |
|---|---|---|---|
| `VIP` | VIP | 199 | +10% coins from every truck and store sale, a gold VIP tag, VIP Gold truck paint and a gold store awning |
| `BiggerBarn` | Bigger Barn | 99 | Your barn holds 2.5× as many crops |

**Developer products** (`productId`: the weathers and the boost in `Config/Monetization.luau`, the looks in `Config/Cosmetics.luau`):

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

Check after: buy one of each in a published test server (each item's price is spent on your account; the purchase comes back as a receipt in the game's Output), and that a pass shows as Owned after a rejoin.

## Sounds (`tools/sound_art/generate.py` → `art/sounds/`)

Upload each `.wav` (Studio: Window > Asset Manager > Import, or Creator Dashboard > Development Items > Audio), then paste its id as `"rbxassetid://..."` next to the same name in `src/shared/Config/Sounds.luau`. They're silent until then.

Error · Plant · Water · Harvest · CashRegister · LevelUp · Tape · TruckHorn · Siren · Bonk · Whistle · Rustle · AlarmBell · Gavel · Rain · Birds · Crickets · FarmTheme

Still to pick from the Creator Store (Toolbox > Audio, one Roblox uploaded so anyone may use it): **Bark**, the guard dog.

## Before launch (PlaytestPlan Stage F)

- Creator Analytics shows the onboarding funnel, the Robux shop's funnel, the economy and the raid events from a private test server.
- The crop and prop meshes are imported into the published place (README step 4).
- Stage E's 50-player test and Stage F's new players on phones have passed.
