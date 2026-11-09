import { encodeInput, INPUT_HZ } from '@couch/shared'

/** Sends `read()`'s snapshot as input `hz` times a second, skipping while it is null. Returns stop. */
export function startSender(read: () => object | null, send: (msg: object) => void, hz = INPUT_HZ): () => void {
  const timer = setInterval(() => {
    const input = read()
    if (input) send(encodeInput(input))
  }, 1000 / hz)
  return () => clearInterval(timer)
}
