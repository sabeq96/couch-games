# Couch Games

Local co-op games on one shared screen, with phones as controllers. Open the site on a big screen (the **shell**):
it opens one room, shows a QR code and a library of games. Players scan once and join the party; the shell decides
what every phone shows. The first game is **Racing Carts**: up to 6 karts, bots fill the empty ones, 3 laps.

## Play

1. Open the site on the screen. It shows a room code, a QR code and the library.
2. Each player scans the QR (or opens `<site>/controller/?room=CODE`), types a name and taps **Join**.
3. The first phone to join is the lead player. Its d-pad moves through the library; **A** opens a game.
4. Racing Carts: hold the phone sideways and **tilt to steer**. Hold **GAS**, tap **ITEM** to use what you picked up, hold **BRAKE** to slow down or reverse. **Center** resets "straight ahead".
5. At the end the screen shows the results. The lead player taps **A** to play again or **B** for the library.

On the host, the keyboard works too: arrows and Enter in the library and results, Backspace for B, Escape to leave a round.

## Develop

Prerequisites: Node, and **Godot 4.7.1 with its web export templates** (Racing Carts is a Godot project). Every
Godot call goes through `scripts/godot.sh`: it uses `$GODOT` if set, else `/Applications/Godot.app`, else `godot` on
the `PATH`. `npm test`, `npm run build` and `npm run e2e` need it.

```bash
npm install
npm test             # Vitest in every workspace, plus Racing Carts' GUT tests in Godot
npm run typecheck
npm run lint
npm run build        # the whole site into output/ (exports Racing Carts first)
```

Run `npm run export -w racing-carts` once (and again after changing the Godot project) before `npm run dev -w
@couch/shell`: the dev server serves the export from `apps/shell/public/games/racing-carts/`.

```bash
npm run dev -w @couch/shell        # the host screen
npm run dev -w @couch/controller   # the phone page, at /couch-games/controller/ (add ?demo=dpad or ?demo=tilt-racer to preview a layout)
```

### End-to-end tests

```bash
npx playwright install chromium   # once
CI=1 npm run e2e
```

`npm run e2e` builds the site for tests, serves it on port 4173 with a local PeerJS broker on port 9000, and runs
Playwright against it (`e2e/`). Without `CI=1`, Playwright reuses whatever is already listening on port 4173, which
can be an unrelated server; `CI=1` always starts a fresh one.

### Add a game

Add a folder `games/<id>/` with `index.ts` (title, cover, layout, player count, a lazy `load`) and `src/game.ts`
exporting `start({ el, players, finish })`. The shell finds it by itself. See
[ARCHITECTURE.md](ARCHITECTURE.md#game-contract); `games/racing-carts` is the example.

## Deploy

GitHub Pages deploys from `main`: every push to `main` runs lint, tests, e2e and the build, then publishes `output/`
(the shell at `/`, the controller at `/controller/`). Pull requests run the same checks without publishing.
One time: in GitHub open **Settings → Pages** and set **Source** to **GitHub Actions**.

## Docs

- [ARCHITECTURE.md](ARCHITECTURE.md): how it is put together
- [FEATURES.md](FEATURES.md): every feature as a user story
- [GLOSSARY.md](GLOSSARY.md): the domain language
- [games/racing-carts/](games/racing-carts/): the game's own GLOSSARY.md, ARCHITECTURE.md and FEATURES.md
- [docs/audio-assets.md](docs/audio-assets.md): prompts for generating the sounds and music

## Layout

```
packages/shared/   @couch/shared: protocol, layouts, Game/Round types, room codes, colours
packages/ui/       @couch/ui: the one Tailwind + daisyUI theme
apps/shell/        the host screen (Vue): room, party, library, results
apps/controller/   the phone page (Vue): join screen and layouts
games/             one folder per game; racing-carts is the first
e2e/               Playwright tests and the fixture game
docs/              item and audio guides
```
