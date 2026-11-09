<script setup lang="ts">
import { computed, toRef } from 'vue'
import type { Player } from '@couch/shared'
import { useJoinLink } from '../composables/useJoinLink'
import { playerBg } from '../playerBg'
import { seatsOf } from '../slots'

const props = defineProps<{ code: string; members: readonly Player[]; compact?: boolean }>()
const { url, qr } = useJoinLink(toRef(props, 'code'))
const seats = computed(() => seatsOf(props.members))
</script>

<template>
  <!-- During a round: a small chip over the game with the code and one small square per slot. -->
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
        v-for="s in seats"
        :key="s.slot"
        class="mask size-4 mask-squircle"
        :class="s.player ? playerBg(s.slot) : 'bg-base-content/15'"
        :title="s.player?.name ?? 'free'"
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
      <ul
        class="ml-auto flex flex-wrap gap-3"
        aria-label="Players"
      >
        <li
          v-for="s in seats"
          :key="s.slot"
          class="card relative size-24 items-center justify-center p-2 text-center"
          :class="s.player ? playerBg(s.slot) : 'card-border border-dashed border-base-content/25'"
        >
          <span
            v-if="s.lead"
            class="absolute top-1 left-2 text-sm"
            title="Lead"
          >★</span>
          <span
            v-if="s.player"
            class="line-clamp-2 text-lg/tight font-black break-all"
          >{{ s.player.name }}</span>
          <span
            v-else
            class="text-sm font-bold text-base-content/40"
          >free</span>
        </li>
      </ul>
    </div>
  </section>
</template>
