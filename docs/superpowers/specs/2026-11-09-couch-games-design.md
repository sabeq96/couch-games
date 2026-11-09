# Couch Games — design

Date: 2026-11-09. Status: approved in brainstorming, awaiting spec review.

## Goal

Turn the `racing-carts` repository into **couch-games**: a collection of local multiplayer games played on one
shared screen with phones as controllers.

- The main URL is a **library** of games.
- Choosing a game opens it. The game is the **host**: it opens a room and shows a QR code.
- Scanning the QR opens the **controller** on the phone with the layout the game asked for.
- Each game is its own module and may use its own framework. Racing Carts (Babylon.js) is the first game.
- The library and the controller are built with Vite + Vue.

**Guiding rule: simplest possible.** One generic mechanism instead of special cases, shared screens and styles
instead of per-game copies, a minimal protocol, no speculative features.

### Success criteria

1. `/` shows the library. Clicking Racing Carts opens `/games/racing-carts/` and the game plays as it does today
   (simulation, rendering, bots, items unchanged).
2. A phone scanning the game's QR gets the `tilt-racer` layout and can drive, start and play again.
3. Library, controller and the game's join card / banners share one look (`@couch/ui`).
4. Adding a game = a folder under `games/` + one entry in `games.json`. Adding a layout = one Vue file + one
   registry line in the controller + its input type in `@couch/protocol`.
5. `npm test`, `npm run typecheck` and `npm run e2e` (Playwright) pass; `npm run build` produces one GitHub Pages
   site.
6. The GitHub repository is renamed to `couch-games`.

## Terms

