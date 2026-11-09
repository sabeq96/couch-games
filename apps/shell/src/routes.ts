import type { RouteLocationNormalizedLoaded } from 'vue-router'
import type { Route } from './layoutFor'
import LibraryScreen from './screens/LibraryScreen.vue'
import NotFoundScreen from './screens/NotFoundScreen.vue'
import PlayScreen from './screens/PlayScreen.vue'
import ResultsScreen from './screens/ResultsScreen.vue'

/**
 * `#/`, `#/play/<id>`, `#/results/<id>`. Only library → play pushes a history entry; every other move replaces it,
 * so browser back always lands on the library without starting a round.
 */
export const routes = [
  { path: '/', name: 'library', component: LibraryScreen },
  { path: '/play/:id', name: 'play', component: PlayScreen, props: true },
  { path: '/results/:id', name: 'results', component: ResultsScreen, props: true },
  { path: '/:pathMatch(.*)*', name: 'not-found', component: NotFoundScreen },
]

/** The shell's view of a route, for layouts and rounds. Anything unknown counts as the library. */
export function routeOf(to: Pick<RouteLocationNormalizedLoaded, 'name' | 'params'>): Route {
  const id = typeof to.params.id === 'string' ? to.params.id : ''
  if (to.name === 'play') return { name: 'play', id }
  if (to.name === 'results') return { name: 'results', id }
  return { name: 'library' }
}
