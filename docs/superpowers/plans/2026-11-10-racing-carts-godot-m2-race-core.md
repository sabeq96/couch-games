# Racing Carts in Godot — Milestone 2 (Race core) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stub race with a real race: a longer track, karts with sliding arcade handling and fixed-value
bounces, laps, countdown, the finish rule, bots, boost pads, mud and catch-up. One temporary follow camera for now.

**Architecture:**
- Godot-native nodes do the heavy lifting:
  - a `Path3D` centre line drives road, walls, progress, bots and grid;
  - `CSGPolygon3D` in path mode builds road and walls;
  - `CharacterBody3D` karts move with `move_and_slide()`;
  - `Area3D` handles pads and mud.
- Rules that need no scene live in small `RefCounted` scripts that GUT tests directly.

**Tech Stack:** Godot 4.7.1 GDScript, GUT 9.7.1, Vitest, Playwright.

**Spec:** `docs/superpowers/specs/2026-11-10-racing-carts-godot-design.md` (§5, §6, §10 milestone 2).
Builds on milestone 1 (`docs/superpowers/plans/2026-11-10-racing-carts-godot-m1-plumbing.md`).

## Global Constraints

- Branch `racing-carts-godot-m2` (stacked on `racing-carts-godot`). Commit after every task.
- Godot through `scripts/godot.sh`. Compatibility renderer, no threads, nothing in `addons/` or `tests/` exported.
- The `godot` MCP server (`@coding-solo/godot-mcp`) may be used to create scenes and run the project; the result must
  be plain `.tscn` / `.gd` files in the repo.
- 6 karts always; humans take grid slots in party-slot order, bots fill the rest.
- Units: metres, seconds, radians. Physics 60 Hz. The track is flat at y = 0; karts never leave the ground.
- Tuning values (all in one `kart_tuning.gd`, `class_name KartTuning`, consts):

  | Const | Value |
  |---|---|
  | `MAX_SPEED` | 20.0 |
  | `ACCEL` | 12.0 |
  | `BRAKE_DECEL` | 24.0 |
  | `REVERSE_MAX` | 6.0 |
  | `COAST_DECEL` | 4.0 |
  | `STEER_RATE` | 2.4 |
  | `GRIP` | 3.0 |
  | `BOOST_FACTOR` | 1.6 |
  | `PAD_BOOST_TIME` | 1.0 |
  | `MUD_TOP_FACTOR` | 0.5 |
  | `SPIN_TIME` | 1.2 |
  | `CATCHUP` | 0.06 |
  | `CATCHUP_WALL_PAUSE` | 2.0 |
  | `WALL_SPEED_KEEP` | 0.8 |
  | `WALL_BOUNCE` | 4.0 |
  | `WALL_BOUNCE_BOOSTED` | 7.0 |
  | `KART_BOUNCE` | 3.0 |
  | `KART_BOUNCE_BOOSTED_OTHER` | 8.0 |
  | `KART_BOUNCE_BOOSTED_SELF` | 2.0 |

- Race: `TOTAL_LAPS = 3`, `COUNTDOWN = 3.0`, `FINISH_GRACE = 30.0`. Inputs are ignored until GO.
- Results: each player's place **among all 6 karts**, bots included (a player behind a bot in 2nd gets place 2).

## Review Focus

1. **Driving backwards over the start line, or cutting across it near the start:** must not count a lap. Pinned in
   Task 1 (`test_reverse_crossing_does_not_count`, `test_lap_needs_most_of_the_track`).
2. **A human finishing behind bots:** the place reported is among all karts, not renumbered 1..n by the shell. Pinned
   in Task 3 (Vitest `decodeResults` keeps places; GUT `test_results_places_among_all_karts`).
3. **A kart pinned against a wall:** each contact bounces it out with the fixed speed and costs speed. It must never
   gain speed or tunnel through. Pinned in Task 2 (scene test `test_wall_bounce_is_fixed_and_outward`).
