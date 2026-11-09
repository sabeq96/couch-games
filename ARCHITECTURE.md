# Architecture

How Couch Games is put together. For the words used here, see [GLOSSARY.md](GLOSSARY.md). For what it does,
see [FEATURES.md](FEATURES.md).

## Overview

```
 phones                                host screen  /   (one page, one room)
┌───────────────────┐  WebRTC   ┌─────────────────────────────────────────────┐
│ /controller/ (Vue)│◀─────────▶│ shell (Vue)                                 │
│ Join │ layout     │           │  room + party ─ party bar (QR, players)     │
└───────────────────┘           │  #/            library grid                 │
     PeerJS broker:             │  #/play/<id>   <div> ← game.start(...)      │
     handshake only             │  #/results/<id> results list                │
                                └─────────────────────────────────────────────┘
```

- **The shell is authoritative.** It owns the one room, the party, the screens and the running game. Phones send
  input and show the layout the shell tells them to show.
- **Games never talk to phones.** A game is given the players and a `<div>`, plays one round and says when it is over.
- **No server of our own.** The shell opens a PeerJS peer named after the room code. The public PeerJS broker
  only does the handshake; game traffic then goes peer to peer.
- **Local co-op is assumed stable.** There is no reconnect, retry or rejoin: a dropped phone leaves the party, and
  reloading a phone joins as a new player.

## Workspaces

An npm workspaces monorepo. TypeScript and Vitest everywhere; Vite + Vue for the two apps.

| Workspace | What it is | Depends on |
| --- | --- | --- |
| `packages/shared` (`@couch/shared`) | Protocol messages and decoding, layout ids and input types, the `Game` / `Round` types, room codes, player colours, PeerJS options. No DOM code. | nothing |
| `packages/ui` (`@couch/ui`) | `theme.css`: Tailwind + the daisyUI `couch` theme. No JS. | nothing |
| `apps/shell` (`@couch/shell`) | The host screen at `/`: room, party, hash routes, library, play and results screens, game mounting. | `@couch/shared`, `@couch/ui`, `vue`, `peerjs`, `qrcode` |
| `apps/controller` (`@couch/controller`) | The phone page at `/controller/`: join and message screens, the layouts. | `@couch/shared`, `@couch/ui`, `vue`, `peerjs` |
| `games/racing-carts` (`racing-carts`) | The first game: `index.ts` (config) and `src/` (simulation, rendering, audio, bots, items). | `@couch/shared`, `@babylonjs/core` |
| `e2e/` | Playwright tests and the fixture game. Not a workspace. | the built site |

Dependency rules: apps never import each other; games import only `@couch/shared` (types) and their own libraries;
only the shell imports games, and lazily. Host networking lives in the shell and phone networking in the
controller, since each has one user.

Root files: `site.config.ts` (the site base, `/couch-games/`, read by both Vite configs), `eslint.config.js`,
`playwright.config.ts`, `scripts/build.sh`, `scripts/e2e-serve.mjs`.

## Protocol (`packages/shared/src`)

Defined in `protocol.ts` and `layouts.ts`, sent as JSON with a `t` field.

| Message | Direction | Meaning |
| --- | --- | --- |
| `hello { name }` | phone → shell | Join the party. The name is trimmed and cut to 12 characters; empty becomes "Player". |
| `input { ...fields }` | phone → shell | The current layout's controls, about 30 times a second (`INPUT_HZ`). |
| `state { layout, color }` | shell → phone | Which layout to show and the player's colour. Sent on join and whenever the shell changes screen. |

- `LayoutId = 'wait' | 'dpad' | 'tilt-racer'`. `wait` sends nothing. `DpadInput = { up, down, left, right, a, b }`.
  `TiltRacerInput = { steer, gas, brake, item }`.
- Decoding drops unknown or malformed messages. The shell decodes input against the layout it last sent that
  phone (`decodeInput`, `inputRouting.ts`), so input from a layout the phone has not left yet is ignored.
- The phone tracks controls continuously and sends one snapshot per interval (`startSender`, `sender.ts`). A
  per-button latch (`latch.ts`) keeps taps shorter than that interval.
- Room codes are 4 letters (`ROOM_ALPHABET`, no I, L, O). The peer id is `couchgames-<CODE>` (`PEER_PREFIX`).
  `openRoom` retries a taken code.
- The party holds at most `MAX_PARTY` (6) players. A 7th phone is closed and sees "Unable to join".

## Shell (`apps/shell/src`)

