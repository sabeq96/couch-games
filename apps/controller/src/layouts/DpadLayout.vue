<script setup lang="ts">
import type { DpadInput } from '@couch/shared'
import { createLatches } from '../latch'

defineProps<{ color: string }>()

type Key = keyof DpadInput
const held: DpadInput = { up: false, down: false, left: false, right: false, a: false, b: false }
const latches = createLatches<Key>()

function down(k: Key): void {
  held[k] = true
  latches.press(k)
}
function up(k: Key): void {
  held[k] = false
}

function read(): DpadInput {
  return {
    up: latches.read('up', held.up),
    down: latches.read('down', held.down),
    left: latches.read('left', held.left),
    right: latches.read('right', held.right),
    a: latches.read('a', held.a),
    b: latches.read('b', held.b),
  }
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
  <main class="flex min-h-screen touch-none items-center justify-around gap-6 p-6 select-none">
    <div class="grid grid-cols-3 grid-rows-3 gap-2">
      <button
        v-for="a in arrows"
        :key="a.key"
        type="button"
        class="btn btn-square btn-lg"
        :class="a.cell"
        :aria-label="a.label"
        @pointerdown="down(a.key)"
        @pointerup="up(a.key)"
        @pointerleave="up(a.key)"
        @pointercancel="up(a.key)"
      >
        {{ a.text }}
      </button>
    </div>
    <div class="flex gap-4">
      <button
        type="button"
        class="btn btn-circle btn-lg btn-secondary"
        @pointerdown="down('b')"
        @pointerup="up('b')"
        @pointerleave="up('b')"
        @pointercancel="up('b')"
      >
        B
      </button>
      <button
        type="button"
        class="btn btn-circle btn-lg btn-primary"
        @pointerdown="down('a')"
        @pointerup="up('a')"
        @pointerleave="up('a')"
        @pointercancel="up('a')"
      >
        A
      </button>
    </div>
  </main>
</template>
