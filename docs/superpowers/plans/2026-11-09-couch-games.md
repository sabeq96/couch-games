# Couch Games Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the racing-carts repo into couch-games: a Vue shell that owns one party room and runs folder-based games, a static Vue phone controller, and Racing Carts reduced to a `start`/`finish` game.

**Architecture:** npm-workspaces monorepo. `@couch/shared` holds the protocol and the game contract types; `@couch/ui` holds the single Tailwind + daisyUI theme. `apps/shell` (served at `/`) opens the PeerJS room, keeps the party, routes by hash and lazy-loads `games/*/index.ts`. `apps/controller` (served at `/controller/`) joins with `hello`, renders the layout from `state`, sends `input` at 30 Hz.

**Tech Stack:** TypeScript, Vite 8, Vue 3, Tailwind CSS 4, daisyUI 5, PeerJS, Vitest, Playwright, ESLint (eslint-plugin-vue, eslint-plugin-better-tailwindcss, typescript-eslint), Babylon.js (Racing Carts only).

**Spec:** `docs/superpowers/specs/2026-11-09-couch-games-design.md`

## Global Constraints

- Simplest possible: no reconnect, retry or rejoin handling anywhere; no feature beyond the spec.
- Every package added with the npm CLI (`npm i -w <ws> <pkg>`), following its official setup guide. Never hand-edit dependency lists.
- Everything built is tested: Playwright e2e for flows, Vitest for pure logic. `npm test`, `npm run typecheck`, `npm run lint`, `npm run e2e` must pass at the end of every task (for the parts that exist by then).
- `PEER_PREFIX = 'couchgames-'`; room codes: 4 letters from `ABCDEFGHJKMNPQRSTUVWXYZ`.
- `INPUT_HZ = 30`; `MAX_PARTY = 6`.
- `PLAYER_COLORS = ['#FF8A80', '#82B1FF', '#9BE7C4', '#FFE38A', '#C9B6F2', '#FFC09F']` (slot order).
- Layout ids: `'wait' | 'dpad' | 'tilt-racer'`.
- Site base `/couch-games/`, defined once in `site.config.ts`; controller at `<base>controller/`; QR target `<base>controller/?room=<CODE>`.
- Phone copy, verbatim: "Join", "Connecting…", "Unable to join", "Try again", "Type the 4 letters from the screen", "Look at the screen".
- Shell screens act on press edges (up → down), never held state.
- Styling only through `packages/ui/theme.css`; components use daisyUI classes + layout utilities; lint rules in Task 2 enforce it.
- Commit after each task with a conventional message ending in `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. Lead player leaves while on library/results → the next player becomes lead and immediately gets `dpad` (test in Task 4: `Party` + shell resends states on leave).
2. A phone joins during a round → gets `wait`, is not given to the running game, and is in the next round's roster (test in Task 5).
3. A still held from the press that opened results → must not trigger play again (test in Task 5: `Presses.reset` on route change).
4. Stale input of the previous layout arriving after a layout switch (dpad fields during `tilt-racer`) → ignored, never forwarded to the game (test in Task 1 `decodeInput` + Task 5 shell forwarding).
5. Opening a game, leaving with Escape and opening it again → second round works, no leaked canvas/render loop (e2e in Task 5 with the fixture, Task 6 with Racing Carts).

---

### Task 1: `@couch/shared` — protocol and game contract

**Files:**
- Move: `packages/shared` → `packages/rc-shared` (directory only; package name stays `@rc/shared` until Task 7 deletes it); update root `package.json` workspaces glob if needed, run `npm install`.
- Create: `packages/shared/package.json` (name `@couch/shared`, `exports: { ".": "./src/index.ts" }`, scripts `test`, `typecheck`), `packages/shared/tsconfig.json` (extends `../../tsconfig.base.json`)
- Create: `packages/shared/src/protocol.ts`, `layouts.ts`, `game.ts`, `peer.ts`, `index.ts` (re-exports)
- Test: `packages/shared/src/protocol.test.ts`, `layouts.test.ts`, `peer.test.ts`
- Create: `site.config.ts` at the root: `export const BASE = '/couch-games/';`

**Interfaces — Produces:**
```ts
// protocol.ts
export const PEER_PREFIX = 'couchgames-';
export const ROOM_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ';
export const INPUT_HZ = 30;
export const MAX_PARTY = 6;
export const PLAYER_COLORS: readonly string[];         // values in Global Constraints
export function makeRoomCode(rand?: () => number): string;
export function peerIdFor(code: string): string;        // PEER_PREFIX + code.toUpperCase()
export function controllerUrl(controllerBase: string, code: string): string; // `${base}?room=${code}`
export type ClientMsg = { t: 'hello'; name: string } | { t: 'input'; fields: Record<string, unknown> };
export type ServerMsg = { t: 'state'; layout: LayoutId; color: string };
export function decodeClient(raw: unknown): ClientMsg | null;  // JSON string or object; name trimmed to 12 chars, empty → 'Player'; input: every key except `t` goes into `fields`
export function decodeServer(raw: unknown): ServerMsg | null;  // null for unknown layout or non-string color
export function encodeInput(input: object): { t: 'input' } & object;

