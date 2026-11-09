import { afterEach, expect, test } from 'vitest'
import { ref } from 'vue'
import { capabilities, type Capability, type Grant } from '../permissions'
import { usePermissions } from './usePermissions'

const real = { ...capabilities.motion }
afterEach(() => Object.assign(capabilities.motion, real))

function answer(grant: Grant): void {
  capabilities.motion.request = async () => grant
}

test('nothing needed → nothing missing, nothing to ask', () => {
  const p = usePermissions(ref<readonly Capability[]>([]))
  expect(p.missing.value).toEqual([])
})

test('Allow with a grant clears what was missing', async () => {
  answer('granted')
  const p = usePermissions(ref<readonly Capability[]>(['motion']))
  expect(p.missing.value).toEqual(['motion'])
  expect(p.askText.value).toBe('This game needs: motion sensor (to steer by tilting)')
  await p.allow()
  expect(p.missing.value).toEqual([])
  expect(p.refused.value).toBeNull()
})

test('a refusal shows the standard error; Try again asks again', async () => {
  answer('denied')
  const p = usePermissions(ref<readonly Capability[]>(['motion']))
  await p.allow()
  expect(p.refused.value).toBe('motion')
  expect(p.refusedText.value).toBe('No access to the motion sensor')
  answer('granted')
  await p.allow()
  expect(p.refused.value).toBeNull()
  expect(p.missing.value).toEqual([])
})

test('an unsupported capability is refused the same way', async () => {
  answer('unsupported')
  const p = usePermissions(ref<readonly Capability[]>(['motion']))
  await p.allow()
  expect(p.refusedText.value).toBe('No access to the motion sensor')
})

test('grants are kept when the layout changes and comes back', async () => {
  answer('granted')
  const needs = ref<readonly Capability[]>(['motion'])
  const p = usePermissions(needs)
  await p.allow()
  needs.value = []
  needs.value = ['motion']
  expect(p.missing.value).toEqual([])
})
