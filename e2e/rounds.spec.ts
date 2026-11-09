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

async function phone(browser: Browser, code: string, name: string): Promise<Page> {
  const page = await openPhone(browser, code)
  pages.push(page)
  await page.getByLabel('Your name').fill(name)
  await page.getByRole('button', { name: 'Join', exact: true }).click()
  return page
}

const button = (p: Page, name: string) => p.getByRole('button', { name, exact: true })
const waits = (p: Page) => p.getByText('Look at the screen')
const roundText = (p: Page) => p.getByTestId('round')
/** Each place as "1st Sam": the podium first, then the rest. */
const results = (p: Page) =>
  expect.poll(() =>
    p.locator('ol[aria-label="Podium"] > li, ol[aria-label="Others"] > li').evaluateAll((els) => els.map((e) => e.getAttribute('aria-label'))),
  )
const testGameCard = (p: Page) => p.getByRole('button', { name: 'Test Game' })
const destroyed = (p: Page) => p.evaluate(() => (window as unknown as { __destroyed?: number }).__destroyed)

/**
 * Taps a phone button. After every screen change the shell takes the next snapshot as the baseline (so a held
 * button is not a press); the short wait lets a baseline arrive first, like a human who looks before pressing.
 */
async function tap(p: Page, name: string): Promise<void> {
  await expect(button(p, name)).toBeVisible({ timeout: 15_000 })
  await p.waitForTimeout(150)
  await button(p, name).click()
}

/** Host with Alex (lead) and Sam joined, on the library. */
async function couch(browser: Browser): Promise<{ page: Page; code: string; alex: Page; sam: Page }> {
  const { page, code } = await host(browser)
  const alex = await phone(browser, code, 'Alex')
  await expect(button(alex, 'A')).toBeVisible({ timeout: 15_000 })
  const sam = await phone(browser, code, 'Sam')
  await expect(waits(sam)).toBeVisible({ timeout: 15_000 })
  return { page, code, alex, sam }
}

