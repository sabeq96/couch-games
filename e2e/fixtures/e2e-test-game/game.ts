import type { DpadInput, Round, RoundHandle } from '@couch/shared'

/** Shows who plays; the first A press from a slot finishes the round with that slot first (or `window.__places`). */
export function start({ el, players, finish }: Round): RoundHandle<'dpad'> {
  const p = document.createElement('p')
  p.dataset.testid = 'round'
  p.textContent = `Round with ${players.map((pl) => pl.name).join(', ')}`
  el.append(p)

  const held = new Map<number, boolean>()
  let done = false
  return {
    input(slot: number, input: DpadInput) {
      const was = held.get(slot) ?? false
      held.set(slot, input.a)
      if (done || !input.a || was) return
      done = true
      const order = [slot, ...players.map((pl) => pl.slot).filter((s) => s !== slot)]
      // A test can set `window.__places` to finish with those places instead, in the same order (the presser first).
      const places = (window as unknown as { __places?: number[] }).__places
      finish(order.map((s, i) => ({ slot: s, place: places?.[i] ?? i + 1 })))
    },
    destroy() {
      el.replaceChildren()
      const w = window as unknown as { __destroyed?: number }
      w.__destroyed = (w.__destroyed ?? 0) + 1
    },
  }
}
