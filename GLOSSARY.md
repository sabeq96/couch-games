# Glossary

The domain language of Couch Games. Use these names in code, docs and commits. When a new concept appears,
add it here first.

## People and devices

| Term | Meaning | In code |
| --- | --- | --- |
| **Host** / **shell** | The screen app at `/` (laptop, desktop, TV browser…). Owns the room, the party, the screens and the running game. | `apps/shell` |
| **Controller** / **phone** | A phone running `/controller/`. Shows the layout the shell sends and sends input. Shows no game data. | `apps/controller` |
| **Player** | A person in the party. Has a slot, a name and a colour. | `Player` (`@couch/shared`) |
| **Party** | Everyone who joined the room, at most 6. Always visible on the host. | `Party` (`apps/shell/src/party.ts`), `MAX_PARTY` |
| **Lead player** | The earliest-joined player still in the party. Navigates the shell screens with the d-pad; the role passes on when they leave. | `Party.lead()` |
| **Bot** | The computer driving a Racing Carts kart nobody plays. | `games/racing-carts/src/bots/bot.ts` |

## Room and networking

| Term | Meaning | In code |
| --- | --- | --- |
| **Room** | The one session phones join. Lives as long as the shell page is open; a reload opens a new one. | `openRoom` (`room/host.ts`) |
| **Room code** | 4 letters with no ambiguous ones (no I, L, O). Carried in the QR code and in `?room=`. | `makeRoomCode`, `ROOM_ALPHABET` |
| **Peer ID** | The PeerJS id the shell opens: `couchgames-<CODE>`. | `peerIdFor`, `PEER_PREFIX` |
| **Broker** | The public PeerJS server that only does the WebRTC handshake. Tests use a local one. | `peerOptions`, `scripts/e2e-serve.mjs` |
| **Slot** | A place in the party, 0 to 5. It fixes the player's colour. A Racing Carts kart's id equals its slot. | `Player.slot` |
| **Color** | The player's colour, by slot. Shown in the party bar, on the phone and on the kart. | `PLAYER_COLORS` |
| **Press** | A d-pad key going from up to down. Shell screens act on presses, never on held keys. | `Presses` (`presses.ts`) |

## Protocol messages

All defined in `packages/shared/src/protocol.ts` and sent as JSON with a `t` field.

| Message | Direction | Meaning |
| --- | --- | --- |
| `hello` | phone → shell | Join the party with a name. |
| `input` | phone → shell | The current layout's controls, about 30 times a second (`INPUT_HZ`). |
| `state` | shell → phone | Which layout to show and the player's colour. |

## Screens, layouts and games

| Term | Meaning | In code |
| --- | --- | --- |
| **Library** | The shell screen at `#/`: a grid of the games found in `games/`. | `LibraryScreen.vue` |
| **Route** | Where the shell is: `#/`, `#/play/<id>` or `#/results/<id>`. | `Route`, `routeOf` (`routes.ts`) |
| **Party bar** | The strip on the host with the QR code, room code, controller URL and the players. Compact during a round. | `PartyBar.vue` |
| **Layout** | A fixed set of controls on the phone: `wait`, `dpad` or `tilt-racer`. Only the shell picks it. | `LayoutId`, `layouts` (`controller/src/layouts/`) |
| **Layout input** | What a layout sends: `DpadInput` or `TiltRacerInput` (`wait` sends nothing). | `LayoutInputs`, `decodeInput` |
| **Message screen** | The phone's one generic screen: text with an optional join form or button. | `MessageScreen.vue` |
| **Game** | A folder under `games/` with a config object and a lazy `start`. The folder name is its id. | `Game` (`@couch/shared`), `games/*/index.ts` |
| **Round** | One run of a game, from `start` to `finish`. | `Round`, `RoundHandle` |
| **Roster** | The players taking part in a round: the first `max` of the party by join order. | `Party.roster` |
| **Results** | The finishing order a game reports with `finish`, shown on the shell until play again or the library. | `Result`, `ResultsScreen.vue` |
| **Play again** | The lead player's **A** on the results: a new round of the same game. | `ResultsScreen.vue` |

## Build and test

| Term | Meaning |
| --- | --- |
| **Site** | The one GitHub Pages build in `output/`: shell at `/`, controller at `/controller/` (`npm run build`). |
| **Theme** | `packages/ui/theme.css`: the daisyUI `couch` theme and the player colours. The only place for look. |
| **Demo** | `?demo=<layout>` on the controller: a layout with no host. |
| **Fixture game** | A tiny game under `e2e/fixtures/` that finishes on the lead player's input. Only in e2e builds. |

## Race (Racing Carts)

| Term | Meaning | In code |
| --- | --- | --- |
| **Phase** | Where the race is: `lobby` → `countdown` → `racing` → `results`. A round starts it at `countdown`. | `Phase` (`rules.ts`), `Race` (`race/race.ts`) |
| **Countdown** | 3-2-1-GO before racing. Input is ignored until GO. | `RaceEvent` `countdown` / `go` |
| **Lap** | One trip round the track. A race is 3 laps. | `TOTAL_LAPS`, `lapOf` |
| **Distance** | How far a kart has driven along the centre line since the start, in metres. Drives laps and ranking. | `Kart.distance`, `updateProgress` |
| **Position** / **rank** | 1st, 2nd, … Finished karts rank first, in finish order; the rest rank by distance. | `compareRank` |
| **Rank fraction** | 0 for the leader, 1 for last place. Weights item rolls and catch-up. | `rankFraction` (`powerups/odds.ts`) |
| **Finish grace** | After the first human finishes, the others get 30 s before the round ends. | `FINISH_GRACE` |
| **Driver** | Whoever drives a kart this step (a player or a bot). The simulation only sees a `Driver` and its `InputSnapshot`. | `Driver` (`game.ts`), `Drivers` (`drivers.ts`) |
| **Input snapshot** | One step's input for a kart: steer −1..1, gas, brake, item. Players and bots both produce it. | `InputSnapshot`, `NEUTRAL_INPUT` |

