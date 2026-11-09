import { PLAYER_COLORS } from '@couch/shared';
import { expect, test } from 'vitest';
import { createKart } from './kart/kart';
import { resultsFor } from './results';
import { buildTrack } from './track/track';
import { TRACK_V1 } from './track/trackDef';

const track = buildTrack(TRACK_V1);

test('players are placed by their kart rank among all karts', () => {
  const karts = [0, 1, 2].map((i) => createKart(i, PLAYER_COLORS[i], track.grid[i], track));
  // Race order: slot 2, slot 0, slot 1.
  karts[2].distance = 300;
  karts[0].distance = 200;
  karts[1].distance = 100;
  const players = [
    { slot: 0, name: 'Alex', color: PLAYER_COLORS[0] },
    { slot: 1, name: 'Sam', color: PLAYER_COLORS[1] },
  ];
  expect(resultsFor(karts, players)).toEqual([
    { slot: 0, place: 2 },
    { slot: 1, place: 3 },
  ]);
});
