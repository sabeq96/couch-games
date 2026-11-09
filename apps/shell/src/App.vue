<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue'
import { peerOptions, type Player } from '@couch/shared'
import PartyBar from './components/PartyBar.vue'
import { Party } from './party'
import { layoutFor, type Route } from './layoutFor'
import { openRoom, type Room } from './room/host'

const ROOM_RETRY_MS = 5000

const party = new Party()
const route: Route = { name: 'library' }
const members = ref<readonly Player[]>([])
const code = ref('')
const roomFailed = ref(false)
let room: Room | null = null
let retryTimer: ReturnType<typeof setTimeout> | undefined

/** Tells every phone its layout and colour for the current screen and party. */
function syncStates(): void {
  members.value = party.members()
  for (const p of party.members()) {
    const id = party.idOf(p.slot)
    if (id) room?.send(id, { t: 'state', layout: layoutFor(route, p, party.lead(), null), color: p.color })
  }
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
        onInput: () => {},
        onLeave: (id) => {
          party.leave(id)
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

onMounted(start)
onUnmounted(() => {
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
  </main>
</template>
