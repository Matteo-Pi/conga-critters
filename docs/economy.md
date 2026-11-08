---
title: "Conga Critters: economy"
repo_path: /docs/economy.md
economy_version: 0.5
date: 2026-11-08
status: "Tuned by simulation. Retune from live data after the soft launch (section 9)."
spec: "/docs/spec.md v0.7"
model: "/tools/econ_sim.py: 1,000 simulated players, 22 hours of play each, seed 7"
developer_decisions:
  - "2026-11-06: new biomes are a mix: tier-matched event biomes, plus a new top tier every second or third week"
  - "2026-11-06: Lead Power mostly rewards effort: LP doubles with each rarity step, and coins keep the jackpots"
  - "2026-11-06: Index coin bonuses have no cap"
  - "2026-11-07: rebirth and the 3 free favourite slots ship at the soft launch; Friend Boost is in from launch"
  - "2026-11-07: the rainbow trail needs only the Common, Uncommon and Rare species in Rainbow"
  - "2026-11-07: a missed day pauses the daily ladder"
  - "2026-11-07: every open decision in section 11 settled. Changed: the default auto-release filter keeps Golden critters, and players can switch auto-release off from launch"
  - "2026-11-08: lines capped at 100, 150 with Longer Leash; rebirth cuts the throw cooldown instead of adding capacity; walk speed slows 0.3% a critter (11.10)"
---
 
# Conga Critters: economy
 
## 0. Read this first
 
### 0.1 What this document is
- It sets every tuning number in the game: odds, critter values, Lead Power (LP), gates, upgrade costs, pen income, storage, rebirth, the Index bonus, daily rewards, events and prices. The spec (`/docs/spec.md`) says how each system works; this document says how much.
- Precedence: the spec's hard rules (spec 0.3), then the spec, then this document for numbers. If a number here and one in the spec ever differ, this document wins and the spec gets fixed.
- Every number lives in `src/shared/Config` (section 10). Never hard-code one.
- The numbers come from a simulation, `/tools/econ_sim.py` (section 6). Section 9 says how to retune them from live data.
- "Minutes" means minutes of play. Days assume 30 minutes of play a day (section 2).
### 0.2 Changing a number
1. Change it in Config, in `DEFAULTS` in `/tools/econ_sim.py` and in section 5 here.
2. Run the model (Python 3 with numpy): `python3 tools/econ_sim.py --free-only` for a quick check (under a minute), or `python3 tools/econ_sim.py --players 1000 --hours 22 --seed 7 --favourites` for the full report behind section 6 (about 8 minutes). `--set KEY=JSON` tries a change without editing the file.
3. Check the targets in 1.2 and the pen share in 6.2. Update section 6 if the results moved.
4. Add a line to the changelog (section 12), and to the spec's decisions log (spec 16) if a rule changed.
### 0.3 Changes from spec v0.2
Spec v0.3 and later include all of these.
 
| What | Spec v0.2 | Now | Why |
|---|---|---|---|
| LP per rarity | 1, 3, 10, 40, 200, 2,000 | 1, 2, 4, 8, 16, 32 | Developer's decision: LP rewards effort and coins keep the jackpots (1.1) |
| Jungle gate | 400 LP | 1,000 LP | 400 opened the Jungle at about 6.5 min; the target is 10–15 |
| Snowy Peaks gate | 20,000 LP | 50,000 LP | Opens on day 2 |
| Pen income | Value × 0.02 coins per second | Value × 0.0005 coins per second (0.0006 until v0.5) | Keeps the pen to at most about a third of coins, so playing beats idling |
| Upgrade costs | One formula per track | A cost for each level (5.5) | Income jumps ×10 at each biome, so no single formula fits. Early levels stay cheap; late ones match Snowy Peaks income |
| Storage track costs | 200 × 3^(n−2) | 2,000 up to 8,000,000 | Each level arrives about when storage starts to fill |
| Rebirth needs | 1,000,000 × 4^r LP | A table of LP and coins (5.7): 1M LP and 20M coins for the first | Cycles of about 2.7, 4.4 and 7.4 hours. Without a coin need, coins piled up with nothing to buy |
| Daily coin rewards | 3, 6 and 10 min of pen income | 10, 20 and 30 min of best pen income | Pen income is now smaller. Best pen income can't be lowered by moving critters (4.5) |
| Stand price | 15 min of pen income | 15 min of best pen income | Closes an exploit: moving pen critters into storage made Stand bait cost 500 |
| Default auto-release filter | Common and Uncommon, Normal only | Rare or lower, Normal only; never Golden (by default) or bound critters. Players can switch auto-release off from launch | In Snowy Peaks the old filter filled 50 storage slots in under 6 minutes; now it takes about 15 (5.6). Golden critters and critters from Golden Bait, which can be bought, are never released without the player choosing to (developer, 2026-11-07) |
| Storage overflow | Epic or better, and Rainbow | Legendary or better, Rainbow, and bound | The overflow of 50 now lasts about 110 minutes in Snowy Peaks |
| Release all shown | — | A button with the Update 1 storage filters | Clearing a full storage one critter at a time is slow |
| Golden Bait odds panel | Odds with active boosts | Odds for each depth band at the player's bait level, with active boosts | Luck applies to the Golden Bait table too (4.1) |
| New biomes | Weekly biomes | Tier-matched event biomes, plus a new top tier every second or third week (section 7) | Developer's decision ("Mix") |
 
Everything else in the spec's sections 4–6 is unchanged. Section 5 restates it all, so this document is complete on its own.
 
## 1. Goals and targets
 
### 1.1 Goals
1. **A fast, generous first 15 minutes.** A delivery and an upgrade within the first minute or two, an Epic within minutes, and a new biome at 10–15 minutes.
2. **Playing beats idling.** Pen income stays under about 40% of an active player's coins. It peaks at 36% in the model (38% with every pass).
3. **Lead Power rewards effort; coins carry the luck.** A Mythic is worth 2,000 Commons in coins but only 32 in LP. Lucky rolls pay out in coins, while gates and rebirths follow how much a player has delivered.
4. **Paying speeds things up but never skips.** All the speed passes together make progress about a fifth to a quarter faster (6.5). Three Golden Bait add about a twentieth of one Snowy Peaks run's LP.
5. **Nothing owned skips the climb.** The biome cap (spec 4.5.3) holds favourites, steals and grabs to the highest biome the player has unlocked.
6. **Numbers a 9-year-old can read.** Short, rounded numbers with K, M and B (section 8).
### 1.2 Pacing targets and results
The model's median free player; 6.1 has the spread. An engaged player (60 minutes a day) gets there in about half the days.
 
| Milestone | Target | Model | Day | Met? |
|---|---|---|---|---|
| First critter | Within 10 s | Not modelled (tutorial, spec 2.1) | 1 | Check in playtests (spec 12) |
| First delivery | Within 75 s | 0.5 min | 1 | Yes |
| First upgrade | Within 90 s | 0.5 min | 1 | Yes |
| First Rare | Within 1 min | Throw 6 (fixed tutorial roll) | 1 | Yes |
| First Epic | Within 8 min | 2.1 min (90% by 5.0 min) | 1 | Yes |
| Jungle unlocked | 10–15 min | 12.1 min | 1 | Yes |
| First 100-critter line | Second or third session | 22.8 min | 1 (second session) | Yes |
| Snowy Peaks unlocked | Day 2–3 | 56.5 min | 2 | Yes |
| First rebirth | Day 5–7 | 169 min | 6 | Yes |
| Second rebirth | About day 14 (new) | 426 min | 15 | Yes |
| Third rebirth | About day 30 (new) | 856 min | 29 | Yes |
| Every Normal species in the 3 launch biomes | Weeks 2–3 | Needs one trip back to the Meadow (6.7) | 7–8 | Yes, with a trip back |
 