| File | What it does |
| --- | --- |
| `App.vue` | The composition root: owns the party, the route and the current round; opens the room; sends each phone its `state` (`syncStates`); routes input; handles the host keyboard. |
| `room/host.ts` | `openRoom`: PeerJS host. Opens a peer under a fresh code, accepts `hello` and `input`, turns a full party away. |
| `party.ts` | `Party`: players by connection id in join order, lowest free slot, colour per slot, `lead()`, `roster(max)`. |
| `router.ts`, `layoutFor.ts` | Hash routes (`#/`, `#/play/<id>`, `#/results/<id>`) and the layout each player gets on a route. |
| `inputRouting.ts` | `routeInput`: where a phone's input goes (the running game, or the screen's presses). |
| `presses.ts` | `Presses`: turns d-pad snapshots into presses (a key going from up to down). |
| `grid.ts` | `move`: d-pad movement in the library grid. |
| `games.ts` | `games`: the games found with `import.meta.glob('games/*/index.ts')`; the folder name is the id. |
| `screens/` | `LibraryScreen.vue`, `PlayScreen.vue`, `ResultsScreen.vue`. |
| `components/PartyBar.vue` | QR, room code, controller URL and the players, lead marked. Compact during a round. |

### Screens and layouts

| Route | Host shows | Lead player's phone | Other phones |
| --- | --- | --- | --- |
| `#/` | library grid; games needing more players than the party has are greyed out | `dpad`: move, **A** open | `wait` |
| `#/play/<id>` | the game in a full-screen `<div>` | the game's layout | the game's layout |
| `#/results/<id>` | finishing order from `finish` | `dpad`: **A** play again, **B** library | `wait` |

- A round starts with the first `max` players by join order. The rest get `wait`. Players who join mid-round get
  `wait` and play in the next round. A game needing more players than are in the party cannot be opened.
- Shell screens act on **presses**, never on held state, so an A still held when results appear does not trigger
  play again (`Presses.reset` on every route change).
- The host keyboard works too: arrows move, Enter is A, Backspace is B, Escape leaves a round.
- Only library → play adds a history entry; every other move replaces the current one. Browser back and Escape
  therefore land on `#/`, destroy the game, and never start a round.
- A reloaded host opens a new room.

### Running a round

`PlayScreen` loads the game (`game.load()`), calls `start({ el, players, finish })`, forwards each roster
member's input to the returned `input(slot, input)` and calls `destroy()` when the round finishes or the screen goes away (at most once). `finish`
sends the shell to `#/results/<id>` with the results. Nothing else crosses the boundary.

## Controller (`apps/controller/src`)

| File | What it does |
| --- | --- |
| `App.vue` | Join form, "Connecting…" and "Unable to join" screens, then the layout from the latest `state`. `?demo=<layout>` shows a layout with no host. |
| `MessageScreen.vue` | One generic screen: text plus an optional join form or button. |
| `connection.ts` | `connect`: the PeerJS link to the shell. Sends `hello`, the first `state` means joined, any error or close (or 15 s of silence) means failed. No retry. |
| `sender.ts` | `startSender`: sends the layout's snapshot at `INPUT_HZ`. |
| `latch.ts` | Keeps a short tap until the next input message reads it. |
| `tilt.ts` | Gravity → roll angle → steer, with a dead zone and full lock. |
| `layouts/` | `WaitLayout.vue`, `DpadLayout.vue`, `TiltRacerLayout.vue` and `index.ts`, the layout registry. |

Every layout takes `{ color }` and exposes `read()`: the input to send, or nothing. The tilt layout also asks for
motion permission, keeps the screen awake and tries to lock landscape; without motion access it shows an error and steering is off (no fallback).

## Game contract

`games/<id>/index.ts` is tiny and is loaded eagerly by the library; the game code is a lazy chunk.

```ts
export default {
  title: 'Racing Carts',
  cover,                                  // imported image
  layout: 'tilt-racer',
  players: { min: 1, max: 6 },
  load: () => import('./src/game'),       // downloads only when opened
} satisfies Game<'tilt-racer'>;
```

`src/game.ts` exports `start(round)`, which returns `{ input(slot, input), destroy() }`:

- `round.el`: the element to draw into. `round.players`: `{ slot, name, color }` list.
- `round.finish(results)`: call once with `{ slot, place }` for each player when the round is over.
- `destroy()`: free WebGL, audio, timers and listeners.

Games may use any framework inside. **Assets are imported, never served from a `public/` folder** (a game is a
chunk of the shell build): `import cover from './cover.png'`, and sounds with `import.meta.glob`.

