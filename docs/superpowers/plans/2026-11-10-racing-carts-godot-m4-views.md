# Racing Carts in Godot — Milestone 4 (Split screen and HUD) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every player gets their own view with a third-person chase camera behind their kart, in the split-screen
layouts for 1–6 players, plus a HUD per view (place, lap, item, finished). The temporary follow camera and item label
go away.

**Architecture:**
- A pure `ViewLayout` turns a player count and a screen size into rectangles.
- `Views` builds one `SubViewportContainer` + `SubViewport` per player. The viewports share the race's `World3D`,
  and each has a `ChaseCamera` and a `ViewHud`.
- The countdown is drawn once over everything.

**Tech Stack:** Godot 4.7.1 GDScript, GUT 9.7.1, Playwright.

**Spec:** `docs/superpowers/specs/2026-11-10-racing-carts-godot-design.md` (§7, §11, §10 milestone 4).

## Global Constraints

- Branch `racing-carts-godot-m4`, stacked on `racing-carts-godot-m3`. Commit after every task.
- Layouts (views in party-slot order, the lowest slot first; rows top to bottom):

  | Players | Layout |
  |---|---|
  | 1 | one full view |
  | 2 | 2 side by side |
  | 3 | 2 on top, 1 full-width below |
  | 4 | 2 × 2 |
  | 5 | 3 on top, 2 below (each half the width) |
  | 6 | 3 × 2 |

- Each view has a 4 px border in the player's colour.
- Chase camera:
  - 7 m behind and 3 m above the kart, looking at a point 4 m ahead of it at 1 m height;
  - it eases toward the kart's heading (heading smoothing 6 /s) and position (8 /s);
  - FOV 70°.
- Shake: a hit on that view's kart shakes only that view, 0.3 m amplitude decaying over 0.4 s.
- HUD per view:
  - place as an ordinal ("2nd"), top left;
  - lap "LAP 2/3", top right;
  - held item, bottom centre;
  - when that player has finished: "FINISHED 2nd" in the middle.
  - Font size is `max(24, view_height / 12)` px, white with a dark outline.
- **No emoji in Godot UI.** The default font has none, so they render as boxes on web. Items are shown by an
  uppercase word in a pastel pill: BOOST, SHIELD, BANANA, ROCKET, and `?` while rolling. The pill uses a new
  `ItemDef.hud_color`.
- The countdown is centred over the whole screen: 3, 2, 1, GO, about 1/5 of the screen height.
- Performance: when there are more than 2 views, `DirectionalLight3D.shadow_enabled = false`.
- e2e builds report `views` (the number of player views) on `window.racingCarts`.

## Review Focus

1. **Party slots with gaps (0, 2, 5):** three views in the 3-player layout, in slot order, each following its own
   kart. Pinned in Task 1 (`test_views_follow_their_karts_by_slot`).
2. **Odd screen sizes (portrait, 4:3, 21:9):** the rectangles tile the screen with no gap or overlap. Pinned in
   Task 1 (`test_layout_tiles_exactly` across sizes and counts).
3. **A window resize mid-race:** the views re-layout. Pinned in Task 1 (`test_views_relayout_on_resize`).
4. **Another kart's hit:** shakes only that kart's view. Pinned in Task 1 (`test_shake_only_own_view`).
5. **A player who finished while others race:** "FINISHED 3rd" stays and the camera keeps following. Pinned in Task 2
   (`test_hud_finished_state`).

---

### Task 1: Layout, views and chase cameras

**Files (under `games/racing-carts/godot/`):** create `scripts/view_layout.gd`, `scripts/views.gd`,
`scripts/chase_camera.gd`, `tests/test_view_layout.gd`, `tests/test_views.gd`. Modify `race.gd` and `race.tscn` (remove
the temporary camera; add `Views`), `bridge.gd` (`report_views(n)` in e2e).

