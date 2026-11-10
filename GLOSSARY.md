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

## Racing Carts

The game has its own glossary: [games/racing-carts/GLOSSARY.md](games/racing-carts/GLOSSARY.md) (race, track, kart,
items, bridge, views, bots).
