import { Peer, type DataConnection } from 'peerjs'
import { decodeClient, makeRoomCode, peerIdFor, type ServerMsg } from '@couch/shared'

export interface RoomHandlers {
  /** Return false to turn the phone away: it gets nothing and is closed 200 ms later. */
  onHello(id: string, name: string): boolean
  onInput(id: string, fields: Record<string, unknown>): void
  onLeave(id: string): void
}

export interface Room {
  code: string
  send(id: string, msg: ServerMsg): void
  close(): void
}

const MAX_CODE_ATTEMPTS = 20
const REJECT_CLOSE_MS = 200
const BROKER_ERRORS = new Set(['network', 'server-error', 'socket-error'])

/** Opens a Peer under a fresh room code, retrying while the code is taken. */
function openPeer(peerOpts: object, rand?: () => number): Promise<{ peer: Peer; code: string }> {
  return new Promise((resolve, reject) => {
    const attempt = (n: number): void => {
      const code = makeRoomCode(rand)
      const peer = new Peer(peerIdFor(code), peerOpts)
      let settled = false
      peer.on('open', () => {
        settled = true
        resolve({ peer, code })
      })
      peer.on('error', (err) => {
        if (settled) return // after opening, per-connection problems must not take the room down
        settled = true
        peer.destroy()
        const type = String(err.type)
        if (type === 'unavailable-id' && n < MAX_CODE_ATTEMPTS) attempt(n + 1)
        else reject(new Error(BROKER_ERRORS.has(type) ? 'broker-unreachable' : type))
      })
    }
    attempt(1)
  })
}

/** Opens the party room: phones connect, say hello, then send input. Keyed by connection id. */
export async function openRoom(handlers: RoomHandlers, peerOpts: object = {}, rand?: () => number): Promise<Room> {
  const { peer, code } = await openPeer(peerOpts, rand)
  const members = new Map<string, DataConnection>()

  peer.on('connection', (conn) => {
    const id = conn.connectionId
    let state: 'new' | 'joined' | 'rejected' = 'new'

    conn.on('data', (raw) => {
      const msg = decodeClient(raw)
      if (!msg) return
      if (state === 'new' && msg.t === 'hello') {
        members.set(id, conn) // before onHello, so the handler can send to this phone
        if (handlers.onHello(id, msg.name)) {
          state = 'joined'
        } else {
          members.delete(id)
          state = 'rejected'
          setTimeout(() => conn.close(), REJECT_CLOSE_MS)
        }
      } else if (state === 'joined' && msg.t === 'input') {
        handlers.onInput(id, msg.fields)
      }
    })
    const gone = (): void => {
      if (state !== 'joined' || !members.delete(id)) return
      handlers.onLeave(id)
    }
    conn.on('close', gone)
    conn.on('error', gone)
  })

  return {
    code,
    send(id, msg) {
      const conn = members.get(id)
      if (conn?.open) conn.send(msg)
    },
    close() {
      members.clear()
      peer.destroy()
    },
  }
}
