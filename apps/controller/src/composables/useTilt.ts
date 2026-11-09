import { onMounted, onUnmounted } from 'vue'
import { gravityToRollDeg, rollToSteer } from '../tilt'

/** Steering from the phone's roll. Motion access is granted before the layout shows (see permissions.ts). */
export function useTilt() {
  let roll = 0
  let neutral = 0

  function onMotion(e: DeviceMotionEvent): void {
    const g = e.accelerationIncludingGravity
    if (g?.x == null || g.y == null) return
    roll = gravityToRollDeg(g.x, g.y, screen.orientation?.angle ?? 0)
  }

  onMounted(() => window.addEventListener('devicemotion', onMotion))
  onUnmounted(() => window.removeEventListener('devicemotion', onMotion))

  return {
    steer: (): number => rollToSteer(roll, neutral),
    /** Takes the current tilt as straight ahead. */
    recenter: (): void => {
      neutral = roll
    },
  }
}
