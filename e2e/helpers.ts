import { devices, type Browser, type Page } from '@playwright/test'

export async function openHost(browser: Browser): Promise<Page> {
  const page = await (await browser.newContext()).newPage()
  await page.goto('./')
  return page
}

export async function openPhone(browser: Browser, code?: string): Promise<Page> {
  const context = await browser.newContext({ ...devices['Pixel 7'] })
  const page = await context.newPage()
  await page.goto(code ? `controller/?room=${code}` : 'controller/')
  return page
}
