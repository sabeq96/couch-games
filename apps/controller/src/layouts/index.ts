import type { Component } from 'vue'
import type { LayoutId } from '@couch/shared'
import type { Capability } from '../permissions'
import DpadLayout from './DpadLayout.vue'
import TiltRacerLayout from './TiltRacerLayout.vue'
import WaitLayout from './WaitLayout.vue'

/**
 * Every layout takes `{ color }` and exposes `read(): object | null` (the input to send, or nothing). `needs` are
 * the device capabilities it uses: the controller asks for them on the standard permission screen first.
 */
export const layouts: Record<LayoutId, { component: Component; needs: readonly Capability[] }> = {
  wait: { component: WaitLayout, needs: [] },
  dpad: { component: DpadLayout, needs: [] },
  'tilt-racer': { component: TiltRacerLayout, needs: ['motion', 'landscape'] },
}
