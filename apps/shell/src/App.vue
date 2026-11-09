<script setup lang="ts">
import { provide, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PartyBar from './components/PartyBar.vue'
import { COUCH } from './couchContext'
import { routeOf } from './routes'
import { useCouch } from './composables/useCouch'
import { useHostKeys } from './composables/useHostKeys'
import { useRoom } from './composables/useRoom'

const route = useRoute()
const router = useRouter()

const couch = useCouch((id, msg) => room.send(id, msg))
provide(COUCH, couch)
const room = useRoom(couch.handlers)
const { members } = couch

// Every navigation (link, d-pad, Escape, browser back) tells the party where we are, before the screen renders.
watch(() => route.fullPath, () => couch.enter(routeOf(route)), { immediate: true })

useHostKeys({
  playing: () => route.name === 'play',
  escape: () => route.name !== 'library' && void router.replace({ name: 'library' }),
  press: couch.press,
})
</script>

<template>
  <main
    class="flex min-h-screen flex-col"
    :class="route.name === 'play' ? '' : 'gap-6 p-6'"
  >
    <div
      v-if="room.failed.value"
      role="alert"
      class="alert alert-error"
    >
      Can't create room
    </div>
    <PartyBar
      v-if="room.code.value"
      :code="room.code.value"
      :members="members"
      :compact="route.name === 'play'"
    />
    <h1
      v-if="route.name !== 'play'"
      class="text-4xl font-black"
    >
      Couch Games
    </h1>
    <RouterView />
  </main>
</template>
