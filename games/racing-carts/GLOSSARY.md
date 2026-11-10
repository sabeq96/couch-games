# Racing Carts: glossary

The domain language of Racing Carts, the Godot game. For the words of the whole site (party, room, layout…), see the
root [GLOSSARY.md](../../GLOSSARY.md). Design: [spec](../../docs/superpowers/specs/2026-11-10-racing-carts-godot-design.md).

Milestones (M1–M5) are listed in the spec. **In code** names what exists today; a name in *italics* is where the
term will live (planned, milestone in brackets). Paths are under `games/racing-carts/`.

## The game and its shell link

| Term | Meaning | In code |
| --- | --- | --- |
| **Bridge** | The link between the shell page and Godot: one global, `window.racingCarts`, with players, inputs and the finish callback. Two halves: the TypeScript side and the Godot side. | `src/game.ts`, `src/bridge.ts`, `godot/scripts/bridge.gd` |
| **Bridge global** | `window.racingCarts`: `players` and `inputs` (JSON), `e2e`, `ready()`, `finish(json)`, and in e2e builds `karts` and `finishNow`. Exists only while a round runs. | `RacingCartsGlobal` (`src/game.ts`) |
| **Pull** | Godot reads `inputs` itself every physics tick; the page never calls into Godot. | `Bridge._physics_process` |
| **Codec** | The pure JSON encode/decode of players, inputs and results, on both sides. | `src/bridge.ts`, `godot/scripts/bridge_codec.gd` |
| **Export** | The Godot web build (`index.html`, `.js`, `.wasm`, `.pck`) written into `apps/shell/public/games/racing-carts/`. Never committed. | `scripts/export.sh` |
| **Bot** | The computer driving a kart nobody plays. The game always has 6 karts. | `godot/scripts/bot.gd` (`BotDriver`) |

## Race

| Term | Meaning | In code |
| --- | --- | --- |
| **Phase** | Where the race is: `countdown` → `racing` → `done`. A round starts at `countdown`. | `Race.Phase` (`race.gd`) |
| **Countdown** | 3-2-1-GO before racing. Input is ignored until GO. Drawn once across the whole screen. | `race.gd` (`HUD/Countdown`) |
| **Lap** | One trip round the track. A race is 3 laps. | `TrackProgress.laps_done`, `RaceRules.TOTAL_LAPS` |
| **Position** / **place** | 1st, 2nd, … Finished karts rank first, in finish order; the rest rank by progress along the path. A player's result place is counted among all 6 karts, bots included. | `RaceRules.ranking`, `RaceRules.places` |
| **Rank fraction** | 0 for the leader, 1 for last place. Weights item rolls and catch-up. | `RaceRules.catchup_scale` |
| **Finish grace** | After the first human finishes, the others get 30 s before the round ends. | `RaceRules.FINISH_GRACE`, `RaceRules.is_over` |
| **Input** | One tick's controls for a kart: steer −1..1, gas, brake, item. Players and bots both produce it. | `Bridge.input_for(slot)`, `BridgeCodec.NEUTRAL` |

## Track

| Term | Meaning | In code |
| --- | --- | --- |
| **Path** | The closed centre line of the road, a Godot `Path3D` / `Curve3D`. One source for road, walls, bots, rockets and lap progress. | `track.tscn` (`CentreLine`) |
| **Offset** | A distance in metres along the path from the start line, in the direction of travel. A point is an offset plus a lateral distance to the right. | `Track.offset_of`, `Track.point_at` |
| **TrackProgress** | Counts one kart's laps from its offset and gives its race distance (laps × length + offset), which ranks karts that have not finished. Karts start behind the line, so their offset counts as negative until they cross it. | `godot/scripts/track_progress.gd` |
| **Grid** | The 6 start positions, two columns of three rows behind the line. Humans take them in party-slot order, bots the rest. | `Track.grid_transform`, `RaceRules.grid` |
| **Boost pad** | A chevron patch on the road that gives a 1 s boost (7 on the track). | `Area3D`, group `boost_pad` |
| **Mud** | A brown patch on the track. While on it, top speed is 50 %, with a splash and a squelch (M5). 4 patches, placed where they tempt a shortcut. | `Area3D`, group `mud` |
| **Scenery** | Hills, trees, rocks, pond, clouds, fences, flowers, the start arch and the moving things. Looks only; karts never hit it. | *`scenes/` (M5)* |

## Kart and driving

