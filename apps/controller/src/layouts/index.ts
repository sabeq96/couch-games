import type { Component } from 'vue'
import type { LayoutId } from '@couch/shared'
import DpadLayout from './DpadLayout.vue'
import WaitLayout from './WaitLayout.vue'

/** Every layout takes `{ color }` and exposes `read(): object | null` (the input to send, or nothing). */
export const layouts: Record<LayoutId, Component> = {
  wait: WaitLayout,
  dpad: DpadLayout,
  'tilt-racer': WaitLayout, // placeholder until the tilt-racer layout lands
}
