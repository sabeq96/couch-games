import { expect, test } from 'vitest'
import type { Game } from '@couch/shared'
import { gamesFrom } from './games'

const game = (title: string): Game => ({
  title,
  cover: '',
  layout: 'dpad',
  players: { min: 1, max: 2 },
  load: () => Promise.reject(new Error('not loaded in tests')),
})

test('id is the folder name from the glob key', () => {
  const entries = gamesFrom({ '../../../games/racing-carts/index.ts': { default: game('Racing Carts') } })
  expect(entries.map((e) => e.id)).toEqual(['racing-carts'])
})

test('sorted by title', () => {
  const entries = gamesFrom({
    '../../../games/zebra/index.ts': { default: game('Zebra') },
    '../../../e2e/fixtures/apple/index.ts': { default: game('Apple') },
  })
  expect(entries.map((e) => e.game.title)).toEqual(['Apple', 'Zebra'])
})
