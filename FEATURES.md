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
- If the shell cannot reach the PeerJS broker, it shows "Can't create room — retrying" and tries again every 5 s.
- Lives in: `packages/shared/src/protocol.ts`, `apps/shell/src/room/host.ts`, `apps/shell/src/party.ts`, `apps/controller/src/App.vue`, `apps/controller/src/MessageScreen.vue`, `apps/controller/src/connection.ts`.

### F2. See the party
As a **viewer**, I want the host screen to always show who is in the party, so that everyone knows who has joined and which colour they are.
- The party bar shows the QR, room code, controller URL, and each player's colour and name, with the lead player marked.
- It is full size on the library and results, and a compact chip during a round.
- New phones can join at any time. A player who joins mid-round waits and plays in the next round.
- The party holds at most 6 players, one colour each.
- Lives in: `apps/shell/src/components/PartyBar.vue`, `apps/shell/src/party.ts`, `packages/shared/src/protocol.ts` (`PLAYER_COLORS`, `MAX_PARTY`).

## The shell

### F3. Pick a game with the d-pad
As the **lead player**, I want to move through the library with my phone's d-pad and open a game with A, so that I choose without leaving the couch.
- The library shows a card per game with its cover and title. Games needing more players than the party has are greyed out and cannot be opened.
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
- Lives in: `apps/shell/src/App.vue`, `apps/shell/src/screens/PlayScreen.vue`, `apps/shell/src/router.ts`, `apps/shell/src/layoutFor.ts`, `packages/shared/src/game.ts`.

### F5. Results and play again
As the **lead player**, I want to see the finishing order and choose play again or the library with A and B, so that the evening keeps going.
- When a game calls `finish`, the shell shows each player's place, name and colour on `#/results/<id>`.
- The lead player's phone shows `dpad`: **A** plays the same game again, **B** goes to the library. Other phones show `wait`.
- An A still held when the results appear does not trigger play again.
- Lives in: `apps/shell/src/screens/ResultsScreen.vue`, `apps/shell/src/presses.ts`, `apps/shell/src/App.vue` (`onFinish`).

### F6. Back to the library
As a **viewer**, I want to get back to the library at any time, so that we are never stuck in a game.
- Escape or browser back on the host from a round, and **B** on the results, go to `#/`.
- Going back never starts a round by itself.
- Lives in: `apps/shell/src/App.vue` (`go`, `onKey`, `applyHash`), `apps/shell/src/router.ts`.

## Phone controls

### F7. Layouts on the phone
As a **player**, I want a simple fixed set of controls for whatever the shell is doing, so that I never have to read the phone.
- `wait`: "Look at the screen" in my colour. `dpad`: d-pad, A and B.
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

## Racing Carts: a round

### F12. Countdown, three laps and a finish
As a **viewer**, I want a 3-2-1-GO countdown, three laps and a clear end, so that every race has a start and a finish.
- Inputs are ignored until GO.
- Lap, final-lap and finish moments play sounds for human karts only.
- The round ends when every player has finished, or 30 s after the first player finishes. Then the game calls `finish` with each player's place among all karts, bots included.
- Lives in: `games/racing-carts/src/race/race.ts`, `games/racing-carts/src/race/progress.ts`, `games/racing-carts/src/results.ts`, `games/racing-carts/src/game.ts` (`start`), `games/racing-carts/src/audio/director.ts`.

### F13. See the race order
As a **viewer**, I want a race list on the screen, so that everyone can see who is leading.
- One row per kart in race order: colour, name, lap, held item (🎲 while rolling), and a flag when finished.
- Text is at least 36 px on the 1920×1080 stage, so it reads from the couch.
- Lives in: `games/racing-carts/src/game.ts` (`rowsFor`), `games/racing-carts/src/render/hud.ts`.

## Racing Carts: driving

### F14. Steer by tilting my phone
As a **player**, I want to hold my phone sideways and tilt it to steer, so that driving feels natural.
- Steer comes from the axis that matches the screen orientation, with a small dead zone and full lock at a moderate tilt.
- **Center** sets the current tilt as straight ahead. A tilt meter shows the current steer.
- The page asks for motion permission (iOS), keeps the screen awake and tries to lock landscape.
- If motion is denied or unavailable, the phone says "No access to the motion sensor — steering is off". There is no fallback.
- Lives in: `apps/controller/src/tilt.ts`, `apps/controller/src/layouts/TiltRacerLayout.vue`.

### F15. Gas, brake, reverse and use an item
As a **player**, I want big **GAS**, **BRAKE** and **ITEM** buttons, so that I can drive without looking at my phone.
- Hold GAS to accelerate. Hold BRAKE to slow down, then reverse.
- A tap on ITEM shorter than one send interval still counts, and one press uses the item once.
- Lives in: `apps/controller/src/layouts/TiltRacerLayout.vue`, `apps/controller/src/latch.ts`, `games/racing-carts/src/drivers.ts`.

### F16. Arcade kart handling
As a **player**, I want simple, forgiving physics, so that anyone can drive in seconds.
- Acceleration, top speed, steering and grip with a little slide. No physics engine; a fixed 60 Hz step.
- Soft wall bounces. Touching a wall also costs speed, so riding the walls never wins.
- Karts bump each other apart.
- A hit spins the kart for 1.2 s. There is no elimination and no respawn.
- Lives in: `games/racing-carts/src/kart/kart.ts`, `games/racing-carts/src/kart/tuning.ts`, `games/racing-carts/src/loop.ts`.

