<script setup lang="ts">
import { onMounted, onUnmounted, reactive, ref } from 'vue'
import { PLAYER_COLORS, type TiltRacerInput } from '@couch/shared'
import { createLatches } from '../latch'
import { gravityToRollDeg, rollToSteer } from '../tilt'

const props = defineProps<{ color: string }>()

// Full class names, so Tailwind finds them.
const PLAYER_BG = ['bg-player-0', 'bg-player-1', 'bg-player-2', 'bg-player-3', 'bg-player-4', 'bg-player-5']

/** No accelerometer sample this long after listening: steer with ◀ ▶ instead. */
const SAMPLE_WAIT_MS = 1000
/** Wait after the first sample before taking the phone's roll as straight ahead. */
const SETTLE_MS = 200

type Key = 'gas' | 'brake' | 'item' | 'left' | 'right'
const held = reactive<Record<Key, boolean>>({ gas: false, brake: false, item: false, left: false, right: false })
/** Pointers down on each button, so several fingers work at once. */
const pointers: Record<Key, Set<number>> = {
  gas: new Set(),
  brake: new Set(),
  item: new Set(),
  left: new Set(),
  right: new Set(),
}
const latches = createLatches<'item'>()

const buttonSteer = ref(typeof DeviceMotionEvent === 'undefined')
/** Steering last sent, shown on the meter. */
const steerShown = ref(0)

let roll = 0
let neutral = 0
let haveSample = false
let waiting = false
let touched = false
let wakeLock: WakeLockSentinel | null = null
let fallbackTimer: ReturnType<typeof setTimeout> | undefined

function press(k: Key, e: PointerEvent): void {
  e.preventDefault()
  try {
    ;(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId)
  } catch {
    // capture can fail for synthetic pointers
  }
  pointers[k].add(e.pointerId)
  if (k === 'item' && !held.item) latches.press('item')
  held[k] = true
}
function release(k: Key, e: PointerEvent): void {
  if (pointers[k].delete(e.pointerId)) held[k] = pointers[k].size > 0
}

function screenAngle(): number {
  const a = screen.orientation?.angle ?? 0
  return typeof a === 'number' ? a : 0
}

function onMotion(e: DeviceMotionEvent): void {
  const g = e.accelerationIncludingGravity
  if (!g || g.x == null || g.y == null) return
  roll = gravityToRollDeg(g.x, g.y, screenAngle())
  if (!haveSample) {
    haveSample = true
    clearTimeout(fallbackTimer)
    setTimeout(recenter, SETTLE_MS)
  }
}

function recenter(): void {
  if (haveSample) neutral = roll
}

/** No sample by then: steer with ◀ ▶. */
function waitForSample(): void {
  if (waiting) return
  waiting = true
  fallbackTimer = setTimeout(() => {
    if (!haveSample) buttonSteer.value = true
  }, SAMPLE_WAIT_MS)
}

interface PermissionApi {
  requestPermission?: () => Promise<string>
}
const permissionApi = (): PermissionApi | undefined =>
  typeof DeviceMotionEvent === 'undefined' ? undefined : (DeviceMotionEvent as unknown as PermissionApi)

async function requestWakeLock(): Promise<void> {
  try {
    wakeLock = (await navigator.wakeLock?.request('screen')) ?? null
  } catch {
    wakeLock = null
  }
}

async function goLandscape(): Promise<void> {
  try {
    await document.documentElement.requestFullscreen?.()
  } catch {
    // fullscreen is optional; it only helps Android allow the orientation lock
  }
  try {
    await (screen.orientation as ScreenOrientation & { lock?: (o: string) => Promise<void> }).lock?.('landscape')
  } catch {
    // not supported or not allowed
  }
}

/**
 * Asks for motion where the browser has a prompt (iOS, recent Chromium). Without a tap only a grant counts
 * (anything else is asked again on the first tap); after the tap's answer, no sample means ◀ ▶.
 */
async function askMotion(fromTap: boolean): Promise<void> {
  const api = permissionApi()
  let granted = false
  try {
    granted = (await api?.requestPermission?.()) === 'granted'
  } catch {
    // needs a tap
  }
  if (granted || fromTap) waitForSample()
}

