<script setup lang="ts">
import { ref } from 'vue'

/** One screen for every phone message: text, plus the join form or a button, and an optional small hint. */
const props = defineProps<{
  text: string
  input?: 'join'
  button?: string
  code?: string
  name?: string
  hint?: string
}>()
const emit = defineEmits<{ submit: [code: string, name: string]; button: [] }>()

const code = ref(props.code ?? '')
const name = ref(props.name ?? '')
</script>

<template>
  <main class="flex min-h-dvh flex-col items-center justify-center gap-6 p-6 text-center">
    <p class="text-2xl font-black">
      {{ text }}
    </p>
    <form
      v-if="input === 'join'"
      class="flex w-full max-w-xs flex-col gap-3"
      @submit.prevent="emit('submit', code.trim().toUpperCase(), name.trim())"
    >
      <input
        v-model="code"
        class="input w-full uppercase"
        aria-label="Room code"
        placeholder="Room code"
        maxlength="4"
        autocomplete="off"
      >
      <input
        v-model="name"
        class="input w-full"
        aria-label="Your name"
        placeholder="Your name"
        maxlength="12"
      >
      <button
        type="submit"
        class="btn btn-primary"
      >
        Join
      </button>
    </form>
    <button
      v-if="button"
      type="button"
      class="btn btn-primary"
      @click="emit('button')"
    >
      {{ button }}
    </button>
    <p
      v-if="hint"
      class="text-sm opacity-70"
    >
      {{ hint }}
    </p>
  </main>
</template>
