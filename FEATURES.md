# Features

Every feature of Couch Games as a user story, with its requirements and where it lives in the code. Add a story
here before building a new feature. Terms are defined in [GLOSSARY.md](GLOSSARY.md).

Roles:
- **player**: anyone in the party with a phone.
- **lead player**: the earliest-joined player still in the party. Navigates the shell with the d-pad.
- **viewer**: anyone watching the host screen, players included.
- **developer**: someone building, testing or shipping the site.

## The party

### F1. Join the party
As a **player**, I want to scan the QR code on the screen and join with my name, so that I can play without installing anything.
- The shell opens one room and shows a 4-letter room code, a QR code and the controller URL.
- The QR opens the controller with `?room=<CODE>`. Without it, the join screen asks for the code.
- The player types a name (up to 12 characters; empty becomes "Player") and taps **Join**. An empty code shows "Type the 4 letters from the screen".
- The shell answers with a layout and the player's colour, and the phone tints itself in that colour.
- A wrong code, a full party (7th phone) or a lost connection shows "Unable to join" and **Try again**. There is no automatic retry or rejoin.
- If the shell cannot reach the PeerJS broker, it shows "Can't create room". Reload the page to try again.
- Lives in: `packages/shared/src/protocol.ts`, `apps/shell/src/room/host.ts`, `apps/shell/src/party.ts`, `apps/controller/src/App.vue`, `apps/controller/src/MessageScreen.vue`, `apps/controller/src/connection.ts`.

### F2. See the party
As a **viewer**, I want the host screen to always show who is in the party, so that everyone knows who has joined and which colour they are.
- The party bar shows the QR, room code, controller URL, and one square per party slot (6): a joined player's square has their colour and name, with the lead player marked; an empty one says "free".
- It is full size on the library and results, and a compact chip during a round (the code and one small square per slot, filled when taken).
- New phones can join at any time. A player who joins mid-round waits and plays in the next round.
- The party holds at most 6 players, one colour each.
- Lives in: `apps/shell/src/components/PartyBar.vue`, `apps/shell/src/slots.ts`, `apps/shell/src/party.ts`, `packages/shared/src/protocol.ts` (`PLAYER_COLORS`, `MAX_PARTY`).

## The shell

### F3. Pick a game with the d-pad
As the **lead player**, I want to move through the library with my phone's d-pad and open a game with A, so that I choose without leaving the couch.
- The library shows a card per game with its cover (a real screenshot of the game), title and player count ("1–6 players"). The selected card is enlarged with a thick primary ring. A small hint pinned to the bottom centre shows the d-pad keys (move) and A (select). Games needing more players than the party has are greyed out and cannot be opened.
- The lead player's phone shows `dpad`; all other phones show `wait` ("Look at the screen").
- The shell acts on presses (a key going from up to down), never on held keys.
- The host's mouse and keyboard (arrows, Enter) work too.
- If the lead leaves, the next player in join order gets the d-pad.
- Lives in: `apps/shell/src/screens/LibraryScreen.vue`, `apps/shell/src/grid.ts`, `apps/shell/src/presses.ts`, `apps/shell/src/inputRouting.ts`, `apps/shell/src/layoutFor.ts`, `apps/controller/src/layouts/DpadLayout.vue`, `apps/controller/src/layouts/WaitLayout.vue`.

### F4. Play a round
As a **player**, I want everyone's phone to switch to the game's controls when the lead opens a game, so that we all play at once.
- The route becomes `#/play/<id>`; the game loads on demand and fills the screen.
- The round starts with the first `max` players by join order. The rest keep `wait` and watch.
- Each phone gets the game's layout; the shell forwards each player's input to the game.
- Escape on the host, or browser back, destroys the game and returns to the library. The same game can be opened again.
- Lives in: `apps/shell/src/App.vue`, `apps/shell/src/screens/PlayScreen.vue`, `apps/shell/src/routes.ts`, `apps/shell/src/layoutFor.ts`, `packages/shared/src/game.ts`.

### F5. Results and play again
As the **lead player**, I want to see the finishing order and choose play again or the library with A and B, so that the evening keeps going.
- When a game calls `finish`, the shell shows the result on `#/results/<id>`: the karts that came 1st to 3rd on a podium in the middle (2nd–1st–3rd, each on the step for its place; a step nobody earned stays empty), and everyone else below with their place, colour and name.
- The lead player's phone shows `dpad`: **A** plays the same game again, **B** goes to the library. The two buttons show their A and B keys. Other phones show `wait`.
- An A still held when the results appear does not trigger play again.
- Lives in: `apps/shell/src/screens/ResultsScreen.vue`, `apps/shell/src/presses.ts`, `apps/shell/src/App.vue` (`onFinish`).

