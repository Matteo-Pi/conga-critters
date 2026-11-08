# Conga Critters: notes for coding agents

A Roblox game (ages 9–15, phones first), built with Rojo 7.7.1, Git and Roblox Studio's built-in MCP server.

- **What to build and how to check it:** `docs/spec.md`. It's about 1,100 lines, so read only the sections the task names.
- **Every number:** `docs/economy.md`. If it disagrees with the spec on a number, economy.md wins.
- **Precedence:** hard rules (spec 0.3), then the spec, then economy.md, then your judgement.

## How we work
- One milestone per session (C01-M1 to C01-M9, spec 10.2). Before coding, read the sections the milestone names and its acceptance checks.
- Code lives on disk under `src/`, and Rojo syncs it into Studio. **Never edit a Rojo-managed script through MCP edit tools**, because Rojo overwrites it. Use MCP to playtest, inspect, run Luau (`execute_luau`) and build map content.
- The map lives in the place file, not in Git. Build `Workspace.Map` through MCP. Don't add Workspace children or `ReplicatedStorage.Assets` to `default.project.json`.
- All content and numbers live in `src/shared/Config`; never hard-code them. Adding a critter, biome, bait level, product or event must need only data.
- The server decides; the client asks and draws (spec 9.3). Never trust numbers from a client.
- `--!strict` in every new module. Code names use Roblox's US spelling (`Color`, `Favorite`).
- Server Authority is on (`Workspace.AuthorityMode = Server`), which also turns on streaming, deferred signals and the Input Action System. Use `WaitForChild` and nil checks, and don't rely on signals firing immediately.
- Your training data may predate Server Authority and the Input Action System. Read the current docs with the MCP tools before using them.
- Finish a milestone by running its acceptance checks in a playtest. Paste the evidence (console lines, numbers, screenshots) into the commit message, for example `C01-M3: follower chain`, and add a line to `CHANGELOG.md`.
- Where the spec is silent, pick the simplest option that fits the pillars (spec 1.2), log it in spec 16 and flag it in the commit message. **Ask the developer first** if the choice touches money, fairness to young players or Roblox policy.
- `docs/` in this repo is the master copy of the spec and economy. The developer's claude.ai project keeps a copy: if you change either file, say so in your final message so they can refresh it.

## Hard rules (spec 0.3, short version)
1. No unlicensed IP: real animals and original designs only.
2. Roblox policy: odds shown before purchase, PolicyService gating, lowest maturity level, no harm to animals shown.
3. Metadata matches the gameplay.
4. The server decides cuts, deliveries, currency and purchases; ProcessReceipt is safe to run twice.
5. Clips and thumbnails show real gameplay only.
6. Fair to young players: no pay-to-win, and nothing paid for can be stolen.
7. A few hundred GBP of ads at most.
8. No trading in the MVP.

## Session routine (the developer does this)
1. Run `rojo serve` in the repo folder.
2. Open the place "Conga Critters" (place ID 88840993419398) in Studio, then click Rojo → Connect.
3. Run `claude` from the repo folder.

## Known noise
Playtests log `ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type` three times at boot. Nothing in the place references that asset, so it comes from Roblox's own scripts, not ours (it was once blamed on the Baseplate, wrongly). Ignore it.

Emulated input (MCP's `user_mouse_input`, or a click in Studio's Controller Emulator) fills the console with `Unknown action nil`, about 10 lines per click. It isn't from our code. Ignore it too. The tool's x/y are GUI coordinates: `UserInputService:GetMouseLocation()` reads them 58 px lower, because it includes the top bar.

In Studio's Device Simulator (phones):
- Roblox's own `PlayerModule` logs `DynamicThumbstick:196: attempt to index nil with 'FindFirstChild'` when the preferred input switches from Touch to KeyboardAndMouse. The MCP tool's keyboard events cause that switch. The touch controls come back on the next touch. Real phones never switch to keyboard, so ignore it.
- `user_mouse_input` with `instance_path` misses, because the simulator scales the view to fit the window: taps landed at about 0.91× the button's coordinates. Tap at raw x/y scaled up to match, and check with an `InputBegan` probe.

The Controller Emulator has no scripting API, and `VirtualInput` can't press gamepad buttons, so a gamepad test needs the developer to click the button in the emulator widget.
