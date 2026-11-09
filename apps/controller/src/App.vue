<script setup lang="ts">
import { ref } from 'vue'
import { LAYOUT_IDS, PLAYER_COLORS, peerOptions, type LayoutId } from '@couch/shared'
import MessageScreen from './MessageScreen.vue'
import { layouts } from './layouts'
import { connect, type Link } from './connection'
import { startSender } from './sender'

const JOIN_TEXT = 'Couch Games'
const HINT = 'Type the 4 letters from the screen'

const params = new URLSearchParams(location.search)
const demoParam = params.get('demo') as LayoutId | null
const demo = demoParam && LAYOUT_IDS.includes(demoParam) ? demoParam : null

const screen = ref<'join' | 'connecting' | 'layout' | 'failed'>(demo ? 'layout' : 'join')
const joinText = ref(JOIN_TEXT)
const code = ref(params.get('room') ?? '')
const name = ref('')
const layout = ref<LayoutId>(demo ?? 'wait')
const color = ref(PLAYER_COLORS[0])
const layoutRef = ref<{ read(): object | null } | null>(null)

let link: Link | null = null
let stopSender: (() => void) | null = null

function leave(): void {
  stopSender?.()
  stopSender = null
  link?.close()
  link = null
}

function join(c: string, n: string): void {
  code.value = c
  name.value = n
  if (!c) {
    joinText.value = HINT
    return
  }
  screen.value = 'connecting'
  const l = connect(
    c,
    n,
    (s) => {
      layout.value = s.layout
      color.value = s.color
    },
    (status) => {
      if (status === 'joined') {
        screen.value = 'layout'
        stopSender = startSender(() => layoutRef.value?.read() ?? null, (m) => l.send(m))
      } else if (status === 'failed') {
        leave()
        screen.value = 'failed'
      }
    },
    peerOptions(import.meta.env),
  )
  link = l
}

function tryAgain(): void {
  joinText.value = JOIN_TEXT
  screen.value = 'join'
}

// Closing the page tears the data channel down silently; close it ourselves so the shell sees us leave.
window.addEventListener('pagehide', leave)
</script>

<template>
  <component
    :is="layouts[layout]"
    v-if="screen === 'layout'"
    :key="layout"
    ref="layoutRef"
    :color="color"
  />
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