/** Permission prompts need a tap (a pointerup grants user activation; a touch pointerdown does not). */
function firstTouch(): void {
  if (touched) return
  touched = true
  void goLandscape()
  void requestWakeLock()
  if (!waiting) void askMotion(true)
}

function onVisible(): void {
  if (touched && document.visibilityState === 'visible') void requestWakeLock()
}

onMounted(() => {
  document.addEventListener('visibilitychange', onVisible)
  const api = permissionApi()
  if (!api) return
  // Listening is harmless before a grant: samples simply start once motion is allowed.
  window.addEventListener('devicemotion', onMotion)
  if (typeof api.requestPermission !== 'function') waitForSample()
  else void askMotion(false)
})
onUnmounted(() => {
  clearTimeout(fallbackTimer)
  window.removeEventListener('devicemotion', onMotion)
  document.removeEventListener('visibilitychange', onVisible)
  void wakeLock?.release().catch(() => {})
  try {
    screen.orientation?.unlock?.()
  } catch {
    // not locked
  }
})

function currentSteer(): number {
  if (buttonSteer.value) return (held.right ? 1 : 0) - (held.left ? 1 : 0)
  return haveSample ? rollToSteer(roll, neutral) : 0
}

function read(): TiltRacerInput {
  const steer = currentSteer()
  steerShown.value = steer
  return { steer, gas: held.gas, brake: held.brake, item: latches.read('item', held.item) }
}
defineExpose({ read })
</script>

<template>
  <main
    class="flex h-screen touch-none flex-col gap-4 p-4 select-none"
    :class="PLAYER_BG[PLAYER_COLORS.indexOf(props.color)]"
    @pointerup.capture="firstTouch"
    @contextmenu.prevent
  >
    <header class="flex items-center gap-4">
      <input
        type="range"
        class="range flex-1"
        aria-label="Steering"
        min="-1"
        max="1"
        step="0.01"
        :value="steerShown"
        disabled
      >
      <button
        type="button"
        class="btn btn-sm"
        @click="recenter"
      >
        Center
      </button>
    </header>
    <div class="flex flex-1 gap-4">
      <button
        type="button"
        class="btn btn-accent h-full flex-1 text-2xl"
        :class="{ 'btn-active': held.item }"
        @pointerdown="press('item', $event)"
        @pointerup="release('item', $event)"
        @pointercancel="release('item', $event)"
        @lostpointercapture="release('item', $event)"
      >
        ITEM
      </button>
      <div class="flex flex-1 flex-col gap-4">
        <div
          v-if="buttonSteer"
          class="flex flex-1 gap-4"
        >
          <button
            type="button"
            class="btn h-full flex-1 text-2xl"
            :class="{ 'btn-active': held.left }"
            aria-label="Steer left"
            @pointerdown="press('left', $event)"
            @pointerup="release('left', $event)"
            @pointercancel="release('left', $event)"
            @lostpointercapture="release('left', $event)"
          >
            ◀
          </button>
          <button
            type="button"
            class="btn h-full flex-1 text-2xl"
            :class="{ 'btn-active': held.right }"
            aria-label="Steer right"
            @pointerdown="press('right', $event)"
            @pointerup="release('right', $event)"
            @pointercancel="release('right', $event)"
            @lostpointercapture="release('right', $event)"
          >
            ▶
          </button>
        </div>
        <button
          type="button"
          class="btn btn-error h-full flex-1 text-2xl"
          :class="{ 'btn-active': held.brake }"
          @pointerdown="press('brake', $event)"
          @pointerup="release('brake', $event)"
          @pointercancel="release('brake', $event)"
          @lostpointercapture="release('brake', $event)"
        >
          BRAKE
        </button>
      </div>
      <button
        type="button"
        class="btn btn-primary h-full flex-1 text-2xl"
        :class="{ 'btn-active': held.gas }"
        @pointerdown="press('gas', $event)"
        @pointerup="release('gas', $event)"
        @pointercancel="release('gas', $event)"
        @lostpointercapture="release('gas', $event)"
      >
        GAS
      </button>
    </div>
  </main>
</template>
