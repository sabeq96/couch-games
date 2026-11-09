<script setup lang="ts">
import { toRef } from 'vue'
import MessageScreen from '../MessageScreen.vue'
import { usePlayerBg } from '../composables/usePlayerBg'
import { useTilt } from '../composables/useTilt'

const props = defineProps<{ color: string }>()
const bg = usePlayerBg(toRef(props, 'color'))
const tilt = useTilt()

defineExpose({ read: (): null => null })
</script>

<template>
  <MessageScreen
    :class="bg"
    text="Look at the screen"
    button="Center"
    @button="tilt.recenter"
  />
</template>
