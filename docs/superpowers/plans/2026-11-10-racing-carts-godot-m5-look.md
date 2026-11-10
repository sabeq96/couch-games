# Racing Carts in Godot — Milestone 5 (Look, environment, particles, sound) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the race cozy and lively:
- low-poly pastel karts and scenery;
- moving things around the track;
- particles for every key moment;
- sound and music;
- a crisp canvas on HiDPI screens.

**Architecture:**
- Looks live in scenes: imported `.glb` models and primitives, `AnimationPlayer`/`Tween` for motion, and
  `GPUParticles3D` effects.
- Gameplay scripts only emit signals or call one `Fx` node, so effects stay out of the rules.
- Sounds go through one `Sfx` node with a name → stream table.

**Tech Stack:** Godot 4.7.1 (Compatibility renderer), GUT 9.7.1, TypeScript (canvas DPR).

**Spec:** `docs/superpowers/specs/2026-11-10-racing-carts-godot-design.md` (§8, §11, §10 milestone 5).

## Global Constraints

- Branch `racing-carts-godot-m5`, stacked on `racing-carts-godot-m4`. Commit after every task.
- Style: cozy pastel, toy-like low-poly, warm sun and a soft sky gradient. Nothing gritty or realistic. The look
  must be original: no imitation of any existing game's characters, karts or tracks.
- **Models:** CC0 low-poly packs from kenney.nl (check the official page and its licence first; take only what you
  use) as `.glb` in `godot/assets/models/<pack>/`, plus a `LICENSE`/`README` note naming the source. Recolour them to
  the pastel palette. Use primitives or CSG where a pack has nothing that fits. No meshes generated in code.
- **Karts:** keep the player colour as the kart's main colour (body tint); bots use the pastel bot colours. The kart
  collider and handling do not change.
- **Moving scenery** (motion from `AnimationPlayer` or a `Tween` in the scene, not physics):
  - a turning windmill, 2–3 floating balloons, drifting clouds, waving flags;
  - a few spectators bobbing near the start;
  - drifting petals or leaves (particles).
- **Particles:** `GPUParticles3D`, each effect a small scene under `scenes/fx/`, at most 64 particles per emitter and
  one-shot where it makes sense.

  | Effect | When |
  |---|---|
  | boost flame | the kart is boosted (pads or item) |
  | slide dust | lateral speed above 2 m/s |
  | bounce sparks | wall or kart bounce; bigger on a boosted bounce |
  | mud splash | on mud while moving |
  | slip stars | banana hit / spin-out |
  | rocket trail | while a rocket flies |
  | rocket burst | rocket hit or pop |
  | item-box burst | box pickup |
  | pad flash | pad boost starts |
  | finish confetti | a human kart finishes |
  | ambient petals | always, a few around the track |

- **Sound:**
  - one `Sfx` autoload or race child with `play(name)` and an engine loop per human kart (pitch 0.8–1.6 following
    speed; volume shared so 6 loops are not louder than 1);
  - `music_race` loops during the race;
  - files from `godot/assets/sounds/`; the mine sounds are renamed `banana_drop.mp3` / `banana_slip.mp3`;
  - a new silent placeholder `mud.mp3`;
  - a missing file stays silent and logs one warning.

  Event → sound:

  | Event | Sound |
  |---|---|
  | countdown step / GO | countdown_beep / countdown_go |
  | lap / final lap / finish (human only) | lap_complete / final_lap / race_finish |
  | box pickup / roll | item_box_pickup / item_roulette |
  | boost | boost |
  | shield up / pop | shield_up / shield_break |
  | banana drop / slip | banana_drop / banana_slip |
  | rocket fire / burst | rocket_fire / rocket_explode |
  | kart bump / wall bump | kart_bump / wall_bump |
  | spin-out | kart_spinout |
  | mud | mud |

- **Performance budget:** a 6-view race keeps about 60 fps on the user's laptop. Measure the native fps with 6 human
  views at 1920×1080. Shadows stay off with more than 2 views (milestone 4 rule).
- **HiDPI:** `games/racing-carts/src/game.ts` sizes the canvas backing store to `clientWidth × devicePixelRatio`,
  capped at 2×. This is the deferred milestone 1 minor.

## Review Focus

