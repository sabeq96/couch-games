import { describe, expect, test } from 'vitest'
import { capabilities, motionGrant } from './permissions'

describe('motionGrant', () => {
  test('no motion API → unsupported', async () => {
    expect(await motionGrant(undefined)).toBe('unsupported')
  })

  test('motion API without a prompt → granted', async () => {
    expect(await motionGrant({})).toBe('granted')
  })

  test('prompt answered granted → granted', async () => {
    expect(await motionGrant({ requestPermission: async () => 'granted' })).toBe('granted')
  })

  test('prompt answered denied → denied', async () => {
    expect(await motionGrant({ requestPermission: async () => 'denied' })).toBe('denied')
  })

  test('prompt throws (e.g. no tap) → denied', async () => {
    expect(
      await motionGrant({
        requestPermission: async () => {
          throw new Error('NotAllowedError')
        },
      }),
    ).toBe('denied')
  })
})

test('every capability has a name and a reason for the permission screen', () => {
  for (const spec of Object.values(capabilities)) {
    expect(spec.name).not.toBe('')
    expect(spec.why).not.toBe('')
  }
})