Racing Carts (`games/racing-carts/src`): `game.ts` builds the scene in `el`, gives each player a kart in their
colour, fills the other karts with bots (`drivers.ts`), runs countdown → race and calls `finish` with the
finishing order (`results.ts`). The simulation (`Game`, `race/`, `kart/`, `track/`, `powerups/`, `bots/`) is plain
TypeScript with no Babylon, DOM or network, driven at a fixed 60 Hz (`loop.ts`); `render/` and `audio/` read it each
frame and never change it. Items are a plugin system, see [docs/powerups.md](docs/powerups.md).

## Shared look (`packages/ui`)

Shell and controller use Tailwind CSS 4 and daisyUI 5. Layout is Tailwind utilities; components are daisyUI
(`btn`, `card`, `input`, `badge`…). The look lives in `packages/ui/theme.css`, the only Tailwind entry for both
apps: one custom theme, `couch`, plus the font and the six player colours (`--color-player-0` … `--color-player-5`).
Changing the look means editing that file. In-game rendering (canvas, HUD) stays the game's own.

Lint makes the theme the only place for look. `eslint.config.js` over `apps/**/*.{ts,vue}` blocks:

| Rule | Blocks |
| --- | --- |
| `vue/no-restricted-block` (`style`) | `<style>` blocks in components |
| `vue/no-static-inline-styles`, `vue/no-restricted-static-attribute` (`style`) | inline `style="…"` |
| `better-tailwindcss/no-restricted-classes` | arbitrary values, raw palette colours (`bg-pink-300`), `rounded-*` / `shadow-*` overrides, `border-<n>` |
| `better-tailwindcss/no-unknown-classes` | typos and classes that do not exist (reads `theme.css`) |
| `better-tailwindcss/no-conflicting-classes` | two classes fighting over one property |

Use theme colours (`bg-primary`, `text-base-content`, `bg-player-2`) and component defaults. Games and packages
only get the TypeScript rules.

## Builds, tests and deploy

| Command | What it does |
| --- | --- |
| `npm test` | Vitest in every workspace. |
| `npm run typecheck` | `tsc` or `vue-tsc` in every workspace. |
| `npm run lint` | ESLint over the whole repo. |
| `npm run build` (`scripts/build.sh`) | One GitHub Pages site in `output/`: shell at `/`, controller at `/controller/`. Games are code-split chunks of the shell. Fails if a root `.env` sets `VITE_E2E` or the fixture game leaks. |
| `npm run build:e2e` | The same build with a local PeerJS broker address and `VITE_E2E=1`, which makes the shell also glob `e2e/fixtures/*/index.ts`. |
| `npm run e2e` | Playwright (`playwright.config.ts`): builds the e2e site and runs `scripts/e2e-serve.mjs`, which serves `output/` on `:4173` and a PeerJS broker (`peer` package) on `:9000`. The host runs in one browser context and each phone in its own, with a mobile viewport and no motion sensors. |
| `.github/workflows/deploy-web.yml` | On every push to `main` and every pull request: lint, test, e2e, build. On `main` it then publishes `output/` to GitHub Pages. |

The broker address is read from `VITE_PEER_HOST`, `VITE_PEER_PORT` and `VITE_PEER_PATH` (`peerOptions`); unset, the
public PeerJS cloud is used. The e2e fixture game lives in `e2e/fixtures/e2e-test-game/` and finishes on the
lead player's input, so tests need no full race.

### TypeScript setup

Two TypeScript versions sit side by side. The root `typescript` is aliased to `@typescript/typescript6` because
typescript-eslint does not support TS 7 yet, while `@typescript/native` (TS 7) provides the `tsc` bin that
`typecheck` runs. Drop the alias once typescript-eslint supports TS 7.

## Adding a feature

Keep a feature in its own files and plug it in at one place.

- **A new game:** a new folder `games/<id>/` with `index.ts` (the contract above), `cover.*` and `src/game.ts`.
  The shell finds it by itself: no list, no registry, no change anywhere else.
- **A new layout:** a Vue file in `apps/controller/src/layouts/`, a line in its `index.ts`, and the layout id and
  input type (with a `NEUTRAL` value and a `decodeInput` case) in `packages/shared/src/layouts.ts`.
- **A new item in Racing Carts:** one file in `powerups/items/` and one registry line.
- **A new screen on the shell:** a component in `screens/`, a route in `router.ts` and its layout in `layoutFor.ts`.
