import { devices, type Browser, type Page } from '@playwright/test'

export async function openHost(browser: Browser): Promise<Page> {
  const page = await (await browser.newContext()).newPage()
  await page.goto('./')
  return page
}

export interface PhoneOptions {
  /** Hold the phone upright: once joined, the controller shows "Turn your phone sideways". Sideways by default. */
  upright?: boolean
  /** Answer the motion prompt with this instead of the headless default (a refusal). */
  motion?: 'granted' | 'denied'
}

export async function openPhone(browser: Browser, code?: string, opts: PhoneOptions = {}): Promise<Page> {
  const pixel = devices['Pixel 7']
  const viewport = opts.upright ? pixel.viewport : { width: pixel.viewport.height, height: pixel.viewport.width }
  const context = await browser.newContext({ ...pixel, viewport })
  if (opts.motion) {
    await context.addInitScript((answer) => {
      ;(window.DeviceMotionEvent as unknown as { requestPermission: () => Promise<string> }).requestPermission =
        async () => answer
    }, opts.motion)
  }
  const page = await context.newPage()
  await page.goto(code ? `controller/?room=${code}` : 'controller/')
  return page
}
