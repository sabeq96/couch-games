<script setup lang="ts">
import { PLAYER_COLORS } from '@couch/shared'
import MessageScreen from '../MessageScreen.vue'

const props = defineProps<{ color: string }>()

// Full class names, so Tailwind finds them.
const PLAYER_BG = ['bg-player-0', 'bg-player-1', 'bg-player-2', 'bg-player-3', 'bg-player-4', 'bg-player-5']

defineExpose({ read: (): null => null })
</script>

<template>
  <MessageScreen
    :class="PLAYER_BG[PLAYER_COLORS.indexOf(props.color)]"
    text="Look at the screen"
  />
</template>
