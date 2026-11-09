import { inject, onMounted, onUnmounted, type InjectionKey } from 'vue'
import type { Couch, MenuSink, RoundSink } from './composables/useCouch'

export const COUCH: InjectionKey<Couch> = Symbol('couch')

/** The shell's party and round state, provided by App.vue. */
export function useCouchContext(): Couch {
  const couch = inject(COUCH)
  if (!couch) throw new Error('useCouchContext() outside App')
  return couch
}

/** While mounted, the lead's d-pad presses go to `menu`. */
export function useMenu(menu: MenuSink): void {
  const couch = useCouchContext()
  onMounted(() => couch.setMenu(menu))
  onUnmounted(() => couch.setMenu(null))
}

/** While mounted, roster input goes to `sink`. */
export function useRoundInput(sink: RoundSink): void {
  const couch = useCouchContext()
  onMounted(() => couch.setRound(sink))
  onUnmounted(() => couch.setRound(null))
}
