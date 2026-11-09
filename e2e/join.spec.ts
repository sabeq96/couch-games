import { test, expect, type Browser, type Page } from '@playwright/test'
import { openHost, openPhone } from './helpers'

const pages: Page[] = []

test.afterEach(async () => {
  for (const p of pages.splice(0)) await p.context().close()
})

async function host(browser: Browser): Promise<{ page: Page; code: string }> {
  const page = await openHost(browser)
  pages.push(page)
  const codeEl = page.getByTestId('room-code')
  await expect(codeEl).toHaveText(/^[A-Z]{4}$/, { timeout: 10_000 })
  return { page, code: (await codeEl.textContent()) ?? '' }
}

async function phone(browser: Browser, code?: string, name?: string): Promise<Page> {
  const page = await openPhone(browser, code)
  pages.push(page)
  if (name !== undefined) {
    await page.getByLabel('Your name').fill(name)
    await page.getByRole('button', { name: 'Join', exact: true }).click()
  }
  return page
}

const aButton = (p: Page) => p.getByRole('button', { name: 'A', exact: true })

test('host shows code and QR', async ({ browser }) => {
  const { page } = await host(browser)
  await expect(page.locator('img[alt="QR code"]')).toBeVisible()
})

test('first phone is lead with dpad, second waits', async ({ browser }) => {
  const { page, code } = await host(browser)
  const alex = await phone(browser, code, 'Alex')
  await expect(aButton(alex)).toBeVisible({ timeout: 15_000 })
  const sam = await phone(browser, code, 'Sam')
  await expect(sam.getByText('Look at the screen')).toBeVisible({ timeout: 15_000 })
  await expect(page.getByText('Alex')).toBeVisible()
  await expect(page.getByText('Sam')).toBeVisible()
})

test('lead leaves, next one gets dpad', async ({ browser }) => {
  const { page, code } = await host(browser)
  const alex = await phone(browser, code, 'Alex')
  await expect(aButton(alex)).toBeVisible({ timeout: 15_000 })
  const sam = await phone(browser, code, 'Sam')
  await expect(sam.getByText('Look at the screen')).toBeVisible({ timeout: 15_000 })
  // Like closing the tab: unload handlers run (Playwright skips them by default).
  await alex.close({ runBeforeUnload: true })
  await expect(aButton(sam)).toBeVisible({ timeout: 5_000 })
  await expect(page.getByText('Alex')).toHaveCount(0)
})

test('wrong code', async ({ browser }) => {
  const p = await phone(browser, 'ZZZZ', 'Alex')
  await expect(p.getByText('Unable to join')).toBeVisible({ timeout: 20_000 })
  await p.getByRole('button', { name: 'Try again', exact: true }).click()
  await expect(p.getByRole('button', { name: 'Join', exact: true })).toBeVisible()
  await expect(p.getByLabel('Your name')).toHaveValue('Alex')
})

test('empty code', async ({ browser }) => {
  const p = await phone(browser, undefined, 'Alex')
  await expect(p.getByText('Type the 4 letters from the screen')).toBeVisible()
})

test('seventh phone', async ({ browser }) => {
  test.setTimeout(90_000)
  const { code } = await host(browser)
  for (let i = 0; i < 6; i++) {
    const p = await phone(browser, code, `P${i}`)
    // wait for each join so slots and the lead are deterministic
    await expect(i === 0 ? aButton(p) : p.getByText('Look at the screen')).toBeVisible({ timeout: 15_000 })
  }
  const seventh = await phone(browser, code, 'Seven')
  await expect(seventh.getByText('Unable to join')).toBeVisible({ timeout: 20_000 })
})

test('demo', async ({ browser }) => {
  const context = await browser.newContext()
  const p = await context.newPage()
  pages.push(p)
  await p.goto('controller/?demo=dpad')
  await expect(aButton(p)).toBeVisible()
})
