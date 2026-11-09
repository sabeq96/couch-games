/**
 * Every device capability a layout can need, behind one interface. Layouts never call these APIs: they declare
 * `needs` in the registry. The controller asks for all of them on the Join tap, and the standard permission screen
 * asks again only if a layout needs one that is still missing. A new capability (camera, microphone…) is one more
 * entry here.
 */
export type Capability = 'motion'
export type Grant = 'granted' | 'denied' | 'unsupported'

export interface CapabilitySpec {
  /** Shown on the permission and error screens: "Motion sensor". */
  name: string
  /** Why the game needs it: "to steer by tilting". */
  why: string
  /** Asks the browser. Called from the Allow tap, so prompts that need user activation work. */
  request(): Promise<Grant>
}

interface MotionApi {
  requestPermission?: () => Promise<string>
}

/** No API → unsupported; no prompt (Android) → granted; iOS prompt → its answer. */
export async function motionGrant(api: MotionApi | undefined): Promise<Grant> {
  if (!api) return 'unsupported'
  if (!api.requestPermission) return 'granted'
  try {
    return (await api.requestPermission()) === 'granted' ? 'granted' : 'denied'
  } catch {
    return 'denied'
  }
}

export const capabilities: Record<Capability, CapabilitySpec> = {
  motion: {
    name: 'Motion sensor',
    why: 'to steer by tilting',
    request: () =>
      motionGrant(typeof DeviceMotionEvent === 'undefined' ? undefined : (DeviceMotionEvent as unknown as MotionApi)),
  },
}
