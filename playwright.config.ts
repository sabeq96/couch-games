import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  forbidOnly: !!process.env.CI,
  reporter: 'list',
  use: { baseURL: 'http://localhost:4173/couch-games/' },
  webServer: {
    command: 'npm run build:e2e && node scripts/e2e-serve.mjs',
    url: 'http://localhost:4173/couch-games/',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
  projects: [
    {
      name: 'chromium',
      use: { launchOptions: { args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] } },
    },
  ],
})
