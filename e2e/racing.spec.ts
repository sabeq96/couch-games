import { test, expect, type Browser, type Page } from '@playwright/test'
import { openHost, openPhone } from './helpers'

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

async function couch(browser: Browser): Promise<{ page: Page; alex: Page }> {
  const page = watch(await openHost(browser))
  const codeEl = page.getByTestId('room-code')
  await expect(codeEl).toHaveText(/^[A-Z]{4}$/, { timeout: 10_000 })
  const alex = watch(await openPhone(browser, (await codeEl.textContent()) ?? ''))
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
  await expect(page.getByText("This screen can't draw 3D")).toHaveCount(0)
}

test('race with the tilt-racer layout, leave with Escape and race again', async ({ browser }) => {
  const { page, alex } = await couch(browser)
  await openRacing(page, alex)

  for (const name of ['GAS', 'BRAKE', 'ITEM']) await expect(button(alex, name)).toBeVisible({ timeout: 15_000 })
  // Hold GAS for 2 s. It is also the first touch, which asks for motion; with no samples (headless) ◀ ▶ appear.
  await button(alex, 'GAS').dispatchEvent('pointerdown', { pointerId: 1 })
  await page.waitForTimeout(2_000)
  await button(alex, 'GAS').dispatchEvent('pointerup', { pointerId: 1 })
  await expect(button(alex, 'Steer left')).toBeVisible()
  await expect(button(alex, 'Steer right')).toBeVisible()
  expect(errors).toEqual([])

  await page.keyboard.press('Escape')
  await expect(page).toHaveURL(/#\/$/)
  await expect(page.locator('canvas')).toHaveCount(0)

  await openRacing(page, alex)
  await expect(button(alex, 'GAS')).toBeVisible({ timeout: 15_000 })
  await page.waitForTimeout(1_000)
  expect(errors).toEqual([])
})

test('demo shows the tilt-racer layout', async ({ page }) => {
  await page.goto('controller/?demo=tilt-racer')
  await expect(button(page, 'GAS')).toBeVisible()
})
