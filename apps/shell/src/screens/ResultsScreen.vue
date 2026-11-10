<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import type { Key } from '../presses'
import { playerBg } from '../playerBg'
import { splitPodium } from '../podium'
import { useCouchContext, useMenu } from '../couchContext'
import NotFoundScreen from './NotFoundScreen.vue'

const ORDINALS = ['1st', '2nd', '3rd', '4th', '5th', '6th']

const props = defineProps<{ id: string }>()
const { last } = useCouchContext()
const router = useRouter()

/** Results of this game's last round, or nothing (a stale or typed link). */
const shown = computed(() => (last.value?.id === props.id ? last.value : null))
const rows = computed(() =>
  [...(shown.value?.results ?? [])]
    .sort((a, b) => a.place - b.place)
    .map((r) => ({ ...r, name: shown.value?.players.find((p) => p.slot === r.slot)?.name ?? '' })),
)

/**
 * Places 1–3 on the podium, each on the step for its place, drawn 2nd–1st–3rd; a step nobody earned stays as an empty
 * placeholder, so every step keeps its spot. Everyone else in a list below.
 */
const STEPS = [
  { height: 'h-36', bg: 'bg-secondary' },
  { height: 'h-24', bg: 'bg-base-300' },
  { height: 'h-16', bg: 'bg-player-5' },
]
const STAND_ORDER = ['order-2', 'order-1', 'order-3']
const split = computed(() => splitPodium(rows.value))
const steps = computed(() => [1, 2, 3].map((place) => ({ place, row: split.value.podium.find((r) => r.place === place) })))
const rest = computed(() => split.value.rest)
const ordinal = (place: number): string => ORDINALS[place - 1] ?? `${place}th`

const again = () => void router.replace({ name: 'play', params: { id: props.id } })
const library = () => void router.replace({ name: 'library' })

/** The lead's dpad: A plays again, B goes back to the library. */
useMenu({
  press(key: Key): void {
    if (key === 'a') again()
    else if (key === 'b') library()
  },
})
</script>

<template>
  <NotFoundScreen v-if="!shown" />
  <section
    v-else
    class="flex flex-col gap-6"
  >
    <ol
      class="flex items-end justify-center gap-4"
      aria-label="Podium"
    >
      <li
        v-for="s in steps"
        :key="s.place"
        class="flex w-44 flex-col items-center gap-2"
        :class="STAND_ORDER[s.place - 1]"
        :aria-label="s.row ? `${ordinal(s.place)} ${s.row.name}` : undefined"
        :aria-hidden="s.row ? undefined : 'true'"
      >
        <span
          class="card size-24 items-center justify-center p-2 text-center text-xl/tight font-black break-all"
          :class="s.row ? playerBg(s.row.slot) : 'invisible'"
        >{{ s.row?.name }}</span>
        <span
          class="card w-full items-center pt-2 text-3xl font-black"
          :class="[STEPS[s.place - 1].height, STEPS[s.place - 1].bg, { 'opacity-40': !s.row }]"
        >{{ s.row ? ordinal(s.place) : '' }}</span>
      </li>
    </ol>
    <ol
      v-if="rest.length"
      class="mx-auto flex w-full max-w-md flex-col gap-2"
      aria-label="Others"
    >
      <li
        v-for="r in rest"
        :key="r.slot"
        class="card flex-row items-center gap-3 bg-base-200 p-2 text-xl font-black"
        :aria-label="`${ordinal(r.place)} ${r.name}`"
      >
        <span class="w-12 text-right">{{ ordinal(r.place) }}</span>
        <span
          class="mask size-6 mask-squircle"
          :class="playerBg(r.slot)"
        />
        <span>{{ r.name }}</span>
      </li>
    </ol>
    <div class="flex justify-center gap-4">
      <button
        type="button"
        class="btn btn-primary"
        @click="again"
      >
        Play again <kbd
          class="kbd kbd-sm"
          aria-hidden="true"
        >A</kbd>
      </button>
      <button
        type="button"
        class="btn"
        @click="library"
      >
        Library <kbd
          class="kbd kbd-sm"
          aria-hidden="true"
        >B</kbd>
      </button>
    </div>
  </section>
</template>
