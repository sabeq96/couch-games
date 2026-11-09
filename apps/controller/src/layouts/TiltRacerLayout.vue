<script setup lang="ts">
import { ref, toRef } from 'vue'
import type { TiltRacerInput } from '@couch/shared'
import { useButtons } from '../composables/useButtons'
import { usePlayerBg } from '../composables/usePlayerBg'
import { useTilt } from '../composables/useTilt'
import { useWakeLock } from '../composables/useWakeLock'

const props = defineProps<{ color: string }>()

const bg = usePlayerBg(toRef(props, 'color'))
const buttons = useButtons(['gas', 'brake', 'item'] as const)
const tilt = useTilt()
useWakeLock()

/** Steering last sent, shown on the meter. */
const steerShown = ref(0)

function read(): TiltRacerInput {
  steerShown.value = tilt.steer()
  return { steer: steerShown.value, gas: buttons.held.gas, brake: buttons.held.brake, item: buttons.read('item') }
}
defineExpose({ read })
</script>

<template>
  <main
    class="flex h-screen touch-none flex-col gap-4 p-4 select-none"
    :class="bg"
    @contextmenu.prevent
  >
    <header class="flex items-center gap-4">
      <input
        type="range"
        class="range flex-1"
        aria-label="Steering"
        min="-1"
        max="1"
        step="0.01"
        :value="steerShown"
        disabled
      >
      <button
        type="button"
        class="btn btn-sm"
        @click="tilt.recenter"
      >
        Center
      </button>
    </header>
    <div class="flex flex-1 gap-4">
      <button
        type="button"
        class="btn btn-accent h-full flex-1 text-2xl"
        :class="{ 'btn-active': buttons.held.item }"
        v-on="buttons.on('item')"
      >
        ITEM
      </button>
      <button
        type="button"
        class="btn btn-neutral h-full flex-1 text-2xl"
        :class="{ 'btn-active': buttons.held.brake }"
        v-on="buttons.on('brake')"
      >
        BRAKE
      </button>
      <button
        type="button"
        class="btn btn-primary h-full flex-1 text-2xl"
        :class="{ 'btn-active': buttons.held.gas }"
        v-on="buttons.on('gas')"
      >
        GAS
      </button>
    </div>
  </main>
</template>
