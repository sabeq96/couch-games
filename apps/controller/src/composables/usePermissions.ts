import { computed, reactive, type Ref } from 'vue'
import { capabilities, type Capability, type Grant } from '../permissions'

/**
 * The standard permission flow for the current layout's `needs`: what is still missing, what was refused,
 * `requestAll()` for the Join tap and `allow()` for the Allow / Try again tap. Answers last until the page reloads.
 */
export function usePermissions(needs: Ref<readonly Capability[]>) {
  const granted = reactive(new Set<Capability>())
  const denied = reactive(new Set<Capability>())
  const missing = computed(() => needs.value.filter((c) => !granted.has(c)))
  const refused = computed(() => needs.value.find((c) => denied.has(c)) ?? null)

  function record(c: Capability, grant: Grant): boolean {
    if (grant === 'granted') {
      granted.add(c)
      denied.delete(c)
      return true
    }
    denied.add(c)
    return false
  }

  /** Asks for every capability at once. Each request starts before the first await, inside the tap. */
  async function requestAll(): Promise<void> {
    const all = (Object.keys(capabilities) as Capability[]).filter((c) => !granted.has(c))
    await Promise.all(all.map(async (c) => record(c, await capabilities[c].request())))
  }

  async function allow(): Promise<void> {
    for (const c of missing.value) {
      if (!record(c, await capabilities[c].request())) return
    }
  }

  return {
    missing,
    refused,
    requestAll,
    allow,
    /** "This game needs: motion sensor (to steer by tilting)" */
    askText: computed(
      () =>
        'This game needs: ' +
        missing.value.map((c) => `${capabilities[c].name.toLowerCase()} (${capabilities[c].why})`).join(', '),
    ),
    refusedText: computed(() => (refused.value ? `No access to the ${capabilities[refused.value].name.toLowerCase()}` : '')),
  }
}
