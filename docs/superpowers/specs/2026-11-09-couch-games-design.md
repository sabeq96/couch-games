# Couch Games — design

Date: 2026-11-09. Status: approved in brainstorming, awaiting spec review.

## Goal

Turn the `racing-carts` repository into **couch-games**: local co-op games on one shared screen with phones as
controllers.

- The main URL is the **shell**: it opens one room for the whole party, shows one QR code and the library of games.
- Phones scan once. The shell decides what every phone shows.
- A game is only the "meat": it plays one round with the players it is given and says when it is over. Lobby,
  results, play again, joining and controller layouts belong to the shell.
- Games may use any framework internally. Racing Carts (Babylon.js) is the first game.
- Shell and controller are built with Vite + Vue.

**Guiding rule: simplest possible.** One generic mechanism instead of special cases, shared screens and styles,
a minimal protocol, nothing speculative. Local co-op is assumed stable: no reconnect, retry or rejoin handling.

### Success criteria

1. `/` shows the shell: party bar (QR, code, players) and the library grid.
2. Phones join by scanning the QR. The lead player picks Racing Carts with the d-pad; everyone gets `tilt-racer`
   and races as today (simulation, rendering, bots, items unchanged).
3. At the end the shell shows results; the lead player picks play again or library with the d-pad.
4. Adding a game = adding a folder under `games/`. Adding a layout = one Vue file + one registry line + its input
   type.
5. Shell, controller and every shared screen share one look (`@couch/ui`).
6. `npm test`, `npm run typecheck` and `npm run e2e` pass; `npm run build` produces one GitHub Pages site.
7. The GitHub repository is renamed to `couch-games`.

## Terms

| Term | Meaning |
| --- | --- |
| **Host** / **shell** | The screen app at `/` (laptop, desktop, TV browser…). Owns the room, the party, the screens and the running game. |
| **Controller** | A phone running `/controller/`. Shows the layout the shell sends; sends input. Shows no game data. |
| **Party** | Everyone who joined the room. Visible on the host at all times. |
| **Lead player** | The earliest-joined player still connected. Navigates the shell screens with the d-pad. |
| **Layout** | A fixed set of controls on the phone: `wait`, `dpad`, `tilt-racer`. |
| **Game** | A folder under `games/` with a config object and a lazy `start` function. |
| **Round** | One run of a game, from `start` to `finish`. |

## Decisions

| Question | Decision |
| --- | --- |
| Who owns the room? | **The shell.** One room and one QR for the whole session. |
| How are games run? | **Inside the shell page.** A game is `import()`ed when chosen, gets an element to draw into, and is destroyed when the round ends or the host leaves. |
| Who decides the phone layout? | **The shell only**, via `state { layout, color }`. Games never talk to phones. |
| Does the phone show game data? | **No.** Layouts are static. |
| Navigation | Hash routes on one page: `#/`, `#/play/<id>`, `#/results/<id>`. Browser back and Escape on the host go to `#/`. |
| Game list | **No list file.** The shell finds `games/*/index.ts` with `import.meta.glob`; the id is the folder name. |
| Disconnects | **Out of scope.** A dropped phone just stops sending; the shell stops forwarding its input and the player stays in the round as they were. Reloading the phone joins as a new player. |
| Errors on the phone | One message: "Unable to join" (room gone, full, wrong code, connection lost). |
| Tizen TV build | **Dropped.** Web only. |

## Architecture

```
 phones                                host screen  /   (one page, one room)
┌───────────────────┐  WebRTC   ┌─────────────────────────────────────────────┐
│ /controller/ (Vue)│◀─────────▶│ shell (Vue)                                 │
│ Join │ layout     │           │  room + party ─ party bar (QR, players)     │
└───────────────────┘           │  #/          library grid                   │
     PeerJS broker:             │  #/play/id   <div> ← game.start(...)        │
     handshake only             │  #/results   results list                   │
                                └─────────────────────────────────────────────┘
```

No server of our own, as today. The host is authoritative.

### Workspaces

```
couch-games/
├─ packages/
│  ├─ shared/   @couch/shared   protocol messages, layout ids + input types, Game/Round types, room codes,
│  │                            player colours. No DOM code, no libs.
│  └─ ui/       @couch/ui       one CSS file: tokens + base classes. No JS.
├─ apps/
│  ├─ shell/       Vue, served at /            room, party, screens, game mounting
│  └─ controller/  Vue, served at /controller/ join screen + layouts
├─ games/
│  └─ racing-carts/   index.ts (config) + src/ (today's apps/game, minus its lobby/net/results)
├─ e2e/              Playwright tests
└─ scripts/build.sh
```

Dependency rules: apps never import each other; games import only `@couch/shared` (types) and their own libraries;
only the shell imports games (lazily). Host networking lives in the shell, phone networking in the controller —
each has one user, so neither is a package.

## Protocol (`@couch/shared`)

