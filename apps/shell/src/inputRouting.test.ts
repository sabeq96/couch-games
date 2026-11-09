import { expect, test } from 'vitest'
import { NEUTRAL, type LayoutId } from '@couch/shared'
import { routeInput, type RoutingState } from './inputRouting'

const dpad = { ...NEUTRAL.dpad, a: true }
const tilt = { steer: 0.5, gas: true, brake: false, item: false }

function state(over: Partial<RoutingState>): RoutingState {
  return {
    route: { name: 'library' },
    leadId: 'alex',
    sentLayout: new Map<string, LayoutId>([['alex', 'dpad'], ['sam', 'wait']]),
    roundIds: new Set(),
    ...over,
  }
}

test("library: the lead's dpad input goes to presses", () => {
  expect(routeInput('alex', 0, dpad, state({}))).toEqual({ to: 'presses', input: dpad })
})

test('library: a non-lead is dropped', () => {
  const s = state({ sentLayout: new Map([['alex', 'dpad'], ['sam', 'dpad']]) })
  expect(routeInput('sam', 1, dpad, s)).toBeNull()
})

test("stale input: dpad fields while the member's layout is tilt-racer are dropped", () => {
  const s = state({
    route: { name: 'play', id: 'racing-carts' },
    sentLayout: new Map([['alex', 'tilt-racer']]),
    roundIds: new Set(['alex']),
  })
  expect(routeInput('alex', 0, dpad, s)).toBeNull()
  expect(routeInput('alex', 0, tilt, s)).toEqual({ to: 'round', slot: 0, input: tilt })
})

test('play: a member not in the round (even on a reused slot) is dropped', () => {
  const s = state({
    route: { name: 'play', id: 'racing-carts' },
    sentLayout: new Map([['chris', 'tilt-racer']]),
    roundIds: new Set(['alex', 'sam']),
  })
  expect(routeInput('chris', 1, tilt, s)).toBeNull()
})

test('a member the shell never sent a layout to is dropped', () => {
  expect(routeInput('nobody', 3, dpad, state({}))).toBeNull()
})
