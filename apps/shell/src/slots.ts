import { MAX_PARTY, type Player } from '@couch/shared'

export interface Seat {
  slot: number
  /** Who sits in this slot, or null when it is free. */
  player: Player | null
  lead: boolean
}

/** One seat per party slot, in slot order; the lead is the first member by join order. */
export function seatsOf(members: readonly Player[]): Seat[] {
  return Array.from({ length: MAX_PARTY }, (_, slot) => {
    const player = members.find((p) => p.slot === slot) ?? null
    return { slot, player, lead: player !== null && player === members[0] }
  })
}