### F6. Back to the library
As a **viewer**, I want to get back to the library at any time, so that we are never stuck in a game.
- Escape or browser back on the host from a round, and **B** on the results, go to `#/`.
- Going back never starts a round by itself.
- Lives in: `apps/shell/src/App.vue`, `apps/shell/src/routes.ts`, `apps/shell/src/composables/useHostKeys.ts`.

## Phone controls

### F7. Layouts on the phone
As a **player**, I want a simple fixed set of controls for whatever the shell is doing, so that I never have to read the phone.
- `wait`: "Look at the screen" in my colour. `dpad`: d-pad, A and B.
- Once joined, every layout is held sideways: an upright phone shows "Turn your phone sideways". Layouts fit the visible area, so Safari's bars never cover a button.
- Controls are tracked continuously and sent about 30 times a second. A tap shorter than one interval still counts.
- `?demo=<layout>` previews a layout with no host.
- Lives in: `apps/controller/src/layouts/`, `apps/controller/src/sender.ts`, `apps/controller/src/latch.ts`, `packages/shared/src/layouts.ts`.

## Building games

### F8. Add a game by folder
As a **developer**, I want to add a game by adding a folder under `games/`, so that nothing else has to change.
- A game is `games/<id>/index.ts` (title, cover, layout, players min and max, a lazy `load`) and a `start(round)` that returns `{ input, destroy }`.
- The shell finds games by itself; the folder name is the id. There is no list to edit.
- Game code downloads only when the game is opened. Assets are imported, not served from `public/`.
- Lives in: `packages/shared/src/game.ts`, `apps/shell/src/games.ts`, `games/racing-carts/index.ts`. Guide: [ARCHITECTURE.md](ARCHITECTURE.md#game-contract).

### F9. Add a layout
As a **developer**, I want to add a phone layout with one Vue file, a registry line and an input type, so that games can ask for new controls cheaply.
- Lives in: `apps/controller/src/layouts/` (`index.ts` is the registry), `packages/shared/src/layouts.ts`.

### F10. A consistent look from one theme
As a **developer**, I want the whole look in one theme file, so that the shell, the phone and every shared screen look like one product.
- `packages/ui/theme.css` holds the daisyUI `couch` theme and the six player colours.
- Lint blocks `<style>` blocks, inline styles, arbitrary values, raw palette colours, and radius, shadow and border-width overrides in the apps.
- Lives in: `packages/ui/theme.css`, `eslint.config.js`.

### F11. Ship to the web
As a **developer**, I want one command to build the site and a pipeline that checks it, so that shipping is routine.
- `npm run build` builds the shell at `/` and the controller at `/controller/` into `output/`.
- `npm run e2e` runs Playwright against a local build and a local PeerJS broker.
- Every push to `main` runs lint, tests, e2e and the build, then deploys to GitHub Pages.
- Lives in: `scripts/build.sh`, `scripts/e2e-serve.mjs`, `playwright.config.ts`, `e2e/`, `.github/workflows/deploy-web.yml`, `site.config.ts`.

## Phone access

### F28. Grant device access the same way in every game
As a **player**, I want one clear screen asking for the device access a game needs, so that I know why the phone asks and what to do when it is refused.
- The **Join** tap asks for every capability at once (today `motion`), so no prompt interrupts a game. A refusal still joins: games that don't need it work.
- A layout lists its `needs`. If one is still missing when it shows (e.g. `?demo=`), the phone lists them with the reason ("This game needs: motion sensor (to steer by tilting)") and an **Allow** button.
- A refusal or a missing sensor shows "No access to the …" with **Try again**, only on layouts that need it. The layout does not show; there is no fallback.
- The Join tap also tries fullscreen and a landscape lock (Android). iPhone has neither; an upright phone shows "Turn your phone sideways".
- Answers last until the page reloads, so later rounds go straight to the controls.
- A **developer** adds a capability (camera, microphone…) as one entry in `permissions.ts`.
- Lives in: `apps/controller/src/permissions.ts`, `apps/controller/src/composables/usePermissions.ts`, `apps/controller/src/composables/usePortrait.ts`, `apps/controller/src/landscape.ts`, `apps/controller/src/App.vue`, `apps/controller/src/layouts/index.ts`.

### F29. Install the controller for full screen
As a **player**, I want to add the controller to my Home Screen, so that it opens without browser bars.
- The controller has a web app manifest (fullscreen, landscape, icons) and the iOS web-app meta tags. Opened from the Home Screen it starts at the join screen; the room code is typed there.
- In an iOS Safari tab the join screen says "For full screen: tap Share, then Add to Home Screen". Installing is suggested, never required: scanning the QR always opens Safari.
- iOS can't be made to install or lock landscape; Android honours the manifest and the Join-tap lock.
- Lives in: `apps/controller/public/`, `apps/controller/index.html`, `apps/controller/src/App.vue`, `apps/controller/src/MessageScreen.vue`.

## Racing Carts

Racing Carts has its own features, F12 to F27 and later: [games/racing-carts/FEATURES.md](games/racing-carts/FEATURES.md).
