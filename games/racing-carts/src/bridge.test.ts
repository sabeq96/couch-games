// @vitest-environment happy-dom
import { expect, test } from 'vitest';
import { decodeResults, encodeInputs, encodePlayers, engineConfig, exportUrl } from './bridge';

const p0 = { slot: 0, name: 'Alex', color: '#ff8fab' };
const p2 = { slot: 2, name: 'Sam', color: '#8fd3ff' };

test('exportUrl works with a base path and with the root', () => {
  expect(exportUrl('/couch-games/', 'index.js')).toBe('/couch-games/games/racing-carts/index.js');
  expect(exportUrl('/couch-games', 'index.js')).toBe('/couch-games/games/racing-carts/index.js');
  expect(exportUrl('/', 'index.js')).toBe('/games/racing-carts/index.js');
});

test('engineConfig keeps focus out of the canvas and leaves resizing to the shell', () => {
  const canvas = document.createElement('canvas');
  const onExit = () => {};
  expect(engineConfig('/couch-games/', canvas, onExit)).toEqual({
    executable: '/couch-games/games/racing-carts/index',
    canvas,
    focusCanvas: false,
    canvasResizePolicy: 0,
    onExit,
    args: [],
  });
});

test('encodePlayers serialises the players as a JSON array', () => {
  expect(encodePlayers([p0])).toBe('[{"slot":0,"name":"Alex","color":"#ff8fab"}]');
});

test('encodeInputs keys the inputs by slot', () => {
  const input = { steer: 1, gas: true, brake: false, item: false };
  expect(encodeInputs(new Map([[5, input]]))).toBe('{"5":{"steer":1,"gas":true,"brake":false,"item":false}}');
});

test('decodeResults keeps valid results as given', () => {
  expect(decodeResults('[{"slot":2,"place":1},{"slot":0,"place":2}]', [p0, p2])).toEqual([
    { slot: 2, place: 1 },
    { slot: 0, place: 2 },
  ]);
});

test('decodeResults places everyone in slot order after bad JSON', () => {
  expect(decodeResults('garbage', [p0, p2])).toEqual([
    { slot: 0, place: 1 },
    { slot: 2, place: 2 },
  ]);
});

test('decodeResults keeps the first duplicate, drops unknown slots and fills the missing', () => {
  expect(decodeResults('[{"slot":2,"place":1},{"slot":2,"place":2},{"slot":9,"place":3}]', [p0, p2])).toEqual([
    { slot: 2, place: 1 },
    { slot: 0, place: 2 },
  ]);
});

test('decodeResults ignores malformed entries and non-array JSON', () => {
  expect(decodeResults('[null,{"slot":"2","place":1},{"slot":0}]', [p0, p2])).toEqual([
    { slot: 0, place: 1 },
    { slot: 2, place: 2 },
  ]);
  expect(decodeResults('{"slot":2,"place":1}', [p0, p2])).toEqual([
    { slot: 0, place: 1 },
    { slot: 2, place: 2 },
  ]);
});

test('decodeResults renumbers places to 1..n', () => {
  expect(decodeResults('[{"slot":2,"place":5},{"slot":0,"place":7}]', [p0, p2])).toEqual([
    { slot: 2, place: 1 },
    { slot: 0, place: 2 },
  ]);
});
