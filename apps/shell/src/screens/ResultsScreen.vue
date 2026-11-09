<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import type { Key } from '../presses'
import { playerBg } from '../playerBg'
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
      class="flex flex-col gap-3"
      aria-label="Results"
    >
      <li
        v-for="r in rows"
        :key="r.slot"
        class="flex items-center gap-3 text-2xl font-black"
      >
        {{ ORDINALS[r.place - 1] ?? `${r.place}th` }} <span
          class="badge badge-lg"
          :class="playerBg(r.slot)"
        >{{ r.name }}</span>
      </li>
    </ol>
    <div class="flex gap-4">
      <button
        type="button"
        class="btn btn-primary"
        @click="again"
      >
        Play again
      </button>
      <button
        type="button"
        class="btn"
        @click="library"
      >
        Library
      </button>
    </div>
  </section>
</template>
