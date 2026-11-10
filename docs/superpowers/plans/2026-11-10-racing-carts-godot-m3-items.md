# Racing Carts in Godot — Milestone 3 (Items) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Item boxes, a weighted roll, and four items: ⚡ boost, 🛡️ shield, 🍌 banana, 🚀 rocket. Bots use items too.
Adding an item is one file plus one registry line.

**Architecture:**
- Each item is a small GDScript (`extends ItemDef`) in `scripts/items/`, listed once in `scripts/items/registry.gd`.
- Items act on the race only through `ItemWorld`, a node the race owns: karts, track, ahead/behind queries, spawning,
  and hits.
- Boxes, bananas and rockets are `Area3D` scenes.
- Pure rules (odds, roll, bot decisions) are static functions that GUT tests directly.

**Tech Stack:** Godot 4.7.1 GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-11-10-racing-carts-godot-design.md` (§6 items, §10 milestone 3).
Builds on milestone 2 (`docs/superpowers/plans/2026-11-10-racing-carts-godot-m2-race-core.md`).

## Global Constraints

- Branch `racing-carts-godot-m3`, stacked on `racing-carts-godot-m2`. Commit after every task.
- Godot through `scripts/godot.sh`; tuning stays in `KartTuning` (use the `class_name`, no preload aliases).
- Item rules:

  | Rule | Value |
  |---|---|
  | Items held per kart | one |
  | Roll time after pickup | 1.0 s (`ITEM_ROLL_TIME`) |
  | Box respawn | 3.0 s (`BOX_RESPAWN`) |
  | Box layout | 2 rows at 0.3 and 0.7 of the lap, 4 boxes per row at lateral −4.5, −1.5, 1.5, 4.5 m |
  | Pickup radius | the kart's sensor overlapping the box's 1.5 m sphere |
  | Boost | `boost(1.5)` (top speed × `BOOST_FACTOR` 1.6) |
  | Shield | 6.0 s or until it absorbs one hit |
  | Banana | dropped 2.5 m behind; lasts 30 s; owner safe for its first 0.5 s; the first kart to touch it is hit |
  | Rocket | 40 m/s; starts 2 m ahead; follows the track; homes onto its target once within 10 m; lives up to 6 s (3 s with no target); pops on a wall |
  | Hit | the shield pops if up, otherwise `spin_out()` (1.2 s) |

- Odds by rank fraction `r` (0 = leader, 1 = last; 0 when alone): boost `1 + 3r`, shield `3 − 2r`, banana `3 − 2r`,
  rocket `0.5 + 3r`.
- Bot use rules:
  - **boost:** when the track turns less than 0.3 rad over the next 40 m;
  - **shield:** when held for more than 5 s, or when a rocket targets this kart;
  - **banana:** when a kart is behind within 15 m;
  - **rocket:** when a kart is ahead within 60 m.
- ITEM uses the held item on a press (rising edge), never while rolling or spinning.
- Placeholder looks, pastel and low-poly:
  - box: a slowly turning cube with "?";
  - banana: a small yellow mesh;
  - rocket: a small capsule;
  - shield: a translucent sphere around the kart.

  Particles come in milestone 5.

## Review Focus

1. **Picking up a box while holding or rolling an item:** gives nothing, and the box still disappears and respawns
   (old behaviour). Pinned in Task 1 (`test_pickup_while_holding_gives_nothing`).
2. **The owner driving over their own banana right after dropping it:** safe for 0.5 s, hit after that. Pinned in
   Task 2 (`test_banana_owner_grace`).
3. **A rocket fired by the leader (nobody ahead):** flies straight and pops on a wall within 3 s, without hitting
   anyone behind. Pinned in Task 2 (`test_rocket_without_target_pops`).
4. **ITEM held down across the roll ending:** does not fire the new item until the next press. Pinned in Task 1
   (`test_item_needs_a_fresh_press`).
5. **A shielded kart hit by a banana:** the shield pops, there's no spin, and the banana is gone. Pinned in Task 2
   (`test_shield_absorbs_one_hit`).

---

## File structure (under `games/racing-carts/godot/`)

| File | Responsibility |
|---|---|
| `scripts/items/item_def.gd` | `ItemDef` base: `id`, `icon`, `weight(r)`, `use(kart, world)`, `bot_should_use(kart, world, held_for)`. |
| `scripts/items/registry.gd` | `ItemRegistry`: the list of items; `roll(r, rng) -> ItemDef`; `by_id(id)`. |
| `scripts/items/{boost,shield,banana,rocket}.gd` | One item each. |
| `scripts/item_world.gd` | `ItemWorld` (Node, child of the race): the queries and actions items use. |
| `scenes/item_box.tscn` + `scripts/item_box.gd` | One box: pickup, hide, respawn. |
| `scenes/banana.tscn` + `scripts/banana.gd`, `scenes/rocket.tscn` + `scripts/rocket.gd` | Item entities. |
| `scripts/kart.gd` | + held item, roll, shield, `hit()`. |
| `scripts/race.gd`, `scenes/race.tscn`, `scenes/track.tscn` | + ItemWorld, boxes on the track, item input, a temporary item label. |

---

### Task 1: Items core — registry, roll, boxes, holding, using

**Files:**
- Create: `item_def.gd`, `registry.gd`, `item_world.gd`, `item_box.gd/.tscn`, `tests/test_items_core.gd`,
  `tests/test_item_box.gd`.
- Modify: `kart.gd`, `kart_tuning.gd` (`ITEM_ROLL_TIME`, `BOX_RESPAWN`, `SHIELD_TIME`), `track.tscn` (an `ItemBoxes` node
  with the 8 boxes; group `item_box`), `race.gd`, `games/racing-carts/scripts/test-godot.sh`.

**Interfaces (produces):**
- `class_name ItemDef extends RefCounted`:
  - `var id: String`, `var icon: String`
  - `func weight(r: float) -> float`
  - `func use(kart: Kart, world: ItemWorld) -> void`
  - `func bot_should_use(kart: Kart, world: ItemWorld, held_for: float) -> bool`
- `class_name ItemRegistry extends RefCounted`:
  - `static func all() -> Array[ItemDef]` (from one `const ITEMS := [preload(...).new(), …]` line per item)
  - `static func roll(r: float, rng: RandomNumberGenerator) -> ItemDef`: weighted by `weight(r)`, negatives count as 0
  - `static func by_id(id: String) -> ItemDef`
- `class_name ItemWorld extends Node`:
  - `var karts: Array[Kart]`, `var track: Track`
  - `func rank_fraction(kart) -> float`
  - `func kart_ahead(kart) -> Kart` and `func kart_behind(kart) -> Kart` (next in race order, or null)
  - `func gap_to(a, b) -> float` (race distance b − a)
  - `func spawn(node: Node3D) -> void`
  - `func hit(kart: Kart) -> void`
  - `func targeted_by_rocket(kart) -> bool`
  - Race order comes from the race (`RaceRules.ranking` each tick).
- `Kart` additions:
  - `var held_item: String` ("" when none)
  - `var roll_left: float`
  - `var held_for: float`
  - `func give_item(id)` (starts the roll)
  - `func use_item_pressed(world)` (rising-edge logic lives in the race)
  - `func shield(seconds)`, `func has_shield() -> bool`
  - `func hit() -> void`: the shield pops if up, otherwise `spin_out()`
- The race wires `ItemWorld`:
  - boxes call `world.on_box(kart)`;
  - the ITEM rising edge per kart uses the held item when not rolling and not spinning;
  - bots use `ItemRegistry.by_id(held).bot_should_use(...)`.
- **Temporary item label:** the race's `CanvasLayer` shows the followed player's held item icon, or 🎲 while
  rolling. Milestone 4 replaces it.
- **Test runner (ruling from the milestone 2 review):** `test-godot.sh` runs GUT with `--fixed-fps 60`, so physics
  tests run as fast as the CPU allows (the bot-lap test takes 55 s of real time otherwise). Check the suite still
  passes and report the new run time.

- [ ] **Step 1: Failing GUT tests** (`test_items_core.gd`, `test_item_box.gd`):
  - `test_weights_match_odds_table` (r = 0 and r = 1 per item)
  - `test_roll_is_weighted` (10 000 seeded rolls at r = 1: rocket and boost each above 30 %)
  - `test_roll_takes_one_second_then_holds`
  - `test_pickup_while_holding_gives_nothing`
  - `test_box_respawns_after_3_s`
  - `test_item_needs_a_fresh_press`
  - `test_no_use_while_spinning`
  - `test_hit_without_shield_spins`
- [ ] **Step 2:** Run. Expected: fail. **Step 3:** implement (registry starts with a single `boost.gd` so the roll has
  something; Task 2 adds the rest). **Step 4:** pass.
- [ ] **Step 5:** `npm test -w racing-carts`, `npm run e2e` pass. Commit `feat(racing-carts): item boxes, roll and using items`.

### Task 2: The four items and bots using them

**Files:**
- Create: `items/{boost,shield,banana,rocket}.gd`, `banana.gd/.tscn`, `rocket.gd/.tscn`, `tests/test_items.gd`.
- Modify: `registry.gd` (one line per item), `kart.gd` (shield bubble visual), `bot.gd` (the item decision).

**Interfaces:**
- Each item implements `ItemDef` with the values and bot rules from Global Constraints.
- `BotDriver.input_for` sets `item = true` for one tick when `bot_should_use` says so. The bot keeps a `held_for`
  timer from `Kart.held_for`.
- Rocket target: `world.kart_ahead(owner)` at fire time, or null.

- [ ] **Step 1: Failing tests** (`test_items.gd`, on a small test arena and on the real track):
  - `test_boost_item_boosts_1_5_s`
  - `test_shield_absorbs_one_hit`
  - `test_shield_expires_after_6_s`
  - `test_banana_spins_first_kart`
  - `test_banana_owner_grace`
  - `test_banana_expires_after_30_s`
  - `test_rocket_hits_kart_ahead`
  - `test_rocket_without_target_pops`
  - `test_bot_uses_rocket_when_kart_ahead_in_range`
  - `test_bot_drops_banana_when_followed`
  - `test_adding_an_item_is_one_file` (the registry's `ITEMS` has exactly the four ids, each with an icon)
- [ ] **Step 2:** fail. **Step 3:** implement. **Step 4:** pass.
- [ ] **Step 5:** Headless full race (`--fixed-fps 60`) with 6 bots: it ends with no script errors, and the report
  counts items used per kind. `npm test`, typecheck, lint and e2e pass. Commit
  `feat(racing-carts): boost, shield, banana and rocket`.

### Task 3: Docs

- [ ] `games/racing-carts/FEATURES.md`: F21 and F22 built (milestone 3); F23, "add an item in one file", describes the
  registry line. `ARCHITECTURE.md`: an Items section (ItemDef, ItemWorld, the registry, entities, the odds and bot
  rules table). `GLOSSARY.md`: item, roll, rank fraction, hit, ItemWorld. Commit `docs(racing-carts): milestone 3`.
