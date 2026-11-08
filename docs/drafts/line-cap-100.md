---
title: "Draft: lines capped at 100 (150 with Longer Leash)"
status: "Approved by the developer on 2026-11-08 with one change (walk speed slows 0.3% a critter, not 0.15%) and applied: economy.md v0.5, spec v0.23, Config. Kept as the record of the comparison; economy.md is the master for every number."
date: 2026-11-08
---

# Draft: lines capped at 100 (150 with Longer Leash)

The developer's brief (2026-11-08): cap lines at 100 for free players and 150 with Longer Leash; keep the pass as ×1.5, not a flat +50, so it stays fair for new players; rebirth no longer adds +10 capacity. Draft the economy.md changes, rerun the model, compare three replacements for the rebirth capacity bonus, recommend one, and list the spec changes as Proposed.

Every number below comes from `tools/econ_sim.py` (new knobs, defaults unchanged: the default run reproduces economy.md 6.1 exactly) driven by `tools/line_cap_100.py`, 300 model players, 22 h each, seed 7. Run with `python3` (the 3.7 install has numpy).

## 1. Recommendation

| Change | Today | Proposed |
|---|---|---|
| Line cap | 300 (performance) | **100 free, 150 with Longer Leash** (150 is also the new performance cap) |
| Leash track | 13 levels, 10 → 200 | **9 levels, 10 → 100**: today's levels 1–9 and their costs; levels 10–13 removed |
| Longer Leash | ×1.5, capped at 300 | ×1.5, capped at 150 (unchanged in kind) |
| Conga steps | 1, 10, 25, 50, 100, 150, 200, 300 | **1, 10, 25, 50, 75, 100, 150**: ×1, ×1.25, ×1.5, ×2, **×2.5**, ×3, ×3.5 |
| Rebirth gives | +15% coins and LP, +10 capacity | +15% coins and LP, **throw cooldown −0.05 s per rebirth, never below 0.5 s** (option 2) |
| Rebirth LP needs | 1M, 2.5M, 5M, 12.5M, 30M | **750K, 1.7M, 3.7M, 9.5M, 23M** |
| Rebirth coin needs | 20M, 200M, 800M, 3B, 12B | **12.5M, 140M, 480M, 1.9B, 7.7B** |
| Pen income | 0.0006 coins/s per coin of value | **0.0005** |
| Longer Leash price | 299 R$ | **299 R$, unchanged** (developer's call: money) |

Result for the median free player: rebirths at **167, 426 and 852 min** against the targets of 164, 425 and 866 (all within 2%). Jungle (12 min), the first 100-critter line (23 min) and Snowy Peaks (56 min) don't move. Longer Leash reaches rebirth 1 **20% sooner** (today 19%); all passes **23% sooner** (today 26%). Pen share peaks at **36%** (target under 40%).

Why option 2: it is the only replacement that still changes anything a player can feel after the leash is maxed (each 100-line fills 5 s faster per rebirth), it doesn't touch cutting, and it is the only one with a measurable effect on later cycles. Walk speed is rejected on cutting fairness; luck and pen slots barely register. Details in section 3.

## 2. What changes in the model, before the replacement

| Median free player | Today | Cap 100, today's needs | Cap 100, needs refitted, no rebirth gain |
|---|---|---|---|
| Jungle / first 100 line / Snowy Peaks (min) | 12 / 24 / 57 | 12 / 23 / 56 | 12 / 23 / 56 |
| All upgrades maxed (min) | 145 | 162 | 155 |
| Rebirth 1 / 2 / 3 (min) | 164 / 427 / 866 | **203 / 574 / 1,192** | 167 / 433 / 878 |
| Coins a minute, 60–120 / 240–600 min | 874K / 1.54M | 658K / 1.22M | 658K / 1.10M |
| Coins held ÷ need at rebirth 1 / 2 / 3 | 1.26 / 1.33 / 1.01 | 1.91 / 1.80 / 1.28 | 1.35 / 1.31 / 1.24 |
| Pen share, 240–600 min | 33% | 47% | **41%** (over the 40% target) |

- A 100 line earns about 63% of a 200 line's LP a second (×3 instead of ×4, shorter runs), so today's rebirth needs push the cycles 24–38% later. Refitting the LP needs (bisection on each rebirth's median) brings them back.
- The Leash track maxes at about minute 21 instead of 93. Its 8 remaining costs total 63,810 coins, so the five tracks cost **79,471,235** per cycle instead of 87,421,235.
- Deliveries pay less, so the pen's share rises past the 40% target. Pen income 0.0006 → 0.0005 brings it to 36% (free) and 38–39% (all passes).

## 3. The rebirth replacements

All on top of "cap 100, needs refitted" (pen income 0.0006, Conga with ×3.5 at 125 and ×4 at 150 for this comparison; the free player never goes past 100, so those top steps don't affect it). The gains start at rebirth 1, so rebirth 1 itself never moves.

| Replacement | Time to fill a 100 line | Back to a 100 line after rebirth 1 | Coins a minute, 120–240 / 240–600 | Rebirth 1 / 2 / 3 (targets 164 / 425 / 866) |
|---|---|---|---|---|
| None | 101.8 s | 15.6 min | 547K / 1.10M | 167 / 433 / 878 |
| **1. Walk speed +1 per rebirth, at most +3** | 101.8 s (throwing sets the pace) | 15.6 min | 549K / 1.14M (+0% / +4%) | 167 / 431 / 872 (−0.5% / −0.7%) |
| **2. Throw cooldown −0.05 s per rebirth, at least 0.5 s** | 96.8 s after 1 rebirth, 91.8 after 2, 86.8 after 3, 71.8 from the 6th | 15.2 min | 564K / 1.19M (+3% / +8%) | 167 / 424 / 829 (−2% / −5.6%) |
| **3a. Bait luck +0.12 per rebirth** (one Bait level) | 101.8 s | 15.5 min | 557K / 1.14M (+2% / +4%) | 167 / 431 / 867 (−0.5% / −1.3%) |
| **3b. +1 pen slot per rebirth** | 101.8 s | 15.6 min | 548K / 1.11M (+0% / +1%) | 167 / 433 / 879 (0%) |
| 2 and 3b together | as 2 | 15.2 min | 564K / 1.20M | 167 / 424 / 828 |

For comparison, today's +10 capacity: back to a 100 line in 15.0 min.

**Option 1, walk speed, and cutting fairness.** Cuts need contact while moving at 6 studs/s or more (spec 4.4.2), so walk speed decides who can catch whom and who can get away. Today a maxed Speed track (28) is 40% faster than a new player (20). With +3 a third-rebirth veteran walks at 31: **55% faster than a new player**, and 11% faster than anyone else on a maxed track, so they can run down any line and outrun any revenge. The spec already keeps walk speed out of paid items for this reason (6.3). It also does almost nothing for pacing (rebirth 3 0.7% sooner), because a run is mostly throwing. Not recommended.

**Option 2, cooldown.** It touches only how fast a player fills their own line, not cutting. Rebirth 3 comes about 5.6% sooner, so the draft raises the 3rd rebirth's LP need from 3.5M to 3.7M (and the 4th and 5th to match), giving 852 min. It needs a per-player cooldown in ThrowService, its rate limiter, the THROW button's cooldown display and, from Update 2, Auto-Bait ("at the player's cooldown"). Spec 6.3's "No pass or product changes … cooldowns" stays true: rebirth is earned.

**Option 3a, bait luck.** Small (rebirth 3 1.3% sooner). Every odds panel would have to include the rebirth luck too, which adds to the paid-random-item display work (spec 6.4) for little gain.

**Option 3b, pen slot.** No measurable effect: the pen's best critters are already in the 30 slots the track gives, and favourites are capped at 3–8. It also nudges the pen share up.

**Mix.** 2 and 3b together is the same as 2 alone. No mix is recommended.

## 4. Passes and the pass price

Conga at 150 decides how strong Longer Leash is (the free player stops at 100, ×3):

| Conga at 150 | Longer Leash: rebirth 1 sooner than free | All passes, 8 favourites |
|---|---|---|
| Today (cap 300) | 19% | 26% |
| ×4 (with ×3.5 at 125) | 28% | 32% |
| ×3.75 (with ×3.5 at 125) | 24% | 28% |
| **×3.5 (today's step; no 125 step)** | **20%** | **23%** |

With ×3.5 at 150 the pass keeps today's strength, and "all the speed passes together make progress about a quarter faster" (economy.md 1.1) still holds. **Price: keep 299 R$.** The pass's effect matches what the price was set against (economy.md 11.6), so there is no case for changing it; review at the day-14 check as already planned. This touches money, so it is the developer's call.

Recommended set-up, all scenarios (minutes of play, medians):

| Scenario | Jungle | Snowy Peaks | All maxed | Rebirth 1 | Rebirth 2 | Rebirth 3 | Rebirth 1 vs free | Pen share 240–600 |
|---|---|---|---|---|---|---|---|---|
| Free | 12 | 56 | 155 | 167 | 426 | 852 | — | 36% |
| 2x Coins | 10 | 52 | 113 | 161 | 414 | 834 | 4% sooner | 36% |
| Longer Leash | 9 | 44 | 124 | 134 | 346 | 697 | 20% sooner | 33% |
| All passes, 8 favourites | 8 | 42 | 92 | 128 | 330 | 673 | 23% sooner | 38% |

Free player's coins a minute: 3.3K (0–15 min), 34K (15–30), 88K (30–60), 633K (60–120), 539K (120–240), 1.09M (240–600); just before rebirths 1, 2 and 3: 747K, 1.2M and 1.88M. Coins held ÷ need at rebirths 1–3: 1.33, 1.17, 1.12 (target 1.0–1.5). 2x Coins now brings rebirth 1 only 4% sooner (today 7%): coins stop mattering once the shorter Leash track is maxed.

## 5. Thresholds tied to line length

| Where | Today | Proposed | Why |
|---|---|---|---|
| Line banners and confetti (spec 4.3, 7.4; `Config.Line.Banners`) | 100, 200, 300 | **50 and 100, plus a "FULL LINE!" banner when a line of 100 or more reaches its own capacity** | Free and pass players get the same celebration at their own top (100 or 150). A banner at 150 alone would be a celebration only buyers can reach |
| "BIG STEAL!" with confetti (4.4.5) | 50 or more | **25 or more** | Half of today's, like the lines. The biggest steal from a full free line is now 50 (75 from a pass line) |
| Server-wide steal toast (4.4.5) | 100 or more | **50 or more** | Today it fires at the biggest steal from a full free line (100 of 200); 50 keeps that |
| Multiplier-step toasts (7.1) | at each Conga step | at each step of the new table (adds 75, drops 200 and 300) | Follows the table |
| Walk-speed slowdown (4.3) | 0.15% a critter, at least ×0.60 (at 267) | **Unchanged** (×0.85 at 100, ×0.775 at 150; the ×0.60 floor is never reached) | The model was fitted with it. Raising it (for example 0.3% a critter, ×0.70 at 100) would make full lines feel heavier again but slows every run; not simulated, flagged as an open question |

## 6. economy.md changes (draft text)

To apply only after the developer approves. Bump to v0.5.

- **0.3 / front matter:** add "2026-11-08 (proposed): lines capped at 100, 150 with Longer Leash; rebirth cuts the throw cooldown instead of adding capacity."
- **1.2 Pacing targets:** unchanged targets; model column 167 / 426 / 852 for rebirths 1–3; first 100-critter line 23.4 → 23 min.
- **2 Player model, Throwing:** "1 throw a second while filling the line (the 0.8 s cooldown plus aiming); 0.05 s less per rebirth, down to 0.7 s (0.5 s cooldown)."
- **4.6:** `capacity = min(150, floor(leash capacity × (1.5 with Longer Leash)))`; walk speed unchanged. Add `throw cooldown = max(0.5, 0.8 − 0.05 × rebirths)`.
- **4.3:** unchanged (rebirth still +15% coins and LP).
- **5.4 Conga multiplier and line:** table 1 / 10 / 25 / 50 / 75 / 100 / 150 → ×1 / ×1.25 / ×1.5 / ×2 / ×2.5 / ×3 / ×3.5. "Capacity: at most 100, 150 with Longer Leash (×1.5). Rebirth adds no capacity." Slowdown bullet: "×0.85 at 100, ×0.775 at 150."
- **5.5 Upgrade tracks:** Leash column ends at level 9 (100, 40,000); Leash total 63,810; all tracks 79,471,235.
- **5.6:** pen income 0.0006 → 0.0005.
- **5.7 Rebirth:** table LP 750,000 / 1,700,000 / 3,700,000 / 9,500,000 / 23,000,000 and coins 12,500,000 / 140,000,000 / 480,000,000 / 1,900,000,000 / 7,700,000,000; model medians 167 / 426 / 852. Bullet: "Each rebirth gives +15% coins and LP, added together, and cuts the throw cooldown by 0.05 s, to at least 0.5 s (4.3, 4.6)."
- **5.11 Prices:** Longer Leash row "Rebirth 1 20% sooner"; 2x Coins row "4% sooner".
- **6.1–6.5:** replace with the runs in section 4 (rerun at 1,000 players before publishing; these are 300-player runs).
- **6.8 Tier 4:** its 4M gate and raised later needs were fitted to today's LP rates. LP now comes about 26% slower, so the gate would sit above the new 3rd rebirth's need (3.7M) and open later than planned. Refit with the new needs before Fri 11 Dec (scaling by about 0.74 suggests a gate near 3M); `tools/line_cap_100.py` can run it with `--set`-style overrides.
- **10 Config mapping:** `Line`: cap 150 (`MaxCapacity`), `RebirthLeashBonus` removed; `Rebirth`: `CooldownCut = 0.05`; `Throw`: `CooldownMin = 0.5`; `Pen`: income 0.0005.
- **11 Decisions:** new row "Lines capped at 100, 150 with Longer Leash" (Proposed → Decided once approved); 11.6 (Longer Leash price) unchanged.

## 7. Spec changes (all Proposed)

| Section | Change |
|---|---|
| 1 (pitch) | "A 200-critter conga line" → "A 100-critter conga line" |
| 4.1 Throw | Cooldown 0.8 s, 0.05 s less per rebirth, at least 0.5 s |
| 4.3 Conga line | Capacity: leash level × 1.5 with Longer Leash; never above 150. Conga table as 5 above. Banners 50 and 100, plus FULL LINE! at capacity (100 or more). Walk-speed examples ×0.85 at 100, ×0.775 at 150 |
| 4.4.1 | Example "In a line of 300, positions 151–300" → "In a line of 150, positions 76–150" |
| 4.4.5 | BIG STEAL! at 25 or more; server toast at 50 or more; example "Ana made a 60-critter steal!" |
| 4.7 Rebirth | Gives: +15% coins and LP; throw cooldown −0.05 s, at least 0.5 s; the crown. Drop "+10 leash capacity, still within the 300 cap" |
| 5 milestones | Unchanged ("First 100-critter line: second or third session" still met at 23 min) |
| 6.1 Passes | Longer Leash: "Leash capacity × 1.5, so 150 at the top" |
| 6.3 Fairness | "Longer Leash never takes capacity past 150"; drop "and rebirth bonuses" |
| 7.4 Clip moments | Banners at 50 and 100 and FULL LINE!; "A 150-critter delivery" instead of 300 |
| 9.x performance | Budgets and soak test "every line at 300" → 150; `Config.Line.MaxCapacity` 300 → 150; LineRenderer pools and the phone cap sized for 150 |
| 10.2 checks | M3 checks 1, 3 and 4 at 150 (walk speed at 0, 50, 100, 150); M4 "a 300-critter delivery within 4.5 s" → 150 (see the note below); M5 check 6 thresholds 25 and 50; M9 check 3: after n rebirths the throw cooldown is max(0.5, 0.8 − 0.05n) and capacity doesn't change; soak test at 150 |
| 16 | One row per change above, Proposed, pointing here |

Note on M4: delivery runs at max(8, L₀ ÷ 4) critters a second, so any line of 32 or more takes 4 s. A 150 line takes 4 s, like a 300 line today, so the 4.5 s limit stays.

## 8. Open questions for the developer

1. Approve option 2 (cooldown) as the rebirth reward, or pick another (section 3)?
2. Keep Longer Leash at 299 R$ (section 4)? Money: your call.
3. Banners: 50, 100 and FULL LINE! at capacity, or a plain 150 banner (reachable only with the pass)?
4. Heavier full lines (raise the 0.15% a critter slowdown)? Needs its own model run.
5. When: before the soft launch (Fri 20 Nov) this changes Config, the M3/M4/M9 checks and the spec in many places; C01-M9 (rebirth) isn't built yet, so the rebirth part costs nothing extra now.
