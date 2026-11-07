---
title: "Conga Critters: game spec (MVP)"
repo_path: /docs/spec.md
spec_version: 0.7
date: 2026-11-07
status: "Ready to build. C01-M1 starts Monday 2026-11-09."
concept: "C01 in 'Roblox viral game: research handoff' (2026-11-06)"
companion_docs:
  - "/docs/economy.md (v0.4): every tuning number, and the simulation behind them"
  - "/CHANGELOG.md"
developer_decisions:
  - "2026-11-06: line cuts take the back half only"
  - "2026-11-06: keep the 2-week build; soft launch Friday 2026-11-20"
  - "2026-11-06: Manage Pen menu, storage, pinning, favourites and Release (4.5.6–4.5.9)"
  - "2026-11-06: no trading in the MVP; reconsider it at the day-30 review"
  - "2026-11-06: new biomes mix tier-matched event biomes with a new top tier every second or third week"
  - "2026-11-06: Lead Power mostly rewards effort: LP doubles with each rarity step; coins keep the jackpots"
  - "2026-11-06: Index coin bonuses have no cap"
  - "2026-11-07: rebirth, 3 favourite slots, Invite, Friend Boost, private servers and custom Quick Words ship at the soft launch"
  - "2026-11-07: a missed day pauses the daily ladder; the rainbow trail needs only Common to Rare species; server-wide steal toasts name only the cutter"
  - "2026-11-07: an optional tier rule for cutting is built but off at launch"
  - "2026-11-07: the Manage Pen menu introduces itself when storage first holds a critter, never before 5 minutes of play"
  - "2026-11-07: every 'Developer to confirm' decision settled (16). Changed: an auto-release on/off switch ships at launch, and the default filter keeps Golden critters (releases Rare or lower, Normal only)"
---
 
# Conga Critters: game spec (MVP)
 
## 0. Read this first
 
### 0.1 What this document is
- The source of truth for what to build for the Conga Critters MVP, and how to check it. The research handoff explains why.
- Written for coding agents (Claude Code or Codex driving Roblox Studio through its built-in MCP server) and for the developer.
- Precedence: the hard rules (0.3), then this spec, then `/docs/economy.md` for numbers, then agent judgement.
- Priority labels:
  - **P0**: needed for the soft launch on Friday 2026-11-20.
  - **P1**: in the soft launch if time allows; otherwise in Update 1 on Friday 2026-11-27.
  - **P2**: later.
- Every number in sections 2–6 is tunable and lives in `src/shared/Config`. Never hard-code one. `/docs/economy.md` sets the values and shows the simulation behind them; it wins if the two documents ever differ.
### 0.2 Working rules for agents
1. Work on one milestone per session (C01-M1 to C01-M9, 10.2). Before coding, read the sections it names and its acceptance checks.
2. Code lives on disk and Rojo syncs it into Studio. Use the MCP tools to playtest, inspect, run Luau and build map content. Never edit a Rojo-managed script with MCP `multi_edit`: Rojo overwrites it.
3. All content and numbers come from `src/shared/Config`. Adding a critter, biome, bait level, product or event must need only data, not code.
4. The server decides; the client asks and draws (9.3).
5. Finish each milestone by running its acceptance checks in a playtest. Then commit (for example `C01-M3: follower chain`) and add a line to `/CHANGELOG.md`.
6. Your training data may predate Server Authority and the Input Action System. Read the current docs with the MCP `skill` and `http_get` tools before using them.
7. Where this spec is silent, pick the simplest option that fits the pillars (1.2), log it in section 16 and flag it in the commit message. Ask the developer instead if the choice touches money, fairness to young players or Roblox policy.
### 0.3 Hard rules
Rules 1–7 come from the handoff (its section 0.5); rule 8 is new.
1. No unlicensed IP. Use real animals and original designs only: no brands, memes, named characters or copyrighted music (including the song "Conga"). Never prompt AI tools for named characters or brands.
2. Follow Roblox policy. Paid random items show their odds before purchase and respect PolicyService (6.4). Content stays at the lowest maturity level: no gore, and nothing that suggests harm to animals.
3. Metadata matches the gameplay. Never lead with giveaways or Robux. Never publish near-copies of our own or others' games.
4. Cuts, deliveries, currency and purchases are decided by the server. ProcessReceipt must be safe to run twice.
5. Clips and thumbnails show real gameplay only.
6. Be fair to young players: no pay-to-win, caps on paid power, and nothing a player paid for can be stolen.
7. Keep ads and promotion to a few hundred GBP.
8. No trading between players in the MVP. It may be reconsidered at the day-30 review (13, 14), on the conditions in 6.4.
### 0.4 Changes from the handoff's C01 card
| Change | Why |
|---|---|
| Cuts can only take the back half of a line | Developer's decision: no single cut takes more than half |
| Critters from Golden Bait can't be cut away ("bound") | Paid outcomes never change hands; fairness |
| No coin packs | Keeps coin purchases outside Roblox's paid-random-item rules (6.4) |
| VIP gives no Golden Bait | A daily paid random item would need the same gating |
| Golden Bait ×3 and Server Luck gated with PolicyService | Required by Roblox policy |
| Update 1 lands in Thanksgiving week; mega-conga is Update 2 (Friday 2026-12-04, if go) | Fixes the handoff's calendar clash (developer's decision) |
| Server Authority on from the first milestone | Movement anti-cheat for a game built on stealing (9.1) |
| A Manage Pen menu with storage, pinning, favourites and Release | Developer's design: players keep and show off the critters they like, not only the most valuable (4.5.6–4.5.9) |
| A critter's value is capped by the highest biome the player has unlocked | Stops favourites, steals and grabs from skipping progression (4.5.3) |
| Lead Power comes from deliveries, not a separate training activity | Keeps one verb; gates follow how much a player has delivered (economy.md 1.1) |
| Rebirth, Friend Boost, Invite and private servers are in the soft launch, with a ninth milestone (C01-M9) | Developer's decision. Without rebirth, players on an hour a day would max every upgrade by about day 3 with nothing left to buy. Friends and invites feed the co-play signal (economy.md 11.9; handoff 7.3, 8.2) |
 
## 1. The game on one page
 
### 1.1 Summary
| Item | Value |
|---|---|
| Hook | "Throw bait. Grow the longest animal conga line. Don't let anyone cut it." |
| 5-second pitch | A 200-critter conga line snakes across the map while a rival sprints at its tail |
| Genre | Collect → earn → upgrade simulator with a social steal; a fast follow on Throw Food For Animals and Steal An Egg (handoff F2, 6.2) |
| Audience | Ages 9–15. English at launch; Portuguese (Brazil), Indonesian and Spanish later |
| Platforms | Phones first (the performance floor), then PC, tablet and console |
| Server size | 6 players (5–8 possible). Each owns a pen in a safe central hub |
| Session target | Average session of at least 12 min by 7 days after launch |
 
### 1.2 Pillars
Use these to settle anything this spec doesn't cover.
1. **One verb in 10 seconds.** Throw, and a critter joins you. No reading needed.
2. **The line is the score, the risk and the show.** Longer lines pay more, move slower and are worth cutting.
3. **Cuts are thrilling, never crushing.** A cut takes at most half a line, never anything paid for, and never in the hub.
### 1.3 Core loop
| Timescale | Loop |
|---|---|
| 30 seconds | Walk into a biome and throw bait. A critter runs in, eats and hops onto the end of your line. Walk it home, where it pops into your pen for coins. |
| 10 minutes | Better bait brings rarer critters. A longer leash means longer lines and a bigger Conga multiplier. Deliveries raise Lead Power, which opens the next biome. Dodge cuts, or make them. |
| Days | Fill the Index (every species in Normal, Golden and Rainbow) and arrange your pen and storage around the critters you like. Claim the daily reward and grab the Golden Bait restock. Rebirth for permanent boosts. Come back for the weekly biome and the Saturday event. |
 
