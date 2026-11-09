import type { LayoutId, Player } from '@couch/shared'

export type Route = { name: 'library' } | { name: 'play'; id: string } | { name: 'results'; id: string }

/** The layout a player's phone shows on the current screen. */
export function layoutFor(
  route: Route,
  player: Player,
  lead: Player | null,
  round: { layout: LayoutId; slots: readonly number[] } | null,
): LayoutId {
  if (route.name === 'play') return round && round.slots.includes(player.slot) ? round.layout : 'wait'
  return lead?.slot === player.slot ? 'dpad' : 'wait'
}
