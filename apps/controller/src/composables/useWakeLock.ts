import { onMounted, onUnmounted } from 'vue'

/** Keeps the screen on while the layout shows; the browser drops the lock when the page is hidden, so it is taken again. */
export function useWakeLock() {
  let lock: WakeLockSentinel | null = null

  function take(): void {
    if (document.visibilityState !== 'visible') return
    navigator.wakeLock?.request('screen').then(
      (l) => (lock = l),
      () => (lock = null),
    )
  }

  onMounted(() => {
    take()
    document.addEventListener('visibilitychange', take)
  })
  onUnmounted(() => {
    document.removeEventListener('visibilitychange', take)
    void lock?.release()
  })
}
