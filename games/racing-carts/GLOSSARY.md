# Racing Carts: glossary

The domain language of Racing Carts, the Godot game. For the words of the whole site (party, room, layout…), see the
root [GLOSSARY.md](../../GLOSSARY.md). Design: [spec](../../docs/superpowers/specs/2026-11-10-racing-carts-godot-design.md).

Milestones (M1–M5) are listed in the spec. **In code** names what exists today; a name in *italics* is where the
term will live (planned, milestone in brackets). Paths are under `games/racing-carts/`.

## The game and its shell link

| Term | Meaning | In code |
| --- | --- | --- |
| **Bridge** | The link between the shell page and Godot: one global, `window.racingCarts`, with players, inputs and the finish callback. Two halves: the TypeScript side and the Godot side. | `src/game.ts`, `src/bridge.ts`, `godot/scripts/bridge.gd` |
| **Bridge global** | `window.racingCarts`: `players` and `inputs` (JSON), `e2e`, `ready()`, `finish(json)`, and in e2e builds `karts`. Exists only while a round runs. | `RacingCartsGlobal` (`src/game.ts`) |
| **Pull** | Godot reads `inputs` itself every physics tick; the page never calls into Godot. | `Bridge._physics_process` |
| **Codec** | The pure JSON encode/decode of players, inputs and results, on both sides. | `src/bridge.ts`, `godot/scripts/bridge_codec.gd` |
| **Export** | The Godot web build (`index.html`, `.js`, `.wasm`, `.pck`) written into `apps/shell/public/games/racing-carts/`. Never committed. | `scripts/export.sh` |
| **Stub race** | The temporary race of M1: one box per player on a floor, finished by the first ITEM press. Replaced in M2. | `godot/scripts/stub_race.gd` |
| **Bot** | The computer driving a kart nobody plays. The game always has 6 karts. | *`bot.gd` (M2)* |

## Race

| Term | Meaning | In code |
| --- | --- | --- |
| **Phase** | Where the race is: `countdown` → `racing` → `done`. A round starts at `countdown`. | *`race.gd` (M2)* |
| **Countdown** | 3-2-1-GO before racing. Input is ignored until GO. Drawn once across the whole screen. | *`race.gd`, `hud.gd` (M2, M4)* |
| **Lap** | One trip round the track. A race is 3 laps. | *`race.gd` (M2)* |
| **Position** / **place** | 1st, 2nd, … Finished karts rank first, in finish order; the rest rank by progress along the path. | *`race.gd` (M2)* |
| **Rank fraction** | 0 for the leader, 1 for last place. Weights item rolls and catch-up. | *rules script (M2)* |
| **Finish grace** | After the first human finishes, the others get 30 s before the round ends. | *`race.gd` (M2)* |
| **Input** | One tick's controls for a kart: steer −1..1, gas, brake, item. Players and bots both produce it. | `Bridge.input_for(slot)`, `BridgeCodec.NEUTRAL` |

## Track

| Term | Meaning | In code |
| --- | --- | --- |
| **Path** | The closed centre line of the road, a Godot `Path3D` / `Curve3D`. One source for road, walls, bots, rockets and lap progress. | *`track.tscn` (M2)* |
| **Progress** | How far along the path a kart is (`get_closest_offset`), with the lap count. Drives laps and ranking. | *`race.gd` (M2)* |
| **Grid** | The start positions, one per slot. | *`track.tscn` (M2)* |
| **Boost pad** | A chevron patch on the road that gives a 1 s boost. | *`Area3D` (M2)* |
| **Mud** | A brown patch on the track. While on it, top speed is 50 %, with a splash and a squelch. About 4 patches, placed where they tempt a shortcut. | *`Area3D` (M2)* |
| **Scenery** | Hills, trees, rocks, pond, clouds, fences, flowers, the start arch and the moving things. Looks only; karts never hit it. | *`scenes/` (M5)* |

## Kart and driving

| Term | Meaning | In code |
| --- | --- | --- |
| **Kart** | One racer's vehicle: a `CharacterBody3D`. The game always says *kart*; *cart* appears only in the product name. A kart's id is its slot. | *`kart.gd` (M2)* |
| **Slide** | Lower sideways grip: the kart drifts outward in fast corners, while low speed stays tight. There is no drift button. | *`kart.gd` (M2)* |
| **Spin-out** | A short loss of control (1.2 s) after a hit. | *`kart.gd` (M2)* |
| **Hit** | Something spins a kart out, unless its shield absorbs it. | *`kart.gd` (M3)* |
| **Bounce** | A fixed push back along the contact normal after a wall or kart hit. No speed-based maths. | *rules script (M2)* |
| **Boosted hit** | A boosted kart hitting a wall or kart: a bigger fixed bounce, no spin-out. | *rules script (M2)* |
| **Catch-up** | Karts further back get up to 6 % more top speed. Paused while touching walls and for 2 s after. | *rules script (M2)* |
| **Effect** | A timed state on a kart, such as boost or shield. Re-applying refreshes it, never stacks it. | *`kart.gd` (M2)* |

## Items

*Item* is one thing a kart holds or uses. The registry lists every item.

| Term | Meaning | In code |
| --- | --- | --- |
| **Item box** | A shimmering box on the track. Driving through it with no item starts a roll. It respawns 3 s after pickup. | *`Area3D` (M3)* |
| **Roll** / **roulette** | The 1 s spin after a pickup, then a weighted pick by rank fraction. Shown as 🎲. | *rules script (M3)* |
| **Registry** | The list of every item. Adding an item means one file plus one registry line. | *`items/registry.gd` (M3)* |
| **Shield** 🛡️ | Absorbs the next hit, or lasts 6 s. | *`items/` (M3)* |
| **Boost** ⚡ | +60 % top speed for 1.5 s. | *`items/` (M3)* |
| **Banana** 🍌 | Dropped behind the kart. The first kart over it spins out; the owner is safe for 0.5 s. It replaces the old mine. | *`items/` (M3)* |
| **Rocket** 🚀 | Follows the path and homes in on the next kart ahead; with nobody ahead it flies straight and pops on a wall. | *`items/` (M3)* |

Note: **boost** means three things: an item, an effect kind (also set by pads) and a sound name (`boost.mp3`). Say
which one you mean.

## Views and presentation

| Term | Meaning | In code |
| --- | --- | --- |
| **View** | One player's part of the screen: a `SubViewport` with its own camera, framed in the player's colour. Views share one world. | *`views.gd` (M4)* |
| **Split screen** | The layout of the views for 1–6 players, in slot order. | *`views.gd` (M4)* |
| **Chase camera** | The third-person camera behind and above a kart that eases behind its heading. A hit shakes only that player's view. | *`views.gd` (M4)* |
| **HUD** | Per view: place, lap, held item and "FINISHED". The countdown is drawn once across the screen. | *`hud.gd` (M4)* |
| **Particles** | Effects such as boost flame, dust, sparks, mud splash and confetti. | *(M5)* |
| **Sound** | Each sound is an mp3 in `godot/assets/sounds/`; a missing file stays silent. Not played yet. | `godot/assets/sounds/` |