### F17. Drift and mini-turbo
As a **player**, I want to power-slide through corners and get a boost out of them, so that cornering has some skill.
- Hold BRAKE while steering at speed to drift. The kart slides and carves the corner.
- The longer the drift, the bigger the mini-turbo when it ends (level 1 or 2). The screen shows sparks.
- BRAKE still held after a drift is ignored until let go, so a drift never ends in a hard stop.
- Lives in: `games/racing-carts/src/kart/kart.ts`, `games/racing-carts/src/kart/tuning.ts`, `games/racing-carts/src/render/sparks.ts`.

### F18. Boost pads
As a **player**, I want chevron pads on the road that boost me, so that the track has spots worth aiming for.
- Driving over a pad gives a 1 s boost and a sound. A pad never cuts a longer boost short.
- Pads only work while racing.
- Lives in: `games/racing-carts/src/race/boostPads.ts`, `games/racing-carts/src/track/` (pad spots), `games/racing-carts/src/render/scene.ts`.

### F19. Slipstream
As a **player**, I want to get a boost by tucking in behind the kart ahead, so that chasing pays off.
- Staying 2–12 m behind the next racing kart, roughly in line and at speed, for 1 s gives a short boost.
- White streaks run past the kart while it drafts.
- Only while racing.
- Lives in: `games/racing-carts/src/kart/slipstream.ts`, `games/racing-carts/src/game.ts`, `games/racing-carts/src/render/kartViews.ts`.

### F20. Gentle catch-up
As a **player** at the back, I want a little extra top speed, so that the race stays close.
- Up to +6 % top speed for last place, nothing for the leader.
- Paused while touching a wall and for 2 s after.
- Lives in: `games/racing-carts/src/game.ts` (`updateCatchUp`), `games/racing-carts/src/kart/kart.ts`, `games/racing-carts/src/kart/tuning.ts`.

## Racing Carts: items

### F21. Pick up an item from a box
As a **player**, I want to drive through item boxes to get an item, so that the race has surprises.
- A kart holds one item. Driving through a box while holding one gives nothing.
- After pickup, the item rolls for about 1 s, then the race list shows it.
- The roll is weighted by position: boosts and rockets favour the back, shields and mines the front.
- A box respawns 3 s after pickup.
- Lives in: `games/racing-carts/src/powerups/itemBoxes.ts`, `games/racing-carts/src/powerups/roll.ts`, `games/racing-carts/src/powerups/odds.ts`.

### F22. Use my item
As a **player**, I want to press ITEM to use what I hold, so that I can attack or defend.
- 🛡️ **Shield**: absorbs the next hit, or lasts 6 s. Shows a bubble.
- ⚡ **Boost**: +60 % top speed for 1.5 s. Shows an exhaust flame.
- 💣 **Mine**: dropped behind the kart. The first kart to touch it spins out. Its owner is safe for 0.5 s.
- 🚀 **Rocket**: follows the track and homes in on the next racing kart ahead. With nobody ahead it flies straight and pops on a wall.
- A hit gives the camera a soft shake if it lands on a human kart.
- Lives in: `games/racing-carts/src/powerups/` (one file per item in `items/`), `games/racing-carts/src/render/entityViews.ts`, `games/racing-carts/src/render/kartViews.ts`.

### F23. Add a new item in one file
As a **developer**, I want to add an item by writing one file and one registry line, so that items are cheap to try.
- Items change the game only through `WorldApi`. Render draws their entities from an `EntityLook`.
- Bots, the HUD and item boxes pick up a new item with no other changes.
- Lives in: `games/racing-carts/src/powerups/`. Guide: [docs/powerups.md](docs/powerups.md).

## Racing Carts: bots

### F24. Race against relaxed bots
As a **player**, I want bots to fill the empty karts, so that a race is fun even with two people.
- Every kart that no player drives is a bot (the game always has 6 karts).
- Bots follow the track with a random lane offset, a per-bot speed and reaction time, and slow down in sharp corners.
- They cruise below top speed, so newcomers can beat them.
- They use items when it makes sense (each item's `botShouldUse`).
- Lives in: `games/racing-carts/src/bots/bot.ts`, `games/racing-carts/src/drivers.ts` (`botInputFor`).

## Racing Carts: presentation

### F25. Follow every human kart with one camera
As a **viewer**, I want one shared camera that keeps all human karts in view, so that nobody drives off screen.
- The camera eases in on the human karts and zooms between a close distance and the whole track.
- A hit on a human kart shakes it softly.
- Lives in: `games/racing-carts/src/render/camera.ts`, `games/racing-carts/src/game.ts`.

### F26. A cozy, readable world
As a **viewer**, I want a warm, toy-like look, so that the game feels friendly.
- Pastel colours, toon shading, blocky toy karts with a blob shadow, lollipop trees, rocks, a pond, drifting clouds, a start arch, bunting, fences and flowers.
- Each kart's colour is the player's colour in the party bar, on the phone and in the race list.
- Lives in: `games/racing-carts/src/render/`.

### F27. Sound and music
As a **viewer**, I want music and sound effects, so that the race feels alive.
- Race music. Sounds for the countdown, items, hits, walls, bumps, laps and the finish.
- One engine loop whose pitch follows the average kart speed.
- A missing or broken file just stays silent. The current files are silent placeholders.
- Lives in: `games/racing-carts/src/audio/` (files in `audio/files/`). Prompts: [docs/audio-assets.md](docs/audio-assets.md).