4. **Nobody finishes (players idle):** the round still ends once the last bot finishes plus the 30 s grace, or the
   e2e `finishNow`. Pinned in Task 3 (`test_finish_rule_*`).
5. **1 human vs 6 humans:** the grid always has 6 karts, and slots with gaps (0, 2, 5) map to their own karts. Pinned in
   Task 3 (`test_grid_humans_by_slot_then_bots`).

---

## File structure (all under `games/racing-carts/godot/`)

| File | Responsibility |
|---|---|
| `scripts/kart_tuning.gd` | `KartTuning` consts above. |
| `scripts/track_progress.gd` | `TrackProgress` (pure): lap counting and distance from a curve offset. |
| `scripts/race_rules.gd` | `RaceRules` (pure): ranking, finish rule, results places, grid assignment, catch-up scale. |
| `scripts/kart_physics.gd` | `KartPhysics` (pure): one velocity/heading step from input; bounce velocities. |
| `scripts/kart.gd` + `scenes/kart.tscn` | `Kart` (`CharacterBody3D`): applies `KartPhysics`, collisions → bounces, boost/mud/spin state. |
| `scripts/track.gd` + `scenes/track.tscn` | `Track`: `Path3D` + CSG road/walls, grid points, pads and mud areas, `offset_of(pos)`, `point_at(offset, lateral)`. |
| `scripts/bot.gd` | `BotDriver` (RefCounted): input for a kart from the track. |
| `scripts/race.gd` + `scenes/race.tscn` | `Race`: phases, countdown label, karts, bots, finish, temp camera; main scene. |
| `tests/test_*.gd` | GUT tests per script. |

`stub_race.gd` / `stub_race.tscn` are deleted in Task 3. `bridge.gd` and `bridge_codec.gd` change in Task 3.

---

### Task 1: Track and lap progress

**Files:** create `scripts/track_progress.gd`, `scripts/track.gd`, `scenes/track.tscn`, `tests/test_track_progress.gd`,
`tests/test_track.gd`.

**Interfaces (produces):**
- `class_name TrackProgress extends RefCounted`:
  - `func _init(length: float)`
  - `var laps_done: int` (completed laps, starts 0)
  - `func update(offset: float) -> void`: feed the kart's curve offset (0..length) each tick.
  - `func distance() -> float`: `laps_done * length + offset`, the race distance used for ranking.
  - Lap rule:
    - a lap counts only when the offset jumps from > 0.75 × length to < 0.25 × length;
    - the reverse jump (< 0.25 to > 0.75) takes one lap back;
    - `laps_done` never goes below 0.
  - Karts start just behind the line: their first offsets are near `length`. Treat the start as lap 0 with the
    offset counted as negative until the first forward crossing, so `distance()` < 0 on the grid and the first
    crossing does **not** count a lap.
- `class_name Track extends Node3D` (root of `track.tscn`):
  - `func length() -> float`
  - `func offset_of(world_pos: Vector3) -> float` (`curve.get_closest_offset` in local space)
  - `func point_at(offset: float, lateral: float) -> Vector3` (lateral: metres to the right of the direction of travel)
  - `func direction_at(offset: float) -> Vector3` (unit, flat)
  - `func grid_transform(index: int) -> Transform3D`: index 0..5. Two columns at lateral ±3 m, rows 6 m apart, the
    first row 4 m behind the start line, facing the direction of travel.
  - Child nodes: `BoostPads` (`Area3D` children in group `boost_pad`) and `Mud` (`Area3D` children in group `mud`).
- Track layout:
  - a closed loop with a centre line of **850–950 m** (about twice the old track);
  - width 12 m, walls 1 m high on both edges (static collision);
  - a start straight of at least 60 m, at least one hairpin, one chicane and one long sweeper;
  - **at least 6 boost pads** (3 × 4 m, flat, chevron-coloured), on straights and at corner exits;
  - **4 mud patches** (about 8 × 6 m, brown), on corner insides and tempting lines.
  - Pastel flat colours (no textures yet).

