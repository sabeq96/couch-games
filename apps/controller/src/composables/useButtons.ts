import { reactive } from 'vue'
import { createLatches } from '../latch'

/**
 * Pointer-driven buttons for a layout: several fingers at once, a pointer that slides off releases, and a tap
 * shorter than one send interval is still read once. `on(k)` is spread onto the button with `v-on`.
 */
export function useButtons<K extends string>(keys: readonly K[]) {
  const held = reactive(Object.fromEntries(keys.map((k) => [k, false]))) as Record<K, boolean>
  const pointers = new Map<K, Set<number>>(keys.map((k) => [k, new Set()]))
  const latches = createLatches<K>()

  function down(k: K, e: PointerEvent): void {
    e.preventDefault()
    ;(e.currentTarget as HTMLElement).setPointerCapture?.(e.pointerId)
    if (!held[k]) latches.press(k)
    pointers.get(k)!.add(e.pointerId)
    held[k] = true
  }
  function up(k: K, e: PointerEvent): void {
    const ps = pointers.get(k)!
    if (ps.delete(e.pointerId)) held[k] = ps.size > 0
  }

  return {
    held,
    on: (k: K) => ({
      pointerdown: (e: PointerEvent) => down(k, e),
      pointerup: (e: PointerEvent) => up(k, e),
      pointercancel: (e: PointerEvent) => up(k, e),
      lostpointercapture: (e: PointerEvent) => up(k, e),
    }),
    /** The level now, or true once for a press since the last read. */
    read: (k: K): boolean => latches.read(k, held[k]),
  }
}
