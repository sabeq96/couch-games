<script setup lang="ts">
import { onMounted, onUnmounted, useTemplateRef } from 'vue'
import { useRouter } from 'vue-router'
import type { RoundHandle } from '@couch/shared'
import { useCouchContext, useRoundInput } from '../couchContext'

const couch = useCouchContext()
const router = useRouter()
const el = useTemplateRef<HTMLElement>('el')

let handle: RoundHandle | null = null
let left = false

/** Destroys the round at most once: on finish or when the screen goes away, whichever comes first. */
function end(): boolean {
  const h = handle
  handle = null
  h?.destroy()
  return h !== null
}

useRoundInput({ input: (slot, input) => handle?.input(slot, input) })

onMounted(async () => {
  const round = couch.round.value
  if (!round) return // unknown game: nothing to start
  const mod = await round.entry.game.load()
  if (left || !el.value) return // left before the game finished loading
  handle = mod.start({
    el: el.value,
    players: round.players,
    finish: (results) => {
      if (!end()) return
      couch.finish(results)
      void router.replace({ name: 'results', params: { id: round.entry.id } })
    },
  })
})
onUnmounted(() => {
  left = true
  end()
})
</script>

<template>
  <div
    ref="el"
    class="fixed inset-0"
  />
</template>
