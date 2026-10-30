# Farm Heist: Play-test log

One entry per session, newest first. Cases and pass bars are in [PlaytestPlan.md](PlaytestPlan.md). Use first names or "Tester 3"; no personal details.

## Template (copy this)

```
### YYYY-MM-DD · Stage X · build <git commit or date+time>
Testers: <who / how many> · Setup: <solo / Clients and Servers × N / private server> · Lag: <0 / 0.2 s>

| Case | Result (numbers, 3 runs) | Pass? | Notes |
|---|---|---|---|
| A1 | 14.1 / 14.6 / 14.3 s | ✓ | |

Bugs: <what, how to reproduce>
Changes made because of this session: <Config / PlotLayout values, and the new tools/raidrace or tools/progression result>
Follow-ups: <what to test next time>
```

## Sessions

### 2026-10-30 · Stage A · build 0795bb8 + this session's changes
Testers: Claude, driving Studio (walks scripted with `Humanoid:MoveTo`, timed every 0.25 s; screenshots in [playtest/2026-10-30/](playtest/2026-10-30/)) · Setup: solo Play · Lag: 0

| Case | Result | Pass? | Notes |
|---|---|---|---|
| A1 | Farm 1: 14.8 s (235 studs) · Farm 5: 12.8 s (204 studs) | ✓ | One run each. Farm 5 is the nearest farm to the town spawn, so the bar is now 12.5–17 s |
| A2 | 1.3 s walking (20 studs) · 1.6 s at sack speed | ✓ | |
| A3 | 6.7 s (158 studs), sprinting at 24 | ✓ | `tools/raidrace` assumes 160 studs |
| A4 | Back fence, hedge, front fence: all blocked | ✓ | The first runs never really jumped: the player controls reset `Humanoid.Jump` every frame. Re-run with forced jumps: the highest the character got was 10.4–10.5 studs (root), a normal jump. Without the invisible wall, the new rail fence gets climbed like a ladder, so the wall stays |
| A5 | You can see a player on the back row from the farmhouse door and from the warehouse | ✓ (barely) | They're about 10 px tall at 135–160 studs, and the rocks on locked land hide some of the back row. Needs the Suspect "!" ([ArtDirection §9](ArtDirection.md)) |
| A6 | 49.2 s, 785 studs (police porch → behind Farm 1, the farthest) | ✗ against 24–36 s | The plan's bar came from straight lines through the plots. On real routes it's 590–790 studs (37–49 s); with Visit and a walk round the hedge, about 30 s. Doc, test and bar corrected |
| A7 | Not run | — | Needs a new human tester |

Bugs: none in the code. Walking from Farm 5's gate straight to the police porch runs into the back of the Police Station; players walk round it (the town's paths will lead the way, ArtDirection §6). ProfileStore ran on its mock store (API access is off), which Stage A doesn't need; B7 does.

Changes made because of this session:
- GameDesign §3 and `tests/layout.test.luau`: the arrest walk is measured along real routes; §4.10: the same-farm cooldown also starts after an arrest.
- PlaytestPlan: A1 bar 12.5–17 s; A6 redone.
- WorldBuilder: labels sized in studs and hidden beyond 45–260 studs; fences 8 studs, posts and rails (`PlotLayout.FENCE_HEIGHT` 5 → 8), invisible walls kept.
- `tools/raidrace` unchanged: 5.8 / 11.4 s for the thieves, 7.7 / 10.4 s for the owner.
- New: [ArtDirection.md](ArtDirection.md), written from this session's screenshots.

Follow-ups: A7 with a new tester; walk A1 and A3 by hand with the keyboard to feel them (3 runs each); then the look pass and week 1.
