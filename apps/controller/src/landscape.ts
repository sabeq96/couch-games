/**
 * Fullscreen then a landscape lock where the browser allows them (Android). Called from the Join tap, which counts
 * as user activation. iPhone has neither API; the "Turn your phone sideways" screen covers it.
 */
export async function lockLandscape(): Promise<void> {
  try {
    await document.documentElement.requestFullscreen?.()
    await (screen.orientation as ScreenOrientation & { lock?: (o: string) => Promise<void> }).lock?.('landscape')
  } catch {
    // the browser doesn't lock
  }
}