| Term | Meaning | In code |
| --- | --- | --- |
| **Kart** | One racer's vehicle: a `CharacterBody3D`. The game always says *kart*; *cart* appears only in the product name. A kart's id is its slot. | `godot/scripts/kart.gd` |
| **Slide** | The velocity follows only part of a heading change (`SLIP`) and the rest becomes sideways speed that grip removes: the kart drifts outward in fast corners, while low speed stays tight. There is no drift button. | `KartPhysics`, `KartTuning.SLIP`, `GRIP` |
| **Spin-out** | A short loss of control (1.2 s) after a hit. | `Kart.spin_out` |
| **Hit** | Something spins a kart out, unless its shield absorbs it. | `Kart.hit`, `ItemWorld.hit` |
| **Bounce** | A fixed push back along the contact normal after a wall or kart hit. No speed-based maths. | `KartPhysics.wall_bounce`, `kart_bounce` |
| **Boosted hit** | A boosted kart hitting a wall or kart: a bigger fixed bounce, no spin-out. | `KartPhysics` |
| **Catch-up** | Karts further back get up to 6 % more top speed. Paused while touching walls and for 2 s after. Bots' cruise speed scales with it. | `RaceRules.catchup_scale`, `Kart.top_speed_scale` |
| **Effect** | A timed state on a kart, such as boost or shield. Re-applying refreshes it, never stacks it. | `Kart.boost`, `Kart.shield` |

## Items

*Item* is one thing a kart holds or uses. The registry lists every item.

| Term | Meaning | In code |
| --- | --- | --- |
| **Item** | One kind of pickup, an `ItemDef` script with an id, a HUD colour, odds, a use and a bot rule. A kart holds one. | `godot/scripts/items/item_def.gd`, `Kart.held_item` |
| **ItemWorld** | What items see of the race and do to it: karts in race order, the track, rank fractions, spawning and hits. The race owns it. | `godot/scripts/item_world.gd` |
| **Item box** | A shimmering box on the track (two rows of four). Driving through it with no item starts a roll. It respawns 3 s after pickup. | `godot/scripts/item_box.gd` |
| **Roll** / **roulette** | The 1 s spin after a pickup, then a weighted pick by rank fraction. Shown as `?` on the HUD. | `ItemRegistry.roll`, `Kart.roll_left` |
| **Rank fraction** | 0 for the leader, 1 for the last kart (0 when alone); the odds of each item are a function of it. | `ItemWorld.rank_fraction` |
| **Registry** | The list of every item. Adding an item means one file plus one `preload` line. | `godot/scripts/items/registry.gd` |
| **Shield** 🛡️ | Absorbs the next hit, or lasts 6 s. | `items/shield.gd`, `Kart.shield` |
| **Boost** ⚡ | +60 % top speed for 1.5 s. | `items/boost.gd`, `Kart.boost` |
| **Banana** 🍌 | Dropped 2.5 m behind the kart, lasts 30 s. The first kart to touch it is hit; the owner is safe for 0.5 s. It replaces the old mine. | `items/banana.gd`, `godot/scripts/banana.gd` |
| **Rocket** 🚀 | Follows the track and homes in on the next kart ahead once within 10 m; with nobody ahead it flies straight and pops when it leaves the road. | `items/rocket.gd`, `godot/scripts/rocket.gd` |

Note: **boost** means three things: an item, an effect kind (also set by pads) and a sound name (`boost.mp3`). Say
which one you mean.

## Views and presentation

| Term | Meaning | In code |
| --- | --- | --- |
| **View** | One player's part of the screen: a `SubViewport` with its own chase camera and HUD, framed in the player's colour. Views share one world. | `Views` (`godot/scripts/views.gd`) |
| **Split screen** | The layout of the views for 1–6 players, in slot order. | `ViewLayout` (`godot/scripts/view_layout.gd`) |
| **Chase camera** | The third-person camera behind and above a kart that eases behind its heading. A hit shakes only that player's view. | `ChaseCamera` (`godot/scripts/chase_camera.gd`) |
| **HUD** | Per view: place, lap, held item (an uppercase word in a pill) and "FINISHED". Plain text, no emoji. The countdown is drawn once across the screen. | `ViewHud` (`godot/scripts/view_hud.gd`) |
| **Particles** | Effects such as boost flame, dust, sparks, mud splash and confetti. | *(M5)* |
| **Sound** | Each sound is an mp3 in `godot/assets/sounds/`; a missing file stays silent. Not played yet. | `godot/assets/sounds/` |