| Term | Meaning |
| --- | --- |
| **Host** | The screen running a game (laptop, desktop, TV browser…). Owns the room and the whole simulation. |
| **Controller** | A phone running `/controller/`. A static gamepad: it sends input and shows no game data. |
| **Library** | The page at `/` listing games. Static, no networking. |
| **Layout** | A fixed set of controls on the phone, e.g. `tilt-racer`. The game picks one per player at join. |
| **Lead player** | The player whose ☰ press starts a race or a rematch. Earliest-joined connected player (today's "host player", renamed to avoid clashing with *host*). |
| **Room** | A 4-letter code + PeerJS peer, opened by a game. |

## Decisions

| Question | Decision |
| --- | --- |
| Who owns the room? | **Each game.** Switching games means phones scan again. |
| How are games combined? | **Multi-page site.** Each game is its own Vite app at `/games/<id>/`; the library just links to it. No SPA mounting, no iframes. |
| Who picks the layout? | **The game**, once, in `joined`. The QR only carries the room code. |
| Does the phone show game data? | **No.** No position, lap, item icon, drift glow, vibration or host-only buttons. All of that lives on the host screen. |
| How do start / play again work? | Every layout has a **☰ button**. The game decides what it means; racing reads the lead player's ☰ in lobby (start) and results (rematch). The host screen shows "Alex, press ☰ to start". |
| Room full / bad code / host gone? | **One generic error.** The host just closes the connection; the phone shows "Unable to join". |
| Tizen TV build? | **Dropped.** Web only. |
| D-pad + A/B layout? | **Later**, with its first game. Only the registry slot exists. |
| Back to the library? | Host side only: a **Library** button on the game's lobby/results screens, and Escape. |

## Architecture

```
 phone                                       host screen
┌───────────────────────┐  WebRTC data      ┌──────────────────────────────────────┐
│ /controller/  (Vue)   │◀── channel ──────▶│ /games/<id>/   (any framework)       │
│ Message | Layout      │                   │ uses @couch/room: room, players,     │
│ uses @couch/link      │                   │ QR join card, banner, Library button │
└───────────────────────┘                   └──────────────────────────────────────┘
          └──── PeerJS broker (handshake only) ───┘           ▲  link
                                                    ┌─────────┴────────┐
                                                    │ /  library (Vue) │
                                                    └──────────────────┘
```

No server of our own, as today. The host is authoritative.

### Workspaces

```
couch-games/
├─ packages/
│  ├─ protocol/  @couch/protocol  messages, layout input types, room codes, peer prefix, decode. No DOM, no libs.
│  ├─ room/      @couch/room      host side: PeerJS host, PlayerRegistry, join card, banner, Library button/Escape.
│  ├─ link/      @couch/link      phone side: connect, reconnect with token, ping, status.
│  └─ ui/        @couch/ui        one CSS file: tokens + base components. No JS.
├─ apps/
│  ├─ library/     Vue, served at /
│  └─ controller/  Vue, served at /controller/
├─ games/
│  └─ racing-carts/  today's apps/game, served at /games/racing-carts/
├─ games.json      [{ id, title, cover, players: "1–6" }]
└─ scripts/build.sh
```

Dependency rules:

- Apps and games never import each other.
- `@couch/protocol` depends on nothing. `@couch/room` and `@couch/link` depend on `@couch/protocol` and `peerjs`.
- `@couch/room` is framework-free DOM + TS so a game in any framework can use it.
- Game rules (laps, kart colours, items…) live inside the game, not in shared packages.

### What moves where

| Today | New home |
| --- | --- |
| `packages/shared/protocol.ts` — codes, peer id, hello/decode | `@couch/protocol` |
| `packages/shared` — `TOTAL_LAPS`, `KART_COLORS`, `MAX_PLAYERS`, `Phase` | `games/racing-carts/src/rules.ts` |
| `apps/game/src/net/host.ts`, `net/players.ts` | `@couch/room` |
| join card / QR drawing in `apps/game/src/render/hud.ts` | `@couch/room` (`joinCard`) |
| `apps/controller/src/connection.ts` | `@couch/link` |
| `apps/controller/src/tilt.ts`, `latch.ts` | stay in the controller (latch made per-button) |
| `apps/controller/src/main.ts` (572 lines) | Vue: `App.vue`, `MessageScreen.vue`, `layouts/TiltRacer.vue` |
| `apps/controller/src/style.css` tokens | `@couch/ui` |
| `Session.syncPhones`, `state`/`event` messages | deleted |

## Protocol (`@couch/protocol`)

```ts
// phone → host
{ t: 'hello', token: string, name: string }
{ t: 'input', ...LayoutInput }          // 30 Hz (INPUT_HZ); also the host's keep-alive
{ t: 'ping' }                           // every 1 s

// host → phone
{ t: 'joined', slot: number, color: string, layout: LayoutId }   // once per connection
{ t: 'pong' }
```

- `LayoutId = 'tilt-racer'`. `TiltRacerInput = { steer: number; gas: boolean; brake: boolean; item: boolean; menu: boolean }`.
- `PEER_PREFIX = 'couchgames-'`, shared by all games, so a typed code works without knowing the game. Taken codes
  are already retried by `openPeer`.
- Decoding stays as today: anything unknown or malformed is dropped.
- **Input sending:** the phone tracks controls continuously and sends one snapshot every ~33 ms. A tap shorter than
  that is held by the per-button latch until the next send. The host keeps the latest snapshot per player and reads
  it on its own 60 Hz step.
- **Health:** host treats 6 s without any message as a dropped phone (as today). Phone treats a closed channel, or
  5 s without `pong`, as a drop.

## Controller (`apps/controller`, Vue)

Two screens, chosen from `@couch/link` status only:

1. **Message screen**, one generic component: a line of text, an optional input and an optional button.
   - Join: room code (prefilled from `?room=`), name, **Join**.
   - "Connecting…", "Reconnecting…".
   - "Unable to join" + **Try again**, "Room closed" + **Try again**.
2. **Layout screen**: renders `layouts[joined.layout]` with the player's colour. A layout receives `color` and emits
   input; nothing else.

`layouts/TiltRacer.vue`: tilt meter, GAS, BRAKE, ITEM, ☰, Center, and ◀ ▶ buttons when motion is denied.
Phone setup is kept: motion permission, wake lock, landscape lock, token in `localStorage`.
`?demo=<layout>` shows a layout with no host.

Error rule (the only one):

| When | Phone shows |
| --- | --- |
| No code typed | "Type the 4 letters from the screen" |
| Connection lost before `joined` (after up to 15 s of retries) | "Unable to join" |
| Connection lost after `joined` | "Reconnecting…", retrying every 2 s with the same token |
| Still lost after 30 s | "Room closed" |

## Library (`apps/library`, Vue)

One screen: a grid of cards from `games.json` (cover, title, players). A card is a plain link to `/games/<id>/`.

## Shared look (`@couch/ui`)

One CSS file imported by the library, the controller and `@couch/room`'s DOM pieces. It holds today's cozy look so
every screen matches:

- Tokens: `--cream`, `--ink`, `--ink-soft`, the six pastel player colours with their `-ink` pairs, `--font` (Nunito),
  one radius, one spacing scale.
- Base classes: `.cg-screen` (centred column), `.cg-card`, `.cg-button`, `.cg-input`, `.cg-banner`, `.cg-grid`.
- The library card, controller message screen, controller buttons, join card and host banner are all built from
  these classes. Games use them for their own menus too; in-game rendering (3D world, HUD) stays the game's own.

Shared host-side pieces in `@couch/room` (same look in every game):

- `joinCard(el, code)`: QR, room code, controller URL.
- `banner(el, text)`: the "Alex, press ☰ to start" line.
- `libraryButton(el)`: the **Library** button plus the Escape key, both go to `/`.

## Racing Carts changes

Only the edges change; simulation, rendering, audio, bots and items stay as they are.

- Uses `@couch/room` for the room, players, join card, banner and Library button.
- `Session` maps `TiltRacerInput` to its `InputSnapshot`; `menu` from the lead player starts the race in lobby and
  rematches in results.
- `Session.syncPhones` and the `state` / `event` messages are removed.
- HUD shows the banner naming the lead player in lobby and results.
- Tizen bits removed: `public/config.xml`, the chrome85/IIFE build target.

## Build and deploy

- `npm run build` (`scripts/build.sh`) builds every workspace into `output/`: library at `/`, controller at
  `/controller/`, each game at `/games/<id>/`.
- The site base (`/couch-games/`) is set once (an env value read by every Vite config); the controller URL is
  derived from it, nothing hardcoded.
- `.github/workflows/deploy-web.yml` runs `npm run build` on every push to `main`, as today.
- Removed: `build:tv`, `scripts/build-tv.sh`, `scripts/build-web.sh`, `docs/tizen-sideload.md`.
- New dependencies (`vue`, `@vitejs/plugin-vue`) are installed with npm CLI, following the official Vite/Vue setup.

## Testing

Rule: everything built is tested. Large flows are covered by **Playwright e2e**; pure logic by **Vitest** unit tests.

### Playwright e2e (`e2e/` at the root)

- Installed with `npm init playwright@latest`, following the official getting-started guide.
- `npm run e2e` serves the built `output/` site and a **local PeerJS server** (the `peer` package) through
  Playwright's `webServer`, so tests never touch the public broker. The broker address comes from one env value
  read by `@couch/room` and `@couch/link` (default: the public PeerJS cloud).
- A test opens the **host** in one browser context and each **phone** in its own context (mobile viewport, no motion
  sensors, so `tilt-racer` shows its ◀ ▶ buttons). Steering is driven through those buttons.
- Flows covered:
  1. Library lists the games from `games.json`; clicking Racing Carts opens it and the join card shows a code + QR.
  2. A phone opens `/controller/?room=<code>`, enters a name, joins, sees `tilt-racer` in its colour; the host lobby
     shows the name and the "press ☰ to start" banner.
  3. Two phones join; only the lead player's ☰ starts the countdown; the race HUD appears.
  4. Phone reload mid-race reconnects to the same slot (name stays in the race list).
  5. Wrong code → "Unable to join". Typing no code → "Type the 4 letters from the screen".
  6. Host clicks **Library** (and Escape) → back at `/`; the phone shows "Room closed".
  7. `?demo=tilt-racer` renders the layout with no host.
- Runs in CI before deploy (`deploy-web.yml`: build → e2e → publish).

### Vitest unit tests

- Existing tests move with their code (`protocol`, `host`, `players`, `connection`, `tilt`, `latch`, all game
  simulation tests) and keep passing.
- New: `joined` / `input` / `ping` decoding, per-button latch, `Session` mapping the lead player's `menu` to start in
  lobby and rematch in results (a full race is too long for e2e, so play again is covered here).

## Docs

`ARCHITECTURE.md`, `FEATURES.md`, `GLOSSARY.md` and `README.md` are rewritten for host / controller / library /
layout / lead player / ☰. Phone stories that no longer apply (F10, drift glow on the phone, vibration, TV-only
flags and builds) are removed; new stories are added for the library, opening a game, going back to the library and
the static controller.

## Order of work

Racing stays playable after each step, and each step lands with its tests. Playwright is set up in step 1 with
flows added as each piece arrives.

1. Playwright + local PeerJS server; shared packages (`protocol`, `room`, `link`, `ui`) and the new protocol; Racing Carts ported onto them and moved
   to `games/racing-carts`.
2. Controller rebuilt in Vue (message screen + `tilt-racer`).
3. Library in Vue, `games.json`, one build script, deploy workflow.
4. Tizen removal and docs.
5. Rename: `gh repo rename couch-games`, update the git remote and the site base. Done last and only after
   confirmation, because old `…/racing-carts/` Pages links and QR codes stop working.

## Out of scope

- Any new game, the d-pad + A/B layout, layout switching mid-game.
- Phones staying connected across games.
- Any server of our own, accounts, saved scores.