// layouts.ts
export type LayoutId = 'wait' | 'dpad' | 'tilt-racer';
export const LAYOUT_IDS: readonly LayoutId[];
export interface DpadInput { up: boolean; down: boolean; left: boolean; right: boolean; a: boolean; b: boolean }
export interface TiltRacerInput { steer: number; gas: boolean; brake: boolean; item: boolean }
export interface LayoutInputs { wait: Record<string, never>; dpad: DpadInput; 'tilt-racer': TiltRacerInput }
export const NEUTRAL: { [L in LayoutId]: LayoutInputs[L] };
export function decodeInput<L extends LayoutId>(layout: L, fields: Record<string, unknown>): LayoutInputs[L] | null;
//  dpad: all six keys must be booleans, else null. tilt-racer: steer finite number (clamped -1..1) + three booleans, else null. wait: always null.

// game.ts
export interface Player { slot: number; name: string; color: string }
export interface Result { slot: number; place: number }
export interface Round { el: HTMLElement; players: readonly Player[]; finish(results: Result[]): void }
export interface RoundHandle<L extends LayoutId = LayoutId> { input(slot: number, input: LayoutInputs[L]): void; destroy(): void }
export interface GameModule<L extends LayoutId = LayoutId> { start(round: Round): RoundHandle<L> }
export interface Game<L extends LayoutId = LayoutId> {
  title: string; cover: string; layout: L; players: { min: number; max: number };
  load(): Promise<GameModule<L>>;
}

// peer.ts
export interface PeerEnv { VITE_PEER_HOST?: string; VITE_PEER_PORT?: string; VITE_PEER_PATH?: string }
export function peerOptions(env: PeerEnv): { host?: string; port?: number; path?: string; secure?: boolean };
//  {} when VITE_PEER_HOST unset; otherwise host, Number(port), path ?? '/', secure: false
```

- [ ] **Step 1: Move the old package** (`git mv packages/shared packages/rc-shared`, `npm install`), run `npm test` → all existing tests still PASS.
- [ ] **Step 2: Write failing tests**
  - `protocol.test.ts`: `makeRoomCode(() => 0) === 'AAAA'`; `peerIdFor('abcd') === 'couchgames-ABCD'`; `controllerUrl('/couch-games/controller/', 'ABCD') === '/couch-games/controller/?room=ABCD'`; `decodeClient('{"t":"hello","name":"  Alexandra the Great "}')` → `{ t: 'hello', name: 'Alexandra th' }`; `decodeClient({t:'hello',name:''})` → name `'Player'`; `decodeClient({t:'input',gas:true})` → `{ t:'input', fields:{ gas:true } }`; `decodeClient('nope')`, `decodeClient({t:'x'})` → `null`; `decodeServer({t:'state',layout:'dpad',color:'#FF8A80'})` round-trips; `decodeServer({t:'state',layout:'piano',color:'#fff'})` → `null`.
  - `layouts.test.ts`: `decodeInput('dpad', {up:true,down:false,left:false,right:false,a:false,b:false})` returns it; missing `b` → `null`; `decodeInput('tilt-racer', {steer:3,gas:true,brake:false,item:false}).steer === 1`; `decodeInput('tilt-racer', <dpad fields>)` → `null` (Review Focus 4); `decodeInput('wait', {})` → `null`.
  - `peer.test.ts`: `peerOptions({})` → `{}`; `peerOptions({VITE_PEER_HOST:'localhost',VITE_PEER_PORT:'9000'})` → `{ host:'localhost', port:9000, path:'/', secure:false }`.
- [ ] **Step 3: Run** `npm test -w @couch/shared` → FAIL (modules missing).
- [ ] **Step 4: Implement** the files above. `decodeClient` reuses the `toRecord` approach from `packages/rc-shared/src/protocol.ts`.
- [ ] **Step 5: Run** `npm test -w @couch/shared && npm run typecheck` → PASS.
- [ ] **Step 6: Commit** `feat(shared): couch protocol, layouts and game contract`.

---

### Task 2: `@couch/ui` theme and the lint rules

**Files:**
- Create: `packages/ui/package.json` (name `@couch/ui`, `exports: { "./theme.css": "./theme.css" }`, script `"test": "vitest run"`), `packages/ui/theme.css`
- Create: `eslint.config.js` (root, flat config), root script `"lint": "eslint ."`
- Test: `packages/ui/lint.test.ts` (Vitest, uses the `ESLint` class with the root config)

**Interfaces — Produces:** `@couch/ui/theme.css` (the only Tailwind entry for shell and controller); theme name `couch`; utilities `bg-player-0` … `bg-player-5` / `text-player-N`; `font-sans` = Nunito.

- [ ] **Step 1: Install** with the CLI per the official guides: `npm i -w @couch/ui tailwindcss daisyui`; root dev deps `npm i -D eslint eslint-plugin-vue typescript-eslint eslint-plugin-better-tailwindcss`.
- [ ] **Step 2: Write `theme.css`:** `@import "tailwindcss"; @plugin "daisyui" { themes: couch --default; }` (if daisyUI rejects a custom name there, use `themes: false;` and verify the custom theme still applies — check by building in Task 3 and record which form works in a comment), then `@plugin "daisyui/theme" { name: "couch"; default: true; color-scheme: light; … }` with:
  - `--color-base-100: #fff3e4; --color-base-200: #f7e6d2; --color-base-300: #efd7bd; --color-base-content: #5b4638;`
  - `--color-primary: #7fddb0; --color-primary-content: #1f5a41; --color-secondary: #ffd966; --color-secondary-content: #6b4e00; --color-accent: #82b1ff; --color-accent-content: #16315e; --color-neutral: #5b4638; --color-neutral-content: #fff3e4; --color-error: #ff8a80; --color-error-content: #6b1f1a;` (info/success/warning reuse accent/primary/secondary).
  - `--radius-box: 1.5rem; --radius-field: 1rem; --radius-selector: 1rem; --border: 2px; --depth: 1; --noise: 0;`
  - `@theme { --font-sans: "Nunito", ui-rounded, system-ui, sans-serif; --color-player-0 … --color-player-5: PLAYER_COLORS; }`
