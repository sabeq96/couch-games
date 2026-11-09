import { expect, test } from 'vitest'
import { MAX_PARTY, PLAYER_COLORS } from '@couch/shared'
import { Party } from './party'

test('joins take the lowest free slot and its colour', () => {
  const party = new Party()
  expect(party.join('a', 'Ann')).toEqual({ slot: 0, name: 'Ann', color: PLAYER_COLORS[0] })
  expect(party.join('b', 'Bo')).toEqual({ slot: 1, name: 'Bo', color: PLAYER_COLORS[1] })
  expect(party.join('c', 'Cy')).toEqual({ slot: 2, name: 'Cy', color: PLAYER_COLORS[2] })
  expect(party.byId('b')?.name).toBe('Bo')
  expect(party.idOf(2)).toBe('c')
})

test('a freed slot is reused by the next joiner', () => {
  const party = new Party()
  party.join('a', 'Ann')
  party.join('b', 'Bo')
  party.join('c', 'Cy')
  party.leave('b')
  expect(party.byId('b')).toBeUndefined()
  expect(party.idOf(1)).toBeUndefined()
  expect(party.join('d', 'Di')?.slot).toBe(1)
})

test('the party is full at MAX_PARTY', () => {
  const party = new Party()
  for (let i = 0; i < MAX_PARTY; i++) expect(party.join(`p${i}`, 'P')).not.toBeNull()
  expect(party.join('seventh', 'S')).toBeNull()
  expect(party.members()).toHaveLength(MAX_PARTY)
})

test('the lead is the first joiner; when the lead leaves it passes to the next joiner', () => {
  const party = new Party()
  expect(party.lead()).toBeNull()
  party.join('a', 'Ann')
  party.join('b', 'Bo')
  party.join('c', 'Cy')
  party.leave('b')
  party.join('d', 'Di') // takes slot 1, but joined last
  expect(party.lead()?.name).toBe('Ann')
  party.leave('a')
  expect(party.lead()?.name).toBe('Cy')
  expect(party.members().map((p) => p.name)).toEqual(['Cy', 'Di'])
})

test('roster takes the first players by join order', () => {
  const party = new Party()
  party.join('a', 'Ann')
  party.join('b', 'Bo')
  party.join('c', 'Cy')
  party.leave('a')
  party.join('d', 'Di') // slot 0, joined last
  expect(party.roster(2).map((p) => p.name)).toEqual(['Bo', 'Cy'])
})