/** The lead moves until Test Game is selected and opens it. */
async function openTestGame(page: Page, lead: Page): Promise<void> {
  // The library is sorted by title: Racing Carts, then Test Game.
  await tap(lead, 'Right')
  await expect(testGameCard(page)).toHaveAttribute('aria-current', 'true')
  await tap(lead, 'A')
  await expect(page).toHaveURL(/#\/play\/e2e-test-game$/)
  await expect(roundText(page)).toBeVisible()
}

test('lead opens a game, everyone gets its layout', async ({ browser }) => {
  const { page, alex, sam } = await couch(browser)
  // The library hints the phone's d-pad; the round does not.
  await expect(page.getByTestId('library-hint')).toHaveText(/move\s*A\s*select/)
  await openTestGame(page, alex)
  await expect(page.getByTestId('library-hint')).toHaveCount(0)
  await expect(roundText(page)).toHaveText('Round with Alex, Sam')
  await expect(button(alex, 'A')).toBeVisible()
  await expect(button(sam, 'A')).toBeVisible({ timeout: 5_000 })
  // The game fills the screen; the party bar shrinks to a chip with the code.
  await expect(page.locator('img[alt="QR code"]')).toBeHidden()
  await expect(page.getByTestId('room-code')).toBeVisible()
})

test('late joiner waits', async ({ browser }) => {
  const { page, code, alex, sam } = await couch(browser)
  await openTestGame(page, alex)
  const chris = await phone(browser, code, 'Chris')
  await expect(waits(chris)).toBeVisible({ timeout: 15_000 })
  await expect(roundText(page)).toHaveText('Round with Alex, Sam')

  await tap(sam, 'A')
  await results(page).toEqual(['1st Sam', '2nd Alex'])
  await expect(waits(chris)).toBeVisible()

  // Sam leaves; the mid-round joiner is on the roster of the next round.
  await sam.close({ runBeforeUnload: true })
  await tap(alex, 'A')
  await expect(page).toHaveURL(/#\/play\/e2e-test-game$/)
  await expect(roundText(page)).toHaveText('Round with Alex, Chris')
})

test('finish shows results, A plays again, B goes back', async ({ browser }) => {
  const { page, alex, sam } = await couch(browser)
  await openTestGame(page, alex)

  await tap(sam, 'A')
  await expect(page).toHaveURL(/#\/results\/e2e-test-game$/)
  await results(page).toEqual(['1st Sam', '2nd Alex'])
  await expect(waits(sam)).toBeVisible({ timeout: 5_000 })

  await tap(alex, 'A')
  await expect(page).toHaveURL(/#\/play\/e2e-test-game$/)
  await expect(roundText(page)).toBeVisible()
  await tap(sam, 'A')
  await results(page).toEqual(['1st Sam', '2nd Alex'])

  await tap(alex, 'B')
  await expect(page).toHaveURL(/#\/$/)
  await expect(testGameCard(page)).toBeVisible()
})

test('held A does not skip results', async ({ browser }) => {
  const { page, alex } = await couch(browser)
  // Open with the host mouse, so the lead's last library snapshot has A up (an A press to open would mask a
  // missing baseline reset).
  await testGameCard(page).click()
  await expect(roundText(page)).toBeVisible()
  await alex.waitForTimeout(150)
  // Press A and keep holding it: the press finishes the round, the hold must not play again.
  await button(alex, 'A').hover()
  await alex.mouse.down()
  await results(page).toEqual(['1st Alex', '2nd Sam'])
  await page.waitForTimeout(1_000)
  await expect(page).toHaveURL(/#\/results\/e2e-test-game$/)
  // One round only: a held A that played again would start (and the fixture finish) a second one.
  expect(await destroyed(page)).toBe(1)
})

test('Escape leaves and the game reopens', async ({ browser }) => {
  const { page, alex, sam } = await couch(browser)
  await openTestGame(page, alex)
  await page.keyboard.press('Escape')
  await expect(page).toHaveURL(/#\/$/)
  await expect(roundText(page)).toHaveCount(0)
  await expect.poll(() => destroyed(page)).toBe(1)
  await expect(button(alex, 'A')).toBeVisible()
  await expect(waits(sam)).toBeVisible({ timeout: 5_000 })

  await openTestGame(page, alex)
  await expect(roundText(page)).toHaveText('Round with Alex, Sam')
  expect(await destroyed(page)).toBe(1)
})

test('not enough players', async ({ browser }) => {
  const { page } = await host(browser)
  await expect(testGameCard(page)).toBeDisabled()
  await expect(testGameCard(page).getByTestId('players')).toHaveText('👥 1–2 players')
})

test('host mouse opens a game and drives results', async ({ browser }) => {
  const { page, sam } = await couch(browser)
  await testGameCard(page).click()
  await expect(roundText(page)).toHaveText('Round with Alex, Sam')
  await tap(sam, 'A')
  await results(page).toEqual(['1st Sam', '2nd Alex'])
  await button(page, 'Play again').click()
  await expect(roundText(page)).toBeVisible()
  await tap(sam, 'A')
  await button(page, 'Library').click()
  await expect(page).toHaveURL(/#\/$/)
})

test('browser back from a round goes to the library', async ({ browser }) => {
  const { page, alex, sam } = await couch(browser)
  await openTestGame(page, alex)
  await tap(sam, 'A')
  await results(page).toEqual(['1st Sam', '2nd Alex'])
  await button(page, 'Play again').click()
  await expect(roundText(page)).toBeVisible()
  const before = (await destroyed(page)) ?? 0
  await page.goBack()
  // The host page was opened without a hash: that first entry is the library too.
  await expect(page).toHaveURL(/\/couch-games\/(#\/)?$/)
  await expect(testGameCard(page)).toBeVisible()
  await expect.poll(() => destroyed(page)).toBe(before + 1)
})

test('browser back after Escape does not start a round', async ({ browser }) => {
  const { page, alex } = await couch(browser)
  await openTestGame(page, alex)
  await page.keyboard.press('Escape')
  await expect(page).toHaveURL(/#\/$/)
  await page.goBack()
  await page.waitForTimeout(500)
  await expect(roundText(page)).toHaveCount(0)
  expect(page.url()).not.toMatch(/#\/play\//)
})

test('host keyboard selects and opens a game, then drives results', async ({ browser }) => {
  const { page, sam } = await couch(browser)
  await page.keyboard.press('ArrowRight')
  await expect(testGameCard(page)).toHaveAttribute('aria-current', 'true')
  await page.keyboard.press('Enter')
  await expect(page).toHaveURL(/#\/play\/e2e-test-game$/)
  await expect(roundText(page)).toBeVisible()
  await tap(sam, 'A')
  await results(page).toEqual(['1st Sam', '2nd Alex'])
  await page.keyboard.press('Enter') // play again
  await expect(page).toHaveURL(/#\/play\/e2e-test-game$/)
  await tap(sam, 'A')
  await results(page).toEqual(['1st Sam', '2nd Alex'])
  await page.keyboard.press('Backspace') // library
  await expect(page).toHaveURL(/#\/$/)
})
