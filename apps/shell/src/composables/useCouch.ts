import { ref, shallowRef } from 'vue'
import type { LayoutId, LayoutInputs, Player, Result, ServerMsg } from '@couch/shared'
import { games, type GameEntry } from '../games'
import { routeInput } from '../inputRouting'
import { layoutFor, type Route } from '../layoutFor'
import { Party } from '../party'
import { Presses, type Key } from '../presses'
import type { RoomHandlers } from '../room/host'

export interface RoundState {
  n: number
  entry: GameEntry
  /** Roster snapshot taken at start; players who leave stay in it. */
  players: readonly Player[]
  /** Connection ids of the roster: slots are reused, ids are not. */
  ids: ReadonlySet<string>
}

export interface CouchDeps {
  send(id: string, msg: ServerMsg): void
  /** The running round's input sink (PlayScreen), if any. */
  round(): { input(slot: number, input: LayoutInputs[LayoutId]): void } | null | undefined
  /** The screen the lead's d-pad drives (library or results), if any. */
  menu(): { press(k: Key): void } | null | undefined
}

/**
 * The party and what each phone is told: who is in it, the current route and round, the last results, the layout
 * sent to each member, and where each member's input goes.
 */
export function useCouch(deps: CouchDeps) {
  const party = new Party()
  const presses = new Presses()
  const sentLayout = new Map<string, LayoutId>()
  const route = shallowRef<Route>({ name: 'library' })
  const round = shallowRef<RoundState | null>(null)
  const last = shallowRef<{ id: string; results: Result[]; players: readonly Player[] } | null>(null)
  const members = ref<readonly Player[]>([])
  let rounds = 0

  const leadId = (): string | undefined => {
    const lead = party.lead()
    return lead ? party.idOf(lead.slot) : undefined
  }

  /** Tells every phone its layout and colour for the current screen and party, and remembers what was sent. */
  function syncStates(): void {
    members.value = party.members()
    const r = round.value
    const slots = r ? party.members().filter((p) => r.ids.has(party.idOf(p.slot) ?? '')).map((p) => p.slot) : []
    for (const p of party.members()) {
      const id = party.idOf(p.slot)
      if (!id) continue
      const layout = layoutFor(route.value, p, party.lead(), r && { layout: r.entry.game.layout, slots })
      sentLayout.set(id, layout)
      deps.send(id, { t: 'state', layout, color: p.color })
    }
  }

  /** A new route: starts a round for `#/play/<id>`, and resets the lead's d-pad baseline. */
  function enter(next: Route): void {
    const entry = next.name === 'play' ? games.find((g) => g.id === next.id) : undefined
    if (entry) {
      const players = party.roster(entry.game.players.max)
      const ids = new Set(players.map((p) => party.idOf(p.slot) ?? ''))
      round.value = { n: ++rounds, entry, players, ids }
    } else {
      round.value = null
    }
    route.value = next
    presses.reset()
    syncStates()
  }

  /** The round's results; the caller then routes to results. */
  function finish(res: Result[]): void {
    const r = round.value
    if (r) last.value = { id: r.entry.id, results: res, players: r.players }
  }

  const handlers: RoomHandlers = {
    onHello(id, name) {
      if (!party.join(id, name)) return false
      syncStates()
      return true
    },
    onInput(id, fields) {
      const p = party.byId(id)
      if (!p) return
      const routed = routeInput(id, p.slot, fields, {
        route: route.value,
        leadId: leadId(),
        sentLayout,
        roundIds: round.value?.ids ?? new Set(),
      })
      if (routed?.to === 'round') deps.round()?.input(routed.slot, routed.input)
      else if (routed?.to === 'presses') for (const k of presses.next(routed.input)) deps.menu()?.press(k)
    },
    onLeave(id) {
      if (id === leadId()) presses.reset() // the new lead's held keys are its baseline
      party.leave(id)
      sentLayout.delete(id)
      syncStates()
    },
  }

  return { route, round, last, members, enter, finish, handlers }
}
