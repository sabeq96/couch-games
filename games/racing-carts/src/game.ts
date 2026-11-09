import { Engine } from '@babylonjs/core/Engines/engine';
import type { AbstractEngine } from '@babylonjs/core/Engines/abstractEngine';
import { PLAYER_COLORS, type Round, type RoundHandle } from '@couch/shared';
import { createAudio, type AudioDeps } from './audio/audio';
import { SoundDirector, type DirectorSource } from './audio/director';
import { soundUrl } from './audio/manifest';
import { Drivers } from './drivers';
import { FixedStepper } from './loop';
import { getPowerup } from './powerups/registry';
import { CameraRig, HIT_TRAUMA } from './render/camera';
import { EntityViews } from './render/entityViews';
import { Hud, type RaceRow } from './render/hud';
import { KartViews } from './render/kartViews';
import { createScene } from './render/scene';
import { SparkViews } from './render/sparks';
import { resultsFor } from './results';
import { buildTrack } from './track/track';
import { TRACK_V1 } from './track/trackDef';
import type { Vec2 } from './math/vec2';
import { NEUTRAL_INPUT, type InputSnapshot } from './rules';
import { createKart, resolveKartCollisions, stepKart, type Kart } from './kart/kart';
import { stepSlipstream } from './kart/slipstream';
import { CATCHUP } from './kart/tuning';
import { ItemBoxes } from './powerups/itemBoxes';
import { rankFraction } from './powerups/odds';
import type { RollContext } from './powerups/types';
import { compareRank, lapOf } from './race/progress';
import { BoostPads } from './race/boostPads';
import { handleItemInput } from './powerups/useItem';
import { createWorld, type World } from './powerups/world';
import { Race, type RaceEvent } from './race/race';
import type { Track } from './track/track';

/** Returned by the drains on quiet steps, so they allocate nothing. */
const NO_IDS: readonly never[] = Object.freeze([]);

export interface Driver {
  kind: 'human' | 'bot';
  name: string;
  input(): InputSnapshot;
}

/** Owns the simulation: karts, physics, powerups and race rules. No rendering here. */
export class Game {
  track: Track;
  karts: Kart[] = [];
  race = new Race();
  /** Powerup entities, effects, sounds and hits for the current karts (replaced by `setupKarts`). */
  world: World;
  itemBoxes: ItemBoxes;
  boostPads: BoostPads;
  /** Human kart ids as of the latest step; reused so the render loop allocates nothing. */
  private humanIds: number[] = [];
  private readonly isHuman = (id: number): boolean => this.humanIds.indexOf(id) >= 0;
  /** Each kart's input for the current step, reused. */
  private inputs: InputSnapshot[] = [];
  /** Each kart's catch-up top speed scale for the current step, and the race order of this step (reused). */
  private topScale: number[] = [];
  private ranked: Kart[] = [];
  private rankCtx: RollContext = { position: 1, racerCount: 1 };
  /** Kart ids that hit a wall / were bumped by another kart since the last drain (for sounds). */
  private wallHits: number[] = [];
  private bumps: number[] = [];

  constructor(track: Track, private readonly rand: () => number = Math.random) {
    this.track = track;
    this.world = createWorld(this.karts, track);
    this.itemBoxes = new ItemBoxes(track);
    this.boostPads = new BoostPads(track);
  }

  /**
   * Creates fresh karts on grid slots 0..n-1 (capped at the grid size) in slot colours, with no items or
   * effects, and resets the powerup world and item boxes (every race start and rematch comes through here).
   */
  setupKarts(slotCount: number): void {
    const n = Math.max(0, Math.min(slotCount, this.track.grid.length, PLAYER_COLORS.length));
    this.karts = Array.from({ length: n }, (_, i) =>
      createKart(i, PLAYER_COLORS[i], this.track.grid[i], this.track),
    );
    this.world = createWorld(this.karts, this.track);
    this.itemBoxes = new ItemBoxes(this.track);
    this.boostPads = new BoostPads(this.track);
    this.wallHits.length = 0;
    this.bumps.length = 0;
  }

