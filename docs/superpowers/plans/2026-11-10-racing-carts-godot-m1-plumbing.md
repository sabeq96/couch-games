# Racing Carts in Godot — Milestone 1 (Plumbing) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Babylon.js Racing Carts with a Godot 4.7.1 web export running in the shell page: a stub race
(one cube per player, driven by the phone) that starts, takes input, finishes on the results screen and tears down
cleanly. It builds locally and in CI and is covered by GUT, Vitest and Playwright.

**Architecture:** `games/racing-carts/src/game.ts` keeps the game contract and starts a Godot `Engine` on a canvas
in `round.el`. The shell and Godot share one global, `window.racingCarts`: TypeScript writes JSON strings (players,
inputs) there, and Godot pulls them each physics tick through `JavaScriptBridge.get_interface("racingCarts")` and
calls back `ready()` and `finish(json)`. The export goes to `apps/shell/public/games/racing-carts/` (gitignored), so
Vite serves it in dev and copies it into `output/`.

**Tech Stack:** Godot 4.7.1 (GDScript, Compatibility renderer, Web export without threads), GUT 9.7.1, godot-ai
v4.4.1, TypeScript + Vitest, Playwright, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-10-racing-carts-godot-design.md` (§2, §3, §4, §9, §10 milestone 1).

Milestones 2–5 get their own plans once this one lands.

## Global Constraints

- Branch: `racing-carts-godot`. Commit after every task. Never commit export output or `godot/.godot/`.
- Godot **4.7.1**, `renderer/rendering_method="gl_compatibility"` (also `.mobile`), web preset
  `variant/thread_support=false`.
- `addons/` and `tests/` are left out of the web export.
- The Godot binary always comes from `scripts/godot.sh`: `$GODOT` if set; otherwise
  `/Applications/Godot.app/Contents/MacOS/Godot` if it exists; otherwise `godot`.
- Install libraries as their official docs say (CLAUDE.md): GUT per gut.readthedocs.io/en/v9.7.1/Install.html,
  godot-ai per its README. npm packages only through the npm CLI (`npm uninstall -w racing-carts …`).
- Paths under the site base come from `import.meta.env.BASE_URL` (`/couch-games/` in production).
- Engine config: `focusCanvas: false`, `canvasResizePolicy: 0`. `destroy()` waits at most **2000 ms** for `onExit`.
- The game contract is unchanged: `players: { min: 1, max: 6 }`, layout `tilt-racer`.
- Every `TiltRacerInput` is `{ steer: number (−1..1), gas: boolean, brake: boolean, item: boolean }` (from
  `@couch/shared`).

## Review Focus

1. **Non-contiguous slots** (party slots 0, 2, 5 when players 1 and 3 left): each cube, input and result must keep
   its real slot. Pinned in Task 2 (`test_parse_players_keeps_slots`) and Task 4 (`decodeResults`).
2. **Malformed or partial results from Godot** (missing slot, duplicate slot, bad JSON): `round.finish` must still get
   exactly one entry per player. Pinned in Task 4.
3. **`destroy()` while the tab is hidden or before Godot is ready:** must return within about 2 s, remove the canvas
   and leave no `window.racingCarts`. Pinned in Task 5 (Vitest, fake engine whose `onExit` never fires).
4. **Escape during "Loading…"** (the round is left before `startGame` resolves): no Godot left running, no errors.
   Pinned in Task 5 (e2e: Escape right after opening).
5. **Input before Godot is ready, or for a slot not in the round:** ignored, no error. Pinned in Task 2
   (`test_parse_inputs_ignores_unknown_slots`) and Task 4 (`encodeInputs`).

---

## File structure

| File | Responsibility |
|---|---|
| `scripts/godot.sh` | Finds the Godot binary and runs it with the given arguments. |
| `games/racing-carts/scripts/export.sh` | `--import`, then the web export into `apps/shell/public/games/racing-carts/`. |
| `games/racing-carts/scripts/test-godot.sh` | `--import`, then GUT headless. |
| `games/racing-carts/godot/project.godot` | Project settings (Compatibility, 60 Hz physics, main scene). |
| `games/racing-carts/godot/export_presets.cfg` | The "Web" preset. |
| `games/racing-carts/godot/.gutconfig.json` | GUT: `dirs: ["res://tests/"]`, `include_subdirs: true`, `should_exit: true`. |
| `godot/scripts/bridge_codec.gd` | Pure JSON in/out for the bridge (`class_name BridgeCodec`). |
| `godot/scripts/bridge.gd` | Node: reads `window.racingCarts` (web) or the keyboard (editor), sends `ready` / `finish`. |
| `godot/scripts/stub_race.gd` + `godot/scenes/stub_race.tscn` | Stub race: a floor, one cube per player in their colour, finish on ITEM. |
| `godot/tests/test_bridge_codec.gd` | GUT tests for the codec. |
| `games/racing-carts/src/bridge.ts` | Pure TS: URLs, engine config, input encoding, results decoding. |
| `games/racing-carts/src/bridge.test.ts` | Vitest for `bridge.ts`. |
| `games/racing-carts/src/game.ts` | `start(round)`: canvas, global, engine, loading text, `destroy()`. |
| `games/racing-carts/src/game.test.ts` | Vitest for `start` / `destroy` with a fake `Engine`. |
| `games/racing-carts/{GLOSSARY,ARCHITECTURE,FEATURES}.md` | Per-game docs. |

---

### Task 1: Godot project skeleton and web export

**Files:**
- Create: `scripts/godot.sh`, `games/racing-carts/scripts/export.sh`, `games/racing-carts/godot/project.godot`,
  `games/racing-carts/godot/export_presets.cfg`, `games/racing-carts/godot/scenes/stub_race.tscn` (empty `Node3D`
  for now)
- Modify: `.gitignore`, `games/racing-carts/package.json` (scripts), `eslint.config.js` (ignore `apps/shell/public/games/**`)

**Interfaces:**
- Produces: `npm run export -w racing-carts` writes `index.html`, `index.js`, `index.wasm`, `index.pck` and the two
  `index.audio*.worklet.js` files to `apps/shell/public/games/racing-carts/`. The engine file prefix is `index`.

- [ ] **Step 1:** Write `scripts/godot.sh` (`set -euo pipefail`, binary lookup per Global Constraints,
  `exec "$GODOT_BIN" "$@"`) and make it executable.
- [ ] **Step 2:** Create `project.godot`: `config/name="Racing Carts"`, `run/main_scene="res://scenes/stub_race.tscn"`,
  `config/features=PackedStringArray("4.7")`, Compatibility renderer (both keys),
  `physics/common/physics_ticks_per_second=60`.
- [ ] **Step 3:** Create `export_presets.cfg`: one preset `name="Web"`, `platform="Web"`,
  `export_filter="all_resources"`, `exclude_filter="addons/*, tests/*, .gutconfig.json"`,
  `variant/thread_support=false`, `variant/extensions_support=false`, `vram_texture_compression/for_desktop=true`,
  `progressive_web_app/enabled=false`, `html/export_icon=false`.
- [ ] **Step 4:** Write `games/racing-carts/scripts/export.sh`: `mkdir -p` the output folder, run
  `scripts/godot.sh --headless --path <godot dir> --import`, then
  `scripts/godot.sh --headless --path <godot dir> --export-release Web <out>/index.html`. Exit non-zero if
  `<out>/index.wasm` is missing (Godot can exit 0 on a failed export).
- [ ] **Step 5:** Add `"export": "bash scripts/export.sh"` to `games/racing-carts/package.json`. Add
  `games/racing-carts/godot/.godot/` and `apps/shell/public/games/` to `.gitignore`. Add
  `'apps/shell/public/games/**'` to the eslint `ignores`.
- [ ] **Step 6: Verify.** Run `npm run export -w racing-carts`. Expected: exit 0, the six files listed above exist,
  `index.wasm` is about 39 MB, and `git status` shows none of them.
- [ ] **Step 7: Commit** `build(racing-carts): Godot project and web export`.

### Task 2: GUT and the bridge codec

**Files:**
- Create: `godot/addons/gut/` (GUT v9.7.1 release zip, the `gut` folder only), `godot/.gutconfig.json`,
  `games/racing-carts/scripts/test-godot.sh`, `godot/scripts/bridge_codec.gd`, `godot/tests/test_bridge_codec.gd`
- Modify: `godot/project.godot` (enable the GUT plugin), `games/racing-carts/package.json` (`test` script)

**Interfaces:**
- Produces (`class_name BridgeCodec extends RefCounted`, all `static`):
  - `parse_players(json: String) -> Array[Dictionary]`: each `{ "slot": int, "name": String, "color": Color }`.
    Invalid JSON or entries are dropped.
  - `parse_inputs(json: String, slots: Array[int]) -> Dictionary`: slot → `{ "steer": float, "gas": bool,
    "brake": bool, "item": bool }`, for every slot in `slots`. Missing, unknown or malformed entries →
    `NEUTRAL` (`steer` clamped to −1..1).
  - `results_json(order: Array[int]) -> String`: `order` is slots from first to last; returns
    `[{"slot":s,"place":i+1},…]`.
  - `const NEUTRAL := { "steer": 0.0, "gas": false, "brake": false, "item": false }`
- Wire format (also used by Task 4): players JSON = `[{"slot":0,"name":"Alex","color":"#ff8fab"}]`; inputs JSON =
  object keyed by slot as a string, `{"0":{"steer":0.5,"gas":true,"brake":false,"item":false}}`.

- [ ] **Step 1:** Install GUT v9.7.1 into `godot/addons/gut/` per its Install page and enable it under
  `[editor_plugins]` in `project.godot`. Write `.gutconfig.json` (`dirs`, `include_subdirs`, `should_exit`,
  `log_level: 1`).
- [ ] **Step 2:** Write `scripts/test-godot.sh`: `--headless --import`, then
  `scripts/godot.sh --headless --path <godot dir> -s addons/gut/gut_cmdln.gd -gexit`. Set the package `test` script to
  `vitest run --passWithNoTests && bash scripts/test-godot.sh`.
- [ ] **Step 3: Write the failing tests** in `tests/test_bridge_codec.gd` (`extends GutTest`):

```gdscript
func test_parse_players_keeps_slots():
	var p = BridgeCodec.parse_players('[{"slot":0,"name":"Alex","color":"#ff0000"},{"slot":5,"name":"Bo","color":"#00ff00"}]')
	assert_eq(p.size(), 2)
	assert_eq(p[1].slot, 5)
	assert_eq(p[1].name, "Bo")
	assert_eq(p[0].color, Color("#ff0000"))

func test_parse_players_bad_json_is_empty():
	assert_eq(BridgeCodec.parse_players("not json").size(), 0)

func test_parse_inputs_reads_known_slots():
	var i = BridgeCodec.parse_inputs('{"2":{"steer":0.5,"gas":true,"brake":false,"item":true}}', [2])
	assert_eq(i[2].steer, 0.5)
	assert_true(i[2].gas)
	assert_true(i[2].item)

func test_parse_inputs_ignores_unknown_slots():
	var i = BridgeCodec.parse_inputs('{"9":{"steer":1,"gas":true,"brake":false,"item":false}}', [0])
	assert_eq(i.keys(), [0])
	assert_eq(i[0], BridgeCodec.NEUTRAL)

func test_parse_inputs_clamps_and_defaults():
	var i = BridgeCodec.parse_inputs('{"0":{"steer":7}}', [0, 1])
	assert_eq(i[0].steer, 1.0)
	assert_false(i[0].gas)
	assert_eq(i[1], BridgeCodec.NEUTRAL)

func test_results_json_places_in_order():
	assert_eq(JSON.parse_string(BridgeCodec.results_json([5, 0])), [{"slot": 5.0, "place": 1.0}, {"slot": 0.0, "place": 2.0}])
```

- [ ] **Step 4:** Run `npm test -w racing-carts`. Expected: GUT fails (no `BridgeCodec`).
- [ ] **Step 5:** Implement `bridge_codec.gd` to the Interfaces above (`JSON.parse_string`; JSON numbers arrive as
  float, so cast slots with `int()`).
- [ ] **Step 6:** Run `npm test -w racing-carts`. Expected: 6/6 passing, exit 0.
- [ ] **Step 7: Commit** `test(racing-carts): GUT and bridge codec`.

### Task 3: godot-ai addon (needs you)

**Files:**
- Create: `godot/addons/godot_ai/` (from the v4.4.1 release), `.mcp.json` (written by the addon's dock)
- Modify: `godot/project.godot` (plugin enabled)

- [ ] **Step 1:** Download both v4.4.1 plugin zips (`godot-ai-plugin.zip`, `godot-ai-v4-plugin.zip`), check each
  `.sha256`, and list their contents. Install the one whose layout is `addons/godot_ai/…` and whose `plugin.cfg` says
  4.4.1. If both qualify, take `godot-ai-plugin.zip` and say so in the commit message.
- [ ] **Step 2:** Enable the plugin in `project.godot`. Check `uv --version`; if uv is missing, stop and ask you to
  install it (its README's command).
- [ ] **Step 3 (you):**
  1. Open the project from the repo root: `/Applications/Godot.app/Contents/MacOS/Godot --path games/racing-carts/godot -e`.
  2. Set **Editor Settings → Plugins → `godot_ai/mcp_client_scope`** to `project`.
  3. Turn telemetry off.
  4. Press **Configure** next to Claude Code.
  5. Approve the server once by running `claude` in the repo.
  6. Restart this Claude Code session.
- [ ] **Step 4: Verify.** In the new session `.mcp.json` lists `godot-ai`, and the `editor_state` tool answers
  with the open project. `npm run export -w racing-carts` still produces no `addons/` files in the `.pck`
  (`strings index.pck | grep -c godot_ai` → 0).
- [ ] **Step 5: Commit** `build(racing-carts): godot-ai editor addon` (addon + `.mcp.json`).

From here on, scenes and scripts may be made through godot-ai's tools or written as files; the result must be the
same files.

### Task 4: TypeScript bridge helpers

**Files:**
- Create: `games/racing-carts/src/bridge.ts`, `games/racing-carts/src/bridge.test.ts`

**Interfaces:**
- Consumes: the wire format from Task 2.
- Produces:
  - `exportUrl(base: string, file: string): string`: `exportUrl('/couch-games/', 'index.js')` →
    `'/couch-games/games/racing-carts/index.js'`; works with or without a trailing slash on `base`.
  - `engineConfig(base: string, canvas: HTMLCanvasElement, onExit: (code: number) => void): Record<string, unknown>`:
    `{ executable: exportUrl(base,'index'), canvas, focusCanvas: false, canvasResizePolicy: 0, onExit, args: [] }`.
  - `encodePlayers(players: readonly Player[]): string`
  - `encodeInputs(inputs: ReadonlyMap<number, TiltRacerInput>): string`: the object keyed by slot.
  - `decodeResults(json: string, players: readonly Player[]): Result[]`: one entry per player, always. Valid entries
    for known slots keep their place. A duplicate slot keeps its first entry. Players missing or after bad JSON are
    placed after the rest, in slot order. Places are renumbered 1..n.

- [ ] **Step 1: Write the failing tests** in `bridge.test.ts`:
  - `exportUrl` with `'/couch-games/'` and with `'/'`;
  - `engineConfig` sets `focusCanvas: false` and `canvasResizePolicy: 0`;
  - `encodeInputs(new Map([[5, {steer:1,gas:true,brake:false,item:false}]]))` →
    `'{"5":{"steer":1,"gas":true,"brake":false,"item":false}}'`;
  - `decodeResults('[{"slot":2,"place":1},{"slot":0,"place":2}]', [p0, p2])` →
    `[{slot:2,place:1},{slot:0,place:2}]`;
  - `decodeResults('garbage', [p0, p2])` → `[{slot:0,place:1},{slot:2,place:2}]`;
  - `decodeResults('[{"slot":2,"place":1},{"slot":2,"place":2},{"slot":9,"place":3}]', [p0, p2])` →
    `[{slot:2,place:1},{slot:0,place:2}]`.
- [ ] **Step 2:** Run `npx vitest run -w racing-carts src/bridge.test.ts` (or `npm test -w racing-carts`). Expected:
  FAIL, module not found.
- [ ] **Step 3:** Implement `bridge.ts`.
- [ ] **Step 4:** Run the tests. Expected: all pass.
- [ ] **Step 5: Commit** `feat(racing-carts): bridge helpers`.

### Task 5: Stub race, `start` / `destroy`, Babylon removed

**Files:**
- Create: `godot/scripts/bridge.gd`, `godot/scripts/stub_race.gd`; fill in `godot/scenes/stub_race.tscn`
- Rewrite: `games/racing-carts/src/game.ts`, `games/racing-carts/src/game.test.ts`
- Delete: every other file in `games/racing-carts/src/` (Babylon code and its tests) and `docs/powerups.md`
- Move: `games/racing-carts/src/audio/files/*.mp3` → `games/racing-carts/godot/assets/sounds/` (`git mv`)
- Modify: `games/racing-carts/package.json` (`npm uninstall -w racing-carts @babylonjs/core`; keep `happy-dom` only if
  `game.test.ts` uses it), `scripts/e2e-serve.mjs` (`.wasm` → `application/wasm`, `.pck` →
  `application/octet-stream`), `e2e/racing.spec.ts`

**Interfaces:**
- Consumes: `BridgeCodec` (Task 2), everything in `bridge.ts` (Task 4).
- The global, set by `start` and deleted by `destroy`:

```ts
interface RacingCartsGlobal {
  players: string            // encodePlayers(round.players)
  inputs: string             // encodeInputs(latest input per slot), rewritten on every input()
  e2e: boolean               // import.meta.env.VITE_E2E === '1'
  ready(): void              // Godot calls once its scene runs
  finish(json: string): void // Godot calls once; game.ts → round.finish(decodeResults(json, round.players))
  karts?: string             // Godot writes [{"slot":0,"x":0,"z":0}] each physics tick when e2e is true
}
```

- `bridge.gd` (node in the stub scene):
  - `players: Array[Dictionary]`, `func input_for(slot: int) -> Dictionary`, `func send_finish(order: Array[int])`,
    `func report_karts(karts: Array[Dictionary])`.
  - On web (`OS.has_feature("web")`) it reads `racingCarts` each `_physics_process`.
  - Elsewhere it uses two players (slots 0 and 1, keyboard: arrows + Space as ITEM for slot 0), and `send_finish`
    prints the JSON and quits.
- `stub_race.gd`:
  - a floor plane, a camera looking down, and one `MeshInstance3D` box per player tinted with their colour;
  - GAS moves a box forward at 5 m/s, steer turns it at 2 rad/s;
  - the first rising edge of any player's ITEM finishes: that slot first, the rest in slot order.

- [ ] **Step 1: Write the failing Vitest tests** in `game.test.ts`, with a fake `Engine` on `globalThis` (records
  its config; `startGame` resolves; `requestQuit` calls `onExit(0)` unless the test says otherwise) and a stub
  `<script>` loader:
  - `start` appends one canvas to `el`, shows "Loading…", and sets `window.racingCarts.players` to
    `encodePlayers(players)`;
  - `ready()` removes "Loading…";
  - `input(2, {...})` updates `window.racingCarts.inputs`;
  - `finish('[{"slot":0,"place":1}]')` calls `round.finish` once with the decoded results; a second call is ignored;
  - `destroy()` calls `requestQuit`, then removes the canvas and deletes `window.racingCarts`;
  - `destroy()` with an `onExit` that never fires still cleans up after 2000 ms (fake timers);
  - `destroy()` before `startGame` resolves: the engine is quit once it resolves, and nothing throws.
- [ ] **Step 2:** Run `npm test -w racing-carts`. Expected: the new tests fail.
- [ ] **Step 3:** Implement `game.ts`.
  - `load()` adds `exportUrl(BASE_URL,'index.js')` as a `<script>` once and awaits it.
  - `start` keeps the canvas at `el`'s size with a `ResizeObserver`.
  - `destroy` waits `Promise.race([exit, 2000 ms])`, then calls `loseContext()` on the canvas's `webgl2` context if
    one exists, removes the canvas and deletes the global.
  - Declare `Engine` as an ambient type in `game.ts`.
- [ ] **Step 4:** Run `npm test -w racing-carts`. Expected: Vitest and GUT pass.
- [ ] **Step 5:** Build the stub: `bridge.gd`, `stub_race.gd`, `stub_race.tscn`.
  - *Verify:* press F5 in the editor (or `scripts/godot.sh --path games/racing-carts/godot`). Two boxes appear, the
    arrows drive slot 0, and Space prints `[{"slot":0,"place":1},{"slot":1,"place":2}]` and quits.
- [ ] **Step 6:** Delete the Babylon files, move the sounds, run the `npm uninstall`, then `npm run typecheck` and
  `npm run lint`. Expected: both clean.
- [ ] **Step 7: Rewrite `e2e/racing.spec.ts`.** Keep the four controller-only tests unchanged, and the "Center"
  test's controller half. Replace the race test with:
  - **`race in Godot: drive, finish on ITEM, results`:**
    1. Open Racing Carts.
    2. Expect `window.racingCarts` to exist and "Loading…" to disappear within 30 s.
    3. Hold GAS for 1 s and expect slot 0's `z` (from `racingCarts.karts`) to change.
    4. Tap ITEM, expect `#/results/racing-carts` and Alex in 1st place, then `pageerror` count 0.
  - **`Escape leaves a round and a second round starts`:**
    1. Escape: expect `#/`, no `canvas`, and `window.racingCarts` undefined.
    2. Open again and expect it ready within 30 s.
  - **`Escape while loading`:** open, press Escape at once, and expect `#/`, no canvas, no `window.racingCarts` and
    no page errors after 3 s.
- [ ] **Step 8:** Run `npm run e2e`. Expected: all pass.
  - If Godot fails to start in headless Chromium (WebGL2 missing), add
    `args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader']` to the Playwright project's `launchOptions`
    and rerun. Record what was needed.
- [ ] **Step 9: Commit** `feat(racing-carts): Godot stub race in the shell, Babylon removed`.

### Task 6: Build script and CI

**Files:**
- Modify: `scripts/build.sh`, `.github/workflows/deploy-web.yml`

- [ ] **Step 1:** In `build.sh`, run `npm run export -w racing-carts` before `npm run build -w @couch/shell`. After
  copying, fail if `$OUT/games/racing-carts/index.wasm` is missing.
- [ ] **Step 2: Verify.** Run `npm run build`. Expected: `output/games/racing-carts/index.{js,wasm,pck}` exist.
- [ ] **Step 3:** In the workflow, before `npm test`, add a Godot setup step:
  - `actions/cache` on `~/godot` and `~/.local/share/godot/export_templates/4.7.1.stable`, key `godot-4.7.1`.
  - On a cache miss:
    1. Download `Godot_v4.7.1-stable_linux.x86_64.zip` and `Godot_v4.7.1-stable_export_templates.tpz` from
       `https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/`.
    2. Check the sha256 values below.
    3. Unzip the editor into `~/godot`.
    4. Extract only `templates/web_nothreads_release.zip` and `templates/version.txt` from the `.tpz` into the
       templates folder.
    5. Delete the `.tpz` (1.19 GB).
  - Then `echo "GODOT=$HOME/godot/Godot_v4.7.1-stable_linux.x86_64" >> $GITHUB_ENV`.
  - sha256 values:
    - editor: `c7ff14fd28472c8d4f193043de30278dcf7e5241a1dcf7566b02e27addaa33ba`
    - templates: `86409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72`
- [ ] **Step 4: Verify.** Push the branch and open a draft PR (ask first). Expected: the workflow passes. If the export
  reports a missing template, the error names the folder Godot looked in; move the files there and rerun.
- [ ] **Step 5: Commit** `ci: install Godot 4.7.1 and export Racing Carts`.

### Task 7: Docs

**Files:**
- Create: `games/racing-carts/GLOSSARY.md`, `games/racing-carts/ARCHITECTURE.md`, `games/racing-carts/FEATURES.md`
- Modify: root `GLOSSARY.md`, `ARCHITECTURE.md`, `FEATURES.md`, `CLAUDE.md` (Domain docs: per-game docs live in
  `games/<id>/`), `docs/audio-assets.md` (file paths)

- [ ] **Step 1: The game's `ARCHITECTURE.md`:**
  - the bridge and global from Task 5;
  - export and serving, as the one exception to "assets are imported";
  - the restart findings: hidden tab, 2 s timeout, `loseContext`;
  - the Godot project layout;
  - running and testing (`npm run export`, `npm test`, F5 in the editor, `GODOT`);
  - godot-ai.
- [ ] **Step 2: The game's `FEATURES.md`:**
  - F12–F27 moved over, rewritten to the spec §6–§8;
  - each feature marked *built* or *planned (milestone n)*;
  - the stub race as *built (milestone 1, temporary)*.
- [ ] **Step 3: The game's `GLOSSARY.md`:**
  - the race, kart and item terms moved from the root `GLOSSARY.md`;
  - drift and slipstream dropped, mine → banana;
  - new terms: mud, view, chase camera, bridge, export.
- [ ] **Step 4: Root docs.** Remove the moved sections. Leave one line per doc linking to the game's docs, and update
  the workspace table (`racing-carts` depends on `@couch/shared` and Godot, no Babylon).
- [ ] **Step 5: Verify.** `grep -rn "babylon\|Babylon\|powerups.md\|slipstream" *.md games/racing-carts/*.md docs/audio-assets.md`.
  Expected: no hits except in the history of `docs/superpowers/`.
- [ ] **Step 6: Commit** `docs(racing-carts): per-game glossary, architecture and features`.

### Task 8: Milestone 1 checks (spec §4)

No new code unless a check fails. The results go in the game's `ARCHITECTURE.md` and are reported to you.

- [ ] **Step 1: Restarts.**
  1. Serve `output/` (`node scripts/e2e-serve.mjs` after `npm run build:e2e`) with the browser pane **visible**.
  2. Open and leave Racing Carts 20 times with the host keyboard (Enter, wait for ready, Escape).
  3. Read **all** console levels. Expected: no "Too many active WebGL contexts", no context-lost warnings, no
     errors, and every start ready.
  4. Note memory from the browser's task manager if it's available; otherwise record it as not measured.
- [ ] **Step 2: Keyboard.** During a round: Escape leaves it (covered by e2e). Enter and Backspace do nothing in the
  round and still work on the results screen.
- [ ] **Step 3: Audio.**
  1. Add a `page.addInitScript`-style wrapper in the pane that records every `AudioContext` and its `state`.
  2. Start a round from the phone, then press a key on the host.
  3. Expected: Godot's context is `running`.
  4. If it stays `suspended`, `game.ts` resumes recorded contexts on the next host `keydown` / `pointerdown`. That is
     a Vitest test plus a small change, committed as `fix(racing-carts): resume Godot audio on host input`.
- [ ] **Step 4:** Report the three results to you, along with the restart-test numbers from the brainstorm.
