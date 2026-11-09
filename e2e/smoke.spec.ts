import { test, expect } from '@playwright/test'
import { openHost } from './helpers'

test('two contexts talk through the local broker', async ({ browser }) => {
  const a = await openHost(browser)
  const b = await openHost(browser)
  const options = { host: 'localhost', port: 9000, path: '/' }

  await a.evaluate(
    (o) =>
      new Promise<void>((resolve) => {
        const w = window as unknown as { __Peer: new (id: string, o: unknown) => any; got?: string }
        const peer = new w.__Peer('couchgames-TEST', o)
        peer.on('open', () => resolve())
        peer.on('connection', (conn: any) => conn.on('data', (d: string) => (w.got = d)))
      }),
    options,
  )

  await b.evaluate(
    (o) =>
      new Promise<void>((resolve) => {
        const w = window as unknown as { __Peer: new (id?: string, o?: unknown) => any }
        const peer = new w.__Peer(undefined, o)
        peer.on('open', () => {
          const conn = peer.connect('couchgames-TEST')
          conn.on('open', () => {
            conn.send('ping')
            resolve()
          })
        })
      }),
    options,
  )

  await expect.poll(() => a.evaluate(() => (window as unknown as { got?: string }).got), { timeout: 10_000 }).toBe('ping')
})