  /**
   * One fixed step: inputs → item presses → physics (with catch-up) → kart collisions → item boxes → boost
   * pads and slipstream (racing only) → powerup world (entities, effects) → race (progress, laps, phases).
   * Inputs, items included, only count while racing.
   */
  step(dt: number, drivers: (kartId: number) => Driver): RaceEvent[] {
    const racing = this.race.phase === 'racing';
    const karts = this.karts;
    const inputs = this.inputs;
    inputs.length = karts.length;
    this.humanIds.length = 0;
    for (let i = 0; i < karts.length; i++) {
      const driver = drivers(karts[i].id);
      if (driver.kind === 'human') this.humanIds.push(karts[i].id);
      inputs[i] = racing ? driver.input() : NEUTRAL_INPUT;
    }
    for (let i = 0; i < karts.length; i++) handleItemInput(karts[i], inputs[i].item, this.world);
    this.rankKarts();
    this.updateCatchUp(racing);
    for (let i = 0; i < karts.length; i++) {
      if (stepKart(karts[i], inputs[i], this.track, dt, this.topScale[i]).hitWall) this.wallHits.push(karts[i].id);
    }
    for (const [a, b] of resolveKartCollisions(karts)) this.bumps.push(a, b);
    this.itemBoxes.update(dt, karts, this.world, this.rand);
    if (racing) {
      // Pads and drafting are race rules: nothing fires on the grid or after the results are up.
      this.boostPads.update(dt, karts, this.world);
      stepSlipstream(this.ranked, this.world, dt); // distances only change in the race step: still in order
    }
    this.world.step(dt);
    return this.race.update(dt, karts, this.track, this.isHuman);
  }

  /** Rebuilds `ranked` in race order (`compareRank`) with an insertion sort: a handful of karts, no temporary arrays. */
  private rankKarts(): void {
    const ranked = this.ranked;
    ranked.length = 0;
    for (const k of this.karts) {
      let j = ranked.length;
      ranked.push(k);
      while (j > 0 && compareRank(ranked[j - 1], k) > 0) {
        ranked[j] = ranked[j - 1];
        j--;
      }
      ranked[j] = k;
    }
  }

  /**
   * Catch-up: while racing, each unfinished kart's top speed is scaled by 1 + CATCHUP × its rank fraction
   * (0 for the leader, 1 for last place), so the back of the pack can close gaps. Allocation-free.
   */
  private updateCatchUp(racing: boolean): void {
    const karts = this.karts;
    const scale = this.topScale;
    scale.length = karts.length;
    for (let i = 0; i < karts.length; i++) scale[i] = 1;
    if (!racing) return;
    const ranked = this.ranked;
    const ctx = this.rankCtx;
    ctx.racerCount = ranked.length;
    for (let r = 0; r < ranked.length; r++) {
      const k = ranked[r];
      if (k.finishedAt !== null) continue;
      ctx.position = r + 1;
      scale[karts.indexOf(k)] = 1 + CATCHUP * rankFraction(ctx);
    }
  }

  /** Ids of karts that hit a wall since the last call (an id repeats per hit). */
  drainWallHits(): readonly number[] {
    if (this.wallHits.length === 0) return NO_IDS;
    const out = this.wallHits;
    this.wallHits = [];
    return out;
  }

  /** Ids of karts that bumped another kart since the last call (both karts of a pair; an id repeats per bump). */
  drainKartBumps(): readonly number[] {
    if (this.bumps.length === 0) return NO_IDS;
    const out = this.bumps;
    this.bumps = [];
    return out;
  }

  /** Ids of karts driven by humans, per the drivers passed to the latest `step` (a live, shared array). */
  humanKartIds(): readonly number[] {
    return this.humanIds;
  }
}

/** Karts on the grid every round: the players' slots, bots in the rest. */
const KART_COUNT = 6;
/** Shown in the race list while a kart's item roulette spins. */
const ROLLING_ICON = '🎲';

/** Test seams: how the Babylon engine is made (default: WebGL on the canvas, antialiased), and audio's. */
export interface StartDeps {
  engine?: (canvas: HTMLCanvasElement) => AbstractEngine;
  audio?: AudioDeps;
}

const webglEngine = (canvas: HTMLCanvasElement): AbstractEngine =>
  new Engine(canvas, true, { stencil: false, preserveDrawingBuffer: false, powerPreference: 'high-performance' }, false);

/**
 * One race in `round.el`: a kart per player in their slot colour, bots in the other karts, countdown → race,
 * then `round.finish` with every player's place.
 */