## Track

| Term | Meaning | In code |
| --- | --- | --- |
| **Track definition** | The data a track is built from: centre-line control points, width, item-box and boost-pad spots. | `TrackDef`, `TRACK_V1` |
| **Track** | The built track: centre line, `project` (world point → distance and lateral), grid, boxes, pads and bounds. | `Track`, `buildTrack` |
| **Centre line** | The closed spline down the middle of the road. | `Track.points` |
| **Lateral** | Signed sideways offset from the centre line, in metres, right positive. | `Kart.lateral` |
| **Racing line** | The line bots aim along; the centre line plus a per-bot lane offset. | `bots/bot.ts` |
| **Grid** | The start positions, one per slot. | `Track.grid` |
| **Scenery** / **decor** | Trees, rocks, pond, clouds, fences, flowers and the start arch. Looks only; karts never hit them. | `render/scene.ts`, `render/decor.ts` |

## Kart and driving

| Term | Meaning | In code |
| --- | --- | --- |
| **Kart** | One racer's vehicle and its whole simulation state. The game always says *kart*; *cart* appears only in the product name. | `Kart` (`kart/kart.ts`) |
| **Tuning** | The arcade physics constants. | `kart/tuning.ts` |
| **Spin-out** | A short loss of control (1.2 s) after a hit. | `Kart.spin`, `SPIN_TIME` |
| **Hit** | Something spins a kart out, unless its shield absorbs it. | `WorldApi.hitKart` |
| **Wall bounce** / **wall scrape** | A soft bounce off the track wall, plus extra speed loss while touching it. | `WALL_RESTITUTION`, `WALL_SCRAPE` |
| **Bump** | Two karts pushing apart. | `resolveKartCollisions` |
| **Drift** | A power slide: BRAKE plus steer at speed. | `Kart.drift` |
| **Mini-turbo** | A boost paid when a drift ends. Level 1 or 2 by how long the drift lasted. | `driftLevel`, `MT1`, `MT2` |
| **Slipstream** / **draft** | Tucking in behind the next kart charges a short boost. | `stepSlipstream`, `Kart.draft` |
| **Boost pad** | A chevron patch on the road that gives a 1 s boost. | `BoostPads` (`race/boostPads.ts`) |
| **Catch-up** | Karts further back get up to 6 % more top speed. Paused while touching walls. | `CATCHUP`, `Game.updateCatchUp` |
| **Effect** | A timed state on a kart, named by a string: `boost`, `shield`. Re-applying refreshes it, never stacks it. | `Effect`, `refreshEffect`, `effectLeft` |

Note: **boost** means three things. It is an item id (`powerups/items/boost.ts`), an effect kind (`'boost'`, also set by pads, drafts and mini-turbos) and a sound name (`boost.mp3`). Say which one you mean.

## Items (powerups)

*Powerup* is the system and the code folder (`powerups/`). *Item* is one thing a kart holds or uses. Both
words refer to the same objects, so `kart.item` holds a powerup id.

| Term | Meaning | In code |
| --- | --- | --- |
| **Powerup definition** | One item type: id, name, icon, roll weight, `use`, and optionally `botShouldUse`. | `PowerupDef` (`powerups/types.ts`) |
| **Registry** | The list of every powerup. Adding an item means one file and one line here. | `POWERUPS`, `getPowerup` |
| **Item box** | A shimmering box on the track. Driving through it with no item starts a roll. It respawns 3 s after pickup. | `ItemBoxes` |
| **Roll** / **roulette** | The 1 s spin after a pickup, then a weighted pick by rank fraction. Shown as 🎲. | `rollItem`, `Kart.rolling` |
| **World** | The only API items use to change the game: entities, effects, hits, race order and sounds. | `WorldApi`, `createWorld` |
| **Entity** | A thing on the track spawned by an item, such as a mine or a rocket. | `PowerupEntity` |
| **Look** | How render draws an entity: shape, colour, size and extras. Render has no per-item code. | `EntityLook` |
| **Shield** 🛡️ | Absorbs the next hit, or lasts 6 s. | `items/shield.ts` |
| **Boost** ⚡ | +60 % top speed for 1.5 s. | `items/boost.ts` |
| **Mine** 💣 | Dropped behind the kart. The first kart to touch it spins out. | `items/mine.ts` |
| **Rocket** 🚀 | Follows the track and homes in on the next kart ahead. | `items/rocket.ts` |

## Racing Carts rendering and audio

| Term | Meaning | In code |
| --- | --- | --- |
| **Scene** | The Babylon.js world: lights, ground, road, walls and scenery. | `createScene` |
| **Views** | Render objects that mirror simulation state each frame: karts, entities, sparks. | `KartViews`, `EntityViews`, `SparkViews` |
| **Camera rig** | One shared camera that fits all human karts, up to the whole track. | `CameraRig`, `fitCamera` |
| **Trauma** | How strongly the camera shakes after a hit on a human kart. Fades out. | `HIT_TRAUMA`, `decayTrauma` |
| **HUD** | The game's HTML overlay: race list, countdown and messages. Drawn on a 1920×1080 stage. | `Hud` (`render/hud.ts`) |
| **Sound manifest** | Every music and sound-effect name. Each one is an mp3 in `games/racing-carts/src/audio/files/`. | `audio/manifest.ts` |
| **Sound director** | Decides which sound plays for what happens in the game. | `SoundDirector` |
