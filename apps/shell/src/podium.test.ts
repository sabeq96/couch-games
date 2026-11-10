import { describe, expect, it } from 'vitest'
import { splitPodium } from './podium'

const row = (slot: number, place: number) => ({ slot, place })

describe('splitPodium', () => {
  it('puts places 1 to 3 on the podium and the rest in the others', () => {
    const { podium, rest } = splitPodium([row(0, 1), row(1, 2), row(2, 3), row(3, 4)])
    expect(podium.map((r) => r.place)).toEqual([1, 2, 3])
    expect(rest.map((r) => r.place)).toEqual([4])
  })

  it('leaves a lone player who finished 4th in the others, with an empty podium', () => {
    const { podium, rest } = splitPodium([row(0, 4)])
    expect(podium).toEqual([])
    expect(rest).toEqual([row(0, 4)])
  })

  it('keeps gaps: places 2 and 5 give a podium of just 2nd', () => {
    const { podium, rest } = splitPodium([row(0, 2), row(1, 5)])
    expect(podium).toEqual([row(0, 2)])
    expect(rest).toEqual([row(1, 5)])
  })
})
