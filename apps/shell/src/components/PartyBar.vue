<script setup lang="ts">
import { ref, watch } from 'vue'
import QRCode from 'qrcode'
import { controllerUrl, type Player } from '@couch/shared'

const props = defineProps<{ code: string; members: readonly Player[] }>()

// Full class names, so Tailwind finds them.
const PLAYER_BG = ['bg-player-0', 'bg-player-1', 'bg-player-2', 'bg-player-3', 'bg-player-4', 'bg-player-5']

const url = ref('')
const qr = ref('')
watch(
  () => props.code,
  async (code) => {
    url.value = controllerUrl(location.origin + import.meta.env.BASE_URL + 'controller/', code)
    qr.value = await QRCode.toDataURL(url.value)
  },
  { immediate: true },
)
</script>

<template>
  <section class="card bg-base-200">
    <div class="card-body flex-row flex-wrap items-center gap-6">
      <img
        v-if="qr"
        :src="qr"
        alt="QR code"
        class="size-32"
      >
      <div class="flex flex-col gap-1">
        <span
          class="text-5xl font-black tracking-widest"
          data-testid="room-code"
        >{{ code }}</span>
        <span class="text-sm">{{ url }}</span>
      </div>
      <ul class="flex flex-wrap gap-2">
        <li
          v-for="(p, i) in members"
          :key="p.slot"
          class="badge badge-lg"
          :class="PLAYER_BG[p.slot]"
        >
          {{ i === 0 ? '★ ' : '' }}{{ p.name }}
        </li>
      </ul>
    </div>
  </section>
</template>
