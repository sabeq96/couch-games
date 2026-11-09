import { onMounted, onUnmounted, ref } from 'vue'

/** True while the phone is held upright. */
export function usePortrait() {
  const query = matchMedia('(orientation: portrait)')
  const portrait = ref(query.matches)
  const update = (): void => {
    portrait.value = query.matches
  }
  onMounted(() => query.addEventListener('change', update))
  onUnmounted(() => query.removeEventListener('change', update))
  return portrait
}
