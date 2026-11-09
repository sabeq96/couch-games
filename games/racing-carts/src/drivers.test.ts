import { expect, test } from 'vitest';
import { Drivers, BOT_NAMES } from './drivers';
import { Game } from './game';
import { buildTrack } from './track/track';
import { TRACK_V1 } from './track/trackDef';
import { mulberry32 } from './test/rand';

const players = [
  { slot: 0, name: 'Alex', color: '#FF8A80' },
  { slot: 3, name: 'Sam', color: '#FFE38A' },
];

function setup(): Drivers {
  const game = new Game(buildTrack(TRACK_V1));
  game.setupKarts(6);
  return new Drivers(game, players, mulberry32(1));
}

test('player slots get human drivers named after the player, the rest bots', () => {
  const d = setup();
  expect(d.driverFor(0).kind).toBe('human');
  expect(d.driverFor(0).name).toBe('Alex');
  expect(d.driverFor(3).kind).toBe('human');
  expect(d.driverFor(3).name).toBe('Sam');
  expect(d.driverFor(1).kind).toBe('bot');
  expect(d.driverFor(1).name).toBe(BOT_NAMES[1]);
});

test('an item press is latched for one read', () => {
  const d = setup();
  d.setInput(0, { steer: 0.5, gas: true, brake: false, item: true });
  const first = d.driverFor(0).input();
  expect(first).toMatchObject({ steer: 0.5, gas: true, brake: false, item: true });
  expect(d.driverFor(0).input().item).toBe(false);
});

test('input for a slot without a player is ignored', () => {
  const d = setup();
  expect(() => d.setInput(4, { steer: 1, gas: true, brake: false, item: true })).not.toThrow();
  expect(d.driverFor(4).kind).toBe('bot');
});

test('a human with no input yet sends nothing', () => {
  expect(setup().driverFor(3).input()).toEqual({ steer: 0, gas: false, brake: false, item: false });
});
