# Racing Carts in Godot: Design Spec

Date: 2026-11-10
Status: Draft for review

Items marked **(default, confirm in review)** are my picks that you have not chosen yourself.

## 1. Intent

Rebuild Racing Carts in Godot 4.7.1 as a web export that runs inside the Couch Games shell, and change the
gameplay along the way: a camera per player in split screen, looser handling, mud, bananas, bouncier collisions,
a longer track, and a livelier world with particles.

**Success:** from the library, a party of 1–6 opens Racing Carts, everyone drives their own kart in their own view
with the same tilt controller as today, and the round ends on the shell's results screen with the finishing order.

### Decisions made during brainstorming

| Topic | Decision |
|---|---|
| Engine | Godot 4.7.1, GDScript |
| Renderer / export | Compatibility (WebGL2) renderer, Web export **without threads**. Laptop/PC browser is the target; this keeps a TV and GitHub Pages (no COOP/COEP headers) possible. |
| Integration | Plugged into the shell; the game contract (`start` / `input` / `finish` / `destroy`) stays. |
| Embedding | **In the shell page**, not an iframe: the Godot `Engine` runs on a canvas inside the round's `<div>`. |
| Players | 1–6 humans, each with their own view. Bots fill the remaining karts up to 6. |
| Cameras | One third-person chase camera per player, split-screen layouts in §6. |
| Look | Cozy pastel low-poly, kept. Meshes come from editor scenes, Godot primitives/CSG and imported low-poly models, **not from code**. |
| Removed | Drift and mini-turbo (F17), slipstream (F19), the one shared camera (F25). |
| Changed | Mine → banana. Looser steering with sliding. Kart–kart bounce like walls. Fixed, bigger bounces for boosted hits. Longer track, more boost pads. |
| Added | Mud that slows. Particles. A livelier environment. |
| Tooling | [godot-ai](https://github.com/hi-godot/godot-ai) editor addon + MCP for building scenes and scripts. |
| Docs | Per-game `GLOSSARY.md`, `ARCHITECTURE.md`, `FEATURES.md` in `games/racing-carts/`. |

### Out of scope

Multiple tracks, kart choice, online play, settings screens, changes to the phone controller or the shell's
screens, a TV build test.

## 2. What the restart test showed

A throwaway test (blank Godot 4.7.1 project, Compatibility, no threads, ~39 MB `.wasm`) started, quit and restarted
the engine in one page on a fresh canvas each time:

- 6 of 6 cycles started, ran and quit with exit code 0, with no console errors. First start ~2.2 s, later starts
  ~0.75 s (the `.wasm` is cached).
- **When the page is hidden, `requestQuit()` never completes**: Godot's main loop runs on `requestAnimationFrame`,
  which stops in a hidden tab. `destroy()` must therefore not wait for the quit forever (§4).
- **Not measured yet:** whether WebGL contexts and wasm memory are freed over 20+ cycles. Chrome keeps about 16
  live WebGL contexts, so §4 releases each context explicitly regardless. Milestone 1 reruns the long test.

## 3. Repository layout

```
games/racing-carts/
  index.ts            game contract (unchanged shape), cover.png
  package.json        no Babylon; scripts: test (GUT), export
  src/game.ts         the bridge: starts/stops the Godot Engine, passes players, input and finish
  src/bridge.ts       pure helpers (engine config, input packing), unit-tested with Vitest
  godot/              the Godot project
    project.godot     Compatibility renderer, 60 Hz physics
    export_presets.cfg  "Web" preset: no threads, addons/ and tests/ excluded
    addons/godot_ai/  editor tooling (not exported)
    addons/gut/       unit tests (not exported)
    scenes/           race.tscn, kart.tscn, track.tscn, hud.tscn, items/…
    scripts/          GDScript (see §5)
    assets/           models (.glb), sounds (moved from src/audio/files), textures
    tests/            GUT tests
  GLOSSARY.md  ARCHITECTURE.md  FEATURES.md
```

The Babylon.js code (`src/` except the bridge), `@babylonjs/core` and `docs/powerups.md` are removed in
milestone 1. `docs/audio-assets.md` stays, with paths updated. The root docs keep a short Racing Carts entry
that links to the game's own docs; F12–F27 move to `games/racing-carts/FEATURES.md`, rewritten for this design.

## 4. The bridge (shell ↔ Godot)

### Export and serving

The Godot export cannot be a Vite import (a 39 MB `.wasm`, a `.pck`, worklets). This is the one exception to
"assets are imported, never served from `public/`", and `ARCHITECTURE.md` records it.

- `npm run export -w racing-carts` runs
  `$GODOT --headless --path games/racing-carts/godot --export-release Web <out>/index.html` into
  `apps/shell/public/games/racing-carts/` (gitignored). Vite serves it in dev and copies it into `output/` on build.
- `GODOT` defaults to `godot`; on macOS you set it to `/Applications/Godot.app/Contents/MacOS/Godot`.
- `scripts/build.sh` runs the export before the shell build and fails if the export fails.
- The URLs are built from `import.meta.env.BASE_URL` (`/couch-games/` in production): `index.js` is added as a
  `<script>` tag on the first `load()`; `executable` and `mainPack` point at the same folder.

### Round lifecycle

`start(round)`:
1. Creates a canvas filling `round.el`.
2. Sets one global, `window.racingCarts`, holding `players` (JSON), `inputs` (one entry per slot), `e2e`
   (true only in `VITE_E2E` builds) and a `finish(json)` callback.
3. Starts a new `Engine({ executable, canvas, focusCanvas: false, canvasResizePolicy: 0, onExit })` and calls
   `startGame({ mainPack })`. With policy 0 Godot leaves the canvas size alone; the bridge keeps it at the size of
   `round.el` with a `ResizeObserver`.
4. Shows "Loading…" in `round.el` until Godot reports it is ready.

`input(slot, input)` only writes `window.racingCarts.inputs[slot]`. **Godot pulls**: each physics tick it reads
`inputs` through `JavaScriptBridge.get_interface("racingCarts")`. No per-message callbacks cross into Godot, which
avoids `create_callback` lifetime problems and keeps 6 × 30 Hz input cheap.

When the race ends, Godot calls `racingCarts.finish('[{"slot":0,"place":2},…]')` (one `create_callback` the other
way, kept as a member variable). The bridge decodes it and calls `round.finish`.

`destroy()` (at most once):
1. Calls `engine.requestQuit()` and waits for `onExit`, at most 2 s (a hidden tab never quits, §2).
2. Releases the WebGL context (`WEBGL_lose_context.loseContext()`).
3. Removes the canvas and deletes `window.racingCarts`.

Only one round runs at a time, so one global is enough.

### Checks for milestone 1

- **Keyboard:** Escape, Enter and Backspace still reach the shell while the Godot canvas is mounted
  (`focusCanvas: false`). If Godot swallows them, the bridge adds a capture-phase listener for those keys.
- **Audio:** as today, sound may start only after the first key or pointer press on the host page. A round started
  from a phone press has no host gesture. If Godot's AudioContext stays suspended after a later host press, the
  bridge resumes it on the next key or pointer press.
- **Restarts:** 20 start/quit cycles in one page with no "too many WebGL contexts" warning.

## 5. The game in Godot

Native Godot features first, so there is little code:

| Thing | Godot feature |
|---|---|
| Track centre line | `Path3D` / `Curve3D` (one source for road, walls, bots, rockets and lap progress) |
| Road, kerbs, walls | `CSGPolygon3D` in path mode, plus a static collider |
| Kart | `CharacterBody3D` + `move_and_slide()`; model from a `.glb` |
| Lap progress / race order | `Curve3D.get_closest_offset()` + lap count |
| Boost pads, mud, item boxes, bananas | `Area3D` |
| Particles | `GPUParticles3D` (supported in Compatibility); `CPUParticles3D` where a TV would struggle |
| Sky and light | `WorldEnvironment` (procedural sky), one `DirectionalLight3D` |
| Split screen | `SubViewportContainer` + `SubViewport` per player, sharing one `World3D` |
| Sound | `AudioStreamPlayer` / `AudioStreamPlayer3D`, current mp3 files |

### Scripts (`godot/scripts/`)

- `race.gd`: phases (countdown → racing → done), lap counts, order, the finish rule, calling the bridge.
- `bridge.gd`: reads players and inputs from `window.racingCarts`, sends results. Outside the web build (editor, GUT)
  it falls back to keyboard input for slot 0, so the game runs with F5.
- `kart.gd`: driving, sliding, bounces, spin-out, boost, mud, catch-up.
- `bot.gd`: follows the path with a lane offset, a per-bot speed and reaction time, slows in sharp corners, and uses
  items through each item's `bot_should_use`.
- `items/`: one script per item plus `items/registry.gd`. A new item is one file plus one registry line.
- `views.gd`: builds the split-screen layout and a chase camera per player.
- `hud.gd`: per-view HUD and the countdown.
- Pure rules (order and ranking, finish timing, odds, bounce values, catch-up) live in small `RefCounted` scripts
  that GUT tests without a scene.

## 6. Gameplay

Kept from today:
- 6 karts, 3-2-1-GO, inputs ignored until GO, 3 laps.
- The round ends when every player has finished, or 30 s after the first player finishes. Results give each
  player's place among all karts.
- Phone: tilt to steer, **Center**, GAS, BRAKE (brake, then reverse), ITEM (one press, one use).
- Spin-out 1.2 s on a hit, no elimination, no respawn.
- Boost pads (1 s boost, never cuts a longer one short).
- Catch-up: up to +6 % top speed for last place, paused while touching a wall and for 2 s after.
- Item boxes: one held item, ~1 s roll, odds weighted by position, respawn after 3 s.
- Bots fill every kart nobody drives.

Changed or new:

- **Steering with slide.** Lateral grip drops, so the kart drifts outward in fast corners and the back steps out a
  little, while low speed stays tight. No drift button. Grip about half of today's value, tuned by feel
  **(default, confirm in review)**. A dust trail shows while sliding.
- **Bounces with fixed values, no speed-based maths.** A wall or another kart pushes the kart back along the contact
  normal at a fixed speed **(defaults, confirm in review)**:

  | Hit | Bounce speed |
  |---|---|
  | Wall | 4 m/s, plus today's wall speed loss |
  | Kart vs kart | each kart 3 m/s apart |
  | Boosted kart into a wall | 7 m/s |
  | Boosted kart into a kart | the other kart 8 m/s, the booster 2 m/s |

  A boosted hit does not spin anyone out.
- **Banana** replaces the mine: dropped behind the kart, the first kart over it spins out for 1.2 s, the owner is safe
  for 0.5 s. Bot odds and use rules stay those of the mine.
- **Mud:** brown patches on parts of the track. While on mud, top speed is 50 % **(default, confirm in review)**, with a
  splash of particles and a squelch sound. About 4 patches, placed where they tempt a shortcut.
- **Longer track:** about twice today's length, with at least twice as many boost pads, and still 3 laps
  **(default, confirm in review)**.

Items: 🛡️ shield (absorbs the next hit, or lasts 6 s), ⚡ boost (+60 % top speed for 1.5 s), 🍌 banana, 🚀 rocket
(follows the path and homes in on the next kart ahead; with nobody ahead it flies straight and pops on a wall).

## 7. Cameras, split screen and HUD

Each player sees their own kart from a third-person chase camera behind and above it, which eases behind the
kart's heading. A hit on that player's kart shakes only their view.

```
1        2          3            4            5              6
[ 1 ]    [1][2]     [1][2]       [1][2]       [1][2][3]      [1][2][3]
                    [  3  ]      [3][4]       [ 4 ][ 5 ]     [4][5][6]
```

Views are in party-slot order, and each has a thin border in the player's colour.

**Per-view HUD (default, confirm in review):**
- place ("2nd"), lap ("2/3") and the held item (🎲 while rolling), text large enough to read from the couch;
- "FINISHED" with the place when that player is done.

The countdown is drawn once across the whole screen. Today's race list is dropped, because each view shows its own
place.

## 8. Look and environment

- Cozy pastel, toy-like low-poly world under warm sunny light and a soft sky gradient.
- Low-poly models from **Kenney's CC0 packs** (racing, nature) as `.glb` **(default, confirm in review)**, recoloured to
  the pastel palette. Primitives and CSG where a pack has nothing that fits.
- Karts are tinted with the player's colour, the same colour as in the party bar and on the phone.
- Livelier scenery: hills, trees, rocks, a pond, a start arch with bunting, fences and flowers, plus moving things:
  a turning windmill, floating balloons, drifting clouds, flags waving, and a few animated spectators.
- **Particles:**
  - boost flame;
  - dust while sliding;
  - sparks on wall and kart bounces (bigger on a boosted hit);
  - mud splash;
  - stars on a banana slip;
  - rocket trail and burst;
  - item-box burst on pickup;
  - pad flash;
  - finish confetti;
  - drifting leaves or petals around the track.
- Sound: all current effects and music (the mine sounds become banana sounds), one engine loop per human kart with
  pitch following speed, and a new mud sound. A missing file stays silent.

## 9. godot-ai and testing

**godot-ai:**
- Install v4.4.1 from its GitHub release into `godot/addons/godot_ai/` and enable the plugin.
- Telemetry off (`GODOT_AI_DISABLE_TELEMETRY=true`). Needs `uv`.
- Register the MCP server for Claude Code from the addon's dock with **project** scope, so the setting lives in the
  repo (`.mcp.json`) and not in your global config **(default, confirm in review)**.
- The editor must be open with the plugin enabled. The tools appear only in a Claude Code session started after
  registration, so the plan includes a "restart the session" step for you.

**Tests:**
- **GUT** for GDScript tests, installed per its official docs. godot-ai's own test runner only runs inside the open
  editor, while GUT runs headless (`godot --headless -s addons/gut/gut_cmdln.gd`), so CI can run it.
  `npm test -w racing-carts` runs GUT; tests live in `godot/tests/`.
  - **Pure rules:** ranking and laps, the finish rule, odds, bounce values, catch-up, mud.
  - **Scene tests:** step physics on a small test track and check, for example, that a kart bounces off a wall at
    4 m/s, a banana spins a kart, and mud slows it.
- **Vitest** for `src/bridge.ts`: engine config and URLs under a base path, input packing, results decoding.
- **Playwright e2e** (`e2e/racing.spec.ts`, rewritten): the lead opens Racing Carts, the Godot canvas starts, tilt
  input moves slot 0's kart (Godot reports kart positions on `window.racingCarts` in e2e builds), and an e2e-only
  `finishNow` flag ends the race with the current order, landing on the results screen. Escape leaves a round.
- **CI** (`deploy-web.yml`): download and cache Godot 4.7.1 (Linux x86_64) and the web export templates before
  `npm test`, `npm run e2e` and `npm run build`. Export output is never committed.

## 10. Milestones

Each milestone ends with its own verification and doc updates.

1. **Plumbing.**
   - Godot project (Compatibility, no-threads web preset), godot-ai and GUT installed.
   - Bridge, export in build and dev, CI with Godot.
   - A stub race: cubes in player colours driven by input, which finishes on the e2e flag.
   - Babylon code removed. Per-game docs started.
   - *Verify:* Vitest, GUT and the e2e test pass in CI; the §4 checks (keyboard, audio, 20 restarts) pass.
2. **Race core.**
   - Longer track (Path3D + CSG), kart handling with slide, fixed bounces.
   - Laps, countdown, finish rule, bots, boost pads, mud, catch-up.
   - One temporary follow camera.
   - *Verify:* GUT rule and scene tests pass; a full race with bots finishes in the shell.
3. **Items.**
   - Boxes, roll and odds, registry; shield, boost, banana, rocket; bots use items.
   - *Verify:* GUT tests per item; manual race.
4. **Split screen and HUD.**
   - Layouts for 1–6, chase cameras, per-view HUD, per-view shake.
   - *Verify:* e2e with 1, 3 and 6 players checks the view count; screenshots at each layout.
5. **Look, environment, particles, sound.**
   - Models, scenery and animation, every particle effect in §8, audio.
   - *Verify:* screenshots; a 6-view race holds about 60 fps on your laptop.

## 11. Risks

- **WebGL in headless Chromium for e2e.** Playwright's Chromium renders WebGL2 in software. If Godot fails there,
  e2e runs Chromium with GPU flags or in headed mode under `xvfb` in CI.
- **6 views on a laptop.** Low-poly scenes, one light, shadows off in the smaller views; particle counts kept low.
- **Download size.** ~39 MB `.wasm` on first open (cached after). Acceptable on a laptop; the round shows
  "Loading…" until Godot is ready.

## 12. Way of working

All work happens on a branch, `racing-carts-godot`, and merges once milestone 5 is done. `main` keeps the
Babylon game until then.