```ts
// phone → shell
{ t: 'hello', name: string }
{ t: 'input', ...LayoutInput }            // 30 Hz (INPUT_HZ)

// shell → phone
{ t: 'state', layout: LayoutId, color: string }   // on join and whenever the shell changes screen
```

- `LayoutId = 'wait' | 'dpad' | 'tilt-racer'`.
- Inputs: `wait` sends nothing; `DpadInput = { up, down, left, right, a, b }`;
  `TiltRacerInput = { steer, gas, brake, item }`.
- `PEER_PREFIX = 'couchgames-'`. Room codes as today; `openPeer` retries taken codes.
- Decoding stays as today: unknown or malformed messages are dropped; input whose fields do not match the phone's
  current layout is ignored.
- **Sending:** the phone tracks controls continuously and sends one snapshot every ~33 ms; a per-button latch keeps
  taps shorter than that. The shell keeps the latest snapshot per player.
- The party holds at most 6 players (6 colours). A 7th phone is closed and sees "Unable to join".

## Game contract

```ts
// games/racing-carts/index.ts — tiny, loaded by the library
import type { Game } from '@couch/shared';
import cover from './cover.png';

export default {
  title: 'Racing Carts',
  cover,
  layout: 'tilt-racer',
  players: { min: 1, max: 6 },
  load: () => import('./src/game'),     // game code downloads only when opened
} satisfies Game;
```

```ts
// games/racing-carts/src/game.ts — every game exports a start with this shape
import type { Round } from '@couch/shared';

export function start({ el, players, finish }: Round) {
  // players: [{ slot, name, color }]; call finish([{ slot, place }]) when the round is over
  return {
    input(slot: number, input: TiltRacerInput) {},
    destroy() {},   // free WebGL, audio, timers, listeners
  };
}
```

The shell calls `start`, forwards each player's input to `input`, and calls `destroy` when the round finishes or
the host leaves. Nothing else crosses the boundary.