### 1.4 Not in the MVP
Mega-conga co-op (Update 2), offline earnings, combat, a custom chat system (Roblox's chat and custom Quick Words cover it; 4.12), coin packs (6.4) and trading (to be reconsidered at the day-30 review; 6.4, 14).
 
## 2. First session
 
### 2.1 Timeline
Measured with the onboarding funnel (9.9). Everything is guided without text.
 
| Time | What happens | Guidance |
|---|---|---|
| 0–3 s | New players spawn on a pad in front of the Meadow gate, facing it; returning players spawn at their pen | A glowing trail to a bait circle just inside the Meadow |
| 3–10 s | Enter the Meadow and throw; the first critter joins | THROW pulses on phones; a cursor hint on PC |
| 10–30 s | Throws 2–10. Throw 3 always gives an Uncommon and throw 6 a Rare | Rarity colour burst and sound |
| By about 30 s | The line reaches the starting leash of 10. THROW greys out and the ×1.25 Conga badge appears | Home arrow |
| 30–75 s | Walk home: first delivery and a coin fountain | The coin counter flies up |
| 75–90 s | The Upgrades button pulses. The first leash upgrade costs less than the first delivery pays. Buying it ends the tutorial | Pulse and arrow |
| About 2–3 min | The first delivery after the tutorial that releases critters: the spare ones wave and hop home, and the Manage Pen button pulses. Once only (4.5.8) | Animation and pulse, no text |
| 2–15 min | The Jungle gate shows Lead Power progress; aim to unlock it at 10–15 min | Meter on the gate |
| About 13 min (simulation median), never before 5 min | The first delivery that leaves a critter in storage: the Manage Pen menu opens by itself, this once only, pointing out pinning, storage and Release (4.5.8) | Highlight arrows |
 
### 2.2 Rules
- **Beginner Shield:** for a new player's first 5 minutes of playtime, or until they unlock the Jungle if that comes first, nobody can cut their line and they can't cut anyone.
- Fixed rolls happen only on free throws during the tutorial, never on anything paid. The odds panel opens after the tutorial.
- The tutorial ends when the player buys their first upgrade. Tutorial progress is saved; returning players skip it.
- Later pacing targets are in 5.6.
## 3. World and map
 
### 3.1 Layout
- **Hub (safe):** a central plaza with 8 pen plots (the first 6 are used, matching the server size) and 6 biome gates around its edge.
- **Gates:** numbered 1–6 clockwise seen from above, in tier order: 1 Sunny Meadow, 2 Jungle, 3 Snowy Peaks, then three "coming soon" gates: 4 for Tier 4, 5 for Tier 5, and 6 for event biomes in turn (Autumn Woods, then the winter biome; economy.md 7.4). Gate 6 is directly counter-clockwise of the Meadow, on your left as you face the Meadow from the spawn. Each `ComingSoonGate` zone has `Slot` (its gate number) and `PlannedUse` (`Tier4`, `Tier5` or `EventBiomes`). Each gate, open or coming soon, is an archway about 60 studs wide and 50 tall (never under 30 wide), so lines flow through and one player can't block it.
- **Biomes:** cones about 400 studs deep: each is a trapezoid that starts at its gate's width and widens steadily to about 300 studs at the far end, with straight angled walls. Each has three depth bands (Near, Mid and Far) at about 0–130, 130–270 and 270–400 studs past the gate. The farther out you throw, the better your luck and the longer the risky walk home. Neighbouring biomes must not overlap. Burrows are spread evenly through each biome.
- **First spawn:** a pad centred in front of the Meadow gate, about 40 studs from it, with the spawn facing straight into the gate (economy.md 2), so the first critter joins well within 10 s (2.1).
- **Distances:** any pen to any gate in 15 s or less at base speed.
- **Walls:** every edge of the playable area has a visible wall at least `Config.Camera.CameraMaxZoomDistance` + 10 studs high (the greybox uses + 20 to allow for a jump), so no camera angle sees over it. Biome walls are in the biome's colour. Invisible walls at least 60 studs taller than the visible ones sit just outside them, so nobody can leave even from on top of a wall. The camera limit is set on `StarterPlayer` at server boot; if it goes up, raise the walls to match.
- **Safety:** no hazards and no way to die. Turn off the reset button with `StarterGui:SetCore("ResetButtonCallback", false)`, from a LocalScript, retrying until it succeeds.
- **Locked gates and other players' pens:** no physical barrier. Show a see-through lock effect. If a player walks in without access, the server moves them back out and shows what they need (for example "🔒 1,000 LP"). This works with or without Server Authority (9.1).
### 3.2 Zone tags
- Gameplay areas are invisible, non-colliding parts tagged with CollectionService inside `Workspace.Map.Zones`.
- Set that model's `ModelStreamingMode` to `Persistent` so every client always has it, even with streaming on.
- Test whether a point is inside a zone with `Zones.Contains(part, point)` in `Zones.luau`: pure maths, not physics queries. It moves the point into the part's object space (`CFrame:PointToObjectSpace`) and checks depth (Z) and height (Y) against `Size`. Box zones then check X against `Size`. Trapezoid zones (`Biome` and `DepthBand`) have `NearWidth` and `FarWidth` attributes: their `CFrame` and `Size` are the bounding box, the `LookVector` points from the near end (local +Z face) to the far end (local −Z face), and abs(X) must be at most half the width at that depth, interpolated between the two.
| Tag | Attributes | Meaning |
|---|---|---|
| `SafeZone` | none | No cuts happen inside: the hub, gates and pens |
| `Biome` | `BiomeId`, `NearWidth`, `FarWidth` | Throwing and cutting allowed; one trapezoid per biome |
| `DepthBand` | `BiomeId`, `Band` (1–3), `NearWidth`, `FarWidth` | Luck band inside a biome; a trapezoid |
| `Gate` | `BiomeId` | Gate area, also a SafeZone; where access is checked |
| `ComingSoonGate` | `Slot` (gate number), `PlannedUse` | Reserved for a future biome; also a SafeZone |
| `Pen` | `PenIndex` (1–8) | A pen plot: owner only; entering starts a delivery |
| `PenDeliveryPoint` | `PenIndex` | Where delivered critters pop |
| `Burrow` | `BiomeId` | Where critters run in from |
| `FirstSpawn` | none | New-player spawn pad by the Meadow gate |
 
## 4. Core systems
 
### 4.1 Throwing bait (C01-M2)
- **Controls** (Input Action System):
  - Phone: a big THROW button. It throws along the camera's forward direction to full range.
  - PC: left click. It throws at the mouse point, limited to range.
  - Console: right trigger. It throws along the camera's forward direction.
- **Numbers:** range 45 studs; cooldown 0.8 s; one critter per throw (events can raise this).
- **A throw needs:** the player inside a biome they have unlocked; a landing point in the same biome; and line length plus critters on their way below the leash capacity.
- **Bait:** Normal bait is free and unlimited. Golden Bait uses up one Golden Bait (4.2). The toggle appears once the player owns some.
- **Client:** draws the arc and the bait at once, then sends `ThrowBait`. If the server rejects the throw, the bait vanishes in a small puff.
- **Server:** checks the throw (9.4), rolls the critter (4.2) and tells every client with `CritterSpawned`.
- **Leash full:** THROW greys out and a home arrow appears. In the hub THROW is hidden.
### 4.2 Critter rolls and odds (C01-M1, C01-M2)
- The server rolls, in order: rarity; then species, with an equal chance among that biome's species of that rarity; then variant.
- **Luck (λ)** = bait luck × depth-band luck × Server Luck × event luck, capped at 10. Luck multiplies the weight of every rarity above the lowest one in the table; then the weights are normalised.
- **Normal bait table:** Common 70, Uncommon 22, Rare 6, Epic 1.6, Legendary 0.35, Mythic 0.05.
- **Golden Bait table:** Rare 70, Epic 22, Legendary 7, Mythic 1.
- Critters from Golden Bait are **bound**: a cut can never take them (4.4.3).
- Critters from Golden Bait, or rolled while Server Luck is active, are also marked **paid**. Nothing uses this mark in the MVP; it's saved so paid critters can be kept out of trading if trading is ever added (6.4).
- **Variants:** Rainbow 0.1% and Golden 2%; otherwise Normal. Golden Bait multiplies both chances by 5. Golden Hour multiplies Golden by 5 and Rainbow by 3. Caps: Golden 25%, Rainbow 2%.
- One shared module, `Odds.luau`, does all of this maths, so the odds shown always equal the odds rolled, including every active boost (6.4).
Worked rarity odds for checks (Normal bait):
 
| Rarity | λ = 1 | λ = 2 (for example, Server Luck) |
|---|---|---|
| Common | 70% | 53.85% |
| Uncommon | 22% | 33.85% |
| Rare | 6% | 9.23% |
| Epic | 1.6% | 2.46% |
| Legendary | 0.35% | 0.54% |
| Mythic | 0.05% | 0.077% |
 
**Arrival**
- The critter starts at the nearest Burrow within 30 studs of the bait; if there is none, 14–20 studs away in a random direction.
- Clients show it run in (1.2 s), eat (0.6 s) and hop to the end of the line.
- The server adds it to the line 1.8 s after the bait lands. If the owner has left, or the line is full by then, the critter is dropped.
- The first time a species or variant joins a player's line, the Index records it (4.8) and a "NEW!" toast plays.
### 4.3 The conga line (C01-M3)
- **State (server):** an ordered list of entries (species, variant, bound), a count of critters on their way, and the capacity.
- **Capacity:** the leash level (5.5), plus 10 per rebirth, times 1.5 with the Longer Leash pass, rounded down. Never above **300**, the performance cap.
- **Following:** followers walk the leader's exact path, breadcrumb by breadcrumb, rather than a straight line. If the leader jumps, the line hops at the same spot.
- **Spacing by size class:** S 2.2 studs, M 3.0 studs, L 4.0 studs.
- **Walk speed:** (20 + Speed upgrades) × max(0.6, 1 − 0.0015 × length). A line of 100 gives ×0.85, 200 gives ×0.70, and 267 or more gives ×0.60. The server sets `Humanoid.WalkSpeed`.
- **Conga multiplier:** applied to delivery coins and Lead Power. It is set by the line's length when delivery starts:
| Length at least | 1 | 10 | 25 | 50 | 100 | 150 | 200 | 300 |
|---|---|---|---|---|---|---|---|---|
| Multiplier | ×1 | ×1.25 | ×1.5 | ×2 | ×3 | ×3.5 | ×4 | ×5 |
 
- The HUD shows length against capacity, and the current multiplier. Reaching 100, 200 and 300 fires a banner with confetti (a clip moment, 7.4).
- **If the character dies** (it shouldn't; see 3.1): bound critters are banked as if the player had left (4.5.5), and the rest scatter as loose critters (4.4.4).
- **If the player leaves:** see 4.5.5.
### 4.4 Line cutting: back half only (C01-M5)
 
#### 4.4.1 The rule
- Walk through the back half of a rival's line and you cut it there. Everything behind the cut follows you.
- Positions count from the leader; position 1 is right behind them. In a line of length L, positions ⌈L/2⌉ + 1 to L can be cut, and positions 1 to ⌈L/2⌉ never can. So no cut takes more than half.
- Examples: in a line of 10, positions 6–10 are at risk. In a line of 300, positions 151–300.
#### 4.4.2 When a cut happens
The server checks ten times a second. A cut needs all of these:
 
| Check | Rule |
|---|---|
| Victim's line | At least 10 long |
| Place | The follower being cut is in a Biome zone and not in a SafeZone |
| Contact | The cutter's movement since the last check, treated as a capsule of radius 2.75 studs, touches a follower that can be cut. Vertical gap at most 4 studs |
| Moving | The cutter's horizontal speed is at least 6 studs/s, so standing in the way doesn't count |
| Room | The cutter has at least 1 free leash slot |
| Shields | Neither player is shielded; shielded players can't cut either |
| Cooldowns | Cutter: 10 s since their last cut. Victim: 15 s since they were last cut. Same pair: 60 s |
| Clean | The cutter has no anti-cheat flag in the last 10 s (9.7) |
| Not self | Nobody can cut their own line |
 
- Friends can cut each other (`FriendCuts = true`).
- **Optional tier rule** (`CutTierGap` in `Config/Cutting`; off at launch). When set to N, nobody can cut in a biome more than N tiers below their own top tier; event biomes count as every tier. With 0, players cut only in their own top biome or an event biome. Leave it off while servers are quiet, or there may be nobody to cut. Turn it on if analytics show stronger players picking on new ones (economy.md 9.2).
- If several followers qualify, cut at the one nearest the cutter.
- If two cutters hit one victim in the same check, the first wins; the victim's immunity blocks the second.
#### 4.4.3 What moves
1. The segment is positions k to L, where k is the cut position.
2. Bound critters in the segment stay with the victim and move to the end of the victim's remaining line.
3. Of the rest, the first n = min(segment count, cutter's free slots) join the cutter directly behind them, in order, ahead of the cutter's existing line. Free slots = capacity − line length − critters on their way.
4. Anything left over becomes loose critters (4.4.4).
5. The victim keeps positions 1 to k − 1, in order.
#### 4.4.4 Loose critters
- They stay where they landed and hop in place for 8 s, then run off for good.
- Anyone with a free slot grabs one by walking within 4 studs of it, and it joins the end of their line. That includes the victim: immunity doesn't stop grabbing.
- The server decides who grabbed first.
- Loose critters are also used when a line scatters after a death (4.3) and in the admin Stampede (4.10).
#### 4.4.5 Feedback
- **The cut:** a scissors burst and a "snip" sound at the cut point, then critters hop happily over to the cutter. Only the line is cut: never show harm to animals.
- **Cutter:** a "+42!" banner. At 50 or more, "BIG STEAL!" with confetti. At 100 or more, a toast to the whole server that names only the cutter, for example "Ana made a 150-critter steal!" The victim is never named to the server.
- **Victim:** a short screen shake, a toast naming the cutter, and a 15 s immunity bubble. A Revenge marker on the cutter for 30 s is P1.
- **Stats:** biggest steal, cuts made, times cut.
#### 4.4.6 Why this is fair enough for 9–15-year-olds
- The back-half rule caps a single loss at 50%.
- Immunity stops chain cuts, and the pair cooldown stops anyone picking on one player.
- The hub, gates and pens are safe, and nothing in a pen or in storage can be cut, so banked progress can't be touched.
- The Beginner Shield covers the first minutes.
- Bound Golden Bait critters can never be taken.
- Server-wide steal toasts name only the cutter, so nobody is shown up in front of everyone.
- If stronger players start picking on new ones, the optional tier rule (4.4.2) can stop cuts in lower biomes.
### 4.5 Delivery, pens and storage (C01-M4; the menu in C01-M7)
 
#### 4.5.1 Pens
- Each player gets a free pen plot on joining.
- Only the owner may enter; the server moves anyone else out (3.1).
- A sign shows the owner's display name, pen income per minute and best line.
- Slots: 6 at the start, up to 30 (5.5). Critters in slots wander around the pen. Clients draw this; it's cosmetic. In the Manage Pen menu, pinned critters show a pin on their slot (4.5.8).
#### 4.5.2 Delivery
- Starts when the owner walks into their own pen with a line.
- The server removes critters from the front at max(8, L₀ ÷ 4) per second, where L₀ is the length when delivery started. Any line finishes within about 4 s. Delivery pauses if the owner steps out.
- The Conga multiplier is fixed when delivery starts.
- For each critter delivered:
  - coins increase by its value × the Conga multiplier × coin boosts;
  - Lead Power increases by its LP × the Conga multiplier × LP boosts;
  - then it goes to the pen or to storage, or is released, by the placement rules in 4.5.6. It has already paid out, whatever happens to it next.
- **Feedback:** a coin pop for each critter at the delivery point, a running total, and "NEW BEST LINE!" when L₀ beats the player's record. When the delivery ends, a short summary shows the coins and LP earned, and how many critters went to the pen, went to storage or were released (and why).
#### 4.5.3 Critter value and Lead Power
- Value = rarity value × biome coin multiplier × variant multiplier.
- LP = rarity LP × biome LP multiplier.
- **Biome cap:** for both biome multipliers, use whichever is lower: the critter's own biome or the highest biome the player has unlocked. So a Snowy Peaks critter that a Meadow-only player stole, grabbed or kept as a favourite pays, earns and gives LP like a Meadow critter of the same rarity and variant. It rises to full value once the player unlocks Snowy Peaks. The cap applies to every critter, in delivery payouts, LP and pen income.
- **Tiers:** each biome has a tier (Sunny Meadow 1, Jungle 2, Snowy Peaks 3; later top tiers 4 and up), and the cap compares tiers. Event biomes, such as Autumn Woods, are **tier-matched**: their critters always count as the owner's highest unlocked tier, so they pay at each player's own level (economy.md 4.2, 7.1).
- The info card shows a capped critter's current value and its full value (4.5.8).
- The tables are in 5.1–5.3.
#### 4.5.4 Pen income
- Each critter in a pen slot earns its value (after the biome cap, 4.5.3) × 0.0006 coins per second, times coin boosts. Critters in storage earn nothing.
- Income is paid every second while the owner is in the server. There is no offline income in the MVP.
- Show pen income per minute everywhere: the sign, the info card and the menu. Early pens earn under 1 coin a second, which would show as 0.
- Coin boosts multiply together: the 2x Coins pass, VIP (P1), Friend Boost (4.12), the rebirth bonus (4.7), Index bonuses (+10% per completed biome, added together, with no cap) and events. LP boosts are the rebirth bonus only.
- For an active player, pen income stays below about 40% of total income, so playing beats idling (33% at most in the simulation; economy.md 6.2).
#### 4.5.5 Leaving mid-run
- On leaving or disconnecting, the line is banked at base value: no Conga multiplier and no Lead Power (coin boosts still apply). Banked critters then follow the placement rules in 4.5.6. Critters still on their way are dropped.
- Leaving is never better than delivering, but a crash doesn't wipe out a run.
#### 4.5.6 Where delivered critters go
After a delivered or banked critter has paid out, it goes through these steps in order. **Protected** means pinned (pen only) or a favourite (4.5.9): no automatic rule ever moves or releases a protected critter.
1. **Auto-place** (setting, on by default). If the pen has an empty slot, the critter takes it. Otherwise, if it's worth more (after the biome cap) than the least valuable unprotected critter in the pen, it takes that critter's slot, and the critter it replaced carries on to step 2 instead. Auto-place only compares the pen with critters being delivered; it never takes critters out of storage. With auto-place off, delivered critters go straight to step 2.
2. **Auto-release** (setting, on by default). If the critter matches the release filter, it's released. The default filter is Rare or lower, Normal variant only, so Golden critters are kept. Legendary, Mythic, Rainbow and bound critters are never auto-released. With auto-release off, critters go straight to step 3.
3. **Storage.** Otherwise it goes to storage, if there's room.
4. **Storage full.** It's released, unless it's Legendary or better, Rainbow or bound. Those go into storage anyway, up to 50 over the limit (4.5.7); past that they're released too. This step applies whether auto-release is on or off.
- Nothing already in storage is ever released automatically.
- At the soft launch, auto-release runs with the default filter, and players can turn it on or off in the Manage Pen menu. The filter editor comes in Update 1 (4.5.8).
#### 4.5.7 Storage
- Holds critters that earn nothing but are safe: they can't be cut, and no automatic rule releases them.
- **Limit:** 50 to start. The Storage upgrade (5.5) raises it to 200, and the Big Storage pass (6.1, P1) adds 100.
- **Over the limit:** only the overflow in 4.5.6 (Legendary or better, Rainbow and bound critters) can push storage over its limit, by at most 50. While storage is over its limit, nothing else can go in, including manual moves, until the player makes room. Swaps that take one critter out for each one put in (Move to pen with a swap, Sort with storage) still work.
- Bound critters (from Golden Bait) are stored, pinned and favourited like any other critter.
- The Manage Pen button shows a warning dot when storage is at least 90% full.
#### 4.5.8 Manage Pen menu (C01-M7)
- **Opening:** a Manage Pen button appears while the player is in their own pen. It pulses after a delivery that put anything into storage.
- **Introduction:** the menu never opens by itself, except once, to introduce pinning, storage and Release. That happens at the end of the first delivery that ends with at least one critter in storage, once the player has at least 5 minutes of playtime (about 13 minutes in the simulation). If the player has already opened the menu themselves, it never opens by itself; the highlight arrows show the next time they open it instead.
- **First release:** the first time a delivery after the tutorial releases critters, the spare ones wave and hop home, with no text, and the Manage Pen button pulses. This plays once.
- **Why so late:** Roblox measures first-play bounce over a player's first three minutes (the handoff's ranking signals; section 13), and until storage holds something the menu has little to show. A pop-up there would interrupt the core loop, need reading and cover a phone screen.
- **Layout:** the pen's slots (pinned ones marked), the storage list and the settings.
- **Info card** (tap a critter): name, rarity, variant, home biome, current value and income per minute, its full value if the biome cap applies (for example "Full value when you unlock Snowy Peaks"), and marks for bound and favourite critters.
- **Actions on the card:**
  - **Move to pen.** If the pen is full, the player picks which unprotected critter to swap out to storage. If every slot is protected, this isn't available.
  - **Move to storage.** Not available while storage is at or over its limit. A pinned critter loses its pin when it moves to storage.
  - **Pin** or **Unpin** (pen only).
  - **Favourite** or **Unfavourite** (4.5.9).
  - **Release.** Gone for good, with no coins, because the delivery already paid. It asks for confirmation for Rare or better, Golden, Rainbow and bound critters. A favourite has to be unfavourited first.
- **Sort with storage** (button): fills the pen's unprotected slots with the most valuable critters from the pen and storage together, moving any critters it displaces into storage. It never releases anything, never touches protected critters, and is the only way storage critters are sorted into the pen automatically.
- **Settings:** auto-place on or off, and auto-release on or off (soft launch). The auto-release filter (Update 1): release up to Common, Uncommon, Rare or Epic, and whether Golden critters count.
- **Sorting and filters** (Update 1): sort by value, rarity, biome or newest; filter by biome, rarity or variant. **Release all shown** releases every unprotected critter in storage that the filter shows, after a confirmation that counts them by rarity and points out any Golden Bait critters. At the soft launch, both lists are sorted by current value, highest first.
- Changes apply at once, even while a delivery is still arriving.
#### 4.5.9 Favourites (C01-M7)
- **Slots:** 3 free at the soft launch. The More Favourites I and II passes (6.1, P1) add 2 and 3, for 8 at most.
- The player marks favourites on the info card. Favourites can be in the pen or in storage. They're protected (4.5.6), and Sort with storage leaves them where they are.
- They're the only critters that survive a rebirth (4.7).
- They follow the biome cap like every critter (4.5.3). Straight after a rebirth they earn at the level of the biomes the player has unlocked again, not at their old full value.
### 4.6 Upgrades, Lead Power and gates (C01-M4)
- **Coins** buy five permanent upgrade tracks (5.5). Rebirth resets them.
- **Lead Power (LP)** comes only from deliveries and is never spent. Biome gates check it.
- **Gates:** Meadow needs 0 LP, Jungle 1,000 LP and Snowy Peaks 50,000 LP. Event biomes need 0 LP once the tutorial is done. A locked gate shows progress, such as "LP 120 / 1,000".
- **Unlocking a biome:** a fanfare, an arrow to the gate, and the biome's Index tab lights up. Any critters the player owns from that biome rise to full value (4.5.3).
### 4.7 Rebirth (C01-M9)
- **Where:** a Rebirth button in the Upgrades screen opens the Rebirth screen. Until the player qualifies it shows their progress towards each need; once they do, the button glows.
- **Needs:** Snowy Peaks unlocked; the LP and coins in economy.md 5.7 (1,000,000 LP and 20,000,000 coins for the first rebirth, rising with each one); and an empty line. Coins reset anyway, so the coin need works like a price.
- **Resets:** coins, upgrades (Storage included), LP, and every critter in the pen and storage except favourites.
- **Keeps:** favourites (4.5.9), the Index and its bonuses, passes, Golden Bait, stored shield time, cosmetics, the daily ladder and streak, stats and settings.
- **Favourites afterwards:** they go back into the pen as far as its 6 slots allow, and any others go to storage. The biome cap (4.5.3) scales their value down until the player unlocks their biomes again.
- **Gives, per rebirth (permanent and additive):** +15% coins and LP; +10 leash capacity, still within the 300 cap; and a crown shown above the player and on their pen sign (bronze, then silver, then gold).
- A confirmation screen lists exactly what resets, which favourites stay and what the player gets. It points out any Golden Bait critters that will go, so the player can favourite them first.
### 4.8 Index (C01-M7)
- At launch: 30 species × 3 variants (Normal, Golden and Rainbow) = 90 entries.
- An entry unlocks the first time that species and variant joins the player's line, whether thrown for, stolen or grabbed.
- **Screen:** one tab per biome, silhouettes for unknown entries, rarity colours, and dots on new entries.
- **Rewards** are granted automatically and survive rebirth:
| Completed in one biome | Reward |
|---|---|
| Every species in Normal | +10% coins permanently, plus a badge. These bonuses add together, with no cap |
| Every species in Golden | A golden pen decoration |
| Every Common, Uncommon and Rare species in Rainbow | A rainbow trail cosmetic (about 7 hours of throwing per biome; economy.md 6.7) |
 
- Event biomes and later top tiers get their own Index tabs, with the same rewards.
- Rainbow Epics, Legendaries and Mythics still fill their Index entries, but no reward needs them: a full Rainbow set takes about 200 hours, so they're bragging rights.
### 4.9 Daily reward and Golden Bait Stand (C01-M7)
**Daily reward**
- Claim once per UTC day, on a seven-day ladder. After day 7 the ladder starts again at day 1.
- Missing a day pauses the ladder: the next claim gives the next reward, so nobody loses progress for missing a day. The streak counter (days in a row, shown on the panel) goes back to 1, but no reward depends on it.
- The daily panel always shows the next reward, as a reason to come back.
| Day | Reward |
|---|---|
| 1 | Coins: 10 min of best pen income (at least 100) |
| 2 | 1 Golden Bait |
| 3 | 5 min of shield time |
| 4 | Coins: 20 min of best pen income (at least 250) |
| 5 | 2 Golden Bait |
| 6 | Coins: 30 min of best pen income (at least 500) |
| 7 | 3 Golden Bait, plus a badge the first time |
 
**Best pen income** is what the pen would earn per minute if it held the player's most valuable critters from pen and storage together (as many as it has slots), with coin boosts (economy.md 4.5). Moving critters can't lower it; only releasing them can.
 
**Golden Bait Stand** (in the hub)
- Restocks 3 Golden Bait at 00:00 UTC every day.
- The first is free. The next two cost coins: 15 min of best pen income each, at least 500.
- Shows a countdown to the next restock.
### 4.10 Events and admin tools (C01-M8)
- Events are data in `Config/Events`: id, name, duration, effects and schedule. Effects can change luck, Golden and Rainbow chances, critters per throw and coins, or add special spawns.
- **Clock events** start from UTC time (`os.time()`), so every server agrees without messaging.
- **Admin events** reach every server through MessagingService. The active event is also stored in MemoryStore with an expiry, so servers that start mid-event join in.
| Event | Effect | When | Priority |
|---|---|---|---|
| Golden Hour | Golden ×5, Rainbow ×3 (caps in 4.2) | Every hour from :00 to :05 UTC | P0 |
| Critter Rush | 2 critters per throw | Admin, 30 minutes unless the command gives a length; part of the Saturday event | P0 |
| Great Migration | Herds of rare loose critters cross each biome | About once a month | P2 |
 
**Admin commands**
- Whitelisted UserIds only. Typed in chat on the admin's client, sent with `AdminCommand`, and checked by the server every time. Rate-limited.
  - `/event start <id> [minutes]` and `/event stop`
  - `/stampede <biome> [count, at most 60]`: a burst of loose Rare-or-better critters in that biome on every server
  - `/luck <multiplier, at most 3> <minutes, at most 30>`
  - `/announce <key>`: preset, translated messages only. There's no free text, so nothing needs filtering.
- **Weekly admin event:** Saturdays at 20:00 UTC (3 pm US Eastern, noon US Pacific, 8 pm UK).
### 4.11 Shields
| Shield | Length | Source | Priority |
|---|---|---|---|
| Beginner | First 5 min of playtime, or until the Jungle unlocks | Automatic | P0 |
| Daily | 5 min | Daily reward, day 3 | P0 |
| Line Shield | 10 min | 29 Robux (6.2) | P0 |
 
- While shielded, your line can't be cut, and you can't cut anyone.
- Shield time is stored. Daily rewards stop adding time once 60 min are stored, but bought time always adds in full, so nothing paid for is wasted. Each tap of the shield button starts or extends a shield by up to 10 min from storage, with at most 30 min active at once. An active shield can't be paused.
- A bubble around the leader and a HUD timer show the shield is on.
### 4.12 Social (C01-M9)
| Feature | Priority | Details |
|---|---|---|
| Friend Boost | P0 | +10% coins for each Roblox friend in the server, up to +30% (`Config/Income`). Coins only, not LP. Check friendships with `Player:IsFriendsWith` (in a pcall) when players join, and cache the result |
| Invite button | P0 | The client calls `SocialService:PromptGameInvite`. Hide the button if `SocialService:CanSendGameInviteAsync` returns false |
| Private servers | P0 | A Creator Hub setting, no code. Turn them on at a low price so friend groups can play together (12) |
| Custom Quick Words | P1 | A Creator Hub setting, no code (below) |
| Revenge marker | P1 | See 4.4.5 |
| Best Line board | P1 | A global top 50 in the hub (OrderedDataStore, refreshed every 5 minutes) |
| Rewards for social actions | — | Joining the group, likes, favourites: check Roblox's current rules before adding any |
 
**Custom Quick Words** are Roblox's built-in preset phrases. Players of every age can use them to coordinate play.
- Set them up in Creator Hub under Configure > Chat > Quick Words: up to 3 categories of 3–10 phrases, each under 25 characters, written in English. Roblox translates them automatically.
- Phrases must coordinate play, not chat socially, and can't be open-ended questions. Roblox reviews them on publishing (Draft, Pending, Not approved or Published). Revise and publish again if any are rejected.
- Custom categories replace Roblox's default ones; General stays. Compare with the defaults first; you can switch back at any time.
- Submit them early because of the review (10.1). They don't block the launch.
- Starting set, to edit freely:
  - **Go:** "Follow me!", "Head home!", "Go to the Jungle!", "Go to Snowy Peaks!", "Throw from far out!"
  - **Watch out:** "Watch your tail!", "Cutter behind you!", "Shield up!", "Get to the hub!"
  - **Look:** "Loose critters here!", "Golden critter here!", "Rainbow critter here!"
### 4.13 Settings (P1)
Music, sound effects, and Low Detail (which halves the render caps in 9.5).
 
## 5. Content and numbers
These are the tuned values from `/docs/economy.md`, which explains them, holds the per-level tables and wins if the two documents ever differ.
 
### 5.1 Rarities
| Rarity | Weight | Coin value | LP | Colour |
|---|---|---|---|---|
| Common | 70 | 5 | 1 | White |
| Uncommon | 22 | 15 | 2 | Green |
| Rare | 6 | 50 | 4 | Blue |
| Epic | 1.6 | 200 | 8 | Purple |
| Legendary | 0.35 | 1,000 | 16 | Gold |
| Mythic | 0.05 | 10,000 | 32 | Pink |
 
Always pair a rarity colour with an icon or label, so colour isn't the only cue.
 
### 5.2 Variants
| Variant | Chance | Value | Look |
|---|---|---|---|
| Normal | 97.9% | ×1 | The base mesh |
| Golden | 2% | ×3 | Gold tint and sparkles |
| Rainbow | 0.1% | ×10 | Cycling colours; a sparkle trail near the camera |
 
### 5.3 Biomes at launch
| Id | Name | Tier | LP to enter | Coin multiplier | LP multiplier |
|---|---|---|---|---|---|
| `meadow` | Sunny Meadow | 1 | 0 | ×1 | ×1 |
| `jungle` | Jungle | 2 | 1,000 | ×10 | ×5 |
| `peaks` | Snowy Peaks | 3 | 50,000 | ×100 | ×25 |
 
- Depth-band luck in every biome: Near ×1, Mid ×1.25, Far ×1.5.
- Every biome needs at least one species of each rarity. The config validator (9.10) stops the server starting otherwise.
- New biomes have 6–8 species and come in two kinds (economy.md 7). **Event biomes** (from Update 1, such as Autumn Woods) are tier-matched (4.5.3) and open to everyone after the tutorial. **New top tiers**, every second or third week, pay ×10 coins and ×5 LP over the previous top tier (Tier 4: ×1,000 and ×125).
### 5.4 Critter roster
- Ids look like `meadow_duckling`. Size class is in brackets.
- Swap species to match the animal pack bought on day 6 or 7, but keep the number per rarity. Mythics are the pack's own meshes with special effects.
| Rarity | Sunny Meadow | Jungle | Snowy Peaks |
|---|---|---|---|
| Common | Duckling (S), Bunny (S), Chick (S) | Tree Frog (S), Parrot (S), Gecko (S) | Penguin Chick (S), Snow Hare (S), Seal Pup (S) |
| Uncommon | Piglet (S), Lamb (M) | Toucan (S), Monkey (M) | Arctic Fox (M), Puffin (S) |
| Rare | Hedgehog (S), Fox (M) | Capybara (M), Sloth (M) | Reindeer (L), Snowy Owl (S) |
| Epic | Calf (L) | Tapir (L) | Yak (L) |
| Legendary | Alpaca (L) | Jaguar (L) | Snow Leopard (L) |
| Mythic | Starlight Stag (L) | Emperor Capybara (M) | Aurora Bear (L) |
 
- Saves store species by id; the network sends them by index (9.4).
- The species list in Config only ever grows. Never reorder or delete entries; mark retired species instead.
### 5.5 Upgrade tracks
| Track | Effect by level | Levels | Costs (every level in economy.md 5.5) |
|---|---|---|---|
| Leash | Capacity 10, 15, 20, 30, 40, 50, 65, 80, 100, 125, 150, 175, 200 | 13 | 30 for level 2, up to 5,000,000 for level 13 |
| Bait | Luck × (1 + 0.12 × (n − 1)); ×2.68 at level 15 | 15 | 50 up to 30,000,000 |
| Pen | 6 + 2 × (n − 1) slots; 30 at level 13 | 13 | 100 up to 10,000,000 |
| Speed | Walk speed 20 + (n − 1); 28 at level 9 | 9 | 75 up to 500,000 |
| Storage | Storage limit 50 + 25 × (n − 1); 200 at level 7 | 7 | 2,000 up to 8,000,000 |
 
Costs are set level by level, not by a formula, because income jumps ×10 at each biome. Show them rounded (`Format.luau`, economy.md 8.3).
 
### 5.6 Pacing targets (median player)
| Milestone | Target |
|---|---|
| First critter | Within 10 s |
| First delivery | Within 75 s |
| First upgrade | Within 90 s |
| First Rare | Within 1 min (fixed tutorial roll) |
| First Epic | Within 8 min |
| Jungle unlocked | 10–15 min |
| First 100-critter line | Second or third session |
| Snowy Peaks unlocked | Day 2–3 |
| First rebirth | Day 5–7 |
| Second rebirth | About day 14 |
| Third rebirth | About day 30 |
| Every Normal species in the 3 launch biomes | Weeks 2–3 |
 
Days assume 30 minutes of play a day. economy.md 1.2 compares each target with the simulation.
 
## 6. Monetisation (C01-M6)
 
### 6.1 Game passes
| Pass | Price | Effect | Priority |
|---|---|---|---|
| 2x Coins | 399 R$ | Doubles coins from deliveries and pen income | P0 |
| Longer Leash | 299 R$ | Leash capacity × 1.5, still capped at 300 | P0 |
| VIP | 249 R$ | +10% coins, a VIP tag and a gold pen fence. No Golden Bait (6.4) | P1 |
| Auto-Bait | 499 R$ | Throws Normal bait automatically, at the normal cooldown, while in a biome with room in the line | P2 (Update 2) |
| Big Storage | 149 R$ | +100 storage (4.5.7) | P1 |
| More Favourites I | 99 R$ | +2 favourite slots (4.5.9) | P1 |
| More Favourites II | 199 R$ | +3 favourite slots (4.5.9) | P1 |
 
### 6.2 Developer products
| Product | Price | Effect | Priority |
|---|---|---|---|
| Golden Bait ×3 | 49 R$ | +3 Golden Bait. A **paid random item** | P0 |
| Line Shield | 29 R$ | +10 min of stored shield time | P0 |
| Server Luck | 99 R$ | Luck ×2 for everyone in the server for 15 min. Buying again adds time, never a bigger multiplier. At most 60 min can be queued, so the button is unavailable while more than 45 min are queued. A toast thanks the buyer. A **paid odds booster** | P0 |
| Cosmetic hats | 49–149 R$ | Sold directly, never random (Great Migration and holiday) | P2 |
 
### 6.3 Fairness rules
- Nothing paid for can be stolen: Golden Bait critters are bound (4.2).
- Shields block cutting both ways.
- No pass or product changes walk speed, cut range or cooldowns.
- Longer Leash and rebirth bonuses never take capacity past 300.
- Favourite slots from passes stop at +5, and favourites follow the biome cap (4.5.3), so buying slots never gives a big income jump after a rebirth.
- All the speed passes together make progress about a quarter faster, never a skip (economy.md 6.5).
### 6.4 Paid random items: compliance
Roblox's policy (page updated 2026-10-15) covers random items bought with Robux, directly or through paid in-game currency, and paid items that improve the odds of random outcomes.
1. **Odds before purchase.** The Golden Bait ×3 and Server Luck store entries each have an odds panel driven by `Odds.luau`. While any boost is active, every odds display shows the true, boosted odds. Luck applies to Golden Bait too, so its panel shows the odds for each depth band at the player's bait level (economy.md 4.1).
2. **PolicyService.** On join, call `PolicyService:GetPolicyInfoForPlayerAsync`, with pcall and retries; if it fails, treat the player as restricted. If `ArePaidRandomItemsRestricted` is true, replace both buttons with "Sorry, this item is unavailable for users in your region" and never prompt those purchases. Free and coin-bought Golden Bait still work. If a receipt arrives anyway, still grant it.
3. **Questionnaire.** Declare paid random items in the Maturity & Compliance Questionnaire. Roblox makes a game that declares them, but doesn't use `ArePaidRandomItemsRestricted`, unavailable to UK users under 18.
4. **No coin packs.** Coins can't be bought with Robux, so things bought with coins (upgrades, Stand bait) stay outside the policy. Selling coins later would turn every coin-bought random item and luck upgrade into a paid one that needs the same gating. Decide on that before adding coin packs.
5. **No trading in the MVP**, so the trading restriction (`IsPaidItemTradingAllowed`) needs no work yet. Cuts aren't trades, and bound critters mean paid outcomes never change hands. If trading is added after the day-30 review: start with trades between Roblox friends only; exclude every critter marked paid (4.2), which covers all bound ones; turn trading off completely for players where `IsPaidItemTradingAllowed` is false; and add scam protection (offers lock once either side accepts, a confirm countdown that restarts after any change, and a trade history).
6. Re-read the policy page and the Community Standards before launch (section 12). Check in particular that a pass multiplying coins (2x Coins) doesn't make coins count as paid currency. If it did, the Stand's coin-bought Golden Bait and the Bait upgrade would fall under the policy too.
### 6.5 Purchase handling
**ProcessReceipt** (server):
1. If the player isn't in the server, or their profile hasn't loaded, return `NotProcessedYet`.
2. If `receipt.PurchaseId` is already in `Purchases.Processed`, return `PurchaseGranted`.
3. Grant the product through its handler, add the PurchaseId to `Purchases.Processed` (keeping the latest 100) and save.
4. Return `PurchaseGranted` only after that save succeeds. Otherwise return `NotProcessedYet`.
**Passes:** check ownership on join with `MarketplaceService:UserOwnsGamePassAsync` (pcall, retry, cache the result). Grant at once on `PromptGamePassPurchaseFinished`.
 
All pass and product ids, display prices and handler keys live in `Config/Monetisation`.
 
## 7. UI, feel and clip moments
 
### 7.1 HUD
Designed for phones first: buttons within thumb reach, icons rather than words, and short numbers with up to three significant figures (1.23K, 3.4M; economy.md 8.3).
- **Top:** coins, and an LP meter towards the next gate.
- **Line widget:** for example "🐾 47/100", with the multiplier badge ("×2").
- **Bottom right:** THROW (phones), the bait toggle (Normal or Golden ×N) and the shield button with stored time.
- **Left:** Upgrades, Index, Store, Daily (with a dot when there's something to claim) and Invite (4.12).
- **In your pen:** the Manage Pen button (4.5.8). It pulses after a delivery that stored critters and shows a warning dot when storage is at least 90% full.
- **Banners:** event countdowns, and Server Luck with the buyer's name.
- **Toasts:** cuts, steals, new species and multiplier steps.
- **Arrows:** home when the leash is full; to a gate when a biome unlocks.
### 7.2 Screens
- Upgrades: the five tracks, each with its cost and next effect.
- Index.
- Manage Pen (4.5.8): pen slots, storage, the info card, Sort with storage and settings. If a long storage list stutters on phones, draw only the rows on screen.
- Store: passes and products, with an odds button on each random item.
- Odds: live, including active boosts.
- Daily ladder.
- Rebirth (4.7), opened from the Upgrades screen: progress towards each need, then what resets, what stays and what the player gets.
Build UI in plain Luau or from templates; no framework is needed. Iterate from `screen_capture` shots at phone and PC sizes.
 
### 7.3 Feel
Required effects and sounds: a throw whoosh; a bait plop; dust as a critter runs in; munching; a pop as it joins; a banner at each multiplier step; the snip; "BIG STEAL!"; coin pops on delivery; rarity bursts for Rare and above (bigger for Legendary and Mythic); and a fanfare when a gate unlocks.
 
### 7.4 Clip moments
Design these to be filmed; marketing uses real gameplay only.
1. **The gate steal:** a long line's tail is cut just as its head reaches the safe hub.
2. **Line milestones:** banners and confetti at 100, 200 and 300.
3. **BIG STEAL:** the banner and the server-wide toast.
4. **A Mythic reveal,** with its burst and sound.
5. **A 300-critter delivery** and its coin fountain.
6. **Stampede** chaos.
Film with Roblox's developer Freecam (Shift+P, for accounts with edit access).
 
### 7.5 Localisation
- Put every string in a LocalizationTable, with English as the source. Bake no text into images.
- Turn on automatic translation.
- Get native speakers to review Portuguese (Brazil), Indonesian and Spanish before marketing in those regions (P2).
## 8. Art and audio
- **Style:** chunky, bright, cosy low-poly. Silhouettes must read at 100 studs on a phone.
- **Critter meshes:** one MeshPart each; at most 1,000 triangles (aim for 300–600); pivot at the feet; facing −Z (LookVector); textures at most 512 px, shared where possible. No rig: movement is a procedural hop and waddle (9.5).
- **Variants and Mythics:** use tint, material and particles on the same MeshId, so the renderer can batch them.
- **Critter icons:** one 2D icon per species for the Index and the Manage Pen menu, rendered once from the meshes; show variants with a tint or frame. Avoid live 3D previews in long lists.
- **Animal pack** (buy on day 6 or 7): its licence must allow uploading to Roblox and use in a monetised game. It needs at least 30 species in one consistent style.
- **Environment:** Creator Store assets or Studio generation (`generate_mesh`, `generate_material`), with simple materials and a distinct palette for each biome.
- **Icon and thumbnail key art:** hand-picked or commissioned. AI tools such as Voyager only make variants from real gameplay captures, and a person picks the final one.
- **Audio:** licensed tracks from the Creator Store only. A bouncy loop for each biome, plus the sound effects in 7.3.
## 9. Technical design
 
### 9.1 Stack and Server Authority
- Roblox Studio with its built-in MCP server; Claude Code or Codex as the client. To connect: in Studio, open Assistant, then … > Manage MCP Servers, turn on "Enable Studio as MCP server", and use quick connect.
- Rojo (or Argon) and Git. Luau `--!strict` in every new module. Selene and StyLua are recommended.
- ProfileStore (a session-locking DataStore wrapper) copied into `src/server/Packages`.
- **Server Authority is on from M1:** set `Workspace.AuthorityMode` to `Server`.
  - In full release since 2026-07-09. For games with default avatars it gives engine-level movement anti-cheat: the server rejects invalid client movement.
  - It also turns on `StreamingEnabled`, deferred signals, `NextGenerationReplication`, the Input Action System for player scripts, and fixed simulation. Write code for those from the start: `WaitForChild` and nil checks for streamed instances, and no reliance on signals firing immediately.
  - Attributes are limited under Server Authority (64 per instance, with limited string sizes). Use attributes only for small values; line contents travel over remotes.
- **Decision at the end of M3:** if Server Authority hurts movement feel, phone performance or the build, set `AuthorityMode` back to Automatic and log it in section 16. The game must work correctly either way. The server checks in 9.7 stay in both cases.
- The map lives in the place file, not in Git, so save a dated `.rbxl` backup after each milestone.
### 9.2 Repo layout
```
/docs/spec.md                  this file
/docs/economy.md               tuning values and the simulation behind them
/tools/econ_sim.py             economy simulation (Python 3 and numpy; Rojo ignores it)
/CHANGELOG.md
default.project.json           Rojo
src/
  shared/                      -> ReplicatedStorage.Shared
    Config/                    Rarities, Variants, Critters, Biomes, Upgrades, Line, Cutting,
                               Delivery, Pen, Income, Rebirth, Index, Events, Daily, Shields,
                               Monetisation, Tutorial, Admin, Debug, Throw, Camera
    Types.luau
    Net.luau                   remote names, payload types, rate limits
    Odds.luau                  roll and display maths (server rolls, clients display)
    Path.luau                  breadcrumb path maths (server and clients)
    Zones.luau                 point-in-zone tests
    Format.luau                number formatting
  server/                      -> ServerScriptService.Server
    init.server.luau           boot: require services, Init() all, then Start() all
    Packages/ProfileStore
    Services/                  see the table below
  client/                      -> StarterPlayer.StarterPlayerScripts.Client
    init.client.luau
    Controllers/               see the table below
```
Assets go in `ReplicatedStorage.Assets` (`Critters/<speciesId>`, `Fx`, `Sounds`). Code names follow Roblox's US spelling (`Color`, `Favorite`); prose is in UK English.
 
| Server service | Job |
|---|---|
| `DataService` | ProfileStore load and save, schema, migrations |
| `PlayerStateService` | Session state: line, critters on their way, cooldowns, shields |
| `MapService` | Zones, pen assignment, gate and pen access |
| `ThrowService` | `ThrowBait` checks, rolls, `CritterSpawned` |
| `LineService` | Line state, capacity, walk speed, server paths, `LineSync` |
| `CutService` | Cut detection and resolution, loose critters |
| `DeliveryService` | Delivery and payouts; hands each critter to `PenService` |
| `PenService` | Pen and storage contents, placement rules (4.5.6), pins, favourites, Release, Release all shown, Sort with storage, `PenSync` and `PenDisplay` |
| `IncomeService` | Pen income every second |
| `UpgradeService` | Upgrades and gate unlocks |
| `IndexService` | Discoveries, rewards, badges |
| `DailyService` | Daily ladder and the Golden Bait Stand |
| `ShieldService` | Beginner, stored and active shields |
| `MonetisationService` | Passes, products, ProcessReceipt, PolicyService |
| `EventService` | Clock events, MemoryStore, MessagingService |
| `AdminService` | Admin and debug commands |
| `AntiCheatService` | Movement checks, rate limits, flags |
| `TelemetryService` | Wraps Roblox AnalyticsService; never lets an analytics error break gameplay |
| `RebirthService` | Rebirth checks, resets and bonuses (4.7) |
| `FriendsService` | Friend Boost (4.12) |
 
| Client controller | Job |
|---|---|
| `InputController` | Throw actions (Input Action System) |
| `LineRenderer` | Followers: paths, pools, level of detail, `BulkMoveTo` |
| `CritterFx` | Run-ins, eating, joins, loose critters, snips, delivery pops |
| `PenRenderer` | Critters wandering in pens, from `PenDisplay` |
| `HudController`, `UpgradesUI`, `IndexUI`, `PenUI`, `StoreUI`, `OddsUI`, `DailyUI`, `RebirthUI` | Interface, including the Invite button |
| `ToastController`, `TutorialController`, `EventUI`, `SoundController`, `ZoneController` | Toasts, tutorial, events, sound, zone-aware buttons |
 
### 9.3 Who decides what
| Thing | Decided by | Client's role |
|---|---|---|
| Coins, LP, upgrades, Index, inventory | Server (saved profile) | Display |
| Throw result and odds | Server | Ask, and draw the arc |
| Line contents and order | Server | Draw |
| Follower positions | Each client, cosmetic and path-based; the server keeps its own paths for cuts | Draw |
| Cuts, loose-critter grabs, deliveries | Server, from server-side positions | Draw effects |
| Pen and storage contents, pins, favourites, releases | Server (saved profile) | Ask through the Manage Pen menu, and display |
| Character movement | Engine (Server Authority) plus server checks (9.7) | Move |
| Purchases | MarketplaceService, then the server | Prompt only |
| Events | Server (clock and MemoryStore) | Display |
 
### 9.4 Remotes and state
| Remote | Direction | Payload | Server checks | Rate limit |
|---|---|---|---|---|
| `ThrowBait` | Client → server (event) | `target: Vector3, golden: boolean` | Finite values; player in an unlocked biome; target within range + 6 studs of the server-side position; target in the same biome; room in the line; Golden Bait owned if `golden` | 1 per (cooldown − 0.1 s) |
| `BuyUpgrade` | Client → server (function) | `track: string` | Known track; enough coins; not maxed | 5 per s |
| `ClaimDaily` | Client → server (function) | none | Not claimed today | 1 per s |
| `BuyStandBait` | Client → server (function) | none | Stock left; enough coins | 2 per s |
| `ActivateShield` | Client → server (event) | none | Stored time above 0 | 1 per s |
| `Rebirth` | Client → server (function) | none | Requirements met; empty line | 1 per s |
| `RequestLineSync` | Client → server (event) | none | None | 1 per 2 s |
| `PenAction` | Client → server (function) | `action` (`toPen`, `toStorage`, `pin`, `unpin`, `favourite`, `unfavourite` or `release`), `uid: number`, optional `swapUid: number` | The critter is the player's own; storage and favourite limits; protected critters can't be swapped out; favourites can't be released | 10 per s |
| `SortWithStorage` | Client → server (function) | none | None beyond ownership | 1 per s |
| `ReleaseMany` (Update 1) | Client → server (function) | `uids: {number}`, at most 400 | Every critter is the player's own, in storage and unprotected | 1 per s |
| `SetPenSettings` | Client → server (function) | `autoPlace: boolean, autoRelease: boolean`; from Update 1 also `releaseUpTo: number, includeGolden: boolean` | Known values; release threshold Epic at most | 2 per s |
| `RequestPenSync` | Client → server (event) | none | None | 1 per 2 s |
| `AdminCommand` | Client → server (event) | `cmd: string, args: {string}` | UserId whitelist; argument ranges | 2 per s |
| `CritterSpawned` | Server → all | `id, owner, species, variant, bound, from, to, joinAt` | — | — |
| `LineSync` | Server → all | `userId, seq, op` (`snapshot`, `append`, `removeFront` or `clear`), plus `entries` or `count` | — | — |
| `LineFx` | Server → all | `kind` (`cut`, `bigSteal`, `deliver` or `tier`) and details | — | — |
| `Loose` | Server → all | `op` (`spawn`, `grab` or `expire`), ids, species, positions | — | — |
| `PenSync` | Server → owner | Every pen and storage record (uids and marks) and the pen settings | — | — |
| `PenDisplay` | Server → all | `userId, slots`: one packed integer per pen slot, 0 for empty | — | — |
| `Toast` | Server → one player | `key, args` | — | — |
 
- **Critters on the wire:** one integer each, packed as species index × 8 + variant × 2 + bound (species indices start at 1, so 0 can mean an empty slot; variant 0 Normal, 1 Golden, 2 Rainbow; bound 0 or 1). Lines and `PenDisplay` both use this.
- **`LineSync`:** a joining client gets snapshots of every line. Throws send `append`, deliveries `removeFront`, and a cut sends fresh snapshots of both lines. Each line has its own sequence number. If a client sees a gap, it sends `RequestLineSync`.
- **`PenSync` and `PenDisplay`** go out after any change to a player's pen or storage, at most twice a second per player. `PenSync` also answers `RequestPenSync` when the menu opens.
- **Display state in attributes** (small values only):
  - On each Player: `Coins`, `LP`, `LineLen`, `LineCap`, `GoldenBait`, `ShieldEndsAt`, `ShieldStored`, `PenIndex`.
  - On ReplicatedStorage: `EventId`, `EventEndsAt`, `ServerLuckEndsAt`, `ServerLuckBuyer`.
- **Rules:** never trust numbers from a client; drop bad payloads silently and count them; never call a RemoteFunction from server to client.
### 9.5 Line simulation and rendering
**Shared `Path.luau`**
- A ring buffer of breadcrumb points, with cumulative distance. Add a point when the leader has moved at least 0.4 studs. Keep at least capacity × 4 + 30 studs of path.
- Follower i sits behind the leader at the summed spacing of followers 1 to i. Work out every position in one pass along the path, so the cost grows with points plus followers, not points times followers.
- A jump of more than 25 studs between samples (a respawn, or the server moving a player) resets the path to a straight line behind the leader.
**Server**
- Records each leader's position 15 times a second.
- Checks for cuts 10 times a second (4.4.2). It skips a victim straight away if the cutter is outside the bounding box of the victim's cuttable followers (plus the cut radius), and otherwise tests only those followers.
**Client (`LineRenderer`)**
- Records every visible leader each frame into its own paths. Small differences between clients don't matter, because follower positions are only for show.
- Keeps one pool of models per species. Parts are anchored, with `CanCollide`, `CanTouch`, `CanQuery` and `CastShadow` off, in a folder only the client has.
- Moves every visible follower with one `workspace:BulkMoveTo` call per frame (`Enum.BulkMoveMode.FireCFrameChanged`).
- Hop: height = |sin(t·ω + i·φ)| × h, plus a small side-to-side waddle, smoothed towards the target.
- Level of detail: full detail within 80 studs; no particles from 80 to 200 studs; hidden beyond 200 studs (150 on phones).
- Draws at most 350 followers on phones and 900 elsewhere: your own line first, then the nearest.
- Transitions: a joining critter starts at its bait; stolen critters glide from where they were to their new places (0.5 s); delivered critters pop at the pen.
- If a leader streams out, hide their line. When they stream back in, start their path again.
### 9.6 Saved data
ProfileStore, store name `CongaCritters_v1`, key `Player_<UserId>`.
 
```lua
export type Critter = {
    u: number, -- uid, unique per player
    id: string, -- species id
    v: number, -- variant: 0 Normal, 1 Golden, 2 Rainbow
    b: boolean?, -- bound (from Golden Bait)
    p: boolean?, -- paid (Golden Bait or Server Luck; 4.2)
    pin: boolean?, -- pinned (pen only)
    fav: boolean?, -- favourite (4.5.9)
}
 
export type SaveData = {
    Version: number, -- 1
    Coins: number,
    LP: number,
    Rebirths: number,
    Upgrades: { Leash: number, Bait: number, Pen: number, Speed: number, Storage: number },
    Pen: { [string]: Critter }, -- slot number ("1" to "30") -> critter; empty slots are absent
    Storage: { Critter },
    NextUid: number,
    Index: { [string]: number }, -- species id -> bitmask: 1 Normal, 2 Golden, 4 Rainbow
    IndexRewards: { [string]: number }, -- biome id -> bitmask of rewards granted
    Inventory: { GoldenBait: number, ShieldSeconds: number },
    Daily: { LastClaimDay: number, LadderDay: number, Streak: number, StandDay: number, StandTaken: number },
    -- LadderDay: the next reward (1-7); a missed day doesn't change it. Streak: days in a row, for show only (4.9)
    Tutorial: { Done: boolean, Step: number, ReleaseCueShown: boolean, PenIntroShown: boolean },
    BeginnerShieldUsed: number, -- seconds
    Stats: {
        Delivered: number, BestLine: number, BiggestSteal: number, Cuts: number,
        TimesCut: number, PlaySeconds: number, FirstJoin: number, LastJoin: number,
    },
    Purchases: { Processed: { string }, RobuxSpent: number },
    Settings: {
        Music: boolean, Sfx: boolean, LowDetail: boolean,
        AutoPlace: boolean, -- default true
        AutoRelease: { Enabled: boolean, UpTo: number, IncludeGolden: boolean }, -- defaults: true, 3 (Rare), false
    },
}
```
- Day numbers are UTC days: `math.floor(os.time() / 86400)`.
- Lines in progress aren't saved; 4.5.5 covers leaving. Line entries on the server carry the same `b` and `p` marks, and a critter gets its uid when it reaches the pen or storage.
- A full pen and storage (30 + 300 + 50 overflow = 380 records) is a few tens of KB, far below the 4 MB DataStore limit.
- **Migrations:** bump `Version` and add an ordered migration function. Never break an old save.
- **Saving:** ProfileStore autosaves; also save on leaving and flush in `BindToClose`.
- **Session lock:** if a profile can't load, kick the player with a friendly "please rejoin" message.
### 9.7 Anti-exploit
| Exploit | Defence |
|---|---|
| Teleporting, speed hacks, flying | Server Authority rejects invalid movement. The server also samples positions: moving more than (walk speed × 1.35 + 4 studs/s) × time elapsed, or more than 2 s airborne over 12 studs up, raises a flag. A flag blocks cutting, grabbing and delivering for 10 s and moves the player back to their last valid position. Log flags; no automatic bans in the MVP. |
| Entering locked biomes or other players' pens | The server checks zones 5 times a second and moves the player out |
| Throw spam, fake targets | Rate limits, range and zone checks; the server picks the critter |
| Remote spam, bad payloads | A token bucket per remote; type and finite-number checks; drop and count |
| Editing coins or stats | Only the server changes state; attributes are display copies |
| Fake purchases | Grants come only from ProcessReceipt and pass-ownership checks |
| Duplicating by rejoining | ProfileStore session lock; banking on leave runs once; critters on their way are dropped |
| Dying on purpose to get home | Death scatters the line (bound critters are banked); the reset button is off |
| Running admin commands | The server checks a UserId whitelist |
| Abusing pen actions | Every `PenAction` is checked against the player's own saved records; moves can't create critters or coins; rate limits |
 
### 9.8 Performance budgets
| Area | Budget |
|---|---|
| Server game logic | 6 ms or less per frame on average, with 6 players and every line at 300 |
| Cut checks | 1.5 ms or less per check (10 per second) |
| Mid-range phone | At least 45 FPS, aiming for 60, in a full server with every line at its cap |
| `LineRenderer` on that phone | 2.5 ms or less per frame |
| Network | Custom remote traffic averages 5 KB/s or less per client |
| Critter mesh | At most 1,000 triangles; textures at most 512 px |
| Pen critters | At most 30 per pen, drawn within 150 studs; they count towards the render caps in 9.5 |
 
Measure with the MicroProfiler and Developer Console on a real phone. Studio's device emulator shows layout, not speed.
 
### 9.9 Analytics
Use Roblox AnalyticsService through `TelemetryService`. Check the function names against the current docs.
- **Onboarding funnel:** 1 joined; 2 entered the Meadow; 3 first throw; 4 first critter joined; 5 leash full; 6 first delivery; 7 first upgrade; 8 opened the Index; 9 Jungle unlocked.
- **Economy events:**
  - Coin sources: delivery, pen income, daily reward, events, banking on leave.
  - Coin sinks: upgrades, Stand bait.
  - Golden Bait: sources and uses.
- **Progression events:** biome unlocks and rebirths (with minutes of play, and the coins and LP held at each rebirth), and upgrades bought (track, level and minutes of play). economy.md 9.2 uses these.
- **Custom events:** cut (number stolen, and the cutter's and victim's top tiers), loose grab, delivery (length band), new best line, shield started, anti-cheat flag, policy-restricted player, Manage Pen opened (by the player or by the introduction, with minutes of play), critters released (manual or automatic, by rarity), storage full, favourite set, auto-release turned off or on, Rebirth screen opened, invite prompt opened, friends in the server (sampled at each delivery).
- Compare weekly with the Creator Analytics benchmarks (PTR, bounce, D1, D7, session length).
### 9.10 Debug tools and config validation
- **Debug commands** work in Studio (`RunService:IsStudio()`) and, in live servers, for whitelisted UserIds only. They can:
  - fill a line to N critters;
  - give coins or LP;
  - set minutes of playtime (for the Beginner Shield and the Manage Pen introduction);
  - unlock biomes;
  - fill storage, or fill it to its limit;
  - spawn K debug leaders: dummy characters that walk random paths with full lines, owned by negative ids, for performance tests;
  - shift the clock, for daily-reward and event tests;
  - force PolicyService "restricted";
  - set the friend count Friend Boost uses (Studio test players aren't Roblox friends);
  - start Server Luck;
  - reset a profile (Studio only).
- **Config validator**, run at server start. It checks that ids are unique, every biome has every rarity, every weight is positive, every species has a mesh in Assets, and live product ids aren't zero. It stops the start in Studio and warns in live servers.
## 10. Milestones and schedule
 
### 10.1 Calendar
| Date | Day | Work |
|---|---|---|
| Fri 6 – Sun 8 Nov | Before | Spec and economy.md (done); install Rojo, Git and the Studio MCP connection (done); settle the open decisions (done) |
| Mon 9 Nov | 1 | Repo skeleton, Rojo project, `AuthorityMode = Server`, greybox map with tagged zones, Config stubs |
| Tue 10 Nov | 2 | C01-M1 and C01-M2 |
| Wed 11 Nov | 3 | C01-M3; phone test; Server Authority decision |
| Thu 12 Nov | 4 | C01-M4, including the placement and storage rules |
| Fri 13 Nov | 5 | C01-M5; two-client test; cheater checklist |
| Sat 14 Nov | 6 | Tune the first 60 s so the first critter arrives within 10 s; buy the animal pack and icon key art; submit custom Quick Words for review (4.12) |
| Sun 15 Nov | 7 | Swap in pack meshes; environment art pass on the greybox map (section 8: a distinct palette for each biome, plus the hub, pens and gates); UI pass |
| Mon 16 Nov | 8 | C01-M6 |
| Tue 17 Nov | 9 | C01-M7, including the Manage Pen menu and favourites |
| Wed 18 Nov | 10 | C01-M8 and C01-M9; analytics events |
| Thu 19 Nov | 11 | Full regression; device tests; store page; questionnaire; 6 thumbnails, 3 icons and three 10–15 s clips. GTA VI is scheduled for consoles today |
| **Fri 20 Nov** | **12** | **Soft launch.** $20–40 of Sponsored ads across 3 thumbnails; one clip a day on TikTok, YouTube Shorts and Roblox Moments |
| Sat 21 – Sun 22 Nov | 13–14 | Watch the numbers; hotfixes |
 
If Sunday runs over, the environment art pass can move to a later day, but it can't be cut: it must be finished before Thu 19 Nov, because the thumbnails, icons and clips come from real gameplay (0.3, rule 5).

If C01-M9 isn't ready for Thursday's regression, launch without it and publish it during the launch weekend. Players on an hour a day can make their first rebirth on day 3, Sun 22 Nov (economy.md 6.1).
 
Weeks 3 and 4 are in section 14.
 
### 10.2 Milestone acceptance checks
Run each check in a playtest (section 11), and paste the evidence into the commit message: console lines, numbers, screenshots.
 
**C01-M1: Config and spawner** (Tue 10 Nov). Scope: Rojo and Git skeleton, Config modules and validator, `Odds.luau`, `Zones.luau`, `MapService`, greybox map, `AuthorityMode = Server`, debug commands.
1. Over 100,000 Meadow rolls at λ = 1, each rarity's share is within 4 standard errors (√(p(1 − p)/n)) of its configured share. The same holds for variants, for Golden Bait, and for Server Luck odds against the table in 4.2.
2. Zone tests return the right zone for at least 20 sample points across the hub, every depth band, every pen and every gate.
3. Two test players get different pens; a rejoining player gets a free pen.
4. A playtest with `AuthorityMode = Server` shows no errors in `get_console_output`.
**C01-M2: Throw arc and attraction** (Tue 10 Nov). Hand-tune: arc feel, run and eat timings.
1. A Meadow throw produces a critter that runs in, eats and joins within 2.5 s of the bait landing (timestamps logged).
2. Throws are rejected, and counted, in the hub, in a locked biome, out of range and during the cooldown.
3. With the leash full, throws are rejected and THROW greys out.
4. 20 rapid clicks (`user_mouse_input`) produce no more accepted throws than elapsed time ÷ cooldown + 1.
**C01-M3: Follower chain** (Wed 11 Nov). Hand-tune: spacing, hop, smoothing.
1. A debug line of 300 follows a figure-of-eight walk (`character_navigation`). `screen_capture` shows it tracing the path, and once settled no follower is more than 1 stud from its target.
2. Two clients (Studio Test tab, Clients and Servers) see each other's lines.
3. Walk speed matches the formula at lengths 0, 100, 200 and 300.
4. On a real mid-range phone, with 6 lines at 300 (debug leaders), the game runs at 45 FPS or more and `LineRenderer` takes 2.5 ms or less (MicroProfiler).
5. Server Authority decision: if movement feels normal on phone and PC with no new errors, keep it. Otherwise switch to Automatic and log the change (9.1).
**C01-M4: Income and DataStore** (Thu 12 Nov). Includes the biome cap, placement and storage rules (4.5.3, 4.5.6, 4.5.7).
1. Delivering a 10-critter line pays exactly Σ value × 1.25 coins and the right LP.
2. A 300-critter delivery finishes within 4.5 s, and stepping out of the pen pauses it.
3. Pen income over 60 s matches the formula to within one tick.
4. Upgrade costs and effects match Config; upgrades can't be bought without enough coins or past the top level.
5. Below the LP requirement, a player pushed into a gate (`execute_luau`) is moved back out; at the requirement they pass.
6. Leaving and rejoining restores everything. Two-account test passes. Opening the same account in two sessions follows ProfileStore's session lock.
7. Leaving mid-run banks the line at base value, with no multiplier, and the banked critters follow the placement rules.
8. Placement (4.5.6): with an empty pen, a 10-critter delivery fills the 6 slots with the most valuable critters. Of the other 4, Normal-variant Rare-or-lower critters are released and the rest, Golden ones included, go to storage.
9. Pinned critters are never moved or released by a delivery, and nothing already in storage is ever released automatically.
10. With storage full, leftovers are released and counted in the delivery summary, except Legendary-or-better, Rainbow and bound critters, which go up to 50 over the limit. A bound Rare from Golden Bait is never auto-released.
11. Biome cap: a Snowy Peaks critter delivered by a Meadow-only player pays, earns and gives LP like a Meadow critter. After a debug unlock of Snowy Peaks, its pen income rises to full.
**C01-M5: Line cutting with server validation** (Fri 13 Nov). Use two clients plus positions set with `execute_luau`. Hand-tune: cut radius, speed threshold, cooldowns, how the snip feels.
1. Crossing position 21 or later of a 40-critter line takes the right number; crossing positions 1–20 does nothing.
2. When the segment is larger than the cutter's free space, the extra become loose critters, and the victim can grab them back within 8 s.
3. No cut happens in each blocked case in 4.4.2: a SafeZone, a line under 10, a cutter standing still, either player shielded, each cooldown, a full leash.
4. Golden Bait critters in the segment stay with the victim.
5. A teleport attempt from the client (`execute_luau` on the Client datamodel) is flagged, can't cut for 10 s, and is moved back.
6. The snip, the banners, "BIG STEAL!" at 50 or more and the server toast at 100 or more all fire. The server toast names the cutter but not the victim.
7. Tier rule (4.4.2): with `CutTierGap` unset (the launch default), a player whose top tier is Snowy Peaks can cut in every biome. With 1, they can't cut in the Meadow; with 0, they can't cut in the Meadow or the Jungle. They can always cut in their top biome and in event biomes.
**C01-M6: Shop and purchase receipts** (Mon 16 Nov)
1. Each pass and product grants exactly once in a Studio test purchase. Replaying ProcessReceipt with the same PurchaseId grants nothing more.
2. A receipt that arrives before the profile loads returns `NotProcessedYet`, and is granted once the profile loads.
3. With "restricted" forced, the Golden Bait ×3 and Server Luck buttons show the unavailable message and never prompt.
4. The odds panel matches `Odds.luau` at λ = 1, with Server Luck, with Golden Bait (for each band at the player's bait level), and during Golden Hour.
5. Buying Server Luck again adds time, never multiplier, and the buyer toast shows. With more than 45 min queued, the button is unavailable. A Line Shield bought with 60 min already stored still adds its full 10 min.
**C01-M7: Index, daily rewards and Manage Pen menu, with favourites** (Tue 17 Nov)
1. A new species or variant adds an Index entry and plays the "NEW!" toast once; stolen and grabbed critters count too.
2. Completing a biome's Normal set grants +10% coins exactly once, and it survives a rejoin. Collecting a biome's Common, Uncommon and Rare species in Rainbow grants the rainbow trail; no rarer Rainbows are needed.
3. The daily reward can be claimed once per UTC day, and rewards match Config. With the clock shift: missing a day pauses the ladder (the next claim gives the next reward) and sets the streak counter back to 1; after day 7 the ladder starts again at day 1, and the badge is granted only the first time.
4. The Stand restocks at 00:00 UTC; the first bait is free and the next two cost coins; stock persists across a same-day rejoin. Daily coin rewards and Stand prices use best pen income: moving every pen critter into storage doesn't change them.
5. The Manage Pen button appears only in the player's own pen. The menu opens by itself exactly once: at the end of the first delivery that ends with a critter in storage, once the player has 5 minutes of playtime. Test a first storage arrival before and after minute 5 (debug playtime and storage), a player who opened the menu first (no automatic opening; arrows on their next open) and a rejoin (never again). The first release after the tutorial plays the hop-home animation and pulses the button, once.
6. The info card shows current and full value for a capped critter. Move to pen (with the swap picker when the pen is full), move to storage (unavailable when full), pin, unpin, favourite, unfavourite and release all work, and release asks for confirmation where 4.5.8 says.
7. Favourites: a fourth can't be set without the passes; a favourite can't be released or swapped out, and no automatic rule moves it, in the pen or in storage.
8. Sort with storage fills the unprotected pen slots with the most valuable critters from pen and storage, never releases anything and never moves protected critters.
9. With auto-place off, delivered critters skip the pen. With auto-release off, critters that miss the pen go to storage; once storage is full, step 4 of 4.5.6 still applies (Legendary-or-better, Rainbow and bound critters overflow; the rest are released). Both settings survive a rejoin.
10. `PenAction` calls with another player's uid, or past a limit, are rejected and counted.
**C01-M8: Event toggle** (Wed 18 Nov)
1. Golden Hour runs from :00 to :05 UTC (test with the clock shift), and the odds panel updates.
2. `/event start critter_rush 10` on one server reaches a second server within 5 s. A server that starts during the event joins it.
3. Admin commands from players not on the whitelist are ignored and logged.
4. `/stampede` spawns loose critters only in the chosen biome, and grab rules apply.
**C01-M9: Rebirth and friends** (Wed 18 Nov). Scope: `RebirthService`, the Rebirth screen, `FriendsService`, the Invite button (4.7, 4.12). If it slips, see the note under 10.1.
1. The Rebirth screen shows progress towards each need until all are met. A `Rebirth` call before Snowy Peaks is unlocked, below the LP or coin need (economy.md 5.7) or with critters in the line is rejected and counted.
2. A rebirth resets coins, upgrades (Storage included), LP and every critter in the pen and storage that isn't a favourite. It keeps everything in the 4.7 Keeps list.
3. After n rebirths: a test delivery pays (1 + 0.15n) times the coins and LP it paid with no rebirths; leash capacity is 10n higher, never above 300; the crown above the player and on the pen sign matches; and the next rebirth's needs match economy.md 5.7.
4. Favourites go back to the pen as far as its 6 slots allow, and the rest go to storage. They earn at the biome-capped value until their biomes are unlocked again.
5. The confirmation screen lists what resets, what stays and what the player gets, and names every Golden Bait critter that isn't a favourite and will go.
6. Two quick `Rebirth` calls rebirth once, and a rejoin straight after a rebirth shows the same state.
7. Friend Boost (debug friend count): with 0, 1, 2, 3 and 4 friends in the server, delivery coins rise by 0%, 10%, 20%, 30% and 30%. LP doesn't change. The boost updates when a friend joins or leaves.
8. The Invite button opens Roblox's invite prompt on PC and on a phone.
## 11. Test plan
1. **MCP loop for each milestone:**
   1. `start_stop_play` to start.
   2. Drive with `character_navigation`, `user_mouse_input` and `user_keyboard_input`.
   3. Read `get_console_output` and check `screen_capture`.
   4. `start_stop_play` to stop, then fix and repeat.
   - Use `execute_luau` on the Server datamodel to check state and on the Client datamodel to try exploits.
2. **Several clients:** Studio Test tab → Clients and Servers, with 2–3 players. Needed for cuts, loose-critter grabs and line drawing.
3. **Cheater checklist** (9.7), at M5 and again at M8: an agent tries each exploit from the Client datamodel and confirms the server blocks it.
4. **Devices:** a real mid-range Android phone and an iPhone, plus PC, and a console if one is available.
5. **Soak test:** 30 minutes with 6 debug leaders at 300. No errors, and memory grows by under 10%.
6. **Data:** two accounts, rejoining, shutdown flush (`BindToClose`) and the session lock.
## 12. Launch checklist (Thu 19 – Fri 20 Nov)
- [ ] Every milestone check passes on a fresh publish.
- [ ] On a phone, the first critter arrives within 10 s in 5 runs out of 5.
- [ ] Re-read Roblox's paid random items policy, the Community Standards and the rules on AI-generated assets.
- [ ] Maturity & Compliance Questionnaire done, with paid random items declared.
- [ ] PolicyService gating tested with a forced "restricted" player.
- [ ] Store page: the title "Conga Critters", an honest description, no giveaway or Robux claims, and the right genre.
- [ ] Search Roblox for "Conga Critters" and close variants. The name should still be free: a near-identical name confuses players and search (handoff 6.3).
- [ ] 6 thumbnails and 3 icons from real gameplay; a custom thumbnail set (needed for Recommended For You).
- [ ] Analytics funnel, economy and custom events showing in Creator Analytics.
- [ ] Debug commands off for anyone not on the whitelist.
- [ ] Real pass and product ids in Config; test purchases done.
- [ ] Private servers on, at a low price (4.12).
- [ ] Custom Quick Words submitted (4.12). If Roblox hasn't approved them yet, launch anyway; they go live once approved.
- [ ] Config values match economy.md section 5 (spot-check every table).
- [ ] Sponsored ads ready: $20–40 across 3 thumbnails.
- [ ] GTA VI's console date (scheduled for 2026-11-19) re-checked.
## 13. Go/kill
From the handoff (section 4.3). Benchmarks are the 50th–90th percentiles for similar games in Creator Analytics.
 
| Check | When | Pass |
|---|---|---|
| Session length | Launch + 7 (Fri 27 Nov) | Average session of 12 min or more |
| First-play bounce | From launch + 7 | Below the median |
| D1 retention | From launch + 7 | At or above the median |
| PTR | After 3 thumbnail tests | At or above the median |
| Go or kill | Launch + 14 (Fri 4 Dec) | PTR, D1 and D7 at or above the 50th percentile, and bounce below the median: ship Update 2 |
| Kill or pivot | After two rounds of fixes | Two "Most important" signals still below the 50th percentile |
| Scale or stop | Launch + 30 (Sun 20 Dec) | Before the holiday window. Also decide whether to add trading (6.4) |
 
When signals are weak, fix bounce first, then PTR, then D1.
 
## 14. After launch
| Date | Release | Contents |
|---|---|---|
| Mon 23 – Thu 26 Nov | Fixes | The weakest signal first. £50–100 on the winning thumbnail |
| **Fri 27 Nov** | **Update 1** (US Thanksgiving week) | The Autumn Woods biome, tier-matched so it pays at each player's own level (economy.md 7.1), with 6–8 critters including a turkey. Any P1 features not in the soft launch: VIP, the Revenge marker, the Best Line board, custom Quick Words (if still waiting for approval) and settings; the Manage Pen menu's sorting, filters and auto-release filter editor; and the Big Storage and More Favourites passes. Tag the title, e.g. "[🦃 UPD]" |
| Sat 28 Nov | Admin event | 20:00 UTC: Critter Rush plus stampedes |
| Mon 30 Nov – Thu 3 Dec | Build Update 2 | Mega-conga and Auto-Bait; prepare the December event |
| **Fri 4 Dec** | **Day-14 review; Update 2 if go** | Ship mega-conga and spend the remaining £100–150. Review the Longer Leash price (economy.md 11.6) and confirm Tier 4 (economy.md 11.8). If not go: change the verb or theme, or switch to C03 Tower Talk |
| Sat 5 Dec | Admin event | |
| Fri 11 Dec | Tier 4 (if go) | The first new top tier: ×1,000 coins, ×125 LP and a 4,000,000 LP gate, with later rebirth needs raised to match (economy.md 6.8, 7.2) |
| Every Friday and Saturday | Weekly rhythm | A new biome as data (an event biome, or a new top tier every second or third week; economy.md 7) and tuning (Friday); an admin event (Saturday). Event biomes close when their event ends and come back for later events (economy.md 7.4) |
| Sun 20 Dec | Day-30 review | Scale up or stop. Decide on trading, friends-only first (6.4) |
| 20 Dec – 4 Jan | Holiday event | A tier-matched winter biome and directly sold hats |
| About launch + 28 | Great Migration | Monthly event (4.10) |
 
**Mega-conga outline** (Update 2; it gets its own spec):
- Two to four friends link their lines. Linked lines count as one length for the Conga multiplier when all of them deliver within 15 s of each other.
- Linked players can't cut each other. The link breaks if they are more than 60 studs apart for 5 s.
- A ribbon between the leaders shows the link.
## 15. Risks
| Risk | Response |
|---|---|
| Clones and saturation | Ship fast, update weekly, own "conga" in search, keep the verb distinctive |
| Exploiters (Break and Steal an Egg had 26 exploit scripts listed) | Server Authority, server checks, cheater checklist |
| Phone performance with hundreds of followers | Render caps, level of detail, pooling; test with debug leaders on a real phone early (M3) |
| Young players feeling robbed | Back-half rule, safe hub, shields, bound paid critters, immunity |
| Players losing good critters to a full storage | The default filter releases only Normal-variant Rare-or-lower critters that miss the pen, never Golden or bound ones; players can turn auto-release off; Legendary-or-better, Rainbow and bound critters overflow; a warning dot at 90% full; Release all shown (Update 1); nothing in storage is released automatically |
| Storage filling faster because the default filter keeps Golden critters (about 15 min for 50 slots in Snowy Peaks instead of 24; economy.md 5.6) | Watch storage-full events (economy.md 9.2). Lower the Storage track's costs, or release Golden Commons to Rares by default |
| Economy too slow or too fast for real players | Simulation-tuned starting values (economy.md 6); weekly retuning from analytics (economy.md 9); never take back what players have |
| Paid-random-item policy | Odds panels, PolicyService, questionnaire, no coin packs |
| Server Authority is new | Decision at M3; the game stays correct without it |
| Rebirth and friends add a ninth milestone to a full fortnight | C01-M9 shares Wed 18 Nov with M8. If it slips, launch without it and publish it during the launch weekend (10.1) |
| The animal trend fading | Biomes are data; fantasy biomes later |
| GTA VI the day before the soft launch | The soft launch is a metrics read; GTA's audience overlaps less with 9–15-year-olds |
 
## 16. Decisions log
| Date | Decision | By | Status |
|---|---|---|---|
| 2026-11-06 | Cuts take the back half only | Developer | Final |
| 2026-11-06 | Keep the 2-week build: soft launch Fri 20 Nov; Update 1 is the Thanksgiving beat; Update 2 on Fri 4 Dec if go | Developer | Final |
| 2026-11-06 | No coin packs at launch (6.4) | Spec; developer confirmed 2026-11-07 | Final |
| 2026-11-06 | Golden Bait critters are bound (can't be cut away) | Spec; developer confirmed 2026-11-07 | Final |
| 2026-11-06 | Friends can cut each other | Spec; developer confirmed 2026-11-07 | Final |
| 2026-11-06 | Launch passes: 2x Coins, Longer Leash. Launch products: Golden Bait ×3, Line Shield, Server Luck | Spec | Final unless changed |
| 2026-11-06 | 6-player servers; 8 pen plots built | Spec | Tune after launch |
| 2026-11-06 | Server Authority on from M1, with a decision at M3 | Spec | Decide at M3 |
| 2026-11-06 | Lines travel over remotes, not attributes | Spec | Final |
| 2026-11-06 | Shields block cutting both ways; shield time is stored and tap-activated | Spec | Final unless changed |
| 2026-11-06 | Leaving mid-run banks the line at base value | Spec | Final unless changed |
| 2026-11-06 | The Manage Pen menu opens from a button in the pen; it opens by itself only once, as an introduction | Developer | Final |
| 2026-11-06 | "Release" instead of selling: no coins, because delivery already paid | Developer | Final |
| 2026-11-06 | Auto-place compares the pen with delivered critters only; storage joins in only through Sort with storage | Developer | Final |
| 2026-11-06 | Storage: no income; 50 to start, up to 200 with upgrades, +100 with the Big Storage pass; nothing in it released automatically | Developer | Final (numbers tunable) |
| 2026-11-06 | Favourites: 3, up to 8 with passes; the only critters kept through a rebirth | Developer | Final |
| 2026-11-06 | The biome cap applies to every critter, not only favourites (4.5.3) | Spec; developer confirmed 2026-11-07 | Final |
| 2026-11-07 | Auto-release is on by default at launch, and players can turn it on or off in the Manage Pen menu; the filter editor comes in Update 1 (changed from a fixed filter with no switch) | Developer | Final |
| 2026-11-07 | Default auto-release filter: Rare or lower, Normal only, so Golden critters are kept (changed from Rare or lower, Normal or Golden; Common and Uncommon, Normal only in 0.2). Storage fills faster as a result (15) | Developer | Final |
| 2026-11-06 | Legendary-or-better, Rainbow and bound critters can overflow a full storage by up to 50, and auto-release never takes bound critters (Epic-or-better and Rainbow in 0.2) | economy.md; developer confirmed 2026-11-07 | Final |
| 2026-11-06 | No trading in the MVP; reconsider at the day-30 review, friends-only first | Developer | Final |
| 2026-11-06 | Critters from Golden Bait or Server Luck are marked paid from launch | Spec | Final |
| 2026-11-06 | New biomes: tier-matched event biomes, plus a new top tier every second or third week | Developer | Final |
| 2026-11-06 | Lead Power mostly rewards effort: LP doubles with each rarity step; coins keep the jackpots | Developer | Final |
| 2026-11-06 | Rebirth needs coins as well as LP (economy.md 5.7) | economy.md; developer confirmed 2026-11-07 | Final (numbers tunable) |
| 2026-11-06 | Index coin bonuses have no cap (a +100% cap was considered and dropped; economy.md 6.10) | Developer | Final |
| 2026-11-06 | Daily coin rewards and Stand prices use best pen income, which closes an exploit | economy.md; developer confirmed 2026-11-07 | Final |
| 2026-11-06 | Storage track costs 2,000 up to 8,000,000 | economy.md; developer confirmed 2026-11-07 | Final (numbers tunable) |
| 2026-11-06 | Longer Leash stays at 299 R$ for the soft launch, although it's the strongest pass | economy.md; developer confirmed 2026-11-07 | Final for the soft launch; review at day 14 |
| 2026-11-06 | Event biomes close when their event ends and return for later events | economy.md; developer confirmed 2026-11-07 | Final |
| 2026-11-06 | Tier 4 on Fri 11 Dec with a 4,000,000 LP gate | economy.md; developer confirmed 2026-11-07 | Planned; confirm at the day-14 review |
| 2026-11-06 | Bought shield time and Server Luck time are never lost to their limits | Spec | Final unless changed |
| 2026-11-07 | Rebirth and the 3 free favourite slots ship at the soft launch (C01-M7 and C01-M9; economy.md 11.9). The More Favourites passes stay P1 | Developer | Final |
| 2026-11-07 | Invite, Friend Boost and private servers are P0: they're cheap, and co-play is an RFY signal (handoff 7.3, 8.2) | Developer | Final |
| 2026-11-07 | The Manage Pen introduction opens the first time a delivery leaves a critter in storage, never before 5 minutes of play, so it stays out of the 61–180 s bounce window. A wordless hop-home cue explains the first releases (4.5.8) | Developer | Final |
| 2026-11-07 | An optional tier rule for cutting (`CutTierGap`, 4.4.2) is built but off at launch, so quiet servers still have someone to cut. Turn it on if stronger players pick on new ones (economy.md 9.2) | Developer | Final |
| 2026-11-07 | A missed day pauses the daily ladder instead of resetting it; the streak counter resets but no reward depends on it | Developer | Final |
| 2026-11-07 | The rainbow trail needs only the Common, Uncommon and Rare species in Rainbow (economy.md 11.10) | Developer | Final |
| 2026-11-07 | The server-wide steal toast names only the cutter, not the victim | Developer | Final |
| 2026-11-07 | Custom Quick Words, such as "Watch your tail!" and "Follow me!": a Creator Hub setting with no code, submitted before launch (P1, as Roblox must approve them) | Developer | Final |
| 2026-11-07 | Favourites are built with the Manage Pen menu (C01-M7); rebirth and friends get their own milestone (C01-M9) on Wed 18 Nov, publishable during the launch weekend if it slips | Spec | Final unless changed |
| 2026-11-07 | Every decision marked "Developer to confirm" is settled: 11 as proposed, 2 changed (the auto-release switch and the default filter, above) | Developer | Final |
| 2026-11-07 | `Config/Throw` added: 9.2's Config list has no home for the throwing and arrival numbers (4.1, 4.2, 9.4) | Build day 1; developer approved | Final |
| 2026-11-07 | Critter Rush runs 30 minutes when `/event start critter_rush` gives no length (4.10) | Developer | Final |
| 2026-11-07 | An environment art pass on the greybox map is scheduled for Sun 15 Nov, alongside the mesh swap and UI pass. It can move if Sunday runs over but can't be cut, and must be done before Thu 19 Nov because the store art and clips come from real gameplay (10.1) | Developer | Final |
| 2026-11-07 | Greybox map: a hexagonal hub with one gate on each flat (meadow, slot 1, jungle, slot 2, peaks, slot 3 going round); biome wedges are stepped (bands 140, 200 and 260 wide) so every zone is an exact box; pens are open at the front and back with fenced sides | Build (greybox) | Gate order, Near width and walls changed (below) |
| 2026-11-07 | Gate and ComingSoonGate zone parts also carry the `SafeZone` tag, so the gate areas outside the hub hexagon are safe (9 SafeZone parts). Pen spawn points are `Spawn` attachments on the `Pen` zone parts (no new tag). `FirstSpawn` is a SpawnLocation inside `Map.Zones` | Build (greybox) | Final unless changed |
| 2026-11-07 | Nobody can leave the playable area: tall walls along the hub edge between gates and round every biome, tested from the top of every wall segment (3.1) | Developer | Final |
| 2026-11-07 | Every biome has a visible boundary wall in its own colour as well as invisible ones; every gate opening stays clear and at least 30 studs wide (3.1) | Developer | Final |
| 2026-11-07 | Gate order, clockwise from above: 1 Meadow, 2 Jungle, 3 Snowy Peaks, 4 Tier 4, 5 Tier 5, 6 event biomes (Autumn Woods, then the winter biome); gate 6 directly counter-clockwise of the Meadow. `ComingSoonGate` gains a `PlannedUse` attribute (3.1, 3.2; economy.md 7.4) | Developer | Final |
| 2026-11-07 | FirstSpawn is centred in front of the Meadow gate, about 40 studs away, facing into it (2.1, 3.1) | Developer | Final |
| 2026-11-07 | `Config/Camera` added with `CameraMaxZoomDistance = 80`, applied to `StarterPlayer` at boot; tune at C01-M3 with 300-critter lines. Every visible wall is at least `CameraMaxZoomDistance` + 10 high so no camera angle sees over it (3.1, 9.2) | Developer | Final (zoom tunable) |
| 2026-11-07 | Greybox walls are `CameraMaxZoomDistance` + 20 (100) high: the camera's pitch limit is 80°, so a jumping player's camera can reach head 4.5 + jump 7.2 + 80 × sin 80° = 90.5, just over + 10. Invisible walls outside them go to 160 | Build (greybox) | Final unless changed |
| 2026-11-07 | Forced by the new gate order (biomes 60° apart): the Near band is 120 wide instead of 140 so neighbouring biomes don't overlap at the hub corner, and each biome has 3 `Biome` zone parts (one per band) instead of one box, so no Biome box reaches into the next biome (9 Biome parts) | Build (greybox) | Replaced by cone biomes (below) |
| 2026-11-07 | Gate archways about 60 studs wide and 50 tall, open and coming-soon gates alike (3.1). The hub didn't need to grow: a 60-stud gate and its pillars take 72 of each 121-stud side | Developer | Final |
| 2026-11-07 | Cone-shaped biomes: one trapezoid per biome from the gate's width (60) to about 300 at the far end, 400 deep, with straight angled walls in the biome's colour and invisible walls outside. One `Biome` part and one part per `DepthBand`, each a trapezoid with `NearWidth` and `FarWidth`; bands stay at 0–130, 130–270 and 270–400. `Zones.Contains` handles trapezoids and plain boxes (3.1, 3.2) | Developer | Final |
| 2026-11-07 | Cone floors are a centre block plus two `WedgePart` triangles per band (basic parts, not meshes). Each side flares at 16.7°, well inside the 30° to the next biome, so the full 300-stud width fits. Burrows: 6 rows evenly through the depth, 2 per row at a quarter and three quarters of the width (12 per biome) | Build (greybox) | Final unless changed |
| 2026-11-07 | Coming-soon gates are closed by a solid panel behind the sign instead of an invisible blocker, so nothing beyond them can be seen | Build (greybox) | Final unless changed |
 
## 17. Sources
- The research handoff, in this project: `claude/roblox-viral-game-research-handoff-2026-11-06.md`.
- `/docs/economy.md` v0.4 and `/tools/econ_sim.py`: the tuned numbers and the simulation behind them.
- Roblox Creator Hub, "Quick Words" (updated 2026-10-22): https://create.roblox.com/docs/chat/quick-words
- Roblox Creator Hub, "Paid random items policy guidelines" (updated 2026-10-15): https://create.roblox.com/docs/production/monetization/paid-random-items
- Roblox DevForum, "Update on paid random items restriction for UK users under 18": https://devforum.roblox.com/t/update-on-paid-random-items-restriction-for-uk-users-under-18/3072183
- Roblox DevForum, "[Full Release] Ship Fair And Competitive Games with Server Authority" (2026-07-09): https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993
- Roblox Creator Hub, Studio MCP server: https://create.roblox.com/docs/studio/mcp
- PCGamesN, GTA 6 release date (updated 2026-04-29): https://www.pcgamesn.com/gta-6-release-date
## 18. Changelog
- 0.1 (2026-11-06): first version.
- 0.2 (2026-11-06): Manage Pen menu, storage, pinning, favourites and Release (4.5.6–4.5.9); the biome cap (4.5.3); the paid mark (4.2); trading deferred to the day-30 review; matching changes to rebirth, upgrades, passes, remotes, saved data, checks, calendar and logs.
- 0.3 (2026-11-06): tuned numbers from economy.md v0.1: LP per rarity, gates, pen income, per-level upgrade costs, rebirth needs in LP and coins, the Index cap, daily rewards and Stand prices from best pen income, and the default auto-release filter and overflow. Tier-matched event biomes and new top tiers; Release all shown; the Golden Bait odds panel by band; matching remotes, saved-data defaults, analytics, checks, calendar, risks and decisions.
- 0.4 (2026-11-06): review pass against the handoff, the audience and economy.md v0.2. Index coin bonuses have no cap. Bound critters are never auto-released and can overflow storage. Bought shield and Server Luck time is never wasted. Pen income is shown per minute. Rebirth points out Golden Bait critters; the daily panel shows tomorrow's reward. The number format matches economy.md; 0.4 gains a Lead Power row; a policy check for 2x Coins; cut events record both players' tiers; launch checks for Config and the game's name. Eight changes logged as "Proposed" in section 16 await the developer.
- 0.5 (2026-11-07): the developer's answers to the review. Rebirth, Friend Boost, Invite and private servers ship at the soft launch: a new milestone C01-M9 (Wed 18 Nov, with a launch-weekend fallback), favourites built in C01-M7, the Rebirth screen opened from Upgrades, `RebirthService` and `FriendsService`, a debug friend count, analytics, checks, the calendar, Update 1's list and a risk row. An optional tier rule for cutting, off at launch (4.4.2). A missed day pauses the daily ladder (4.9). The rainbow trail needs only Common to Rare species (4.8). Server-wide steal toasts name only the cutter (4.4.5). Custom Quick Words (4.12, P1), submitted on Sat 14 Nov. The Manage Pen introduction's timing is still "Proposed".
- 0.6 (2026-11-07): the Manage Pen menu introduces itself the first time a delivery leaves a critter in storage, never before 5 minutes of play, instead of at 2–3 minutes. The first release after the tutorial gets a wordless hop-home cue and a button pulse. Matching timeline, saved-data flags, a debug playtime command, analytics and the M7 check (2.1, 4.5.8, 9.6, 9.9, 9.10, 10.2).
- 0.7 (2026-11-07): the developer settled all 13 "Developer to confirm" decisions (16); 11 stand as written. Two changes: an auto-release on/off switch ships at the soft launch in the Manage Pen menu (4.5.6, 4.5.8; `SetPenSettings` gains `autoRelease`, 9.4), and the default filter releases Rare or lower, Normal only, keeping Golden critters (`IncludeGolden` defaults to false, 9.6). Matching M4 check 8 and M7 check 9, an analytics event for the switch, Update 1's list, a new risk row, and the day-14 review items in 14.
 