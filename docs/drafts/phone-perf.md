---
title: "Phone performance: test script, Studio split and proposed optimisations"
date: 2026-11-09
status: "Draft for the developer. Nothing here is built yet except the /debug perf box."
---

# Phone performance

The developer's first phone test (Pixel 7 Pro, automatic graphics; the player plus 6 debug leaders at 150, jumping) showed FPS around 30, `LineRenderer` about 13 ms on average and 21 ms at worst, and the jump replay now and then. The budget (spec 9.8) is 45 FPS or more and `LineRenderer` 2.5 ms or less on a mid-range phone. This page is for finding where the time goes before changing anything.

## 1. The perf box (`/d perf`)

Type `/d perf` in chat (whitelisted players only) to show or hide it. It sits in the top-right corner:

```
FPS 60  frame 16.7 ms (max 20.6)        FPS in the last second; time between frames, 5 s average and worst
Line 3.21 ms avg, 8.84 max (5s)         LineRenderer's own time per frame
 sample 0.34  waves 0.05  hop 0.22      path sampling | jump waves and hops | hop, waddle, facing, CFrame
 loop rest 0.32  bulk 2.26              rest of the per-follower loop | workspace:BulkMoveTo
 record 0.10 (Heartbeat, extra)         recording leaders into paths (outside the Line figure)
 timers ~0.09 ms (2672 calls)           what the box's own timers add (take it off the Line figure)
Drawn 887 (1138 parts)                  followers drawn, parts moved this frame
Corrections 30s: 0 rollbacks (...)      Server Authority corrections in the last 30 s
```

- `Line` = `sample` + `waves` + `hop` + `loop rest` + `bulk` (+ a little sorting).
- **Corrections:** game scripts can't listen to `RunService.Misprediction` (it needs the plugin capability), so the box counts `RunService.Rollback`, which fires once per correction. In Studio the two counts matched exactly: 20 and 20 in 10 s, also 20 resimulation bursts. A rollback doesn't say what was wrong. The `walk8` debug command causes corrections by itself (the server steers `Humanoid.WalkToPoint`), so don't use it in these runs.

## 2. Phone test script

**Before you start**
- Publish the current build: Rojo connected, then File → Publish to Roblox.
- Phone unplugged, battery above 50%, brightness fixed, other apps closed, graphics on Automatic (note it if you change it).
- Start cool: screen off for 5 minutes first.
- Join alone, so nobody else's line is drawn.

**Every run**
1. Join, then type `/d perf` and `/d goto me peaks 200` (the same spot every time).
2. Type that run's setup commands.
3. Walk in a slow circle with the thumbstick, so the camera sweeps round.
4. Screenshot the box at 20 s and at 60 s. Also note any jump replay and when it happened.
5. **Cool-down:** leave the game and lock the phone for 3 minutes. Leaving also empties the server, so the next run starts fresh.

| Run | Setup commands | What to do |
|---|---|---|
| (a) No lines: baseline | none (a fresh join has no line and no leaders) | Walk in a circle for 60 s. Then stand still for 10 s looking into the biome, and take a third screenshot |
| (b) My line at 150 | `/d fill me 150 peaks` (raises Leash and Longer Leash to hold 150) | Walk for 10 s so the line unfolds, then walk in a circle for 60 s |
| (c) Me plus 5 leaders at 150 | `/d fill me 150 peaks`, then `/d leaders 5 150 peaks` | Walk among the leaders in a circle for 60 s. Then stand still for 20 s facing where most lines are, and take a third screenshot (the worst view) |
| (d) As (c), jumping | as (c) | Walk in a circle and tap Jump about once a second for 30 s. Screenshots at 20 s and 30 s. Note each jump replay |
| (c2) Optional: (c) again | as (c) | Run last, to see whether heat has made the phone slower |

**Record** each screenshot into this table and paste it back:

| Run | FPS | Frame avg / max | Line avg / max | sample | waves | hop | loop rest | bulk | record | timers | Drawn (parts) | Corrections | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| (a) 20 s | | | | | | | | | | | | | |
| … | | | | | | | | | | | | | |

How to read it:
- **(a) alone** shows what the phone does without lines. If (a) is already well under 60 FPS, the frame is limited by more than `LineRenderer` (rendering, the map, the graphics level).
- **(b) and (c)** separate the cost of my line from the cost of other players' lines.
- **(d)** shows what jump waves add, and whether corrections come with the jump replay.

## 3. Studio split (PC, for scale)

Studio, real simulated input (the Input Action System, not `walk8`), the player and 5 leaders at 150 in Snowy Peaks:

| | Walking | Walking and jumping every 0.8 s |
|---|---|---|
| Line, avg / max | 3.21 / 8.84 ms | 2.99 / 4.32 ms |
| sample | 0.34 | 0.36 |
| waves | 0.05 | 0.06 |
| hop | 0.22 | 0.20 |
| loop rest | 0.32 | 0.30 |
| **bulk (BulkMoveTo)** | **2.26 (70%)** | **2.05 (69%)** |
| record (Heartbeat) | 0.10 | 0.10 |
| Timers' own cost | about 0.09 | about 0.09 |
| Drawn (parts moved) | 887 (1,138) | 821 (1,066) |
| Corrections, 30 s | 0 from jumping | 0 |

