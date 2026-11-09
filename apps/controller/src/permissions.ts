/**
 * Every device capability a layout can need, behind one interface. Layouts never call these APIs: they declare
 * `needs` in the registry and the controller asks through the standard permission screen. A new capability
 * (camera, microphone…) is one more entry here.
 */
export type Capability = 'motion' | 'landscape'
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

/** Fullscreen then a landscape lock where the browser allows them. Nothing to refuse: holding sideways is checked live. */
async function lockLandscape(): Promise<Grant> {
  try {
    await document.documentElement.requestFullscreen?.()
    await (screen.orientation as ScreenOrientation & { lock?: (o: string) => Promise<void> }).lock?.('landscape')
  } catch {
    // the browser doesn't lock; the "turn your phone sideways" screen covers it
  }
  return 'granted'
}

export const capabilities: Record<Capability, CapabilitySpec> = {
  motion: {
    name: 'Motion sensor',
    why: 'to steer by tilting',
    request: () =>
      motionGrant(typeof DeviceMotionEvent === 'undefined' ? undefined : (DeviceMotionEvent as unknown as MotionApi)),
  },
  landscape: {
    name: 'Landscape',
    why: 'to hold the phone sideways',
    request: lockLandscape,
  },
}
