# Racing Carts: architecture

How Racing Carts, a Godot 4.7.1 web export embedded in the shell, is put together. Words: [GLOSSARY.md](GLOSSARY.md).
What it does: [FEATURES.md](FEATURES.md). Site-wide architecture: [../../ARCHITECTURE.md](../../ARCHITECTURE.md).
Design and milestones: [spec](../../docs/superpowers/specs/2026-11-10-racing-carts-godot-design.md).

The game contract is the shell's: `index.ts` exports a config with layout `tilt-racer` and 1–6 players, and `src/game.ts`
exports `start(round)` returning `{ input, destroy }`. Everything inside is the game's own. Status: milestones 1
(plumbing), 2 (race core: track, karts, bots, laps, results), 3 (items), 4 (split screen with a HUD per view) and
5 (look, particles, sound) are built.

## Overview

```
 shell page                                   Godot (same page, own canvas)
┌──────────────────────────────┐   window.racingCarts   ┌───────────────────────────┐
│ src/game.ts   start/destroy  │──── players, inputs ──▶│ scripts/bridge.gd         │
│ src/bridge.ts pure helpers   │◀─── ready, finish ─────│ scripts/race.gd           │
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
    project.godot       Compatibility renderer (also for mobile), 60 Hz physics with interpolation, main scene race.tscn
    export_presets.cfg  "Web" preset: no threads, excludes addons/*, tests/*, .gutconfig.json
    scenes/             race.tscn (main: Track, Bridge, ItemWorld, Fx, Sfx, Views, the full-screen countdown), track.tscn
                        (centre line Curve3D, CSG road and walls, boost pads, mud, Scenery), kart.tscn (Kenney kart
                        model, cylinder collider, Area3D sensor for pads and mud), scenery/ (windmill, balloon, cloud,
                        flag, spectator, start arch, pond, hills, greenery), fx/ (12 particle scenes)
    scripts/            bridge.gd, bridge_codec.gd, race.gd (wiring), race_rules.gd (pure), bot.gd (BotDriver),
                        track.gd, track_progress.gd (lap counting), kart.gd, kart_physics.gd (pure handling and
                        bounce rules), kart_tuning.gd (all kart values), items/ and the item entities, views.gd,
                        view_layout.gd (pure), chase_camera.gd, view_hud.gd, fx.gd, fx_toggle.gd, sfx.gd
    tools/              dress_track.gd (greenery generator), fps_probe.gd (6-view fps probe); not exported
    assets/models/      Kenney Car Kit and Nature Kit .glb files with their licences (CC0)
    assets/sounds/      the 22 mp3 files (silent placeholders), played by Sfx (sfx.gd: one-shots, race music, engine loops)
    addons/gut/         GUT 9.7.1, unit tests (not exported)
    addons/godot_ai/    godot-ai editor addon, exposes the editor to the MCP server (not exported)
    tests/              GUT tests
```

## Look, particles and sound (milestone 5)

### Assets and licences

