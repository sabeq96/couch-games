// @vitest-environment happy-dom
import { afterEach, beforeEach, expect, test, vi } from 'vitest';
import type { Round } from '@couch/shared';
import { encodeInputs, encodePlayers } from './bridge';
import { start } from './game';

const players = [
  { slot: 0, name: 'Alex', color: '#ff8fab' },
  { slot: 2, name: 'Sam', color: '#8fd3ff' },
];

/** Stands in for the page's `AudioContext`; `game.ts` wraps it on the first start. */
class FakeAudioContext {
  static all: FakeAudioContext[] = [];
  state: AudioContextState = 'suspended';
  close = vi.fn(async () => {
    if (this.state === 'closed') throw new DOMException('already closed', 'InvalidStateError');
    this.state = 'closed';
  });
  resume = vi.fn(async () => {
    this.state = 'running';
  });
  constructor() {
    FakeAudioContext.all.push(this);
  }
}
(window as unknown as { AudioContext: unknown }).AudioContext = FakeAudioContext;

/** Stands in for the global `Engine` of Godot's `index.js`. */
class FakeEngine {
  static all: FakeEngine[] = [];
  /** Set by a test: `requestQuit` then never calls `onExit`. */
  static neverExits = false;
  /** Set by a test: `startGame` waits until this resolves. */
  static gate: Promise<void> | null = null;
  quits = 0;
  audio?: FakeAudioContext;
  constructor(readonly config: Record<string, unknown>) {
    FakeEngine.all.push(this);
  }
  async startGame(_override: { mainPack: string }): Promise<void> {
    // Godot makes its AudioContext while it starts: `new (window.AudioContext || window.webkitAudioContext)()`.
    this.audio = new (window as unknown as { AudioContext: new () => FakeAudioContext }).AudioContext();
    await FakeEngine.gate;
  }
  requestQuit(): void {
    this.quits++;
    if (!FakeEngine.neverExits) (this.config.onExit as (code: number) => void)(0);
  }
}

const loadScript = () => Promise.resolve();
let finish: ReturnType<typeof vi.fn<Round['finish']>>;
let el: HTMLElement;
let round: Round;

beforeEach(() => {
  FakeEngine.all = [];
  FakeEngine.neverExits = false;
  FakeEngine.gate = null;
  FakeAudioContext.all = [];
  (globalThis as unknown as { Engine: typeof FakeEngine }).Engine = FakeEngine;
  el = document.createElement('div');
  document.body.append(el);
  finish = vi.fn<Round['finish']>();
  round = { el, players, finish };
});

afterEach(() => {
  vi.useRealTimers();
  el.remove();
  delete window.racingCarts;
});

/** Lets the script load and `startGame` settle. */
const settle = () => new Promise((r) => setTimeout(r, 0));

test('start mounts one canvas, shows Loading… and publishes the players', async () => {
  start(round, { loadScript });
  expect(el.querySelectorAll('canvas')).toHaveLength(1);
  expect(el.querySelector('canvas')?.id).not.toBe('');
  expect(el.textContent).toContain('Loading…');
  expect(window.racingCarts?.players).toBe(encodePlayers(players));
  await settle();
  expect(FakeEngine.all).toHaveLength(1);
  expect(FakeEngine.all[0].config.canvas).toBe(el.querySelector('canvas'));
});

test('ready() removes Loading…', () => {
  start(round, { loadScript });
  window.racingCarts?.ready();
  expect(el.textContent).not.toContain('Loading…');
});

test('input() rewrites the inputs', () => {
  const handle = start(round, { loadScript });
  const input = { steer: -0.5, gas: true, brake: false, item: false };
  handle.input(2, input);
  expect(window.racingCarts?.inputs).toBe(encodeInputs(new Map([[2, input]])));
});

test('finish() hands the decoded results to the round once', () => {
  start(round, { loadScript });
  window.racingCarts?.finish('[{"slot":0,"place":1}]');
  window.racingCarts?.finish('[{"slot":2,"place":1}]');
  expect(finish).toHaveBeenCalledTimes(1);
  expect(finish).toHaveBeenCalledWith([
    { slot: 0, place: 1 },
    { slot: 2, place: 2 },
  ]);
});

test('destroy() quits the engine, then removes the canvas and the global', async () => {
  const handle = start(round, { loadScript });
  await settle();
  handle.destroy();
  await settle();
  expect(FakeEngine.all[0].quits).toBe(1);
  expect(el.querySelector('canvas')).toBeNull();
  expect(window.racingCarts).toBeUndefined();
});

test('destroy() cleans up after 2000 ms when the engine never exits', async () => {
  vi.useFakeTimers();
  FakeEngine.neverExits = true;
  const handle = start(round, { loadScript });
  await vi.advanceTimersByTimeAsync(0);
  handle.destroy();
  await vi.advanceTimersByTimeAsync(1999);
  expect(el.querySelector('canvas')).not.toBeNull();
  await vi.advanceTimersByTimeAsync(1);
  expect(el.querySelector('canvas')).toBeNull();
  expect(window.racingCarts).toBeUndefined();
});

