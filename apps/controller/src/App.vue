<script setup lang="ts">
import { computed, ref } from 'vue'
import MessageScreen from './MessageScreen.vue'
import { layouts } from './layouts'
import { usePermissions } from './composables/usePermissions'
import { usePortrait } from './composables/usePortrait'
import { useSession } from './composables/useSession'

const layoutRef = ref<{ read(): object | null } | null>(null)
const { screen, joinText, code, name, layout, color, join, tryAgain } = useSession(() => layoutRef.value?.read() ?? null)

const needs = computed(() => layouts[layout.value].needs)
const permissions = usePermissions(needs)
const portrait = usePortrait()
const turnSideways = computed(() => needs.value.includes('landscape') && portrait.value)
</script>

<template>
  <template v-if="screen === 'layout'">
    <MessageScreen
      v-if="permissions.refused.value"
      role="alert"
      :text="permissions.refusedText.value"
      button="Try again"
      @button="permissions.allow"
    />
    <MessageScreen
      v-else-if="permissions.missing.value.length"
      :text="permissions.askText.value"
      button="Allow"
      @button="permissions.allow"
    />
    <MessageScreen
      v-else-if="turnSideways"
      text="Turn your phone sideways"
    />
    <component
      :is="layouts[layout].component"
      v-else
      :key="layout"
      ref="layoutRef"
      :color="color"
    />
  </template>
  <MessageScreen
    v-else-if="screen === 'join'"
    :text="joinText"
    input="join"
    :code="code"
    :name="name"
    @submit="join"
  />
  <MessageScreen
    v-else-if="screen === 'connecting'"
    text="Connecting…"
  />
  <MessageScreen
    v-else
    text="Unable to join"
    button="Try again"
    @button="tryAgain"
  />
</template>
