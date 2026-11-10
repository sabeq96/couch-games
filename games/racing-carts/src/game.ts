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
  window.racingCarts = bridge;

  let exited!: () => void;
  const exit = new Promise<void>((resolve) => (exited = resolve));
  // Resolves to the running engine, or null when the round was left before it started or it failed to start.
  const running = (deps.loadScript ?? load)()
    .then(async () => {
      if (destroyed) return null;
      const engine = new Engine(engineConfig(BASE, canvas, () => exited()));
      await engine.startGame({ mainPack: exportUrl(BASE, 'index.pck') });
      return engine;
    })
    .catch((error: unknown) => {
      console.error('Racing Carts could not start', error);
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
      void running.then(async (engine) => {
        if (engine) {
          engine.requestQuit();
          let timer: ReturnType<typeof setTimeout> | undefined;
          await Promise.race([exit, new Promise<void>((resolve) => (timer = setTimeout(resolve, QUIT_TIMEOUT_MS)))]);
          clearTimeout(timer);
          canvas.getContext('webgl2')?.getExtension('WEBGL_lose_context')?.loseContext();
        }
        canvas.remove();
        loading.remove();
        if (window.racingCarts === bridge) delete window.racingCarts;
      });
    },
  };
}