- [ ] **Step 1: Failing GUT tests** (`test_track_progress.gd`):
  - `test_forward_crossing_counts_lap`
  - `test_first_crossing_from_grid_is_not_a_lap`
  - `test_reverse_crossing_does_not_count`
  - `test_reverse_then_forward_is_net_zero`
  - `test_lap_needs_most_of_the_track` (a jump from 0.5 × length to 0.1 × length counts nothing)
  - `test_distance_grows_with_laps`
- [ ] **Step 2:** Run `npm test -w racing-carts`. Expected: fail.
- [ ] **Step 3:** Implement `TrackProgress`. Run again. Expected: pass.
- [ ] **Step 4: Build `track.tscn` and `track.gd`.** Scene tests (`test_track.gd`):
  - length is in 850..950;
  - 6 grid transforms are distinct, sit on the road behind the line, and face along `direction_at(0)`;
  - `offset_of(point_at(o, 0))` ≈ o;
  - there are ≥ 6 nodes in `boost_pad` and 4 in `mud`.
- [ ] **Step 5:** `npm test -w racing-carts` passes. Commit `feat(racing-carts): track and lap progress`.

### Task 2: Kart handling and bounces

**Files:** create `scripts/kart_tuning.gd`, `scripts/kart_physics.gd`, `scripts/kart.gd`, `scenes/kart.tscn`,
`tests/test_kart_physics.gd`, `tests/test_kart.gd`.

**Interfaces (produces):**
- `class_name KartPhysics extends RefCounted`, static:
  - `step(velocity: Vector3, heading: float, input: Dictionary, top_speed: float, dt: float) -> Dictionary` → `{ "velocity": Vector3, "heading": float }`.
    - Forward speed `f = velocity · forward(heading)`.
    - GAS accelerates `f` by `ACCEL` up to `top_speed`. BRAKE decelerates by `BRAKE_DECEL`, then reverses down to
      `-REVERSE_MAX`. With neither, `f` coasts toward 0 by `COAST_DECEL`. Above `top_speed`, `f` eases down by
      `COAST_DECEL`.
    - Turn rate is `-steer × STEER_RATE × clamp(|f| / 5, 0, 1)`, flipped when reversing.
    - **Slide:** the lateral component decays as `lateral × exp(-GRIP × dt)`, instead of being snapped to 0. This is
      the "not glued to the road" change.
    - `forward(heading) = Vector3(sin h, 0, cos h)`.
  - `wall_bounce(velocity: Vector3, normal: Vector3, boosted: bool) -> Vector3`:
    - the normal component is replaced by `normal × (WALL_BOUNCE_BOOSTED if boosted else WALL_BOUNCE)`;
    - the tangential part is scaled by `WALL_SPEED_KEEP`.
  - `kart_bounce(velocity: Vector3, away: Vector3, self_boosted: bool, other_boosted: bool) -> Vector3`:
    - `away` is the unit vector from the other kart to this one; the normal component is replaced by
      `away × speed`;
    - speed is `KART_BOUNCE`; or `KART_BOUNCE_BOOSTED_SELF` when this kart is boosted and the other is not; or
      `KART_BOUNCE_BOOSTED_OTHER` when the other is boosted and this kart is not.
    - Bounces never spin a kart out.
- `class_name Kart extends CharacterBody3D` (`kart.tscn`: a low-poly placeholder body from primitives, tinted by
  `color`, plus a capsule or box collider about 1 m radius):
  - `var slot: int` (−1 for bots), `var color: Color`, `var heading: float`, `var input: Dictionary`
  - `var top_speed_scale := 1.0` (catch-up, set by the race)
  - `func boost(seconds: float)`: refreshes, never shortens the remaining boost.
  - `func spin_out()`: spins for `SPIN_TIME`. Input is ignored meanwhile and speed decays (M3 hits use it).
  - `func is_boosted() -> bool`, `func touched_wall_recently() -> bool` (a wall contact within `CATCHUP_WALL_PAUSE`).
  - `_physics_process`:
    - top speed is `MAX_SPEED × top_speed_scale × (BOOST_FACTOR if boosted) × (MUD_TOP_FACTOR if on mud)`;
    - run `KartPhysics.step`, then `move_and_slide()`;
    - for each slide collision: against a kart, apply `kart_bounce` to both (once per pair per tick); otherwise
      apply `wall_bounce`;
    - keep y = 0.
  - Mud and pad detection: the kart's own `Area3D` overlap with the groups `mud` / `boost_pad`. A pad gives
    `boost(PAD_BOOST_TIME)` on entry.
