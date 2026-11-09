import { Peer, type DataConnection } from 'peerjs'
import { decodeServer, peerIdFor, type ClientMsg, type ServerMsg } from '@couch/shared'

export type LinkStatus = 'connecting' | 'joined' | 'failed'

export interface Link {
  send(msg: object): void
  close(): void
}

const JOIN_TIMEOUT_MS = 15_000

/**
 * Joins the room `code`: sends hello when the channel opens; the first state means joined.
 * Any error or close, or no state within 15 s, means failed. No retry.
 */
export function connect(
  code: string,
  name: string,
  onState: (s: ServerMsg) => void,
  onStatus: (s: LinkStatus) => void,
  peerOpts: object = {},
): Link {
  let status: LinkStatus = 'connecting'
  let closed = false
  let conn: DataConnection | null = null

  const fail = (): void => {
    if (closed || status === 'failed') return
    status = 'failed'
    clearTimeout(timer)
    onStatus('failed')
  }
  const timer = setTimeout(fail, JOIN_TIMEOUT_MS)

  const peer = new Peer(peerOpts)
  peer.on('error', fail)
  peer.on('open', () => {
    const c = peer.connect(peerIdFor(code), { serialization: 'json' })
    conn = c
    c.on('open', () => c.send({ t: 'hello', name } satisfies ClientMsg))
    c.on('data', (raw) => {
      const msg = decodeServer(raw)
      if (!msg || closed || status === 'failed') return
      onState(msg)
      if (status === 'connecting') {
        status = 'joined'
        clearTimeout(timer)
        onStatus('joined')
      }
    })
    c.on('close', fail)
    c.on('error', fail)
  })

  return {
    send(msg) {
      if (status === 'joined' && conn?.open) conn.send(msg)
    },
    close() {
      closed = true
      clearTimeout(timer)
      peer.destroy()
    },
  }
}
