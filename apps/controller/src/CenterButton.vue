<script setup lang="ts">
import { useTilt } from './composables/useTilt'

/** Takes the current tilt as straight ahead. On every layout, so players can set it before the round starts. */
const tilt = useTilt()
</script>

<template>
  <button
    type="button"
    class="btn btn-sm"
    @click="tilt.recenter"
  >
    Center
  </button>
</template>