test('destroy() before startGame resolves quits the engine once it has started', async () => {
  let open!: () => void;
  FakeEngine.gate = new Promise((r) => (open = r));
  const handle = start(round, { loadScript });
  await settle();
  handle.destroy();
  await settle();
  expect(FakeEngine.all[0].quits).toBe(0);
  open();
  await settle();
  expect(FakeEngine.all[0].quits).toBe(1);
  expect(el.querySelector('canvas')).toBeNull();
  expect(window.racingCarts).toBeUndefined();
});

test('destroy() while the script loads never starts an engine', async () => {
  let loaded!: () => void;
  const handle = start(round, { loadScript: () => new Promise((r) => (loaded = r)) });
  handle.destroy();
  loaded();
  await settle();
  expect(FakeEngine.all).toHaveLength(0);
  expect(el.querySelector('canvas')).toBeNull();
  expect(window.racingCarts).toBeUndefined();
});

test("Godot's audio worklet error after a quit is kept out of the page errors, others are not", () => {
  const rejection = (reason: unknown) => {
    const event = new Event('unhandledrejection', { cancelable: true });
    Object.defineProperty(event, 'reason', { value: reason });
    window.dispatchEvent(event);
    return event.defaultPrevented;
  };
  expect(rejection(new TypeError("Failed to construct 'AudioWorkletNode': parameter 1 is not of type 'BaseAudioContext'."))).toBe(true);
  expect(rejection(new TypeError('something else'))).toBe(false);
  expect(rejection(new Error('AudioWorkletNode'))).toBe(false);
});

test("destroy() closes the round's audio contexts", async () => {
  const handle = start(round, { loadScript });
  await settle();
  const audio = FakeEngine.all[0].audio!;
  expect(audio).toBeInstanceOf(FakeAudioContext);
  audio.close.mockClear();
  handle.destroy();
  await settle();
  expect(audio.close).toHaveBeenCalledTimes(1);
  expect(audio.state).toBe('closed');
});

test('destroy() closes the audio contexts after 2000 ms when the engine never exits', async () => {
  vi.useFakeTimers();
  FakeEngine.neverExits = true;
  const handle = start(round, { loadScript });
  await vi.advanceTimersByTimeAsync(0);
  const audio = FakeEngine.all[0].audio!;
  handle.destroy();
  await vi.advanceTimersByTimeAsync(1999);
  expect(audio.close).not.toHaveBeenCalled();
  await vi.advanceTimersByTimeAsync(1);
  expect(audio.close).toHaveBeenCalledTimes(1);
});

test('closing an already closed audio context is ignored', async () => {
  const errors: unknown[] = [];
  const onRejection = (e: Event) => errors.push(e);
  window.addEventListener('unhandledrejection', onRejection);
  const handle = start(round, { loadScript });
  await settle();
  FakeEngine.all[0].audio!.state = 'closed';
  handle.destroy();
  await settle();
  await settle();
  window.removeEventListener('unhandledrejection', onRejection);
  expect(errors).toEqual([]);
  expect(el.querySelector('canvas')).toBeNull();
});

test("one round's destroy leaves another round's audio alone", async () => {
  const elB = document.createElement('div');
  document.body.append(elB);
  const a = start(round, { loadScript });
  await settle();
  const b = start({ ...round, el: elB }, { loadScript });
  await settle();
  const [audioA, audioB] = FakeEngine.all.map((e) => e.audio!);
  b.destroy();
  await settle();
  expect(audioB.close).toHaveBeenCalledTimes(1);
  expect(audioA.close).not.toHaveBeenCalled();
  a.destroy();
  await settle();
  expect(audioA.close).toHaveBeenCalledTimes(1);
  elB.remove();
});

test('a key or pointer press on the page resumes suspended audio while the round runs', async () => {
  const handle = start(round, { loadScript });
  await settle();
  const audio = FakeEngine.all[0].audio!;
  window.dispatchEvent(new Event('keydown'));
  expect(audio.resume).toHaveBeenCalledTimes(1);
  audio.state = 'suspended';
  window.dispatchEvent(new Event('pointerdown'));
  expect(audio.resume).toHaveBeenCalledTimes(2);
  // Running audio is left alone.
  await settle();
  window.dispatchEvent(new Event('keydown'));
  expect(audio.resume).toHaveBeenCalledTimes(2);
  handle.destroy();
});

test('after destroy, presses no longer touch the audio', async () => {
  const handle = start(round, { loadScript });
  await settle();
  const audio = FakeEngine.all[0].audio!;
  handle.destroy();
  await settle();
  audio.state = 'suspended';
  window.dispatchEvent(new Event('keydown'));
  window.dispatchEvent(new Event('pointerdown'));
  expect(audio.resume).not.toHaveBeenCalled();
});