**Interfaces:**
- `class_name ViewLayout extends RefCounted`: `static func rects(count: int, size: Vector2) -> Array[Rect2]`, in
  pixels, in view order, using integer pixel edges that tile exactly.
- `class_name ChaseCamera extends Camera3D`:
  - `var target: Kart`
  - `func shake()`
  - `_process` eases as described in Global Constraints.
- `class_name Views extends Control` (full rect):
  - `func setup(karts_by_slot: Array[Kart], world: World3D) -> void`, which builds the views;
  - `func view_count() -> int`;
  - `func camera_for(slot: int) -> ChaseCamera`;
  - re-layouts on `resized`.
- The race calls `views.camera_for(kart.slot).shake()` when a human kart is hit (hook it in `ItemWorld.hit`).
- [ ] **Step 1: Failing GUT tests:**
  - `test_layout_counts` (1..6 → 1..6 rects)
  - `test_layout_shapes` (3: two top halves plus a full-width bottom; 5: three top thirds plus two bottom halves)
  - `test_layout_tiles_exactly` (sizes 1920×1080, 1080×1920, 1024×768, 2560×1080: areas sum to w × h, no overlaps)
  - `test_views_follow_their_karts_by_slot`
  - `test_views_relayout_on_resize`
  - `test_shake_only_own_view`
  - `test_camera_sits_behind_kart` (after settling: 7 m behind, 3 m above, ±0.5)
- [ ] **Step 2:** fail. **Step 3:** implement. **Step 4:** pass.
- [ ] **Step 5:** Run the race off-web for 10 s with no errors. `npm test`, `npm run e2e` pass. Commit
  `feat(racing-carts): split-screen chase cameras`.

### Task 2: HUD per view and the shared countdown

**Files:** create `scripts/view_hud.gd`, `scenes/view_hud.tscn` (or build it in code if simpler),
`tests/test_view_hud.gd`. Modify `views.gd`, `race.gd` (remove the temporary item label; the countdown becomes full
screen), `items/item_def.gd` (+ `hud_color`), each item (its `hud_color`), `e2e/racing.spec.ts`.

**Interfaces:**
- `class_name ViewHud extends Control`:
  - `func show_state(place: int, lap: int, total_laps: int, item_id: String, rolling: bool, finished_place: int) -> void`
  - `finished_place` is 0 while racing.
- The race feeds every HUD each frame, from `RaceRules.ranking`, `TrackProgress.laps_done` and the kart's item state.
  The lap shown is `min(laps_done + 1, TOTAL_LAPS)`.
- Ordinals: 1st, 2nd, 3rd, 4th, 5th, 6th.
- [ ] **Step 1: Failing tests:**
  - `test_hud_shows_place_lap_item`
  - `test_hud_rolling_shows_question_mark`
  - `test_hud_finished_state`
  - `test_hud_font_scales_with_view`
  - `test_no_emoji_in_hud` (no character above U+2000 in any HUD label for every item and state)
- [ ] **Step 2:** fail. **Step 3:** implement. **Step 4:** pass.
- [ ] **Step 5: e2e.** `race in Godot …` also expects `racingCarts.views === 1` with one player. Add
  **`three players get three views`**: three phones join, the lead opens the game, and the test expects `views === 3`
  and then finishes with `finishNow`. Use the existing helpers; the rounds spec already joins several phones.
- [ ] **Step 6:** `npm test`, typecheck, lint and e2e pass. Commit `feat(racing-carts): per-view HUD`.

### Task 3: Docs

- [ ] `games/racing-carts/FEATURES.md`: F13 (race order) becomes the per-view HUD and is built (milestone 4); F25
  becomes the chase camera per player in split screen, built (milestone 4). `ARCHITECTURE.md`: Views, ViewLayout,
  ChaseCamera, ViewHud, the layouts table, and the no-emoji rule. `GLOSSARY.md`: view, chase camera, HUD. Commit
  `docs(racing-carts): milestone 4`.
