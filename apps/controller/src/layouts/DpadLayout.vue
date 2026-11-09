<script setup lang="ts">
import { toRef } from 'vue'
import type { DpadInput } from '@couch/shared'
import { useButtons } from '../composables/useButtons'
import { usePlayerBg } from '../composables/usePlayerBg'

const props = defineProps<{ color: string }>()

type Key = keyof DpadInput
const KEYS = ['up', 'down', 'left', 'right', 'a', 'b'] as const satisfies readonly Key[]

const bg = usePlayerBg(toRef(props, 'color'))
const buttons = useButtons(KEYS)

function read(): DpadInput {
  return Object.fromEntries(KEYS.map((k) => [k, buttons.read(k)])) as unknown as DpadInput
}
defineExpose({ read })

const arrows: { key: Key; label: string; text: string; cell: string }[] = [
  { key: 'up', label: 'Up', text: '▲', cell: 'col-start-2 row-start-1' },
  { key: 'left', label: 'Left', text: '◀', cell: 'col-start-1 row-start-2' },
  { key: 'right', label: 'Right', text: '▶', cell: 'col-start-3 row-start-2' },
  { key: 'down', label: 'Down', text: '▼', cell: 'col-start-2 row-start-3' },
]
</script>

<template>
  <main
    class="flex min-h-screen touch-none items-center justify-around gap-6 p-6 select-none"
    :class="bg"
  >
    <div class="grid grid-cols-3 grid-rows-3 gap-2">
      <button
        v-for="a in arrows"
        :key="a.key"
        type="button"
        class="btn btn-square btn-lg"
        :class="a.cell"
        :aria-label="a.label"
        v-on="buttons.on(a.key)"
      >
        {{ a.text }}
      </button>
    </div>
    <div class="flex gap-4">
      <button
        type="button"
        class="btn btn-circle btn-lg btn-secondary"
        v-on="buttons.on('b')"
      >
        B
      </button>
      <button
        type="button"
        class="btn btn-circle btn-lg btn-primary"
        v-on="buttons.on('a')"
      >
        A
      </button>
    </div>
  </main>
</template>
