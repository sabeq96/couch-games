# Racing Carts: architecture

How Racing Carts, a Godot 4.7.1 web export embedded in the shell, is put together. Words: [GLOSSARY.md](GLOSSARY.md).
What it does: [FEATURES.md](FEATURES.md). Site-wide architecture: [../../ARCHITECTURE.md](../../ARCHITECTURE.md).
Design and milestones: [spec](../../docs/superpowers/specs/2026-11-10-racing-carts-godot-design.md).

The game contract is the shell's: `index.ts` exports a config with layout `tilt-racer` and 1–6 players, and `src/game.ts`
exports `start(round)` returning `{ input, destroy }`. Everything inside is the game's own. Status: milestone 1
(plumbing) is built, so the race is a stub; the rest is planned in the spec.

## Overview

```
 shell page                                   Godot (same page, own canvas)
┌──────────────────────────────┐   window.racingCarts   ┌───────────────────────────┐
│ src/game.ts   start/destroy  │──── players, inputs ──▶│ scripts/bridge.gd         │
│ src/bridge.ts pure helpers   │◀─── ready, finish ─────│ scripts/stub_race.gd      │
└──────────────────────────────┘                        └───────────────────────────┘
```

Godot runs on a canvas inside the round's `<div>`, not in an iframe. The renderer is Compatibility (WebGL2) and the
web export has no threads, so no COOP/COEP headers are needed (GitHub Pages cannot set them).

## Repository layout

```
games/racing-carts/
  index.ts              game contract, cover.png
  package.json          scripts: export, test (Vitest, then GUT), typecheck
  src/game.ts           start/destroy: loads the export, starts and stops the Godot Engine
  src/bridge.ts         pure helpers (URLs, engine config, JSON codec), Vitest-tested
  scripts/export.sh     the web export
  scripts/test-godot.sh the GUT run
  godot/                the Godot project
    project.godot       Compatibility renderer (also for mobile), 60 Hz physics, main scene stub_race.tscn
    export_presets.cfg  "Web" preset: no threads, excludes addons/*, tests/*, .gutconfig.json
    scenes/             stub_race.tscn (temporary)
    scripts/            bridge.gd, bridge_codec.gd, stub_race.gd
    assets/sounds/      the 21 mp3 files (silent placeholders, not played yet)
    addons/gut/         GUT 9.7.1, unit tests (not exported)
    addons/godot_ai/    godot-ai editor addon, exposes the editor to the MCP server (not exported)
    tests/              GUT tests
```

Planned (milestones 2 to 5): `race.gd`, `kart.gd`, `bot.gd`, `items/`, `views.gd`, `hud.gd`, the track, kart, HUD and
item scenes and models. See spec §5.

## Export and serving