- [ ] **Step 1: Failing GUT tests** (`test_kart_physics.gd`):
  - `test_gas_accelerates_to_top_speed`
  - `test_brake_then_reverse_capped`
  - `test_coast_slows_down`
  - `test_no_turn_when_stopped`
  - `test_lateral_slides_and_decays` (lateral 5 m/s → `5 × exp(-GRIP × dt)` after one step; not 0)
  - `test_wall_bounce_fixed_values` (head-on at 20 m/s → normal 4.0; boosted → 7.0; tangential × 0.8)
  - `test_kart_bounce_values` (3/3; boosted hitter: 2 self / 8 other)
- [ ] **Step 2:** Run. Expected: fail. **Step 3:** implement `KartPhysics` and `KartTuning`. **Step 4:** pass.
- [ ] **Step 5: Kart scene and scene tests** (`test_kart.gd`, a small test arena of floor + wall + mud + pad, built in
  the test):
  - `test_wall_bounce_is_fixed_and_outward`: drive at a wall; after contact the normal velocity is +4 ± 0.1 and the
    kart is outside the wall.
  - `test_mud_halves_top_speed`
  - `test_pad_boosts_for_one_second`
  - `test_karts_bump_apart`
  - `test_spin_ignores_input_for_spin_time`
- [ ] **Step 6:** `npm test -w racing-carts` passes. Commit `feat(racing-carts): kart handling and fixed bounces`.

### Task 3: The race (replaces the stub)

**Files:**
- Create: `scripts/race_rules.gd`, `scripts/bot.gd`, `scripts/race.gd`, `scenes/race.tscn`, `tests/test_race_rules.gd`,
  `tests/test_bot.gd`, `tests/test_race.gd`.
- Delete: `scripts/stub_race.gd`, `scenes/stub_race.tscn`.
- Modify: `project.godot` (main scene `res://scenes/race.tscn`), `scripts/bridge.gd`, `scripts/bridge_codec.gd` (+ its
  test), `games/racing-carts/src/bridge.ts` (+ test), `games/racing-carts/src/game.ts` (finishNow), `e2e/racing.spec.ts`.

**Interfaces:**
- `class_name RaceRules extends RefCounted`, static:
  - `grid(human_slots: Array[int]) -> Array[int]`: six entries in grid order; the human slots sorted ascending, then
    `-1` for bots.
  - `ranking(karts: Array[Dictionary]) -> Array[int]`: each entry is `{ "id": int, "finished_at": float (-1 if not),
    "distance": float }`; returns ids, finished first by `finished_at`, then by `distance` descending.
  - `places(ranking_ids: Array[int], id_to_slot: Dictionary) -> Array[Dictionary]`: `[{ "slot", "place" }]` for humans
    only, where place = index in the full ranking + 1.
  - `is_over(now: float, first_human_finish: float, humans_all_finished: bool, last_kart_finish: float) -> bool`:
    true when every human has finished; or 30 s after the first human finished; or, with no human finished, 30 s after
    every bot finished.
  - `catchup_scale(rank_index: int, kart_count: int, wall_paused: bool) -> float`: `1 + CATCHUP × rank_index /
    (kart_count − 1)`, or 1.0 when paused.
- `BridgeCodec.results_json(places: Array[Dictionary]) -> String` replaces the old `results_json(order)`, and
  serialises the `{slot, place}` list as given.
- `decodeResults` in `bridge.ts` **keeps the given places**: it stops renumbering. Valid, unique places for known
  slots stay. Missing players go after the highest place, in slot order. Update its tests.
