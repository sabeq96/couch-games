<script setup lang="ts">
import { onMounted, onUnmounted, ref, shallowRef, useTemplateRef } from 'vue'
import { peerOptions, type LayoutId, type Player, type Result } from '@couch/shared'
import PartyBar from './components/PartyBar.vue'
import LibraryScreen from './screens/LibraryScreen.vue'
import PlayScreen from './screens/PlayScreen.vue'
import ResultsScreen from './screens/ResultsScreen.vue'
import { games, type GameEntry } from './games'
import { routeInput } from './inputRouting'
import { Party } from './party'
import { Presses } from './presses'
import { hashFor, parseHash } from './router'
import { layoutFor, type Route } from './layoutFor'
import { openRoom, type Room } from './room/host'

const ROOM_RETRY_MS = 5000

interface RoundState {
  n: number
  entry: GameEntry
  /** Roster snapshot taken at start; players who leave stay in it. */
  players: readonly Player[]
  /** Connection ids of the roster: slots are reused, ids are not. */
  ids: ReadonlySet<string>
}

const party = new Party()
const presses = new Presses()
const sentLayout = new Map<string, LayoutId>()
const route = shallowRef<Route>({ name: 'library' })
const round = shallowRef<RoundState | null>(null)
const last = shallowRef<{ id: string; results: Result[]; players: readonly Player[] } | null>(null)
const members = ref<readonly Player[]>([])
const code = ref('')
const roomFailed = ref(false)
const library = useTemplateRef<InstanceType<typeof LibraryScreen>>('library')
const play = useTemplateRef<InstanceType<typeof PlayScreen>>('play')
const results = useTemplateRef<InstanceType<typeof ResultsScreen>>('results')
let rounds = 0
let room: Room | null = null
let retryTimer: ReturnType<typeof setTimeout> | undefined

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
    room?.send(id, { t: 'state', layout, color: p.color })
  }
}

/** The hash is the route: every navigation, Escape and browser back come through here. */
function applyHash(): void {
  const next = parseHash(location.hash)
  const entry = next.name === 'play' ? games.find((g) => g.id === next.id) : undefined
  const playable = entry && party.members().length >= entry.game.players.min
  if ((next.name === 'play' && !playable) || (next.name === 'results' && last.value?.id !== next.id)) {
    location.replace(hashFor({ name: 'library' }))
    return
  }
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

function go(next: Route): void {
  location.hash = hashFor(next)
}

function onFinish(res: Result[]): void {
  const r = round.value
  if (!r) return
  last.value = { id: r.entry.id, results: res, players: r.players }
  // Results replace the round in history, so browser back from results doesn't start a new round.
  location.replace(hashFor({ name: 'results', id: r.entry.id }))
}

function onInput(id: string, fields: Record<string, unknown>): void {
  const p = party.byId(id)
  if (!p) return
  const routed = routeInput(id, p.slot, fields, {
    route: route.value,
    leadId: leadId(),
    sentLayout,
    roundIds: round.value?.ids ?? new Set(),
  })
  if (routed?.to === 'round') play.value?.input(routed.slot, routed.input)
  else if (routed?.to === 'presses') for (const k of presses.next(routed.input)) (library.value ?? results.value)?.press(k)
}

function onKey(e: KeyboardEvent): void {
  if (e.key === 'Escape' && route.value.name === 'play') go({ name: 'library' })
}

async function start(): Promise<void> {
  try {
    room = await openRoom(
      {
        onHello: (id, name) => {
          if (!party.join(id, name)) return false
          syncStates()
          return true
        },
        onInput,
        onLeave: (id) => {
          if (id === leadId()) presses.reset() // the new lead's held keys are its baseline
          party.leave(id)
          sentLayout.delete(id)
          syncStates()
        },
      },
      peerOptions(import.meta.env),
    )
    code.value = room.code
    roomFailed.value = false
  } catch {
    roomFailed.value = true
    retryTimer = setTimeout(start, ROOM_RETRY_MS)
  }
}

onMounted(() => {
  window.addEventListener('hashchange', applyHash)
  window.addEventListener('keydown', onKey)
  applyHash()
  start()
})
onUnmounted(() => {
  window.removeEventListener('hashchange', applyHash)
  window.removeEventListener('keydown', onKey)
  clearTimeout(retryTimer)
  room?.close()
})
</script>

<template>
  <main class="flex min-h-screen flex-col gap-6 p-6">
    <div
      v-if="roomFailed"
      role="alert"
      class="alert alert-error"
    >
      Can't create room — retrying
    </div>
    <PartyBar
      v-if="code"
      :code="code"
      :members="members"
    />
    <h1 class="text-4xl font-black">
      Couch Games
    </h1>
    <PlayScreen
      v-if="route.name === 'play' && round"
      ref="play"
      :key="round.n"
      :game="round.entry.game"
      :players="round.players"
      @finish="onFinish"
    />
    <ResultsScreen
      v-else-if="route.name === 'results' && last"
      ref="results"
      :results="last.results"
      :players="last.players"
      @again="go({ name: 'play', id: last.id })"
      @library="go({ name: 'library' })"
    />
    <LibraryScreen
      v-else
      ref="library"
      :games="games"
      :party-size="members.length"
      @open="(id) => go({ name: 'play', id })"
    />
  </main>
</template>
