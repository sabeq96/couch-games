import type { Round, RoundHandle, TiltRacerInput } from '@couch/shared';
import { decodeResults, encodeInputs, encodePlayers, engineConfig, exportUrl } from './bridge';

/** The engine class that Godot's `index.js` defines as a global. */
declare class Engine {
  constructor(config: Record<string, unknown>);
  startGame(override: { mainPack: string }): Promise<void>;
  requestQuit(): void;
}

/** The one global the page shares with Godot while a round runs. */
interface RacingCartsGlobal {
  players: string;
  inputs: string;
  e2e: boolean;
  ready(): void;
  finish(json: string): void;
  karts?: string;
  /** e2e builds only: the number of player views. */
  views?: number;
  /** Set by e2e tests: Godot ends the race on its next tick. */
  finishNow?: boolean;
}

declare global {
  interface Window {
    racingCarts?: RacingCartsGlobal;
  }
}

/** `destroy()` waits at most this long for Godot to quit: a hidden tab never does. */
const QUIT_TIMEOUT_MS = 2000;
const BASE = import.meta.env.BASE_URL;

let script: Promise<void> | undefined;
/** Numbers the canvases: Godot finds its canvas by id, and an old one may still be quitting. */
let rounds = 0;
/**
 * The last destroyed round's teardown. A round sets its global, owns new audio and starts its engine only after this,
 * so an engine still starting or quitting never sees the next round's global and two engines never share the page.
 */
let previousTeardown: Promise<void> = Promise.resolve();
/** A new round waits at most this long for the last one: its Godot may be stuck downloading and never quit. */
const PREVIOUS_ROUND_TIMEOUT_MS = 5000;

/** Resolves once the last round is torn down (even if that failed), or after `PREVIOUS_ROUND_TIMEOUT_MS`. */
function previousRoundGone(): Promise<void> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<void>((resolve) => (timer = setTimeout(resolve, PREVIOUS_ROUND_TIMEOUT_MS)));
  return Promise.race([previousTeardown.catch(() => {}), timeout]).finally(() => clearTimeout(timer));
}

/** Adds Godot's `index.js` to the page once. */
function load(): Promise<void> {
  script ??= new Promise<void>((resolve, reject) => {
    const tag = document.createElement('script');
    tag.src = exportUrl(BASE, 'index.js');
    tag.addEventListener('load', () => resolve());
    tag.addEventListener('error', () => {
      script = undefined;
      tag.remove();
      reject(new Error(`could not load ${tag.src}`));
    });
    document.head.append(tag);
  });
  return script;
}

// Godot 4.7.1 loads its audio worklets with `addModule().then(() => new AudioWorkletNode(GodotAudio.ctx, …))`.
// Quitting before they load clears `ctx` first, so that callback throws as an unhandled rejection. It is harmless
// (the engine is gone), so it is kept out of the page's errors. Rounds can quit this way at any time, hence for the
// page's lifetime.
function ignoreAudioAfterQuit(event: PromiseRejectionEvent): void {
  if (event.reason instanceof TypeError && event.reason.message.includes('AudioWorkletNode')) event.preventDefault();
}
window.addEventListener('unhandledrejection', ignoreAudioAfterQuit);

// `requestQuit()` leaves Godot's AudioContext open and running, so every round would leak one. The page's AudioContext
// is wrapped once: each new context joins the set of the round whose engine is running (rounds can overlap while an
// old one quits), and that round closes its set in destroy().
let audioOwner: Set<AudioContext> | null = null;
let audioTracked = false;
function trackAudioContexts(): void {
  if (audioTracked) return;
  audioTracked = true;
  const w = window as unknown as { AudioContext?: typeof AudioContext; webkitAudioContext?: typeof AudioContext };
  const Native = w.AudioContext ?? w.webkitAudioContext;
  if (!Native) return;
  class Tracked extends Native {
    constructor(options?: AudioContextOptions) {
      super(options);
      audioOwner?.add(this);
    }
  }
  if (w.AudioContext) w.AudioContext = Tracked;
  if (w.webkitAudioContext) w.webkitAudioContext = Tracked;
}

export interface StartDeps {
  loadScript?: () => Promise<void>;
}

export function start(round: Round, deps: StartDeps = {}): RoundHandle<'tilt-racer'> {
  const { el, players } = round;
  const canvas = document.createElement('canvas');
  canvas.id = `racing-carts-${++rounds}`;
  canvas.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;display:block;';
  const loading = document.createElement('div');
  loading.textContent = 'Loading…';
  loading.style.cssText =
    'position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-size:2rem;';
  el.append(canvas, loading);

  // With canvasResizePolicy 0 Godot leaves the canvas size to the page: keep it at the size of el.
  const fit = (): void => {
    canvas.width = el.clientWidth;
    canvas.height = el.clientHeight;
  };
  fit();
  const observer = new ResizeObserver(fit);
  observer.observe(el);

  let finished = false;
  let destroyed = false;
  const latest = new Map<number, TiltRacerInput>();
  const bridge: RacingCartsGlobal = {
    players: encodePlayers(players),
    inputs: encodeInputs(latest),
    e2e: import.meta.env.VITE_E2E === '1',
    ready: () => loading.remove(),
    finish: (json) => {
      if (finished || destroyed) return;
      finished = true;
      round.finish(decodeResults(json, players));
    },
  };

  // Godot's audio, and a page press to unlock it: a round started from a phone press has had no host gesture.
  trackAudioContexts();
  const audio = new Set<AudioContext>();
  const unlockAudio = (): void => {
    for (const ctx of audio) if (ctx.state === 'suspended') ctx.resume().catch(() => {});
  };
  window.addEventListener('keydown', unlockAudio, true);
  window.addEventListener('pointerdown', unlockAudio, true);

  let exited!: () => void;
  const exit = new Promise<void>((resolve) => (exited = resolve));
  // Resolves to the running engine, or null when the round was left before it started or it failed to start.
  const running = Promise.all([(deps.loadScript ?? load)(), previousRoundGone()])
    .then(async () => {
      if (destroyed) return null;
      window.racingCarts = bridge;
      audioOwner = audio;
      const engine = new Engine(engineConfig(BASE, canvas, () => exited()));
      await engine.startGame({ mainPack: exportUrl(BASE, 'index.pck') });
      return engine;
    })
    .catch((error: unknown) => {
      console.error('Racing Carts could not start', error);
      loading.textContent = 'Racing Carts could not start';
      return null;
    });

  return {
    input(slot, input) {
      latest.set(slot, input);
      bridge.inputs = encodeInputs(latest);
    },
    destroy() {
      if (destroyed) return;
      destroyed = true;
      observer.disconnect();
      window.removeEventListener('keydown', unlockAudio, true);
      window.removeEventListener('pointerdown', unlockAudio, true);
      previousTeardown = running.then(async (engine) => {
        if (engine) {
          engine.requestQuit();
          let timer: ReturnType<typeof setTimeout> | undefined;
          await Promise.race([exit, new Promise<void>((resolve) => (timer = setTimeout(resolve, QUIT_TIMEOUT_MS)))]);
          clearTimeout(timer);
          canvas.getContext('webgl2')?.getExtension('WEBGL_lose_context')?.loseContext();
        }
        for (const ctx of audio) ctx.close().catch(() => {}); // already closed: nothing to do
        if (audioOwner === audio) audioOwner = null;
        canvas.remove();
        loading.remove();
        if (window.racingCarts === bridge) delete window.racingCarts;
      });
    },
  };
}
