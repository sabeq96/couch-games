import { MAX_PARTY, PLAYER_COLORS, type Player } from '@couch/shared'

/** Who is on the couch: connection id → player, in join order. */
export class Party {
  private byConn = new Map<string, Player>()

  /** Takes the lowest free slot; null when the party is full. */
  join(id: string, name: string): Player | null {
    if (this.byConn.size >= MAX_PARTY) return null
    const used = new Set([...this.byConn.values()].map((p) => p.slot))
    let slot = 0
    while (used.has(slot)) slot++
    const player = { slot, name, color: PLAYER_COLORS[slot] }
    this.byConn.set(id, player)
    return player
  }

  leave(id: string): void {
    this.byConn.delete(id)
  }

  byId(id: string): Player | undefined {
    return this.byConn.get(id)
  }

  idOf(slot: number): string | undefined {
    for (const [id, p] of this.byConn) if (p.slot === slot) return id
    return undefined
  }

  /** Join order (a Map iterates in insertion order). */
  members(): readonly Player[] {
    return [...this.byConn.values()]
  }

  lead(): Player | null {
    return this.members()[0] ?? null
  }

  roster(max: number): Player[] {
    return this.members().slice(0, max)
  }
}
