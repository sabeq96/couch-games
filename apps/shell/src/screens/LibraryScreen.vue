<script setup lang="ts">
import { ref } from 'vue'
import type { GameEntry } from '../games'
import { move } from '../grid'
import type { Key } from '../presses'

const COLS = 3

const props = defineProps<{ games: readonly GameEntry[]; partySize: number }>()
const emit = defineEmits<{ open: [id: string] }>()

const selected = ref(0)
const enabled = (e: GameEntry): boolean => props.partySize >= e.game.players.min

function open(e: GameEntry | undefined): void {
  if (e && enabled(e)) emit('open', e.id)
}

/** The lead's dpad: arrows move the selection, A opens it. */
function press(key: Key): void {
  if (key === 'a') open(props.games[selected.value])
  else if (key !== 'b') selected.value = move(selected.value, key, props.games.length, COLS)
}
defineExpose({ press })
</script>

<template>
  <section class="grid grid-cols-3 gap-6">
    <button
      v-for="(e, i) in games"
      :key="e.id"
      type="button"
      class="card text-left"
      :class="[i === selected ? 'card-border bg-base-200' : '', enabled(e) ? '' : 'opacity-50']"
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
      </div>
    </button>
  </section>
</template>
