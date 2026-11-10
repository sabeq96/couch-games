import { test, expect, type Browser, type Page } from '@playwright/test'
import { openHost, openPhone, type PhoneOptions } from './helpers'

const pages: Page[] = []
const errors: string[] = []

test.afterEach(async () => {
  for (const p of pages.splice(0)) await p.context().close()
  errors.length = 0
})

function watch(page: Page): Page {
  pages.push(page)
  page.on('pageerror', (e) => errors.push(e.message))
  return page
}

const button = (p: Page, name: string) => p.getByRole('button', { name, exact: true })
const card = (p: Page) => p.getByRole('button', { name: 'Racing Carts' })

async function tap(p: Page, name: string): Promise<void> {
  await expect(button(p, name)).toBeVisible({ timeout: 15_000 })
  await p.waitForTimeout(150)
  await button(p, name).click()
}

async function couch(browser: Browser, opts: PhoneOptions = { motion: 'granted' }): Promise<{ page: Page; alex: Page }> {
  const page = watch(await openHost(browser))
  const codeEl = page.getByTestId('room-code')
  await expect(codeEl).toHaveText(/^[A-Z]{4}$/, { timeout: 10_000 })
  const alex = watch(await openPhone(browser, (await codeEl.textContent()) ?? '', opts))
  await alex.getByLabel('Your name').fill('Alex')
  await button(alex, 'Join').click()
  await expect(button(alex, 'A')).toBeVisible({ timeout: 15_000 })
  return { page, alex }
}

