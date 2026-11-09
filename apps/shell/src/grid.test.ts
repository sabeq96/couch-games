import { expect, test } from 'vitest'
import { move } from './grid'

test('moves within a 3-column grid of 5, clamped, no wrap', () => {
  expect(move(0, 'right', 5, 3)).toBe(1)
  expect(move(2, 'right', 5, 3)).toBe(2)
  expect(move(1, 'down', 5, 3)).toBe(4)
  expect(move(4, 'up', 5, 3)).toBe(1)
})

test('stays put at the edges', () => {
  expect(move(0, 'left', 5, 3)).toBe(0)
  expect(move(3, 'left', 5, 3)).toBe(3)
  expect(move(0, 'up', 5, 3)).toBe(0)
  expect(move(2, 'down', 5, 3)).toBe(2) // nothing below index 2
  expect(move(4, 'right', 5, 3)).toBe(4)
})