The Godot export (a ~39 MB `.wasm`, a `.pck`, audio worklets) cannot be a Vite import. It is **the one exception to
"assets are imported, never served from `public/`"** (root [ARCHITECTURE.md](../../ARCHITECTURE.md#game-contract)).

- `npm run export -w racing-carts` (`scripts/export.sh`) clears the previous `index.*`, runs `--import`, then
  `--export-release Web` into `apps/shell/public/games/racing-carts/` (gitignored, never committed). It fails if
  `index.wasm` is missing, because Godot can exit 0 on a failed export.
- Vite serves that folder in dev and copies it into `output/` on build. `scripts/build.sh` runs the export before the
  shell build and fails if `output/games/racing-carts/index.wasm` is missing.
- URLs come from `import.meta.env.BASE_URL` (`/couch-games/` in production), via `exportUrl(base, file)`. `index.js` is
  added as a `<script>` tag on the first `load()` (a failed load is retried next round); `executable` and `mainPack`
  point at the same folder.
- `scripts/e2e-serve.mjs` serves `.wasm` as `application/wasm` and `.pck` as `application/octet-stream`.

## The bridge

Only one round runs at a time, so one global is enough: `window.racingCarts`.

| Field | Direction | Meaning |
| --- | --- | --- |
| `players` | page → Godot | JSON `[{slot, name, color}]`. |
| `inputs` | page → Godot | JSON `{ "<slot>": {steer, gas, brake, item} }`, rewritten on every `input()`. |
| `e2e` | page → Godot | `true` only in `VITE_E2E` builds. |
| `ready()` | Godot → page | Removes "Loading…". |
| `finish(json)` | Godot → page | `[{slot, place}]`, decoded to results (see below), then `round.finish`. Ignored after the first call or after `destroy`. |
| `karts` | Godot → page | e2e builds only: JSON `[{slot, x, z}]`, written every tick so tests can see karts move. |

**Godot pulls.** `input(slot, input)` only writes the global. `Bridge` (`bridge.gd`, physics priority −1 so it runs
before the race) takes `JavaScriptBridge.get_interface("racingCarts")` once and parses `inputs` every physics tick.
No per-message callback crosses into Godot. `bridge_codec.gd` holds the pure parsing and is tested with GUT;
missing or malformed inputs are neutral. Outside the web (editor F5, GUT) `Bridge` plays two players itself: slot 0
on the keyboard (arrows, Space for ITEM), slot 1 idle; `send_finish` prints the results and quits.

`decodeResults` always returns one result per player: unknown, duplicate or malformed entries are dropped and missing
players are placed last, in slot order.

### Round lifecycle (`src/game.ts`)

`start(round)`:
1. Appends a canvas and a "Loading…" element to `round.el`. The canvas has a **unique id per round**
   (`racing-carts-<n>`): Godot 4.7.1 finds its canvas by a `#id` selector (no id throws "'#' is not a valid
   selector"), and an old canvas can still be in the page while it quits.
2. Keeps the canvas at the size of `round.el` with a `ResizeObserver` (`canvasResizePolicy: 0` leaves it to the page).
3. Loads `index.js` and waits for the previous round's teardown (`previousTeardown`). Only then does it set
   `window.racingCarts` and start `new Engine({ executable, canvas, focusCanvas: false, canvasResizePolicy: 0, onExit })`
   with `startGame({ mainPack })`. Engine lifetimes never overlap: a round left while loading has quit before the next
   one starts, so an old engine never reads the new round's global or owns its audio. The wait is capped at **5000 ms**
   and a failed teardown is ignored, so an old Godot stuck downloading never blocks later rounds.
4. A start failure is logged and "Loading…" becomes "Racing Carts could not start".

`destroy()` (at most once):
1. Disconnects the observer. If the engine has not started yet it never will.
2. Calls `engine.requestQuit()` and waits for `onExit`, **at most 2000 ms**.
3. Calls `WEBGL_lose_context.loseContext()` on the canvas (only if the engine started, so no new context is made).
4. Removes the canvas and deletes `window.racingCarts`. This teardown is the next round's `previousTeardown`.

### Restart findings

From the spec's restart test (a blank project, 6 of 6 start/quit cycles clean) and the M1 e2e work:

- **A hidden tab never quits.** Godot's main loop runs on `requestAnimationFrame`, which stops in a hidden tab, so
  `requestQuit()` never completes. Hence the 2 s timeout.
- **WebGL contexts are released explicitly** with `loseContext()`: Chrome keeps about 16 live contexts. Whether
  contexts and wasm memory are freed over 20+ cycles is checked in M1 (the 20-restart check).
- **Audio worklet race.** Godot 4.7.1 loads its audio worklets with
  `addModule().then(() => new AudioWorkletNode(GodotAudio.ctx, …))`. Quitting clears `GodotAudio.ctx` first, so a quit
  before the worklets load (about 900 ms after start) throws "Failed to construct 'AudioWorkletNode'" as an
  **unhandled rejection**. `game.ts` has a page-lifetime `unhandledrejection` filter (`ignoreAudioAfterQuit`) that
  calls `preventDefault()` only for a `TypeError` whose message contains `AudioWorkletNode`; other rejections still
  surface. It is page-lifetime because the rejection can arrive after the round has cleaned up. It works around an
  engine bug: **recheck it on every Godot upgrade** and remove it when the engine is fixed.
- **Audio contexts.** `requestQuit()` leaves Godot's AudioContext open and running (20 rounds left 20). `game.ts`
  wraps `window.AudioContext` once, files each new context under the round whose engine is running, closes that
  round's contexts in `destroy()` after the quit wait, and while the round runs resumes a suspended one on the host
  page's next keydown or pointerdown.
- **Keyboard.** With `focusCanvas: false`, Escape, Enter and Backspace still reach the shell while the canvas is
  mounted (covered by e2e).

## Running and testing

| Command | What it does |
| --- | --- |
| `npm run export -w racing-carts` | The web export above. |
| `npm test -w racing-carts` | Vitest (`src/*.test.ts`), then GUT headless (`scripts/test-godot.sh`: `--import`, then `-s addons/gut/gut_cmdln.gd -gexit` with `godot/.gutconfig.json`, tests in `godot/tests/`). `npm test` at the root runs it too. |
| F5 in the Godot editor | Runs the project outside the shell; `Bridge` falls back to keyboard input. Open `godot/` as the project. |
| `npm run e2e` | Playwright `e2e/racing.spec.ts` against the built site: the Godot canvas starts, GAS moves slot 0's box (read from `karts`), ITEM reaches the results screen, Escape leaves a round (also while loading) and a second round starts. Default headless Chromium renders Godot's WebGL2 without extra flags. |

**The Godot binary** always comes from `scripts/godot.sh`: `$GODOT` if set, else `/Applications/Godot.app/Contents/MacOS/Godot`
if it exists, else `godot` on `PATH`. It needs Godot 4.7.1 with the web export templates installed.

Pure rules are tested with GUT without a scene (`RefCounted` scripts); scene tests, Vitest for `bridge.ts` and
Playwright for flows follow the spec §9.

## CI

`.github/workflows/deploy-web.yml` installs Godot before `npm test`, `npm run e2e` and `npm run build`:

- `scripts/ci-install-godot.sh` downloads the Godot 4.7.1 Linux x86_64 editor and the export templates, checks both
  SHA-256 sums, puts the editor in `~/godot` and the templates in `~/.local/share/godot/export_templates/4.7.1.stable`.
  **Only the web no-threads release template is kept** (`web_nothreads_release.zip` and `version.txt`), to keep the
  cache small.
- `actions/cache` stores both folders under the key `godot-4.7.1`; the install runs only on a cache miss. Changing the
  Godot version means changing the key, the script's version, URLs and checksums, and the `GODOT` path together.
- A step sets `GODOT=$HOME/godot/Godot_v4.7.1-stable_linux.x86_64` for the later steps.

## godot-ai and the Godot MCP server

The [godot-ai](https://github.com/hi-godot/godot-ai) editor addon (v4.4.1, `godot/addons/godot_ai/`) stays enabled
in the project: it exposes the open editor to the MCP server registered in `.mcp.json`,
[@coding-solo/godot-mcp](https://www.npmjs.com/package/@coding-solo/godot-mcp) (server `godot`). It is not exported.

## Adding a feature

- **A new item:** *(planned, M3)* one script in `godot/scripts/items/` plus one line in `items/registry.gd`.
- **A new rule** (ranking, odds, bounces…): a pure `RefCounted` script with a GUT test, so the scene only wires it.
- **A new bridge field:** one entry in `RacingCartsGlobal` and `bridge.ts` on the page side, one in `bridge.gd` and
  `bridge_codec.gd` on the Godot side, each with a test.