Rebirth ships at the soft launch with the 3 free favourite slots (11.9), as the model assumes. Players on an hour a day reach their first rebirth on day 3.
 
## 2. Player model
The model plays like a focused player who never wastes a second. Real players are slower (6.9), so a target the model only just meets is at risk.
 
| Assumption | Value |
|---|---|
| Play | 15-minute sessions; 30 minutes a day typical, 60 engaged |
| Throwing | 1 throw a second while filling the line (the 0.8 s cooldown plus aiming); 0.05 s less per rebirth, down to 0.7 s at the 0.5 s cooldown (4.6) |
| Walking | 120 studs from pen to gate. Band centres 65, 200 and 335 studs into the biome. The first run starts 40 studs from the Meadow gate |
| Overheads | 1.8 s for the last critter to join, and 8 s a run for turning, crowds and the delivery summary |
| Band | Whichever band gives the most coins per second |
| Upgrades | After every delivery, buys the cheapest affordable level across all five tracks, until nothing is affordable |
| Rebirth | As soon as it's allowed. The 3 most valuable pen critters are kept as favourites |
| Cuts | From minute 5: 12% of runs lose a random share of the line, up to half (a quarter on average). Golden Bait critters are never lost. Gains from cutting others aren't counted |
| Golden Hour | Averaged in: 5 minutes in every 60 |
| Golden Bait | 4 per hour of play, thrown straight away. A player who claims every day gets about 3.9 a day from the ladder and the Stand |
| Left out | 6.9 |
 
Run time:
```
run = d ÷ v                                          walk out
    + capacity × t + 1.8 s                           fill the line; t = 1 s, less the rebirth cut (4.6)
    + d ÷ (v × max(0.6, 1 − 0.003 × capacity))       walk home, slowed by the line
    + capacity ÷ max(8, capacity ÷ 4)                deliver
    + 8 s                                            overheads
d = pen to gate + band depth (studs); v = walk speed (studs per second)
```
For example, a 100-critter Snowy Peaks run in the Far band at walk speed 28, before any rebirth, takes about 153 s (2.6 min).
 
## 3. Currencies and flows
| Currency | Comes from | Goes to | Reset by rebirth? |
|---|---|---|---|
| Coins | Deliveries; pen income; daily ladder days 1, 4 and 6; banking a line on leaving | Upgrades; Stand bait; each rebirth needs a coin balance (5.7) | Yes |
| Lead Power | Deliveries only | Never spent: biome gates and rebirth check it | Yes |
| Golden Bait | Daily ladder days 2, 5 and 7 (6 a week); the Stand (1 free and 2 for coins each day); Golden Bait ×3 for 49 R$ | One throw each | No |
| Shield time | Daily ladder day 3 (5 min); Line Shield for 29 R$ (10 min). Daily time stops adding at 60 min stored; bought time always adds in full | Shields (spec 4.11) | No |
| Robux | Players | Passes and products only. No coin packs (spec 6.4) | — |
 
- Deliveries make 67–97% of coins and the pen the rest (6.2). Each daily coin reward is worth a few minutes of play (5.9).
- Maxing all five upgrade tracks costs 87.4M coins per cycle. After that, coins only go on Stand bait and the next rebirth's coin need. Coins reset at rebirth, so that need works like a price.
## 4. Formulas
Implement these exactly. `Odds.luau`, `DeliveryService`, `IncomeService`, `DailyService` and `RebirthService` use them.
 
### 4.1 Rolls
```
λ = min(10, baitLuck × bandLuck × serverLuck × eventLuck)
    baitLuck   = 1 + 0.12 × (bait level − 1)       ×1.00 to ×2.68
    bandLuck   = Near 1, Mid 1.25, Far 1.5
    serverLuck = 2 while Server Luck runs, else 1
    eventLuck  = from Config/Events and /luck (at most 3), else 1
weight[r] = tableWeight[r] × λ for every rarity above the table's lowest; the lowest keeps its weight
chance[r] = weight[r] ÷ sum of weights
golden  = min(0.25, 0.02  × gb × ghGolden)     gb = 5 with Golden Bait, else 1
rainbow = min(0.02, 0.001 × gb × ghRainbow)    ghGolden = 5 and ghRainbow = 3 in Golden Hour, else 1
u = uniform in [0, 1): Rainbow if u < rainbow; Golden if u < rainbow + golden; otherwise Normal
```
The Golden Bait table's lowest rarity is Rare, so luck raises its Epic, Legendary and Mythic chances. Golden Bait's odds therefore depend on bait level and band, and its store panel shows the odds for each band at the player's bait level, with any active boost (spec 6.4).
 
Odds for checks and odds panels. Coins and LP per critter are before biome and Conga multipliers, with variants averaged over Golden Hour.
 
| Luck (λ) | When | Common | Uncommon | Rare | Epic | Legendary | Mythic | Coins per critter | LP per critter |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Normal bait, Near band | 70% | 22% | 6% | 1.6% | 0.35% | 0.05% | 22.9 | 1.58 |
| 1.25 | Mid band | 65.1% | 25.6% | 6.98% | 1.86% | 0.407% | 0.0581% | 25.7 | 1.67 |
| 1.5 | Far band | 60.9% | 28.7% | 7.83% | 2.09% | 0.457% | 0.0652% | 28.2 | 1.76 |
| 2 | Server Luck | 53.8% | 33.8% | 9.23% | 2.46% | 0.538% | 0.0769% | 32.3 | 1.89 |
| 2.68 | Bait level 15, Near band | 46.5% | 39.2% | 10.7% | 2.85% | 0.624% | 0.0891% | 36.6 | 2.03 |
| 4.02 | Bait level 15, Far band | 36.7% | 46.4% | 12.7% | 3.37% | 0.738% | 0.105% | 42.3 | 2.22 |
| 10 | The cap | 18.9% | 59.5% | 16.2% | 4.32% | 0.946% | 0.135% | 52.8 | 2.57 |
| 1 | Golden Bait, bait level 1, Near band | — | — | 70% | 22% | 7% | 1% | 318 | 6.00 |
| 4.02 | Golden Bait, bait level 15, Far band | — | — | 36.7% | 46.4% | 14.8% | 2.11% | 600 | 8.22 |
 
### 4.2 Tiers and the biome cap
```
topTier  = the highest tier among the fixed-tier biomes the player has unlocked (Meadow 1, Jungle 2, Snowy Peaks 3)
tier(c)  = topTier                          if c's biome is tier-matched (event biomes, 7.1)
         = min(c's biome tier, topTier)     otherwise (the biome cap, spec 4.5.3)
value(c) = rarity value × coin multiplier[tier(c)] × variant multiplier
LP(c)    = rarity LP × LP multiplier[tier(c)]
```
 
### 4.3 Boosts
```
coinBoost = (2 with 2x Coins) × (1.1 with VIP) × (1 + min(0.3, 0.1 × Roblox friends in the server))
          × (1 + 0.15 × rebirths) × (1 + 0.1 × completed Normal Index sets) × event coin multiplier
lpBoost   = 1 + 0.15 × rebirths
```
A factor that doesn't apply is 1.
 
