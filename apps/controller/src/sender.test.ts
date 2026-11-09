import { afterEach, beforeEach, expect, test, vi } from 'vitest'
import { startSender } from './sender'

beforeEach(() => vi.useFakeTimers())
afterEach(() => vi.useRealTimers())

test('sends one input snapshot every ~33 ms', () => {
  const sent: object[] = []
  let a = false
  startSender(() => ({ a }), (m) => sent.push(m))
  vi.advanceTimersByTime(34)
  a = true
  vi.advanceTimersByTime(66)
  expect(sent).toEqual([
    { t: 'input', a: false },
    { t: 'input', a: true },
    { t: 'input', a: true },
  ])
})

test('nothing is sent while read() is null', () => {
  const send = vi.fn()
  startSender(() => null, send)
  vi.advanceTimersByTime(1000)
  expect(send).not.toHaveBeenCalled()
})

test('the stop function stops sending', () => {
  const send = vi.fn()
  const stop = startSender(() => ({}), send)
  vi.advanceTimersByTime(100)
  expect(send).toHaveBeenCalledTimes(3)
  stop()
  vi.advanceTimersByTime(1000)
  expect(send).toHaveBeenCalledTimes(3)
})
