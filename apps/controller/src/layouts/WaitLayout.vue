<script setup lang="ts">
import { toRef } from 'vue'
import MessageScreen from '../MessageScreen.vue'
import { usePlayerBg } from '../composables/usePlayerBg'

const props = defineProps<{ color: string }>()
const bg = usePlayerBg(toRef(props, 'color'))

defineExpose({ read: (): null => null })
</script>

<template>
  <MessageScreen
    :class="bg"
    text="Look at the screen"
  />
</template>
