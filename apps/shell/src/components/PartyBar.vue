<script setup lang="ts">
import { ref, watch } from 'vue'
import QRCode from 'qrcode'
import { controllerUrl, type Player } from '@couch/shared'

const props = defineProps<{ code: string; members: readonly Player[]; compact?: boolean }>()

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
  <!-- During a round: a small chip over the game with the code and one dot per player. -->
  <section
    v-if="compact"
    class="card fixed top-2 right-2 z-10 bg-base-200"
  >
    <div class="card-body flex-row items-center gap-2 p-2">
      <span
        class="font-black tracking-widest"
        data-testid="room-code"
      >{{ code }}</span>
      <span
        v-for="p in members"
        :key="p.slot"
        class="badge badge-xs"
        :class="PLAYER_BG[p.slot]"
        :title="p.name"
      />
    </div>
  </section>
  <section
    v-else
    class="card bg-base-200"
  >
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
