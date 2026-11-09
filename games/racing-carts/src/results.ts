import type { Player, Result } from '@couch/shared';
import type { Kart } from './kart/kart';
import { compareRank } from './race/progress';

/** Each player's place: the rank of their kart among all karts (bots included), 1-based. */
export function resultsFor(karts: readonly Kart[], players: readonly Player[]): Result[] {
  const ranked = [...karts].sort(compareRank);
  const results: Result[] = [];
  for (const p of players) {
    const i = ranked.findIndex((k) => k.id === p.slot);
    if (i >= 0) results.push({ slot: p.slot, place: i + 1 });
  }
  return results;
}
