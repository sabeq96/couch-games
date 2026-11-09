import { describe, expect, it } from 'vitest'
import { seatsOf } from './slots'

const p = (slot: number, name: string) => ({ slot, name, color: '' })

describe('seatsOf', () => {
  it('is six free seats for an empty party', () => {
    const seats = seatsOf([])
    expect(seats.map((s) => s.slot)).toEqual([0, 1, 2, 3, 4, 5])
    expect(seats.every((s) => s.player === null && !s.lead)).toBe(true)
  })

  it('puts players in their slot and marks the first joiner as lead', () => {
    const sam = p(2, 'Sam')
    const alex = p(0, 'Alex')
    const seats = seatsOf([sam, alex])
    expect(seats.map((s) => s.player?.name ?? null)).toEqual(['Alex', null, 'Sam', null, null, null])
    expect(seats.map((s) => s.lead)).toEqual([false, false, true, false, false, false])
  })
})
