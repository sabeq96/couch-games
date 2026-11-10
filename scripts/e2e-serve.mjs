// Serves output/ at http://localhost:4173/couch-games/ and a local PeerJS broker on :9000.
import { createServer } from 'node:http'
import { readFile, stat } from 'node:fs/promises'
import { extname, join, normalize, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { PeerServer } from 'peer'

const ROOT = resolve(fileURLToPath(new URL('../output', import.meta.url)))
const PREFIX = '/couch-games/'
const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.mp3': 'audio/mpeg',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
}

createServer(async (req, res) => {
  const { pathname } = new URL(req.url, 'http://localhost')
  if (!pathname.startsWith(PREFIX)) {
    res.writeHead(404).end()
    return
  }
  let file = normalize(join(ROOT, decodeURIComponent(pathname.slice(PREFIX.length))))
  if (!file.startsWith(ROOT)) {
    res.writeHead(403).end()
    return
  }
  try {
    if ((await stat(file)).isDirectory()) file = join(file, 'index.html')
    const body = await readFile(file)
    res.writeHead(200, { 'content-type': TYPES[extname(file)] ?? 'application/octet-stream' }).end(body)
  } catch {
    res.writeHead(404).end()
  }
}).listen(4173, 'localhost')

PeerServer({ host: 'localhost', port: 9000, path: '/' })
