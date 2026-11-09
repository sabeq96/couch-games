import { afterEach, beforeEach, expect, test, vi } from 'vitest'

const { FakeConn, FakePeer } = vi.hoisted(() => {
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

  let nextId = 0
  class FakeConn extends FakeEmitter {
    connectionId = `dc_${nextId++}`
    open = true
    sent: unknown[] = []
    closed = false
    send(m: unknown): void {
      this.sent.push(m)
    }
    close(): void {
      if (this.closed) return
      this.closed = true
      this.open = false
      this.emit('close')
    }
  }

  class FakePeer extends FakeEmitter {
    static last: FakePeer
    /** Peer ids the broker already has: opening one fails with 'unavailable-id'. */
    static taken = new Set<string>()
    destroyed = false
    id: string
    constructor(id: string) {
      super()
      this.id = id
      FakePeer.last = this
      queueMicrotask(() => {
        if (FakePeer.taken.has(id)) this.emit('error', { type: 'unavailable-id' })
        else this.emit('open', id)
      })
    }
    destroy(): void {
      this.destroyed = true
    }
  }

  return { FakeConn, FakePeer }
})

vi.mock('peerjs', () => ({ Peer: FakePeer }))

import { openRoom, type Room, type RoomHandlers } from './host'

beforeEach(() => vi.useFakeTimers())
afterEach(() => {
  vi.useRealTimers()
  FakePeer.taken.clear()
})

const handlers = (over: Partial<RoomHandlers> = {}): RoomHandlers => ({
  onHello: () => true,
  onInput: () => {},
  onLeave: () => {},
  ...over,
})

function connectPhone(): InstanceType<typeof FakeConn> {
  const conn = new FakeConn()
  FakePeer.last.emit('connection', conn)
  return conn
}

const state = { t: 'state', layout: 'dpad', color: '#FF8A80' } as const

test('hello is passed to onHello with the connection id and name', async () => {
  const onHello = vi.fn(() => true)
  await openRoom(handlers({ onHello }))
  const conn = connectPhone()
  conn.emit('data', { t: 'hello', name: 'Alex' })
  expect(onHello).toHaveBeenCalledWith(conn.connectionId, 'Alex')
  expect(conn.closed).toBe(false)
})

test('send inside onHello reaches the new phone', async () => {
  const room: Room = await openRoom(
    handlers({
      onHello: (id) => {
        room.send(id, state)
        return true
      },
    }),
  )
  const conn = connectPhone()
  conn.emit('data', { t: 'hello', name: 'Alex' })
  expect(conn.sent).toEqual([state])
})

test('a rejected hello gets nothing and is closed after 200 ms, without onLeave', async () => {
  const onLeave = vi.fn()
  const onInput = vi.fn()
  const room = await openRoom(handlers({ onHello: () => false, onLeave, onInput }))
  const conn = connectPhone()
  conn.emit('data', { t: 'hello', name: 'Seven' })
  conn.emit('data', { t: 'input', a: true })
  room.send(conn.connectionId, state)
  expect(conn.closed).toBe(false)
  vi.advanceTimersByTime(200)
  expect(conn.closed).toBe(true)
  expect(conn.sent).toEqual([])
  expect(onInput).not.toHaveBeenCalled()
  expect(onLeave).not.toHaveBeenCalled()
})

test('input after hello reaches onInput; input before hello is ignored', async () => {
  const onInput = vi.fn()
  const onHello = vi.fn(() => true)
  await openRoom(handlers({ onHello, onInput }))
  const conn = connectPhone()
  conn.emit('data', { t: 'input', a: true })
  expect(onInput).not.toHaveBeenCalled()
  conn.emit('data', { t: 'hello', name: 'Alex' })
  conn.emit('data', { t: 'input', a: true, b: false })
  expect(onHello).toHaveBeenCalledTimes(1)
  expect(onInput).toHaveBeenCalledWith(conn.connectionId, { a: true, b: false })
})

test('close after hello calls onLeave once and stops sends', async () => {
  const onLeave = vi.fn()
  const room = await openRoom(handlers({ onLeave }))
  const conn = connectPhone()
  conn.emit('data', { t: 'hello', name: 'Alex' })
  conn.close()
  conn.emit('error', new Error('gone'))
  expect(onLeave).toHaveBeenCalledTimes(1)
  expect(onLeave).toHaveBeenCalledWith(conn.connectionId)
  room.send(conn.connectionId, state)
  expect(conn.sent).toEqual([])
})

test('a taken room code is retried with a new code', async () => {
  // rand 0 → 'AAAA'; then 0.5 picks the middle letter of the alphabet.
  const values = [0, 0, 0, 0, 0.5, 0.5, 0.5, 0.5]
  const rand = () => values.shift() ?? 0.5
  FakePeer.taken.add('couchgames-AAAA')
  const room = await openRoom(handlers(), {}, rand)
  expect(room.code).toBe('NNNN')
  expect(FakePeer.last.id).toBe('couchgames-NNNN')
})

test('a broker that cannot be reached rejects with broker-unreachable', async () => {
  const opening = openRoom(handlers())
  const peer = FakePeer.last
  peer.emit('error', { type: 'network' })
  await expect(opening).rejects.toThrow('broker-unreachable')
  expect(peer.destroyed).toBe(true)
})

test('close destroys the peer', async () => {
  const room = await openRoom(handlers())
  room.close()
  expect(FakePeer.last.destroyed).toBe(true)
})
