# Racing Carts: features

Every feature of Racing Carts as a user story, with its requirements, its status and where it lives. Add a story here
before building a feature. Site-wide features are in the root [FEATURES.md](../../FEATURES.md); terms in
[GLOSSARY.md](GLOSSARY.md). Design: [spec](../../docs/superpowers/specs/2026-11-10-racing-carts-godot-design.md) (§6–§8).

Roles: **player** (anyone in the party with a phone), **viewer** (anyone watching the host screen), **developer**.

Status is one of *built*, *built (milestone n)* or *planned (milestone n)*, where *built (milestone n)* may still gain polish in a later milestone, named in the story. Milestones: 1 plumbing,
2 race core, 3 items, 4 split screen and HUD, 5 look, environment, particles, sound. Numbers keep the old F-numbers;
F17, F19 and the shared camera of F25 were removed in the Godot rebuild (no drift, no drafting boost).
Paths are under `games/racing-carts/` unless they start with `apps/`.

## A round

### F12. Countdown, three laps and a finish
As a **viewer**, I want a 3-2-1-GO countdown, three laps and a clear end, so that every race has a start and a finish.
- Status: **built (milestone 2)**; the countdown is drawn on the one temporary screen, per-view drawing comes in milestone 4.
- Inputs are ignored until GO. The countdown is drawn once across the whole screen.
- Lap, final-lap and finish moments play sounds for human karts only.
- The round ends when every player has finished, or 30 s after the first player finishes. Then the game calls `finish` with each player's place among all karts, bots included.
- Lives in: `godot/scripts/race.gd` (phases, wiring), `godot/scripts/race_rules.gd` (grid, ranking, places, finish rule), `godot/scripts/track_progress.gd` (laps), `godot/scripts/bridge.gd` (`send_finish`, `finish_now`), `src/game.ts`.

### F13. See my place, lap and item
As a **player**, I want my own place, lap and item on my view, so that I always know how I am doing.
- Status: **planned (milestone 4)**. The old shared race list is dropped.
- Each view shows the place ("2nd"), the lap ("2/3") and the held item (🎲 while rolling), large enough to read from the couch.
- A finished player's view shows "FINISHED" with the place.
- Lives in: *`godot/scripts/hud.gd`*.

## Driving

### F14. Steer by tilting my phone
As a **player**, I want to hold my phone sideways and tilt it to steer, so that driving feels natural.
- Status: **built** on the phone; **built (milestone 2)** in the game, where steer turns the kart (F16).
- Steer comes from the axis that matches the screen orientation, with a small dead zone and full lock at a moderate tilt. **Center** sets the current tilt as straight ahead, on every layout.
- Motion access is asked for on the **Join** tap. If it is denied, the phone says "No access to the motion sensor" with **Try again**; there is no fallback.
- Held upright, the phone says "Turn your phone sideways". While driving, the screen stays awake.
- Lives in: `apps/controller/src/tilt.ts`, `apps/controller/src/composables/useTilt.ts`, `apps/controller/src/CenterButton.vue`, `apps/controller/src/layouts/TiltRacerLayout.vue`, `apps/controller/src/permissions.ts`.

### F15. Gas, brake, reverse and use an item
As a **player**, I want big **GAS**, **BRAKE** and **ITEM** buttons, so that I can drive without looking at my phone.
- Status: buttons **built**; GAS, BRAKE and reverse **built (milestone 2)**; ITEM is read by the bridge and used in milestone 3.
- Hold GAS to accelerate. Hold BRAKE to slow down, then reverse.
- A tap on ITEM shorter than one send interval still counts, and one press uses the item once.
- Godot reads the inputs once per physics tick, so the page holds the latest input per slot.
- Lives in: `apps/controller/src/layouts/TiltRacerLayout.vue`, `apps/controller/src/latch.ts`, `godot/scripts/bridge.gd`, `godot/scripts/bridge_codec.gd`, `godot/scripts/kart_physics.gd`.

### F16. Arcade kart handling with a slide
As a **player**, I want simple, forgiving physics where the kart slides a little in fast corners, so that anyone can drive in seconds.
- Status: **built (milestone 2)**; the dust trail is milestone 5.
- Acceleration, top speed, reverse, steering and grip. When the kart turns, its velocity follows only part of the turn (the slide, `SLIP`) and the rest becomes sideways speed that grip removes: the kart drifts outward in fast corners, while low speed stays tight. No drift button. A dust trail shows while sliding (milestone 5).
- A kart is a `CharacterBody3D` moved with `move_and_slide()`; a fixed 60 Hz physics step. All values are in `kart_tuning.gd`.
- A spin-out turns the kart for 1.2 s and takes control away; nothing causes one yet (items, milestone 3). There is no elimination and no respawn.
- Lives in: `godot/scripts/kart.gd`, `godot/scripts/kart_physics.gd` (pure rules), `godot/scripts/kart_tuning.gd`, `godot/scenes/kart.tscn`.

### F31. Bouncy collisions
As a **player**, I want walls and other karts to bounce me with the same clear push every time, so that collisions feel readable and fun.
- Status: **built (milestone 2)**; sparks are milestone 5.
- A wall or kart pushes the kart back along the contact normal at a fixed speed: wall 4 m/s (plus the old wall speed loss), kart against kart 3 m/s each.
- A boosted kart bounces harder: into a wall 7 m/s; into a kart the other kart 8 m/s and the booster 2 m/s. A boosted hit spins nobody out.
- Sparks fly on bounces, bigger on a boosted hit (milestone 5).
- Lives in: `godot/scripts/kart.gd`, `godot/scripts/kart_physics.gd`.

