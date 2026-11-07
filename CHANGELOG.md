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
