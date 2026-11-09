<script setup lang="ts">
import { computed } from 'vue'
import type { Player, Result } from '@couch/shared'
import type { Key } from '../presses'

const ORDINALS = ['1st', '2nd', '3rd', '4th', '5th', '6th']
// Full class names, so Tailwind finds them.
const PLAYER_BG = ['bg-player-0', 'bg-player-1', 'bg-player-2', 'bg-player-3', 'bg-player-4', 'bg-player-5']

const props = defineProps<{ results: readonly Result[]; players: readonly Player[] }>()
const emit = defineEmits<{ again: []; library: [] }>()

const rows = computed(() =>
  [...props.results]
    .sort((a, b) => a.place - b.place)
    .map((r) => ({ ...r, name: props.players.find((p) => p.slot === r.slot)?.name ?? '' })),
)

/** The lead's dpad: A plays again, B goes back to the library. */
function press(key: Key): void {
  if (key === 'a') emit('again')
  else if (key === 'b') emit('library')
}
defineExpose({ press })
</script>

<template>
  <section class="flex flex-col gap-6">
    <ol
      class="flex flex-col gap-3"
      aria-label="Results"
    >
      <li
        v-for="r in rows"
        :key="r.slot"
        class="flex items-center gap-3 text-2xl font-black"
      >
        {{ ORDINALS[r.place - 1] ?? `${r.place}th` }} <span
          class="badge badge-lg"
          :class="PLAYER_BG[r.slot]"
        >{{ r.name }}</span>
      </li>
    </ol>
    <div class="flex gap-4">
      <button
        type="button"
        class="btn btn-primary"
        @click="emit('again')"
      >
        Play again
      </button>
      <button
        type="button"
        class="btn"
        @click="emit('library')"
      >
        Library
      </button>
    </div>
  </section>
</template>
