import { expect, test } from 'vitest'
import { PLAYER_COLORS, type Player } from '@couch/shared'
import { layoutFor } from './layoutFor'

const player = (slot: number): Player => ({ slot, name: `P${slot}`, color: PLAYER_COLORS[slot] })
const lead = player(0)

test('library: lead gets dpad, others wait', () => {
  expect(layoutFor({ name: 'library' }, lead, lead, null)).toBe('dpad')
  expect(layoutFor({ name: 'library' }, player(1), lead, null)).toBe('wait')
})

test('results: lead gets dpad, others wait', () => {
  const route = { name: 'results', id: 'racing-carts' } as const
  expect(layoutFor(route, lead, lead, null)).toBe('dpad')
  expect(layoutFor(route, player(1), lead, null)).toBe('wait')
})

test("play: players in the round get the game's layout, the rest wait", () => {
  const route = { name: 'play', id: 'racing-carts' } as const
  const round = { layout: 'tilt-racer', slots: [0, 1] } as const
  expect(layoutFor(route, player(1), lead, round)).toBe('tilt-racer')
  expect(layoutFor(route, player(2), lead, round)).toBe('wait')
})