Models come from [kenney.nl](https://kenney.nl), all CC0 1.0. Each pack's `License.txt` and a README naming its source
sit next to the files in `godot/assets/models/<pack>/`. Only the files in use are copied.

| Pack | Used |
| --- | --- |
| [Car Kit 3.1](https://kenney.nl/assets/car-kit) | `kart-oobi.glb` and its colormap: the kart body, wheels and driver |
| [Nature Kit 2.1](https://kenney.nl/assets/nature-kit) | trees, bush, stones, flowers, fence, lily pad |

The nature models keep their `.glb` as the source. Their `.import` settings remap every material to pastel
`scenes/scenery/materials/*.tres` and save each mesh to `scenes/scenery/meshes/<name>.res`. The kart's body mesh is
painted with a flat material in `kart.color` (`kart.gd`); the wheels and driver keep the pack's colormap. Everything
else (windmill, balloons, clouds, flags, spectators, arch, pond, hills) is primitives, with repeated parts as
`MultiMeshInstance3D`s.

### Scenery

`track.tscn` has one `Scenery` node. Moving things are scenes under `scenes/scenery/`, animated by an `AnimationPlayer`
set to the physics callback (so physics interpolation smooths them). No scenery has a physics body. The greenery is
placed by `tools/dress_track.gd` with a fixed seed and saved as `greenery.tscn`: MultiMeshes in 160 m tiles, so each
view culls the tiles it cannot see. Rerun the tool when the centre line changes. `test_scenery_stays_off_the_road`
catches a stale dressing.

### Fx (particles)

`Fx` (`fx.gd`, a child of `race.tscn`) plays effects from `scenes/fx/` by name. `spawn(effect, at, on = null)` plays a
one-shot at a world point, or riding on a node; it frees itself after the effect's lifetime. `attach(effect, node)`
adds a continuous effect to its owner. Continuous kart effects use `FxToggle` (`fx_toggle.gd`), which sets `emitting`
each physics tick from a predicate on its parent (`is_boosted`, `is_sliding`, `is_on_mud`).

The gameplay rules hold no effect code: they emit signals or call ItemWorld's `play_sound`/`spawn_fx` (`attach_fx` for
the rocket trail); the race wires karts. `Kart` only emits signals (`bounced`, `spun_out`, `pad_boosted`, and the sound
ones below); `Race` wires them to `Fx`. Without an `Fx` set (`ItemWorld.fx` null, as in most item tests) items make no
effects; the fx tests set one.

**The effects are `CPUParticles3D`, not `GPUParticles3D`.** On the Compatibility renderer (which the web export uses)
each active `GPUParticles3D` costs a roughly fixed 0.35 ms per frame, whatever its particle count, view count or
process rate. With 6 views that took the fps from 178 to 74–95. `CPUParticles3D` is about 3x cheaper there. GPU
particles with several `ParticleProcessMaterial`s also leak a shader at exit (Godot 4.7.1), which `CPUParticles3D`
does not. Particles fade by a scale curve and use two shared unshaded, vertex-coloured, opaque materials, so there is
no alpha blending and no depth sorting. Overlapping particles still overdraw, but each opaque unshaded pixel is cheap.

### Sfx (sound)

`Sfx` (`sfx.gd`, a child of `race.tscn`) plays `godot/assets/sounds/<name>.mp3`:
- `play(name)` plays a non-positional one-shot (split screen makes a position meaningless) that frees itself.
- `start_music()` loops `music_race` at volume 0.5 for the race.
- `watch_kart(kart, human)` wires a kart's signals to sounds (`boost_started`, `shield_raised`, `shield_broken`,
  `entered_mud`, `bumped`, `spun_out`). A human kart also gets an engine loop: pitch 0.8–1.6 following speed (capped
  at boost top speed), volume `0.35 / sqrt(human count)`: loops that are not in phase add up in power, so N loops
  together sound as loud as one at 0.35, never louder. Bots get no engine.
- `Race` plays the countdown beeps, `lap_complete`, `final_lap` and `race_finish` (human karts only). Items play
  their pickup, roulette, banana and rocket sounds through `ItemWorld.play_sound`. `banana_slip` plays only when the
  kart spins, not when a shield absorbs the banana (that is `shield_break`).
- A missing file stays silent and logs one warning (looked up once). The current files are silent placeholders.
- With the Dummy audio driver (headless runs, GUT) no player is started: their playbacks outlived the quit and leaked
  objects at exit.
- On `NOTIFICATION_WM_CLOSE_REQUEST` Sfx stops every player. A player still playing at engine quit made Godot's web
  audio throw `null.currentTime` in the page.
- On `NOTIFICATION_EXIT_TREE` it stops them too and, off the web with a real audio device, waits 50 ms: a stopped
  playback is released only after the audio thread mixes once more, and at a quit (EXIT_TREE comes after the last frame)
  that never happened, so the playbacks leaked at exit ("ObjectDB instances leaked").
- `Sfx` takes a `CharacterBody3D`, not `Kart`: Kart → ItemWorld → Sfx → Kart would be a class type cycle that fails to
  compile when tests load alone.

### Performance

Measured natively and windowed, 6 human views at 1920×1080, vsync off, on an Apple M4 (Compatibility renderer) with
`tools/fps_probe.gd`:

| Run | fps |
| --- | --- |
| Before particles (karts and scenery) | 178 |
| Normal race with the CPU particles | 171 |
| Worst case (every second 6 big sparks, 6 confetti, 2 boosts) | 157–163 |

The web build (WebGL2 through ANGLE) and a slower laptop are not measured. Shadows stay off (see F26).

### HiDPI

`game.ts` sizes the canvas backing store to `clientWidth × devicePixelRatio`, capped at 2×, with the pure
`backingSize(cssW, cssH, dpr)` (Vitest-tested). The `ResizeObserver` calls it; the canvas CSS size stays 100 %.
Six views at 3× would be too much to draw.

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
| `finishNow` | page → Godot | Set by e2e tests (read on web): `true` ends the race at once (`Bridge.finish_now()`), with the places as they stand. |
| `karts` | Godot → page | e2e builds only: JSON `[{slot, x, z}]`, written every tick so tests can see karts move. |
| `views` | Godot → page | e2e builds only: the number of player views, written once at start (`Bridge.report_views`). |

**Godot pulls.** `input(slot, input)` only writes the global. `Bridge` (`bridge.gd`, physics priority −1 so it runs
before the race) takes `JavaScriptBridge.get_interface("racingCarts")` once and parses `inputs` every physics tick.
No per-message callback crosses into Godot. `bridge_codec.gd` holds the pure parsing and is tested with GUT;
missing or malformed inputs are neutral. Outside the web (editor F5, GUT) `Bridge` plays two players itself: slot 0
on the keyboard (arrows, Space for ITEM), slot 1 idle; `send_finish` prints the results and **quits the tree**. A GUT test that runs a race to the end therefore kills the
test run: tests call `RaceRules` or `Race` pieces directly, never a whole race through `send_finish`.

### Results: places among all karts

`Race` sends `[{slot, place}]` for the human players only, but each `place` is the kart's rank among **all 6 karts**,
bots included: a player behind a bot in 2nd gets place 2 (`RaceRules.places`). `decodeResults` keeps those places as
given, without renumbering, so a lone player can be 4th, and always returns one result per player: unknown, duplicate or
malformed entries are dropped and missing players are placed after the highest place, in slot order. The shell's
results screen therefore puts only places 1–3 on the podium, each on the step for its place (`splitPodium`,
`apps/shell/src/podium.ts`; a step nobody earned stays as an empty placeholder), and everyone else in the Others list.

## The race

`race.tscn` is the main scene. `Race` (`race.gd`) builds six karts from `RaceRules.grid` (humans by party slot, then
bots), puts them on `Track.grid_transform`, and each physics tick, in phase `COUNTDOWN` → `RACING` → `DONE`:

1. Reads each human's input from `Bridge.input_for(slot)` and each bot's from its `BotDriver`. Inputs are ignored until
   GO (karts get no input during the 3 s countdown).
2. Updates each kart's `TrackProgress` from `Track.offset_of`, records finishes after `TOTAL_LAPS` laps, and ranks all
   karts with `RaceRules.ranking` (finished first, by time; the rest by distance).
3. Sets each kart's `top_speed_scale` from `RaceRules.catchup_scale`.
4. Ends the round when `RaceRules.is_over` (every human finished, or `FINISH_GRACE` 30 s after the first human; a
   race with no human finish ends 30 s after the last bot), or on `finish_now`, then calls `Bridge.send_finish`.

5. Sets the `ItemWorld`'s `order` and `distances`, lets item boxes roll items for karts that touch them, and uses a
   held item on a fresh ITEM press (rising edge) for players and bots alike (see Items).

6. Feeds each view's HUD (see Views, cameras and HUD).

Pure scripts are tested with GUT: `race_rules.gd`, `kart_physics.gd`, `track_progress.gd`, `bridge_codec.gd`,
`view_layout.gd`; the scene scripts (`kart.gd`, `bot.gd`, `track.gd`, `race.gd`, `views.gd`, `view_hud.gd`) have
scene-level GUT tests.

### Items

An item is a script extending `ItemDef` (`godot/scripts/items/item_def.gd`): `id`, `hud_color` (the HUD pill), `weight(r)` (odds at
rank fraction `r`), `use(kart, world)` and `bot_should_use(kart, world, held_for)`. `ItemRegistry`
(`items/registry.gd`) lists them in `ITEMS`, one `preload` line each (adding an item is that line plus its script),
and does the weighted roll (`roll(r, rng)`, `pick`, `by_id`). Tuning stays in `KartTuning` (`ITEM_ROLL_TIME`,
`BOX_RESPAWN`, `SHIELD_TIME`, `BOOST_FACTOR`, `SPIN_TIME`).

`ItemWorld` (`item_world.gd`, a node the race owns) is all an item sees of the race: `karts`, `track`, `order` and
`distances` (set by the race every tick), `rank_fraction`, `kart_ahead`/`kart_behind`, `gap_to`, `targeted_by_rocket`,
`spawn` and `hit`. `on_box(kart)` rolls an item for a kart that holds none and returns whether it rolled.
`play_sound`, `spawn_fx` and `attach_fx` reach `Sfx` and `Fx` when the race set them, and do nothing otherwise. `hit(kart)` calls `kart.hit()` and emits
`kart_hit(kart)`, which the race turns into a shake of that player's view (also when the shield absorbs the hit).

- **Kart** (`kart.gd`) holds one item id (`held_item`), rolls it for `ITEM_ROLL_TIME` after `give_item`, and
  `use_item_pressed(world)` uses it unless it still rolls or the kart spins. `hit()` pops the shield, else `spin_out()`.
- **Entities** are `Area3D`s found by overlap: `ItemBox` (group `item_box`, `world` set by the race, placed in
  `track.tscn`), `Banana`, `Rocket`. A targeted `Rocket` follows the track (`Track.point_at`), easing its lateral toward the
  target's as the gap along the track closes, and once within 10 m homes onto the target for good; an untargeted one
  flies straight. Both pop when `Track.lateral_of` passes
  `Track.ROAD_HALF_WIDTH` (a wall), or at the end of their life. `Track.turn_ahead` feeds the bots' boost rule.
- **Bots** press ITEM for one tick when the held item's `bot_should_use` says so (not while rolling or spinning). The
  `ItemDef` default is `true`: an item with no rule of its own is used by bots as soon as it is held.

| Item | Odds weight at `r` | Use | Bot uses it when |
| --- | --- | --- | --- |
| Boost | `1 + 3r` | `boost(1.5)` | the track turns under 0.3 rad over the next 40 m |
| Shield | `3 - 2r` | `shield(6.0)` | held over 5 s, or a rocket targets it |
| Banana | `3 - 2r` | dropped 2.5 m behind; 30 s; owner safe 0.5 s | a kart is behind within 15 m, or held over 10 s |
| Rocket | `0.5 + 3r` | 40 m/s from 2 m ahead; 6 s (3 s untargeted) | a kart is ahead within 60 m, or held over 10 s (at whatever is ahead, or straight) |

### Views, cameras and HUD

`Views` (`views.gd`, a full-rect `Control` in `race.tscn`, below the `HUD` canvas layer) holds the split screen.
`Race` calls `setup(karts, world)` with the human karts in slot order. With no humans it passes the pole kart, then
retargets that one view to the leader every tick. Each view is:

- a `ColorRect` in the kart's colour (the 4 px border);
- a `SubViewportContainer` (stretch) with a `SubViewport` whose `world_3d` is the race's world, so all views see one
  world, and a current `ChaseCamera` inside it;
- a `ViewHud` over the same inner rect.

The main viewport has no camera, so nothing renders full screen underneath the views. `camera_for(slot)` and
`hud_for(slot)` look a view up by party slot. Views re-layout on `resized`. With more than 2 views the race turns
the sun's shadows off. e2e builds report the view count as `views` on the bridge.

`ViewLayout.rects(count, size)` (pure) gives the rects in view order with integer edges (`floor(size * i / n)`), so
they tile the screen exactly:

| Players | Layout |
| --- | --- |
| 1 | one full view |
| 2 | 2 side by side |
| 3 | 2 on top, 1 full-width below |
| 4 | 2 × 2 |
| 5 | 3 on top, 2 below (each half the width) |
| 6 | 3 × 2 |

`ChaseCamera` (`chase_camera.gd`, `Camera3D`, FOV 70°) sits 7 m behind and 3 m above its `target`. It aims 4 m ahead
at 1 m height, easing toward the kart's heading at 6 /s (`lerp_angle`) and its position at 8 /s, in `_physics_process`. A new
target snaps it behind that kart. `shake()` adds a wobble of 0.3 m that fades linearly over 0.4 s. The wobble is added
on top of the eased position, so it never accumulates.

`ViewHud` (`view_hud.gd`, built in code) shows:

- the place as an ordinal, top left;
- "LAP 2/3", top right;
- the held item, bottom centre: an uppercase word (the item `id`) in a pill filled with `ItemDef.hud_color`, or `?`
  on lavender while it rolls;
- "FINISHED 2nd" in the middle once that player is done.

Text is white with a dark outline at `max(24, view height / 12)` px. The race calls `show_state` on every HUD each
physics tick, from `RaceRules.ranking` (the grid order before GO), `min(laps_done + 1, TOTAL_LAPS)` and the kart's item
state. The countdown is one label over the whole screen in the `HUD` canvas layer, its font size 1/5 of the screen
height.

**Physics interpolation** is on (`physics/common/physics_interpolation`): everything that moves (karts, rockets,
bananas, the chase cameras) moves in `_physics_process` at 60 Hz, and Godot interpolates the rendered transforms, so
the views stay smooth on 120 Hz screens. A placement that is not a move must call `reset_physics_interpolation()`
after it, or the node visibly sweeps there: the race does it for karts on the grid, `ItemWorld.spawn` for items, and
`ChaseCamera` when it cuts to a new target. A node moved in `_process` opts out (`physics_interpolation_mode = OFF`),
as the item box's spinning cube does.

**No emoji in Godot UI.** The default font has none, so they render as boxes on the web. HUD text is plain words,
and a GUT test checks that every HUD label stays below U+2000.

### Track

`track.tscn` has one closed `Path3D` (`CentreLine`, about 900 m) that the road and walls (CSG polygons) follow. Offsets
run along it from 0 at the start line. `Track` exposes `length`, `offset_of`, `point_at(offset, lateral)`,
`direction_at` and `grid_transform(index)`: two columns, 6 m between rows, starting 4 m behind the line.

| Feature | Count | Where | Effect |
| --- | --- | --- | --- |
| Boost pad | 7 | `Area3D` in group `boost_pad` | Kart sensor entering gives `PAD_BOOST_TIME` (1 s) of boost, never cutting a longer one. |
| Mud | 4 | `Area3D` in group `mud` | Top speed × `MUD_TOP_FACTOR` while the sensor overlaps; slows by `MUD_DECEL` above it. |
| Walls | 2 | `StaticBody` from CSG | Bounce (below). |

The chicane (minimum radius 8.5 m) needs a lift at full speed: the full-lock turn radius at top speed is about 8.6 m.
Bots lift there (`SHARP_TURN`); a bot laps the track in about 55 s.

`TrackProgress` counts a lap when the offset jumps from the last quarter of the track to the first, and gives the
race distance (laps × length + offset) used for ranking. Karts start behind the line, so their offset counts as negative
until they first cross it.

### Kart tuning and handling

All values are consts in `kart_tuning.gd` (`KartTuning`); metres, seconds, radians.

| Const | Value | Meaning |
| --- | --- | --- |
| `MAX_SPEED` | 20.0 | m/s |
| `ACCEL` | 12.0 | m/s² |
| `BRAKE_DECEL` | 24.0 | m/s², also the rate of reversing |
| `REVERSE_MAX` | 6.0 | m/s |
| `COAST_DECEL` | 4.0 | m/s² with no pedal, and above top speed |
| `STEER_RATE` | 2.4 | rad/s at full steer and at least 5 m/s |
| `GRIP` | 3.0 | 1/s, decay of sideways speed |
| `SLIP` | 0.35 | share of a heading change the velocity does not follow |
| `BOOST_FACTOR` | 1.6 | top speed × while boosted |
| `PAD_BOOST_TIME` | 1.0 | s |
| `MUD_TOP_FACTOR` | 0.5 | top speed × on mud |
| `MUD_DECEL` | 16.0 | m/s², instead of `COAST_DECEL` while on mud and above the mud top speed |
| `SPIN_TIME` | 1.2 | s |
| `CATCHUP` | 0.06 | extra top speed for last place |
| `CATCHUP_WALL_PAUSE` | 2.0 | s |
| `WALL_SPEED_KEEP` | 0.8 | share of the speed along the wall kept |
| `WALL_BOUNCE` / `WALL_BOUNCE_BOOSTED` | 4.0 / 7.0 | m/s off a wall |
| `KART_BOUNCE` | 3.0 | m/s apart, each from the pair's mean speed along the contact |
| `KART_BOUNCE_BOOSTED_OTHER` / `_SELF` | 8.0 / 2.0 | m/s for the kart hit / the boosted kart |

**Slide model (`SLIP`).** `KartPhysics` keeps velocity as forward speed plus sideways speed in the kart's own frame.
When steering turns the kart, the velocity follows only `1 − SLIP` of the heading change; the rest becomes sideways
speed, which `GRIP` decays. So the kart drifts outward in fast corners, while at low speed the turn is small and the
slide negligible. Bounces add sideways speed the same way, so they also decay by grip.

**Bounces** are fixed, not speed-based: a wall sets the speed along the normal to `WALL_BOUNCE` and keeps
`WALL_SPEED_KEEP` of the rest. A kart pair bounces in the pair's frame, once per physics tick for both karts: along the
contact normal `n` (from B to A) the mean speed is `vn = (vA + vB)·n / 2`, A leaves at `vn + speedA` and B at
`vn − speedB` (`KART_BOUNCE` each, or `KART_BOUNCE_BOOSTED_SELF` / `_OTHER`), and the speeds across `n` stay. So a
rear-end at matched speed nudges both karts instead of stopping them. A boosted kart bounces harder and neither spins
out.

**Mud** scales top speed by `MUD_TOP_FACTOR`; above that, the kart slows by `MUD_DECEL` instead of `COAST_DECEL`, so a
6 × 8 m patch taken at 20 m/s leaves the kart at about 10 m/s.

**Catch-up** is `1 + CATCHUP × rank / (karts − 1)` (0 for the leader), 1 for `CATCHUP_WALL_PAUSE` after touching a wall.

**Bots** (`BotDriver`) aim `AIM_AHEAD` metres ahead on a random lane (±3 m, redrawn every 3–6 s), steer with a
per-bot reaction delay (0.1–0.3 s) and lift before sharp turns. Each draws a cruise speed of 85–95 % of `MAX_SPEED`,
and the cruise speed is **multiplied by the kart's catch-up scale**, so a trailing bot keeps up with the raised top
speed instead of cruising at a fixed speed.

### Round lifecycle (`src/game.ts`)

`start(round)`:
1. Appends a canvas and a "Loading…" element to `round.el`. The canvas has a **unique id per round**
   (`racing-carts-<n>`): Godot 4.7.1 finds its canvas by a `#id` selector (no id throws "'#' is not a valid
   selector"), and an old canvas can still be in the page while it quits.
2. Keeps the canvas backing store at the size of `round.el` times `devicePixelRatio` (capped at 2) with a
   `ResizeObserver` (`canvasResizePolicy: 0` leaves it to the page).
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
| `npm test -w racing-carts` | Vitest (`src/*.test.ts`), then GUT headless (`scripts/test-godot.sh`: `--import`, then `-s addons/gut/gut_cmdln.gd -gexit` with `godot/.gutconfig.json`, tests in `godot/tests/`, run with `--fixed-fps 60` so each frame is one 60 Hz physics tick and tests count physics frames; it also fails when a test script does not load, which GUT itself skips with exit 0). `npm test` at the root runs it too. |
| F5 in the Godot editor | Runs the project outside the shell; `Bridge` falls back to keyboard input. Open `godot/` as the project. |
| `npm run e2e` | Playwright `e2e/racing.spec.ts` against the built site: the Godot canvas starts with one view (`views`), three players get three views, GAS after the countdown moves slot 0's kart (read from `karts`), `finishNow` reaches the results screen, Escape leaves a round (also while loading) and a second round starts. Default headless Chromium renders Godot's WebGL2 without extra flags. |

**The Godot binary** always comes from `scripts/godot.sh`: `$GODOT` if set, else `/Applications/Godot.app/Contents/MacOS/Godot`
if it exists, else `godot` on `PATH`. It needs Godot 4.7.1 with the web export templates installed.

Pure rules are tested with GUT without a scene (`RefCounted` scripts); scene tests, Vitest for `bridge.ts` and
Playwright for flows follow the spec §9.

## CI

`.github/workflows/deploy-web.yml` installs Godot before `npm test`, `npm run e2e` and `npm run build`:

- [`chickensoft-games/setup-godot@v2`](https://github.com/chickensoft-games/setup-godot) with `version: 4.7.1`,
  `use-dotnet: false` and `include-templates: true`. It caches the editor and all export templates itself (no
  per-template choice, no checksum check) and sets `GODOT`, which `scripts/godot.sh` reads.
- Changing the Godot version means changing `version` there and `config/features` in `project.godot`.

## godot-ai and the Godot MCP server

The [godot-ai](https://github.com/hi-godot/godot-ai) editor addon (v4.4.1, `godot/addons/godot_ai/`) stays enabled
in the project: it exposes the open editor to the MCP server registered in `.mcp.json`,
[@coding-solo/godot-mcp](https://www.npmjs.com/package/@coding-solo/godot-mcp) (server `godot`). It is not exported.

## Adding a feature

- **A new item:** one script in `godot/scripts/items/` (with its `hud_color`) plus one line in `items/registry.gd`.
- **A new rule** (ranking, odds, bounces…): a pure `RefCounted` script with a GUT test, so the scene only wires it.
- **A new bridge field:** one entry in `RacingCartsGlobal` and `bridge.ts` on the page side, one in `bridge.gd` and
  `bridge_codec.gd` on the Godot side, each with a test.