### F18. Boost pads
As a **player**, I want chevron pads on the road that boost me, so that the track has spots worth aiming for.
- Status: **built (milestone 2)**; the sound is milestone 5.
- Driving over a pad gives a 1 s boost and a sound. A pad never cuts a longer boost short. Pads only work while racing.
- The track has 7 pads, at least twice as many as the old one.
- Lives in: `Area3D` pads (group `boost_pad`) on `godot/scenes/track.tscn`, `godot/scripts/kart.gd`.

### F32. Mud that slows
As a **player**, I want mud patches on the track, so that shortcuts cost something.
- Status: **built (milestone 2)**; splash particles and the squelch sound in milestone 5.
- On mud, top speed is 50 %. 4 patches, placed where they tempt a shortcut.
- Lives in: `Area3D` patches (group `mud`) on `godot/scenes/track.tscn`, `godot/scripts/kart.gd`.

### F33. A longer track
As a **player**, I want a longer track, so that three laps feel like a proper race.
- Status: **built (milestone 2)**.
- About 900 m, twice the old length, still 3 laps. One `Path3D` is the source for the road, walls, bots, rockets and lap progress.
- Lives in: `godot/scenes/track.tscn`, `godot/scripts/track.gd`, `godot/scripts/track_progress.gd`.

### F20. Gentle catch-up
As a **player** at the back, I want a little extra top speed, so that the race stays close.
- Status: **built (milestone 2)**.
- Up to +6 % top speed for last place, nothing for the leader. Paused while touching a wall and for 2 s after.
- Lives in: `godot/scripts/race_rules.gd` (`catchup_scale`), `godot/scripts/race.gd`, `godot/scripts/kart.gd`.

## Items

### F21. Pick up an item from a box
As a **player**, I want to drive through item boxes to get an item, so that the race has surprises.
- Status: **planned (milestone 3)**.
- A kart holds one item. Driving through a box while holding one gives nothing.
- After pickup, the item rolls for about 1 s, then the HUD shows it.
- The roll is weighted by position: boosts and rockets favour the back, shields and bananas the front.
- A box respawns 3 s after pickup and bursts on pickup (milestone 5).
- Lives in: *item boxes, a pure odds script*.

### F22. Use my item
As a **player**, I want to press ITEM to use what I hold, so that I can attack or defend.
- Status: **planned (milestone 3)**.
- 🛡️ **Shield**: absorbs the next hit, or lasts 6 s. Shows a bubble.
- ⚡ **Boost**: +60 % top speed for 1.5 s. Shows a flame.
- 🍌 **Banana**: dropped behind the kart. The first kart over it spins out for 1.2 s. Its owner is safe for 0.5 s. It replaces the old mine.
- 🚀 **Rocket**: follows the path and homes in on the next racing kart ahead. With nobody ahead it flies straight and pops on a wall.
- A hit gives that player's view a soft shake (milestone 4).
- Lives in: *`godot/scripts/items/`*.

### F23. Add a new item in one file
As a **developer**, I want to add an item by writing one script and one registry line, so that items are cheap to try.
- Status: **planned (milestone 3)**.
- Bots, the HUD and item boxes pick up a new item with no other changes. Bots use an item through its `bot_should_use`.
- Lives in: *`godot/scripts/items/`, `godot/scripts/items/registry.gd`*.

## Bots

### F24. Race against relaxed bots
As a **player**, I want bots to fill the empty karts, so that a race is fun even with two people.
- Status: **built (milestone 2)**; item use in milestone 3.
- Every kart that no player drives is a bot (the game always has 6 karts).
- Bots follow the path with a random lane offset, a per-bot speed and reaction time, and slow down in sharp corners.
- They cruise at 85–95 % of top speed (scaled by catch-up), so newcomers can beat them, and use items when it makes sense (milestone 3).
- Lives in: `godot/scripts/bot.gd`.

## Presentation

### F25. My own view: split screen with a chase camera
As a **player**, I want my own camera behind my kart, so that I always see where I am going.
- Status: **planned (milestone 4)**; until then a temporary follow camera chases the lowest-slot player's kart (milestone 2, `race.gd`). This replaces the old shared camera.
- Each player has a third-person camera behind and above their kart, easing behind its heading.
- The screen is split by player count, in slot order, each view with a thin border in the player's colour:

  ```
  1        2          3            4            5              6
  [ 1 ]    [1][2]     [1][2]       [1][2]       [1][2][3]      [1][2][3]
                      [  3  ]      [3][4]       [ 4 ][ 5 ]     [4][5][6]
  ```

- A hit on a kart shakes only that player's view.
- Lives in: *`godot/scripts/views.gd`*.

### F26. A cozy, lively world
As a **viewer**, I want a warm, toy-like look with things moving, so that the game feels friendly.
- Status: **planned (milestone 5)**.
- Pastel low-poly under warm light and a soft sky: hills, trees, rocks, a pond, a start arch with bunting, fences, flowers, plus a turning windmill, balloons, drifting clouds, waving flags and a few animated spectators.
- Particles for boost, dust, bounces, mud, banana slips, rockets, item boxes, pads, finish confetti and drifting leaves.
- Each kart is tinted in the player's colour, the same as in the party bar and on the phone.
- Lives in: *`godot/scenes/`, `godot/assets/`*.

### F27. Sound and music
As a **viewer**, I want music and sound effects, so that the race feels alive.
- Status: the 21 placeholder files are **built** (`godot/assets/sounds/`); playing them is **planned (milestone 5)**.
- Race music. Sounds for the countdown, items, hits, walls, bumps, laps and the finish; the mine sounds become banana sounds; a new mud sound.
- One engine loop per human kart, its pitch following speed.
- A missing or broken file just stays silent. The current files are silent placeholders.
- Lives in: `godot/assets/sounds/`. Prompts: [docs/audio-assets.md](../../docs/audio-assets.md).