**Assets are imported, never served from a `public/` folder** (a game is a chunk of the shell build, so only the
shell's `public/` exists): `import cover from './cover.png'`, and sounds via
`import.meta.glob('./audio/*.mp3', { query: '?url', eager: true })`.

## Shell (`apps/shell`, Vue)

**Party bar**, always visible: QR, room code, controller URL, and each player's colour + name (lead marked). Full
size on library and results, a compact chip during a round. New phones can join at any time.

**Screens and layouts:**

| Route | Host shows | Lead player's phone | Other phones |
| --- | --- | --- | --- |
| `#/` | library grid; games needing more players than the party has are greyed out | `dpad`: move, **A** open | `wait` |
| `#/play/<id>` | the game in a full-screen `<div>` | the game's layout | the game's layout |
| `#/results/<id>` | finishing order from `finish` | `dpad`: **A** play again, **B** library | `wait` |

- A round starts with the first `max` players by join order; the rest get `wait` and watch. Too many players never blocks a game. Players who join mid-round get
  `wait` and play in the next round.
- Shell screens act on **presses** (a button going from up to down), never on held state, so an A still held
  when results appear does not trigger play again.
- The host's mouse/keyboard can also navigate the grid and results. Escape or browser back during a round destroys
  the game and returns to `#/`.
- Refreshing the host page opens a new room (out of scope to keep it).

## Controller (`apps/controller`, Vue)

- **Message screen**, one generic component (text + optional input + optional button), used for:
  - Join: room code (prefilled from `?room=`) + name + **Join**. Empty code → "Type the 4 letters from the screen".
  - "Connecting…".
  - "Unable to join" + **Try again** (any failure before or after joining).
- **Layouts** (`src/layouts/`, one registry):
  - `wait`: the message screen with "Look at the screen" in the player's colour.
  - `dpad`: d-pad + A + B.
  - `tilt-racer`: tilt meter, GAS, BRAKE, ITEM, Center, and ◀ ▶ when motion is unavailable (today's controls,
    minus every game-data display).
- Kept as plain TS with tests: `tilt.ts`, per-button `latch.ts`, the 30 Hz sender, the connection (today's
  `connection.ts` minus reconnect, token and watchdog).
- Phone setup kept: motion permission, wake lock, landscape lock for `tilt-racer`.
- `?demo=<layout>` shows a layout with no host.

## Shared look (`@couch/ui`)

One CSS file used by the shell and the controller; it carries today's cozy look:

- Tokens: `--cream`, `--ink`, `--ink-soft`, the six pastel player colours with `-ink` pairs, `--font` (Nunito), one
  radius, one spacing scale.
- Base classes: `.cg-screen`, `.cg-card`, `.cg-button`, `.cg-input`, `.cg-grid`, `.cg-chip`.
- Library cards, results list, party bar, phone message screen and phone buttons are all built from these. Games
  may use them; in-game rendering stays the game's own.

## Racing Carts changes

Simulation, rendering, audio, bots and items stay. The edges shrink to the game contract:

- `main.ts` becomes `start({ el, players, finish })`: build the scene in `el`, give each player a kart in their
  colour, fill the rest with bots, run countdown → race, then call `finish` with the finishing order.
- Removed: `net/`, `Session`'s lobby/rematch/host-player/reconnect/bot-takeover/`syncPhones`, `PlayerRegistry`, the
  lobby and results HUD, the join card, `probe.ts`, the keyboard player, URL flags, `public/config.xml`, the
  chrome85/IIFE build target.
- `input(slot, TiltRacerInput)` maps to the kart's `InputSnapshot`.
- `destroy()` disposes the Babylon engine, stops audio and removes listeners.
- `public/audio/*.mp3` and `public/icon.png` move into the game's `src/` and are imported (see the game contract).
- Racing constants (`TOTAL_LAPS`, `KART_COLORS` order, `Phase`) move into the game.

## Build and deploy

- `npm run build` (`scripts/build.sh`): shell at `/`, controller at `/controller/`, in `output/`. Games are code-split
  chunks of the shell build.
- The site base (`/couch-games/`) is set once and read by both Vite configs; the controller URL is derived from it.
- `.github/workflows/deploy-web.yml`: build → e2e → publish on every push to `main`.
- Removed: `build:tv`, `scripts/build-tv.sh`, `scripts/build-web.sh`, `docs/tizen-sideload.md`.
- New dependencies (`vue`, `@vitejs/plugin-vue`, `@playwright/test`, `peer`) are installed with the npm CLI,
  following each project's official setup guide.

## Testing

Rule: everything built is tested. Large flows by **Playwright e2e**, pure logic by **Vitest**.

### Playwright e2e (`e2e/`)

- Set up with `npm init playwright@latest`.
- `npm run e2e` serves the built site and a **local PeerJS server** (`peer` package) via Playwright `webServer`. The
  broker address is one env value read by shell and controller (default: the public PeerJS cloud).
- The host runs in one browser context; each phone in its own context with a mobile viewport and no motion sensors
  (so `tilt-racer` shows ◀ ▶).
- Flows:
  1. Shell shows the party bar (code + QR) and the library grid with Racing Carts.
  2. A phone joins via `/controller/?room=<code>`: it appears in the party bar in its colour and gets `dpad`; a
     second phone gets `wait`.
  3. Lead player moves and presses A on Racing Carts: host goes to `#/play/racing-carts`, both phones get
     `tilt-racer`, the race canvas appears.
  4. Escape on the host: game destroyed, back to `#/`, phones back to `dpad` / `wait`. Opening the game again works
     (checks `destroy`).
  5. A round that calls `finish` shows results; A plays again, B returns to the library. (Uses a tiny test game
     under `e2e/fixtures/` that finishes on the lead player's input, so no full race is needed. The e2e build sets
     `E2E=1`, which makes the shell also glob `e2e/fixtures/*/index.ts`; production builds never include it.)
  6. Wrong code → "Unable to join"; empty code → the hint.
  7. `?demo=dpad` and `?demo=tilt-racer` render with no host.
- Runs in CI before deploy.

### Vitest

- Existing tests move with their code (protocol, tilt, latch, connection, all race simulation tests).
- New: message decoding, party (slots, colours, lead player, max 6), layout per screen per player, per-button latch,
  Racing Carts `start` mapping input and calling `finish` with the order.

## Docs

`ARCHITECTURE.md`, `FEATURES.md`, `GLOSSARY.md` and `README.md` are rewritten for shell / party / lead player /
layout / game / round. Stories that no longer apply are removed (phone HUD, drift glow, vibration, reconnect, lobby
and rematch inside the game, keyboard player, URL flags, probe, TV builds). New stories: join the party, see the
party, pick a game with the d-pad, play a round, results and play again, back to the library, add a game by folder.

## Order of work

Each step lands with its tests and leaves the repo building.

1. Workspace skeleton: `@couch/shared` (protocol, types), `@couch/ui`, Vue shell and controller apps, Playwright +
   local PeerJS server. First prove two Playwright contexts connect over WebRTC through the local server, locally
   and in GitHub Actions, before building on it. The old `apps/controller` is replaced in place; `apps/game` stays
   untouched until step 3 moves it.
2. Shell party + controller join, message screen, `wait` and `dpad` layouts, library grid (with the e2e test game).
3. Racing Carts moved to `games/racing-carts` and reduced to the game contract; `tilt-racer` layout.
4. Results and play again; Tizen removal; one build script; deploy workflow.
5. Docs.
6. Rename: `gh repo rename couch-games`, update the git remote and site base. Done last and only after
   confirmation, since old `…/racing-carts/` links stop working.

## Out of scope

- Reconnect, retry, rejoin, host refresh keeping the room.
- Any new game beyond Racing Carts (plus the e2e test fixture).
- Layout changes mid-round, game data on phones.
- Any server of our own, accounts, saved scores.
