import { expect, test } from 'vitest'
import { NEUTRAL } from '@couch/shared'
import { Presses } from './presses'

const up = NEUTRAL.dpad
const aDown = { ...NEUTRAL.dpad, a: true }

test('a key going up → down is a press', () => {
  const p = new Presses()
  p.next(up)
  expect(p.next(aDown)).toEqual(['a'])
})

test('a held key is not pressed again', () => {
  const p = new Presses()
  p.next(up)
  p.next(aDown)
  expect(p.next(aDown)).toEqual([])
})

test('after reset the next snapshot is only the baseline', () => {
  const p = new Presses()
  p.next(up)
  p.reset()
  expect(p.next(aDown)).toEqual([])
  expect(p.next(aDown)).toEqual([])
})

test('the first snapshot ever is the baseline', () => {
  expect(new Presses().next(aDown)).toEqual([])
})
