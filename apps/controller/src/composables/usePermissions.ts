import { computed, reactive, ref, type Ref } from 'vue'
import { capabilities, type Capability } from '../permissions'

/**
 * The standard permission flow for the current layout's `needs`: what is still missing, what was refused, and
 * `allow()` for the Allow / Try again tap. Grants last until the page reloads.
 */
export function usePermissions(needs: Ref<readonly Capability[]>) {
  const granted = reactive(new Set<Capability>())
  const refused = ref<Capability | null>(null)
  const missing = computed(() => needs.value.filter((c) => !granted.has(c)))

  async function allow(): Promise<void> {
    refused.value = null
    for (const c of missing.value) {
      if ((await capabilities[c].request()) !== 'granted') {
        refused.value = c
        return
      }
      granted.add(c)
    }
  }

  return {
    missing,
    refused,
    allow,
    /** "This game needs the motion sensor (to steer by tilting)." */
    askText: computed(
      () =>
        'This game needs: ' +
        missing.value.map((c) => `${capabilities[c].name.toLowerCase()} (${capabilities[c].why})`).join(', '),
    ),
    refusedText: computed(() => (refused.value ? `No access to the ${capabilities[refused.value].name.toLowerCase()}` : '')),
  }
}