1. **6 views with every effect firing:** no frame-time cliff. Pinned in Task 2 (an fps measurement in the report).
2. **An effect node outliving its kart or rocket:** one-shot effects free themselves, with no orphan nodes after a
   race. Pinned in Task 2 (`test_one_shot_fx_free_themselves`).
3. **A missing sound file:** silent, with one warning and no error. Pinned in Task 3 (`test_missing_sound_is_silent`).
4. **6 engine loops:** total volume no louder than one. Pinned in Task 3 (`test_engine_loops_share_volume`).
5. **A DPR 3 phone-class screen:** the canvas is capped at 2× and is not blurry at 1×. Pinned in Task 4 (Vitest on the
   size function).

---

### Task 1: Karts, track dressing and moving scenery

**Files:**
- Create: `godot/assets/models/**`, `godot/scenes/scenery/*.tscn` (windmill, balloon, cloud, flag, spectator, tree…).
- Modify: `scenes/kart.tscn` (model), `scenes/track.tscn` (dressing: hills, trees, rocks, pond, start arch with bunting,
  fences, flowers), `scenes/race.tscn` (`WorldEnvironment` sky and light tuning).
- Tests: `tests/test_scenery.gd`:
  - every scenery scene instances;
  - the windmill rotates over 60 frames;
  - no scenery collides with karts (scenery sits on layers the kart doesn't mask), except the start-arch posts if they
    are outside the walls;
  - existing kart tests still pass (collider unchanged).
- [ ] Steps:
  1. Pick the models (official kenney.nl pages; record the pack names and licence).
  2. Write the failing scenery tests.
  3. Build the scenes.
  4. Tests pass.
  5. Take 4 screenshots from a windowed run (start, hairpin, sweeper, a close-up kart) into the task report folder
     (not the repo) and describe them.
  6. Commit `feat(racing-carts): low-poly karts and a lively track`.

### Task 2: Particles

> Ruling during Task 2: the particles are `CPUParticles3D`, not `GPUParticles3D` (fps cost per active emitter and a
> shader leak at exit on the Compatibility renderer); see the Task 2 report.

**Files:** create `scenes/fx/*.tscn`, `scripts/fx.gd` (an `Fx` node: `spawn(name, position)` for one-shots,
`attach(name, node)` for continuous ones), `tests/test_fx.gd`. Modify `kart.gd`, `rocket.gd`, `banana.gd`,
`item_box.gd`, `race.gd`, and the `track.tscn` pads to call `Fx` / emit signals.
- [ ] Steps:
  1. Failing tests:
     - `test_each_fx_scene_instances`
     - `test_one_shot_fx_free_themselves`
     - `test_boost_flame_follows_boost` (emitting while boosted, not after)
     - `test_slide_dust_threshold`
  2. Implement.
  3. Pass.
  4. Measure fps with 6 human views (an off-web debug run forcing 6 player slots), with effects firing, at 1920×1080;
     report it.
  5. Commit `feat(racing-carts): particles`.

### Task 3: Sound and music

**Files:** create `scripts/sfx.gd`, `tests/test_sfx.gd`, `godot/assets/sounds/mud.mp3` (silent placeholder; copy an
existing silent placeholder file). Rename the two mine sounds. Modify the gameplay scripts to call `Sfx`, and
`docs/audio-assets.md` (names and prompts for banana and mud).
- [ ] Steps:
  1. Failing tests:
     - `test_every_event_maps_to_a_file`
     - `test_missing_sound_is_silent`
     - `test_engine_loops_share_volume`
     - `test_engine_pitch_follows_speed`
     - `test_sounds_only_for_human_events` (lap/finish)
  2. Implement.
  3. Pass.
  4. Commit `feat(racing-carts): sound and music`.

### Task 4: HiDPI canvas, final check and docs

- [ ] Steps:
  1. `game.ts`: a pure `backingSize(cssW, cssH, dpr) -> {w, h}` with a cap of 2, used by the `ResizeObserver`.
     Vitest first.
  2. Run `npm test`, typecheck, lint and e2e.
  3. Docs:
     - `games/racing-carts/FEATURES.md`: F26 (look) and F27 (sound) built (milestone 5); the particles list.
     - `ARCHITECTURE.md`: Fx, Sfx, assets and licences, the fps measurement, HiDPI.
     - `GLOSSARY.md`: Fx, Sfx, scenery.
     - Root `README` credits for the Kenney packs.
  4. Commit `feat(racing-carts): crisp canvas; docs for milestone 5`.
