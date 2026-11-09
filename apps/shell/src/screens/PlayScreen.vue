<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue'
import type { Game, LayoutId, LayoutInputs, Player, Result, RoundHandle } from '@couch/shared'

const props = defineProps<{ game: Game; players: readonly Player[] }>()
const emit = defineEmits<{ finish: [results: Result[]] }>()

const el = ref<HTMLElement | null>(null)
let handle: RoundHandle | null = null
let left = false

/** Destroys the round at most once: on finish or when the screen goes away, whichever comes first. */
function end(): boolean {
  const h = handle
  handle = null
  h?.destroy()
  return h !== null
}

onMounted(async () => {
  const mod = await props.game.load()
  if (left || !el.value) return // left before the game finished loading
  handle = mod.start({
    el: el.value,
    players: props.players,
    finish: (results) => {
      if (end()) emit('finish', results)
    },
  })
})
onUnmounted(() => {
  left = true
  end()
})

defineExpose({ input: (slot: number, input: LayoutInputs[LayoutId]) => handle?.input(slot, input) })
</script>

<template>
  <div
    ref="el"
    class="fixed inset-0"
  />
</template>
