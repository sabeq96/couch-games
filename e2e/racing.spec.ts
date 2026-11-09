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

test('race with the tilt-racer layout, leave with Escape and race again', async ({ browser }) => {
  const { page, alex } = await couch(browser)
  await openRacing(page, alex)

  // Motion was granted on the Join tap: the driving controls show straight away, no permission screen.
  await expect(button(alex, 'Allow')).toHaveCount(0)
  for (const name of ['GAS', 'BRAKE', 'ITEM', 'Center']) await expect(button(alex, name)).toBeVisible({ timeout: 15_000 })
  await expect(alex.getByLabel('Steering')).toBeVisible()
  // Hold GAS for 2 s.
  await button(alex, 'GAS').hover()
  await alex.mouse.down()
  await expect(button(alex, 'GAS')).toHaveClass(/btn-active/)
  await page.waitForTimeout(2_000)
  await alex.mouse.up()
  await expect(button(alex, 'GAS')).not.toHaveClass(/btn-active/)
  expect(errors).toEqual([])

  await page.keyboard.press('Escape')
  await expect(page).toHaveURL(/#\/$/)
  await expect(page.locator('canvas')).toHaveCount(0)

  // Grants last for the page: the second round goes straight to the controls.
  await openRacing(page, alex)
  await expect(button(alex, 'GAS')).toBeVisible({ timeout: 15_000 })
  await page.waitForTimeout(1_000)
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