### 4.4 Delivery
```
L₀ = line length when delivery starts; m = Conga multiplier for L₀ (5.4)
each critter delivered: coins += value(c) × m × coinBoost;  LP += LP(c) × m × lpBoost
banking on leave:       coins += value(c) × coinBoost;      no m and no LP
```
 
### 4.5 Pen income and best pen income
```
pen income per second      = 0.0005 × coinBoost × sum of value(c) over the critters in pen slots
best pen income per minute = 60 × 0.0005 × coinBoost × sum of the S highest value(c) among pen and storage critters
                             S = the number of pen slots
```
Best pen income is what the pen would earn if it held the player's most valuable critters. Moving critters can't lower it; only releasing them can. Daily coin rewards and Stand prices use it (5.9).
 
### 4.6 Capacity, walk speed and throw cooldown
```
capacity      = min(150, floor(leash capacity × (1.5 with Longer Leash)))    100 free, 150 with Longer Leash
walkSpeed     = (20 + speed level − 1) × max(0.6, 1 − 0.003 × line length)
throwCooldown = max(0.5, 0.8 − 0.05 × rebirths)                              seconds
```
Rebirth adds no capacity (since v0.5). A walk-speed change reaches the game 0.3 s after the line changes (spec 9.1).
 
### 4.7 Rebirth needs
```
need(k) for rebirth k (k = 1 is the first) = the table in 5.7, for k ≤ 5
need(k) = need(k − 1) × 2.5 for LP and × 4 for coins, for k > 5
```
 
