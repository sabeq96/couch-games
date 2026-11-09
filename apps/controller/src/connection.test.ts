import { afterEach, beforeEach, expect, test, vi } from 'vitest'

const { FakePeer } = vi.hoisted(() => {
  type Listener = (...args: unknown[]) => void

  class FakeEmitter {
    private listeners = new Map<string, Listener[]>()
    on(ev: string, fn: Listener): this {
      this.listeners.set(ev, [...(this.listeners.get(ev) ?? []), fn])
      return this
    }
    emit(ev: string, ...args: unknown[]): void {
      for (const fn of this.listeners.get(ev) ?? []) fn(...args)
    }
  }

  class FakeConn extends FakeEmitter {
    open = false
    closed = false
    sent: unknown[] = []
    peerId: string
    constructor(peerId: string) {
      super()
      this.peerId = peerId
    }
    send(m: unknown): void {
      this.sent.push(m)
    }
    close(): void {
      if (this.closed) return
      this.closed = true
      this.open = false
      this.emit('close')
    }
    /** The data channel opens. */
    opened(): void {
      this.open = true
      this.emit('open')
    }
  }

  class FakePeer extends FakeEmitter {
    static last: FakePeer
    destroyed = false
    conns: FakeConn[] = []
    constructor() {
      super()
      FakePeer.last = this
      queueMicrotask(() => this.emit('open', 'phone-id'))
    }
    connect(id: string): FakeConn {
      const c = new FakeConn(id)
      this.conns.push(c)
      return c
    }
    destroy(): void {
      this.destroyed = true
    }
  }

  return { FakePeer }
})

vi.mock('peerjs', () => ({ Peer: FakePeer }))

import { connect, type LinkStatus } from './connection'
import type { ServerMsg } from '@couch/shared'

beforeEach(() => vi.useFakeTimers())
afterEach(() => vi.useRealTimers())

const state = { t: 'state', layout: 'dpad', color: '#FF8A80' } as const

async function dial(): Promise<{
  link: ReturnType<typeof connect>
  conn: InstanceType<typeof FakePeer>['conns'][number]
  states: ServerMsg[]
  statuses: LinkStatus[]
}> {
  const states: ServerMsg[] = []
  const statuses: LinkStatus[] = []
  const link = connect('ABCD', 'Alex', (s) => states.push(s), (s) => statuses.push(s))
  await Promise.resolve() // the Peer opens and dials the room
  return { link, conn: FakePeer.last.conns[0], states, statuses }
}

test('dials the room and sends hello when the channel opens', async () => {
  const { conn } = await dial()
  expect(conn.peerId).toBe('couchgames-ABCD')
  expect(conn.sent).toEqual([])
  conn.opened()
  expect(conn.sent).toEqual([{ t: 'hello', name: 'Alex' }])
})

test('the first state means joined; every state reaches onState', async () => {
  const { conn, states, statuses } = await dial()
  conn.opened()
  conn.emit('data', state)
  conn.emit('data', { ...state, layout: 'wait' })
  conn.emit('data', { t: 'nonsense' })
  expect(states).toEqual([state, { ...state, layout: 'wait' }])
  expect(statuses).toEqual(['joined'])
})

test('sends only once joined', async () => {
  const { link, conn } = await dial()
  conn.opened()
  link.send({ t: 'input', a: true })
  conn.emit('data', state)
  link.send({ t: 'input', a: true })
  expect(conn.sent).toEqual([{ t: 'hello', name: 'Alex' }, { t: 'input', a: true }])
})

test('a close before any state fails, once', async () => {
  const { conn, statuses } = await dial()
  conn.opened()
  conn.close()
  conn.emit('error', new Error('gone'))
  expect(statuses).toEqual(['failed'])
})

test('a close after joining fails too', async () => {
  const { conn, statuses } = await dial()
  conn.opened()
  conn.emit('data', state)
  conn.close()
  expect(statuses).toEqual(['joined', 'failed'])
})

test('a peer error (e.g. no such room) fails', async () => {
  const { statuses } = await dial()
  FakePeer.last.emit('error', { type: 'peer-unavailable' })
  expect(statuses).toEqual(['failed'])
})

test('a peer network error after joining does not fail the link', async () => {
  const { link, conn, statuses } = await dial()
  conn.opened()
  conn.emit('data', state)
  FakePeer.last.emit('error', { type: 'network' })
  expect(statuses).toEqual(['joined'])
  link.send({ t: 'input', a: true })
  expect(conn.sent).toEqual([{ t: 'hello', name: 'Alex' }, { t: 'input', a: true }])
})

test('no state within 15 s fails', async () => {
  const { conn, statuses } = await dial()
  conn.opened()
  vi.advanceTimersByTime(14_999)
  expect(statuses).toEqual([])
  vi.advanceTimersByTime(1)
  expect(statuses).toEqual(['failed'])
})

test('a joined link does not time out', async () => {
  const { conn, statuses } = await dial()
  conn.opened()
  conn.emit('data', state)
  vi.advanceTimersByTime(60_000)
  expect(statuses).toEqual(['joined'])
})

test('close tears the peer down without reporting a status', async () => {
  const { link, conn, statuses } = await dial()
  conn.opened()
  link.close()
  expect(FakePeer.last.destroyed).toBe(true)
  conn.close()
  vi.advanceTimersByTime(20_000)
  expect(statuses).toEqual([])
})