export function start(round: Round, deps: StartDeps = {}): RoundHandle<'tilt-racer'> {
  const { el, players } = round;
  const canvas = document.createElement('canvas');
  canvas.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;display:block;';
  const hudRoot = document.createElement('div');
  hudRoot.style.cssText = 'position:absolute;inset:0;pointer-events:none;overflow:hidden;';
  el.append(canvas, hudRoot);
  const hud = new Hud(hudRoot);

  const clear = (): void => {
    hud.dispose();
    el.replaceChildren();
  };
  let engine: AbstractEngine;
  try {
    engine = (deps.engine ?? webglEngine)(canvas);
  } catch {
    hud.message("This screen can't draw 3D");
    return { input() {}, destroy: clear };
  }
  engine.resize();
  // Sound never blocks or breaks the game: files that fail to load just stay silent.
  const audio = createAudio(soundUrl, deps.audio);
  const sounds = new SoundDirector(audio);
  audio.unlock(); // resumes on the first key or pointer press if the page has not had one
  void audio.load();

  const track = buildTrack(TRACK_V1);
  const game = new Game(track);
  game.setupKarts(KART_COUNT);
  const drivers = new Drivers(game, players);
  const driverFor = (id: number): Driver => drivers.driverFor(id);
  game.race.start();

  const scene = createScene(engine, track);
  const views = new KartViews(scene);
  const entities = new EntityViews(scene);
  const rig = new CameraRig(scene, track.bounds);
  const sparks = new SparkViews(scene, track);
  const stepper = new FixedStepper(60);
  // Wall hits feed both the sparks and the sounds: drained once per frame, then handed to the director.
  let frameWallHits: readonly number[] = [];
  const soundSource: DirectorSource = {
    drainWallHits: () => frameWallHits,
    drainKartBumps: () => game.drainKartBumps(),
    get world() {
      return game.world;
    },
    get race() {
      return game.race;
    },
    get karts() {
      return game.karts;
    },
  };

  // Reused every frame so the render loop does not allocate.
  const ranked: Kart[] = [];
  const rows: RaceRow[] = [];
  const framed: Vec2[] = [];
  const rowsFor = (): RaceRow[] => {
    ranked.length = 0;
    for (const k of game.karts) ranked.push(k);
    ranked.sort(compareRank);
    rows.length = ranked.length;
    for (let i = 0; i < ranked.length; i++) {
      const k = ranked[i];
      const row = rows[i] || (rows[i] = { name: '', color: '', lap: 1, item: null, finished: false });
      row.name = driverFor(k.id).name;
      row.color = k.color;
      row.lap = lapOf(k, track);
      row.item = k.rolling ? ROLLING_ICON : k.item !== null ? getPowerup(k.item)?.icon ?? null : null;
      row.finished = k.finishedAt !== null;
    }
    return rows;
  };

  let destroyed = false;
  let finished = false;
  let reported = false;

  engine.runRenderLoop(() => {
    if (destroyed) return;
    const dt = engine.getDeltaTime() / 1000;
    stepper.advance(dt, (h) => {
      if (finished) return;
      for (const e of game.step(h, driverFor)) {
        sounds.raceEvent(e, game.humanKartIds());
        if (e.kind === 'countdown') hud.countdown(e.n);
        else if (e.kind === 'go') hud.countdown('GO');
        else if (e.kind === 'results') finished = true;
      }
      // A hit on a human kart gives the shared camera a soft shake.
      const humans = game.humanKartIds();
      for (const id of game.world.drainHits()) if (humans.indexOf(id) >= 0) rig.addTrauma(HIT_TRAUMA);
    });
    if (finished) {
      // The shell destroys the round from inside `finish`: report after this frame, never from inside it.
      if (!reported) {
        reported = true;
        setTimeout(() => {
          if (!destroyed) round.finish(resultsFor(game.karts, players));
        }, 0);
      }
      return;
    }
    frameWallHits = game.drainWallHits();
    sounds.frame(soundSource, performance.now());
    const phase = game.race.phase;
    if (phase === 'countdown' || phase === 'racing') hud.race(rowsFor());

    views.update(game.karts);
    entities.update(game.itemBoxes, game.world.entities, Math.min(0.1, dt));
    sparks.update(game.karts, frameWallHits, Math.min(0.1, dt));
    const humanIds = game.humanKartIds();
    framed.length = 0;
    // The camera eases in on the humans' karts (all karts when there are none).
    for (const k of game.karts) if (humanIds.length === 0 || humanIds.indexOf(k.id) >= 0) framed.push(k.pos);
    rig.update(framed, engine.getAspectRatio(rig.camera), Math.min(0.1, dt));
    scene.render();
  });
  const onResize = (): void => engine.resize();
  window.addEventListener('resize', onResize);

  return {
    input(slot, input) {
      drivers.setInput(slot, input);
    },
    destroy() {
      if (destroyed) return;
      destroyed = true;
      engine.stopRenderLoop();
      engine.dispose();
      audio.dispose();
      window.removeEventListener('resize', onResize);
      clear();
    },
  };
}
