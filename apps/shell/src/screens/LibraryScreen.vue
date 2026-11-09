<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { games, playersLabel, type GameEntry } from '../games'
import { move } from '../grid'
import type { Key } from '../presses'
import { useCouchContext, useMenu } from '../couchContext'

const COLS = 3

const { members } = useCouchContext()
const router = useRouter()
const selected = ref(0)

const enabled = (e: GameEntry): boolean => members.value.length >= e.game.players.min

function open(e: GameEntry | undefined): void {
  if (e && enabled(e)) void router.push({ name: 'play', params: { id: e.id } })
}

/** The lead's d-pad: arrows move the selection, A opens it. */
useMenu({
  press(key: Key): void {
    if (key === 'a') open(games[selected.value])
    else if (key !== 'b') selected.value = move(selected.value, key, games.length, COLS)
  },
})
</script>

<template>
  <section class="grid grid-cols-3 gap-6">
    <button
      v-for="(e, i) in games"
      :key="e.id"
      type="button"
      class="card bg-base-200 text-left transition duration-150"
      :class="[
        i === selected ? 'scale-105 ring-8 ring-primary' : '',
        enabled(e) ? '' : 'opacity-50',
      ]"
      :aria-current="i === selected"
      :disabled="!enabled(e)"
      @click="open(e)"
    >
      <figure>
        <img
          :src="e.game.cover"
          alt=""
          class="aspect-video w-full object-cover"
        >
      </figure>
      <div class="card-body">
        <h2 class="card-title">
          {{ e.game.title }}
        </h2>
        <p
          class="text-sm font-bold text-base-content/60"
          data-testid="players"
        >
          👥 {{ playersLabel(e.game.players) }}
        </p>
      </div>
    </button>
  </section>
  <!-- How the lead drives the library from the phone. -->
  <p
    class="card fixed bottom-6 left-1/2 -translate-x-1/2 flex-row items-center gap-2 bg-base-200 px-4 py-2 text-sm font-bold"
    data-testid="library-hint"
  >
    <kbd class="kbd">▲</kbd><kbd class="kbd">▼</kbd><kbd class="kbd">◀</kbd><kbd class="kbd">▶</kbd> move
    <kbd class="kbd ml-4">A</kbd> select
  </p>
</template>
