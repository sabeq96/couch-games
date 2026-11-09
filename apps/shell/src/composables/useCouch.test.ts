import { expect, test } from 'vitest'
import type { ServerMsg } from '@couch/shared'
import { useCouch } from './useCouch'

function setup() {
  const sent: { id: string; msg: ServerMsg }[] = []
  const pressed: string[] = []
  const couch = useCouch({
    send: (id, msg) => sent.push({ id, msg }),
    round: () => null,
    menu: () => ({ press: (k) => pressed.push(k) }),
  })
  const lastLayout = (id: string) => [...sent].reverse().find((s) => s.id === id)?.msg.layout
  return { couch, sent, pressed, lastLayout }
}

const dpad = (a: boolean) => ({ up: false, down: false, left: false, right: false, a, b: false })

test('first phone is lead with dpad, the next waits', () => {
  const { couch, lastLayout } = setup()
  couch.enter({ name: 'library' })
  expect(couch.handlers.onHello('c1', 'Alex')).toBe(true)
  expect(couch.handlers.onHello('c2', 'Sam')).toBe(true)
  expect(lastLayout('c1')).toBe('dpad')
  expect(lastLayout('c2')).toBe('wait')
  expect(couch.members.value.map((p) => p.name)).toEqual(['Alex', 'Sam'])
})

test('lead leaves: the next member gets dpad', () => {
  const { couch, lastLayout } = setup()
  couch.enter({ name: 'library' })
  couch.handlers.onHello('c1', 'Alex')
  couch.handlers.onHello('c2', 'Sam')
  couch.handlers.onLeave('c1')
  expect(lastLayout('c2')).toBe('dpad')
})

test('only press edges of the lead reach the menu', () => {
  const { couch, pressed } = setup()
  couch.enter({ name: 'library' })
  couch.handlers.onHello('c1', 'Alex')
  couch.handlers.onHello('c2', 'Sam')
  couch.handlers.onInput('c1', dpad(false))
  couch.handlers.onInput('c1', dpad(true))
  couch.handlers.onInput('c1', dpad(true))
  couch.handlers.onInput('c2', dpad(true))
  expect(pressed).toEqual(['a'])
})

test('a seventh phone is turned away', () => {
  const { couch } = setup()
  couch.enter({ name: 'library' })
  for (let i = 0; i < 6; i++) expect(couch.handlers.onHello(`c${i}`, `P${i}`)).toBe(true)
  expect(couch.handlers.onHello('c6', 'Late')).toBe(false)
})

test('an unknown game on #/play starts no round', () => {
  const { couch } = setup()
  couch.enter({ name: 'play', id: 'nope' })
  expect(couch.round.value).toBeNull()
})