- `Bridge.finish_now() -> bool`: true when `window.racingCarts.finishNow === true` (any build). `game.ts` declares
  `finishNow?: boolean` on the global. e2e tests set it. Delete the stub's "finish on ITEM" rule.
- `class_name BotDriver extends RefCounted`:
  - `func _init(rng: RandomNumberGenerator)`
  - `func input_for(kart: Kart, track: Track, dt: float) -> Dictionary`
  - Behaviour:
    - lane offset in ±3 m, re-picked every 3–6 s;
    - aims at `point_at(offset + 9, lane)`;
    - cruise target 0.85–0.95 × `MAX_SPEED` (per bot);
    - steering reacts after 0.1–0.3 s (per bot);
    - when the track turns more than 0.9 rad over the next 25 m, it lets off GAS until under 70 % of its cruise speed;
    - `item` is always false in M2.
- `Race` (`race.gd`, root of `race.tscn` with `Track`, `Bridge`, a `Camera3D`, a `CanvasLayer` countdown `Label`):
  - spawns 6 karts on the grid using `RaceRules.grid`, colours from `bridge.players` and pastel bot colours;
  - phases: countdown (3, 2, 1, GO in a big label) → racing → done;
  - each tick: human input from `bridge.input_for(slot)`, bots from `BotDriver`; `TrackProgress.update`; finish times
    after `TOTAL_LAPS`; catch-up scale per kart;
  - ends via `RaceRules.is_over` or `bridge.finish_now()` → `bridge.send_finish(RaceRules.places(...))`;
  - `report_karts` each tick (e2e only), as before;
  - **temporary camera:** chases the lowest-slot human's kart from 8 m behind and 4 m above, smoothed.
- [ ] **Step 1: Failing tests:**
  - GUT `test_race_rules.gd`:
    - `test_grid_humans_by_slot_then_bots`
    - `test_ranking_finished_first_then_distance`
    - `test_results_places_among_all_karts`
    - `test_finish_rule_all_humans`, `test_finish_rule_grace_after_first_human`, `test_finish_rule_no_humans_finished`
    - `test_catchup_scale`
  - GUT `test_bot.gd`: on a test `Track`, a bot driven for 20 s of physics stays on the road (|lateral| < 6) and gains
    distance.
  - GUT `test_race.gd`: instancing `race.tscn` gives 6 karts; nothing moves during the countdown; after GO with GAS on
    slot 0 it moves.
  - Vitest `decodeResults` keeps places.
- [ ] **Step 2:** Run `npm test -w racing-carts`. Expected: fail. **Step 3:** implement. **Step 4:** pass.
- [ ] **Step 5: e2e (`e2e/racing.spec.ts`).** Replace the stub test with **`race in Godot: countdown, drive, finish,
  results`**:
  1. Open the game and wait for ready.
  2. After about 4 s (countdown) hold GAS for 2 s, and expect slot 0's position to change.
  3. Set `window.racingCarts.finishNow = true`, and expect `#/results/racing-carts` with Alex listed.
  4. Expect `pageerror` count 0.

  Keep the Escape / Escape-while-loading / second-round tests passing.
- [ ] **Step 6:** Run `npm test -w racing-carts`, `npm run typecheck`, `npm run lint`, `npm run e2e`. All pass. Commit
  `feat(racing-carts): the race — laps, bots, pads, mud, catch-up`.

### Task 4: Docs

- [ ] Update `games/racing-carts/FEATURES.md`:
  - F12, F14–F16, F18, F20, F24, F31–F33 become *built (milestone 2)*;
  - F30 (stub) is removed;
  - F25 says "temporary follow camera until milestone 4".
- [ ] Update `games/racing-carts/ARCHITECTURE.md` (the new scripts and scenes, the track and tuning tables, the results
  places rule) and `GLOSSARY.md` (TrackProgress, offset, grid, pad, mud, bounce, catch-up). Commit
  `docs(racing-carts): milestone 2`.
