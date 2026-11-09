import type { Route } from './layoutFor'

const ROUTE = /^#\/(play|results)\/([^/]+)$/

export function parseHash(hash: string): Route {
  const m = ROUTE.exec(hash)
  if (!m) return { name: 'library' }
  return { name: m[1] as 'play' | 'results', id: decodeURIComponent(m[2]) }
}

export function hashFor(route: Route): string {
  return route.name === 'library' ? '#/' : `#/${route.name}/${encodeURIComponent(route.id)}`
}
