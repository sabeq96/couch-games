import { onMounted, onUnmounted } from 'vue'
import type { Route } from '../layoutFor'
import { hashFor, parseHash } from '../router'

/**
 * The hash is the route: every navigation, Escape and browser back come through `onChange`. Only library → play
 * adds a history entry (`go(next)`); every other move replaces it (`go(next, true)`), so browser back always lands
 * on the library without starting a round.
 */
export function useHashRoute(onChange: (next: Route) => void) {
  const apply = (): void => onChange(parseHash(location.hash))

  onMounted(() => {
    window.addEventListener('hashchange', apply)
    apply()
  })
  onUnmounted(() => window.removeEventListener('hashchange', apply))

  return {
    go(next: Route, replace = false): void {
      if (replace) location.replace(hashFor(next))
      else location.hash = hashFor(next)
    },
  }
}