async function openRacing(page: Page, lead: Page): Promise<void> {
  // Racing Carts is first in the library: step off it and back, so the check below sees the Left press.
  await tap(lead, 'Right')
  await expect(card(page)).not.toHaveAttribute('aria-current', 'true')
  for (let i = 0; i < 10 && (await card(page).getAttribute('aria-current')) !== 'true'; i++) await tap(lead, 'Left')
  await expect(card(page)).toHaveAttribute('aria-current', 'true')
  await tap(lead, 'A')
  await expect(page).toHaveURL(/#\/play\/racing-carts$/)
  await expect(page.locator('canvas')).toBeVisible({ timeout: 15_000 })
}

/** True once the page has a `window.racingCarts` (a round is mounted). */
const hasBridge = (page: Page) => page.evaluate(() => 'racingCarts' in window)

/** Slot 0's kart position on the ground, once Godot reports the karts. */
const kartPos = (page: Page) =>
  page.evaluate(() => {
    const karts = (window as unknown as { racingCarts?: { karts?: string } }).racingCarts?.karts
    const all = karts ? (JSON.parse(karts) as { slot: number; x: number; z: number }[]) : []
    const kart = all.find((k) => k.slot === 0)
    return kart ? { x: kart.x, z: kart.z } : undefined
  })

/** Waits until Godot runs the race: the bridge exists and "Loading…" is gone. */
async function godotReady(page: Page): Promise<void> {
  await expect.poll(() => hasBridge(page)).toBe(true)
  await expect(page.getByText('Loading…')).toBeHidden({ timeout: 30_000 })
}

/** Holds a controller button down while `until` runs, so Godot's per-tick poll sees it down. */
async function holding(p: Page, name: string, until: () => Promise<void>): Promise<void> {
  await expect(button(p, name)).toBeVisible({ timeout: 15_000 })
  await button(p, name).hover()
  await p.mouse.down()
  try {
    await until()
  } finally {
    await p.mouse.up()
  }
}

test('race in Godot: countdown, drive, finish, results', async ({ browser }) => {
  test.setTimeout(90_000)
  const { page, alex } = await couch(browser)
  await openRacing(page, alex)
  await godotReady(page)
  // One player, one view.
  await expect
    .poll(() => page.evaluate(() => (window as unknown as { racingCarts?: { views?: number } }).racingCarts?.views))
    .toBe(1)

  await expect.poll(() => kartPos(page)).toBeDefined()
  const start = await kartPos(page)
  // GAS is ignored during the countdown (3, 2, 1, GO); held through it, the kart drives off after GO.
  await holding(alex, 'GAS', () => expect.poll(() => kartPos(page), { timeout: 30_000 }).not.toEqual(start))

  await page.evaluate(() => {
    const bridge = (window as unknown as { racingCarts?: { finishNow?: boolean } }).racingCarts
    if (bridge) bridge.finishNow = true
  })
  await expect(page).toHaveURL(/#\/results\/racing-carts$/, { timeout: 15_000 })
  // Alex races five bots, so any place from 1st to 6th is right.
  await expect(page.locator('li[aria-label$=" Alex"]')).toHaveCount(1)
  expect(errors).toEqual([])
})

test('three players get three views', async ({ browser }) => {
  test.setTimeout(90_000)
  const { page, alex } = await couch(browser)
  const code = (await page.getByTestId('room-code').textContent()) ?? ''
  for (const name of ['Sam', 'Kim']) {
    const p = watch(await openPhone(browser, code, { motion: 'granted' }))
    await p.getByLabel('Your name').fill(name)
    await button(p, 'Join').click()
    await expect(p.getByText('Look at the screen')).toBeVisible({ timeout: 15_000 })
  }
  await openRacing(page, alex)
  await godotReady(page)
  await expect
    .poll(() => page.evaluate(() => (window as unknown as { racingCarts?: { views?: number } }).racingCarts?.views))
    .toBe(3)

  await page.evaluate(() => {
    const bridge = (window as unknown as { racingCarts?: { finishNow?: boolean } }).racingCarts
    if (bridge) bridge.finishNow = true
  })
  await expect(page).toHaveURL(/#\/results\/racing-carts$/)
  expect(errors).toEqual([])
})

test('Escape leaves a round and a second round starts', async ({ browser }) => {
  test.setTimeout(120_000)
  const { page, alex } = await couch(browser)
  await openRacing(page, alex)
  await godotReady(page)

  await page.keyboard.press('Escape')
  await expect(page).toHaveURL(/#\/$/)
  await expect(page.locator('canvas')).toHaveCount(0)
  await expect.poll(() => hasBridge(page)).toBe(false)

  await openRacing(page, alex)
  await godotReady(page)
  expect(errors).toEqual([])
})

test('Escape while loading', async ({ browser }) => {
  test.setTimeout(60_000)
  const { page, alex } = await couch(browser)
  await openRacing(page, alex)
  await page.keyboard.press('Escape')
  await expect(page).toHaveURL(/#\/$/)
  // The round's Godot finishes starting before it quits (one engine at a time), which takes a while in software GL.
  await expect(page.locator('canvas')).toHaveCount(0, { timeout: 30_000 })
  await expect.poll(() => hasBridge(page), { timeout: 30_000 }).toBe(false)
  expect(errors).toEqual([])
})

test('motion refused on Join: still joins, the round shows the standard error with Try again', async ({ browser }) => {
  const { page, alex } = await couch(browser, { motion: 'denied' })
  await openRacing(page, alex)
  await expect(alex.getByText('No access to the motion sensor')).toBeVisible()
  await expect(button(alex, 'Try again')).toBeVisible()
  await expect(button(alex, 'GAS')).toHaveCount(0)
})

test('held upright after joining: asked to turn the phone sideways, even on the d-pad', async ({ browser }) => {
  const page = watch(await openHost(browser))
  const codeEl = page.getByTestId('room-code')
  await expect(codeEl).toHaveText(/^[A-Z]{4}$/, { timeout: 10_000 })
  const alex = watch(await openPhone(browser, (await codeEl.textContent()) ?? '', { upright: true, motion: 'granted' }))
  await expect(button(alex, 'Join')).toBeVisible()
  await alex.getByLabel('Your name').fill('Alex')
  await button(alex, 'Join').click()
  await expect(alex.getByText('Turn your phone sideways')).toBeVisible({ timeout: 15_000 })
  await expect(button(alex, 'A')).toHaveCount(0)
  // Join entered fullscreen (the Android path); leave it so the test can turn the viewport.
  await alex.evaluate(() => document.fullscreenElement && document.exitFullscreen())
  await alex.setViewportSize({ width: 915, height: 412 })
  await expect(button(alex, 'A')).toBeVisible()
})

test('demo shows the permission screen, then the tilt-racer layout', async ({ browser }) => {
  const page = await openPhone(browser, undefined, { motion: 'granted' })
  pages.push(page)
  await page.goto('controller/?demo=tilt-racer')
  await tap(page, 'Allow')
  await expect(button(page, 'GAS')).toBeVisible()
})

test('no motion API: unsupported shows the same error', async ({ browser }) => {
  const page = await openPhone(browser)
  pages.push(page)
  await page.context().addInitScript(() => {
    delete (window as { DeviceMotionEvent?: unknown }).DeviceMotionEvent
  })
  await page.goto('controller/?demo=tilt-racer')
  await tap(page, 'Allow')
  await expect(page.getByText('No access to the motion sensor')).toBeVisible()
  await expect(button(page, 'GAS')).toHaveCount(0)
})

test('Center pressed in the lobby carries into the race', async ({ browser }) => {
  const { page, alex } = await couch(browser)
  const tiltTo = (x: number) =>
    alex.evaluate((gx) => {
      window.dispatchEvent(
        new DeviceMotionEvent('devicemotion', { accelerationIncludingGravity: { x: gx, y: 4, z: 8 } }),
      )
    }, x)
  // Held tilted on the d-pad, the player sets that as straight ahead.
  await tiltTo(5)
  await tap(alex, 'Center')
  await openRacing(page, alex)
  await expect(button(alex, 'GAS')).toBeVisible({ timeout: 15_000 })
  await tiltTo(5)
  await expect.poll(() => alex.getByLabel('Steering').inputValue()).toBe('0')
  await tiltTo(-5)
  await expect.poll(() => alex.getByLabel('Steering').inputValue()).not.toBe('0')
})
