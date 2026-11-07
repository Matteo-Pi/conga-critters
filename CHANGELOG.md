# Changelog

One line per milestone or build day; the commit message holds the playtest evidence.

## Build day 1: repo skeleton and Config (2026-11-07)
- Layout per spec 9.2: shared `Config/`, `Types`, `Net`, `Odds`, `Path`, `Zones`, `Format`; 20 server services and 17 client controllers as empty `--!strict` modules with `Init`/`Start`; `rojo init`'s hello-world scripts removed.
- Boot order: `init.server.luau` and `init.client.luau` require every module in `Services`/`Controllers` and call `Init()` on all, then `Start()` on all, in the order of spec 9.2's tables (DataService first). A module missing from the list still loads, after the listed ones, alphabetically, with a warning. Per-module prints are gated by `Config.Debug.LogBoot`; the "Booted N … in X ms" line always prints.
- Config: one deep-frozen module per name in spec 9.2, plus `Throw` (spec 16), filled from economy.md 5 and the mapping in 10. `Config/init.luau` returns them all as one table. `Config/Cutting` holds `CutTierGap` (off) and the spec 4.4.2/4.4.4 cut, loose-critter and steal numbers. `Config/Pen` holds `NeverReleaseMinRank = 5` and `NeverReleaseVariants = { "Rainbow" }` (overflow and never auto-released); bound critters always count too, as a hard rule in `PenService` code, not Config. Starting slots and storage limits live only in `Config/Upgrades`. The deep-freeze helper is `src/shared/Util/DeepFreeze.luau`. `Monetisation` (ids 0), `Admin` and `Debug` are typed stubs; `Tutorial` holds the fixed rolls and the Manage Pen intro's 300 s minimum.
- `Format.luau` per economy.md 8.3: balances round down, prices round up, 3 significant figures with K…Dc, scientific notation from 10^36, odds to 3 significant figures and "less than 0.001%" below that, rates per minute.
- ProfileStore 1.0.3 (MadStudioRoblox, commit 45c9847, Apache-2.0) vendored in `src/server/Packages/ProfileStore`; not used yet.
- Tooling: Selene and StyLua configs (Packages excluded), `.gitattributes` (LF), `.gitignore` covers `*.rbxl`/`*.rbxlx`.
- `default.project.json`: the `Workspace` node (Baseplate) removed so Rojo manages no Workspace children; the map lives in the place file (CLAUDE.md).

## Build day 2: greybox map (2026-11-07)
- Greybox map built in the place file through MCP (not in Git): a hexagonal hub at the origin with a 40-stud archway gate on each flat, 8 pens on a 62-stud ring, and stepped biome wedges (Near/Mid/Far 140/200/260 wide, 130/140/130 deep) behind the Meadow, Jungle and Snowy Peaks gates. The other 3 gates have a "coming soon" sign and an invisible blocker. Invisible walls round every wedge; a ground plate under everything. Default Baseplate and SpawnLocation removed.
- `Workspace.Map.Zones` (Model, `ModelStreamingMode = Persistent`) holds every tagged part from spec 3.2: 9 SafeZone (3 hub rectangles + all 6 gate parts), 3 Biome, 9 DepthBand, 3 Gate, 3 ComingSoonGate, 8 Pen (each with a `Spawn` attachment for returning players), 8 PenDeliveryPoint, 36 Burrow, and FirstSpawn (a SpawnLocation by the Meadow gate).
- Walking distance pen → gate by navmesh, other pens impassable: mean 126 studs, max 174 (8.7 s at speed 20). `Workspace.AuthorityMode = Server`.
- `Config/Events`: Critter Rush runs 30 minutes by default (developer decision, spec 16).
- SafeZone coverage box-tested: pen corners and delivery points, every gate opening, the hub hexagon's corners and edges, and a 2-stud grid over the hub floor. Fixed a gap: the outer half of each coming-soon gate wasn't covered, so ComingSoonGate parts are now SafeZones too. CLAUDE.md: `docs/` is now the master copy; the Known noise section is removed.

## Build day 2b: map fixes from the developer's playtest (2026-11-07)
- Escape bug fixed: every edge of the playable area now has a visible wall 100 studs high (`Config.Camera.CameraMaxZoomDistance` + 20), in the biome's colour around each biome and grey along the hub, with invisible walls up to 160 just outside. Coming-soon gates are closed by a solid panel. Tests: 264 runs from the top of 66 wall segments (4 directions each), 0 escapes; 318 floor-level runs into every wall face, 0 escapes, highest point 12.9.
- Gates renumbered clockwise in tier order: 1 Meadow, 2 Jungle, 3 Snowy Peaks, 4 Tier 4, 5 Tier 5, 6 event biomes. `ComingSoonGate` has `Slot` (gate number) and `PlannedUse`. With biomes 60 degrees apart, the Near band is 120 wide and each biome has 3 `Biome` zone parts.
- FirstSpawn centred 40 studs in front of the Meadow gate, facing it.
- New `Config/Camera` (`CameraMaxZoomDistance = 80`), applied to `StarterPlayer` at server boot. At full zoom and the 80 degree pitch limit the camera sits at y 83.3 (90.5 at a jump's peak), below every wall top.
- CLAUDE.md: the Known noise note is back with the right cause (Roblox's own scripts, not the Baseplate).

## Build day 2c: wider gates, cone biomes, Zones.luau (2026-11-07)
- Every gate archway is 60 wide and 50 tall; the hub didn't need to grow. Pen to gate: mean 125, longest 174 studs.
- Biomes are cones: one trapezoid each, 60 wide at the gate to 300 at 400 deep, with straight walls in the biome's colour and invisible walls outside. Floors are blocks plus `WedgePart` triangles. `Biome` and `DepthBand` zones are trapezoids with `NearWidth`/`FarWidth`; burrows in 6 even rows.
- `Zones.luau`: `Zones.Contains(part, point)` and `Zones.WidthAt(part, localZ)`; plain boxes keep the box test. 328 edge cases (just inside and just outside each angled edge, ends, top, box corners) all correct.
- Re-ran every check: tags, bands, biome overlap (0 of 54,317 points), walls in playable zones (0), SafeZone tests, escape tests (312 runs from wall tops and 216 from the floor, 0 escapes), FirstSpawn, walk to the Meadow's Far band.
