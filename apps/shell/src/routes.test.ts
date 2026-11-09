import { expect, test } from 'vitest'
import { createMemoryHistory, createRouter } from 'vue-router'
import { routeOf, routes } from './routes'

async function at(path: string) {
  const r = createRouter({ history: createMemoryHistory(), routes })
  await r.push(path)
  return { name: r.currentRoute.value.name, route: routeOf(r.currentRoute.value) }
}

test('the three routes', async () => {
  expect(await at('/')).toEqual({ name: 'library', route: { name: 'library' } })
  expect(await at('/play/x')).toEqual({ name: 'play', route: { name: 'play', id: 'x' } })
  expect(await at('/results/x')).toEqual({ name: 'results', route: { name: 'results', id: 'x' } })
})

test('anything else is not found, and counts as the library for phones', async () => {
  for (const p of ['/nope', '/play', '/play/x/y']) {
    expect(await at(p)).toEqual({ name: 'not-found', route: { name: 'library' } })
  }
})