### 4.8 Worked examples
- **First delivery:** 10 Meadow critters, including the fixed Uncommon and Rare. At worst the other 8 are Normal Commons: (8 × 5 + 15 + 50) × 1.25 = 131.25 coins. On average it pays about 310 coins and 23 LP. Leash level 2 costs 30, so the first upgrade is always affordable (spec 2.1).
- **A full Snowy Peaks run:** 100 critters at bait level 15 in the Far band (λ = 4.02), Conga ×3, no boosts: about 1.3M coins and 16,700 LP in about 2.6 minutes (v0.4's 200-critter run at ×4: 3.4M coins and 44,500 LP in 4.2 minutes).
- **A full pen:** 30 Snowy Peaks Legendaries (value 100,000 each) earn 30 × 100,000 × 0.0005 = 1,500 coins a second, or 90,000 a minute.
## 5. Tuned values
 
### 5.1 Rarities
| Rarity | Weight, Normal bait | Weight, Golden Bait | Coin value | LP | Colour |
|---|---|---|---|---|---|
| Common | 70 | — | 5 | 1 | White |
| Uncommon | 22 | — | 15 | 2 | Green |
| Rare | 6 | 70 | 50 | 4 | Blue |
| Epic | 1.6 | 22 | 200 | 8 | Purple |
| Legendary | 0.35 | 7 | 1,000 | 16 | Gold |
| Mythic | 0.05 | 1 | 10,000 | 32 | Pink |
 
Luck is capped at 10 (4.1). Always pair a rarity colour with an icon or label.
 
### 5.2 Variants
| Variant | Chance | Value | With Golden Bait | In Golden Hour | Cap |
|---|---|---|---|---|---|
| Normal | The rest | ×1 | — | — | — |
| Golden | 2% | ×3 | ×5 (10%) | ×5 (10%) | 25% |
| Rainbow | 0.1% | ×10 | ×5 (0.5%) | ×3 (0.3%) | 2% |
 
Averaged over Golden Hour, Golden is 2.67% and Rainbow 0.117%, which adds 6.4% to the average critter's value.
 
### 5.3 Biomes and tiers
| Tier | Biome | Gate | Coins | LP | Status |
|---|---|---|---|---|---|
| 1 | Sunny Meadow (`meadow`) | 0 LP | ×1 | ×1 | Launch |
| 2 | Jungle (`jungle`) | 1,000 LP | ×10 | ×5 | Launch |
| 3 | Snowy Peaks (`peaks`) | 50,000 LP | ×100 | ×25 | Launch |
| 4 | Not named yet | About 4,000,000 LP | ×1,000 | ×125 | Planned for Fri 11 Dec (7.2, 7.3) |
| Tier-matched | Event biomes, such as Autumn Woods | 0 LP, after the tutorial | The owner's top tier | The owner's top tier | From Update 1 (7.1) |
 
- Depth bands: Near ×1, Mid ×1.25, Far ×1.5. They split each biome into thirds by depth: about 0–130, 130–270 and 270–400 studs past the gate.
- Every biome, event biomes included, has at least one species of each rarity and uses the same rarity weights (spec 5.3).
- Launch biomes have 3 Common, 2 Uncommon and 2 Rare species, and 1 each of Epic, Legendary and Mythic (spec 5.4).
### 5.4 Conga multiplier and line
| Length at least | 1 | 10 | 25 | 50 | 75 | 100 | 150 |
|---|---|---|---|---|---|---|---|
| Multiplier | ×1 | ×1.25 | ×1.5 | ×2 | ×2.5 | ×3 | ×3.5 |
 
- Capacity: at most 100, 150 with Longer Leash (×1.5). Rebirth adds no capacity (4.6).
- Walk speed slows by 0.3% per critter in the line: ×0.85 at 50, ×0.70 at 100, and ×0.60 (the floor) at 134 or more (spec 4.3).
- Delivery: max(8, L₀ ÷ 4) critters a second (spec 4.5.2).
### 5.5 Upgrade tracks
Every level's effect and cost. Level 1 is free. A blank cell means the track has no such level.
 
| Level | Leash capacity | Leash cost | Bait luck | Bait cost | Pen slots | Pen cost | Walk speed | Speed cost | Storage limit | Storage cost |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 10 | — | ×1.00 | — | 6 | — | 20 | — | 50 | — |
| 2 | 15 | 30 | ×1.12 | 50 | 8 | 100 | 21 | 75 | 75 | 2,000 |
| 3 | 20 | 80 | ×1.24 | 150 | 10 | 300 | 22 | 250 | 100 | 20,000 |
| 4 | 30 | 200 | ×1.36 | 400 | 12 | 800 | 23 | 800 | 125 | 200,000 |
| 5 | 40 | 500 | ×1.48 | 1,000 | 14 | 2,500 | 24 | 3,000 | 150 | 1,000,000 |
| 6 | 50 | 2,000 | ×1.60 | 3,000 | 16 | 8,000 | 25 | 10,000 | 175 | 3,000,000 |
| 7 | 65 | 6,000 | ×1.72 | 10,000 | 18 | 25,000 | 26 | 40,000 | 200 | 8,000,000 |
| 8 | 80 | 15,000 | ×1.84 | 30,000 | 20 | 70,000 | 27 | 150,000 | | |
| 9 | 100 | 40,000 | ×1.96 | 80,000 | 22 | 200,000 | 28 | 500,000 | | |
| 10 | | | ×2.08 | 250,000 | 24 | 600,000 | | | | |
| 11 | | | ×2.20 | 700,000 | 26 | 1,500,000 | | | | |
| 12 | | | ×2.32 | 2,000,000 | 28 | 4,000,000 | | | | |
| 13 | | | ×2.44 | 5,000,000 | 30 | 10,000,000 | | | | |
| 14 | | | ×2.56 | 12,000,000 | | | | | | |
| 15 | | | ×2.68 | 30,000,000 | | | | | | |
| **Total** | | **63,810** | | **50,074,600** | | **16,406,700** | | **704,125** | | **12,222,000** |
 
All five tracks cost 79,471,235 coins in total. The Leash track stops at level 9 (100) since v0.5. Rebirth resets every track, Storage included (spec 4.7). Show costs with `Format.luau` (section 8), for example "250K" and "2M".
 
### 5.6 Pen and storage
| Setting | Value |
|---|---|
| Pen income | 0.0005 coins per second for each coin of value in a pen slot (4.5) |
| Pen slots | 6, up to 30 with the Pen track |
| Storage limit | 50, up to 200 with the Storage track; +100 with the Big Storage pass |
| Overflow | Legendary, Mythic, Rainbow and bound (Golden Bait) critters can go up to 50 over the limit when storage is full |
| Default auto-release filter | Rare or lower, Normal only (`UpTo = 3`, `IncludeGolden = false`). On by default; players can switch it off from launch. The filter editor comes in Update 1 |
| Never auto-released | Legendary, Mythic, Rainbow and bound critters, whatever the filter; Golden critters too under the default filter. The filter goes up to Epic at most |
| Warning dot | Storage at 90% full or more |
 
Why the default filter is what it is. In Snowy Peaks, at bait level 15 in the Far band, the spec v0.2 filter (release only Normal Commons and Uncommons) sent about 38 critters a run into storage once the pen was full: 50 slots in under 6 minutes. The current filter keeps Epic-or-better, Rainbow and Golden critters: about 8.7 Epic-or-better and Rainbow critters a run, plus about 5.1 Golden Commons to Rares (2.67% of the 192 or so Rare-or-lower critters), so about 13.8 a run. Then 50 slots last about 15 minutes and 200 slots about 60. (Releasing Golden Commons to Rares as well, as v0.3 did, stretches those to about 24 and 100 minutes.) The overflow takes only Legendary-or-better, Rainbow and bound critters, about 1.9 a run, so it still lasts about 110 minutes; a Golden Common to Rare that reaches a full storage is released (spec 4.5.6, step 4). Golden Bait critters, which are never released automatically, add only about 4 an hour. Keeping Golden critters was the developer's choice (2026-11-07). If storage-full events come too often (9.2), lower the Storage track's costs or let the default filter release Golden Commons to Rares. A player who wants more room can switch auto-release off or, from Update 1, change the filter. The simulation doesn't model storage (6.9), so these figures are worked out by hand from the odds in 4.1 and the run time in section 2.
 
### 5.7 Rebirth
| Rebirth | LP needed | Coins needed | Model median | Day |
|---|---|---|---|---|
| 1st | 750,000 | 12,500,000 | 169 min | 6 |
| 2nd | 1,700,000 | 140,000,000 | 426 min | 15 |
| 3rd | 3,700,000 | 480,000,000 | 856 min | 29 |
| 4th | 9,500,000 | 1,900,000,000 | Beyond the model | — |
| 5th | 23,000,000 | 7,700,000,000 | Beyond the model | — |
| Each later one | Previous × 2.5 | Previous × 4 | — | — |
 
- Rebirth also needs Snowy Peaks unlocked and an empty line (spec 4.7).
- Coins reset at rebirth, so the coin need works like a price.
- Each rebirth gives +15% coins and LP, added together, and cuts the throw cooldown by 0.05 s, to at least 0.5 s (4.3, 4.6). A full 100-line fills about 5 s faster per rebirth.
- Adding a new top tier changes these numbers (7.2).
### 5.8 Index
| Completed in one biome | Reward |
|---|---|
| Every species in Normal | +10% coins, permanently. The bonuses add together, with no cap (6.10) |
| Every species in Golden | A golden pen decoration |
| Every Common, Uncommon and Rare species in Rainbow | A rainbow trail (6.7) |
 
- Event biomes have their own Index tabs with the same rewards.
- No reward needs a Rainbow Epic, Legendary or Mythic. They fill their Index entries as bragging rights.
### 5.9 Daily ladder and Golden Bait Stand
| Day | Reward |
|---|---|
| 1 | Coins: 10 min of best pen income (at least 100) |
| 2 | 1 Golden Bait |
| 3 | 5 min of shield time |
| 4 | Coins: 20 min of best pen income (at least 250) |
| 5 | 2 Golden Bait |
| 6 | Coins: 30 min of best pen income (at least 500) |
| 7 | 3 Golden Bait, plus a badge the first time |
 
- A missed day pauses the ladder: the next claim gives the next reward. The streak counter goes back to 1, but no reward depends on it (spec 4.9).
- **Golden Bait Stand:** 3 at 00:00 UTC each day. The first is free; the next two cost 15 minutes of best pen income each, at least 500 coins.
- Best pen income is defined in 4.5. Work out the amount when the player claims or buys.
What these are worth, in minutes of active play, for a median player in the model (1,000 players, seed 7, measured within 5 minutes of each point):
 
| Minutes of play so far | 30 | 90 | 150 | 300 |
|---|---|---|---|---|
| Pen share of income | 8% | 14% | 27% | 35% |
| Day 1 coins (10 min) | 0.8 min | 1.4 min | 2.7 min | 3.5 min |
| Day 4 coins (20 min) | 1.7 min | 2.9 min | 5.5 min | 6.9 min |
| Day 6 coins (30 min) | 2.5 min | 4.3 min | 8.2 min | 10.4 min |
| One Stand bait (15 min) | 1.3 min | 2.2 min | 4.1 min | 5.2 min |
 
### 5.10 Events and luck boosts
| Event | Effect | Effect on progress |
|---|---|---|
| Golden Hour | Golden ×5 and Rainbow ×3, from :00 to :05 UTC every hour | In the model, averaged in |
| Critter Rush | 2 critters per throw | About doubles critters per minute while it runs |
| Server Luck (99 R$) | Luck ×2 for 15 min, for everyone in the server | While it runs: +41% coins and +20% LP at λ = 1; +20% coins and +12% LP at λ = 4.02 |
| `/luck` (admin) | Luck up to ×3 for up to 30 min | Somewhat more than Server Luck while it runs |
| Great Migration (P2) | Herds of loose Rare-or-better critters | Small |
 
Event biomes can open with a Golden Hour-style event for their first weekend to draw players in.
 
### 5.11 Prices and earnings
| Item | Price | Creator gets (70%) | DevEx value | Sales to repay £250 (about $330) | Effect in the model |
|---|---|---|---|---|---|
| 2x Coins (pass, P0) | 399 R$ | 279 R$ | $1.06 | 311 | Rebirth 1 5% sooner |
| Longer Leash (pass, P0) | 299 R$ | 209 R$ | $0.80 | 415 | Rebirth 1 19% sooner |
| VIP (pass, P1) | 249 R$ | 174 R$ | $0.66 | 499 | +10% coins; not modelled |
| Auto-Bait (pass, P2) | 499 R$ | 349 R$ | $1.33 | 249 | Not modelled (6.5) |
| Big Storage (pass, P1) | 149 R$ | 104 R$ | $0.40 | 833 | None on progress |
| More Favourites I (pass, P1) | 99 R$ | 69 R$ | $0.26 | 1,254 | Very small (6.6) |
| More Favourites II (pass, P1) | 199 R$ | 139 R$ | $0.53 | 624 | Very small (6.6) |
| Golden Bait ×3 (product) | 49 R$ | 34 R$ | $0.13 | 2,532 | About a fifth of one Snowy Peaks run's coins and a twentieth of its LP |
| Line Shield (product) | 29 R$ | 20 R$ | $0.08 | 4,278 | Protection only |
| Server Luck (product) | 99 R$ | 69 R$ | $0.26 | 1,254 | 5.10 |
 
- Roblox keeps 30% of pass and product sales. DevEx pays $0.0038 per earned Robux. Some spending by age-checked US adults earns $0.0054, which won't apply to most players of this game.
- Cashing out needs 30,000 earned Robux ($114): about 108 sales of 2x Coins.
- £250 is about $330 at roughly $1.33 to the pound in 2026. Check the current rate.
## 6. Simulation results
From `python3 tools/econ_sim.py --players 1000 --hours 22 --seed 7 --favourites`. Minutes of play. "Day" is the median's day at 30 and 60 minutes a day.
 
### 6.1 Pacing (free player, 3 favourites)
| Milestone | p10 | p50 | p90 | Reached | Day at 30 min | Day at 60 min |
|---|---|---|---|---|---|---|
| First delivery | 0.5 | 0.5 | 0.5 | 100% | 1 | 1 |
| First upgrade | 0.5 | 0.5 | 0.5 | 100% | 1 | 1 |
| First Epic | 0.5 | 2.1 | 5.0 | 100% | 1 | 1 |
| Jungle unlocked | 10.4 | 12.1 | 13.8 | 100% | 1 | 1 |
| First 100-critter line | 18.4 | 22.8 | 26.5 | 100% | 1 | 1 |
| Snowy Peaks unlocked | 53.3 | 56.5 | 60.0 | 100% | 2 | 1 |
| All upgrades maxed | 141 | 157 | 167 | 47% | 6 | 3 |
| Rebirth 1 | 163 | 169 | 180 | 100% | 6 | 3 |
| Snowy Peaks again | 207 | 214 | 227 | 100% | 8 | 4 |
| Rebirth 2 | 415 | 426 | 447 | 100% | 15 | 8 |
| Rebirth 3 | 841 | 856 | 889 | 100% | 29 | 15 |
 
53% of players rebirth before maxing every track (the last Bait and Pen levels); rebirth doesn't need maxed upgrades. Rebirth is in the game from the soft launch, as modelled (11.9).
 
### 6.2 Income and pen share
| Minutes of play | 0–15 | 15–30 | 30–60 | 60–120 | 120–240 | 240–600 |
|---|---|---|---|---|---|---|
| Coins a minute (median) | 3.3K | 33.9K | 73.4K | 616K | 526K | 1.07M |
| Pen share of coins | 3% | 5% | 9% | 14% | 26% | 36% |
 
- The jump at 60–120 is Snowy Peaks (×100). The dip at 120–240 is the first rebirth (median minute 169), after which players start again in the Meadow with their bonuses.
- Pen share stays at 38% or less in every scenario (the highest is all passes, 240–600 minutes), under the 40% target. Pen income was lowered from 0.0006 to 0.0005 in v0.5 to keep it there: shorter lines pay less per run.
### 6.3 Upgrade timeline, first cycle
The median minute at which each level is bought.
 
| Track | L2 | L3 | L4 | L5 | L6 | L7 | L8 | L9 | L10 | L11 | L12 | L13 | L14 | L15 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Leash | 1 | 1 | 2 | 4 | 8 | 13 | 16 | 20 | | | | | | |
| Bait | 1 | 2 | 3 | 7 | 13 | 15 | 19 | 26 | 42 | 60 | 69 | 89 | 132 | 157 |
| Pen | 1 | 3 | 5 | 11 | 14 | 18 | 24 | 33 | 58 | 65 | 81 | 116 | | |
| Speed | 1 | 3 | 6 | 13 | 15 | 22 | 29 | 51 | | | | | | |
| Storage | 10 | 17 | 37 | 63 | 75 | 102 | | | | | | | | |
 
- At least one upgrade every few minutes for the first half hour. The Leash track is maxed (100) at minute 20. The quiet stretch is minutes 33–42, in the Jungle, when the Bait and Pen tracks' level 10 prices arrive. Snowy Peaks income then pays for the rest.
- Storage levels arrive as storage fills: level 2 at minute 10, level 7 at minute 102. With the default filter keeping Golden critters (5.6), storage fills sooner than this timeline assumed, so watch the storage-full signal in 9.2.
### 6.4 Band choice
| Biome | Near | Mid | Far |
|---|---|---|---|
| Sunny Meadow | 100% | 0% | 0% |
| Jungle | 42% | 58% | 0% |
| Snowy Peaks | 93% | 7% | 0% |
 
**Open (11.11).** Before v0.5 the deep, risky Far band won from the Jungle on, as pillar 2 intends (spec 1.2): Snowy Peaks was 100% Far. With lines capped at 100 a run is short, so the extra walk to the Far band (270 studs each way) costs more than its luck earns, and the model stays near the gate. Comparison runs (200 players, free): cap 100 with the old 0.15% slowdown gives Snowy Peaks Near 68%, Mid 32%; with the approved 0.3% it is Near 93%, Mid 7%; the old set-up (cap 300) gave Mid 95%, Far 5% in the same short run. Pacing doesn't move, but pillar 2 doesn't hold in the model. Levers: more luck in the Mid and Far bands (`Biomes`), shorter band depths, or less slowdown. If live data shows most Snowy Peaks lines coming from the Near band, this is why.
 
### 6.5 Passes
| Scenario | Jungle | Snowy Peaks | All maxed | Rebirth 1 | Rebirth 2 | Rebirth 3 | Rebirth 1 vs free |
|---|---|---|---|---|---|---|---|
| Free | 12.1 | 56.5 | 157 | 169 | 426 | 856 | — |
| 2x Coins | 10.5 | 53.3 | 115 | 161 | 413 | 837 | 5% sooner |
| Longer Leash | 9.3 | 45.4 | 128 | 137 | 349 | 708 | 19% sooner |
| All passes, 8 favourites | 8.3 | 43.3 | 95 | 131 | 335 | 678 | 23% sooner |
 
- Longer Leash is the strongest pass. LP decides gates and rebirths, and LP per run grows with line length and the Conga multiplier (150 at ×3.5 against the free player's 100 at ×3). 2x Coins mostly speeds up upgrades, which stop mattering once they're maxed; with the shorter Leash track that happens sooner, so 2x Coins dropped from 7% to 5%.
- All passes together reach each rebirth 21–23% sooner: faster, never a skip (spec 0.3, rule 6).
- VIP, Friend Boost and Auto-Bait aren't in these runs. Try VIP with `--set extra_coin=1.1` and Friend Boost with values up to `1.3`. Before Update 2, run `--set throw_every=0.8` to see Auto-Bait's effect, since it throws at the player's cooldown (0.8 s before any rebirth).
### 6.6 Rebirth, favourites and coins
- Coins held at rebirth (median): 17.1M against a need of 12.5M, 155M against 140M, and 535M against 480M. LP and coins run out at about the same time, so neither piles up.
- Income just before each rebirth: 730K, 1.21M and 1.86M coins a minute.
- Favourites (300 players, seed 7):
| Favourites kept | Back to Snowy Peaks after rebirth 1 | Pen share in the first 10 min after it | Rebirth 2 |
|---|---|---|---|
| 0 | 47.6 min | 3% | 436 min |
| 3 (free) | 45.3 min | 40% | 425 min |
| 8 (both passes) | 44.8 min | 51% | 424 min |
 
Favourites make the pen matter straight after a rebirth: a big share of a small Meadow income. The biome cap keeps the amount small, so they save 2–3 minutes of the climb and bring rebirth 2 about 11 minutes (2.5%) sooner. Buying favourite slots never gives a big jump in income.
 
### 6.7 Index (Normal sets)
| Normal set | p10 | p50 | p90 | Done within 22 h |
|---|---|---|---|---|
| Snowy Peaks | 62 | 78 | 117 | 100% |
| Jungle | 18 | 35 | 207 | 100% |
| Sunny Meadow | 7 | 177 | 861 | 54% |
 
- The model leaves the Meadow at minute 12 and only passes back through after rebirths, so finding its Mythic is left to luck.
- A player who goes back with bait level 15 and throws in the Far band finds a Normal-variant Mythic in 0.103% of throws, at about 47 throws a minute: about 21 minutes on average. The Legendary takes about 3.
- One deliberate trip back completes all three launch sets by about 3–4 hours of play (day 7–8), inside the weeks 2–3 target. The +10% reward repays a 21-minute trip after about 3.5 hours of play.
Golden and Rainbow sets, at bait level 15 in the Far band (about 47 throws a minute):
 
| Entry | Chance per throw | Average throwing time |
|---|---|---|
| Golden Legendary | 1 in 5,080 | 1.8 h |
| Golden Mythic | 1 in 35,600 | 12.5 h |
| Rainbow Rare (one species) | 1 in 13,500 | 4.8 h |
| Rainbow Epic | 1 in 25,400 | 8.9 h |
| Rainbow Legendary | 1 in 116,000 | 41 h |
| Rainbow Mythic | 1 in 813,000 | 286 h |
 
- A full Golden set takes a median of about 9 hours of throwing in that biome (90% of players within 29): a goal of several weeks.
- A full Rainbow set takes a median of about 200 hours per biome, so almost nobody will finish one. Golden Bait barely helps: a Rainbow Mythic is 1 in about 8,100 Golden Bait.
- So the rainbow trail needs only the Common, Uncommon and Rare species (decided 2026-11-07; 11.10): a median of about 7 hours per biome (90% within 15). The rarer Rainbows stay in the Index as bragging rights.
### 6.8 Adding a new top tier
**Refit needed (v0.5).** This section was fitted to the v0.4 numbers (lines up to 300, rebirth needs 1M, 2.5M, 5M LP). LP now comes about a quarter slower and the 3rd rebirth needs 3.7M, so a 4M gate would sit above it and open later than planned. Refit the gate and the later needs with the new numbers before Fri 11 Dec (scaling by about 0.74 suggests a gate near 3M); `tools/line_cap_100.py` runs the scenarios. The v0.4 results:

Free player, 250 players, seed 11, median minutes. Tier 4 pays ×1,000 coins and ×125 LP.
 
| Setup | Rebirth 2 | Rebirth 3 | Tier 4 first unlocked | Coins held at rebirth 3 |
|---|---|---|---|---|
| Launch tiers only | 425 | 863 | — | 809M (needs 800M) |
| Tier 4 gate 2M LP | 394 | 635 | 385 | 943M (needs 800M) |
| Tier 4 gate 4M LP | 426 | 790 | 768 | 850M (needs 800M) |
| Gate 4M; rebirth LP from the 3rd: 10M, 25M, 60M | 428 | 860 | 768 | 2.12B (needs 800M) |
| As above, plus rebirth coins from the 3rd: 1.5B, 6B, 24B | 428 | 860 | 768 | 2.12B (needs 1.5B) |
 
- A gate below the second rebirth's LP need (2.5M) lets players reach Tier 4 in their second cycle and makes the third much shorter (635 minutes against 863).
- A 4M gate with the later rebirth needs raised keeps the old pace and gives third-cycle players a new top biome.
- Starting values for Tier 4: gate 4,000,000 LP. From the third rebirth, LP needs of 10M, 25M and 60M, and coin needs of 1.5B, 6B and 24B. Retune from live data before shipping (section 9). Raising needs affects live players, so follow rule 4 in 9.1.
### 6.9 What the model leaves out
| Left out | Real players will be |
|---|---|
| Imperfect play: other bands, idling, menus, chatting, wandering | Slower, especially early on |
| Gains from cutting other lines (only losses are counted) | Faster if they cut a lot; no change on average |
| Daily coin rewards; the Stand's coin price | A little faster; a little slower |
| Critter Rush, `/luck` and Server Luck while they run; VIP and Friend Boost | Faster |
| Trips back for the Index | Slower for a while, then faster (+10%) |
| Storage (beyond the Storage track's cost), event biomes, offline time | No different: storage earns nothing, event biomes pay at the player's tier, and there's no offline income |
| A cut rate other than 12% of runs | Either; check live data (9.2) |
 
Expect real median players to be slower than the model, mostly in the first sessions. If the first week's data shows the Jungle opening after 15 minutes, lower its gate first (9.2).
 
### 6.10 Large coin bonuses (why the Index bonus has no cap)
A flat coin bonus from the start stands in for many completed Index sets. 300 players, 16 hours, seed 5: `python3 tools/econ_sim.py --free-only --players 300 --hours 16 --seed 5 --set extra_coin=2`, then 3 and 6. Median minutes.
 
| Coin bonus | Jungle | Snowy Peaks | All maxed | Rebirth 1 | Rebirth 2 | Rebirth 3 | Coins held at rebirth 1 ÷ need |
|---|---|---|---|---|---|---|---|
| None | 12.0 | 57.0 | 146 | 164 | 426 | 868 | 1.3 |
| +100% (10 sets) | 10.5 | 52.0 | 102 | 152 | 408 | 816 | 6.1 |
| +200% (20 sets) | 9.7 | 49.3 | 84 | 148 | 400 | 808 | 11.6 |
| +500% (50 sets) | 9.2 | 45.3 | 63 | 142 | 391 | 796 | 27.7 |
 
- Even +500% brings rebirths only 8–13% sooner. Lead Power decides when biomes and rebirths open, and coin boosts don't add any.
- The side effect is spare coins: at +500%, players reach their first rebirth with about 28 times the coins it needs. Coins can't be traded and no leaderboard ranks them, so this is harmless.
- The bonuses add rather than multiply, so each set counts for a little less than the one before: the 20th raises income by about 3%.
- A cap would have stopped Index sets paying coins after about two months of weekly biomes, just when long-term players need reasons to stay. So the bonus has no cap.
## 7. New content under the mix
 
### 7.1 Event biomes (tier-matched)
- Open to everyone who has finished the tutorial: the gate needs 0 LP.
- Their critters always count as the owner's top tier (4.2) for value, LP and pen income. A Jungle player earns there as in the Jungle; a Snowy Peaks player as in Snowy Peaks. Their critters rise as the owner unlocks biomes and drop back after a rebirth, like every other critter.
- They aren't a tier: they never raise `topTier`, and rebirth doesn't need them.
- 6–8 species, at least one per rarity, with the same rarity weights, variants and depth bands as every biome.
- Each has its own Index tab with the same rewards. Its Normal set adds another +10% coins.
- Cutting a much weaker player in an event biome pays little, because their lines are short, so tier-matching doesn't reward picking on new players.
- Why: everyone can play the new biome on its first day, nobody's progress is skipped, and the top biome stays the best place to earn.
- Autumn Woods (Update 1) and the winter biome are the first two.
- When its event ends, an event biome's gate closes until a later event brings it back (decided 2026-11-07; 11.7). Critters already caught keep paying in pens.
### 7.2 New top tiers
- A fixed tier that becomes the new top: coins ×10 and LP ×5 over the previous top tier. Tier 4 is ×1,000 and ×125; Tier 5 would be ×10,000 and ×625.
- Gate: between two rebirths' LP needs, so it's reached partway through a cycle. Tier 4's is 4,000,000 LP.
- Raise the needs of every later rebirth until the cycle lengths match the run before the change, within about 5%. Then check that coins held at rebirth stay at 1.0–1.5 times the coin need. Test with `--set` (the script's header has an example) before shipping.
- 6–8 species, at least one per rarity, and a new Index tab.
- Rebirth still needs only Snowy Peaks.
### 7.3 Calendar
| Date | Content | Economy work |
|---|---|---|
| Fri 20 Nov (soft launch) | The 3 launch biomes, with rebirth, favourites and Friend Boost | The values in section 5 |
| Fri 27 Nov (Update 1) | Autumn Woods, a tier-matched event biome with 6–8 species including a turkey | First retune from a week of data (section 9) |
| Fri 4 Dec (day-14 review; Update 2 if go) | Mega-conga and Auto-Bait | Set Tier 4's gate and the rebirth needs from data and the model; review the Longer Leash price (11.6) |
| Fri 11 Dec | Tier 4, the first new top tier | ×1,000 coins and ×125 LP; rebirth needs raised (6.8) |
| Sun 20 Dec (day-30 review) | The winter biome, tier-matched, for the holiday event (to 4 Jan) | Review the whole economy with the day-30 numbers |
| Early January | Tier 5, if the game is scaling up | ×10,000 coins and ×625 LP; retune |
 
### 7.4 Gate slots
- The hub has 6 gates, numbered clockwise in tier order (spec 3.1): 1 Sunny Meadow, 2 Jungle, 3 Snowy Peaks, 4 Tier 4, 5 Tier 5, and 6 for event biomes in turn.
- Gate 6 hosts Autumn Woods, then the winter biome. Event biomes close when their events end (11.7), so Autumn Woods' event must end before the winter biome opens on Sun 20 Dec. Tier 5 has its own gate, so it needs no map change either.
## 8. Number scale and display
 
### 8.1 How big numbers get
| Number | By the day-30 review | Later |
|---|---|---|
| Coins held | Up to about 1B, or about 2B with Tier 4 (6.8) | About ×10 per new top tier |
| Lead Power | Up to about 10M | About ×5 per new top tier |
| One critter's value | A Rainbow Mythic in Snowy Peaks: 10M | 100M at Tier 4 |
| Upgrade prices | Up to 30M | Unchanged unless retuned |
 
### 8.2 Rules for code
1. Coins and LP are plain Luau numbers (64-bit floats). Whole numbers are exact up to 2^53, about 9 × 10^15: room for about six more top tiers. Past that, only the last digits blur.
2. Coins and LP can hold fractions, from multipliers and per-second pen income. Keep the fractions; show values rounded down.
3. Check prices with `coins >= price`. Never compare coins with `==`.
4. Never format coins with `string.format("%d", …)`: Luau raises an error for a number with a fraction. Use `Format.luau`.
5. Use attributes (spec 9.4) or `NumberValue` for display copies, not `IntValue`.
6. ProfileStore saves these numbers as they are; nothing extra is needed.
### 8.3 `Format.luau`
- Below 1,000: the whole number, rounded down ("999").
- From 1,000: three significant figures with trailing zeros dropped, plus a suffix: K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, Dc, each 1,000 times the last. For example, 1,234 → "1.23K", 12,345 → "12.3K", 250,000 → "250K", 2,000,000 → "2M", 2,500,000,000 → "2.5B".
- Balances round down and prices round up, so a balance never looks bigger than it is and a price never looks smaller. Whether a player can afford something is always decided on the exact numbers.
- Past Dc (10^33), use scientific notation, such as "1.2e36".
- Odds: up to three significant figures ("0.0769%"). Never show a real chance as 0%: write "less than 0.001%".
- Rates: show income per minute, not per second. Early pens earn under 1 coin a second, which would read as 0.
## 9. Tuning after launch
 
### 9.1 Rules
1. Retune on Fridays with the weekly update. Change one or two levers at a time, so the next week's data shows what each did.
2. Re-run the model with the new numbers before shipping, and update sections 5 and 6.
3. Never take back what players have: critters, levels, coins, LP, Golden Bait or stored shield time.
4. When raising a gate or a rebirth need, a player who already meets the old value keeps it. Check on their first join after the update and save a flag.
5. Lowering costs or needs is always safe. Say so in the update notes; players like it.
### 9.2 Signals and levers
The analytics come from spec 9.9.
 
| Signal | Healthy | Too low or too slow | Too high or too fast |
|---|---|---|---|
| Jungle unlock, median minutes (funnel step 9) | 10–15 | Lower the Jungle gate (1,000) | Raise it |
| Snowy Peaks unlock, median minutes | 45–90 | Lower its gate (50,000) | Raise it |
| First rebirth, median minutes | 150–210 (day 5–7) | Lower the first rebirth's LP need | Raise it |
| Pen share of coin sources, after the first hour | 10–40% | Raise the pen rate (0.0005) | Lower it |
| Coins held at rebirth ÷ coin need (median) | 1.0–1.5 | Below 1.0, coins hold rebirth back: lower the coin need | Coins pile up: raise the coin need |
| Minute each upgrade level is bought, against 6.3 | Within ±50% | Lower that track's costs from there on | Raise them |
| Storage-full events and automatic releases of Epics, per hour played | A few an hour from the second hour | — | Lower the Storage track's costs, or let the default filter release Golden Commons to Rares (5.6) |
| Players switching auto-release off | A minority | — | If most switch it off, the filter releases critters they want: consider keeping Rares by default |
| Cuts per run and the share of a line lost | About 12% of runs, a quarter of the line | — | Real lines lose more than the model: lengthen the cut cooldowns before touching the economy |
| Average session (the go/kill check, spec 13) | 12 min or more | Make the first 15 minutes richer: cheaper early levels or a lower Jungle gate | — |
| Players buying Stand bait with coins | Most players who visit the Stand buy at least one | Lower the price to 10 min of best pen income | — |
| Cuts made by a player whose top tier is above the biome's | Rare | — | Stronger players are picking on new ones: turn on the tier rule (`CutTierGap` 1, or 0 for only their top biome and event biomes; spec 4.4.2). It's off at launch so quiet servers still have someone to cut |
 
## 10. Config mapping
| Config module | Values | Section |
|---|---|---|
| `Rarities` | Weights (Normal and Golden Bait tables), coin values, LP, colours, the luck cap | 5.1, 4.1 |
| `Variants` | Chances, value multipliers, Golden Bait and Golden Hour multipliers, caps | 5.2 |
| `Biomes` | Id, tier or tier-matched, gate LP, coin and LP multipliers, depth-band luck | 5.3 |
| `Critters` | Species: id, biome, rarity and size class (spec 5.4) | — |
| `Line` | Conga table, the 150 cap (`MaxCapacity`), the Longer Leash multiplier, walk-speed constants and the 0.3 s lead for speed changes, banners | 5.4, 4.6 |
| `Delivery` | Delivery rate; banking on leave | 5.4, 4.4 |
| `Upgrades` | Effect and cost of every level of the five tracks | 5.5 |
| `Income` | Pen rate (0.0005); 2x Coins, VIP and Friend Boost multipliers | 5.6, 4.3 |
| `Pen` | Starting slots, storage limits, overflow, the default auto-release setting and filter (`Enabled = true`, `UpTo = 3`, `IncludeGolden = false`), the warning threshold | 5.6 |
| `Rebirth` (new) | LP and coin needs, growth after the table, bonuses, `CooldownCut = 0.05` | 5.7 |
| `Index` (new) | Bonus per Normal set (no cap), cosmetic rewards | 5.8 |
| `Daily` | Ladder, best-pen-income minutes and floors, Stand stock and price | 5.9 |
| `Events` | Golden Hour, Critter Rush and `/luck` limits | 5.10 |
| `Monetisation` | Pass and product ids, prices and effects; the 60-minute Server Luck queue | 5.11 |
| `Shields` | Shield lengths, the 60-minute limit on daily shield time and the 30-minute limit on an active shield (spec 4.11) | — |
| `Cutting` | `CutTierGap`: unset (off) at launch; `BigStealAt = 25`, `ServerToastAt = 50` | 9.2; spec 4.4.2, 4.4.5 |
| `Throw` | `Cooldown = 0.8`, `CooldownMin = 0.5`; the rate limit uses each player's own cooldown | 4.6; spec 4.1 |
 
## 11. Decisions
Every decision here has been settled by the developer; the spec's decisions log (spec 16) records each one. Add new open decisions here as they come up.
 
| # | Decision | Outcome | Where |
|---|---|---|---|
| 11.1 | The default auto-release filter and the storage overflow | Decided (developer, 2026-11-07): release Rare or lower, Normal only, keeping Golden critters (changed from Normal or Golden); never bound critters; players can switch auto-release off from launch (changed); Legendary-or-better, Rainbow and bound critters overflow | 5.6; spec 4.5.6 |
| 11.2 | Rebirth needs coins as well as LP | Decided: yes (developer, 2026-11-07). Otherwise coins pile up with nothing to buy | 5.7 |
| 11.3 | Index coin bonuses | Decided: no cap (developer, 2026-11-06) | 5.8, 6.10 |
| 11.4 | Daily coin rewards and Stand prices use best pen income | Decided: yes (developer, 2026-11-07). Closes the empty-pen exploit | 4.5, 5.9 |
| 11.5 | Storage track costs: 2,000 up to 8,000,000 | Decided: accepted as a starting point; retune from the storage-full signal (developer, 2026-11-07) | 5.5, 9.2 |
| 11.6 | Longer Leash is the strongest pass (19% sooner) but costs less than 2x Coins (5% sooner since v0.5; 7% before) | Decided: keep 299 R$ for the soft launch (developer, 2026-11-07). If it far outsells 2x Coins, try 349–399 R$ at the day-14 review | 6.5 |
| 11.7 | Event biomes after their event: close them or keep them open | Decided: close them when the event ends and bring them back for later events, so their Index sets stay completable (developer, 2026-11-07). Their critters keep paying in pens | 7.1, 7.4 |
| 11.8 | Tier 4's date and gate | Decided: pencilled in for Fri 11 Dec, with a 4M LP gate and the raised rebirth needs in 6.8; confirm at the day-14 review (developer, 2026-11-07). The gate and needs need a refit for v0.5 (6.8) | 7.2, 7.3 |
| 11.9 | Rebirth at the soft launch or in Update 1. Without it, engaged players (an hour a day) max every upgrade around day 3 with nothing left to buy, right in the D2–7 window | Decided: ship rebirth, with the 3 free favourite slots, at the soft launch (developer, 2026-11-07) | 1.2, 6.1; spec 4.7 |
| 11.10 | Lines capped at 100, 150 with Longer Leash (×1.5); rebirth cuts the throw cooldown (−0.05 s, at least 0.5 s) instead of adding +10 capacity; refitted rebirth needs, Conga steps and pen income | Decided (developer, 2026-11-08): approved as drafted in `docs/drafts/line-cap-100.md`, with one change: walk speed slows 0.3% a critter (not 0.15%), floor ×0.60. Longer Leash stays 299 R$. That change moved no pacing target by more than 3.1% | 4.6, 5.4–5.7, 6 |
| 11.11 | The Far band no longer wins with lines capped at 100 (6.4) | **Open**: pacing is fine, but pillar 2 (deep, risky runs pay best) doesn't hold in the model. Pick a lever (band luck, band depth or slowdown) before the soft launch, or accept it and watch band choice live | 6.4; spec 1.2 |
| 11.10 | A full Rainbow set takes about 200 hours of throwing per biome | Decided: the rainbow trail needs only the Common, Uncommon and Rare species, about 7 hours (developer, 2026-11-07) | 6.7; spec 4.8 |
 
## 12. Changelog
- 0.1 (2026-11-06): first version, tuned with `/tools/econ_sim.py` for spec v0.3.
- 0.2 (2026-11-06): review pass. Index coin bonuses have no cap (6.10). Bound critters are never auto-released and can overflow storage (5.6). Golden and Rainbow set times (6.7). Open decisions 11.9 (rebirth at the soft launch) and 11.10 (the Rainbow reward). Rates are shown per minute (8.3). A signal for stronger players picking on new ones (9.2). The simulation gains `extra_coin` and drops the Index cap; its results are unchanged.
- 0.3 (2026-11-07): the developer's decisions. Rebirth and favourites ship at the soft launch, as modelled (1.2, 6.1, 7.3, 11.9). The rainbow trail needs only the Common to Rare species (5.8, 6.7, 11.10). A missed day pauses the daily ladder (5.9). The tier rule for cutting is a Config lever, off at launch (9.2, 10). No numbers changed, so the simulation wasn't re-run.
- 0.4 (2026-11-07): every open decision settled (section 11, now "Decisions"). The default auto-release filter keeps Golden critters (`IncludeGolden = false`), and players can switch auto-release off from launch. Storage now fills in about 15 minutes for 50 slots in Snowy Peaks instead of 24, and 60 for 200 instead of 100, worked out by hand because the simulation doesn't model storage (5.6). New signals for storage and the auto-release switch (9.2). Event biomes close after their events (7.1, 7.4). The Longer Leash review is on the day-14 calendar (7.3). No simulated numbers changed, so the simulation wasn't re-run.
- 0.5 (2026-11-08): lines capped at 100, 150 with Longer Leash (11.10). The Leash track stops at level 9; rebirth cuts the throw cooldown by 0.05 s (at least 0.5 s) instead of adding capacity; Conga steps 1, 10, 25, 50, 75, 100, 150; walk speed slows 0.3% a critter; pen income 0.0005; rebirth needs refitted (750K LP and 12.5M coins for the first). Re-run at 1,000 players: rebirths at 169, 426 and 856 min. New open item 11.11: the Far band no longer wins (6.4). Tier 4's numbers need a refit (6.8).
## Sources
- `/docs/spec.md` v0.7, and the research handoff (`claude/roblox-viral-game-research-handoff-2026-11-06.md` in the project).
- Roblox Creator Hub, "Roblox Developer Exchange Program": https://create.roblox.com/docs/production/monetization/developer-exchange
- Roblox Help, "Developer Exchange – Help and Information Page": https://en.help.roblox.com/hc/en-us/articles/13061189551124-Developer-Exchange-Help-and-Information-Page
 