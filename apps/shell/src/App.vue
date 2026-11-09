<script setup lang="ts">
import { useTemplateRef } from 'vue'
import type { Result } from '@couch/shared'
import PartyBar from './components/PartyBar.vue'
import LibraryScreen from './screens/LibraryScreen.vue'
import PlayScreen from './screens/PlayScreen.vue'
import ResultsScreen from './screens/ResultsScreen.vue'
import { games } from './games'
import { useCouch } from './composables/useCouch'
import { useHashRoute } from './composables/useHashRoute'
import { useHostKeys } from './composables/useHostKeys'
import { useRoom } from './composables/useRoom'

const library = useTemplateRef<InstanceType<typeof LibraryScreen>>('library')
const play = useTemplateRef<InstanceType<typeof PlayScreen>>('play')
const results = useTemplateRef<InstanceType<typeof ResultsScreen>>('results')

const couch = useCouch({
  send: (id, msg) => room.send(id, msg),
  round: () => play.value,
  menu: () => library.value ?? results.value,
})
const { route, round, last, members } = couch
const room = useRoom(couch.handlers)
const { go } = useHashRoute(couch.enter)
useHostKeys({
  playing: () => route.value.name === 'play',
  escape: () => route.value.name !== 'library' && go({ name: 'library' }, true),
  press: (k) => (library.value ?? results.value)?.press(k),
})

function onFinish(res: Result[]): void {
  couch.finish(res)
  if (round.value) go({ name: 'results', id: round.value.entry.id }, true)
}
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
      @again="go({ name: 'play', id: last.id }, true)"
      @library="go({ name: 'library' })"
    />
    <LibraryScreen
      v-else-if="route.name === 'library'"
      ref="library"
      :games="games"
      :party-size="members.length"
      @open="(id) => go({ name: 'play', id })"
    />
    <p
      v-else
      class="text-2xl"
    >
      Not found
    </p>
  </main>
</template>
