import { onMounted, onUnmounted } from 'vue'
import type { Key } from '../presses'

/** Host keyboard: arrows and Enter/Backspace act like the lead's d-pad and A/B. */
const KEYS: Record<string, Key> = {
  ArrowUp: 'up',
  ArrowDown: 'down',
  ArrowLeft: 'left',
  ArrowRight: 'right',
  Enter: 'a',
  Backspace: 'b',
}

/** `escape` on Escape; `press` for d-pad keys (ignored while `playing`, and for key repeat). */
export function useHostKeys(opts: { playing: () => boolean; escape: () => void; press: (k: Key) => void }) {
  function onKey(e: KeyboardEvent): void {
    if (e.key === 'Escape') return opts.escape()
    const key = KEYS[e.key]
    if (!key || e.repeat || opts.playing()) return
    e.preventDefault() // Enter must not also click a focused button
    opts.press(key)
  }
  onMounted(() => window.addEventListener('keydown', onKey))
  onUnmounted(() => window.removeEventListener('keydown', onKey))
}