- [ ] **Step 3: Write `eslint.config.js`** covering `apps/**/*.{ts,vue}`: `pluginVue.configs['flat/recommended']`, typescript-eslint parser for `<script lang="ts">`, and rules:
  - `vue/no-restricted-block: ['error', 'style']`
  - `vue/no-static-inline-styles: 'error'`, `vue/no-restricted-static-attribute: ['error', 'style']`
  - `better-tailwindcss/no-unknown-classes: 'error'`, `better-tailwindcss/no-conflicting-classes: 'error'`
  - `better-tailwindcss/no-restricted-classes: ['error', { restrict: [arbitrary values '\\[([^\\[\\]]*?)\\](?!:)', raw palette '^(.*:)?(bg|text|border|ring|outline|fill|stroke|from|to|via)-(slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose|black|white)(-\\d+)?(/\\d+)?$', overrides '^(.*:)?(rounded|shadow)(-.*)?$', '^(.*:)?border-\\d+$'] }]` (copy the arbitrary-value pattern from the plugin's raw `docs/rules/no-restricted-classes.md`)
  - settings `'better-tailwindcss': { entryPoint: 'packages/ui/theme.css', detectComponentClasses: true }`
  - ignore `games/**`, `**/dist/**`, `output/**`, `packages/rc-shared/**`.
- [ ] **Step 4: Write failing test `lint.test.ts`** — lints virtual `.vue` files via `eslint.lintText(code, { filePath: 'apps/shell/src/X.vue' })` and asserts rule ids:
  - `<template><div class="btn bg-pink-300"/></template>` → contains `better-tailwindcss/no-restricted-classes`
  - `class="text-[#fff]"`, `class="btn rounded-none"`, `class="card shadow-xl"` → same rule
  - `<style>.a{}</style>` → `vue/no-restricted-block`; `<div style="color:red">` → `vue/no-static-inline-styles`
  - `class="btn btn-primary flex gap-2 bg-player-2 text-base-content"` → zero messages
  - `class="btnn"` → `better-tailwindcss/no-unknown-classes`
- [ ] **Step 5: Run** `npx vitest run packages/ui` → FAIL until config is right; fix until PASS. `npm run lint` → PASS (nothing to lint yet besides fixtures, which are virtual).
- [ ] **Step 6: Commit** `feat(ui): couch daisyUI theme, lint keeps look in the theme`.

---

### Task 3: Shell and controller scaffolds, Playwright harness, WebRTC smoke test

**Files:**
- Create: `apps/shell/` via `npm create vite@latest apps/shell -- --template vue-ts`; remove template sample components; scripts `test: vitest run`, `typecheck: vue-tsc --noEmit` (from the template); `vite.config.ts` (`base: BASE` from `../../site.config`, plugins `vue()`, `tailwindcss()`, `envDir: '../..'`, `server.fs.allow: ['../..']`); `src/style.css` = `@import "@couch/ui/theme.css";` plus `@source "../../../games";` and `@source "../../../e2e/fixtures";`; `index.html` with the Nunito Google Fonts link and `data-theme="couch"` on `<html>`.
- Replace: `apps/controller/` with a fresh `vue-ts` scaffold the same way (`base: BASE + 'controller/'`). Keep `src/tilt.ts`, `src/tilt.test.ts`, `src/latch.ts`, `src/latch.test.ts` from the old controller; delete the rest of the old controller (`main.ts`, `connection.ts` and their tests move/rewrite in Task 4).
- Create: `playwright.config.ts` (root, via `npm init playwright@latest`, tests in `e2e/`), `scripts/e2e-serve.mjs`, root scripts `build`, `build:e2e`, `e2e`.
- Create: `scripts/build.sh`: builds shell and controller, assembles `output/` (shell dist at root, controller dist at `controller/`), `touch output/.nojekyll`.
- Test: `e2e/smoke.spec.ts`

**Interfaces — Produces:**
- `npm run build` → `output/`; `npm run build:e2e` = same with `VITE_PEER_HOST=localhost VITE_PEER_PORT=9000 VITE_PEER_PATH=/ VITE_E2E=1`.
- `scripts/e2e-serve.mjs`: one Node process serving `output/` at `http://localhost:4173/couch-games/` (node:http + fs, correct MIME types for html/js/css/png/mp3/svg) and `PeerServer({ port: 9000, path: '/' })` from `peer`.
- `playwright.config.ts`: `webServer: { command: 'npm run build:e2e && node scripts/e2e-serve.mjs', url: 'http://localhost:4173/couch-games/', reuseExistingServer: !process.env.CI }`, `use.baseURL: 'http://localhost:4173/couch-games/'`, projects: `chromium` with `launchOptions.args: ['--disable-features=WebRtcHideLocalIpsWithMdns']`.
- e2e helper `e2e/helpers.ts`: `openHost(browser): Promise<Page>`, `openPhone(browser, code?): Promise<Page>` (new context, `devices['Pixel 7']` viewport, no permissions).

- [ ] **Step 1: Scaffold** both apps with the CLI, install `npm i -w apps/shell vue peerjs qrcode @couch/shared @couch/ui` and `npm i -w apps/shell -D @tailwindcss/vite @types/qrcode` (same for controller without qrcode), `npm i -D @playwright/test peer`, `npx playwright install chromium`.
- [ ] **Step 2: Write the WebRTC smoke test** `e2e/smoke.spec.ts` → test `two contexts talk through the local broker`: page A (shell origin) runs `new Peer('couchgames-TEST', {host:'localhost',port:9000,path:'/'})` via `page.evaluate` using the bundled `peerjs` exposed as `window.__Peer` **only when `import.meta.env.VITE_E2E`**; page B connects and sends `'ping'`; assert A receives `'ping'` within 10 s.
- [ ] **Step 3: Run** `npm run e2e -- smoke` → must PASS locally. If ICE fails, check the mDNS flag first; record the working launch args in `playwright.config.ts`.
- [ ] **Step 4: Add CI job** in `.github/workflows/deploy-web.yml`: after `npm ci`, run `npx playwright install --with-deps chromium`, `npm run lint`, `npm test`, `npm run e2e`, then `npm run build` and upload `output`. Push the branch and confirm the smoke test passes in GitHub Actions before Task 4 (Actions run on push to the branch: add `pull_request` and `push: branches: [main, couch-games]` triggers, keep deploy steps `if: github.ref == 'refs/heads/main'`).
- [ ] **Step 5: Commit** `build: Vue shell and controller scaffolds, Playwright with local PeerJS broker`.

---

### Task 4: Party room, join flow, `wait` and `dpad` layouts

**Files:**
- Create: `apps/shell/src/room/host.ts` (+ `host.test.ts`, port the FakePeer harness from the deleted `apps/game/src/net/host.test.ts` — copy it before Task 7 deletes the old game), `apps/shell/src/party.ts` (+ test), `apps/shell/src/layoutFor.ts` (+ test), `apps/shell/src/components/PartyBar.vue`, `apps/shell/src/App.vue`
- Create: `apps/controller/src/connection.ts` (+ `connection.test.ts`, port the FakePeer harness from git history `apps/controller/src/connection.test.ts`), `src/sender.ts` (+ test), `src/App.vue`, `src/MessageScreen.vue`, `src/layouts/index.ts`, `src/layouts/Wait.vue`, `src/layouts/Dpad.vue`
- Modify: `apps/controller/src/latch.ts` → per-button latch
- Test: `e2e/join.spec.ts`

**Interfaces:**
- Consumes: Task 1 protocol/layouts/peer.
- Produces:
```ts
// shell/room/host.ts — based on apps/game/src/net/host.ts (openPeer retry on 'unavailable-id', broker errors), keyed by DataConnection.connectionId, no tokens, no hello timeout/silence logic
export interface RoomHandlers { onHello(id: string, name: string): boolean; onInput(id: string, fields: Record<string, unknown>): void; onLeave(id: string): void }
export interface Room { code: string; send(id: string, msg: ServerMsg): void; close(): void }
export function openRoom(handlers: RoomHandlers, peerOpts?: object, rand?: () => number): Promise<Room>; // onHello false → send nothing, close conn after 200 ms

// shell/party.ts
export class Party {
  join(id: string, name: string): Player | null;  // lowest free slot, color PLAYER_COLORS[slot]; null when MAX_PARTY members
  leave(id: string): void;
  byId(id: string): Player | undefined;
  idOf(slot: number): string | undefined;
  members(): readonly Player[];                    // join order
  lead(): Player | null;                           // members()[0] ?? null
  roster(max: number): Player[];                   // first `max` of members()
}

// shell/layoutFor.ts
export type Route = { name: 'library' } | { name: 'play'; id: string } | { name: 'results'; id: string };
export function layoutFor(route: Route, player: Player, lead: Player | null, round: { layout: LayoutId; slots: readonly number[] } | null): LayoutId;
//  library/results: lead → 'dpad', others → 'wait'. play: slot in round.slots → round.layout, else 'wait'.

// controller/connection.ts
export type LinkStatus = 'connecting' | 'joined' | 'failed';
export interface Link { send(msg: object): void; close(): void }
export function connect(code: string, name: string, onState: (s: ServerMsg) => void, onStatus: (s: LinkStatus) => void, peerOpts?: object): Link;
//  sends hello on open; first state → 'joined'; error/close at any time or no state within 15 s → 'failed' (no retry)

// controller/sender.ts
export function startSender(read: () => object | null, send: (msg: object) => void, hz?: number): () => void; // setInterval 1000/hz; skips when read() is null

// controller/latch.ts
export function createLatches<K extends string>(): { press(k: K): void; read(k: K, level: boolean): boolean };

// controller/layouts/index.ts
export const layouts: Record<LayoutId, Component>; // each layout: props { color: string }, emits nothing; exposes `read(): object | null` via defineExpose
```

- [ ] **Step 1: Failing unit tests**
  - `party.test.ts`: three joins get slots 0,1,2 with `PLAYER_COLORS[0..2]`; leave slot 1 then join → slot 1 reused; 7th join → `null`; `lead()` is the first joiner and after `leave` of the lead it is the second joiner (Review Focus 1); `roster(2)` returns the first two by join order.
  - `layoutFor.test.ts`: library lead → `'dpad'`, other → `'wait'`; results same; play with `{layout:'tilt-racer', slots:[0,1]}` → slot 1 `'tilt-racer'`, slot 2 `'wait'` (Review Focus 2).
  - `host.test.ts`: hello accepted → `onHello` called with conn id and name; `onHello` returning false → conn closed; input after hello → `onInput(fields)`; close → `onLeave`; taken code → new code.
  - `connection.test.ts`: open → hello sent; state → `onState` + status `'joined'`; close before state → `'failed'`; 15 s fake timers with no state → `'failed'`.
  - `sender.test.ts` (fake timers): sends `{t:'input',...read()}` every 33 ms; `read()` null → nothing sent; stop function clears it.
  - `latch.test.ts`: `press('a')` then `read('a', false)` → true once, then false.
- [ ] **Step 2: Run** `npm test -w apps/shell -w apps/controller` → FAIL.
- [ ] **Step 3: Implement** the modules above.
- [ ] **Step 4: Implement shell `App.vue` + `PartyBar.vue`:** on mount `openRoom` with `peerOptions(import.meta.env)`; `onHello` → `party.join`, false when null; after every join/leave/route change send `state { layout: layoutFor(...), color }` to every member; `PartyBar` shows QR (`qrcode` → data URL of `controllerUrl(location.origin + BASE + 'controller/', code)`), the code, and each member as a daisyUI `badge` with `bg-player-N`, lead marked "★". Room failure shows a daisyUI `alert`: "Can't create room — retrying" and retries every 5 s.
- [ ] **Step 5: Implement controller:** `App.vue` state machine `join → connecting → layout | failed`; `MessageScreen.vue` props `{ text: string; input?: 'join'; button?: string }` emits `submit(code, name)` / `button`; join form prefilled from `?room=`, empty code shows "Type the 4 letters from the screen"; `connecting` text "Connecting…"; `failed` text "Unable to join" + button "Try again" (back to join). `Wait.vue` = `MessageScreen` with "Look at the screen" on `bg-player-N`. `Dpad.vue` = four arrow `btn`s + A + B, `read()` returns `DpadInput` with latched presses. `startSender(() => layoutRef.value?.read() ?? null, link.send)`. `?demo=<layout>` renders that layout with color `PLAYER_COLORS[0]` and no link.
- [ ] **Step 6: Write e2e `join.spec.ts`:**
  - `host shows code and QR`: host page has a 4-letter code and an `img[alt="QR code"]`.
  - `first phone is lead with dpad, second waits`: phone 1 joins with `?room=<code>` + name "Alex" → `getByRole('button', { name: 'A' })` visible; phone 2 "Sam" → "Look at the screen"; host party bar shows "Alex" and "Sam".
  - `lead leaves, next one gets dpad`: close phone 1's context → phone 2 shows the A button within 5 s; host bar no longer shows "Alex".
  - `wrong code`: phone with `?room=ZZZZ` → "Unable to join" then "Try again" returns to the join form.
  - `empty code`: submit without code → "Type the 4 letters from the screen".
  - `seventh phone`: six phones join, a seventh → "Unable to join".
  - `demo`: `/controller/?demo=dpad` shows the A button with no host.
- [ ] **Step 7: Run** `npm test && npm run lint && npm run e2e` → PASS.
- [ ] **Step 8: Commit** `feat: party room, phone join, wait and dpad layouts`.

---

### Task 5: Library, rounds, results and the e2e fixture game

**Files:**
- Create: `apps/shell/src/games.ts` (+ test), `src/router.ts` (+ test), `src/presses.ts` (+ test), `src/grid.ts` (+ test), `src/screens/Library.vue`, `src/screens/Play.vue`, `src/screens/Results.vue`
- Modify: `apps/shell/src/App.vue` (route switching, input routing, state resend)
- Create: `e2e/fixtures/e2e-test-game/index.ts`, `e2e/fixtures/e2e-test-game/game.ts`, `e2e/fixtures/e2e-test-game/cover.svg`
- Test: `e2e/rounds.spec.ts`

**Interfaces:**
- Consumes: Task 1 `Game`, `GameModule`, `Result`; Task 4 `Party`, `layoutFor`, `Route`, `Room`.
- Produces:
```ts
// games.ts
export interface GameEntry { id: string; game: Game }
export function gamesFrom(modules: Record<string, { default: Game }>): GameEntry[]; // id = folder name from the glob key, sorted by title
export const games: GameEntry[]; // gamesFrom({ ...import.meta.glob('../../../games/*/index.ts', { eager: true }), ...(import.meta.env.VITE_E2E ? import.meta.glob('../../../e2e/fixtures/*/index.ts', { eager: true }) : {}) })

// router.ts
export function parseHash(hash: string): Route;  // '' | '#/' → library; '#/play/x' → play; '#/results/x' → results; anything else → library
export function hashFor(route: Route): string;

// presses.ts
export type Key = keyof DpadInput;
export class Presses { next(input: DpadInput): Key[]; reset(): void } // keys that went false→true since the previous snapshot; reset() treats the next snapshot as the baseline (no presses)

// grid.ts
export function move(index: number, key: 'up' | 'down' | 'left' | 'right', count: number, cols: number): number; // clamped, no wrap
```
- Shell round lifecycle (in `Play.vue`): `const mod = await entry.game.load(); handle = mod.start({ el, players: party.roster(max) snapshot, finish })`; `finish(results)` → store `{ results, players snapshot }`, `handle.destroy()`, go `#/results/<id>`. Leaving the route (Escape, back, hash change) → `handle.destroy()` once.
- Input routing in `App.vue`: each member's input is decoded with `decodeInput(currentLayoutOf(member), fields)`; null → dropped (Review Focus 4). On library/results only the lead's `DpadInput` goes through `Presses`; during a round inputs go to `handle.input(slot, input)` for roster slots only; a member who left is never forwarded again.
- Library: daisyUI `card`s in a `grid grid-cols-3`; selected card has `ring` via daisyUI `card-border` + `bg-base-200` (theme-only classes); game disabled (`opacity-50`, not selectable) when `party.members().length < players.min`. Lead A / mouse click opens it.
- Results: ordered list "1st Sam" (ordinal + name on `bg-player-N` badge); A → play again (same id, new roster), B → library. Mouse buttons do the same.
- Fixture game (`e2e-test-game`, title "Test Game", layout `'dpad'`, players `{ min: 1, max: 2 }`): `start` renders `<p data-testid="round">Round with Alex, Sam</p>`, on any `a` press from slot X calls `finish` with X first; `destroy` empties `el` and increments `window.__destroyed`.

- [ ] **Step 1: Failing unit tests**
  - `games.test.ts`: keys `'../../../games/racing-carts/index.ts'` → id `'racing-carts'`; sorted by title.
  - `router.test.ts`: the parse cases above and `hashFor(parseHash(h)) === h` for the three routes.
  - `presses.test.ts`: `{a:true}` after `{a:false}` → `['a']`; held `a` on the next snapshot → `[]`; after `reset()`, a snapshot with `a:true` → `[]` (Review Focus 3).
  - `grid.test.ts`: `move(0,'right',5,3) === 1`; `move(2,'right',5,3) === 2`; `move(1,'down',5,3) === 4`; `move(4,'up',5,3) === 1`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** modules and screens. Call `presses.reset()` on every route change.
- [ ] **Step 4: Write e2e `rounds.spec.ts`** (build has `VITE_E2E=1`):
  - `lead opens a game, everyone gets its layout`: two phones; lead presses right/left until "Test Game" is selected, presses A → host URL hash `#/play/e2e-test-game`, `getByTestId('round')` shows both names; both phones show the A button (fixture layout is dpad, so non-leads now also see it).
  - `late joiner waits`: a third phone joining during the round sees "Look at the screen" and is not in the round text (Review Focus 2); after results → play again, round text includes the first two only (max 2).
  - `finish shows results, A plays again, B goes back`: phone 2 presses A → results list "1st Sam", "2nd Alex"; lead A → `#/play/...` again; finish again; lead B → `#/` library.
  - `held A does not skip results`: lead holds A (mouse down without release on the A button) while the round finishes → still on results after 1 s (Review Focus 3).
  - `Escape leaves and the game reopens`: in a round press Escape on the host → `#/`, `window.__destroyed === 1`, phones show dpad/wait; open the game again → round text visible (Review Focus 5).
  - `not enough players`: with zero phones the host's Test Game card is disabled (min 1).
- [ ] **Step 5: Run** `npm test && npm run lint && npm run e2e` → PASS.
- [ ] **Step 6: Commit** `feat(shell): library, rounds, results and play again`.

---

### Task 6: Racing Carts as a game folder, `tilt-racer` layout

**Files:**
- Move: `apps/game/src/**` → `games/racing-carts/src/**` (`git mv`), `apps/game/public/audio/*.mp3` → `games/racing-carts/src/audio/files/`, `apps/game/public/icon.png` → `games/racing-carts/cover.png`
- Create: `games/racing-carts/package.json` (name `racing-carts`, deps via CLI: `@babylonjs/core`, `@couch/shared`; scripts `test`, `typecheck`), `tsconfig.json`, `index.ts`, `src/game.ts` (+ `game.test.ts`), `src/drivers.ts` (+ `drivers.test.ts`), `src/results.ts` (+ `results.test.ts`), `src/rules.ts`
- Delete: `src/main.ts`, `src/probe.ts`, `src/session.ts` (+ test), `src/net/` (after Task 4 copied its test harness), `src/input/keyboard.ts` (+ test)
- Modify: `src/render/hud.ts` (+ test) — remove `lobby`, `join`, `results`, `LobbySlot`, `JoinMode`; keep `countdown`, `race`, `message`
- Modify: `src/audio/audio.ts` (+ test) — `createAudio(urlFor: (name: SoundName) => string, deps?)` instead of a base URL; add `dispose(): void` to `Audio` (stops sources, closes the context, removes gesture listeners)
- Modify: `src/audio/manifest.ts` — `export const SOUND_URLS: Record<string, string>` from `import.meta.glob('./files/*.mp3', { query: '?url', import: 'default', eager: true })`, `soundUrl(name)`
- Modify: every `@rc/shared` import → `./rules` (`TOTAL_LAPS`, `Phase`, `InputSnapshot`, `NEUTRAL_INPUT`) or `@couch/shared` (`PLAYER_COLORS` replaces `KART_COLORS`)
- Create: `apps/controller/src/layouts/TiltRacer.vue`, register `'tilt-racer'` in `layouts/index.ts`
- Test: `e2e/racing.spec.ts`

**Interfaces:**
- Consumes: Task 1 `Round`, `RoundHandle<'tilt-racer'>`, `TiltRacerInput`, `PLAYER_COLORS`; Task 4 `createLatches`, `startSender`; `tilt.ts` (`gravityToRollDeg`, `rollToSteer`).
- Produces:
```ts
// index.ts
export default { title: 'Racing Carts', cover, layout: 'tilt-racer', players: { min: 1, max: 6 }, load: () => import('./src/game') } satisfies Game<'tilt-racer'>;
// src/drivers.ts — replaces Session: humans by slot, bots for every other kart (6 karts total, as today's default)
export class Drivers {
  constructor(game: Game, players: readonly Player[], rand?: () => number);
  setInput(slot: number, input: TiltRacerInput): void; // latches item like today's phoneInput
  driverFor(kartId: number): Driver;                    // human for player slots (name = player name), bot otherwise (BOT_NAMES)
}
// src/results.ts
export function resultsFor(karts: readonly Kart[], players: readonly Player[]): Result[]; // players only, place = rank among all karts by compareRank (1-based)
// src/game.ts
export function start(round: Round): RoundHandle<'tilt-racer'>;
```
- `start`: creates a `<canvas>` and a HUD `<div>` inside `el` (absolute, full size), builds Engine (antialias on), track, `Game`, `Drivers`, scene, views, camera, sparks, audio (`createAudio(soundUrl)`), `game.setupKarts(6)`, `game.race.start()`; render loop as in today's `main.ts` without the room/lobby/results code; on the `results` race event → `round.finish(resultsFor(game.karts, round.players))`. `destroy`: `engine.stopRenderLoop()`, `engine.dispose()`, `audio.dispose()`, remove the resize listener, `el.replaceChildren()`. Safe to call twice.
- `TiltRacer.vue`: today's driving screen minus every game-data display — tilt meter, GAS, BRAKE, ITEM, Center, ◀ ▶ when `DeviceOrientationEvent` is unavailable or permission denied; motion permission on first touch, wake lock, `screen.orientation.lock('landscape')` best-effort. `read()` → `TiltRacerInput` with latched ITEM.

- [ ] **Step 1: Move files** (`git mv`), create the package, fix imports; run `npm test -w racing-carts` → existing simulation tests PASS (kart, race, powerups, bots, track, render, audio after the `createAudio` signature change).
- [ ] **Step 2: Failing tests**
  - `drivers.test.ts`: players at slots 0 and 3 → `driverFor(0).kind === 'human'`, name the player's; `driverFor(1).kind === 'bot'`; `setInput(0, {steer:0.5,gas:true,brake:false,item:true})` then two reads of `driverFor(0).input()` → `item` true then false (latch); unknown slot `setInput(4, …)` ignored.
  - `results.test.ts`: three karts ranked [slot 2, slot 0, slot 1], players at slots 0 and 1 → `[{slot:0,place:2},{slot:1,place:3}]`.
  - `game.test.ts` (Vitest with Babylon's `NullEngine` injected via an optional second parameter `start(round, { engine?: (canvas) => AbstractEngine })`): `start` then `destroy` twice does not throw and leaves `el` empty; `input(0, …)` before `destroy` does not throw.
  - `audio.test.ts`: update to `createAudio((n) => `/a/${n}.mp3`, deps)`; new test `dispose closes the context`.
- [ ] **Step 3: Run** → FAIL. **Step 4: Implement**. **Step 5: Run** `npm test` → PASS.
- [ ] **Step 6: e2e `racing.spec.ts`:** one phone joins; lead selects "Racing Carts" and presses A → host `#/play/racing-carts` with a `canvas` visible; phone shows GAS, BRAKE, ITEM and ◀ ▶; pressing GAS for 2 s does not error (no page errors captured with `page.on('pageerror')`); Escape → `#/`; open Racing Carts again → canvas visible, still no page errors (Review Focus 5). `demo`: `/controller/?demo=tilt-racer` shows GAS.
- [ ] **Step 7: Run** `npm test && npm run typecheck && npm run lint && npm run e2e` → PASS. Manually: `npm run build:e2e && node scripts/e2e-serve.mjs`, open the host and a phone tab, drive a full race to results.
- [ ] **Step 8: Commit** `feat(racing-carts): game folder with start/finish, tilt-racer layout`.

---

### Task 7: Remove the old app and Tizen, production build check

**Files:**
- Delete: `apps/game/` (anything left), `packages/rc-shared/`, `scripts/build-tv.sh`, `scripts/build-web.sh`, `apps/game/scripts/make-silent-audio.sh` (move to `games/racing-carts/scripts/` if `docs/audio-assets.md` refers to it), `docs/tizen-sideload.md`
- Modify: root `package.json` scripts: `build`, `build:e2e`, `e2e`, `lint`, `test`, `typecheck` only (remove `build:tv`, `build:web`); workspaces `["packages/*", "apps/*", "games/*"]`
- Modify: `scripts/build.sh` — after assembling, fail if `grep -rq "e2e-test-game" output/` (fixture must not ship) when `VITE_E2E` is unset
- Modify: `.github/workflows/deploy-web.yml` triggers back to `push: branches: [main]` + `workflow_dispatch` (keep lint/test/e2e before build)

- [ ] **Step 1: Delete and edit** as listed; `npm install`.
- [ ] **Step 2: Run** `npm run build` → PASS and `output/index.html`, `output/controller/index.html` exist, no `e2e-test-game` in `output/`; `npm test && npm run typecheck && npm run lint && npm run e2e` → PASS.
- [ ] **Step 3: Commit** `build: one site build, drop the Tizen build and the old apps`.

---

### Task 8: Docs

**Files:** Modify `ARCHITECTURE.md`, `FEATURES.md`, `GLOSSARY.md`, `README.md`; delete `docs/superpowers/plans/2026-10-29-racing-carts.md` only if the user agrees (ask; default keep). Commit `CLAUDE.md` with them.

- [ ] **Step 1:** `GLOSSARY.md`: host/shell, controller, party, lead player, layout, game, round, `state`; remove TV, host player, keyboard player, token, lobby grace.
- [ ] **Step 2:** `ARCHITECTURE.md`: the workspace table and diagram from the spec, game contract, protocol, layout registry, theme + lint rules, build/e2e commands; "Adding a game" = new folder; "Adding a layout" = Vue file + registry line + input type.
- [ ] **Step 3:** `FEATURES.md`: remove F1–F7, F9, F10, F15's phone glow, F26–F28, F30's TV part, reconnect (F3, F5 parts); add stories (each with requirements + "Lives in"): join the party, see the party, pick a game with the d-pad, play a round, results and play again, back to the library, add a game by folder, consistent look via one theme. Keep F8, F11–F25 racing stories with updated "Lives in" paths under `games/racing-carts/src/`.
- [ ] **Step 4:** `README.md`: what it is, `npm install`, dev commands, `npm run e2e`, how to add a game.
- [ ] **Step 5: Run** `npm run lint` (markdown untouched by lint) and check every path mentioned in the docs exists (`grep -o 'games/[^ )`]*\|apps/[^ )`]*\|packages/[^ )`]*' *.md | sort -u` then `ls` each). **Step 6: Commit** `docs: couch games architecture, features and glossary`.

---

### Task 9: Rename to couch-games

Outward-facing: ask the user for an explicit go-ahead before Step 1.

- [ ] **Step 1:** `gh repo rename couch-games` (from the repo directory).
- [ ] **Step 2:** `git remote set-url origin git@github.com:sabeq96/couch-games.git`; `git remote -v` shows the new URL.
- [ ] **Step 3:** Confirm `site.config.ts` `BASE` is `'/couch-games/'`; `package.json` root `name` → `couch-games`; commit `chore: rename to couch-games`.
- [ ] **Step 4:** After merge to `main`, check the Pages deploy run passes and `https://sabeq96.github.io/couch-games/` serves the shell.