- **Unit costs:** about 2.0 µs per part moved and about 1.05 µs of Luau per follower drawn.
- **Where the drawn followers were** (900 placed, distance from the player): 20% within 40 studs, 42% within 80, 74% within 120, and all within 200. **Only 91 of the 900 (10%) were on screen.**
- **Placeholders are 2 parts each** (body and head), so `BulkMoveTo` moves twice the parts that single-mesh critters will.
- **Phone versus Studio:** the phone's 13 ms is about 4× Studio's 3.2 ms, for 7 lines against 6. The estimates below assume the phone's split looks like Studio's; runs (a)–(d) will confirm or correct that.

## 4. Proposed optimisations, ranked by expected saving

Savings are of `LineRenderer` time, worked out from the Studio split and the distance figures above. Phone milliseconds assume the same split as Studio (×4.2). The savings overlap, so they don't add up.

| # | Change | Expected saving | Phone (from 13 ms) | Cost and risk |
|---|---|---|---|---|
| 1 | **Off-screen followers updated rarely.** A cheap camera-cone test (one dot product per follower, with a margin of about 20° beyond the field of view). Off-screen followers skip the hop maths and the move, and refresh every 8th frame | 60–80% (90% of followers were off screen in Studio; assume 30–40% on screen in play) | −8 to −10 ms | Small. When the camera swings fast, a follower at the edge can be up to 0.13 s (about 1.5 studs) out of date for one frame; the margin hides most of it |
| 2 | **Single-part placeholders** (body only, or a single mesh). Not an optimisation of the shipped game, but it makes the test measure what will ship: pack critters are one MeshPart each | About 35% (`bulk` halves) | about −4.5 ms | Needed anyway before the phone budget can be judged. The art pass brings the real meshes |
| 3 | **Far followers moved less often.** Full detail within 40 studs (now 80), `FarUpdateEvery` 4 (now 2), with no hop or waddle beyond 40 | About 35–40% (moves per frame from 0.71 to 0.40 of drawn) | about −5 ms | Lines 40–150 studs away move 15 times a second. At those distances on a phone that's hard to see, and `Smoothing` hides the steps |
| 4 | **Other players' lines drawn more cheaply than my own.** No waddle or jump waves on others' lines, every 2nd frame even when near | About 35% alone; about 10% on top of 1 and 3 | −1 to −4 ms | You see your own line at full quality. Others' lines look a little less lively up close. Jump waves on others' lines are a nice touch to lose |
| 5 | **Fade in and out, then a phone cap or a shorter hide distance.** Followers fade over 0.25 s instead of popping, which makes a cap of about 450 nearest followers, or `HideDistancePhone` 100, acceptable | Up to 50% in a full server, 0% below the cap. Hide distance 100: about 40% (58% of drawn are within 100) | up to −6 ms in the worst case | A hard upper bound for any number of players. Fades cost a few `Transparency` writes a frame. Lines further away are hidden, but cutting only needs the near ones |
| 6 | **`--!native` on `LineRenderer` and `Path`** | Luau is about 29% of the time in Studio. Native code typically runs numeric code 1.5–3× faster, so 10–20%, probably more on a phone | −1.5 to −2.5 ms on Android, **0 on iPhone** | One line per file. The Creator Hub (native code generation page, updated 2026-11-09): native code runs only in server scripts and in client scripts on Android. It does nothing on iOS, so it can't be what keeps us in budget |
| 7 | **Skip the hop maths beyond a distance** (on its own) | Waves and hop together are only 0.27 ms (8%); skipping beyond 40 studs saves about 6% | about −0.8 ms | Already covered by 3 |

**Suggested order:**
1. Build 2 first, so the numbers are real.
2. Then 1 and 3 together. Estimate in Studio: 3.2 ms → about 0.6–0.8 ms; on the phone about 2.5–3.5 ms.
3. Then 6 on Android and 5 as the safety cap.
4. Re-run (c) and (d) after each step.

If run (a) shows the phone well under 60 FPS with no lines at all, the graphics level and the map need looking at as well.

## 5. Comparing with `AuthorityMode = Automatic`

Under Server Authority the client predicts its character and the server corrects it. Under Automatic the client simply owns its character, so there's nothing to correct: if the jump replay disappears there, it's a prediction problem; if it stays, it's ours (animation or LineRenderer).

**Found in Studio (2026-11-09): under Automatic the player can't move.** Setting `Workspace.AuthorityMode` to Automatic kept streaming on, but the engine didn't start the Input Action System's character controls. `Players.<you>.InputContexts.CharacterContext.MoveAction` was missing, there was no classic `PlayerModule` either, and the character didn't respond. Our own throw actions (`PlayContext`), the lines and the perf box all worked. I set the place back to Server, and the controls came back.

Steps (use a separate private copy, so the main place stays on Server):
1. In Studio, select Workspace and set **AuthorityMode** to **Automatic** in the Properties panel.
2. In the same panel, find the **PlayerScriptsUseInputActionSystem** setting. The docs list it among the five that Server mode sets; it may sit under Workspace or StarterPlayer, and it can't be read from a script, so I couldn't check it. Untick it, so the classic `PlayerModule` (thumbstick and jump button) loads.
3. Press **Play** and check that you can walk (WASD) and jump (Space). If you can't, stop and tell me; the comparison would be meaningless.
4. **File → Publish to Roblox As… → Create new experience**, private, named for example "Conga Critters (Automatic test)". The main place's published version stays on Server.
5. Join the copy from the phone and repeat run (d). Corrections should read 0 there. Note whether the jump replay still happens.
6. Afterwards, in Studio set **AuthorityMode** back to **Server**, which turns the five settings back on, and check with Play that you can move. Before the next publish, check which place File → Publish targets: after Publish As, Studio publishes to the new copy until you reopen the main place.
