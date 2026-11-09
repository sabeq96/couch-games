import { expect, test } from 'vitest'
import { hashFor, parseHash } from './router'

test('parses the three routes', () => {
  expect(parseHash('')).toEqual({ name: 'library' })
  expect(parseHash('#/')).toEqual({ name: 'library' })
  expect(parseHash('#/play/x')).toEqual({ name: 'play', id: 'x' })
  expect(parseHash('#/results/x')).toEqual({ name: 'results', id: 'x' })
})

test('anything else is the library', () => {
  expect(parseHash('#/nope')).toEqual({ name: 'library' })
  expect(parseHash('#/play/')).toEqual({ name: 'library' })
  expect(parseHash('#/play/x/y')).toEqual({ name: 'library' })
})

test('hashFor round-trips', () => {
  for (const h of ['#/', '#/play/x', '#/results/x']) expect(hashFor(parseHash(h))).toBe(h)
})
